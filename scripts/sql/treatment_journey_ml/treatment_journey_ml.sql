/* 
 * Procedure Payment Journey Query
 * Tracks procedures from offering through payment completion, with detailed adjustment analysis
 */
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
        a.ProcNum,
        COUNT(*) as adj_count,
        -- Write-offs (negative adjustments)
        SUM(CASE 
            WHEN a.AdjType IN (8, 9, 186, 188, 472, 473, 474, 475, 477, 
                              482, 485, 486, 488, 537, 550, 601, 616, 648) THEN a.AdjAmt
            ELSE 0 
        END) as write_offs,
        -- Positive adjustments (type 18 is the only positive one we see)
        SUM(CASE 
            WHEN a.AdjType = 18 THEN a.AdjAmt
            ELSE 0 
        END) as positive_adjustments,
        -- Total adjustments
        SUM(a.AdjAmt) as total_adjustments,
        -- Track adjustment types
        GROUP_CONCAT(DISTINCT a.AdjType ORDER BY a.AdjType) as adjustment_types,
        MIN(a.DateEntry) as first_adj_date,
        MAX(a.DateEntry) as last_adj_date
    FROM adjustment a
    WHERE a.AdjAmt != 0  -- Exclude zero adjustments
    GROUP BY a.ProcNum
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
PaymentSplitMetrics AS (
    -- Add payment split pattern analysis
    SELECT 
        ps.ProcNum,
        COUNT(*) as split_count,
        SUM(ps.SplitAmt) as total_split_amount,
        SUM(ps.SplitAmt) as total_paid,
        p.PayAmt as payment_amount,
        ps.UnearnedType as unearned_type,
        CASE 
            WHEN COUNT(*) BETWEEN 1 AND 3 THEN 'normal_split'
            WHEN COUNT(*) BETWEEN 4 AND 15 THEN 'complex_split'
            WHEN COUNT(*) > 15 THEN 'review_needed'
            ELSE 'no_splits'
        END as split_pattern
    FROM paysplit ps
    JOIN payment p ON ps.PayNum = p.PayNum
    GROUP BY ps.ProcNum, p.PayAmt, ps.UnearnedType
    HAVING ABS(SUM(ps.SplitAmt) - p.PayAmt) < 0.01  -- Verify split integrity
),
PaymentValidation AS (
    SELECT 
        pl.ProcNum,
        pl.ProcFee as OriginalFee,
        pl.ProcStatus,
        COALESCE(cp.InsPayAmt, 0) as insurance_paid,
        COALESCE(adj.write_offs, 0) as write_offs,
        COALESCE(adj.positive_adjustments, 0) as positive_adjustments,
        COALESCE(adj.total_adjustments, 0) as adjustments,
        COALESCE(adj.adj_count, 0) as adjustment_count,
        adj.adjustment_types,
        COALESCE(psm.total_paid, 0) as direct_paid,
        -- Total payments including adjustments
        (COALESCE(cp.InsPayAmt, 0) + 
         COALESCE(psm.total_paid, 0) + 
         COALESCE(adj.total_adjustments, 0)) as total_payments,
        -- Payment status with adjustments
        CASE
            WHEN pl.ProcFee = 0 THEN 'zero_fee'
            WHEN pl.ProcStatus != 2 THEN 'not_completed'
            WHEN pl.CodeNum IN (626, 627) THEN 'cancelled_or_missed'
            WHEN (COALESCE(cp.InsPayAmt, 0) + 
                  COALESCE(psm.total_paid, 0) + 
                  COALESCE(adj.total_adjustments, 0)) >= pl.ProcFee THEN 'paid_in_full'
            WHEN (COALESCE(cp.InsPayAmt, 0) + 
                  COALESCE(psm.total_paid, 0) + 
                  COALESCE(adj.total_adjustments, 0)) > 0 THEN 'partially_paid'
            ELSE 'unpaid'
        END as validation_status,
        -- Payment success with adjustments
        CASE
            WHEN pl.ProcFee = 0 THEN NULL
            WHEN pl.ProcStatus = 2  -- Must be completed
                AND pl.CodeNum NOT IN (626, 627)  -- Not cancelled
                AND (COALESCE(cp.InsPayAmt, 0) + 
                     COALESCE(psm.total_paid, 0) + 
                     COALESCE(adj.total_adjustments, 0)) >= pl.ProcFee
            THEN 1
            ELSE 0
        END as payment_success,
        -- Add remaining balance
        pl.ProcFee - (COALESCE(cp.InsPayAmt, 0) + 
                     COALESCE(psm.total_paid, 0) + 
                     COALESCE(adj.total_adjustments, 0)) as remaining_balance,
        -- Add overcredited flag
        CASE WHEN (COALESCE(cp.InsPayAmt, 0) + 
                  COALESCE(adj.total_adjustments, 0) + 
                  COALESCE(psm.total_paid, 0)) > pl.ProcFee THEN 1 ELSE 0 END as is_overcredited,
        -- Add insurance and adjustment flag
        CASE WHEN COALESCE(cp.InsPayAmt, 0) > 0 
             AND COALESCE(adj.total_adjustments, 0) != 0 THEN 1 ELSE 0 END as has_both_ins_and_adj
    FROM FilteredProcs pl
    LEFT JOIN ClaimProcSummary cp ON pl.ProcNum = cp.ProcNum
    LEFT JOIN AdjustmentSummary adj ON pl.ProcNum = adj.ProcNum
    LEFT JOIN PaymentSplitMetrics psm ON pl.ProcNum = psm.ProcNum
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
),
InsuranceAccuracy AS (
    -- Track insurance estimate accuracy
    SELECT 
        cp.ProcNum,
        cp.InsPayEst,
        cp.InsPayAmt,
        CASE
            WHEN cp.InsPayAmt = cp.InsPayEst THEN 'exact_match'
            WHEN cp.InsPayAmt > cp.InsPayEst THEN 'over_estimate'
            WHEN cp.InsPayAmt < cp.InsPayEst THEN 'under_estimate'
            ELSE 'no_estimate'
        END as estimate_accuracy,
        CASE WHEN cp.InsPayAmt > cp.InsPayEst * 1.1 THEN 1 ELSE 0 END as significant_overpayment
    FROM claimproc cp
    WHERE cp.Status = 1  -- Only active claims
),

