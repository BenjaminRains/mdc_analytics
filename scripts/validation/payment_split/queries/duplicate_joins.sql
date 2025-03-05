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

-- Note: CTEs from ctes.sql are automatically prepended by the export script
-- Date filter: Uses @start_date to @end_date

, PaymentSplitAnalysis AS (
    -- Base payment split analysis
    SELECT 
        ps.PayNum,
        ps.PayAmt,
        ps.PayDate,
        ps.split_count,
        cm.claimproc_count,
        cm.claim_nums,
        CASE WHEN cm.common_claim_count > 0 THEN 1 ELSE 0 END as has_known_oversplit_claims,
        ps.payment_category,
        ps.total_split_amount,
        ps.split_difference,
        ROUND(ps.split_count / NULLIF(cm.claimproc_count, 0), 1) as splits_per_proc,
        CASE WHEN (
            cm.common_claim_count = cm.total_claim_count 
            AND cm.common_claim_count = 3 
            AND ps.split_count / cm.total_claim_count > 20
        ) OR (
            ps.split_count > 100 
            AND cm.total_claim_count < 5
        ) THEN 1 ELSE 0 END as is_suspicious,
        'Payment' as record_type,
        NULL as ClaimNum,
        NULL as ClaimProcNum,
        NULL as min_split_amt,
        NULL as max_split_amt,
        NULL as active_days
    FROM PaymentSummary ps
    JOIN ClaimMetrics cm ON ps.PayNum = cm.PayNum
    WHERE ps.split_count > 10
),

ProblemClaimAnalysis AS (
    -- Problem claim details with payment links
    SELECT 
        NULL as PayNum,
        NULL as PayAmt,
        NULL as PayDate,
        pcd.split_count,
        NULL as claimproc_count,
        CAST(pcd.ClaimNum AS CHAR) as claim_nums,
        1 as has_known_oversplit_claims,
        'Problem Claim' as payment_category,
        NULL as total_split_amount,
        NULL as split_difference,
        NULL as splits_per_proc,
        1 as is_suspicious,
        'Claim' as record_type,
        pcd.ClaimNum,
        pcd.ClaimProcNum,
        pcd.min_split_amt,
        pcd.max_split_amt,
        pcd.active_days
    FROM ProblemClaimDetails pcd
)

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
