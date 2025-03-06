/*
Patient Payment Balance Report Query
===========================

Purpose:
- Generate patient-level balance report with payment type distribution
- Shows both regular payments (Type 0) and unearned income (Types 288, 439)
- Combines patient table's aging data with payment calculations
- Shows prepayment, treatment plan prepayment, and other amounts with aging information

NOTE FOR PANDAS ANALYSIS:
- This comprehensive patient-level data provides excellent insights for payment pattern analysis
- Required data transformations:
  1. Currency columns: df[col] = df[col].str.replace(',', '').str.replace('$', '').astype(float)
  2. Percentage columns: df[col] = df[col].str.rstrip('%').astype(float) / 100
  3. Date columns: df['Last Payment Date'] = pd.to_datetime(df['Last Payment Date'])
- Key analytical approaches:
  1. Patient segmentation: df[df['Prepayment Amount'] > 0], df[df['Total Patient Balance'] < 0]
  2. Payment distribution analysis: df.groupby(['% Regular Payments']).agg({'Patient Number': 'count'})
  3. Aging analysis: correlation between prepayments and aging buckets
  4. Investigate negative balances with large prepayments (potential credit situations)
  5. Analyze recency of payments with 'Days Since Last Payment'
- Watch for "-0.00" values which indicate small negative values that were rounded

NOTE FOR EXECUTION IN DBEAVER:
- This query uses multiple statements with temporary tables
- In DBeaver, make sure to execute each statement separately or use "Execute Script" (F5) not "Execute Statement" (F9)
- Alternatively, break this query into three separate queries for execution

Dependencies:
- Requires only @start_date and @end_date variables, not CTEs

Date Filter: Uses @end_date as cutoff date for balances
*/

-- Set date parameters for testing (comment out when using in a script)
-- SET @start_date = '2023-01-01';
-- SET @end_date = '2024-12-31';

-- Step 1: Create a temporary table with payment balances by type
DROP TEMPORARY TABLE IF EXISTS temp_patient_balances;

CREATE TEMPORARY TABLE temp_patient_balances AS
SELECT
    ps.PatNum,
    -- Regular payments
    SUM(CASE WHEN ps.UnearnedType = 0 THEN ps.SplitAmt ELSE 0 END) AS regular_payment_amount,
    -- Unearned income types
    SUM(CASE WHEN ps.UnearnedType = 288 THEN ps.SplitAmt ELSE 0 END) AS prepayment_amount,
    SUM(CASE WHEN ps.UnearnedType = 439 THEN ps.SplitAmt ELSE 0 END) AS tp_prepayment_amount,
    SUM(CASE WHEN ps.UnearnedType NOT IN (0, 288, 439) AND ps.UnearnedType != 0 THEN ps.SplitAmt ELSE 0 END) AS other_unearned_amount,
    -- Subtotals
    SUM(CASE WHEN ps.UnearnedType != 0 THEN ps.SplitAmt ELSE 0 END) AS total_unearned_amount,
    SUM(CASE WHEN ps.UnearnedType = 0 THEN ps.SplitAmt ELSE 0 END) AS total_earned_amount,
    -- Total of all payments
    SUM(ps.SplitAmt) AS total_payment_amount,
    -- Last payment date
    MAX(ps.DatePay) AS last_payment_date
FROM paysplit ps
WHERE ps.DatePay <= @end_date
GROUP BY ps.PatNum;

-- Step 2: Create a temporary table with transaction counts
DROP TEMPORARY TABLE IF EXISTS temp_transaction_counts;

CREATE TEMPORARY TABLE temp_transaction_counts AS
SELECT
    PatNum,
    COUNT(*) AS total_transaction_count,
    SUM(CASE WHEN UnearnedType = 0 THEN 1 ELSE 0 END) AS regular_transaction_count,
    SUM(CASE WHEN UnearnedType != 0 THEN 1 ELSE 0 END) AS unearned_transaction_count
FROM paysplit
WHERE DatePay BETWEEN @start_date AND @end_date
GROUP BY PatNum;

-- Step 3: Join the temporary tables with patient information and aging data for the final report
SELECT
    pb.PatNum AS 'Patient Number',
    CONCAT(pt.LName, ', ', pt.FName) AS 'Patient Name',
    
    -- Regular Payment Information
    FORMAT(pb.regular_payment_amount, 2) AS 'Regular Payment Amount',
    FORMAT(pb.regular_payment_amount / NULLIF(pb.total_payment_amount, 0) * 100, 1) AS '% Regular Payments',
    
    -- Unearned Income Information
    FORMAT(pb.prepayment_amount, 2) AS 'Prepayment Amount',
    FORMAT(pb.tp_prepayment_amount, 2) AS 'Treatment Plan Prepayment Amount',
    FORMAT(pb.other_unearned_amount, 2) AS 'Other Unearned Amount',
    FORMAT(pb.total_unearned_amount, 2) AS 'Total Unearned Amount',
    FORMAT(pb.total_unearned_amount / NULLIF(pb.total_payment_amount, 0) * 100, 1) AS '% Unearned Payments',
    
    -- Payment total
    FORMAT(pb.total_payment_amount, 2) AS 'Total Payment Amount',
    
    -- Add aging information from patient table
    FORMAT(pt.Bal_0_30, 2) AS 'Current Balance (0-30)',
    FORMAT(pt.Bal_31_60, 2) AS 'Balance 31-60 Days',
    FORMAT(pt.Bal_61_90, 2) AS 'Balance 61-90 Days',
    FORMAT(pt.BalOver90, 2) AS 'Balance Over 90 Days',
    FORMAT(pt.BalTotal, 2) AS 'Total Patient Balance',
    FORMAT(pt.InsEst, 2) AS 'Insurance Estimate',
    
    -- Calculate balance vs. unearned ratios
    CASE 
        WHEN pt.BalTotal = 0 THEN '0%'
        ELSE CONCAT(FORMAT((pb.total_unearned_amount / pt.BalTotal) * 100, 1), '%') 
    END AS 'Unearned % of Total Balance',
    
    -- Transaction counts
    tc.total_transaction_count AS 'Total Transaction Count',
    tc.regular_transaction_count AS 'Regular Transaction Count',
    tc.unearned_transaction_count AS 'Unearned Transactions Count',
    
    -- Additional metrics
    pb.last_payment_date AS 'Last Payment Date',
    DATEDIFF(@end_date, pb.last_payment_date) AS 'Days Since Last Payment'
FROM temp_patient_balances pb
INNER JOIN patient pt ON pt.PatNum = pb.PatNum
LEFT JOIN temp_transaction_counts tc ON tc.PatNum = pb.PatNum
ORDER BY pb.total_payment_amount DESC; 