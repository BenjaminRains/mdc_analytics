-- PAYMENT LINKS
-- Calculates payment linkage metrics for procedures
-- Used for identifying payment tracking issues and linkage patterns
-- Dependent CTEs: base_procedures.sql
PaymentLinks AS (
    SELECT 
        bp.ProcNum,
        bp.ProcStatus,
        bp.ProcFee,
        bp.ProcDate,
        bp.DateComplete,
        -- Count linked payment splits
        COUNT(DISTINCT ps.SplitNum) AS paysplit_count,
        -- Count linked claim procs with payment
        COUNT(DISTINCT cp.ClaimProcNum) AS claimproc_count,
        -- Payment amounts
        COALESCE(SUM(ps.SplitAmt), 0) AS direct_payment_amount,
        COALESCE(SUM(cp.InsPayAmt), 0) AS insurance_payment_amount,
        -- Insurance estimate amount (expected insurance)
        COALESCE(SUM(cp.InsEstTotal), 0) AS insurance_estimate_amount,
        -- Days from procedure to payment metrics
        MIN(CASE WHEN ps.SplitAmt > 0 THEN 
            DATEDIFF(ps.DatePay, COALESCE(bp.DateComplete, bp.ProcDate))
            END) AS min_direct_days_to_payment,
        MIN(CASE WHEN cp.InsPayAmt > 0 THEN 
            DATEDIFF(cp.DateCP, COALESCE(bp.DateComplete, bp.ProcDate))
            END) AS min_insurance_days_to_payment,
        LEAST(
            COALESCE(MIN(CASE WHEN ps.SplitAmt > 0 THEN 
                DATEDIFF(ps.DatePay, COALESCE(bp.DateComplete, bp.ProcDate))
                END), 999999),
            COALESCE(MIN(CASE WHEN cp.InsPayAmt > 0 THEN 
                DATEDIFF(cp.DateCP, COALESCE(bp.DateComplete, bp.ProcDate))
                END), 999999)
        ) AS min_days_to_payment,
        MAX(CASE WHEN ps.SplitAmt > 0 OR cp.InsPayAmt > 0 THEN 
            GREATEST(
                COALESCE(DATEDIFF(ps.DatePay, COALESCE(bp.DateComplete, bp.ProcDate)), 0),
                COALESCE(DATEDIFF(cp.DateCP, COALESCE(bp.DateComplete, bp.ProcDate)), 0)
            )
            END) AS max_days_to_payment,
        -- Flag for zero insurance payments with claims
        CASE WHEN COUNT(DISTINCT cp.ClaimProcNum) > 0 AND 
                  COALESCE(SUM(cp.InsPayAmt), 0) = 0 
             THEN 1 ELSE 0 END AS has_zero_insurance_payment
    FROM BaseProcedures bp
    LEFT JOIN paysplit ps ON bp.ProcNum = ps.ProcNum
    LEFT JOIN claimproc cp ON bp.ProcNum = cp.ProcNum
    GROUP BY 
        bp.ProcNum, 
        bp.ProcStatus,
        bp.ProcFee,
        bp.ProcDate,
        bp.DateComplete
)