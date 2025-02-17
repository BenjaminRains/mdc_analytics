-- Procedure Payment Journey Query
-- Tracks procedures from offering through payment completion, with detailed adjustment analysis
WITH ClaimProcSummary AS (
    SELECT 
        ProcNum,
        MAX(InsPayAmt) as InsPayAmt,
        MAX(InsPayEst) as InsPayEst,
        MAX(Status) as Status,
        MAX(ClaimNum) as ClaimNum
    FROM claimproc 
    GROUP BY ProcNum
),
FilteredProcs AS (
    SELECT pl.*
    FROM procedurelog pl
    WHERE pl.ProcDate >= '2023-01-01'
        AND pl.ProcDate < '2024-01-01'
        AND pl.ProcStatus IN (1, 2, 6)
        AND pl.ProcFee > 0
),
HistoricalFees AS (
    SELECT 
        p_hist.CodeNum,
        p_hist.ProvNum,
        AVG(p_hist.ProcFee) as Avg_Fee
    FROM procedurelog p_hist
    WHERE p_hist.ProcDate >= DATE_SUB('2024-01-01', INTERVAL 1 YEAR)
    AND p_hist.ProcFee > 0
    GROUP BY p_hist.CodeNum, p_hist.ProvNum
),
AdjustmentSummary AS (
    SELECT 
        ProcNum,
        SUM(AdjAmt) as TotalAdjustments
    FROM adjustment
    GROUP BY ProcNum
),
HistoricalAcceptance AS (
    SELECT 
        pl_hist.CodeNum,
        pl_hist.ProcDate,
        COUNT(CASE WHEN pl_hist.ProcStatus = 2 THEN 1 END) as CompletedCount,
        COUNT(CASE WHEN pl_hist.DateTP != '0001-01-01' THEN 1 END) as PlannedCount,
        SUM(CASE WHEN pl_hist.ProcStatus = 2 THEN pl_hist.ProcFee ELSE 0 END) as CompletedFees,
        SUM(CASE WHEN pl_hist.DateTP != '0001-01-01' THEN pl_hist.ProcFee ELSE 0 END) as PlannedFees
    FROM procedurelog pl_hist
    WHERE pl_hist.ProcDate >= DATE_SUB('2024-01-01', INTERVAL 2 YEAR)
        AND pl_hist.ProcFee > 0
    GROUP BY pl_hist.CodeNum, pl_hist.ProcDate
)
SELECT DISTINCT
    pl.ProcNum,
    pl.ProcDate,
    pl.ProcStatus,
    pl.ProcFee as OriginalFee,
    pl.ProvNum,
    
    -- Fee Analysis (raw values for pandas calculation)
    f.Amount as UCR_Fee,
    pl.ProcFee - f.Amount as UCR_Difference,
    
    -- Historical Fee Analysis (raw values)
    (
        SELECT AVG(p_hist.ProcFee)
        FROM procedurelog p_hist
        WHERE p_hist.CodeNum = pl.CodeNum
        AND p_hist.ProcDate < pl.ProcDate
        AND p_hist.ProcDate >= DATE_SUB(pl.ProcDate, INTERVAL 1 YEAR)
        AND p_hist.ProcFee > 0
    ) as Avg_Historical_Fee,
    
    -- Provider's Typical Pricing
    (
        SELECT AVG(p_hist.ProcFee)
        FROM procedurelog p_hist
        WHERE p_hist.CodeNum = pl.CodeNum
        AND p_hist.ProvNum = pl.ProvNum
        AND p_hist.ProcDate < pl.ProcDate
        AND p_hist.ProcDate >= DATE_SUB(pl.ProcDate, INTERVAL 1 YEAR)
        AND p_hist.ProcFee > 0
    ) as Provider_Avg_Fee,
    
    -- Core identifiers
    pl.CodeNum as ProcCodeNum,
    pc.ProcCode,
    pc.Descript as ProcedureDescription,
    pc.ProcCat as ProcedureCategory,
    
    -- Treatment Timing Features
    CASE 
        WHEN pl.DateTP = '0001-01-01' THEN 0
        WHEN pl.DateTP = pl.ProcDate THEN 1
        ELSE 0
    END as SameDayTreatment,
    
    CASE 
        WHEN pl.DateTP = '0001-01-01' THEN NULL
        WHEN pl.DateTP = pl.ProcDate THEN 0
        ELSE DATEDIFF(pl.ProcDate, pl.DateTP)
    END as DaysFromPlanToProc,
    
    -- Patient Context
    pat.PatNum,
    TIMESTAMPDIFF(YEAR, pat.Birthdate, pl.ProcDate) as PatientAge,
    pat.Gender,
    CASE WHEN pat.HasIns != '' THEN 1 ELSE 0 END as HasInsurance,
    
    -- Adjustment Analysis (raw values)
    adj.TotalAdjustments,
    
    -- Historical Acceptance (raw counts for pandas calculation)
    (
        SELECT COUNT(CASE WHEN pl_hist.ProcStatus = 2 THEN 1 END) as completed_count
        FROM procedurelog pl_hist
        WHERE pl_hist.CodeNum = pl.CodeNum
        AND pl_hist.ProcDate < pl.ProcDate
        AND pl_hist.ProcDate >= DATE_SUB(pl.ProcDate, INTERVAL 2 YEAR)
    ) as CompletedCount,
    
    (
        SELECT COUNT(CASE WHEN pl_hist.DateTP != '0001-01-01' THEN 1 END) as planned_count
        FROM procedurelog pl_hist
        WHERE pl_hist.CodeNum = pl.CodeNum
        AND pl_hist.ProcDate < pl.ProcDate
        AND pl_hist.ProcDate >= DATE_SUB(pl.ProcDate, INTERVAL 2 YEAR)
    ) as PlannedCount,
    
    -- Insurance Processing
    cp.InsPayAmt as ActualInsurancePayment,
    cp.InsPayEst as EstimatedInsurancePayment,
    
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
    
    -- Appointment History (raw counts)
    (
        SELECT COUNT(*)
        FROM procedurelog pl_hist
        WHERE pl_hist.PatNum = pl.PatNum
        AND pl_hist.ProcDate < pl.ProcDate
        AND pl_hist.ProcDate >= DATE_SUB(pl.ProcDate, INTERVAL 2 YEAR)
        AND pl_hist.CodeNum IN (626, 627)
        AND pl_hist.ProcStatus IN (2, 6)
    ) as PriorMissedOrCancelledAppts,
    
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
    (
        SELECT COALESCE(COUNT(*), 0)
        FROM procedurelog pl_hist
        WHERE pl_hist.PatNum = pl.PatNum
        AND pl_hist.ProcDate < pl.ProcDate
        AND pl_hist.ProcDate >= DATE_SUB(pl.ProcDate, INTERVAL 365 DAY)
        AND pl_hist.CodeNum IN (626, 627)
        AND pl_hist.ProcStatus IN (2, 6)
    ) as RecentMissedOrCancelledAppts,
    
    -- Similar Procedure Acceptance Rates (2 years)
    (
        SELECT 
            CASE 
                WHEN SUM(CASE WHEN pl_hist.DateTP != '0001-01-01' THEN pl_hist.ProcFee ELSE 0 END) = 0 THEN 0
                ELSE (SUM(CASE WHEN pl_hist.ProcStatus = 2 THEN pl_hist.ProcFee ELSE 0 END) * 100.0) 
                    / SUM(CASE WHEN pl_hist.DateTP != '0001-01-01' THEN pl_hist.ProcFee ELSE 0 END)
            END
        FROM procedurelog pl_hist
        WHERE pl_hist.CodeNum = pl.CodeNum
        AND pl_hist.ProcDate < pl.ProcDate
        AND pl_hist.ProcDate >= DATE_SUB(pl.ProcDate, INTERVAL 2 YEAR)
        AND pl_hist.ProcFee > 0
    ) as SimilarProcedureAcceptanceRate2yr_FeeWeighted,
    
    -- Count-based acceptance rates (raw counts for pandas)
    (
        SELECT COUNT(CASE WHEN pl_hist.ProcStatus = 2 THEN 1 END)
        FROM procedurelog pl_hist
        WHERE pl_hist.CodeNum = pl.CodeNum
        AND pl_hist.ProcDate < pl.ProcDate
        AND pl_hist.ProcDate >= DATE_SUB(pl.ProcDate, INTERVAL 2 YEAR)
        AND pl_hist.ProcFee > 0
    ) as SimilarProcedureAcceptanceRate2yr_Completed,
    
    (
        SELECT COUNT(CASE WHEN pl_hist.DateTP != '0001-01-01' THEN 1 END)
        FROM procedurelog pl_hist
        WHERE pl_hist.CodeNum = pl.CodeNum
        AND pl_hist.ProcDate < pl.ProcDate
        AND pl_hist.ProcDate >= DATE_SUB(pl.ProcDate, INTERVAL 2 YEAR)
        AND pl_hist.ProcFee > 0
    ) as SimilarProcedureAcceptanceRate2yr_Planned,
    
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
    
    -- Category acceptance rates (raw counts for pandas)
    (
        SELECT COUNT(CASE WHEN pl_hist.ProcStatus = 2 THEN 1 END)
        FROM procedurelog pl_hist
        WHERE LEFT(pc.ProcCode, 2) = LEFT((
            SELECT ProcCode 
            FROM procedurecode 
            WHERE CodeNum = pl_hist.CodeNum
        ), 2)  -- Same category (e.g., D2xxx)
        AND pl_hist.ProcDate < pl.ProcDate
        AND pl_hist.ProcDate >= DATE_SUB(pl.ProcDate, INTERVAL 2 YEAR)
        AND pl_hist.ProcFee > 0
    ) as CategoryCompletedCount,
    
    (
        SELECT COUNT(CASE WHEN pl_hist.DateTP != '0001-01-01' THEN 1 END)
        FROM procedurelog pl_hist
        WHERE LEFT(pc.ProcCode, 2) = LEFT((
            SELECT ProcCode 
            FROM procedurecode 
            WHERE CodeNum = pl_hist.CodeNum
        ), 2)  -- Same category (e.g., D2xxx)
        AND pl_hist.ProcDate < pl.ProcDate
        AND pl_hist.ProcDate >= DATE_SUB(pl.ProcDate, INTERVAL 2 YEAR)
        AND pl_hist.ProcFee > 0
    ) as CategoryPlannedCount,
    
    -- Insurance info
    cp.InsPayAmt,
    cp.InsPayEst,
    cp.Status as ClaimStatus

FROM FilteredProcs pl
LEFT JOIN patient pat ON pl.PatNum = pat.PatNum
LEFT JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
LEFT JOIN fee f ON f.CodeNum = pl.CodeNum
LEFT JOIN ClaimProcSummary cp ON pl.ProcNum = cp.ProcNum
LEFT JOIN claim c ON cp.ClaimNum = c.ClaimNum
LEFT JOIN AdjustmentSummary adj ON pl.ProcNum = adj.ProcNum
LEFT JOIN HistoricalAcceptance h ON pl.CodeNum = h.CodeNum AND h.ProcDate < pl.ProcDate

ORDER BY pl.ProcDate DESC;