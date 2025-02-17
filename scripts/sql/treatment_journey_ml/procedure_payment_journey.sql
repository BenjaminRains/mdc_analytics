-- Procedure Payment Journey Query
-- Tracks procedures from offering through payment completion, with detailed adjustment analysis
SELECT
    -- Core identifiers and pricing info
    proc.ProcNum,
    proc.ProcDate,
    proc.ProcStatus,
    proc.ProcFee as OriginalFee,
    proc.ProvNum,
    
    -- Fee Analysis (Out of Network Context)
    f.Amount as UCR_Fee,  -- Usual, Customary, and Reasonable fee
    COALESCE((proc.ProcFee - f.Amount) / NULLIF(f.Amount, 0) * 100, 0) as UCR_Variance,
    
    -- Historical Fee Analysis
    COALESCE((
        SELECT AVG(p_hist.ProcFee)
        FROM procedurelog p_hist
        WHERE p_hist.CodeNum = proc.CodeNum
        AND p_hist.ProcDate < proc.ProcDate
        AND p_hist.ProcDate >= DATE_SUB(proc.ProcDate, INTERVAL 1 YEAR)
        AND p_hist.ProcFee > 0
    ), 0) as Avg_Historical_Fee,
    
    -- Provider's Typical Pricing
    COALESCE((
        SELECT AVG(p_hist.ProcFee)
        FROM procedurelog p_hist
        WHERE p_hist.CodeNum = proc.CodeNum
        AND p_hist.ProvNum = proc.ProvNum
        AND p_hist.ProcDate < proc.ProcDate
        AND p_hist.ProcDate >= DATE_SUB(proc.ProcDate, INTERVAL 1 YEAR)
        AND p_hist.ProcFee > 0
    ), 0) as Provider_Avg_Fee,
    
    -- Procedure Code Details
    proc.CodeNum as ProcCodeNum,
    pc.ProcCode,
    pc.Descript as ProcedureDescription,
    pc.ProcCat as ProcedureCategory,
    
    -- Treatment Timing Features
    CASE 
        WHEN proc.DateTP = '0001-01-01' THEN 0  -- No treatment plan date
        WHEN proc.DateTP = proc.ProcDate THEN 1  -- Same day treatment
        ELSE 0  -- Planned treatment
    END as SameDayTreatment,
    
    CASE 
        WHEN proc.DateTP = '0001-01-01' THEN NULL  -- No treatment plan
        WHEN proc.DateTP = proc.ProcDate THEN 0    -- Same day treatment
        ELSE DATEDIFF(proc.ProcDate, proc.DateTP)  -- Days between plan and procedure
    END as DaysFromPlanToProc,
    
    -- Patient Context
    pat.PatNum,
    TIMESTAMPDIFF(YEAR, pat.Birthdate, proc.ProcDate) as PatientAge,
    pat.Gender,
    CASE WHEN pat.HasIns != '' THEN 1 ELSE 0 END as HasInsurance,
    
    -- Adjustment Analysis (Complete)
    COALESCE((
        SELECT SUM(adj.AdjAmt)
        FROM adjustment adj 
        WHERE adj.ProcNum = proc.ProcNum
        AND adj.DateEntry <= proc.ProcDate
    ), 0) as PreProcedureAdjustments,
    
    COALESCE((
        SELECT SUM(adj.AdjAmt)
        FROM adjustment adj 
        WHERE adj.ProcNum = proc.ProcNum
        AND adj.DateEntry > proc.ProcDate
    ), 0) as PostProcedureAdjustments,
    
    -- Adjustment Types (All Types)
    (
        SELECT 
            GROUP_CONCAT(
                CONCAT(
                    d.ItemName, ':', 
                    CAST(adj.AdjAmt AS CHAR)
                )
                SEPARATOR '; '
            )
        FROM adjustment adj 
        JOIN definition d ON adj.AdjType = d.DefNum
        WHERE adj.ProcNum = proc.ProcNum
    ) as AdjustmentTypes,
    
    -- Adjustment Summary
    (
        SELECT COUNT(DISTINCT adj.AdjType)
        FROM adjustment adj
        WHERE adj.ProcNum = proc.ProcNum
    ) as NumberOfAdjustmentTypes,
    
    -- Adjustment Timing
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM adjustment adj 
            WHERE adj.ProcNum = proc.ProcNum
            AND adj.DateEntry <= proc.DateTP
        ) THEN 1 ELSE 0 
    END as HasPrePlanningAdjustment,
    
    -- Total Adjustment Impact
    COALESCE((
        SELECT SUM(adj.AdjAmt)
        FROM adjustment adj 
        WHERE adj.ProcNum = proc.ProcNum
    ), 0) / NULLIF(proc.ProcFee, 0) * 100 as AdjustmentPercentage,
    
    -- Historical Pattern
    COALESCE((
        SELECT AVG(adj_hist.AdjAmt / p_hist.ProcFee) * 100
        FROM procedurelog p_hist
        JOIN adjustment adj_hist ON p_hist.ProcNum = adj_hist.ProcNum
        WHERE p_hist.PatNum = proc.PatNum
        AND p_hist.ProcDate < proc.ProcDate
        AND p_hist.ProcDate >= DATE_SUB(proc.ProcDate, INTERVAL 2 YEAR)
    ), 0) as HistoricalAdjustmentPercentage,
    
    -- Insurance Processing
    CASE 
        WHEN cp.Status = 1 THEN cp.InsPayEst
        WHEN cp.Status = 0 THEN cp.InsPayEst
        ELSE 0 
    END as EstimatedInsurancePayment,
    COALESCE(cp.InsPayAmt, 0) as ActualInsurancePayment,
    
    -- Payment Windows
    CASE WHEN EXISTS (
        SELECT 1 
        FROM paysplit ps 
        JOIN payment pay ON ps.PayNum = pay.PayNum
        WHERE ps.ProcNum = proc.ProcNum 
        AND DATEDIFF(pay.PayDate, proc.ProcDate) <= 30
    ) THEN 1 ELSE 0 END as Paid_Within_30d,
    
    CASE WHEN EXISTS (
        SELECT 1 
        FROM paysplit ps 
        JOIN payment pay ON ps.PayNum = pay.PayNum
        WHERE ps.ProcNum = proc.ProcNum 
        AND DATEDIFF(pay.PayDate, proc.ProcDate) <= 90
    ) THEN 1 ELSE 0 END as Paid_Within_90d,
    
    -- Payment Completion Status
    CASE 
        WHEN proc.ProcFee <= 0 THEN NULL
        WHEN (proc.ProcFee + COALESCE((
            SELECT SUM(adj.AdjAmt)
            FROM adjustment adj 
            WHERE adj.ProcNum = proc.ProcNum
        ), 0)) <= COALESCE(
            (SELECT SUM(ps.SplitAmt) FROM paysplit ps WHERE ps.ProcNum = proc.ProcNum), 0
        ) + COALESCE(cp.InsPayAmt, 0) THEN 1 
        ELSE 0 
    END as FullyPaid,
    
    -- Target Variables
    CASE 
        WHEN proc.ProcStatus = 2 AND proc.ProcFee > 0 THEN 1 
        ELSE 0 
    END as target_accepted,
    
    -- Appointment History Features
    COALESCE((
        SELECT COUNT(*)
        FROM procedurelog p_hist
        WHERE p_hist.PatNum = proc.PatNum
        AND p_hist.ProcDate < proc.ProcDate
        AND p_hist.ProcDate >= DATE_SUB(proc.ProcDate, INTERVAL 2 YEAR)
        AND p_hist.CodeNum IN (626, 627)  -- Missed (626) and Cancelled (627) appointment codes
        AND p_hist.ProcStatus IN (2, 6)
    ), 0) as PriorMissedOrCancelledAppts,
    
    -- Separate Missed vs Cancelled
    COALESCE((
        SELECT COUNT(*)
        FROM procedurelog p_hist
        WHERE p_hist.PatNum = proc.PatNum
        AND p_hist.ProcDate < proc.ProcDate
        AND p_hist.ProcDate >= DATE_SUB(proc.ProcDate, INTERVAL 2 YEAR)
        AND p_hist.CodeNum = 626  -- D9986/626 Missed Appointments
        AND p_hist.ProcStatus IN (2, 6)
    ), 0) as PriorMissedAppts,
    
    COALESCE((
        SELECT COUNT(*)
        FROM procedurelog p_hist
        WHERE p_hist.PatNum = proc.PatNum
        AND p_hist.ProcDate < proc.ProcDate
        AND p_hist.ProcDate >= DATE_SUB(proc.ProcDate, INTERVAL 2 YEAR)
        AND p_hist.CodeNum = 627  -- D9987/627 Cancelled Appointments
        AND p_hist.ProcStatus IN (2, 6)
    ), 0) as PriorCancelledAppts,
    
    -- Recent History (Last 365 Days)
    COALESCE((
        SELECT COUNT(*)
        FROM procedurelog p_hist
        WHERE p_hist.PatNum = proc.PatNum
        AND p_hist.ProcDate < proc.ProcDate
        AND p_hist.ProcDate >= DATE_SUB(proc.ProcDate, INTERVAL 365 DAY)
        AND p_hist.CodeNum IN (626, 627)
        AND p_hist.ProcStatus IN (2, 6)
    ), 0) as RecentMissedOrCancelledAppts,
    
    -- Similar Procedure Acceptance Rates (2 years)
    COALESCE((
        SELECT SUM(CASE 
            WHEN p_hist.ProcStatus = 2 THEN p_hist.ProcFee  -- Completed
            ELSE 0 
        END) * 100.0 / NULLIF(SUM(CASE 
            WHEN p_hist.DateTP != '0001-01-01' THEN p_hist.ProcFee  -- Was Treatment Planned
            ELSE 0
        END), 0)
        FROM procedurelog p_hist
        WHERE p_hist.CodeNum = proc.CodeNum
        AND p_hist.ProcDate < proc.ProcDate
        AND p_hist.ProcDate >= DATE_SUB(proc.ProcDate, INTERVAL 2 YEAR)
        AND p_hist.ProcFee > 0
    ), 0) as SimilarProcedureAcceptanceRate2yr_FeeWeighted,
    
    -- Count-based acceptance rate
    COALESCE((
        SELECT COUNT(CASE 
            WHEN p_hist.ProcStatus = 2 THEN 1 
            ELSE NULL 
        END) * 100.0 / NULLIF(COUNT(CASE 
            WHEN p_hist.DateTP != '0001-01-01' THEN 1 
            ELSE NULL
        END), 0)
        FROM procedurelog p_hist
        WHERE p_hist.CodeNum = proc.CodeNum
        AND p_hist.ProcDate < proc.ProcDate
        AND p_hist.ProcDate >= DATE_SUB(proc.ProcDate, INTERVAL 2 YEAR)
        AND p_hist.ProcFee > 0
    ), 0) as SimilarProcedureAcceptanceRate2yr_CountBased,
    
    -- Add context counts
    COALESCE((
        SELECT COUNT(*)
        FROM procedurelog p_hist
        WHERE p_hist.CodeNum = proc.CodeNum
        AND p_hist.ProcDate < proc.ProcDate
        AND p_hist.ProcDate >= DATE_SUB(proc.ProcDate, INTERVAL 2 YEAR)
        AND p_hist.DateTP != '0001-01-01'  -- Was Treatment Planned
        AND p_hist.ProcFee > 0
    ), 0) as SimilarProceduresPlanned2yr,
    
    -- Acceptance rates by procedure category
    COALESCE((
        SELECT COUNT(CASE 
            WHEN p_hist.ProcStatus = 2 THEN 1 
            ELSE NULL 
        END) * 100.0 / NULLIF(COUNT(CASE 
            WHEN p_hist.DateTP != '0001-01-01' THEN 1 
            ELSE NULL
        END), 0)
        FROM procedurelog p_hist
        WHERE LEFT(pc.ProcCode, 2) = LEFT((
            SELECT ProcCode 
            FROM procedurecode 
            WHERE CodeNum = p_hist.CodeNum
        ), 2)  -- Same category (e.g., D2xxx)
        AND p_hist.ProcDate < proc.ProcDate
        AND p_hist.ProcDate >= DATE_SUB(proc.ProcDate, INTERVAL 2 YEAR)
        AND p_hist.ProcFee > 0
    ), 0) as CategoryAcceptanceRate2yr

FROM procedurelog proc
LEFT JOIN patient pat ON proc.PatNum = pat.PatNum
LEFT JOIN procedurecode pc ON proc.CodeNum = pc.CodeNum
LEFT JOIN claimproc cp ON proc.ProcNum = cp.ProcNum
LEFT JOIN claim c ON cp.ClaimNum = c.ClaimNum
LEFT JOIN fee f ON f.CodeNum = proc.CodeNum

WHERE proc.ProcDate >= '2023-01-01'
    AND proc.ProcDate < '2024-01-01'
    AND proc.ProcStatus IN (1, 2, 6)
    AND proc.ProcFee > 0

ORDER BY proc.ProcDate DESC;