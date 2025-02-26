-- VISIT COUNTS
-- Identifies patient visits with multiple procedures
-- Used for analyzing bundling opportunities and visit optimization
-- dependent CTEs: BaseProcedures
VisitCounts AS (
    SELECT
        PatNum,
        ProcDate,
        COUNT(*) AS procedure_count,
        SUM(ProcFee) AS total_fee
    FROM BaseProcedures
    GROUP BY PatNum, ProcDate
    HAVING COUNT(*) > 1
)