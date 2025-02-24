-- Join stages
-- tracks payment counts through join stages
-- identifies missing or duplicate payments
-- validates join integrity

SELECT 
    (SELECT COUNT(DISTINCT PayNum) 
     FROM payment 
     WHERE PayDate >= '2024-01-01' AND PayDate < '2025-01-01'
    ) as base_count,
    
    (SELECT COUNT(DISTINCT p.PayNum)
     FROM payment p
     LEFT JOIN paysplit ps ON p.PayNum = ps.PayNum
     WHERE p.PayDate >= '2024-01-01' AND p.PayDate < '2025-01-01'
    ) as paysplit_count,
    
    (SELECT COUNT(DISTINCT p.PayNum)
     FROM payment p
     LEFT JOIN paysplit ps ON p.PayNum = ps.PayNum
     LEFT JOIN claim c ON ps.ClaimNum = c.ClaimNum
     LEFT JOIN claimproc cp ON c.ClaimNum = cp.ClaimNum 
         AND cp.ProcNum = ps.ProcNum
         AND cp.Status IN (1, 4, 5)
         AND cp.InsPayAmt > 0
     WHERE p.PayDate >= '2024-01-01' AND p.PayDate < '2025-01-01'
    ) as claimproc_count,
    
    (SELECT COUNT(DISTINCT PayNum) 
     FROM payment 
     WHERE PayDate >= '2024-01-01' AND PayDate < '2025-01-01'
    ) - 
    (SELECT COUNT(DISTINCT p.PayNum)
     FROM payment p
     LEFT JOIN paysplit ps ON p.PayNum = ps.PayNum
     LEFT JOIN claim c ON ps.ClaimNum = c.ClaimNum
     LEFT JOIN claimproc cp ON c.ClaimNum = cp.ClaimNum 
         AND cp.ProcNum = ps.ProcNum
         AND cp.Status IN (1, 4, 5)
         AND cp.InsPayAmt > 0
     WHERE p.PayDate >= '2024-01-01' AND p.PayDate < '2025-01-01'
    ) as missing_payments;
