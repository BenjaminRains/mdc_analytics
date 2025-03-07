-- UnearnedIncomePatientBalances: CTE for patient balances
-- Purpose: Provides patient account balance information with aging breakdown
-- Dependencies: None
-- Date filter: @end_date

PatientBalances AS (
    SELECT 
        p.PatNum,
        p.BalTotal AS total_balance,
        -- Use aging brackets directly from patient table
        -- These are maintained by the OpenDental system
        p.Bal_0_30 AS balance_0_to_30,
        p.Bal_31_60 AS balance_31_to_60,
        p.Bal_61_90 AS balance_61_to_90,
        p.BalOver90 AS balance_over_90,
        
        -- Insurance estimate if available
        p.InsEst AS insurance_estimate,
        
        -- Calculate percentages of total balance in each aging bucket
        CASE WHEN p.BalTotal = 0 THEN 0 ELSE 
            (p.Bal_0_30 / p.BalTotal * 100)
        END AS percent_current,
        
        CASE WHEN p.BalTotal = 0 THEN 0 ELSE 
            (p.Bal_31_60 / p.BalTotal * 100)
        END AS percent_31_to_60,
        
        CASE WHEN p.BalTotal = 0 THEN 0 ELSE 
            (p.Bal_61_90 / p.BalTotal * 100)
        END AS percent_61_to_90,
        
        CASE WHEN p.BalTotal = 0 THEN 0 ELSE 
            (p.BalOver90 / p.BalTotal * 100)
        END AS percent_over_90
    FROM patient p
    WHERE p.BalTotal <> 0
) 