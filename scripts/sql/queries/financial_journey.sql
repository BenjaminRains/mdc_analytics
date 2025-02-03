-- Financial Journey Analysis
-- Tracks production, adjustments, writeoffs, and payments by fee schedule

-- Analyze current month
SET @FromDate = DATE_FORMAT(CURRENT_DATE(), '%Y-%m-01');
SET @ToDate = LAST_DAY(@FromDate);

-- Analyze previous quarter
SET @FromDate = DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 1 QUARTER), '%Y-%m-01');
SET @ToDate = LAST_DAY(DATE_ADD(@FromDate, INTERVAL 2 MONTH));

-- Analyze year to date
SET @FromDate = DATE_FORMAT(CURRENT_DATE(), '%Y-01-01');
SET @ToDate = CURRENT_DATE();

-- Main analysis query
SELECT 
    A.FeeSchedule,
    A.$Production_,
    A.$Adjustment_,
    A.$Writeoff_,
    (A.$Production_ + A.$Adjustment_ + A.$Writeoff_) AS $NetProd_,
    A.$InsPay_,
    A.$PatPay_,
    A.$TotPay_
FROM (
    SELECT 
        -- Determine fee schedule hierarchy (Insurance > Patient > Provider)
        CASE 
            WHEN fs1.Description IS NOT NULL THEN fs1.Description  -- Insurance fee schedule
            WHEN fs2.Description IS NOT NULL THEN fs2.Description  -- Patient fee schedule
            WHEN fs3.Description IS NOT NULL THEN fs3.Description  -- Provider fee schedule
            ELSE NULL 
        END AS FeeSchedule,
        
        -- Financial metrics
        SUM(CASE WHEN RawTable.TranType = 'Fee' 
            THEN RawTable.TranAmount ELSE 0 END) AS $Production_,
        SUM(CASE WHEN RawTable.TranType = 'Adj' 
            THEN RawTable.TranAmount ELSE 0 END) AS $Adjustment_,
        SUM(CASE WHEN RawTable.TranType = 'Writeoff' 
            THEN RawTable.TranAmount ELSE 0 END) AS $Writeoff_,
        SUM(CASE WHEN RawTable.TranType = 'InsPay' 
            THEN RawTable.TranAmount ELSE 0 END) AS $InsPay_,
        SUM(CASE WHEN RawTable.TranType = 'Pay' 
            THEN RawTable.TranAmount ELSE 0 END) AS $PatPay_,
        SUM(CASE WHEN RawTable.TranType IN ('Pay', 'InsPay') 
            THEN RawTable.TranAmount ELSE 0 END) AS $TotPay_
    FROM (
        -- Completed procedures and charges
        SELECT 
            'Fee' AS TranType,
            pl.PatNum,
            pl.ProcDate AS TranDate,
            pl.ProcFee * (pl.UnitQty + pl.BaseUnits) AS TranAmount
        FROM procedurelog pl
        WHERE pl.ProcStatus = 2  -- Completed procedures
            AND pl.ProcDate BETWEEN @FromDate AND @ToDate

        UNION ALL

        -- Capitation writeoffs
        SELECT 
            'Fee' AS TranType,
            cp.PatNum,
            cp.ProcDate AS TranDate,
            -cp.Writeoff AS TranAmount
        FROM claimproc cp
        WHERE cp.Status = '7'  -- Capitation complete

        UNION ALL

        -- Patient payments
        SELECT 
            'Pay' AS TranType,
            ps.PatNum,
            ps.ProcDate AS TranDate,
            ps.SplitAmt AS TranAmount
        FROM paysplit ps
        WHERE ps.PayPlanNum = 0  -- Exclude payment plan splits

        UNION ALL

        -- Adjustments
        SELECT 
            'Adj' AS TranType,
            a.PatNum,
            a.AdjDate AS TranDate,
            a.AdjAmt AS TranAmount
        FROM adjustment a

        UNION ALL

        -- Insurance payments
        SELECT 
            'InsPay' AS TranType,
            cp.PatNum,
            cp.ProcDate AS TranDate,
            cp.InsPayAmt AS TranAmount
        FROM claimproc cp
        WHERE cp.Status IN (1, 4)  -- Received, supplemental

        UNION ALL

        -- Insurance writeoffs
        SELECT 
            'Writeoff' AS TranType,
            cp.PatNum,
            cp.ProcDate AS TranDate,
            -cp.Writeoff AS TranAmount
        FROM claimproc cp
        WHERE cp.Status IN (1, 4, 0)  -- Received, supplemental, notreceived
    ) RawTable
    INNER JOIN patient p ON p.PatNum = RawTable.PatNum
    INNER JOIN provider pv ON p.PriProv = pv.ProvNum
    INNER JOIN feesched fs3 ON fs3.FeeSchedNum = pv.FeeSched
    LEFT JOIN feesched fs2 ON fs2.FeeSchedNum = p.FeeSched
    LEFT JOIN patplan pp ON pp.PatNum = p.PatNum AND pp.Ordinal = 1
    LEFT JOIN inssub ib ON ib.InsSubNum = pp.InsSubNum
    LEFT JOIN insplan ip ON ip.PlanNum = ib.PlanNum
    LEFT JOIN feesched fs1 ON ip.FeeSched = fs1.FeeSchedNum
    WHERE RawTable.TranDate BETWEEN @FromDate AND @ToDate
    GROUP BY FeeSchedule
) A
ORDER BY FeeSchedule;


