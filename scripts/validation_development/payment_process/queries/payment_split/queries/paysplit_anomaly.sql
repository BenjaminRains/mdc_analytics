{% import "cte_macros.sql" as macros %}

{{ macros.begin_ctes() }}
{{ macros.include_cte("payment_split_analysis.sql", True) }}
{{ macros.include_cte("problem_claim_analysis.sql") }}

SELECT * FROM (
    SELECT * FROM PaymentSplitAnalysis
    UNION ALL
    SELECT * FROM ProblemClaimAnalysis
) combined_results
ORDER BY 
    record_type,
    has_known_oversplit_claims DESC,
    is_suspicious DESC,
    split_count DESC;
