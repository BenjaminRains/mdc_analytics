-- Unearned Income Report
-- This query extracts raw data about unearned income for analysis in notebooks
-- UnearnedType values:
-- Type 0: Regular payments (88.9% of splits) - Direct application to procedures
-- Type 288: Prepayments (10.9% of splits) - Payment received before procedure
-- Type 439: Treatment Plan Prepayments (0.2% of splits) - Specific to treatment plan deposits

-- Date filter: Use @start_date to @end_date variables

-- Common Table Expressions for efficient data retrieval
WITH UnearntypeDef AS (
    -- Get UnearnedType definitions once
    SELECT 
        DefNum,
        ItemName AS UnearnedTypeName
    FROM definition
    WHERE DefNum IN (
        SELECT DISTINCT UnearnedType 
        FROM paysplit 
        WHERE UnearnedType != 0
    )
),
PayTypeDef AS (
    -- Get PayType definitions once
    SELECT 
        DefNum,
        ItemName AS PayTypeName
    FROM definition
    WHERE DefNum IN (
        SELECT DISTINCT p.PayType 
        FROM payment p
        JOIN paysplit ps ON p.PayNum = ps.PayNum
        WHERE ps.UnearnedType != 0
    )
),
ProvDef AS (
    -- Get Provider information from the provider table, not definition table
    SELECT 
        ProvNum,
        CONCAT(FName, ' ', LName) AS ProviderName
    FROM provider
    WHERE ProvNum IN (
        SELECT DISTINCT ProvNum 
        FROM paysplit
        WHERE UnearnedType != 0
    )
),
PatientBalances AS (
    -- Pre-calculate patient balances to avoid repeated subqueries
    SELECT
        PatNum,
        SUM(SplitAmt) AS TotalBalance
    FROM paysplit
    GROUP BY PatNum
)

-- QUERY_NAME: unearned_income_main_transactions
-- Main query to extract all relevant data for analysis
SELECT
    -- Transaction Info
    ps.SplitNum,
    ps.DatePay AS PaymentDate,
    ps.UnearnedType,
    COALESCE(ud.UnearnedTypeName, 'Unknown') AS UnearnedTypeName,
    ps.SplitAmt,
    CASE 
        WHEN ps.UnearnedType = 288 THEN 'Prepayment'
        WHEN ps.UnearnedType = 439 THEN 'Treatment Plan Prepayment'
        WHEN ps.UnearnedType != 0 THEN 'Other Unearned Type'
        ELSE 'Regular Payment'
    END AS Category,
    
    -- Payment Info
    pm.PayNum,
    pm.PayAmt AS TotalPaymentAmount,
    pm.PayType,
    COALESCE(pd.PayTypeName, 'Income Transfer') AS PayTypeName,
    pm.PayDate,
    pm.PayNote,
    
    -- Patient Info
    ps.PatNum,
    pt.LName AS LastName,
    pt.FName AS FirstName,
    CONCAT(pt.LName, ', ', pt.FName) AS PatientName,
    
    -- Provider Info
    ps.ProvNum,
    COALESCE(prvd.ProviderName, 'Unassigned') AS ProviderName,
    
    -- Balance Info
    pb.TotalBalance AS CurrentPatientBalance,
    
    -- Clinic Info
    ps.ClinicNum,
    
    -- Procedure Info if available
    ps.ProcNum,
    
    -- Dates for aging analysis
    DATEDIFF(@end_date, ps.DatePay) AS DaysSincePayment
FROM paysplit ps
JOIN payment pm ON pm.PayNum = ps.PayNum
JOIN patient pt ON pt.PatNum = ps.PatNum
LEFT JOIN UnearntypeDef ud ON ud.DefNum = ps.UnearnedType
LEFT JOIN PayTypeDef pd ON pd.DefNum = pm.PayType
LEFT JOIN ProvDef prvd ON prvd.ProvNum = ps.ProvNum
LEFT JOIN PatientBalances pb ON pb.PatNum = ps.PatNum
WHERE 
    -- Filter unearned income transactions
    ps.UnearnedType != 0
    -- Date filter can be adjusted as needed
    AND ps.DatePay BETWEEN @start_date AND @end_date
