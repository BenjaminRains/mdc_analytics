/*
 * Treatment Journey Target Validation
 * Tests various hypotheses about success criteria and payment patterns
 */

WITH ExcludedCodes AS (
    SELECT CodeNum 
    FROM procedurecode 
    WHERE ProcCode IN (
        -- Administrative/Documentation
        '~GRP~', 'D9987', 'D9986',  -- Notes and cancellations
        'Watch', 'Ztoth',           -- Monitoring
        'D0350',                    -- Photos
        '00040', 'D2919',          -- Post-proc
        '00051',                    -- Scans
        -- Patient Management
        'D9992',                    -- Care coordination
        'D9995', 'D9996',          -- Teledentistry
        -- Evaluations/Exams
        'D0190',                    -- Screening
        'D0171',                    -- Re-evaluation
        'D0140',                    -- Limited eval
        'D9430',                    -- Office visit
        'D0120'                     -- Periodic eval
    )
),

PaymentActivity AS (
    -- Calculate total payments and adjustments per procedure
    SELECT 
        pl.ProcNum,
        pl.ProcFee,
        COALESCE(SUM(cp.InsPayAmt), 0) as insurance_paid,
        COALESCE(SUM(ps.SplitAmt), 0) as direct_paid,
        COALESCE(SUM(adj.AdjAmt), 0) as adjustments,
        COALESCE(SUM(cp.InsPayAmt), 0) + COALESCE(SUM(ps.SplitAmt), 0) as total_paid
    FROM procedurelog pl
    LEFT JOIN claimproc cp ON pl.ProcNum = cp.ProcNum AND cp.InsPayAmt > 0
    LEFT JOIN paysplit ps ON pl.ProcNum = ps.ProcNum AND ps.SplitAmt > 0
    LEFT JOIN adjustment adj ON pl.ProcNum = adj.ProcNum
    GROUP BY pl.ProcNum, pl.ProcFee
),

PaymentSplitMetrics AS (
    SELECT 
        ps.ProcNum,
        COUNT(*) as split_count,
        CASE 
            WHEN COUNT(*) BETWEEN 1 AND 3 THEN 'normal_split'
            WHEN COUNT(*) BETWEEN 4 AND 15 THEN 'complex_split'
            ELSE 'review_needed'
        END as split_pattern
    FROM paysplit ps
    GROUP BY ps.ProcNum
),

ThresholdTests AS (
    SELECT 
        pl.ProcNum,
        pl.ProcFee,
        COALESCE(pa.total_paid, 0) as total_paid,
        COALESCE(pa.total_paid, 0) / NULLIF(pl.ProcFee, 0) as payment_ratio,
        -- Test different thresholds
        CASE 
            WHEN pl.ProcFee = 0 THEN 'zero_fee'
            WHEN COALESCE(pa.total_paid, 0) / NULLIF(pl.ProcFee, 0) >= 0.98 THEN 'strict_98'
            WHEN COALESCE(pa.total_paid, 0) / NULLIF(pl.ProcFee, 0) >= 0.95 THEN 'current_95'
            WHEN COALESCE(pa.total_paid, 0) / NULLIF(pl.ProcFee, 0) >= 0.90 THEN 'lenient_90'
            ELSE 'below_90'
        END as threshold_category,
        -- Define success criteria
        CASE 
            WHEN pl.ProcStatus = 2  -- Completed
                AND (
                    -- Zero-fee success
                    (pl.ProcFee = 0 AND pl.CodeNum NOT IN (SELECT CodeNum FROM ExcludedCodes))
                    OR 
                    -- Paid procedure success
                    (pl.ProcFee > 0 AND COALESCE(pa.total_paid, 0) / NULLIF(pl.ProcFee, 0) >= 0.95)
                ) THEN 1
            ELSE 0
        END as target_journey_success,
        -- Include payment_ratio for output
        COALESCE(pa.total_paid, 0) / NULLIF(pl.ProcFee, 0) as payment_ratio_output
    FROM procedurelog pl
    LEFT JOIN PaymentActivity pa ON pl.ProcNum = pa.ProcNum
    WHERE pl.ProcDate >= '2023-01-01'
)

-- Output 1: Threshold Analysis
SELECT 
    threshold_category,
    COUNT(*) as case_count,
    AVG(target_journey_success * 1.0) as current_success_rate,
    AVG(payment_ratio_output) as avg_payment_ratio,
    COUNT(CASE WHEN payment_ratio_output > 1 THEN 1 END) as overpayment_count
FROM ThresholdTests
GROUP BY threshold_category
ORDER BY 
    CASE threshold_category 
        WHEN 'zero_fee' THEN 1
        WHEN 'below_90' THEN 2
        WHEN 'lenient_90' THEN 3
        WHEN 'current_95' THEN 4
        WHEN 'strict_98' THEN 5
    END;

