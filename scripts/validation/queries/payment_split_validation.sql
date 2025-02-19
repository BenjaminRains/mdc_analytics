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
        STRING_AGG(CAST(payment_sequence AS VARCHAR), ',' ORDER BY payment_sequence) as payment_sequence_pattern,
        CASE 
            WHEN COUNT(*) BETWEEN 1 AND 3 THEN 'normal_split'
            WHEN COUNT(*) BETWEEN 4 AND 15 THEN 'complex_split'
            WHEN COUNT(*) > 15 THEN 'review_needed'
            ELSE 'no_splits'
        END as split_pattern
    FROM ProcedurePayments
    GROUP BY ProcNum
)

SELECT 
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
    STRING_AGG(DISTINCT spa.payment_sequence_pattern, '; ') 
        FILTER (WHERE spa.split_count > 3) as complex_payment_patterns,
    
    -- Payment Amount Analysis
    AVG(pp.ProcFee) as avg_procedure_fee,
    AVG(spa.total_paid) as avg_total_paid,
    COUNT(CASE WHEN spa.total_paid > pp.ProcFee THEN 1 END) as overpayment_count,
    
    -- Unearned Type Analysis
    COUNT(CASE WHEN pp.UnearnedType = 0 THEN 1 END) as regular_payment_count,
    COUNT(CASE WHEN pp.UnearnedType = 288 THEN 1 END) as prepayment_count,
    COUNT(CASE WHEN pp.UnearnedType = 439 THEN 1 END) as treatment_plan_prepayment_count

FROM PaymentSummary ps
LEFT JOIN ProcedurePayments pp ON ps.PayNum = pp.PayNum
LEFT JOIN SplitPatternAnalysis spa ON pp.ProcNum = spa.ProcNum
WHERE pp.ProcNum IS NOT NULL  -- Only include payments linked to procedures

UNION ALL

-- Detailed analysis of problematic cases
SELECT *
FROM (
    -- Payments with split mismatches
    SELECT 
        ps.PayNum,
        ps.PayAmt,
        ps.split_count,
        ps.total_split_amount,
        ps.split_difference,
        pp.ProcNum,
        pp.ProcFee,
        spa.payment_sequence_pattern,
        spa.split_pattern
    FROM PaymentSummary ps
    JOIN ProcedurePayments pp ON ps.PayNum = pp.PayNum
    JOIN SplitPatternAnalysis spa ON pp.ProcNum = spa.ProcNum
    WHERE ps.split_difference > 0.01
        OR spa.split_pattern = 'review_needed'
        OR spa.total_paid > pp.ProcFee
    ORDER BY ps.split_difference DESC, spa.split_count DESC
    LIMIT 100
) problem_cases;