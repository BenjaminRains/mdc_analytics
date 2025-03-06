-- PayTypeDef: Gets PayType definitions from the definition table
-- Extracts the name of the payment type based on DefNum
-- Dependencies: None
-- Date filter: None (not date dependent)

PayTypeDef AS (
    -- Get PayType definitions once
    SELECT 
        DefNum,
        ItemName AS PayTypeName
    FROM definition
    WHERE DefNum IN (
        SELECT DISTINCT p.PayType 
        FROM payment p
        JOIN paysplit ps ON p.PayNum = ps.PayNum
        WHERE ps.UnearnedType != 0
    )
) 