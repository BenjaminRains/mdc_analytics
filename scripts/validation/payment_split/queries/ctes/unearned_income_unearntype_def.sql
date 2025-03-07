-- UnearnedIncomeUnearnedTypeDef: Gets UnearnedType definitions from the definition table
-- Extracts the name of the unearned income type based on DefNum
-- 
-- !!! IMPORTANT NOTE FOR ANALYSIS !!!
-- Type 0 does NOT exist in the definition table but represents 88.9% of all paysplit records.
-- We are manually defining it as "Regular Payment" in this query, but this requires further investigation:
--   1. Why is the most common payment type (0) not defined in the definition table?
--   2. Are Type 0 payments truly "unearned income" or are they being miscategorized?
--   3. The clinic may not be aware they're only explicitly defining prepayment types (288, 439)
--   4. Pandas analysis should specifically investigate Type 0 to validate this assumption
--
-- Includes all types:
-- Type 0: Default payment type (99.31% of splits) - NOT IN DEFINITION TABLE
--         Most (62.7%) are NOT directly applied to procedures
-- Type 288: Prepayments (10.9% of splits) - Payment received before procedure
-- Type 439: Treatment Plan Prepayments (0.2% of splits) - Specific to treatment plan deposits
-- Dependencies: None
-- Date filter: None (not date dependent)

UnearnedIncomeUnearnedTypeDef AS (
    -- Get UnearnedType definitions for all types
    SELECT 
        DefNum,
        ItemName AS unearned_type_name
    FROM definition
    WHERE DefNum IN (
        SELECT DISTINCT UnearnedType 
        FROM paysplit
    )
    
    UNION
    
    -- Add Type 0 with a custom name since it might not be in the definition table
    SELECT 
        0 AS DefNum,
        'Regular Payment' AS unearned_type_name
    WHERE NOT EXISTS (
        SELECT 1 FROM definition WHERE DefNum = 0
    )
) 