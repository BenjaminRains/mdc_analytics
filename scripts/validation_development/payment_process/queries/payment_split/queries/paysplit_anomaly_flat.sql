/*
 * Query: duplicate_joins_flat.sql
 * Purpose: Identifies problematic payment splits across payments and claims
 * Primary Joins: payment → paysplit → claimproc
 * Key Filters: PayDate between @start_date and @end_date
 * 
 * This query identifies potentially problematic payment splits by analyzing:
 * - Payments with suspicious split patterns
 * - Discrepancies between payment amounts and split totals
 * - Known problematic claims (2536, 2542, 6519)
 * 
 * Documentation: /docs/payment_split/duplicate_joins_flat.md
 */

{% import "cte_macros.sql" as macros %}

{# Begin the CTEs section #}
{{ macros.begin_ctes() }}

{# Base CTEs first #}
-- PaymentLevelMetrics: Base payment data with split statistics and categorization
PaymentLevelMetrics AS (
    SELECT 
        p.PayNum,
        p.PayAmt,
        p.PayDate,
        p.PayType,
        p.PayNote,
        COUNT(ps.SplitNum) AS split_count,
        SUM(ps.SplitAmt) AS total_split_amount,
        ABS(p.PayAmt - COALESCE(SUM(ps.SplitAmt), 0)) AS split_difference,
        CASE WHEN p.PayAmt < 0 THEN 1 ELSE 0 END AS is_reversal,
        CASE WHEN COUNT(ps.SplitNum) > 15 THEN 1 ELSE 0 END AS is_high_split,
        CASE WHEN p.PayAmt = 0 THEN 1 ELSE 0 END AS is_zero_amount,
        CASE WHEN p.PayAmt > 5000 THEN 1 ELSE 0 END AS is_large_payment,
        CASE WHEN COUNT(ps.SplitNum) = 1 THEN 1 ELSE 0 END AS is_single_split,
        CASE 
            WHEN p.PayType IN (417, 574, 634) THEN 'Insurance'
            WHEN p.PayType IN (69, 70, 71) THEN 'Check/Cash'
            WHEN p.PayType IN (391, 412) THEN 'Card/Online'
            WHEN p.PayType = 72 THEN 'Refund'
            WHEN p.PayType = 0 THEN 'Transfer'
            ELSE 'Other'
        END AS payment_category
    FROM payment p
    LEFT JOIN paysplit ps ON p.PayNum = ps.PayNum
    WHERE p.PayDate >= @start_date
      AND p.PayDate < @end_date
    GROUP BY p.PayNum, p.PayAmt, p.PayDate, p.PayType, p.PayNote
)
{{ macros.cte_separator(False) }}

-- ClaimMetrics: Aggregates claim-level information for each payment
ClaimMetrics AS (
    SELECT 
        ps.PayNum,
        COUNT(DISTINCT cp.ClaimProcNum) as claimproc_count,
        GROUP_CONCAT(DISTINCT cp.ClaimNum) as claim_nums,
        COUNT(DISTINCT CASE WHEN cp.ClaimNum IN (2536, 2542, 6519) THEN cp.ClaimNum END) as common_claim_count,
        COUNT(DISTINCT cp.ClaimNum) as total_claim_count
    FROM paysplit ps
    JOIN payment p ON ps.PayNum = p.PayNum
    JOIN claimproc cp ON ps.ProcNum = cp.ProcNum
        AND cp.Status IN (1, 4, 5)
        AND cp.InsPayAmt > 0
    WHERE p.PayDate >= @start_date
      AND p.PayDate < @end_date
    GROUP BY ps.PayNum
)
{{ macros.cte_separator(False) }}

{# Secondary CTEs that depend on the base ones #}
-- PaymentSplitAnalysis: Combines payment and claim metrics to identify suspicious patterns
PaymentSplitAnalysis AS (
    -- Base payment split analysis
    SELECT 
        'Payment' AS record_type,
        p.PayNum,
        p.PayDate,
        p.payment_category,
        p.split_count,
        CASE WHEN p.split_count > 1 AND cm.claimproc_count >= p.split_count*2 THEN 1 ELSE 0 END as has_known_oversplit_claims,
        CASE WHEN p.split_count > 5 AND p.split_difference > 1 THEN 1 ELSE 0 END as is_suspicious,
        cm.claim_nums,
        cm.common_claim_count,
        p.PayAmt,
        p.total_split_amount,
        p.split_difference,
        cm.claimproc_count
    FROM PaymentLevelMetrics p
    LEFT JOIN ClaimMetrics cm ON p.PayNum = cm.PayNum
    WHERE p.is_zero_amount = 0
      AND p.split_count > 0
)
{{ macros.cte_separator(False) }}

-- ProblemClaimDetails: Identifies payments associated with known problematic claims
ProblemClaimDetails AS (
    SELECT 
        ps.PayNum,
        COUNT(DISTINCT cp.ClaimNum) as unique_claim_count,
        GROUP_CONCAT(DISTINCT cp.ClaimNum) as claim_proc_counts, -- Simplified to avoid nested aggregation
        MAX(cp.ClaimNum) as sample_claim
    FROM paysplit ps
    JOIN payment p ON ps.PayNum = p.PayNum
    JOIN claimproc cp ON ps.ProcNum = cp.ProcNum
    WHERE p.PayDate >= @start_date
      AND p.PayDate < @end_date
      AND cp.ClaimNum IN (2536, 2542, 6519)
    GROUP BY ps.PayNum
    HAVING COUNT(*) > 1
)
{{ macros.cte_separator(False) }}

-- ProblemClaimAnalysis: Detailed analysis of payments with known problematic claims
ProblemClaimAnalysis AS (
    SELECT 
        'Claim' AS record_type,
        p.PayNum,
        p.PayDate,
        p.payment_category,
        p.split_count,
        1 as has_known_oversplit_claims,
        CASE WHEN p.split_count > 5 THEN 1 ELSE 0 END as is_suspicious,
        pcd.claim_proc_counts as claim_nums,
        pcd.unique_claim_count as common_claim_count,
        p.PayAmt,
        p.total_split_amount,
        p.split_difference,
        cm.claimproc_count
    FROM PaymentLevelMetrics p
    JOIN ProblemClaimDetails pcd ON p.PayNum = pcd.PayNum
    LEFT JOIN ClaimMetrics cm ON p.PayNum = cm.PayNum
)
{{ macros.cte_separator(True) }}

{# Main query #}
-- Union of general payment analysis and specific problem claim analysis
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