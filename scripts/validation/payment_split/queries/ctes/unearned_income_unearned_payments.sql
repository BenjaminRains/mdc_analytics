-- CTE for unearned income analysis
-- Purpose: Isolates unearned payment data (UnearnedType != 0) with prepayment type details
-- Dependencies: None
-- Date filter: @start_date to @end_date

unearned_income AS (
    SELECT 
        'Unearned Income' AS 'Section',
        DATE_FORMAT(ps.DatePay, '%Y-%m') AS 'Payment Month',
        IFNULL(
            (SELECT def.ItemName 
             FROM definition def 
             WHERE def.DefNum = pm.PayType), 
            'Income Transfer'
        ) AS 'Payment Type',
        'Unearned Income' AS 'Payment Category',
        COUNT(*) AS 'Transaction Count',
        SUM(ps.SplitAmt) AS 'Total Amount',
        COUNT(DISTINCT ps.PatNum) AS 'Unique Patients',
        0 AS 'Regular Payment Amount',
        SUM(ps.SplitAmt) AS 'Unearned Income Amount',
        0 AS 'Regular Payment %',
        AVG(ps.SplitAmt) AS 'Average Payment Amount',
        SUM(CASE WHEN ps.UnearnedType = 288 THEN ps.SplitAmt ELSE 0 END) AS 'Prepayment Amount',
        SUM(CASE WHEN ps.UnearnedType = 439 THEN ps.SplitAmt ELSE 0 END) AS 'Treatment Plan Prepayment Amount'
    FROM paysplit ps
    INNER JOIN payment pm ON pm.PayNum = ps.PayNum
    WHERE ps.DatePay BETWEEN @start_date AND @end_date
        AND ps.UnearnedType != 0
    GROUP BY DATE_FORMAT(ps.DatePay, '%Y-%m'), pm.PayType
) 