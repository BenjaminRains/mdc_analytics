-- Fee Relationship Analysis
-- Examines how procedure fees compare to standard fee schedules
-- CTEs used: ExcludedCodes, BaseProcedures, StandardFees
-- Date filter: 2024-01-01 to 2025-01-01
SELECT
    fee_relationship,
    COUNT(*) AS procedure_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS percentage,
    MIN(recorded_fee) AS min_fee,
    MAX(recorded_fee) AS max_fee,
    ROUND(AVG(recorded_fee), 2) AS avg_fee,
    COUNT(DISTINCT CodeNum) AS unique_codes
FROM StandardFees
GROUP BY fee_relationship
ORDER BY procedure_count DESC; 