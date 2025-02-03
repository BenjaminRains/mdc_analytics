-- Office A/R totals at the end of each month for 12 months from the AsOf date
-- WARNING: This query uses temporary tables. If using replication, use on one computer at a time.

SET @AsOf = '';

-- Create temporary table to store all financial transactions
DROP TABLE IF EXISTS RawPatTrans;
CREATE TABLE RawPatTrans AS
SELECT *
FROM (
    -- Completed procedures
    SELECT 
        'Fee' AS TranType,
        pl.PatNum,
        pl.ProcDate AS TranDate,
        pl.ProcFee * (pl.UnitQty + pl.BaseUnits) AS TranAmount 
    FROM procedurelog pl 
    WHERE pl.ProcStatus = 2

    UNION ALL

    -- Payment splits (excluding payment plans)
    SELECT 
        'Pay' AS TranType,
        ps.PatNum,
        ps.DatePay AS TranDate,
        -ps.SplitAmt AS TranAmount 
    FROM paysplit ps
    WHERE ps.PayPlanNum = 0

    UNION ALL

    -- Adjustments
    SELECT 
        'Adj' AS TranType,
        a.PatNum,
        a.AdjDate AS TranDate,
        a.AdjAmt AS TranAmount
    FROM adjustment a
    WHERE a.AdjAmt != 0

    UNION ALL

    -- Insurance payments
    SELECT 
        'InsPay' AS TranType,
        cp.PatNum,
        cp.DateCp AS TranDate,
        -(cp.InsPayAmt + cp.Writeoff) AS TranAmount 
    FROM claimproc cp
    WHERE cp.Status IN (1,4,5,7) -- Received, Supplemental, CapClaim, CapComplete

    UNION ALL 

    -- Payment plan principal
    SELECT 
        'PayPlan' AS TranType,
        pp.PatNum,
        pp.PayPlanDate AS TranDate,
        -pp.CompletedAmt AS TranAmount 
    FROM payplan pp
    WHERE pp.CompletedAmt != 0
) RawTransactions;

-- Function to calculate aging buckets for a given month offset
DELIMITER //
CREATE FUNCTION CalculateAgingBuckets(monthOffset INT) 
RETURNS TABLE AS
BEGIN
    RETURN
    SELECT 
        DATE_FORMAT(LAST_DAY(@AsOf + INTERVAL monthOffset MONTH), '%M %Y') AS MONTH,
        -- Calculate aging buckets using CASE statements
        -- ... (aging calculation logic) ...
    FROM (
        -- Get family level totals
        SELECT 
            g.PatNum,
            SUM(B.PatBal) AS FamBal,
            -- ... (family level calculations) ...
        FROM (
            -- Get patient level charges and credits
            SELECT 
                PatNum,
                SUM(TranAmount) AS PatBal,
                -- ... (patient level calculations) ...
            FROM RawPatTrans
            WHERE TranDate <= LAST_DAY(@AsOf + INTERVAL monthOffset MONTH)
            GROUP BY PatNum
        ) B
        -- ... (joins and grouping) ...
    ) D
    WHERE D.FamBal > 0.005;
END //
DELIMITER ;

-- Generate report for all 12 months
SELECT * FROM (
    SELECT * FROM CalculateAgingBuckets(0)
    UNION ALL SELECT * FROM CalculateAgingBuckets(1)
    UNION ALL SELECT * FROM CalculateAgingBuckets(2)
    -- ... continue for remaining months ...
    UNION ALL SELECT * FROM CalculateAgingBuckets(11)
) MonthlyReport
ORDER BY MONTH;

-- Cleanup
DROP TABLE IF EXISTS RawPatTrans;
DROP FUNCTION IF EXISTS CalculateAgingBuckets;