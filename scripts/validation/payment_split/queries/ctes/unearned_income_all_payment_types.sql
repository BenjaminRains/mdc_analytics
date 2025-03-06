-- CTE for all payment types analysis
-- Purpose: Aggregates payment data across all types with detailed breakdowns
-- Dependencies: None
-- Date filter: @start_date to @end_date

all_payment_types AS (
    SELECT 
        'All Payment Types' AS 'Section',
        DATE_FORMAT(ps.DatePay, '%Y-%m') AS 'Payment Month',
        IFNULL(
            (SELECT def.ItemName 
             FROM definition def 
             WHERE def.DefNum = pm.PayType), 
            'Income Transfer'
        ) AS 'Payment Type',
        'All' AS 'Payment Category',
        COUNT(*) AS 'Transaction Count',
        SUM(ps.SplitAmt) AS 'Total Amount',
        COUNT(DISTINCT ps.PatNum) AS 'Unique Patients',
        SUM(CASE WHEN ps.UnearnedType = 0 THEN ps.SplitAmt ELSE 0 END) AS 'Regular Payment Amount',
        SUM(CASE WHEN ps.UnearnedType != 0 THEN ps.SplitAmt ELSE 0 END) AS 'Unearned Income Amount',
        CASE 
            WHEN SUM(ps.SplitAmt) = 0 THEN 0
            ELSE (SUM(CASE WHEN ps.UnearnedType = 0 THEN ps.SplitAmt ELSE 0 END) / SUM(ps.SplitAmt)) * 100
        END AS 'Regular Payment %',
        NULL AS 'Average Payment Amount',
        NULL AS 'Prepayment Amount',
        NULL AS 'Treatment Plan Prepayment Amount'
    FROM paysplit ps
    INNER JOIN payment pm ON pm.PayNum = ps.PayNum
    WHERE ps.DatePay BETWEEN @start_date AND @end_date
    GROUP BY DATE_FORMAT(ps.DatePay, '%Y-%m'), pm.PayType
) 