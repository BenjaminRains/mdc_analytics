-- PAYMENT METRICS
-- Tracks payment statistics including insurance and patient payments
-- Dependent CTEs: base_procedures.sql
PaymentMetrics AS (
    SELECT 
        bp.ProvNum,
        -- Total amounts billed and paid
        SUM(bp.ProcFee) AS TotalBilled,
        
        -- Insurance payments
        COALESCE(SUM(
            CASE WHEN cp.ProcNum IS NOT NULL 
                 AND cp.InsPayAmt > 0 
                 AND cp.ProcDate >= '{{START_DATE}}'
                 AND cp.ProcDate < '{{END_DATE}}'
            THEN cp.InsPayAmt 
            ELSE 0 END
        ), 0) AS TotalInsurancePaid,
        
        -- Patient payments
        COALESCE(SUM(
            CASE WHEN ps.ProcNum IS NOT NULL 
                 AND ps.SplitAmt > 0
                 AND ps.ProcDate >= '{{START_DATE}}'
                 AND ps.ProcDate < '{{END_DATE}}'
            THEN ps.SplitAmt 
            ELSE 0 END
        ), 0) AS TotalPatientPaid,
        
        -- Derived metrics
        COALESCE(SUM(
            CASE WHEN cp.ProcNum IS NOT NULL 
                 AND cp.InsPayAmt > 0 
                 AND cp.ProcDate >= '{{START_DATE}}'
                 AND cp.ProcDate < '{{END_DATE}}'
            THEN cp.InsPayAmt 
            ELSE 0 END
        ), 0) +
        COALESCE(SUM(
            CASE WHEN ps.ProcNum IS NOT NULL 
                 AND ps.SplitAmt > 0
                 AND ps.ProcDate >= '{{START_DATE}}'
                 AND ps.ProcDate < '{{END_DATE}}'
            THEN ps.SplitAmt 
            ELSE 0 END
        ), 0) AS TotalPaid,
        
        -- Collection rate (as percentage)
        CASE 
            WHEN SUM(bp.ProcFee) > 0 THEN
                ROUND(100.0 * (
                    COALESCE(SUM(
                        CASE WHEN cp.ProcNum IS NOT NULL 
                             AND cp.InsPayAmt > 0 
                             AND cp.ProcDate >= '{{START_DATE}}'
                             AND cp.ProcDate < '{{END_DATE}}'
                        THEN cp.InsPayAmt 
                        ELSE 0 END
                    ), 0) +
                    COALESCE(SUM(
                        CASE WHEN ps.ProcNum IS NOT NULL 
                             AND ps.SplitAmt > 0
                             AND ps.ProcDate >= '{{START_DATE}}'
                             AND ps.ProcDate < '{{END_DATE}}'
                        THEN ps.SplitAmt 
                        ELSE 0 END
                    ), 0)
                ) / SUM(bp.ProcFee), 1)
            ELSE 0
        END AS CollectionRate
    FROM BaseProcedures bp
    LEFT JOIN claimproc cp ON bp.ProcNum = cp.ProcNum
    LEFT JOIN paysplit ps ON bp.ProcNum = ps.ProcNum
    WHERE bp.ProvNum > 0
      AND bp.ProcStatus = 2  -- Only completed procedures
    GROUP BY bp.ProvNum
) 