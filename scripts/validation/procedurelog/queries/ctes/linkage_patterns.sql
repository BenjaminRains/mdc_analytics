-- LINKAGE PATTERNS
-- Categorizes procedures by payment linkage patterns
-- Used for analyzing payment source distribution and payment status
-- dependent CTEs: PaymentLinks
LinkagePatterns AS (
    SELECT
        ProcNum,
        ProcStatus,
        ProcFee,
        paysplit_count,
        claimproc_count,
        direct_payment_amount,
        insurance_payment_amount,
        insurance_estimate_amount,
        direct_payment_amount + insurance_payment_amount AS total_payment_amount,
        min_days_to_payment,
        max_days_to_payment,
        has_zero_insurance_payment,
        CASE
            WHEN paysplit_count = 0 AND claimproc_count = 0 THEN 'No payment links'
            WHEN paysplit_count > 0 AND claimproc_count = 0 THEN 'Direct payment only'
            WHEN paysplit_count = 0 AND claimproc_count > 0 THEN 'Insurance only'
            ELSE 'Mixed payment sources'
        END AS payment_source_type,
        CASE
            WHEN direct_payment_amount + insurance_payment_amount >= ProcFee * 0.95 THEN 'Fully paid'
            WHEN direct_payment_amount + insurance_payment_amount > 0 THEN 'Partially paid'
            ELSE 'Unpaid'
        END AS payment_status,
        CASE
            WHEN insurance_estimate_amount > 0 AND insurance_payment_amount = 0 THEN 'Expected insurance not received'
            WHEN insurance_estimate_amount > 0 AND insurance_payment_amount < insurance_estimate_amount * 0.9 THEN 'Insurance underpaid'
            WHEN insurance_estimate_amount > 0 AND insurance_payment_amount > insurance_estimate_amount * 1.1 THEN 'Insurance overpaid'
            ELSE 'Normal insurance pattern'
        END AS insurance_pattern
    FROM PaymentLinks
)