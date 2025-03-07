-- UnearnedIncomePaymentUnearnedTypeSummary: Detailed breakdown of payments by unearned type
-- depends on: none
-- Date filter: Uses @start_date to @end_date variables

UnearnedIncomePaymentUnearnedTypeSummary AS (
    SELECT 
        CONCAT(
            IFNULL(
                (SELECT def.ItemName 
                FROM definition def 
                WHERE def.DefNum = ps.UnearnedType), 
                CASE WHEN ps.UnearnedType = 0 THEN 'Regular Payment' ELSE 'Unknown' END
            ),
            ' (Type ', CAST(ps.UnearnedType AS CHAR), ')'
        ) AS payment_category,
        COUNT(*) AS total_splits,
        SUM(ps.SplitAmt) AS total_amount,
        AVG(ps.SplitAmt) AS avg_amount,
        COUNT(DISTINCT ps.PatNum) AS unique_patients,
        CASE WHEN ps.UnearnedType = 0 THEN COUNT(*) ELSE 0 END AS regular_payment_splits,
        CASE WHEN ps.UnearnedType != 0 THEN COUNT(*) ELSE 0 END AS unearned_income_splits,
        CASE WHEN ps.UnearnedType = 0 THEN SUM(ps.SplitAmt) ELSE 0 END AS regular_payment_amount,
        CASE WHEN ps.UnearnedType != 0 THEN SUM(ps.SplitAmt) ELSE 0 END AS unearned_income_amount,
        CASE WHEN ps.UnearnedType = 0 THEN '100.0' ELSE '0.0' END AS percent_regular_payments,
        CASE WHEN ps.UnearnedType != 0 THEN '100.0' ELSE '0.0' END AS percent_unearned_income,
        1 AS sort_order -- Make detail rows appear after summary
    FROM paysplit ps
    WHERE ps.DatePay BETWEEN @start_date AND @end_date
    GROUP BY ps.UnearnedType
) 