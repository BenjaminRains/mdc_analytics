-- PAYMENT ACTIVITY
-- Aggregates payment information from insurance and direct patient payments
-- Calculates total payments and payment ratio (percentage of fee paid)
-- Date filter: 2024-01-01 to 2025-01-01
-- Dependent CTEs: base_procedures.sql
PaymentActivity AS (
    SELECT 
        pl.ProcNum,
        pl.ProcFee,
        COALESCE(SUM(CASE 
            WHEN cp.ProcDate >= '{{START_DATE}}' 
                 AND cp.ProcDate < '{{END_DATE}}' 
            THEN cp.InsPayAmt ELSE 0 END), 0) AS insurance_paid,
        COALESCE(SUM(CASE 
            WHEN ps.ProcDate >= '{{START_DATE}}' 
                 AND ps.ProcDate < '{{END_DATE}}' 
            THEN ps.SplitAmt ELSE 0 END), 0) AS direct_paid,
        COALESCE(SUM(CASE 
            WHEN cp.ProcDate >= '{{START_DATE}}' 
                 AND cp.ProcDate < '{{END_DATE}}' 
            THEN cp.InsPayAmt ELSE 0 END), 0)
        + COALESCE(SUM(CASE 
            WHEN ps.ProcDate >= '{{START_DATE}}' 
                 AND ps.ProcDate < '{{END_DATE}}' 
            THEN ps.SplitAmt ELSE 0 END), 0) AS total_paid,
        CASE 
            WHEN pl.ProcFee > 0 THEN 
                (COALESCE(SUM(CASE 
                    WHEN cp.ProcDate >= '{{START_DATE}}' 
                         AND cp.ProcDate < '{{END_DATE}}' 
                    THEN cp.InsPayAmt ELSE 0 END), 0)
                + COALESCE(SUM(CASE 
                    WHEN ps.ProcDate >= '{{START_DATE}}' 
                         AND ps.ProcDate < '{{END_DATE}}' 
                    THEN ps.SplitAmt ELSE 0 END), 0)
                ) / pl.ProcFee 
            ELSE NULL 
        END AS payment_ratio
    FROM BaseProcedures pl
    LEFT JOIN claimproc cp 
           ON pl.ProcNum = cp.ProcNum 
          AND cp.InsPayAmt > 0
    LEFT JOIN paysplit ps 
           ON pl.ProcNum = ps.ProcNum 
          AND ps.SplitAmt > 0
    GROUP BY pl.ProcNum, pl.ProcFee
)