ORDER BY ps.DatePay;

-- QUERY_NAME: unearned_income_patient_balance_report
-- Optimized Patient Balance Report using temporary tables for better performance
-- Step 1: Create a temporary table with patient balances
DROP TEMPORARY TABLE IF EXISTS temp_patient_balances;
CREATE TEMPORARY TABLE temp_patient_balances AS
SELECT
    ps.PatNum,
    SUM(CASE WHEN ps.UnearnedType = 288 THEN ps.SplitAmt ELSE 0 END) AS prepayment_amount,
    SUM(CASE WHEN ps.UnearnedType = 439 THEN ps.SplitAmt ELSE 0 END) AS tp_prepayment_amount,
    SUM(CASE WHEN ps.UnearnedType NOT IN (0, 288, 439) AND ps.UnearnedType != 0 THEN ps.SplitAmt ELSE 0 END) AS other_unearned_amount,
    SUM(CASE WHEN ps.UnearnedType != 0 THEN ps.SplitAmt ELSE 0 END) AS total_unearned_amount,
    SUM(CASE WHEN ps.UnearnedType = 0 THEN ps.SplitAmt ELSE 0 END) AS earned_amount,
    SUM(ps.SplitAmt) AS total_balance,
    MAX(ps.DatePay) AS last_payment_date
FROM paysplit ps
WHERE ps.DatePay <= @end_date
GROUP BY ps.PatNum;

-- Step 2: Create a temporary table with transaction counts
DROP TEMPORARY TABLE IF EXISTS temp_transaction_counts;
CREATE TEMPORARY TABLE temp_transaction_counts AS
SELECT
    PatNum,
    COUNT(*) AS transaction_count
FROM paysplit
WHERE DatePay BETWEEN @start_date AND @end_date
    AND UnearnedType != 0
GROUP BY PatNum;

-- Step 3: Join the temporary tables with patient information for the final report
SELECT
    pb.PatNum AS 'Patient Number',
    CONCAT(pt.LName, ', ', pt.FName) AS 'Patient Name',
    FORMAT(pb.prepayment_amount, 2) AS 'Prepayment Amount',
    FORMAT(pb.tp_prepayment_amount, 2) AS 'Treatment Plan Prepayment Amount',
    FORMAT(pb.other_unearned_amount, 2) AS 'Other Unearned Amount',
    FORMAT(pb.total_unearned_amount, 2) AS 'Total Unearned Amount',
    FORMAT(pb.earned_amount, 2) AS 'Earned Amount',
    FORMAT(pb.total_balance, 2) AS 'Total Balance',
    pb.last_payment_date AS 'Last Payment Date',
    DATEDIFF(@end_date, pb.last_payment_date) AS 'Days Since Last Payment',
    IFNULL(tc.transaction_count, 0) AS 'Unearned Transactions Count'
FROM temp_patient_balances pb
INNER JOIN patient pt ON pt.PatNum = pb.PatNum
LEFT JOIN temp_transaction_counts tc ON tc.PatNum = pb.PatNum
WHERE pb.total_unearned_amount != 0 -- Only patients with unearned amounts
ORDER BY pb.total_unearned_amount DESC;

-- QUERY_NAME: unearned_income_unearned_type_summary
-- Summary statistics by unearned type
SELECT 
    COUNT(*) AS 'Total Unearned Splits',
    SUM(ps.SplitAmt) AS 'Total Unearned Amount',
    IFNULL(
        (SELECT def.ItemName 
         FROM definition def 
         WHERE def.DefNum = ps.UnearnedType), 
        'Unknown'
    ) AS 'Unearned Type',
    COUNT(DISTINCT ps.PatNum) AS 'Unique Patients',
    MIN(ps.SplitAmt) AS 'Min Amount',
    MAX(ps.SplitAmt) AS 'Max Amount',
    AVG(ps.SplitAmt) AS 'Avg Amount'
FROM paysplit ps
WHERE ps.DatePay BETWEEN @start_date AND @end_date
    AND ps.UnearnedType != 0
