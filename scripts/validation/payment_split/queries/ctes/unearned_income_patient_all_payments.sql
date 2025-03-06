-- CTE for all patient payment types analysis
-- Purpose: Aggregates payment data by patient showing regular and unearned income distribution
-- Dependencies: None
-- Date filter: @start_date to @end_date

all_payments AS (
    SELECT
        'All Payment Types' AS 'Payment Type',
        ps.PatNum AS 'Patient Number',
        CONCAT(pt.LName, ', ', pt.FName) AS 'Patient Name',
        COUNT(*) AS 'Transaction Count',
        SUM(ps.SplitAmt) AS 'Total Amount',
        SUM(CASE WHEN ps.UnearnedType = 0 THEN ps.SplitAmt ELSE 0 END) AS 'Regular Payment Amount',
        SUM(CASE WHEN ps.UnearnedType != 0 THEN ps.SplitAmt ELSE 0 END) AS 'Unearned Income Amount',
        CASE 
            WHEN SUM(ps.SplitAmt) = 0 THEN 0
            ELSE (SUM(CASE WHEN ps.UnearnedType = 0 THEN ps.SplitAmt ELSE 0 END) / SUM(ps.SplitAmt)) * 100
        END AS 'Regular Payment %',
        MIN(ps.DatePay) AS 'First Payment Date',
        MAX(ps.DatePay) AS 'Last Payment Date',
        DATEDIFF(MAX(ps.DatePay), MIN(ps.DatePay)) AS 'Days Between First and Last'
    FROM paysplit ps
    INNER JOIN patient pt ON pt.PatNum = ps.PatNum
    WHERE ps.DatePay BETWEEN @start_date AND @end_date
    GROUP BY ps.PatNum, pt.LName, pt.FName
) 