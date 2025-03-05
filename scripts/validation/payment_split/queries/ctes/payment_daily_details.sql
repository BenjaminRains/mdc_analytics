-- PaymentDailyDetails: Extract daily payment patterns and metrics.
-- depends on: none
-- Date filter: Uses @start_date to @end_date
PaymentDailyDetails AS (
    SELECT 
        p.PayNum,
        p.PayDate,
        p.PayType,
        p.PayAmt,
        p.PayNote,
        ps.SplitNum,
        ps.SplitAmt,
        ps.ProcNum,
        cp.ClaimNum,
        cp.ClaimProcNum,
        cp.Status as ProcStatus,
        c.ClaimStatus,
        c.DateService
    FROM payment p
    JOIN paysplit ps ON p.PayNum = ps.PayNum
    JOIN claimproc cp ON ps.ProcNum = cp.ProcNum
    JOIN claim c ON cp.ClaimNum = c.ClaimNum
    WHERE p.PayDate >= @start_date AND p.PayDate < @end_date
)