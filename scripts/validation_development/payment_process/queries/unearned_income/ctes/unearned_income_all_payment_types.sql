-- UnearnedIncomeAllPaymentTypes: CTE for all payment types analysis
-- Purpose: Aggregates payment data across all types with detailed breakdowns
-- Dependencies: None
-- Date filter: @start_date to @end_date

UnearnedIncomeAllPaymentTypes AS (
    SELECT 
        'All Payment Types' AS section,
        DATE_FORMAT(ps.DatePay, '%Y-%m') AS payment_month,
        IFNULL(
            (SELECT def.ItemName 
             FROM definition def 
             WHERE def.DefNum = pm.PayType), 
            'Income Transfer'
        ) AS payment_type,
        'All' AS payment_category,
        COUNT(*) AS transaction_count,
        SUM(ps.SplitAmt) AS total_amount,
        COUNT(DISTINCT ps.PatNum) AS unique_patients,
        SUM(CASE WHEN ps.UnearnedType = 0 THEN ps.SplitAmt ELSE 0 END) AS regular_payment_amount,
        SUM(CASE WHEN ps.UnearnedType != 0 THEN ps.SplitAmt ELSE 0 END) AS unearned_income_amount,
        CASE 
            WHEN SUM(ps.SplitAmt) = 0 THEN 0
            ELSE (SUM(CASE WHEN ps.UnearnedType = 0 THEN ps.SplitAmt ELSE 0 END) / SUM(ps.SplitAmt)) * 100
        END AS regular_payment_percent,
        NULL AS average_payment_amount,
        NULL AS prepayment_amount,
        NULL AS treatment_plan_prepayment_amount
    FROM paysplit ps
    INNER JOIN payment pm ON pm.PayNum = ps.PayNum
    WHERE ps.DatePay BETWEEN @start_date AND @end_date
    GROUP BY DATE_FORMAT(ps.DatePay, '%Y-%m'), pm.PayType
) 