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
), PaymentFilterDiagnostics AS (
    SELECT 
        pd.PayNum,
        pd.PayAmt,
        pd.join_status,
        pd.split_count,
        pd.proc_count,
        CASE
            WHEN pd.PayAmt = 0 THEN 'Zero Amount'
            WHEN pd.split_count > 15 THEN 'High Split Count'
            WHEN pd.PayAmt < 0 THEN 'Reversal'
            WHEN pd.join_status = 'No Insurance' THEN 'No Insurance'
            WHEN pd.join_status = 'No Procedures' THEN 'No Procedures'
            ELSE 'Normal Payment'
        END as filter_reason,
        CASE WHEN pd.split_count > pd.proc_count * 2 THEN 1 ELSE 0 END as has_multiple_splits_per_proc,
        CASE WHEN pd.PayAmt > 5000 THEN 1 ELSE 0 END as is_large_payment,
        CASE WHEN pd.split_count = 1 AND pd.proc_count = 1 THEN 1 ELSE 0 END as is_simple_payment,
        CASE 
            WHEN split_count > 0 AND proc_count > 0 
                 AND (split_count * 1.0 / proc_count) > 10 
            THEN 1 ELSE 0 
        END as has_high_split_ratio,
        CASE 
            WHEN EXISTS (
                SELECT 1 
                FROM paysplit ps2 
                JOIN claimproc cp2 ON ps2.ProcNum = cp2.ProcNum
                WHERE ps2.PayNum = pd.PayNum
                GROUP BY cp2.ClaimNum
                HAVING COUNT (*) > 1000
            ) THEN 1 ELSE 0 
        END as has_oversplit_claims
    FROM PaymentJoinDiagnostics pd
)
SELECT * FROM (
    SELECT 
        'verification_counts' as report_type,
        'Total Base Payments' as metric,
        total_payments as payment_count,
        min_date,
        max_date
    FROM PaymentBaseCounts
    UNION ALL
    SELECT 
        'verification_counts' as report_type,
        CONCAT ('Join Status: ', join_status) as metric,
        COUNT (*) as payment_count,
        MIN (PayDate) as min_date,
        MAX (PayDate) as max_date
    FROM PaymentJoinDiagnostics
    GROUP BY join_status
    UNION ALL
    SELECT
        'verification_counts' as report_type,
        CONCAT ('Payment Type: ', CAST (PayType AS CHAR), ' (', 
               CASE 
                   WHEN PayType IN (417, 574, 634) THEN 'Insurance' 
                   WHEN PayType IN (69, 70, 71) THEN 'Check/Cash'
                   WHEN PayType IN (391, 412) THEN 'Card/Online'
                   WHEN PayType = 72 THEN 'Refund'
                   WHEN PayType = 0 THEN 'Transfer'
                   ELSE 'Other'
               END, ')') as metric,
        COUNT (*) as payment_count,
        MIN (PayDate) as min_date,
        MAX (PayDate) as max_date
    FROM PaymentLevelMetrics
    GROUP BY PayType
    UNION ALL
    SELECT
        'verification_counts' as report_type,
        CONCAT ('Filter: ', filter_reason) as metric,
        COUNT (*) as payment_count,
        MIN (pd.PayDate) as min_date,
        MAX (pd.PayDate) as max_date
    FROM PaymentFilterDiagnostics pfd
    JOIN PaymentJoinDiagnostics pd ON pfd.PayNum = pd.PayNum
    GROUP BY filter_reason
    UNION ALL
    SELECT
        'verification_counts' as report_type,
        'Discrepancy: Join vs Filter Missing Procedures' as metric,
        (SELECT COUNT (*) FROM PaymentJoinDiagnostics WHERE join_status = 'No Procedures') -
        (SELECT COUNT (*) FROM PaymentFilterDiagnostics WHERE filter_reason = 'No Procedures') as payment_count,
        NULL as min_date,
        NULL as max_date
    UNION ALL
    SELECT
        'verification_counts' as report_type,
        'Payments with Split Mismatches' as metric,
        COUNT (*) as payment_count,
        MIN (PayDate) as min_date,
        MAX (PayDate) as max_date
    FROM PaymentLevelMetrics
    WHERE split_difference > 0.01
) verification_metrics
ORDER BY 
    report_type,
    CASE 
        WHEN metric = 'Total Base Payments' THEN 0
        WHEN metric LIKE 'Filter:%' THEN 1
        WHEN metric LIKE 'Payment Type:%' THEN 2
        WHEN metric LIKE 'Join Status:%' THEN 3
        WHEN metric LIKE 'Discrepancy:%' THEN 4
        ELSE 5
    END,
    payment_count DESC;