-- Output 2: Payment Pattern Analysis
WITH ExcludedCodes AS (
    SELECT CodeNum 
    FROM procedurecode 
    WHERE ProcCode IN (
        -- Administrative/Documentation
        '~GRP~', 'D9987', 'D9986',  -- Notes and cancellations
        'Watch', 'Ztoth',           -- Monitoring
        'D0350',                    -- Photos
        '00040', 'D2919',          -- Post-proc
        '00051',                    -- Scans
        -- Patient Management
        'D9992',                    -- Care coordination
        'D9995', 'D9996',          -- Teledentistry
        -- Evaluations/Exams
        'D0190',                    -- Screening
        'D0171',                    -- Re-evaluation
        'D0140',                    -- Limited eval
        'D9430',                    -- Office visit
        'D0120'                     -- Periodic eval
    )
),
PaymentActivity AS (
    -- Calculate total payments and adjustments per procedure
    SELECT 
        pl.ProcNum,
        pl.ProcFee,
        COALESCE(SUM(cp.InsPayAmt), 0) as insurance_paid,
        COALESCE(SUM(ps.SplitAmt), 0) as direct_paid,
        COALESCE(SUM(adj.AdjAmt), 0) as adjustments,
        COALESCE(SUM(cp.InsPayAmt), 0) + COALESCE(SUM(ps.SplitAmt), 0) as total_paid
    FROM procedurelog pl
    LEFT JOIN claimproc cp ON pl.ProcNum = cp.ProcNum AND cp.InsPayAmt > 0
    LEFT JOIN paysplit ps ON pl.ProcNum = ps.ProcNum AND ps.SplitAmt > 0
    LEFT JOIN adjustment adj ON pl.ProcNum = adj.ProcNum
    GROUP BY pl.ProcNum, pl.ProcFee
),
PaymentSplitMetrics AS (
    SELECT 
        ps.ProcNum,
        COUNT(*) as split_count,
        CASE 
            WHEN COUNT(*) BETWEEN 1 AND 3 THEN 'normal_split'
            WHEN COUNT(*) BETWEEN 4 AND 15 THEN 'complex_split'
            ELSE 'review_needed'
        END as split_pattern
    FROM paysplit ps
    GROUP BY ps.ProcNum
),
PaymentPatterns AS (
    SELECT 
        pl.ProcNum,
        CASE
            WHEN pl.ProcFee = 0 AND pl.CodeNum IN (SELECT CodeNum FROM ExcludedCodes) THEN 'administrative_zero_fee'
            WHEN pl.ProcFee = 0 THEN 'clinical_zero_fee'
            WHEN COALESCE(pa.total_paid, 0) = 0 THEN 'no_payment'
            WHEN COALESCE(pa.insurance_paid, 0) > 0 AND COALESCE(pa.direct_paid, 0) = 0 THEN 'insurance_only'
            WHEN COALESCE(pa.insurance_paid, 0) = 0 AND COALESCE(pa.direct_paid, 0) > 0 THEN 'direct_only'
            ELSE 'both_payment_types'
        END as payment_category,
        psm.split_pattern,
        -- Define success criteria
        CASE 
            WHEN pl.ProcStatus = 2  -- Completed
                AND (
                    -- Zero-fee success
                    (pl.ProcFee = 0 AND pl.CodeNum NOT IN (SELECT CodeNum FROM ExcludedCodes))
                    OR 
                    -- Paid procedure success
                    (pl.ProcFee > 0 AND COALESCE(pa.total_paid, 0) / NULLIF(pl.ProcFee, 0) >= 0.95)
                ) THEN 1
            ELSE 0
        END as target_journey_success
    FROM procedurelog pl
    LEFT JOIN PaymentActivity pa ON pl.ProcNum = pa.ProcNum
    LEFT JOIN PaymentSplitMetrics psm ON pl.ProcNum = psm.ProcNum
)
SELECT 
    payment_category,
    split_pattern,
    COUNT(*) as case_count,
    AVG(target_journey_success * 1.0) as success_rate
FROM PaymentPatterns
GROUP BY payment_category, split_pattern
ORDER BY payment_category, split_pattern;

