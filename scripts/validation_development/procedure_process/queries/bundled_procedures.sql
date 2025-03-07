-- Bundled Procedures Query
-- Analyzes procedures that are commonly performed together (bundled)
-- Dependent CTEs: excluded_codes.sql, base_procedures.sql, procedure_pairs.sql, common_pairs.sql
SELECT 
    'Common Procedure Pairs' AS analysis_type,
    cp.proc1_code,
    pc1.Descript AS proc1_desc,
    cp.proc2_code,
    pc2.Descript AS proc2_desc,
    cp.pair_count,
    cp.avg_combined_fee AS avg_pair_fee,
    (cp.avg_proc1_fee + cp.avg_proc2_fee) AS total_pair_fee
FROM CommonPairs cp
LEFT JOIN procedurecode pc1 ON cp.proc1_code = pc1.ProcCode
LEFT JOIN procedurecode pc2 ON cp.proc2_code = pc2.ProcCode
ORDER BY cp.pair_count DESC;
