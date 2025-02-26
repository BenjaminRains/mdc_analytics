-- Fee Validation Query
-- Analyzes procedure fees across different ranges, categories, and relationships
-- to fee schedules and adjustments
-- CTEs used: ExcludedCodes, BaseProcedures, StandardFees, ProcedureAdjustments, PaymentActivity, PatientResponsibility, FeeRanges
-- Date filter: 2024-01-01 to 2025-01-01
SELECT
    fee_range,
    COUNT(*) AS procedure_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS percentage,
    MIN(ProcFee) AS min_fee,
    MAX(ProcFee) AS max_fee,
    ROUND(AVG(ProcFee), 2) AS avg_fee,
    COUNT(DISTINCT ProcCode) AS unique_codes,
    -- Status breakdown
    SUM(CASE WHEN ProcStatus = 2 THEN 1 ELSE 0 END) AS completed_count,
    SUM(CASE WHEN ProcStatus = 1 THEN 1 ELSE 0 END) AS planned_count,
    -- Excluded codes metrics
    SUM(CASE WHEN CodeCategory = 'Excluded' THEN 1 ELSE 0 END) AS excluded_count,
    ROUND(100.0 * SUM(CASE WHEN CodeCategory = 'Excluded' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS excluded_pct,
    -- Fee relationship to standard
    SUM(CASE WHEN fee_relationship = 'Matches Standard' THEN 1 ELSE 0 END) AS standard_fee_count,
    ROUND(100.0 * SUM(CASE WHEN fee_relationship = 'Matches Standard' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS standard_pct,
    -- Patient responsibility
    SUM(CASE WHEN responsibility_category = 'Fully Covered' THEN 1 ELSE 0 END) AS fully_covered_count,
    ROUND(100.0 * SUM(CASE WHEN responsibility_category = 'Fully Covered' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS fully_covered_pct
FROM FeeRanges
GROUP BY fee_range
ORDER BY 
    CASE fee_range
        WHEN 'Zero Fee' THEN 1
        WHEN 'Under $100' THEN 2
        WHEN '$100-$249' THEN 3
        WHEN '$250-$499' THEN 4
        WHEN '$500-$999' THEN 5
        WHEN '$1000-$1999' THEN 6
        WHEN '$2000+' THEN 7
    END;
