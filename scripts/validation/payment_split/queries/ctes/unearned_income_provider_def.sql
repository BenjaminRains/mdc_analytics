-- ProviderDef: Gets Provider information from the provider table
-- Creates a provider name from first and last name columns
-- Dependencies: None
-- Date filter: None (not date dependent)

ProviderDef AS (
    -- Get Provider information from the provider table, not definition table
    SELECT 
        ProvNum,
        CONCAT(FName, ' ', LName) AS ProviderName
    FROM provider
    WHERE ProvNum IN (
        SELECT DISTINCT ProvNum 
        FROM paysplit
        WHERE UnearnedType != 0
    )
) 