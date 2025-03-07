-- CTE for all patient payment types analysis
-- Purpose: Aggregates payment data by patient showing regular and unearned income distribution
-- Dependencies: None
-- Date filter: @start_date to @end_date

UnearnedIncomePatientAllPayments AS (
    SELECT
        'All Payment Types' AS payment_type,
        ps.PatNum AS patient_number,
        CONCAT(pt.LName, ', ', pt.FName) AS patient_name,
        COUNT(*) AS transaction_count,
        SUM(ps.SplitAmt) AS total_amount,
        SUM(CASE WHEN ps.UnearnedType = 0 THEN ps.SplitAmt ELSE 0 END) AS regular_payment_amount,
        SUM(CASE WHEN ps.UnearnedType != 0 THEN ps.SplitAmt ELSE 0 END) AS unearned_income_amount,
        CASE 
            WHEN SUM(ps.SplitAmt) = 0 THEN 0
            ELSE (SUM(CASE WHEN ps.UnearnedType = 0 THEN ps.SplitAmt ELSE 0 END) / SUM(ps.SplitAmt)) * 100
        END AS regular_payment_percent,
        MIN(ps.DatePay) AS first_payment_date,
        MAX(ps.DatePay) AS last_payment_date,
        DATEDIFF(MAX(ps.DatePay), MIN(ps.DatePay)) AS days_between_first_and_last
    FROM paysplit ps
    INNER JOIN patient pt ON pt.PatNum = ps.PatNum
    WHERE ps.DatePay BETWEEN @start_date AND @end_date
    GROUP BY ps.PatNum, pt.LName, pt.FName
) 