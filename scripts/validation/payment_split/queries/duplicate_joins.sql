-- Duplicate joins
-- identifies duplicate payments from joins
-- split and claimproc counts per payment

SELECT 
    ps.PayNum,
    ps.PayAmt,
    ps.PayDate,
    COUNT(*) as join_count,
    ps.split_count,
    COUNT(DISTINCT cp.ClaimProcNum) as claimproc_count,
    GROUP_CONCAT(DISTINCT cp.ClaimNum) as claim_nums
FROM PaymentSummary ps
LEFT JOIN paysplit psp ON ps.PayNum = psp.PayNum
LEFT JOIN claimproc cp ON psp.ProcNum = cp.ProcNum  
    AND cp.Status IN (1, 4, 5)   -- Only completed/received claims
    AND cp.InsPayAmt > 0         -- Only actual insurance payments
GROUP BY ps.PayNum, ps.PayAmt, ps.PayDate, ps.split_count
HAVING COUNT(*) > 1;
