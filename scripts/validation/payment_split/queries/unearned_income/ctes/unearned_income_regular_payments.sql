-- UnearnedIncomeRegularPayments: CTE for regular payments analysis
-- Purpose: Isolates regular payment data (UnearnedType = 0) by payment method and date
-- Dependencies: None
-- Date filter: @start_date to @end_date

UnearnedIncomeRegularPayments AS (
    SELECT 
        'Regular Payments' AS section,
        DATE_FORMAT(ps.DatePay, '%Y-%m') AS payment_month,
        IFNULL(
            (SELECT def.ItemName 
             FROM definition def 
             WHERE def.DefNum = pm.PayType), 
            'Income Transfer'
        ) AS payment_type,
        'Regular Payments' AS payment_category,
        COUNT(*) AS transaction_count,
        SUM(ps.SplitAmt) AS total_amount,
        COUNT(DISTINCT ps.PatNum) AS unique_patients,
        SUM(ps.SplitAmt) AS regular_payment_amount,
        0 AS unearned_income_amount,
        100 AS regular_payment_percent,
        AVG(ps.SplitAmt) AS average_payment_amount,
        NULL AS prepayment_amount,
        NULL AS treatment_plan_prepayment_amount
    FROM paysplit ps
    INNER JOIN payment pm ON pm.PayNum = ps.PayNum
    WHERE ps.DatePay BETWEEN @start_date AND @end_date
        AND ps.UnearnedType = 0
    GROUP BY DATE_FORMAT(ps.DatePay, '%Y-%m'), pm.PayType
) 