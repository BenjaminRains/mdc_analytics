-- UnearntypeDef: Gets UnearnedType definitions from the definition table
-- Extracts the name of the unearned income type based on DefNum
-- Includes all types:
-- Type 0: Regular payments (88.9% of splits) - Direct application to procedures
-- Type 288: Prepayments (10.9% of splits) - Payment received before procedure
-- Type 439: Treatment Plan Prepayments (0.2% of splits) - Specific to treatment plan deposits
-- Dependencies: None
-- Date filter: None (not date dependent)

UnearntypeDef AS (
    -- Get UnearnedType definitions for all types
    SELECT 
        DefNum,
        ItemName AS UnearnedTypeName
    FROM definition
    WHERE DefNum IN (
        SELECT DISTINCT UnearnedType 
        FROM paysplit
    )
    
    UNION
    
    -- Add Type 0 with a custom name since it might not be in the definition table
    SELECT 
        0 AS DefNum,
        'Regular Payment' AS UnearnedTypeName
    WHERE NOT EXISTS (
        SELECT 1 FROM definition WHERE DefNum = 0
    )
) 