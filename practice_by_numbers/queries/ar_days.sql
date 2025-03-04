-- AR Days = AR Ratio × 30
-- AR Ratio = Total AR / Average Monthly Production (last 12 months)

WITH MonthlyProduction AS (
    SELECT 
        DATE_FORMAT(pl.ProcDate, '%Y-%m-01') as month,
        SUM(pl.ProcFee) as monthly_production
    FROM procedurelog pl
    WHERE 
        pl.ProcStatus = 2
        AND pl.ProcDate >= '2023-01-01'
        AND pl.ProcDate < '2024-01-01'
        AND pl.ProcFee > 0
    GROUP BY DATE_FORMAT(pl.ProcDate, '%Y-%m-01')
),

ProcedureBalances AS (
    SELECT 
        pl.ProcNum,
        pl.ProcDate,
        pl.ProcFee,
        -- Only include payments up to end of 2023
        COALESCE(
            (SELECT SUM(SplitAmt) 
             FROM paysplit 
             WHERE ProcNum = pl.ProcNum 
             AND DatePay < '2024-01-01'), 
            0
        ) as payment_amt,
        
        -- Only include insurance payments up to end of 2023
        COALESCE(
            (SELECT SUM(InsPayAmt) 
             FROM claimproc 
             WHERE ProcNum = pl.ProcNum 
             AND Status = 1 
             AND ProcDate < '2024-01-01'), 
            0
        ) as insurance_amt,
        
        -- Separate positive and negative adjustments
        COALESCE(
            (SELECT SUM(CASE WHEN AdjAmt > 0 THEN AdjAmt ELSE 0 END)
             FROM adjustment 
             WHERE ProcNum = pl.ProcNum 
             AND AdjDate < '2024-01-01'), 
            0
        ) as positive_adj_amt,
        
        COALESCE(
            (SELECT SUM(CASE WHEN AdjAmt < 0 THEN AdjAmt ELSE 0 END)
             FROM adjustment 
             WHERE ProcNum = pl.ProcNum 
             AND AdjDate < '2024-01-01'), 
            0
        ) as negative_adj_amt,
        
        -- Get latest insurance estimate
        (SELECT InsPayEst 
         FROM claimproc 
         WHERE ProcNum = pl.ProcNum 
         AND Status = 1 
         AND ProcDate < '2024-01-01'
         ORDER BY ProcDate DESC 
         LIMIT 1) as insurance_estimate,
        
        -- Use the most recent transaction date for aging
        GREATEST(
            pl.ProcDate,
            COALESCE(
                (SELECT MAX(DatePay) 
                 FROM paysplit 
                 WHERE ProcNum = pl.ProcNum 
                 AND DatePay < '2024-01-01'
                 AND SplitAmt != 0), 
                pl.ProcDate
            ),
            COALESCE(
                (SELECT MAX(ProcDate) 
                 FROM claimproc 
                 WHERE ProcNum = pl.ProcNum 
                 AND Status = 1 
                 AND ProcDate < '2024-01-01'
                 AND InsPayAmt != 0), 
                pl.ProcDate
            ),
            COALESCE(
                (SELECT MAX(AdjDate) 
                 FROM adjustment 
                 WHERE ProcNum = pl.ProcNum 
                 AND AdjDate < '2024-01-01'
                 AND AdjAmt != 0), 
                pl.ProcDate
            )
        ) as last_activity_date
    FROM procedurelog pl
    WHERE pl.ProcStatus = 2
        AND pl.ProcDate >= '2023-01-01'
        AND pl.ProcDate < '2024-01-01'
        AND pl.ProcFee > 0
        AND pl.ProcFee <= 10000  -- Filter out unusually large fees
),

BalanceCalculation AS (
    SELECT 
        *,
        (ProcFee - payment_amt - insurance_amt + negative_adj_amt - positive_adj_amt) as balance
    FROM ProcedureBalances
),

AccountsReceivable AS (
    SELECT
        SUM(CASE WHEN balance > 0 THEN balance ELSE 0 END) as total_ar,
        
        SUM(CASE 
            WHEN balance > 0 
                AND DATEDIFF('2024-01-01', last_activity_date) <= 30
            THEN balance 
            ELSE 0 
        END) as ar_30,
        
        SUM(CASE 
            WHEN balance > 0 
                AND DATEDIFF('2024-01-01', last_activity_date) BETWEEN 31 AND 60
            THEN balance 
            ELSE 0 
        END) as ar_60,
        
        SUM(CASE 
            WHEN balance > 0 
                AND DATEDIFF('2024-01-01', last_activity_date) BETWEEN 61 AND 90
            THEN balance 
            ELSE 0 
        END) as ar_90,
        
        SUM(CASE 
            WHEN balance > 0 AND insurance_estimate > 0 
            THEN balance 
            ELSE 0 
        END) as insurance_ar,
        
        SUM(CASE 
            WHEN balance > 0 AND COALESCE(insurance_estimate, 0) = 0 
            THEN balance 
            ELSE 0 
        END) as patient_ar,
        
        SUM(CASE WHEN balance < 0 THEN balance ELSE 0 END) as patient_credits
    FROM BalanceCalculation
)

SELECT 
    ar_days,
    ar_ratio * 100 as ar_ratio_percentage,
    total_ar,
    insurance_ar,
    patient_ar,
    patient_credits,
    ar_30 as "current",
    ar_60 as "30_day",
    ar_90 as "60_day",
    (total_ar - ar_30 - ar_60 - ar_90) as "90_day",
    avg_monthly_production,
    month_count
FROM (
    SELECT
        ar.*,
        AVG(mp.monthly_production) as avg_monthly_production,
        COUNT(DISTINCT mp.month) as month_count,
        ar.total_ar / NULLIF(AVG(mp.monthly_production), 0) as ar_ratio,
        (ar.total_ar / NULLIF(AVG(mp.monthly_production), 0)) * 30 as ar_days
    FROM AccountsReceivable ar
    CROSS JOIN MonthlyProduction mp
    GROUP BY 
        ar.total_ar, ar.ar_30, ar.ar_60, ar.ar_90,
        ar.insurance_ar, ar.patient_ar, ar.patient_credits
) Metrics;