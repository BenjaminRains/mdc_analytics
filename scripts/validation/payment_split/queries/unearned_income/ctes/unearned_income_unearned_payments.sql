-- UnearnedIncomeUnearnedPayments: CTE for unearned income analysis
-- Purpose: Isolates unearned payment data (UnearnedType != 0) with prepayment type details
-- Dependencies: None
-- Date filter: @start_date to @end_date

UnearnedIncomeUnearnedPayments AS (
    SELECT 
        'Unearned Income' AS section,
        DATE_FORMAT(ps.DatePay, '%Y-%m') AS payment_month,
        IFNULL(
            (SELECT def.ItemName 
             FROM definition def 
             WHERE def.DefNum = pm.PayType), 
            'Income Transfer'
        ) AS payment_type,
        'Unearned Income' AS payment_category,
        COUNT(*) AS transaction_count,
        SUM(ps.SplitAmt) AS total_amount,
        COUNT(DISTINCT ps.PatNum) AS unique_patients,
        0 AS regular_payment_amount,
        SUM(ps.SplitAmt) AS unearned_income_amount,
        0 AS regular_payment_percent,
        AVG(ps.SplitAmt) AS average_payment_amount,
        SUM(CASE WHEN ps.UnearnedType = 288 THEN ps.SplitAmt ELSE 0 END) AS prepayment_amount,
        SUM(CASE WHEN ps.UnearnedType = 439 THEN ps.SplitAmt ELSE 0 END) AS treatment_plan_prepayment_amount
    FROM paysplit ps
    INNER JOIN payment pm ON pm.PayNum = ps.PayNum
    WHERE ps.DatePay BETWEEN @start_date AND @end_date
        AND ps.UnearnedType != 0
    GROUP BY DATE_FORMAT(ps.DatePay, '%Y-%m'), pm.PayType
) 