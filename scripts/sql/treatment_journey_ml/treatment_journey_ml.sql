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
        AND pl.ProcStatus IN (1, 2)
        AND pl.ProcFee > 0
),
HistoricalMetrics AS (
    -- Pre-calculate all historical metrics in one pass
    SELECT 
        pl_hist.CodeNum,
        pl_hist.PatNum,
        COUNT(CASE WHEN pl_hist.ProcStatus = 2 THEN 1 END) as completed_count,
        COUNT(CASE WHEN pl_hist.DateTP != '0001-01-01' THEN 1 END) as planned_count,
        AVG(pl_hist.ProcFee) as avg_historical_fee,
        SUM(CASE WHEN pl_hist.ProcStatus = 2 THEN pl_hist.ProcFee ELSE 0 END) as completed_fees,
        SUM(CASE WHEN pl_hist.DateTP != '0001-01-01' THEN pl_hist.ProcFee ELSE 0 END) as planned_fees
    FROM procedurelog pl_hist
    WHERE pl_hist.ProcDate >= DATE_SUB('2024-01-01', INTERVAL 2 YEAR)
    GROUP BY pl_hist.CodeNum, pl_hist.PatNum
),
CategoryMetrics AS (
    -- Pre-calculate category-level metrics
    SELECT 
        LEFT(pc.ProcCode, 2) as category,
        pl_hist.CodeNum,
        COUNT(CASE WHEN pl_hist.ProcStatus = 2 THEN 1 END) as cat_completed_count,
        COUNT(CASE WHEN pl_hist.DateTP != '0001-01-01' THEN 1 END) as cat_planned_count
    FROM procedurelog pl_hist
    JOIN procedurecode pc ON pl_hist.CodeNum = pc.CodeNum
    WHERE pl_hist.ProcDate >= DATE_SUB('2024-01-01', INTERVAL 2 YEAR)
    GROUP BY LEFT(pc.ProcCode, 2), pl_hist.CodeNum
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
PatientHistory AS (
    -- Pre-calculate patient-specific metrics
    SELECT 
        PatNum,
        COUNT(CASE WHEN CodeNum IN (626, 627) AND ProcStatus IN (2, 6) THEN 1 END) as missed_cancelled_count,
        COUNT(CASE WHEN CodeNum = 626 AND ProcStatus IN (2, 6) THEN 1 END) as missed_count,
        COUNT(CASE WHEN CodeNum = 627 AND ProcStatus IN (2, 6) THEN 1 END) as cancelled_count
    FROM procedurelog
    WHERE ProcDate >= DATE_SUB('2024-01-01', INTERVAL 2 YEAR)
    GROUP BY PatNum
),
PaymentValidation AS (
    SELECT 
        pl.ProcNum,
        pl.ProcFee,
        COALESCE(cp.InsPayAmt, 0) as insurance_paid,
        COALESCE(adj.TotalAdjustments, 0) as adjustments,
        (pl.ProcFee - COALESCE(cp.InsPayAmt, 0) - COALESCE(adj.TotalAdjustments, 0)) as remaining_balance,
        CASE
            WHEN COALESCE(cp.InsPayAmt, 0) > pl.ProcFee THEN 'insurance_overpaid'
            WHEN COALESCE(adj.TotalAdjustments, 0) > pl.ProcFee THEN 'adjustment_overpaid'
            WHEN COALESCE(cp.InsPayAmt, 0) + COALESCE(adj.TotalAdjustments, 0) > pl.ProcFee THEN 'total_overpaid'
            WHEN COALESCE(cp.InsPayAmt, 0) + COALESCE(adj.TotalAdjustments, 0) = pl.ProcFee THEN 'exactly_covered'
            WHEN pl.ProcFee = 0 THEN 'zero_fee'
            ELSE 'standard'
        END as validation_status,
        -- Add flags for potential data issues
        CASE WHEN COALESCE(adj.TotalAdjustments, 0) > 0 AND COALESCE(cp.InsPayAmt, 0) > 0 THEN 1 ELSE 0 END as has_both_ins_and_adj,
        CASE WHEN COALESCE(adj.TotalAdjustments, 0) + COALESCE(cp.InsPayAmt, 0) > pl.ProcFee THEN 1 ELSE 0 END as is_overcredited
    FROM FilteredProcs pl
    LEFT JOIN ClaimProcSummary cp ON pl.ProcNum = cp.ProcNum
    LEFT JOIN AdjustmentSummary adj ON pl.ProcNum = adj.ProcNum
    WHERE pl.ProcStatus = 2
),
AdjustmentDetails AS (
    -- Get detailed breakdown of adjustments
    SELECT 
        a.ProcNum,
        a.AdjAmt,
        d.ItemName as adjustment_type,
        a.AdjDate
    FROM adjustment a
    LEFT JOIN definition d ON a.AdjType = d.DefNum
    WHERE EXISTS (
        SELECT 1 FROM FilteredProcs pl 
        WHERE pl.ProcNum = a.ProcNum
        AND pl.ProcStatus = 2
    )
)

SELECT DISTINCT
    pl.ProcNum,
    pl.ProcDate,
    pl.ProcStatus,
    pl.ProcFee as OriginalFee,
    pl.ProvNum,
    
    -- Fee Analysis
    f.Amount as UCR_Fee,
    pl.ProcFee - f.Amount as UCR_Difference,
    hf.Avg_Fee as Provider_Avg_Fee,
    
    -- Core identifiers
    pl.CodeNum as ProcCodeNum,
    pc.ProcCode,
    pc.Descript as ProcedureDescription,
    
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
    
    -- Historical Metrics (from CTEs)
    COALESCE(hm.completed_count, 0) as CompletedCount,
    COALESCE(hm.planned_count, 0) as PlannedCount,
    COALESCE(hm.avg_historical_fee, 0) as Avg_Historical_Fee,
    
    -- Category Metrics (from CTEs)
    COALESCE(cm.cat_completed_count, 0) as CategoryCompletedCount,
    COALESCE(cm.cat_planned_count, 0) as CategoryPlannedCount,
    
    -- Patient History (from CTE)
    COALESCE(ph.missed_cancelled_count, 0) as PriorMissedOrCancelledAppts,
    COALESCE(ph.missed_count, 0) as PriorMissedAppts,
    COALESCE(ph.cancelled_count, 0) as PriorCancelledAppts,
    
    -- Insurance and Payment Info
    cp.InsPayAmt as ActualInsurancePayment,
    cp.InsPayEst as EstimatedInsurancePayment,
    adj.TotalAdjustments,
    
    -- Define journey stage (current state)
    CASE 
        WHEN pl.ProcStatus = 1 THEN 'treatment_planned'
        WHEN pl.ProcStatus = 2 THEN 'completed'
        WHEN pl.ProcStatus = 6 THEN 'ordered_not_scheduled'
        ELSE 'other'
    END as journey_stage,
    
    -- Track cancellations/missed appointments
    CASE 
        WHEN pl.CodeNum IN (626, 627) AND pl.ProcStatus = 2 THEN 'cancelled_or_missed'
        WHEN pl.CodeNum = 626 AND pl.ProcStatus = 2 THEN 'missed'
        WHEN pl.CodeNum = 627 AND pl.ProcStatus = 2 THEN 'cancelled'
        ELSE 'regular_procedure'
    END as cancellation_status,
    
    -- Detailed journey outcome (for analysis)
    CASE 
        -- Successful completion
        WHEN pl.ProcStatus = 2 
            AND pl.CodeNum NOT IN (626, 627)  -- Not a cancellation/missed appt
            AND (
                -- Payment is valid
                COALESCE(cp.InsPayAmt, 0) >= pl.ProcFee
                OR (COALESCE(cp.InsPayAmt, 0) + COALESCE(adj.TotalAdjustments, 0) >= pl.ProcFee)
                OR (pl.ProcFee - COALESCE(cp.InsPayAmt, 0) - COALESCE(adj.TotalAdjustments, 0) >= 0)
            ) THEN 'completed_and_paid'
        
        -- Completed but payment issues
        WHEN pl.ProcStatus = 2 
            AND pl.CodeNum NOT IN (626, 627) THEN 'completed_unpaid'
        
        -- Cancellations/Missed
        WHEN pl.CodeNum IN (626, 627) THEN 'cancelled_or_missed'
        
        -- Still in planning
        WHEN pl.ProcStatus = 1 THEN 'in_planning'
        
        ELSE 'other'
    END as journey_outcome,

    -- Binary target for ML
    CASE 
        WHEN pl.ProcStatus = 2 
            AND pl.CodeNum NOT IN (626, 627)  -- Not a cancellation
            AND (
                -- Payment is valid (using our existing payment logic)
                COALESCE(cp.InsPayAmt, 0) >= pl.ProcFee
                OR (COALESCE(cp.InsPayAmt, 0) + COALESCE(adj.TotalAdjustments, 0) >= pl.ProcFee)
                OR (pl.ProcFee - COALESCE(cp.InsPayAmt, 0) - COALESCE(adj.TotalAdjustments, 0) >= 0)
            ) THEN 1
        ELSE 0
    END as target_journey_success,
    
    -- Payment validation and details (keep these for analysis)
    pv.validation_status,
    pv.remaining_balance,
    pv.has_both_ins_and_adj,
    pv.is_overcredited,
    
    -- Add adjustment details for problematic cases
    (
        SELECT GROUP_CONCAT(CONCAT(ad.adjustment_type, ': ', ad.AdjAmt) SEPARATOR '; ')
        FROM AdjustmentDetails ad
        WHERE ad.ProcNum = pl.ProcNum
    ) as adjustment_breakdown

FROM FilteredProcs pl
LEFT JOIN patient pat ON pl.PatNum = pat.PatNum
LEFT JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
LEFT JOIN fee f ON f.CodeNum = pl.CodeNum
LEFT JOIN ClaimProcSummary cp ON pl.ProcNum = cp.ProcNum
LEFT JOIN AdjustmentSummary adj ON pl.ProcNum = adj.ProcNum
LEFT JOIN HistoricalMetrics hm ON pl.CodeNum = hm.CodeNum AND pl.PatNum = hm.PatNum
LEFT JOIN CategoryMetrics cm ON pl.CodeNum = cm.CodeNum
LEFT JOIN HistoricalFees hf ON pl.CodeNum = hf.CodeNum AND pl.ProvNum = hf.ProvNum
LEFT JOIN PatientHistory ph ON pl.PatNum = ph.PatNum
LEFT JOIN PaymentValidation pv ON pl.ProcNum = pv.ProcNum

GROUP BY pl.ProcNum
ORDER BY pl.ProcDate DESC;