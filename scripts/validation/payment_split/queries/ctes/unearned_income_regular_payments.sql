-- CTE for regular payments analysis
-- Purpose: Isolates regular payment data (UnearnedType = 0) by payment method and date
-- Dependencies: None
-- Date filter: @start_date to @end_date

regular_payments AS (
    SELECT 
        'Regular Payments' AS 'Section',
        DATE_FORMAT(ps.DatePay, '%Y-%m') AS 'Payment Month',
        IFNULL(
            (SELECT def.ItemName 
             FROM definition def 
             WHERE def.DefNum = pm.PayType), 
            'Income Transfer'
        ) AS 'Payment Type',
        'Regular Payments' AS 'Payment Category',
        COUNT(*) AS 'Transaction Count',
        SUM(ps.SplitAmt) AS 'Total Amount',
        COUNT(DISTINCT ps.PatNum) AS 'Unique Patients',
        SUM(ps.SplitAmt) AS 'Regular Payment Amount',
        0 AS 'Unearned Income Amount',
        100 AS 'Regular Payment %',
        AVG(ps.SplitAmt) AS 'Average Payment Amount',
        NULL AS 'Prepayment Amount',
        NULL AS 'Treatment Plan Prepayment Amount'
    FROM paysplit ps
    INNER JOIN payment pm ON pm.PayNum = ps.PayNum
    WHERE ps.DatePay BETWEEN @start_date AND @end_date
        AND ps.UnearnedType = 0
    GROUP BY DATE_FORMAT(ps.DatePay, '%Y-%m'), pm.PayType
) 