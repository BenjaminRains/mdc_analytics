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
), FilterStats AS (
    SELECT 
        filter_reason,
        COUNT (*) as payment_count,
        ROUND (COUNT (*) * 100.0 / SUM (COUNT (*)) OVER (), 1) as percentage,
        SUM (PayAmt) as total_amount,
        AVG (PayAmt) as avg_amount,
        SUM (has_multiple_splits_per_proc) as complex_split_count,
        SUM (is_large_payment) as large_payment_count,
        SUM (is_simple_payment) as simple_payment_count,
        SUM (has_high_split_ratio) as high_ratio_count,
        SUM (has_oversplit_claims) as oversplit_claim_count
    FROM PaymentFilterDiagnostics
    GROUP BY filter_reason
)
SELECT 
    fs.filter_reason,
    fs.payment_count,
    fs.percentage,
    fs.total_amount,
    fs.avg_amount,
    (SELECT AVG (split_count) FROM PaymentFilterDiagnostics WHERE filter_reason = fs.filter_reason) as avg_splits,
    (SELECT MIN (PayAmt) FROM PaymentFilterDiagnostics WHERE filter_reason = fs.filter_reason) as min_amount,
    (SELECT MAX (PayAmt) FROM PaymentFilterDiagnostics WHERE filter_reason = fs.filter_reason) as max_amount,
    CASE 
        WHEN fs.filter_reason = 'Zero Amount' AND fs.percentage != 13.1 
            THEN 'Unexpected: Should be 13.1%'
        WHEN fs.filter_reason = 'High Split Count' AND fs.percentage != 0.2 
            THEN 'Unexpected: Should be 0.2%'
        WHEN fs.filter_reason = 'Reversal' AND fs.percentage != 0.6 
            THEN 'Unexpected: Should be 0.6%'
        WHEN fs.filter_reason = 'No Insurance' AND fs.percentage != 38.8 
            THEN 'Unexpected: Should be 38.8%'
        WHEN fs.filter_reason = 'No Procedures' AND fs.percentage != 4.6 
            THEN 'Unexpected: Should be 4.6%'
        WHEN fs.filter_reason = 'Normal Payment' AND fs.percentage != 47.2 
            THEN 'Unexpected: Should be 47.2%'
        ELSE 'OK'
    END as validation_check,
    fs.complex_split_count,
    fs.large_payment_count,
    fs.simple_payment_count,
    fs.high_ratio_count,
    fs.oversplit_claim_count,
    'filter_validation' as report_type
FROM FilterStats fs
ORDER BY fs.payment_count DESC;