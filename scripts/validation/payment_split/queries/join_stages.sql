-- Join stages analysis
-- Tracks payment progression through join stages
-- Validates data relationships and identifies expected patterns
-- Note: "missing" payments are often valid (patient payments, transfers, etc.)
-- Date filter: Use @start_date to @end_date variables
-- Include dependent CTE
<<include:join_stage_counts.sql>>


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
