/*
Main Payment Transactions Query
======================================

Purpose:
- Extract all payment transactions with detailed information
- Includes regular payments (Type 0) and unearned income (Types 288, 439, etc.)
- Joins payment, patient, provider, and definition tables for complete context
- Classifies income by type and category
- Includes detailed aging information from patient table

Dependencies:
- UnearntypeDef
- PayTypeDef
- ProviderDef
- PatientBalances

Date Filter: @start_date to @end_date
*/

-- Main query to extract all relevant data for analysis
SELECT
    -- Transaction Info
    ps.SplitNum,
    ps.DatePay AS PaymentDate,
    ps.UnearnedType,
    COALESCE(ud.UnearnedTypeName, 'Unknown') AS UnearnedTypeName,
    ps.SplitAmt,
    CASE 
        WHEN ps.UnearnedType = 0 THEN 'Regular Payment'
        WHEN ps.UnearnedType = 288 THEN 'Prepayment'
        WHEN ps.UnearnedType = 439 THEN 'Treatment Plan Prepayment'
        ELSE 'Other Unearned Type'
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
    
    -- Balance Info - Using detailed aging data from patient table
    pb.TotalBalance AS CurrentPatientBalance,
    pb.Balance0to30 AS Balance0to30Days,
    pb.Balance31to60 AS Balance31to60Days,
    pb.Balance61to90 AS Balance61to90Days,
    pb.BalanceOver90 AS BalanceOver90Days,
    pb.InsuranceEstimate AS InsuranceEstimate,
    pb.PercentCurrent AS PercentCurrentBalance,
    pb.Percent31to60 AS Percent31to60Balance,
    pb.Percent61to90 AS Percent61to90Balance,
    pb.PercentOver90 AS PercentOver90Balance,
    
    -- Clinic Info
    ps.ClinicNum,
    
    -- Procedure Info if available
    ps.ProcNum,
    
    -- Is this unearned income?
    CASE WHEN ps.UnearnedType = 0 THEN 'No' ELSE 'Yes' END AS IsUnearnedIncome,
    
    -- Dates for aging analysis
    DATEDIFF(@end_date, ps.DatePay) AS DaysSincePayment
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