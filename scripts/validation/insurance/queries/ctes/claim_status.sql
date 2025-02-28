-- ClaimStatus: Analyzes claim processing status and key metrics
-- Date filter: 2024-01-01 to 2025-01-01
-- Dependencies: none

ClaimStatus AS (
    SELECT 
        cp.ClaimNum,
        cp.PlanNum,
        cp.PatNum,
        cp.Status,
        cp.DateCP,
        cp.ProcDate,
        cp.InsPayEst,
        cp.InsPayAmt,
        cp.WriteOff,
        cp.DedApplied,
        cp.DateInsFinalized,
        cp.IsTransfer,
        cp.ClaimPaymentNum,
        ct.TrackingType,
        ct.DateTimeEntry as tracking_date,
        DATEDIFF(cp.DateInsFinalized, cp.ProcDate) as days_to_finalize,
        CASE 
            WHEN cp.Status IN (1, 4, 5) THEN 'Received'
            WHEN cp.Status = 2 THEN 'Sent'
            WHEN cp.Status = 3 THEN 'Pending'
            WHEN cp.Status = 6 THEN 'Rejected'
            WHEN cp.Status = 7 THEN 'Reversed'
            ELSE 'Other'
        END as status_category,
        ROW_NUMBER() OVER (
            PARTITION BY cp.ClaimNum 
            ORDER BY ct.DateTimeEntry DESC
        ) as tracking_rank
    FROM claimproc cp
    LEFT JOIN claimtracking ct ON cp.ClaimNum = ct.ClaimNum
    WHERE 
        cp.ProcDate BETWEEN '{{START_DATE}}' AND '{{END_DATE}}'
        OR cp.DateCP BETWEEN '{{START_DATE}}' AND '{{END_DATE}}'
) 