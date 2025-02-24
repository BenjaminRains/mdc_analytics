-- Join stages analysis
-- Tracks payment progression through join stages
-- Validates data relationships and identifies expected patterns
-- Note: "missing" payments are often valid (patient payments, transfers, etc.)

WITH JoinStageCounts AS (
    SELECT 
        pbc.total_payments as base_count,
        -- Split stages
        COUNT(DISTINCT CASE WHEN pjd.join_status != 'No Splits' THEN pjd.PayNum END) as with_splits,
        COUNT(DISTINCT CASE WHEN pjd.join_status NOT IN ('No Splits', 'No Procedures') THEN pjd.PayNum END) as with_procedures,
        COUNT(DISTINCT CASE WHEN pjd.join_status = 'Complete' THEN pjd.PayNum END) as with_insurance,
        -- Payment categories
        COUNT(DISTINCT CASE WHEN pjd.join_status = 'No Insurance' AND pjd.PayAmt > 0 THEN pjd.PayNum END) as patient_payments,
        COUNT(DISTINCT CASE WHEN pjd.join_status = 'No Procedures' AND pjd.PayAmt = 0 THEN pjd.PayNum END) as transfer_count,
        COUNT(DISTINCT CASE WHEN pjd.join_status = 'No Procedures' AND pjd.PayAmt < 0 THEN pjd.PayNum END) as refund_count,
        -- Split analysis
        AVG(ps.split_count) as avg_splits_per_payment,
        COUNT(DISTINCT CASE WHEN ps.split_difference > 0.01 THEN ps.PayNum END) as mismatch_count
    FROM PaymentBaseCounts pbc
    CROSS JOIN PaymentJoinDiagnostics pjd
    LEFT JOIN PaymentSummary ps ON pjd.PayNum = ps.PayNum
    GROUP BY pbc.total_payments
)
SELECT 
    base_count,
    with_splits,
    with_procedures,
    with_insurance,
    -- Expected non-insurance payments
    patient_payments as valid_patient_payments,
    transfer_count as internal_transfers,
    refund_count as payment_refunds,
    -- Data quality metrics
    base_count - with_splits as missing_splits,
    with_splits - with_procedures as unlinked_procedures,
    avg_splits_per_payment,
    mismatch_count as split_amount_mismatches,
    -- Summary percentages
    ROUND(with_insurance * 100.0 / base_count, 1) as pct_insurance,
    ROUND(patient_payments * 100.0 / base_count, 1) as pct_patient,
    ROUND(transfer_count * 100.0 / base_count, 1) as pct_transfer
FROM JoinStageCounts;
