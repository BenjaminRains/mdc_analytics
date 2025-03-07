<<include:problem_claim_details.sql>>
ProblemClaimAnalysis AS (
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