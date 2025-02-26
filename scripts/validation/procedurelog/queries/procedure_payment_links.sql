-- Procedure Payment Links Query
-- Validates the relationships between procedures and their associated payments
-- CTEs used: ExcludedCodes, BaseProcedures, PaymentActivity, PaymentLinks, LinkagePatterns

WITH 
-- Define excluded codes that are exempt from payment validation
ExcludedCodes AS (
    SELECT CodeNum 
    FROM procedurecode 
    WHERE ProcCode IN (
      '~GRP~', 'D9987', 'D9986', 'Watch', 'Ztoth', 'D0350',
      '00040', 'D2919', '00051',
      'D9992', 'D9995', 'D9996',
      'D0190', 'D0171', 'D0140', 'D9430', 'D0120'
    )
),

-- Base procedure set (filtered by date range)
BaseProcedures AS (
    SELECT 
        pl.ProcNum,
        pl.PatNum,
        pl.ProvNum,
        pl.ProcDate,
        pl.ProcStatus,
        pl.ProcFee,
        pl.CodeNum,
        pl.AptNum,
        pl.DateComplete,
        pc.ProcCode,
        pc.Descript,
        CASE WHEN ec.CodeNum IS NOT NULL THEN 'Excluded' ELSE 'Standard' END AS CodeCategory
    FROM procedurelog pl
    JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
    LEFT JOIN ExcludedCodes ec ON pl.CodeNum = ec.CodeNum
    WHERE pl.ProcDate >= '2024-01-01' AND pl.ProcDate < '2024-12-31' -- Fixed date range for testing
),

-- Calculate payment linkage metrics
PaymentLinks AS (
    SELECT
        pl.ProcNum,
        pl.ProcStatus,
        pl.ProcFee,
        pl.ProcDate,
        pl.DateComplete,
        -- Count payment splits linked to this procedure
        COUNT(DISTINCT ps.SplitNum) AS paysplit_count,
        -- Count claim procs linked to this procedure
        COUNT(DISTINCT cp.ClaimProcNum) AS claimproc_count,
        -- Calculate total amounts by source
        COALESCE(SUM(ps.SplitAmt), 0) AS direct_payment_amount,
        COALESCE(SUM(cp.InsPayAmt), 0) AS insurance_payment_amount,
        -- Calculate total expected from insurance
        COALESCE(SUM(cp.InsPayEst), 0) AS insurance_estimate_amount,
        -- Calculate days from completion to payment using MySQL's DATEDIFF
        MIN(CASE WHEN ps.SplitAmt > 0 AND pl.DateComplete IS NOT NULL AND ps.DatePay IS NOT NULL THEN 
            DATEDIFF(ps.DatePay, pl.DateComplete)
        END) AS min_days_to_payment,
        MAX(CASE WHEN ps.SplitAmt > 0 AND pl.DateComplete IS NOT NULL AND ps.DatePay IS NOT NULL THEN 
            DATEDIFF(ps.DatePay, pl.DateComplete)
        END) AS max_days_to_payment,
        -- Flag if there are claimproc entries with zero InsPayAmt
        MAX(CASE WHEN cp.ClaimProcNum IS NOT NULL AND cp.InsPayAmt = 0 THEN 1 ELSE 0 END) AS has_zero_insurance_payment
    FROM BaseProcedures pl
    LEFT JOIN paysplit ps ON pl.ProcNum = ps.ProcNum
    LEFT JOIN claimproc cp ON pl.ProcNum = cp.ProcNum
    WHERE pl.ProcFee > 0  -- Only look at procedures with fees
      AND pl.CodeCategory = 'Standard'  -- Exclude special codes
    GROUP BY pl.ProcNum, pl.ProcStatus, pl.ProcFee, pl.ProcDate, pl.DateComplete
),

-- Categorize by payment linkage pattern
LinkagePatterns AS (
    SELECT
        ProcNum,
        ProcStatus,
        ProcFee,
        paysplit_count,
        claimproc_count,
        direct_payment_amount,
        insurance_payment_amount,
        insurance_estimate_amount,
        direct_payment_amount + insurance_payment_amount AS total_payment_amount,
        min_days_to_payment,
        max_days_to_payment,
        has_zero_insurance_payment,
        CASE
            WHEN paysplit_count = 0 AND claimproc_count = 0 THEN 'No payment links'
            WHEN paysplit_count > 0 AND claimproc_count = 0 THEN 'Direct payment only'
            WHEN paysplit_count = 0 AND claimproc_count > 0 THEN 'Insurance only'
            ELSE 'Mixed payment sources'
        END AS payment_source_type,
        CASE
            WHEN direct_payment_amount + insurance_payment_amount >= ProcFee * 0.95 THEN 'Fully paid'
            WHEN direct_payment_amount + insurance_payment_amount > 0 THEN 'Partially paid'
            ELSE 'Unpaid'
        END AS payment_status,
        CASE
            WHEN insurance_estimate_amount > 0 AND insurance_payment_amount = 0 THEN 'Expected insurance not received'
            WHEN insurance_estimate_amount > 0 AND insurance_payment_amount < insurance_estimate_amount * 0.9 THEN 'Insurance underpaid'
            WHEN insurance_estimate_amount > 0 AND insurance_payment_amount > insurance_estimate_amount * 1.1 THEN 'Insurance overpaid'
            ELSE 'Normal insurance pattern'
        END AS insurance_pattern
    FROM PaymentLinks
)

-- Output payment linkage summary by pattern
SELECT
    payment_source_type,
    payment_status,
    COUNT(*) AS procedure_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS pct_of_total,
    SUM(CASE WHEN ProcStatus = 2 THEN 1 ELSE 0 END) AS completed_count,
    ROUND(100.0 * SUM(CASE WHEN ProcStatus = 2 THEN 1 ELSE 0 END) / COUNT(*), 2) AS completed_pct,
    ROUND(AVG(paysplit_count), 2) AS avg_paysplit_count,
    ROUND(AVG(claimproc_count), 2) AS avg_claimproc_count,
    SUM(ProcFee) AS total_fee,
    SUM(direct_payment_amount) AS total_direct_payment,
    SUM(insurance_payment_amount) AS total_insurance_payment,
    SUM(direct_payment_amount + insurance_payment_amount) AS total_payment,
    ROUND(SUM(direct_payment_amount + insurance_payment_amount) / NULLIF(SUM(ProcFee), 0) * 100, 2) AS payment_rate,
    SUM(CASE WHEN has_zero_insurance_payment = 1 THEN 1 ELSE 0 END) AS procs_with_zero_insurance,
    ROUND(AVG(CASE WHEN min_days_to_payment IS NOT NULL THEN min_days_to_payment ELSE NULL END)) AS avg_days_to_payment
FROM LinkagePatterns
GROUP BY payment_source_type, payment_status
ORDER BY payment_source_type, payment_status; 