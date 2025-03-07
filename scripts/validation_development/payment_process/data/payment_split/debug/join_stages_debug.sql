WITH RECURSIVE PaymentBaseCounts AS (
    SELECT 
        'base_counts' as metric,
        COUNT (DISTINCT p.PayNum) as total_payments,
        (SELECT COUNT (*) FROM paysplit ps2 
         JOIN payment p2 ON ps2.PayNum = p2.PayNum 
         WHERE p2.PayDate >= @start_date AND p2.PayDate < @end_date) as total_splits,
        (SELECT COUNT (DISTINCT pl2.ProcNum) 
         FROM procedurelog pl2 
         JOIN paysplit ps2 ON pl2.ProcNum = ps2.ProcNum
         JOIN payment p2 ON ps2.PayNum = p2.PayNum
         WHERE p2.PayDate >= @start_date AND p2.PayDate < @end_date) as total_procedures,
        SUM (p.PayAmt) as total_amount,
        AVG (p.PayAmt) as avg_payment,
        COUNT (CASE WHEN p.PayAmt < 0 THEN 1 END) as negative_payments,
        COUNT (CASE WHEN p.PayAmt = 0 THEN 1 END) as zero_payments,
        MIN (p.PayDate) as min_date,
        MAX (p.PayDate) as max_date,
        CAST ((SELECT COUNT (*) FROM paysplit ps2 
              JOIN payment p2 ON ps2.PayNum = p2.PayNum 
              WHERE p2.PayDate >= @start_date AND p2.PayDate < @end_date) AS FLOAT) / 
            COUNT (DISTINCT p.PayNum) as avg_splits_per_payment,
        (SELECT COUNT (DISTINCT pl2.ProcNum) 
         FROM procedurelog pl2 
         JOIN paysplit ps2 ON pl2.ProcNum = ps2.ProcNum
         JOIN payment p2 ON ps2.PayNum = p2.PayNum
         WHERE p2.PayDate >= @start_date AND p2.PayDate < @end_date) * 1.0 / 
            COUNT (DISTINCT p.PayNum) as avg_procedures_per_payment
    FROM payment p
    WHERE p.PayDate >= @start_date
      AND p.PayDate < @end_date
    GROUP BY 'base_counts'
), PaymentJoinDiagnostics AS (
    SELECT 
        p.PayNum,
        p.PayDate,
        p.PayAmt,
        p.PayType,
        CASE 
            WHEN NOT EXISTS (SELECT 1 FROM paysplit ps2 WHERE ps2.PayNum = p.PayNum) 
                THEN 'No Splits'
            WHEN NOT EXISTS (SELECT 1 FROM paysplit ps2 
                           JOIN procedurelog pl2 ON ps2.ProcNum = pl2.ProcNum 
                           WHERE ps2.PayNum = p.PayNum) 
                THEN 'No Procedures'
            WHEN NOT EXISTS (SELECT 1 FROM paysplit ps2 
                           JOIN claimproc cp2 ON ps2.ProcNum = cp2.ProcNum 
                           WHERE ps2.PayNum = p.PayNum AND cp2.InsPayAmt IS NOT NULL) 
                THEN 'No Insurance'
            ELSE 'Complete'
        END as join_status,
        COUNT (DISTINCT ps.SplitNum) as split_count,
        COUNT (DISTINCT pl.ProcNum) as proc_count
    FROM payment p
    LEFT JOIN paysplit ps ON p.PayNum = ps.PayNum
    LEFT JOIN procedurelog pl ON ps.ProcNum = pl.ProcNum
    WHERE p.PayDate >= @start_date
      AND p.PayDate < @end_date
    GROUP BY p.PayNum, p.PayDate, p.PayAmt, p.PayType
), PaymentLevelMetrics AS (
    SELECT 
        p.PayNum,
        p.PayAmt,
        p.PayDate,
        p.PayType,
        p.PayNote,
        COUNT (ps.SplitNum) AS split_count,
        SUM (ps.SplitAmt) AS total_split_amount,
        ABS (p.PayAmt - COALESCE (SUM (ps.SplitAmt), 0)) AS split_difference,
        CASE WHEN p.PayAmt < 0 THEN 1 ELSE 0 END AS is_reversal,
        CASE WHEN COUNT (ps.SplitNum) > 15 THEN 1 ELSE 0 END AS is_high_split,
        CASE WHEN p.PayAmt = 0 THEN 1 ELSE 0 END AS is_zero_amount,
        CASE WHEN p.PayAmt > 5000 THEN 1 ELSE 0 END AS is_large_payment,
        CASE WHEN COUNT (ps.SplitNum) = 1 THEN 1 ELSE 0 END AS is_single_split,
        CASE 
            WHEN p.PayType IN (417, 574, 634) THEN 'Insurance'
            WHEN p.PayType IN (69, 70, 71) THEN 'Check/Cash'
            WHEN p.PayType IN (391, 412) THEN 'Card/Online'
            WHEN p.PayType = 72 THEN 'Refund'
            WHEN p.PayType = 0 THEN 'Transfer'
            ELSE 'Other'
        END AS payment_category
    FROM payment p
    LEFT JOIN paysplit ps ON p.PayNum = ps.PayNum
    WHERE p.PayDate >= @start_date
      AND p.PayDate < @end_date
    GROUP BY p.PayNum, p.PayAmt, p.PayDate, p.PayType, p.PayNote
), JoinStageCounts AS (
    SELECT 
        pbc.total_payments as base_count,
        COUNT (DISTINCT CASE WHEN pjd.join_status != 'No Splits' THEN pjd.PayNum END) as with_splits,
        COUNT (DISTINCT CASE WHEN pjd.join_status NOT IN ('No Splits', 'No Procedures') THEN pjd.PayNum END) as with_procedures,
        COUNT (DISTINCT CASE WHEN pjd.join_status = 'Complete' THEN pjd.PayNum END) as with_insurance,
        COUNT (DISTINCT CASE WHEN pjd.join_status = 'No Insurance' AND pjd.PayAmt > 0 THEN pjd.PayNum END) as patient_payments,
        COUNT (DISTINCT CASE WHEN pjd.join_status = 'No Procedures' AND pjd.PayAmt = 0 THEN pjd.PayNum END) as transfer_count,
        COUNT (DISTINCT CASE WHEN pjd.join_status = 'No Procedures' AND pjd.PayAmt < 0 THEN pjd.PayNum END) as refund_count,
        AVG (ps.split_count) as avg_splits_per_payment,
        COUNT (DISTINCT CASE WHEN ps.split_difference > 0.01 THEN ps.PayNum END) as mismatch_count,
        COUNT (DISTINCT CASE WHEN pjd.split_count > 15 THEN pjd.PayNum END) as high_split_count,
        COUNT (DISTINCT CASE WHEN pjd.split_count = 1 THEN pjd.PayNum END) as single_split_count,
        COUNT (DISTINCT CASE WHEN pjd.PayAmt > 5000 THEN pjd.PayNum END) as large_payment_count
    FROM PaymentBaseCounts pbc
    CROSS JOIN PaymentJoinDiagnostics pjd
    LEFT JOIN PaymentLevelMetrics ps ON pjd.PayNum = ps.PayNum
    GROUP BY pbc.total_payments
)
SELECT 
    base_count,
    with_splits,
    with_procedures,
    with_insurance,
    patient_payments as valid_patient_payments,
    transfer_count as internal_transfers,
    refund_count as payment_refunds,
    base_count - with_splits as missing_splits,
    with_splits - with_procedures as unlinked_procedures,
    avg_splits_per_payment,
    mismatch_count as split_amount_mismatches,
    ROUND (with_insurance * 100.0 / base_count, 1) as pct_insurance,
    ROUND (patient_payments * 100.0 / base_count, 1) as pct_patient,
    ROUND (transfer_count * 100.0 / base_count, 1) as pct_transfer
FROM JoinStageCounts;