-- Output 3: Bundled Procedure Analysis
WITH ExcludedCodes AS (
    SELECT CodeNum 
    FROM procedurecode 
    WHERE ProcCode IN (
        -- Administrative/Documentation
        '~GRP~', 'D9987', 'D9986',  -- Notes and cancellations
        'Watch', 'Ztoth',           -- Monitoring
        'D0350',                    -- Photos
        '00040', 'D2919',          -- Post-proc
        '00051',                    -- Scans
        -- Patient Management
        'D9992',                    -- Care coordination
        'D9995', 'D9996',          -- Teledentistry
        -- Evaluations/Exams
        'D0190',                    -- Screening
        'D0171',                    -- Re-evaluation
        'D0140',                    -- Limited eval
        'D9430',                    -- Office visit
        'D0120'                     -- Periodic eval
    )
),
PaymentActivity AS (
    -- Calculate total payments and adjustments per procedure
    SELECT 
        pl.ProcNum,
        pl.ProcFee,
        COALESCE(SUM(cp.InsPayAmt), 0) as insurance_paid,
        COALESCE(SUM(ps.SplitAmt), 0) as direct_paid,
        COALESCE(SUM(adj.AdjAmt), 0) as adjustments,
        COALESCE(SUM(cp.InsPayAmt), 0) + COALESCE(SUM(ps.SplitAmt), 0) as total_paid
    FROM procedurelog pl
    LEFT JOIN claimproc cp ON pl.ProcNum = cp.ProcNum AND cp.InsPayAmt > 0
    LEFT JOIN paysplit ps ON pl.ProcNum = ps.ProcNum AND ps.SplitAmt > 0
    LEFT JOIN adjustment adj ON pl.ProcNum = adj.ProcNum
    GROUP BY pl.ProcNum, pl.ProcFee
),
BundledProcedures AS (
    SELECT 
        pl1.ProcNum as zero_fee_proc,
        pl2.ProcNum as paid_proc,
        pl1.ProcDate,
        pl1.PatNum,
        pl2.ProcFee as related_fee,
        CASE 
            WHEN pl2.ProcStatus = 2  -- Completed
                AND (pl2.ProcFee > 0 AND COALESCE(pa.total_paid, 0) / NULLIF(pl2.ProcFee, 0) >= 0.95)
            THEN 1
            ELSE 0
        END as related_success
    FROM procedurelog pl1
    JOIN procedurelog pl2 
        ON pl1.PatNum = pl2.PatNum 
        AND pl1.ProcDate = pl2.ProcDate
        AND pl1.ProcFee = 0 
        AND pl2.ProcFee > 0
    LEFT JOIN PaymentActivity pa ON pl2.ProcNum = pa.ProcNum
)
SELECT 
    COUNT(DISTINCT zero_fee_proc) as zero_fee_count,
    COUNT(DISTINCT paid_proc) as related_paid_count,
    AVG(related_success * 1.0) as related_success_rate,
    AVG(related_fee) as avg_related_fee
FROM BundledProcedures;

-- Output 4: Adjustment Pattern Impact
WITH ExcludedCodes AS (
    SELECT CodeNum 
    FROM procedurecode 
    WHERE ProcCode IN (
        -- Administrative/Documentation
        '~GRP~', 'D9987', 'D9986',  -- Notes and cancellations
        'Watch', 'Ztoth',           -- Monitoring
        'D0350',                    -- Photos
        '00040', 'D2919',          -- Post-proc
        '00051',                    -- Scans
        -- Patient Management
        'D9992',                    -- Care coordination
        'D9995', 'D9996',          -- Teledentistry
        -- Evaluations/Exams
        'D0190',                    -- Screening
        'D0171',                    -- Re-evaluation
        'D0140',                    -- Limited eval
        'D9430',                    -- Office visit
        'D0120'                     -- Periodic eval
    )
),
PaymentActivity AS (
    -- Calculate total payments and adjustments per procedure
    SELECT 
        pl.ProcNum,
        pl.ProcFee,
        COALESCE(SUM(cp.InsPayAmt), 0) as insurance_paid,
        COALESCE(SUM(ps.SplitAmt), 0) as direct_paid,
        COALESCE(SUM(adj.AdjAmt), 0) as adjustments,
        COALESCE(SUM(cp.InsPayAmt), 0) + COALESCE(SUM(ps.SplitAmt), 0) as total_paid
    FROM procedurelog pl
    LEFT JOIN claimproc cp ON pl.ProcNum = cp.ProcNum AND cp.InsPayAmt > 0
    LEFT JOIN paysplit ps ON pl.ProcNum = ps.ProcNum AND ps.SplitAmt > 0
    LEFT JOIN adjustment adj ON pl.ProcNum = adj.ProcNum
    GROUP BY pl.ProcNum, pl.ProcFee
),
AdjustmentPatterns AS (
    SELECT 
        pl.ProcNum,
        COUNT(DISTINCT adj.AdjType) as unique_adj_types,
        SUM(CASE WHEN adj.AdjAmt < 0 THEN 1 ELSE 0 END) as negative_adj_count,
        SUM(CASE WHEN adj.AdjAmt > 0 THEN 1 ELSE 0 END) as positive_adj_count,
        COALESCE(SUM(adj.AdjAmt), 0) as total_adjustment,
        CASE 
            WHEN pl.ProcStatus = 2  -- Completed
                AND (
                    -- Zero-fee success
                    (pl.ProcFee = 0 AND pl.CodeNum NOT IN (SELECT CodeNum FROM ExcludedCodes))
                    OR 
                    -- Paid procedure success
                    (pl.ProcFee > 0 AND COALESCE(pa.total_paid, 0) / NULLIF(pl.ProcFee, 0) >= 0.95)
                ) THEN 1
            ELSE 0
        END as target_journey_success
    FROM procedurelog pl
    LEFT JOIN adjustment adj ON pl.ProcNum = adj.ProcNum
    LEFT JOIN PaymentActivity pa ON pl.ProcNum = pa.ProcNum
    GROUP BY pl.ProcNum, pl.ProcStatus, pl.ProcFee, pl.CodeNum
)
SELECT 
    CASE 
        WHEN total_adjustment = 0 THEN 'no_adjustments'
        WHEN total_adjustment < 0 THEN 'net_negative'
        ELSE 'net_positive'
    END as adjustment_category,
    COUNT(*) as case_count,
    AVG(target_journey_success * 1.0) as success_rate,
    AVG(unique_adj_types) as avg_adjustment_types,
    AVG(negative_adj_count) as avg_negative_adjustments,
    AVG(positive_adj_count) as avg_positive_adjustments
