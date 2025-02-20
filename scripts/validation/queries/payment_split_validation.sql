-- Payment and PaySplit Validation Query
-- Validates payment patterns, split integrity, and payment success criteria

WITH PaymentSummary AS (
    -- Get all payments and their total splits
    SELECT 
        p.PayNum,
        p.PayAmt,
        p.PayDate,
        COUNT(ps.SplitNum) as split_count,
        SUM(ps.SplitAmt) as total_split_amount,
        ABS(p.PayAmt - SUM(ps.SplitAmt)) as split_difference
    FROM payment p
    LEFT JOIN paysplit ps ON p.PayNum = ps.PayNum
    GROUP BY p.PayNum, p.PayAmt, p.PayDate
),
ProcedurePayments AS (
    -- Link payments to procedures and validate amounts
    SELECT 
        pl.ProcNum,
        pl.ProcFee,
        pl.ProcStatus,
        pl.CodeNum,
        ps.PayNum,
        ps.SplitAmt,
        p.PayAmt,
        p.PayDate,
        ps.UnearnedType,
        ROW_NUMBER() OVER (PARTITION BY pl.ProcNum ORDER BY p.PayDate) as payment_sequence
    FROM procedurelog pl
    JOIN paysplit ps ON pl.ProcNum = ps.ProcNum
    JOIN payment p ON ps.PayNum = p.PayNum
    WHERE pl.ProcDate >= '2023-01-01'
        AND pl.ProcDate < '2024-01-01'
),
SplitPatternAnalysis AS (
    -- Analyze split patterns per procedure
    SELECT 
        ProcNum,
        COUNT(DISTINCT PayNum) as payment_count,
        COUNT(*) as split_count,
        SUM(SplitAmt) as total_paid,
        GROUP_CONCAT(payment_sequence ORDER BY payment_sequence) as payment_sequence_pattern,
        CASE 
            WHEN COUNT(*) BETWEEN 1 AND 3 THEN 'normal_split'
            WHEN COUNT(*) BETWEEN 4 AND 15 THEN 'complex_split'
            WHEN COUNT(*) > 15 THEN 'review_needed'
            ELSE 'no_splits'
        END as split_pattern
    FROM ProcedurePayments
    GROUP BY ProcNum
)

SELECT * FROM (
    -- Main Summary Query
    SELECT 
        'summary' as report_type,
        -- Payment Summary Statistics
        COUNT(DISTINCT ps.PayNum) as total_payments,
        AVG(ps.split_count) as avg_splits_per_payment,
        SUM(CASE WHEN ps.split_difference > 0.01 THEN 1 ELSE 0 END) as payments_with_split_mismatch,
        
        -- Split Pattern Distribution
        COUNT(CASE WHEN spa.split_pattern = 'normal_split' THEN 1 END) as normal_split_count,
        COUNT(CASE WHEN spa.split_pattern = 'complex_split' THEN 1 END) as complex_split_count,
        COUNT(CASE WHEN spa.split_pattern = 'review_needed' THEN 1 END) as review_needed_count,
        
        -- Payment Sequence Analysis
        MAX(spa.payment_count) as max_payments_per_procedure,
        AVG(spa.payment_count) as avg_payments_per_procedure,
        
        -- Common Payment Sequence Patterns
        GROUP_CONCAT(DISTINCT 
            CASE WHEN spa.split_count > 3 
            THEN spa.payment_sequence_pattern 
            END
        ) as complex_payment_patterns,
        
        -- Payment Amount Analysis
        AVG(pp.ProcFee) as avg_procedure_fee,
        AVG(spa.total_paid) as avg_total_paid,
        COUNT(CASE WHEN spa.total_paid > pp.ProcFee THEN 1 END) as overpayment_count,
        
        -- Unearned Type Analysis
        COUNT(CASE WHEN pp.UnearnedType = 0 THEN 1 END) as regular_payment_count,
        COUNT(CASE WHEN pp.UnearnedType = 288 THEN 1 END) as prepayment_count,
        COUNT(CASE WHEN pp.UnearnedType = 439 THEN 1 END) as treatment_plan_prepayment_count,
        
        0 as split_difference,  -- Added for ordering
        0 as split_count       -- Added for ordering

    FROM PaymentSummary ps
    LEFT JOIN ProcedurePayments pp ON ps.PayNum = pp.PayNum
    LEFT JOIN SplitPatternAnalysis spa ON pp.ProcNum = spa.ProcNum
    WHERE pp.ProcNum IS NOT NULL  -- Only include payments linked to procedures

    UNION ALL

    -- Detailed Problem Cases
    SELECT 
        'problem_detail' as report_type,
        ps.PayNum as total_payments,
        ps.PayAmt as avg_splits_per_payment,
        ps.split_count as payments_with_split_mismatch,
        ps.total_split_amount as normal_split_count,
        ps.split_difference as complex_split_count,
        pp.ProcNum as review_needed_count,
        pp.ProcFee as max_payments_per_procedure,
        spa.payment_count as avg_payments_per_procedure,
        spa.payment_sequence_pattern as complex_payment_patterns,
        spa.split_pattern as avg_procedure_fee,
        spa.total_paid as avg_total_paid,
        CASE WHEN spa.total_paid > pp.ProcFee THEN 1 ELSE 0 END as overpayment_count,
        pp.UnearnedType as regular_payment_count,
        0 as prepayment_count,
        0 as treatment_plan_prepayment_count,
        ps.split_difference,  -- Added for ordering
        spa.split_count      -- Added for ordering

    FROM PaymentSummary ps
    JOIN ProcedurePayments pp ON ps.PayNum = pp.PayNum
    JOIN SplitPatternAnalysis spa ON pp.ProcNum = spa.ProcNum
    WHERE ps.split_difference > 0.01
        OR spa.split_pattern = 'review_needed'
        OR spa.total_paid > pp.ProcFee
    LIMIT 100
) combined_results
ORDER BY 
    report_type DESC,  -- Summary first, then details
    split_difference DESC,
    split_count DESC;