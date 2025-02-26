-- JoinStageCounts: Analyze payment progression through join stages and related metrics.
-- depends on: PaymentBaseCounts, PaymentJoinDiagnostics, PaymentSummary
-- Date filter: 2024-01-01 to 2025-01-01
JoinStageCounts AS (
    SELECT 
        pbc.total_payments as base_count,
        COUNT(DISTINCT CASE WHEN pjd.join_status != 'No Splits' THEN pjd.PayNum END) as with_splits,
        COUNT(DISTINCT CASE WHEN pjd.join_status NOT IN ('No Splits', 'No Procedures') THEN pjd.PayNum END) as with_procedures,
        COUNT(DISTINCT CASE WHEN pjd.join_status = 'Complete' THEN pjd.PayNum END) as with_insurance,
        COUNT(DISTINCT CASE WHEN pjd.join_status = 'No Insurance' AND pjd.PayAmt > 0 THEN pjd.PayNum END) as patient_payments,
        COUNT(DISTINCT CASE WHEN pjd.join_status = 'No Procedures' AND pjd.PayAmt = 0 THEN pjd.PayNum END) as transfer_count,
        COUNT(DISTINCT CASE WHEN pjd.join_status = 'No Procedures' AND pjd.PayAmt < 0 THEN pjd.PayNum END) as refund_count,
        AVG(ps.split_count) as avg_splits_per_payment,
        COUNT(DISTINCT CASE WHEN ps.split_difference > 0.01 THEN ps.PayNum END) as mismatch_count,
        COUNT(DISTINCT CASE WHEN pjd.split_count > 15 THEN pjd.PayNum END) as high_split_count,
        COUNT(DISTINCT CASE WHEN pjd.split_count = 1 THEN pjd.PayNum END) as single_split_count,
        COUNT(DISTINCT CASE WHEN pjd.PayAmt > 5000 THEN pjd.PayNum END) as large_payment_count
    FROM PaymentBaseCounts pbc
    CROSS JOIN PaymentJoinDiagnostics pjd
    LEFT JOIN PaymentSummary ps ON pjd.PayNum = ps.PayNum
    GROUP BY pbc.total_payments
)