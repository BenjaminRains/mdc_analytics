-- Appointment Insurance Analysis
-- Purpose: Track appointments and estimate expected insurance payments
-- Used for: Financial forecasting, insurance verification, patient estimates

-- Daily collection forecasting
SET @FromDate = CURDATE();
SET @ToDate = CURDATE();

-- Check upcoming appointments needing verification
SET @FromDate = CURDATE();
SET @ToDate = DATE_ADD(CURDATE(), INTERVAL 5 DAY);

-- Generate patient portions for tomorrow
SET @FromDate = DATE_ADD(CURDATE(), INTERVAL 1 DAY);
SET @ToDate = DATE_ADD(CURDATE(), INTERVAL 1 DAY);


SELECT 
    a.AptDateTime,                           -- Appointment date/time
    p.PatNum,
    -- Primary insurance carrier name
    CASE 
        WHEN carrier.CarrierName IS NULL THEN '*No Insurance' 
        ELSE carrier.CarrierName 
    END AS 'PriCarrier',

    -- Total fees for all procedures
    SUM(pl.ProcFee) AS '$Fees',

    -- Expected insurance payment based on status:
    COALESCE(SUM(CASE
        WHEN cp.Status IN (1, 4) THEN cp.InsPayAmt      -- Received/Supplemental
        WHEN cp.Status = 0 THEN cp.InsPayEst            -- Not received
        WHEN cp.Status = 6 THEN                         -- Cap/Copay
            CASE WHEN cp.InsEstTotalOverride = -1 
                THEN cp.InsEstTotal 
                ELSE cp.InsEstTotalOverride
            END
    END), 0) AS '$InsPayEst',

    -- Expected write-off amount
    COALESCE(SUM(CASE
        WHEN cp.Status IN (1, 4) THEN cp.WriteOff
        ELSE (
            CASE WHEN cp.WriteOffEstOverride = -1 
                THEN CASE WHEN cp.WriteOffEst = -1 THEN 0 ELSE cp.WriteOffEst END
                ELSE cp.WriteOffEstOverride
            END
        )
    END), 0) AS '$Writeoff',

    -- Calculate patient portion:
    -- (Total Fees - Write-offs - Insurance Estimate)
    (SUM(pl.ProcFee)) -
    (WriteoffTotal) -
    (InsuranceEstimate) AS '$PatPorEst'

FROM appointment a
INNER JOIN patient p ON p.PatNum = a.PatNum
INNER JOIN procedurelog pl ON a.AptNum = pl.AptNum 
    AND a.AptDateTime BETWEEN @FromDate AND @ToDate + INTERVAL 1 DAY 
    AND a.AptStatus IN (1, 2, 4)  -- scheduled, complete, ASAP

-- Insurance information joins
LEFT JOIN patplan pp ON pp.PatNum = p.PatNum 
    AND ORDINAL = 1               -- Primary insurance only
LEFT JOIN inssub iss ON pp.InsSubNum = iss.InsSubNum
LEFT JOIN insplan ip ON ip.PlanNum = iss.PlanNum 
LEFT JOIN carrier ON carrier.CarrierNum = ip.CarrierNum
LEFT JOIN claimproc cp ON cp.ProcNum = pl.ProcNum 
    AND cp.Status IN (0, 1, 4, 6) -- Not received, Received, Supplemental, Cap
    AND cp.PlanNum = ip.PlanNum

GROUP BY a.AptNum
ORDER BY a.AptDateTime;
