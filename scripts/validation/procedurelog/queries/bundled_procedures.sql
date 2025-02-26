-- Bundled Procedures Query
-- Analyzes procedures that are commonly performed together (bundled)
-- CTEs used: common_pairs.sql, excluded_codes.sql, base_procedures.sql, payment_activity.sql, payment_analysis.sql
SELECT 
    1 as sort_order,
    'Common Procedure Pairs' AS analysis_type,
    proc1_code,
    proc1_desc,
    proc2_code,
    proc2_desc,
    pair_count,
    avg_pair_fee,
    total_pair_fee,
    NULL AS bundle_size,
    NULL AS visit_count,
    NULL AS total_procedures,
    NULL AS avg_procedures_per_visit,
    NULL AS avg_visit_fee,
    NULL AS total_fees,
    NULL AS total_paid,
    NULL AS payment_percentage,
    NULL AS fully_paid_visits,
    NULL AS fully_paid_pct
FROM CommonPairs

UNION ALL

SELECT 
    2 as sort_order,
    'Bundle Size Payment Analysis' AS analysis_type,
    NULL AS proc1_code,
    NULL AS proc1_desc,
    NULL AS proc2_code,
    NULL AS proc2_desc,
    NULL AS pair_count,
    NULL AS avg_pair_fee,
    NULL AS total_pair_fee,
    bundle_size,
    visit_count,
    total_procedures,
    avg_procedures_per_visit,
    avg_visit_fee,
    total_fees,
    total_paid,
    payment_percentage,
    fully_paid_visits,
    fully_paid_pct
FROM PaymentAnalysis
ORDER BY 
    sort_order,
    CASE 
        WHEN sort_order = 1 THEN pair_count
        WHEN sort_order = 2 THEN
            CASE bundle_size
                WHEN 'Single Procedure' THEN 1
                WHEN '2-3 Procedures' THEN 2
                WHEN '4-5 Procedures' THEN 3
                WHEN '6+ Procedures' THEN 4
            END
    END DESC;
