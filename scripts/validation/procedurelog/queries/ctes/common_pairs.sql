-- COMMON PAIRS
-- Counts the most frequent procedure pairs and their associated fees
-- Used for bundling analysis and procedure combination patterns
-- dependent CTEs: procedure_pairs.sql
CommonPairs AS (
    SELECT 
        proc1_code,
        proc2_code,
        COUNT(*) AS pair_count,
        AVG(proc1_fee) AS avg_proc1_fee,
        AVG(proc2_fee) AS avg_proc2_fee,
        AVG(combined_fee) AS avg_combined_fee
    FROM ProcedurePairs
    GROUP BY proc1_code, proc2_code
)