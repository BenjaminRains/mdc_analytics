/*
Duplicate Joins Analysis
========================

Purpose:
- Identifies payments with excessive splits or claim linkages
- Helps detect data quality issues and oversplit claims
- Provides both payment-level and claim-level details in a single result set

Key metrics:
- split_count vs claimproc_count ratios
- Known problematic claim detection
- Split pattern suspicion scoring
*/
-- Date filter: Use @start_date to @end_date variables
-- Include CTEs
<<include:ctes/payment_split_analysis.sql>>
<<include:ctes/problem_claim_analysis.sql>>

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
