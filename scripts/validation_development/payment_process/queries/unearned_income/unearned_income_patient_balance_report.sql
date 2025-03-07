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
  3. Date columns: df['last_payment_date'] = pd.to_datetime(df['last_payment_date'])
- Key analytical approaches:
  1. Patient segmentation: df[df['prepayment_amount'] > 0], df[df['total_patient_balance'] < 0]
  2. Payment distribution analysis: df.groupby(['percent_regular_payments']).agg({'patient_number': 'count'})
  3. Aging analysis: correlation between prepayments and aging buckets
  4. Investigate negative balances with large prepayments (potential credit situations)
  5. Analyze recency of payments with 'days_since_last_payment'
- Watch for "-0.00" values which indicate small negative values that were rounded
*/

-- Date Filter: Uses @end_date as cutoff date for balances
-- Include dependent CTEs
<<include:unearned_income_patient_payment_summary.sql>>
<<include:unearned_income_transaction_counts.sql>>

SELECT
    pb.PatNum AS patient_number,
    CONCAT(pt.LName, ', ', pt.FName) AS patient_name,
    
    -- Regular Payment Information
    FORMAT(pb.regular_payment_amount, 2) AS regular_payment_amount,
    FORMAT(pb.regular_payment_amount / NULLIF(pb.total_payment_amount, 0) * 100, 1) AS percent_regular_payments,
    
    -- Unearned Income Information
    FORMAT(pb.prepayment_amount, 2) AS prepayment_amount,
    FORMAT(pb.tp_prepayment_amount, 2) AS treatment_plan_prepayment_amount,
    FORMAT(pb.other_unearned_amount, 2) AS other_unearned_amount,
    FORMAT(pb.total_unearned_amount, 2) AS total_unearned_amount,
    FORMAT(pb.total_unearned_amount / NULLIF(pb.total_payment_amount, 0) * 100, 1) AS percent_unearned_payments,
    
    -- Payment total
    FORMAT(pb.total_payment_amount, 2) AS total_payment_amount,
    
    -- Add aging information from patient table
    FORMAT(pt.Bal_0_30, 2) AS current_balance_0_30,
    FORMAT(pt.Bal_31_60, 2) AS balance_31_60_days,
    FORMAT(pt.Bal_61_90, 2) AS balance_61_90_days,
    FORMAT(pt.BalOver90, 2) AS balance_over_90_days,
    FORMAT(pt.BalTotal, 2) AS total_patient_balance,
    FORMAT(pt.InsEst, 2) AS insurance_estimate,
    
    -- Calculate balance vs. unearned ratios
    CASE 
        WHEN pt.BalTotal = 0 THEN '0%'
        ELSE CONCAT(FORMAT((pb.total_unearned_amount / pt.BalTotal) * 100, 1), '%') 
    END AS unearned_percent_of_total_balance,
    
    -- Transaction counts
    tc.total_transaction_count AS total_transaction_count,
    tc.regular_transaction_count AS regular_transaction_count,
    tc.unearned_transaction_count AS unearned_transaction_count,
    
    -- Additional metrics
    pb.last_payment_date AS last_payment_date,
    DATEDIFF(@end_date, pb.last_payment_date) AS days_since_last_payment
FROM UnearnedIncomePatientPaymentSummary pb
INNER JOIN patient pt ON pt.PatNum = pb.PatNum
LEFT JOIN UnearnedIncomeTransactionCounts tc ON tc.PatNum = pb.PatNum
ORDER BY pb.total_payment_amount DESC 