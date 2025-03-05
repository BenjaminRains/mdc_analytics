-- SplitPatternAnalysis: Analyze and categorize payment split patterns.
-- depends on: ProcedurePayments
-- Date filter: Uses @start_date to @end_date
SplitPatternAnalysis AS (
    SELECT 
        ProcNum,
        COUNT(DISTINCT PayNum) AS payment_count,
        COUNT(*) AS split_count,
        SUM(SplitAmt) AS total_paid,
        AVG(days_to_payment) AS avg_days_to_payment,
        CASE 
            WHEN COUNT(*) = 1 THEN 'single_payment'
            WHEN COUNT(*) = 2 THEN 'double_payment'
            WHEN COUNT(*) BETWEEN 3 AND 5 THEN 'multiple_payment'
            WHEN COUNT(*) BETWEEN 6 AND 15 THEN 'complex_payment'
            ELSE 'review_needed'
        END AS split_pattern,
        MIN(days_to_payment) AS first_payment_days,
        MAX(days_to_payment) AS last_payment_days,
        DATEDIFF(MAX(PayDate), MIN(PayDate)) AS payment_span_days,
        MIN(SplitAmt) AS min_split_amount,
        MAX(SplitAmt) AS max_split_amount,
        CASE WHEN COUNT(*) > COUNT(DISTINCT PayNum) * 2 THEN 1 ELSE 0 END AS has_multiple_splits_per_payment,
        CASE WHEN MAX(days_to_payment) - MIN(days_to_payment) > 365 THEN 1 ELSE 0 END AS is_long_term_payment,
        GROUP_CONCAT(
            DISTINCT 
            CASE payment_sequence 
                WHEN 1 THEN 'First' 
                WHEN 2 THEN 'Second' 
                WHEN 3 THEN 'Third' 
                WHEN 4 THEN 'Fourth'
                WHEN 5 THEN 'Fifth'
                ELSE CONCAT(payment_sequence) 
            END
            ORDER BY payment_sequence
            SEPARATOR ' > '
        ) AS payment_sequence_pattern
    FROM ProcedurePayments
    GROUP BY ProcNum
)