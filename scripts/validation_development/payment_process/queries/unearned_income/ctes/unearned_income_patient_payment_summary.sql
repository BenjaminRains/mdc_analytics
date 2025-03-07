-- UnearnedIncomePatientPaymentSummary: Aggregates payment data by payment types
-- Summary of payments grouped by patient: regular vs unearned income
-- Dependencies: None
-- Date filter: Uses @end_date parameter to filter payments

UnearnedIncomePatientPaymentSummary AS (
    SELECT
        ps.PatNum,
        -- Regular payments
        SUM(CASE WHEN ps.UnearnedType = 0 THEN ps.SplitAmt ELSE 0 END) AS regular_payment_amount,
        -- Unearned income types
        SUM(CASE WHEN ps.UnearnedType = 288 THEN ps.SplitAmt ELSE 0 END) AS prepayment_amount,
        SUM(CASE WHEN ps.UnearnedType = 439 THEN ps.SplitAmt ELSE 0 END) AS tp_prepayment_amount,
        SUM(CASE WHEN ps.UnearnedType NOT IN (0, 288, 439) AND ps.UnearnedType != 0 THEN ps.SplitAmt ELSE 0 END) AS other_unearned_amount,
        -- Subtotals
        SUM(CASE WHEN ps.UnearnedType != 0 THEN ps.SplitAmt ELSE 0 END) AS total_unearned_amount,
        SUM(CASE WHEN ps.UnearnedType = 0 THEN ps.SplitAmt ELSE 0 END) AS total_earned_amount,
        -- Total of all payments
        SUM(ps.SplitAmt) AS total_payment_amount,
        -- Last payment date
        MAX(ps.DatePay) AS last_payment_date
    FROM paysplit ps
    WHERE ps.DatePay <= @end_date
    GROUP BY ps.PatNum
) 