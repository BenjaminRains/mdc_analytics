-- PROVIDER BASE
-- Core provider information and attributes
-- Used as the foundation for provider-based analytics
-- Date filter: {{START_DATE}} to {{END_DATE}}
-- Dependent CTEs:

ProviderBase AS (
    SELECT DISTINCT 
        provider.ProvNum,
        provider.Abbr AS ProviderAbbr,
        CONCAT(
            COALESCE(provider.PreferredName, provider.FName),
            CASE 
                WHEN provider.MI > '' THEN CONCAT(' ', provider.MI)
                ELSE ''
            END,
            ' ',
            provider.LName,
            CASE 
                WHEN provider.Suffix > '' THEN CONCAT(' ', provider.Suffix)
                ELSE ''
            END
        ) AS ProviderName,
        CASE provider.Specialty
            WHEN 0 THEN 'General'
            WHEN 1 THEN 'Hygienist'
            WHEN 2 THEN 'Endodontist'
            WHEN 3 THEN 'Pediatric'
            WHEN 4 THEN 'Periodontist'
            WHEN 5 THEN 'Prosthodontist'
            WHEN 6 THEN 'Orthodontist'
            WHEN 7 THEN 'Denturist'
            WHEN 8 THEN 'Surgery'
            WHEN 9 THEN 'Assistant'
            ELSE 'Other'
        END AS Specialty,
        provider.ProvStatus,
        provider.IsHidden,
        provider.IsHiddenReport,
        COALESCE(provider.HourlyProdGoalAmt, 0) AS HourlyProdGoalAmt,
        provider.DateTerm,
        -- Additional fields for filtering and grouping
        CASE 
            WHEN provider.DateTerm = '0001-01-01' THEN NULL 
            ELSE provider.DateTerm 
        END AS TerminationDate,
        provider.IsSecondary,
        -- Normalize production goal (handle nulls and zeros)
        CASE 
            WHEN COALESCE(provider.HourlyProdGoalAmt, 0) <= 0 THEN NULL
            ELSE COALESCE(provider.HourlyProdGoalAmt, 0)
        END AS NormalizedProdGoal
    FROM provider
    -- Join to procedurelog to get only providers with activity in date range
    INNER JOIN procedurelog pl ON pl.ProvNum = provider.ProvNum
    WHERE pl.ProcDate BETWEEN '{{START_DATE}}' AND '{{END_DATE}}'
    AND provider.IsHidden = 0
) 