GROUP BY ps.UnearnedType
ORDER BY COUNT(*) DESC;

-- QUERY_NAME: unearned_income_payment_type_summary
-- Summary statistics by payment type
SELECT 
    IFNULL(
        (SELECT def.ItemName 
         FROM definition def 
         WHERE def.DefNum = pm.PayType), 
        'Income Transfer'
    ) AS 'Payment Type',
    COUNT(*) AS 'Count',
    SUM(ps.SplitAmt) AS 'Total Amount',
    COUNT(DISTINCT ps.PatNum) AS 'Unique Patients'
FROM paysplit ps
INNER JOIN payment pm ON pm.PayNum = ps.PayNum
WHERE ps.DatePay BETWEEN @start_date AND @end_date
    AND ps.UnearnedType != 0
GROUP BY pm.PayType
ORDER BY SUM(ps.SplitAmt) DESC;

-- QUERY_NAME: unearned_income_monthly_trend
-- Monthly trend of unearned income
SELECT 
    DATE_FORMAT(ps.DatePay, '%Y-%m') AS 'Month',
    COUNT(*) AS 'Transaction Count',
    SUM(CASE WHEN ps.UnearnedType = 288 THEN ps.SplitAmt ELSE 0 END) AS 'Prepayment Amount',
    SUM(CASE WHEN ps.UnearnedType = 439 THEN ps.SplitAmt ELSE 0 END) AS 'Treatment Plan Prepayment Amount',
    SUM(CASE WHEN ps.UnearnedType NOT IN (0, 288, 439) THEN ps.SplitAmt ELSE 0 END) AS 'Other Unearned Amount',
    SUM(ps.SplitAmt) AS 'Total Unearned Amount'
FROM paysplit ps
WHERE ps.DatePay BETWEEN @start_date AND @end_date
    AND ps.UnearnedType != 0
GROUP BY DATE_FORMAT(ps.DatePay, '%Y-%m')
ORDER BY DATE_FORMAT(ps.DatePay, '%Y-%m');

-- QUERY_NAME: unearned_income_negative_prepayments
-- Negative prepayments (potential refunds or adjustments)
SELECT
    DATE_FORMAT(ps.DatePay, '%m/%d/%Y') AS 'Payment Date',
    ps.PatNum AS 'Patient Number',
    CONCAT(pt.LName, ', ', pt.FName) AS 'Patient Name',
    IFNULL(
        (SELECT def.ItemName 
         FROM definition def 
         WHERE def.DefNum = ps.UnearnedType), 
        'Unknown'
    ) AS 'Unearned Type',
    FORMAT(ps.SplitAmt, 2) AS 'Split Amount',
    IFNULL(pm.PayNote, '') AS 'Payment Note'
FROM paysplit ps
INNER JOIN payment pm ON pm.PayNum = ps.PayNum
INNER JOIN patient pt ON pt.PatNum = ps.PatNum
WHERE ps.DatePay BETWEEN @start_date AND @end_date
    AND ps.UnearnedType != 0
    AND ps.SplitAmt < 0
ORDER BY ps.SplitAmt;

-- Top patients with unearned income
SELECT
    ps.PatNum AS 'Patient Number',
    CONCAT(pt.LName, ', ', pt.FName) AS 'Patient Name',
    COUNT(*) AS 'Transaction Count',
    SUM(ps.SplitAmt) AS 'Total Unearned Amount',
    MIN(ps.DatePay) AS 'First Payment Date',
    MAX(ps.DatePay) AS 'Last Payment Date',
    DATEDIFF(MAX(ps.DatePay), MIN(ps.DatePay)) AS 'Days Between First and Last'
FROM paysplit ps
INNER JOIN patient pt ON pt.PatNum = ps.PatNum
WHERE ps.DatePay BETWEEN @start_date AND @end_date
    AND ps.UnearnedType != 0
GROUP BY ps.PatNum, pt.LName, pt.FName
ORDER BY SUM(ps.SplitAmt) DESC
LIMIT 20;

