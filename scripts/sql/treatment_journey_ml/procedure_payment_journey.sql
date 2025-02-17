-- Procedure Payment Journey Query
-- Tracks procedures from offering through payment completion, with detailed adjustment analysis
SELECT
    -- Core identifiers and pricing info
    pl.ProcNum,
    pl.ProcDate,
    pl.ProcStatus,
    pl.ProcFee as OriginalFee,
    pl.ProvNum,
    
    -- Fee Analysis (Out of Network Context)
    f.Amount as UCR_Fee,  -- Usual, Customary, and Reasonable fee
    COALESCE((pl.ProcFee - f.Amount) / NULLIF(f.Amount, 0) * 100, 0) as UCR_Variance,
    
    -- Historical Fee Analysis
    COALESCE((
        SELECT AVG(pl_hist.ProcFee)
        FROM procedurelog pl_hist
        WHERE pl_hist.CodeNum = pl.CodeNum
        AND pl_hist.ProcDate < pl.ProcDate
        AND pl_hist.ProcDate >= DATE_SUB(pl.ProcDate, INTERVAL 1 YEAR)
        AND pl_hist.ProcFee > 0
    ), 0) as Avg_Historical_Fee,
    
    -- Provider's Typical Pricing
    COALESCE((
        SELECT AVG(pl_hist.ProcFee)
        FROM procedurelog pl_hist
        WHERE pl_hist.CodeNum = pl.CodeNum
        AND pl_hist.ProvNum = pl.ProvNum
        AND pl_hist.ProcDate < pl.ProcDate
        AND pl_hist.ProcDate >= DATE_SUB(pl.ProcDate, INTERVAL 1 YEAR)
        AND pl_hist.ProcFee > 0
    ), 0) as Provider_Avg_Fee,
    
    -- Procedure Code Details
    pl.CodeNum as ProcCodeNum,
    pc.ProcCode,
    pc.Descript as ProcedureDescription,
    pc.ProcCat as ProcedureCategory,
    
    -- Treatment Timing Features
    CASE 
        WHEN pl.DateTP = '0001-01-01' THEN 0  -- No treatment plan date
        WHEN pl.DateTP = pl.ProcDate THEN 1  -- Same day treatment
        ELSE 0  -- Planned treatment
    END as SameDayTreatment,
    
    CASE 
        WHEN pl.DateTP = '0001-01-01' THEN NULL  -- No treatment plan
        WHEN pl.DateTP = pl.ProcDate THEN 0    -- Same day treatment
        ELSE DATEDIFF(pl.ProcDate, pl.DateTP)  -- Days between plan and procedure
    END as DaysFromPlanToProc,
    
    -- Patient Context
    pat.PatNum,
    TIMESTAMPDIFF(YEAR, pat.Birthdate, pl.ProcDate) as PatientAge,
    pat.Gender,
    CASE WHEN pat.HasIns != '' THEN 1 ELSE 0 END as HasInsurance,
    
    -- Adjustment Analysis (Complete)
    COALESCE((
        SELECT SUM(adj.AdjAmt)
        FROM adjustment adj 
        WHERE adj.ProcNum = pl.ProcNum
        AND adj.DateEntry <= pl.ProcDate
    ), 0) as PreProcedureAdjustments,
    
    COALESCE((
        SELECT SUM(adj.AdjAmt)
        FROM adjustment adj 
        WHERE adj.ProcNum = pl.ProcNum
        AND adj.DateEntry > pl.ProcDate
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
        WHERE adj.ProcNum = pl.ProcNum
    ) as AdjustmentTypes,
    
    -- Adjustment Summary
    (
        SELECT COUNT(DISTINCT adj.AdjType)
        FROM adjustment adj
        WHERE adj.ProcNum = pl.ProcNum
    ) as NumberOfAdjustmentTypes,
    
    -- Adjustment Timing
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM adjustment adj 
            WHERE adj.ProcNum = pl.ProcNum
            AND adj.DateEntry <= pl.DateTP
        ) THEN 1 ELSE 0 
    END as HasPrePlanningAdjustment,
    
    -- Total Adjustment Impact
    COALESCE((
        SELECT SUM(adj.AdjAmt)
        FROM adjustment adj 
        WHERE adj.ProcNum = pl.ProcNum
    ), 0) / NULLIF(pl.ProcFee, 0) * 100 as AdjustmentPercentage,
    
    -- Historical Pattern
    COALESCE((
        SELECT AVG(adj_hist.AdjAmt / pl_hist.ProcFee) * 100
        FROM procedurelog pl_hist
        JOIN adjustment adj_hist ON pl_hist.ProcNum = adj_hist.ProcNum
        WHERE pl_hist.PatNum = pl.PatNum
        AND pl_hist.ProcDate < pl.ProcDate
        AND pl_hist.ProcDate >= DATE_SUB(pl.ProcDate, INTERVAL 2 YEAR)
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
        WHERE ps.ProcNum = pl.ProcNum 
        AND DATEDIFF(pay.PayDate, pl.ProcDate) <= 30
    ) THEN 1 ELSE 0 END as Paid_Within_30d,
    
    CASE WHEN EXISTS (
        SELECT 1 
        FROM paysplit ps 
        JOIN payment pay ON ps.PayNum = pay.PayNum
        WHERE ps.ProcNum = pl.ProcNum 
        AND DATEDIFF(pay.PayDate, pl.ProcDate) <= 90
    ) THEN 1 ELSE 0 END as Paid_Within_90d,
    
    -- Payment Completion Status
    CASE 
        WHEN pl.ProcFee <= 0 THEN NULL
        WHEN (pl.ProcFee + COALESCE((
            SELECT SUM(adj.AdjAmt)
            FROM adjustment adj 
            WHERE adj.ProcNum = pl.ProcNum
        ), 0)) <= COALESCE(
            (SELECT SUM(ps.SplitAmt) FROM paysplit ps WHERE ps.ProcNum = pl.ProcNum), 0
        ) + COALESCE(cp.InsPayAmt, 0) THEN 1 
        ELSE 0 
    END as FullyPaid,
    
    -- Target Variables
    CASE 
        WHEN pl.ProcStatus = 2 AND pl.ProcFee > 0 THEN 1 
        ELSE 0 
    END as target_accepted,
    
    -- Appointment History Features
    COALESCE((
        SELECT COUNT(*)
        FROM procedurelog pl_hist
        WHERE pl_hist.PatNum = pl.PatNum
        AND pl_hist.ProcDate < pl.ProcDate
        AND pl_hist.ProcDate >= DATE_SUB(pl.ProcDate, INTERVAL 2 YEAR)
        AND pl_hist.CodeNum IN (626, 627)  -- Missed (626) and Cancelled (627) appointment codes
        AND pl_hist.ProcStatus IN (2, 6)
    ), 0) as PriorMissedOrCancelledAppts,
    
    -- Separate Missed vs Cancelled
    COALESCE((
        SELECT COUNT(*)
        FROM procedurelog pl_hist
        WHERE pl_hist.PatNum = pl.PatNum
        AND pl_hist.ProcDate < pl.ProcDate
        AND pl_hist.ProcDate >= DATE_SUB(pl.ProcDate, INTERVAL 2 YEAR)
        AND pl_hist.CodeNum = 626  -- D9986/626 Missed Appointments
        AND pl_hist.ProcStatus IN (2, 6)
    ), 0) as PriorMissedAppts,
    
    COALESCE((
        SELECT COUNT(*)
        FROM procedurelog pl_hist
        WHERE pl_hist.PatNum = pl.PatNum
        AND pl_hist.ProcDate < pl.ProcDate
        AND pl_hist.ProcDate >= DATE_SUB(pl.ProcDate, INTERVAL 2 YEAR)
        AND pl_hist.CodeNum = 627  -- D9987/627 Cancelled Appointments
        AND pl_hist.ProcStatus IN (2, 6)
    ), 0) as PriorCancelledAppts,
    
    -- Recent History (Last 365 Days)
    COALESCE((
        SELECT COUNT(*)
        FROM procedurelog pl_hist
        WHERE pl_hist.PatNum = pl.PatNum
        AND pl_hist.ProcDate < pl.ProcDate
        AND pl_hist.ProcDate >= DATE_SUB(pl.ProcDate, INTERVAL 365 DAY)
        AND pl_hist.CodeNum IN (626, 627)
        AND pl_hist.ProcStatus IN (2, 6)
    ), 0) as RecentMissedOrCancelledAppts,
    
    -- Similar Procedure Acceptance Rates (2 years)
    COALESCE((
        SELECT SUM(CASE 
            WHEN pl_hist.ProcStatus = 2 THEN pl_hist.ProcFee  -- Completed
            ELSE 0 
        END) * 100.0 / NULLIF(SUM(CASE 
            WHEN pl_hist.DateTP != '0001-01-01' THEN pl_hist.ProcFee  -- Was Treatment Planned
            ELSE 0
        END), 0)
        FROM procedurelog pl_hist
        WHERE pl_hist.CodeNum = pl.CodeNum
        AND pl_hist.ProcDate < pl.ProcDate
        AND pl_hist.ProcDate >= DATE_SUB(pl.ProcDate, INTERVAL 2 YEAR)
        AND pl_hist.ProcFee > 0
    ), 0) as SimilarProcedureAcceptanceRate2yr_FeeWeighted,
    
    -- Count-based acceptance rate
    COALESCE((
        SELECT COUNT(CASE 
            WHEN pl_hist.ProcStatus = 2 THEN 1 
            ELSE NULL 
        END) * 100.0 / NULLIF(COUNT(CASE 
            WHEN pl_hist.DateTP != '0001-01-01' THEN 1 
            ELSE NULL
        END), 0)
        FROM procedurelog pl_hist
        WHERE pl_hist.CodeNum = pl.CodeNum
        AND pl_hist.ProcDate < pl.ProcDate
        AND pl_hist.ProcDate >= DATE_SUB(pl.ProcDate, INTERVAL 2 YEAR)
        AND pl_hist.ProcFee > 0
    ), 0) as SimilarProcedureAcceptanceRate2yr_CountBased,
    
    -- Add context counts
    COALESCE((
        SELECT COUNT(*)
        FROM procedurelog pl_hist
        WHERE pl_hist.CodeNum = pl.CodeNum
        AND pl_hist.ProcDate < pl.ProcDate
        AND pl_hist.ProcDate >= DATE_SUB(pl.ProcDate, INTERVAL 2 YEAR)
        AND pl_hist.DateTP != '0001-01-01'  -- Was Treatment Planned
        AND pl_hist.ProcFee > 0
    ), 0) as SimilarProceduresPlanned2yr,
    
    -- Acceptance rates by procedure category
    COALESCE((
        SELECT COUNT(CASE 
            WHEN pl_hist.ProcStatus = 2 THEN 1 
            ELSE NULL 
        END) * 100.0 / NULLIF(COUNT(CASE 
            WHEN pl_hist.DateTP != '0001-01-01' THEN 1 
            ELSE NULL
        END), 0)
        FROM procedurelog pl_hist
        WHERE LEFT(pc.ProcCode, 2) = LEFT((
            SELECT ProcCode 
            FROM procedurecode 
            WHERE CodeNum = pl_hist.CodeNum
        ), 2)  -- Same category (e.g., D2xxx)
        AND pl_hist.ProcDate < pl.ProcDate
        AND pl_hist.ProcDate >= DATE_SUB(pl.ProcDate, INTERVAL 2 YEAR)
        AND pl_hist.ProcFee > 0
    ), 0) as CategoryAcceptanceRate2yr

FROM procedurelog pl
LEFT JOIN patient pat ON pl.PatNum = pat.PatNum
LEFT JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
LEFT JOIN claimproc cp ON pl.ProcNum = cp.ProcNum
LEFT JOIN claim c ON cp.ClaimNum = c.ClaimNum
LEFT JOIN fee f ON f.CodeNum = pl.CodeNum

WHERE pl.ProcDate >= '2023-01-01'
    AND pl.ProcDate < '2024-01-01'
    AND pl.ProcStatus IN (1, 2, 6)
    AND pl.ProcFee > 0

ORDER BY pl.ProcDate DESC;