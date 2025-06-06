-- UnearnedIncomePatientRegularPayments: CTE for regular patient payments analysis
-- Purpose: Isolates regular payment data (UnearnedType = 0) by patient
-- Dependencies: None
-- Date filter: @start_date to @end_date

UnearnedIncomePatientRegularPayments AS (
    SELECT
        'Regular Payments (Type 0)' AS payment_type,
        ps.PatNum AS patient_number,
        CONCAT(pt.LName, ', ', pt.FName) AS patient_name,
        COUNT(*) AS transaction_count,
        SUM(ps.SplitAmt) AS total_amount,
        SUM(ps.SplitAmt) AS regular_payment_amount,
        0 AS unearned_income_amount,
        100 AS regular_payment_percent,
        MIN(ps.DatePay) AS first_payment_date,
        MAX(ps.DatePay) AS last_payment_date,
        DATEDIFF(MAX(ps.DatePay), MIN(ps.DatePay)) AS days_between_first_and_last
    FROM paysplit ps
    INNER JOIN patient pt ON pt.PatNum = ps.PatNum
    WHERE ps.DatePay BETWEEN @start_date AND @end_date
        AND ps.UnearnedType = 0
    GROUP BY ps.PatNum, pt.LName, pt.FName
) 