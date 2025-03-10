{% include "payment_base.sql" %}
-- Payment-level analytics CTE that aggregates split-level data into payment-level metrics
-- Provides one row per payment with calculated metrics about associated splits, claims, and procedures
-- Used for payment reconciliation, split analysis, and payment pattern identification
-- Refactored from original PaymentDetailsMetrics to build upon PaymentBase foundation
PaymentLevelAnalytics AS (
    SELECT 
        PayNum,
        PayDate,
        PayType,
        PayAmt,
        PayNote,
        payment_source,
        payment_method,
        COUNT(SplitNum) as splits_count,
        COUNT(DISTINCT ClaimNum) as claims_count,
        COUNT(DISTINCT ProcNum) as procedures_count,
        MIN(SplitAmt) as min_split_amount,
        MAX(SplitAmt) as max_split_amount,
        SUM(SplitAmt) as total_split_amount,
        ABS(PayAmt - COALESCE(SUM(SplitAmt), 0)) as split_difference
    FROM PaymentBase
    GROUP BY PayNum, PayDate, PayType, PayAmt, PayNote, payment_source, payment_method
)