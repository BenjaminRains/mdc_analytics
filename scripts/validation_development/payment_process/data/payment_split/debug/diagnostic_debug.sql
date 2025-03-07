WITH RECURSIVE PaymentJoinDiagnostics AS (
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
SELECT 
    'diagnostic_correlation' as report_type,
    filter_reason,
    COUNT (*) as payment_count,
    AVG (split_count) as avg_splits,
    ROUND (AVG (split_count * 1.0 / NULLIF (proc_count, 0)), 2) as avg_splits_per_proc,
    SUM (has_multiple_splits_per_proc) as complex_split_count,
    SUM (has_multiple_splits_per_proc) * 100.0 / NULLIF (COUNT (*), 0) as pct_complex,
    SUM (is_large_payment) as large_payment_count,
    SUM (is_large_payment) * 100.0 / NULLIF (COUNT (*), 0) as pct_large,
    SUM (is_simple_payment) as simple_payment_count,
    SUM (is_simple_payment) * 100.0 / NULLIF (COUNT (*), 0) as pct_simple,
    SUM (has_high_split_ratio) as high_ratio_count,
    SUM (has_high_split_ratio) * 100.0 / NULLIF (COUNT (*), 0) as pct_high_ratio,
    SUM (has_oversplit_claims) as oversplit_claim_count,
    SUM (has_oversplit_claims) * 100.0 / NULLIF (COUNT (*), 0) as pct_oversplit
FROM PaymentFilterDiagnostics
GROUP BY filter_reason
ORDER BY payment_count DESC;