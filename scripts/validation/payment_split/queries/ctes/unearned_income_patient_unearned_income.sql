-- CTE for unearned patient payments analysis
-- Purpose: Isolates unearned payment data (UnearnedType != 0) by patient
-- Dependencies: None
-- Date filter: @start_date to @end_date

unearned_income AS (
    SELECT
        'Unearned Income (Type != 0)' AS 'Payment Type',
        ps.PatNum AS 'Patient Number',
        CONCAT(pt.LName, ', ', pt.FName) AS 'Patient Name',
        COUNT(*) AS 'Transaction Count',
        SUM(ps.SplitAmt) AS 'Total Amount',
        0 AS 'Regular Payment Amount',
        SUM(ps.SplitAmt) AS 'Unearned Income Amount',
        0 AS 'Regular Payment %',
        MIN(ps.DatePay) AS 'First Payment Date',
        MAX(ps.DatePay) AS 'Last Payment Date',
        DATEDIFF(MAX(ps.DatePay), MIN(ps.DatePay)) AS 'Days Between First and Last'
    FROM paysplit ps
    INNER JOIN patient pt ON pt.PatNum = ps.PatNum
    WHERE ps.DatePay BETWEEN @start_date AND @end_date
        AND ps.UnearnedType != 0
    GROUP BY ps.PatNum, pt.LName, pt.FName
) 