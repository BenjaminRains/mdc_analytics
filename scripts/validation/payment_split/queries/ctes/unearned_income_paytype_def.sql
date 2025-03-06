-- PayTypeDef: Gets PayType definitions from the definition table
-- Extracts the name of the payment type based on DefNum
-- Dependencies: None
-- Date filter: None (not date dependent)

PayTypeDef AS (
    -- Get PayType definitions once
    SELECT 
        DefNum,
        ItemName AS PayTypeName,
        ItemValue
    FROM definition
    WHERE Category = 8 -- Payment Type category in OpenDental
    AND DefNum IN (
        SELECT DISTINCT p.PayType 
        FROM payment p
        JOIN paysplit ps ON p.PayNum = ps.PayNum
        -- Include ALL payment types, not just unearned income types
    )
    
    UNION
    
    -- Include a fallback for any payment types not in definition table
    SELECT 
        0 AS DefNum,
        'Unknown' AS PayTypeName,
        '' AS ItemValue
    WHERE NOT EXISTS (
        SELECT 1 FROM definition WHERE DefNum = 0 AND Category = 8
    )
) 