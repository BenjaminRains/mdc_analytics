/*
Main Payment Transactions Query
======================================

Purpose:
- Extract all payment transactions with detailed information
- Includes regular payments (Type 0) and unearned income (Types 288, 439, etc.)
- Joins payment, patient, provider, and definition tables for complete context
- Classifies income by type and category
- Includes detailed aging information from patient table

Date Filter: @start_date to @end_date
*/
-- Include dependent CTEs
<<include:unearned_income_unearned_type_def.sql>>
<<include:unearned_income_pay_type_def.sql>>
<<include:unearned_income_provider_defs.sql>>
<<include:unearned_income_patient_balances.sql>>

-- Main query to extract all relevant data for analysis
SELECT
    -- Transaction Info
    ps.SplitNum,
    ps.DatePay AS payment_date,
    ps.UnearnedType,
    COALESCE(ud.UnearnedTypeName, 'Unknown') AS unearned_type_name,
    ps.SplitAmt,
    CASE 
        WHEN ps.UnearnedType = 0 THEN 'Regular Payment'
        WHEN ps.UnearnedType = 288 THEN 'Prepayment'
        WHEN ps.UnearnedType = 439 THEN 'Treatment Plan Prepayment'
        ELSE 'Other Unearned Type'
    END AS category,
    
    -- Payment Info
    pm.PayNum,
    pm.PayAmt AS total_payment_amount,
    pm.PayType,
    COALESCE(pd.PayTypeName, 'Income Transfer') AS pay_type_name,
    pm.PayDate,
    pm.PayNote,
    
    -- Patient Info
    ps.PatNum,
    pt.LName AS last_name,
    pt.FName AS first_name,
    CONCAT(pt.LName, ', ', pt.FName) AS patient_name,
    
    -- Provider Info
    ps.ProvNum,
    COALESCE(prvd.ProviderName, 'Unassigned') AS provider_name,
    
    -- Balance Info - Using detailed aging data from patient table
    pb.TotalBalance AS current_patient_balance,
    pb.Balance0to30 AS balance_0_to_30_days,
    pb.Balance31to60 AS balance_31_to_60_days,
    pb.Balance61to90 AS balance_61_to_90_days,
    pb.BalanceOver90 AS balance_over_90_days,
    pb.InsuranceEstimate AS insurance_estimate,
    pb.PercentCurrent AS percent_current_balance,
    pb.Percent31to60 AS percent_31_to_60_balance,
    pb.Percent61to90 AS percent_61_to_90_balance,
    pb.PercentOver90 AS percent_over_90_balance,
    
    -- Clinic Info
    ps.ClinicNum,
    
    -- Procedure Info if available
    ps.ProcNum,
    
    -- Is this unearned income?
    CASE WHEN ps.UnearnedType = 0 THEN 'No' ELSE 'Yes' END AS is_unearned_income,
    
    -- Dates for aging analysis
    DATEDIFF(@end_date, ps.DatePay) AS days_since_payment
FROM paysplit ps
JOIN payment pm ON pm.PayNum = ps.PayNum
JOIN patient pt ON pt.PatNum = ps.PatNum
LEFT JOIN UnearntypeDef ud ON ud.DefNum = ps.UnearnedType
LEFT JOIN PayTypeDef pd ON pd.DefNum = pm.PayType
LEFT JOIN ProviderDef prvd ON prvd.ProvNum = ps.ProvNum
LEFT JOIN PatientBalances pb ON pb.PatNum = ps.PatNum
WHERE 
    -- Date filter can be adjusted as needed
    ps.DatePay BETWEEN @start_date AND @end_date
ORDER BY ps.DatePay; 