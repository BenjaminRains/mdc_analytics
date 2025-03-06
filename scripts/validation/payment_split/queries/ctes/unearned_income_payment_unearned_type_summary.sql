-- unearned_income_payment_unearned_type_summary: Detailed breakdown of payments by unearned type
-- depends on: none
-- Date filter: Uses @start_date to @end_date variables

unearned_income_payment_unearned_type_summary AS (
    SELECT 
        CONCAT(
            IFNULL(
                (SELECT def.ItemName 
                FROM definition def 
                WHERE def.DefNum = ps.UnearnedType), 
                CASE WHEN ps.UnearnedType = 0 THEN 'Regular Payment' ELSE 'Unknown' END
            ),
            ' (Type ', CAST(ps.UnearnedType AS CHAR), ')'
        ) AS 'Payment Category',
        COUNT(*) AS 'Total Splits',
        SUM(ps.SplitAmt) AS 'Total Amount',
        AVG(ps.SplitAmt) AS 'Avg Amount',
        COUNT(DISTINCT ps.PatNum) AS 'Unique Patients',
        CASE WHEN ps.UnearnedType = 0 THEN COUNT(*) ELSE 0 END AS 'Regular Payment Splits',
        CASE WHEN ps.UnearnedType != 0 THEN COUNT(*) ELSE 0 END AS 'Unearned Income Splits',
        CASE WHEN ps.UnearnedType = 0 THEN SUM(ps.SplitAmt) ELSE 0 END AS 'Regular Payment Amount',
        CASE WHEN ps.UnearnedType != 0 THEN SUM(ps.SplitAmt) ELSE 0 END AS 'Unearned Income Amount',
        CASE WHEN ps.UnearnedType = 0 THEN '100.0' ELSE '0.0' END AS '% Regular Payments',
        CASE WHEN ps.UnearnedType != 0 THEN '100.0' ELSE '0.0' END AS '% Unearned Income',
        1 AS sort_order -- Make detail rows appear after summary
    FROM paysplit ps
    WHERE ps.DatePay BETWEEN @start_date AND @end_date
    GROUP BY ps.UnearnedType
) 