-- QUERY_NAME: unearned_income_aging_analysis
-- Aging analysis of unearned income
SELECT
    CASE
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 30 THEN '0-30 days'
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 60 THEN '31-60 days'
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 90 THEN '61-90 days'
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 180 THEN '91-180 days'
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 365 THEN '181-365 days'
        ELSE 'Over 365 days'
    END AS 'Age Bucket',
    COUNT(*) AS 'Transaction Count',
    SUM(ps.SplitAmt) AS 'Total Amount',
    COUNT(DISTINCT ps.PatNum) AS 'Unique Patients'
FROM paysplit ps
WHERE ps.DatePay <= @end_date
    AND ps.UnearnedType != 0
GROUP BY 
    CASE
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 30 THEN '0-30 days'
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 60 THEN '31-60 days'
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 90 THEN '61-90 days'
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 180 THEN '91-180 days'
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 365 THEN '181-365 days'
        ELSE 'Over 365 days'
    END
ORDER BY 
    CASE
        WHEN CASE
            WHEN DATEDIFF(@end_date, ps.DatePay) <= 30 THEN '0-30 days'
            WHEN DATEDIFF(@end_date, ps.DatePay) <= 60 THEN '31-60 days'
            WHEN DATEDIFF(@end_date, ps.DatePay) <= 90 THEN '61-90 days'
            WHEN DATEDIFF(@end_date, ps.DatePay) <= 180 THEN '91-180 days'
            WHEN DATEDIFF(@end_date, ps.DatePay) <= 365 THEN '181-365 days'
            ELSE 'Over 365 days'
        END = '0-30 days' THEN 1
        WHEN CASE
            WHEN DATEDIFF(@end_date, ps.DatePay) <= 30 THEN '0-30 days'
            WHEN DATEDIFF(@end_date, ps.DatePay) <= 60 THEN '31-60 days'
            WHEN DATEDIFF(@end_date, ps.DatePay) <= 90 THEN '61-90 days'
            WHEN DATEDIFF(@end_date, ps.DatePay) <= 180 THEN '91-180 days'
            WHEN DATEDIFF(@end_date, ps.DatePay) <= 365 THEN '181-365 days'
            ELSE 'Over 365 days'
        END = '31-60 days' THEN 2
        WHEN CASE
            WHEN DATEDIFF(@end_date, ps.DatePay) <= 30 THEN '0-30 days'
            WHEN DATEDIFF(@end_date, ps.DatePay) <= 60 THEN '31-60 days'
            WHEN DATEDIFF(@end_date, ps.DatePay) <= 90 THEN '61-90 days'
            WHEN DATEDIFF(@end_date, ps.DatePay) <= 180 THEN '91-180 days'
            WHEN DATEDIFF(@end_date, ps.DatePay) <= 365 THEN '181-365 days'
            ELSE 'Over 365 days'
        END = '61-90 days' THEN 3
        WHEN CASE
            WHEN DATEDIFF(@end_date, ps.DatePay) <= 30 THEN '0-30 days'
            WHEN DATEDIFF(@end_date, ps.DatePay) <= 60 THEN '31-60 days'
            WHEN DATEDIFF(@end_date, ps.DatePay) <= 90 THEN '61-90 days'
            WHEN DATEDIFF(@end_date, ps.DatePay) <= 180 THEN '91-180 days'
            WHEN DATEDIFF(@end_date, ps.DatePay) <= 365 THEN '181-365 days'
            ELSE 'Over 365 days'
        END = '91-180 days' THEN 4
        WHEN CASE
            WHEN DATEDIFF(@end_date, ps.DatePay) <= 30 THEN '0-30 days'
            WHEN DATEDIFF(@end_date, ps.DatePay) <= 60 THEN '31-60 days'
            WHEN DATEDIFF(@end_date, ps.DatePay) <= 90 THEN '61-90 days'
            WHEN DATEDIFF(@end_date, ps.DatePay) <= 180 THEN '91-180 days'
            WHEN DATEDIFF(@end_date, ps.DatePay) <= 365 THEN '181-365 days'
            ELSE 'Over 365 days'
        END = '181-365 days' THEN 5
        ELSE 6
    END;

