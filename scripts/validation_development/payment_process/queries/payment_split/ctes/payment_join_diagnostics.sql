PaymentJoinDiagnostics AS (
    SELECT 
        p.PayNum,
        p.PayDate,
        p.PayAmt,
        p.PayType,
        CASE 
            WHEN NOT EXISTS (SELECT 1 FROM paysplit ps2 WHERE ps2.PayNum = p.PayNum) 
                THEN 'No Splits'
            WHEN NOT EXISTS (SELECT 1 FROM paysplit ps2 
                           JOIN procedurelog pl2 ON ps2.ProcNum = pl2.ProcNum 
                           WHERE ps2.PayNum = p.PayNum) 
                THEN 'No Procedures'
            WHEN NOT EXISTS (SELECT 1 FROM paysplit ps2 
                           JOIN claimproc cp2 ON ps2.ProcNum = cp2.ProcNum 
                           WHERE ps2.PayNum = p.PayNum AND cp2.InsPayAmt IS NOT NULL) 
                THEN 'No Insurance'
            ELSE 'Complete'
        END as join_status,
        COUNT(DISTINCT ps.SplitNum) as split_count,
        COUNT(DISTINCT pl.ProcNum) as proc_count
    FROM payment p
    LEFT JOIN paysplit ps ON p.PayNum = ps.PayNum
    LEFT JOIN procedurelog pl ON ps.ProcNum = pl.ProcNum
    WHERE p.PayDate >= @start_date
      AND p.PayDate < @end_date
    GROUP BY p.PayNum, p.PayDate, p.PayAmt, p.PayType
)