-- Duplicate joins
-- identifies duplicate payments from joins
-- split and claimproc counts per payment

SELECT 
    p.PayNum,
    p.PayAmt,
    p.PayDate,
    COUNT(*) as join_count,
    COUNT(DISTINCT ps.SplitNum) as split_count,
    COUNT(DISTINCT cp.ClaimProcNum) as claimproc_count,
    GROUP_CONCAT(DISTINCT cp.ClaimNum) as claim_nums
FROM payment p
LEFT JOIN paysplit ps ON p.PayNum = ps.PayNum
-- Join to claim first to get the correct relationship
LEFT JOIN claim c ON ps.ClaimNum = c.ClaimNum
LEFT JOIN claimproc cp ON c.ClaimNum = cp.ClaimNum 
    AND cp.ProcNum = ps.ProcNum  -- Ensure procedure matches
    AND cp.Status IN (1, 4, 5)   -- Only completed/received claims
    AND cp.InsPayAmt > 0         -- Only actual insurance payments
WHERE p.PayDate >= '2024-01-01' 
    AND p.PayDate < '2025-01-01'
GROUP BY p.PayNum, p.PayAmt, p.PayDate
HAVING COUNT(*) > 1;