-- Add Journey Stage calculation
JourneyStage AS (
    SELECT 
        pl.ProcNum,
        CASE
            WHEN pl.ProcStatus = 2 THEN 'completed'
            WHEN pl.ProcStatus = 1 AND pl.DateTP != '0001-01-01' THEN 'treatment_planned'
            WHEN pl.ProcStatus = 1 THEN 'in_progress'
            ELSE 'other'
        END as journey_stage
    FROM FilteredProcs pl
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
    adj.total_adjustments,
    
    -- Define journey stage (current state)
    js.journey_stage,
    
    -- Track cancellations/missed appointments
    CASE 
        WHEN pl.CodeNum IN (626, 627) AND pl.ProcStatus = 2 THEN 'cancelled_or_missed'
        WHEN pl.CodeNum = 626 AND pl.ProcStatus = 2 THEN 'missed'
        WHEN pl.CodeNum = 627 AND pl.ProcStatus = 2 THEN 'cancelled'
        ELSE 'regular_procedure'
    END as cancellation_status,
    
    -- Payment Components (from PaymentValidation)
    pv.insurance_paid,
    pv.adjustments,
    pv.adjustment_count,
    pv.direct_paid,
    pv.total_payments,
    pv.validation_status,
    pv.payment_success,
    
    -- Keep existing journey outcome and other metrics
    CASE 
        WHEN pl.ProcStatus = 2 
            AND pl.CodeNum NOT IN (626, 627)  -- Not a cancellation
            AND (
                pl.ProcFee = 0  -- Zero fee procedures are automatically successful
                OR (
                    -- Either insurance covers it
                    COALESCE(cp.InsPayAmt, 0) >= pl.ProcFee
                    -- Or insurance + adjustments cover it
                    OR (COALESCE(cp.InsPayAmt, 0) + COALESCE(pv.adjustments, 0) >= pl.ProcFee)
                    -- Or direct payments + adjustments cover it
                    OR (COALESCE(psm.total_paid, 0) + COALESCE(pv.adjustments, 0) >= pl.ProcFee)
                )
            ) THEN 'completed_and_paid'
        
        -- Rest of journey_outcome logic
        WHEN pl.ProcStatus = 2 
            AND pl.CodeNum NOT IN (626, 627) THEN 'completed_unpaid'
        WHEN pl.CodeNum IN (626, 627) THEN 'cancelled_or_missed'
        WHEN pl.ProcStatus = 1 THEN 'in_planning'
        ELSE 'other'
    END as journey_outcome,

    -- Binary target for ML
    CASE 
        WHEN pl.ProcStatus = 2  -- Must be completed
            AND pl.CodeNum NOT IN (626, 627)  -- Not cancelled/missed
            AND (
                -- Zero-fee success path (40.1% success rate observed)
                (pl.ProcFee = 0 AND pl.CodeNum NOT IN (SELECT CodeNum FROM ExcludedCodes))
                
                OR
                
                -- Fee-based success path
                (pl.ProcFee > 0 AND (
                    -- Direct payment path (98.5% success rate)
                    (
                        COALESCE(psm.total_paid, 0) > 0
                        AND COALESCE(cp.InsPayAmt, 0) = 0  -- No insurance involved
                        AND psm.split_pattern IN ('normal_split', 'complex_split')  -- Both patterns show high success
                        AND (
                            COALESCE(psm.total_paid, 0) + 
                            COALESCE(adj.total_adjustments, 0) >= pl.ProcFee * 0.95
                        )
                    )
                    
                    OR
                    
                    -- Insurance path (84.3% success rate)
                    (
                        cp.Status = 1  -- Active claim
                        AND COALESCE(cp.InsPayAmt, 0) > 0
                        AND (
                            -- Full insurance coverage
                            cp.InsPayAmt >= pl.ProcFee * 0.90  -- Adjusted threshold for insurance
                            OR
                            -- Combined coverage
                            (
                                cp.InsPayAmt + COALESCE(psm.total_paid, 0) + 
                                COALESCE(adj.total_adjustments, 0) >= pl.ProcFee * 0.95
                                AND psm.split_pattern IN ('normal_split', 'complex_split')
                            )
                        )
                        AND NOT ia.significant_overpayment  -- No insurance overpayment
                    )
                ))
            ) THEN 1
        ELSE 0
    END as target_journey_success,
    
    -- Payment validation and details (keep these for analysis)
    pv.remaining_balance,
    pv.is_overcredited,
    pv.has_both_ins_and_adj,
    
    -- Add adjustment details for problematic cases
    (
        SELECT GROUP_CONCAT(CONCAT(ad.adjustment_type, ': ', ad.AdjAmt) SEPARATOR '; ')
        FROM AdjustmentDetails ad
        WHERE ad.ProcNum = pl.ProcNum
    ) as adjustment_breakdown,

    -- Add Payment Split Analysis
    psm.split_pattern,
    
    -- Add Payment Type Context
    CASE 
        WHEN psm.unearned_type = 0 THEN 'regular_payment'
        WHEN psm.unearned_type = 288 THEN 'prepayment'
        WHEN psm.unearned_type = 439 THEN 'treatment_plan_prepayment'
        ELSE 'unknown_type'
    END as payment_type,
    
    -- Enhanced Insurance Payment Validation
    ia.estimate_accuracy,
    ia.significant_overpayment,
    CASE 
        WHEN ia.InsPayAmt IS NOT NULL AND ia.InsPayEst IS NOT NULL 
        THEN ABS(ia.InsPayAmt - ia.InsPayEst) / NULLIF(ia.InsPayEst, 0) 
        ELSE NULL 
    END as insurance_estimate_variance,
    
    -- Enhanced Payment Validation Status
    CASE
        WHEN pv.validation_status = 'insurance_overpaid' 
            AND ia.significant_overpayment = 1 THEN 'investigate_overpayment'
        WHEN psm.split_pattern = 'review_needed' THEN 'review_split_pattern'
        WHEN pl.ProcFee = 0 THEN 'zero_fee_valid'
        WHEN psm.unearned_type IN (288, 439) THEN 'prepayment_valid'
        WHEN pv.validation_status = 'exactly_covered' 
            AND psm.split_pattern = 'normal_split' THEN 'standard_valid'
        WHEN adj.adj_count > 0 AND pv.payment_success = 0 THEN 'adjustment_review_needed'
        WHEN psm.split_pattern = 'complex_split' AND pv.payment_success = 1 THEN 'successful_complex_split'
        WHEN pl.ProcFee = 0 AND pl.CodeNum NOT IN (SELECT CodeNum FROM ExcludedCodes) THEN 'bundled_procedure'
        ELSE pv.validation_status
    END as enhanced_validation_status,
    
    -- Refined Journey Success Definition
    CASE
        WHEN js.journey_stage = 'completed' 
        AND pl.CodeNum NOT IN (626, 627)  -- Not a cancellation
        AND (
            -- Zero fee success path
            pl.ProcFee = 0
            OR
            -- Non-insurance success path
            (CASE WHEN pat.HasIns != '' THEN 1 ELSE 0 END = 0 
             AND psm.split_pattern = 'normal_split'
             AND COALESCE(psm.total_paid, 0) + COALESCE(adj.total_adjustments, 0) >= pl.ProcFee)
            OR
            -- Insurance success path
            (CASE WHEN pat.HasIns != '' THEN 1 ELSE 0 END = 1 
             AND cp.Status = 1  -- Active claim
             AND cp.InsPayAmt IS NOT NULL
             AND (
                 -- Full insurance coverage
                 cp.InsPayAmt >= pl.ProcFee
                 OR
                 -- Partial coverage with valid split
                 (cp.InsPayAmt + COALESCE(psm.total_paid, 0) + COALESCE(adj.total_adjustments, 0) >= pl.ProcFee
                  AND psm.split_pattern = 'normal_split')
             )
             AND CASE WHEN cp.InsPayAmt > cp.InsPayEst * 1.1 THEN 1 ELSE 0 END = 0  -- No significant overpayment
            )
        )
        THEN 1
        ELSE 0
    END as refined_journey_success,

    psm.total_paid

FROM FilteredProcs pl
JOIN patient pat ON pl.PatNum = pat.PatNum
LEFT JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
LEFT JOIN fee f ON f.CodeNum = pl.CodeNum
LEFT JOIN ClaimProcSummary cp ON pl.ProcNum = cp.ProcNum
LEFT JOIN AdjustmentSummary adj ON pl.ProcNum = adj.ProcNum
LEFT JOIN HistoricalMetrics hm ON pl.CodeNum = hm.CodeNum AND pl.PatNum = hm.PatNum
LEFT JOIN CategoryMetrics cm ON pl.CodeNum = cm.CodeNum
LEFT JOIN HistoricalFees hf ON pl.CodeNum = hf.CodeNum AND pl.ProvNum = hf.ProvNum
LEFT JOIN PatientHistory ph ON pl.PatNum = ph.PatNum
LEFT JOIN PaymentValidation pv ON pl.ProcNum = pv.ProcNum
LEFT JOIN PaymentSplitMetrics psm ON pl.ProcNum = psm.ProcNum
LEFT JOIN InsuranceAccuracy ia ON pl.ProcNum = ia.ProcNum
LEFT JOIN JourneyStage js ON pl.ProcNum = js.ProcNum

GROUP BY pl.ProcNum
ORDER BY pl.ProcDate DESC;