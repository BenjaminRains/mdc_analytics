-- PAYMENT SPLITS
-- Analyzes how payments are split between insurance and direct payments
-- Used for understanding payment source distribution and insurance vs. patient contribution
-- Dependent CTEs: base_procedures.sql, payment_activity.sql
PaymentSplits AS (
    SELECT
        pl.ProcNum,
        pl.ProcStatus,
        pl.ProcFee,
        pa.insurance_paid,
        pa.direct_paid,
        pa.total_paid,
        CASE
            WHEN pa.total_paid IS NULL OR pa.total_paid = 0 THEN 'No Payment'
            WHEN pa.insurance_paid > 0 AND pa.direct_paid > 0 THEN 'Split Payment'
            WHEN pa.insurance_paid > 0 THEN 'Insurance Only'
            WHEN pa.direct_paid > 0 THEN 'Direct Payment Only'
            ELSE 'No Payment'
        END AS payment_type,
        CASE
            WHEN pa.total_paid IS NULL OR pa.total_paid = 0 THEN 0
            WHEN pa.total_paid > 0 THEN pa.insurance_paid / pa.total_paid
            ELSE 0
        END AS insurance_ratio
    FROM BaseProcedures pl
    LEFT JOIN PaymentActivity pa ON pl.ProcNum = pa.ProcNum
    WHERE pl.ProcFee > 0  -- Only procedures with fees
)