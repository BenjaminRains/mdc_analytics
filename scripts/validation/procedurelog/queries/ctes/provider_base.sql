-- PROVIDER BASE
-- Core provider information and attributes
-- Used as the foundation for provider-based analytics
-- No dependencies

ProviderBase AS (
    SELECT 
        p.ProvNum,
        p.Abbr AS ProviderAbbr,
        CONCAT(
            COALESCE(p.PreferredName, p.FName),
            CASE 
                WHEN p.MI > '' THEN CONCAT(' ', p.MI)
                ELSE ''
            END,
            ' ',
            p.LName,
            CASE 
                WHEN p.Suffix > '' THEN CONCAT(' ', p.Suffix)
                ELSE ''
            END
        ) AS ProviderName,
        CASE p.Specialty
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
        p.ProvStatus,
        p.IsHidden,
        p.IsHiddenReport,
        p.HourlyProdGoalAmt,
        p.DateTerm,
        -- Additional fields for filtering and grouping
        CASE 
            WHEN p.DateTerm = '0001-01-01' THEN NULL 
            ELSE p.DateTerm 
        END AS TerminationDate,
        p.IsSecondary,
        -- Normalize production goal (handle nulls and zeros)
        CASE 
            WHEN p.HourlyProdGoalAmt <= 0 THEN NULL
            ELSE p.HourlyProdGoalAmt
        END AS NormalizedProdGoal
    FROM provider p
    WHERE 
        p.IsNotPerson = 0  -- Exclude non-person providers
        AND p.ProvStatus = 0  -- Active providers only
        AND p.IsHidden = 0  -- Not hidden
        AND (p.DateTerm = '0001-01-01' OR p.DateTerm >= '{{START_DATE}}')  -- Not terminated before period
) 