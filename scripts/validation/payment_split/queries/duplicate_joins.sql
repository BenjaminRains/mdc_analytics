<<include:payment_level_metrics.sql>>
<<include:claim_metrics.sql>>
<<include:payment_split_analysis.sql>>
<<include:problem_claim_details.sql>>
<<include:problem_claim_analysis.sql>>
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
