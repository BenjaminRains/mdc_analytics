-- UnearnedIncomeProviderDefs: CTE for provider definitions
-- Purpose: Provides a lookup for provider names from provider table
-- Dependencies: None
-- Date filter: None

UnearnedIncomeProviderDefs AS (
    SELECT 
        ProvNum,
        FName,
        LName,
        CONCAT(FName, ' ', LName) AS provider_name,
        Specialty
    FROM provider
    WHERE ProvNum IN (
        SELECT DISTINCT ProvNum 
        FROM paysplit
    )
    
    UNION
    
    -- Include a fallback for unassigned provider (0)
    SELECT 
        0 AS ProvNum,
        'Unassigned' AS FName,
        'Provider' AS LName,
        'Unassigned Provider' AS provider_name,
        0 AS Specialty
    WHERE NOT EXISTS (
        SELECT 1 FROM provider WHERE ProvNum = 0
    )
) 