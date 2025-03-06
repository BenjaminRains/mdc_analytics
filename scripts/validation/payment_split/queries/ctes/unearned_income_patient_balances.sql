-- CTE for patient balances
-- Purpose: Provides patient account balance information with aging breakdown
-- Dependencies: None
-- Date filter: @end_date

PatientBalances AS (
    SELECT 
        p.PatNum,
        p.BalTotal AS TotalBalance,
        -- Use aging brackets directly from patient table
        -- These are maintained by the OpenDental system
        p.Bal_0_30 AS Balance0to30,
        p.Bal_31_60 AS Balance31to60,
        p.Bal_61_90 AS Balance61to90,
        p.BalOver90 AS BalanceOver90,
        
        -- Insurance estimate if available
        p.InsEst AS InsuranceEstimate,
        
        -- Calculate percentages of total balance in each aging bucket
        CASE WHEN p.BalTotal = 0 THEN 0 ELSE 
            (p.Bal_0_30 / p.BalTotal * 100)
        END AS PercentCurrent,
        
        CASE WHEN p.BalTotal = 0 THEN 0 ELSE 
            (p.Bal_31_60 / p.BalTotal * 100)
        END AS Percent31to60,
        
        CASE WHEN p.BalTotal = 0 THEN 0 ELSE 
            (p.Bal_61_90 / p.BalTotal * 100)
        END AS Percent61to90,
        
        CASE WHEN p.BalTotal = 0 THEN 0 ELSE 
            (p.BalOver90 / p.BalTotal * 100)
        END AS PercentOver90
    FROM patient p
    WHERE p.BalTotal <> 0
) 