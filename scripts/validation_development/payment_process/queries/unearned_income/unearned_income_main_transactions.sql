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
<<include:ctes/unearned_income_unearned_type_def.sql>>
<<include:ctes/unearned_income_pay_type_def.sql>>
<<include:ctes/unearned_income_provider_defs.sql>>
<<include:ctes/unearned_income_patient_balances.sql>>

-- Main query to extract all relevant data for analysis
SELECT
    -- Transaction Info
    ps.SplitNum,
    ps.DatePay AS payment_date,
    ps.UnearnedType,
    COALESCE(UnearnedIncomeUnearnedTypeDef.unearned_type_name, 'Unknown') AS unearned_type_name,
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
    COALESCE(UnearnedIncomePayTypeDef.pay_type_name, 'Income Transfer') AS pay_type_name,
    pm.PayDate,
    pm.PayNote,
    
    -- Patient Info
    ps.PatNum,
    pt.LName AS last_name,
    pt.FName AS first_name,
    CONCAT(pt.LName, ', ', pt.FName) AS patient_name,
    
    -- Provider Info
    ps.ProvNum,
    COALESCE(UnearnedIncomeProviderDefs.provider_name, 'Unassigned') AS provider_name,
    
    -- Balance Info - Using detailed aging data from patient table
    UnearnedIncomePatientBalances.total_balance AS current_patient_balance,
    UnearnedIncomePatientBalances.balance_0_to_30 AS balance_0_to_30_days,
    UnearnedIncomePatientBalances.balance_31_to_60 AS balance_31_to_60_days,
    UnearnedIncomePatientBalances.balance_61_to_90 AS balance_61_to_90_days,
    UnearnedIncomePatientBalances.balance_over_90 AS balance_over_90_days,
    UnearnedIncomePatientBalances.insurance_estimate AS insurance_estimate,
    UnearnedIncomePatientBalances.percent_current AS percent_current_balance,
    UnearnedIncomePatientBalances.percent_31_to_60 AS percent_31_to_60_balance,
    UnearnedIncomePatientBalances.percent_61_to_90 AS percent_61_to_90_balance,
    UnearnedIncomePatientBalances.percent_over_90 AS percent_over_90_balance,
    
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
LEFT JOIN UnearnedIncomeUnearnedTypeDef ON UnearnedIncomeUnearnedTypeDef.DefNum = ps.UnearnedType
LEFT JOIN UnearnedIncomePayTypeDef ON UnearnedIncomePayTypeDef.DefNum = pm.PayType
LEFT JOIN UnearnedIncomeProviderDefs ON UnearnedIncomeProviderDefs.ProvNum = ps.ProvNum
LEFT JOIN UnearnedIncomePatientBalances ON UnearnedIncomePatientBalances.PatNum = ps.PatNum
WHERE 
    -- Date filter can be adjusted as needed
    ps.DatePay BETWEEN @start_date AND @end_date
ORDER BY ps.DatePay; 