FROM AdjustmentPatterns
GROUP BY 
    CASE 
        WHEN total_adjustment = 0 THEN 'no_adjustments'
        WHEN total_adjustment < 0 THEN 'net_negative'
        ELSE 'net_positive'
    END;

-- Output 5: Edge Cases
WITH ExcludedCodes AS (
    SELECT CodeNum 
    FROM procedurecode 
    WHERE ProcCode IN (
        -- Administrative/Documentation
        '~GRP~', 'D9987', 'D9986',  -- Notes and cancellations
        'Watch', 'Ztoth',           -- Monitoring
        'D0350',                    -- Photos
        '00040', 'D2919',          -- Post-proc
        '00051',                    -- Scans
        -- Patient Management
        'D9992',                    -- Care coordination
        'D9995', 'D9996',          -- Teledentistry
        -- Evaluations/Exams
        'D0190',                    -- Screening
        'D0171',                    -- Re-evaluation
        'D0140',                    -- Limited eval
        'D9430',                    -- Office visit
        'D0120'                     -- Periodic eval
    )
),
PaymentActivity AS (
    -- Calculate total payments and adjustments per procedure
    SELECT 
        pl.ProcNum,
        pl.ProcFee,
        COALESCE(SUM(cp.InsPayAmt), 0) as insurance_paid,
        COALESCE(SUM(ps.SplitAmt), 0) as direct_paid,
        COALESCE(SUM(adj.AdjAmt), 0) as adjustments,
        COALESCE(SUM(cp.InsPayAmt), 0) + COALESCE(SUM(ps.SplitAmt), 0) as total_paid
    FROM procedurelog pl
    LEFT JOIN claimproc cp ON pl.ProcNum = cp.ProcNum AND cp.InsPayAmt > 0
    LEFT JOIN paysplit ps ON pl.ProcNum = ps.ProcNum AND ps.SplitAmt > 0
    LEFT JOIN adjustment adj ON pl.ProcNum = adj.ProcNum
    GROUP BY pl.ProcNum, pl.ProcFee
),
ThresholdTests AS (
    SELECT 
        pl.ProcNum,
        pl.ProcFee,
        COALESCE(pa.total_paid, 0) as total_paid,
        COALESCE(pa.total_paid, 0) / NULLIF(pl.ProcFee, 0) as payment_ratio,
        CASE 
            WHEN pl.ProcStatus = 2  -- Completed
                AND (
                    -- Zero-fee success
                    (pl.ProcFee = 0 AND pl.CodeNum NOT IN (SELECT CodeNum FROM ExcludedCodes))
                    OR 
                    -- Paid procedure success
                    (pl.ProcFee > 0 AND COALESCE(pa.total_paid, 0) / NULLIF(pl.ProcFee, 0) >= 0.95)
                ) THEN 1
            ELSE 0
        END as target_journey_success,
        COALESCE(pa.total_paid, 0) / NULLIF(pl.ProcFee, 0) as payment_ratio_output
    FROM procedurelog pl
    LEFT JOIN PaymentActivity pa ON pl.ProcNum = pa.ProcNum
    WHERE pl.ProcDate >= '2023-01-01'
)
SELECT 
    'High ratio failures' as case_type,
    COUNT(*) as case_count
FROM ThresholdTests
WHERE payment_ratio_output >= 0.95 
    AND target_journey_success = 0
UNION ALL
SELECT 
    'Low ratio successes' as case_type,
    COUNT(*) as case_count
FROM ThresholdTests
WHERE payment_ratio_output < 0.95 
    AND target_journey_success = 1;