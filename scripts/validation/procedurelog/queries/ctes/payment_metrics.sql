-- PAYMENT METRICS
-- Tracks payment statistics including insurance and patient payments
-- Date filter: 2024-01-01 to 2025-01-01
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
        
        -- Aging buckets for fees
        SUM(CASE 
            WHEN DATEDIFF(CURRENT_DATE, bp.ProcDate) <= 30 
            THEN bp.ProcFee 
            ELSE 0 
        END) AS Fees0to30Days,
        
        SUM(CASE 
            WHEN DATEDIFF(CURRENT_DATE, bp.ProcDate) BETWEEN 31 AND 60
            THEN bp.ProcFee 
            ELSE 0 
        END) AS Fees31to60Days,
        
        SUM(CASE 
            WHEN DATEDIFF(CURRENT_DATE, bp.ProcDate) BETWEEN 61 AND 90
            THEN bp.ProcFee 
            ELSE 0 
        END) AS Fees61to90Days,
        
        SUM(CASE 
            WHEN DATEDIFF(CURRENT_DATE, bp.ProcDate) > 90
            THEN bp.ProcFee 
            ELSE 0 
        END) AS FeesOver90Days,
        
        -- Payment aging buckets
        COALESCE(SUM(
            CASE WHEN DATEDIFF(CURRENT_DATE, COALESCE(cp.ProcDate, ps.ProcDate)) <= 30
            THEN COALESCE(cp.InsPayAmt, 0) + COALESCE(ps.SplitAmt, 0)
            ELSE 0 END
        ), 0) AS Paid0to30Days,
        
        COALESCE(SUM(
            CASE WHEN DATEDIFF(CURRENT_DATE, COALESCE(cp.ProcDate, ps.ProcDate)) BETWEEN 31 AND 60
            THEN COALESCE(cp.InsPayAmt, 0) + COALESCE(ps.SplitAmt, 0)
            ELSE 0 END
        ), 0) AS Paid31to60Days,
        
        -- Total paid (unchanged)
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
        
        -- Collection rate excluding recent procedures (more accurate)
        CASE 
            WHEN SUM(CASE WHEN DATEDIFF(CURRENT_DATE, bp.ProcDate) > 30 
                         THEN bp.ProcFee ELSE 0 END) > 0 
            THEN ROUND(100.0 * (
                COALESCE(SUM(
                    CASE WHEN cp.ProcNum IS NOT NULL 
                         AND cp.InsPayAmt > 0 
                         AND DATEDIFF(CURRENT_DATE, cp.ProcDate) > 30
                    THEN cp.InsPayAmt 
                    ELSE 0 END
                ), 0) +
                COALESCE(SUM(
                    CASE WHEN ps.ProcNum IS NOT NULL 
                         AND ps.SplitAmt > 0
                         AND DATEDIFF(CURRENT_DATE, ps.ProcDate) > 30
                    THEN ps.SplitAmt 
                    ELSE 0 END
                ), 0)
            ) / SUM(CASE WHEN DATEDIFF(CURRENT_DATE, bp.ProcDate) > 30 
                        THEN bp.ProcFee ELSE 0 END), 1)
            ELSE 0
        END AS AdjustedCollectionRate
    FROM BaseProcedures bp
    LEFT JOIN claimproc cp ON bp.ProcNum = cp.ProcNum
    LEFT JOIN paysplit ps ON bp.ProcNum = ps.ProcNum
    WHERE bp.ProvNum > 0
      AND bp.ProcStatus = 2  -- Only completed procedures
    GROUP BY bp.ProvNum
)