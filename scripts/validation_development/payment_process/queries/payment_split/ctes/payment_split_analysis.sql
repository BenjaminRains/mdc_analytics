{% include "payment_level_metrics.sql" %}
{% include "claim_metrics.sql" %}
PaymentSplitAnalysis AS (
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
    FROM PaymentLevelMetrics ps
    JOIN ClaimMetrics cm ON ps.PayNum = cm.PayNum
    WHERE ps.split_count > 10
) 