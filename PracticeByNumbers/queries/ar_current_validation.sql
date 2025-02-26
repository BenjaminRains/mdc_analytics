-- Validate Total AR Current calculation
WITH DateInfo AS (
    SELECT STR_TO_DATE('2025-01-03', '%Y-%m-%d') as as_of_date
),
Monthly_Production AS (
    SELECT 
        AVG(monthly_total) as avg_monthly_production
    FROM (
        SELECT 
            DATE_FORMAT(p.ProcDate, '%Y-%m') as month,
            SUM(p.ProcFee) as monthly_total
        FROM procedurelog p, DateInfo d
        WHERE p.ProcStatus = 2
            AND p.ProcDate >= DATE_SUB(d.as_of_date, INTERVAL 12 MONTH)
            AND p.ProcDate < d.as_of_date
        GROUP BY DATE_FORMAT(p.ProcDate, '%Y-%m')
    ) monthly
),
AR_Aging AS (
    SELECT 
        p.ProcNum,
        p.ProcFee,
        p.ProcDate,
        d.as_of_date,
        COALESCE(cp.InsPayEst, 0) as insurance_estimate,
        COALESCE(SUM(CASE WHEN cp.ProcDate < d.as_of_date THEN cp.InsPayAmt ELSE 0 END), 0) as insurance_paid,
        COALESCE(SUM(CASE WHEN ps.DatePay < d.as_of_date THEN ps.SplitAmt ELSE 0 END), 0) as patient_paid,
        COALESCE(SUM(CASE WHEN a.AdjDate < d.as_of_date AND a.AdjAmt < 0 THEN a.AdjAmt ELSE 0 END), 0) as negative_adjustments,
        COALESCE(SUM(CASE WHEN a.AdjDate < d.as_of_date AND a.AdjAmt > 0 THEN a.AdjAmt ELSE 0 END), 0) as positive_adjustments,
        DATEDIFF(d.as_of_date, p.ProcDate) as age_days,
        DATE_FORMAT(p.ProcDate, '%Y-%m-%d') as proc_date_formatted,
        CASE 
            WHEN DATEDIFF(d.as_of_date, p.ProcDate) <= 30 THEN 'Current'
            WHEN DATEDIFF(d.as_of_date, p.ProcDate) <= 60 THEN '30-60'
            WHEN DATEDIFF(d.as_of_date, p.ProcDate) <= 90 THEN '60-90'
            ELSE '90+'
        END as aging_bucket,
        -- Include the balance calculation in the CTE
        (ProcFee 
         - COALESCE(SUM(CASE WHEN cp.ProcDate < d.as_of_date THEN cp.InsPayAmt ELSE 0 END), 0)
         - COALESCE(SUM(CASE WHEN ps.DatePay < d.as_of_date THEN ps.SplitAmt ELSE 0 END), 0)
         + COALESCE(SUM(CASE WHEN a.AdjDate < d.as_of_date AND a.AdjAmt < 0 THEN a.AdjAmt ELSE 0 END), 0)
         - COALESCE(SUM(CASE WHEN a.AdjDate < d.as_of_date AND a.AdjAmt > 0 THEN a.AdjAmt ELSE 0 END), 0)
        ) as balance,
        -- Add claim status for debugging
        cp.Status as claim_status,
        -- Add procedure status for debugging
        p.ProcStatus
    FROM procedurelog p
    CROSS JOIN DateInfo d
    LEFT JOIN claimproc cp ON p.ProcNum = cp.ProcNum
    LEFT JOIN paysplit ps ON p.ProcNum = ps.ProcNum
    LEFT JOIN adjustment a ON p.ProcNum = a.ProcNum
    WHERE p.ProcStatus = 2  -- Completed procedures only
        AND p.ProcDate < d.as_of_date  -- No future procedures
        AND p.ProcDate >= DATE_SUB(d.as_of_date, INTERVAL 6 MONTH)  -- Last 6 months only
    GROUP BY 
        p.ProcNum, p.ProcFee, p.ProcDate, d.as_of_date, 
        cp.InsPayEst, cp.Status, p.ProcStatus
),
Ranked_AR AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (PARTITION BY aging_bucket ORDER BY ProcNum) as rn
    FROM AR_Aging
    WHERE balance <> 0  -- Only include procedures with remaining balance
        AND balance > -1000  -- Exclude large negative balances
        AND balance < 10000  -- Exclude unusually large balances
        AND ProcDate < as_of_date  -- Double check no future dates
)
SELECT 
    aging_bucket,
    COUNT(*) as procedure_count,
    SUM(balance) as total_ar,
    -- Calculate AR Ratio
    ROUND(
        SUM(balance) / (SELECT avg_monthly_production FROM Monthly_Production),
        2
    ) as ar_ratio,
    -- Calculate percentage of total
    ROUND(
        100.0 * SUM(balance) / SUM(SUM(balance)) OVER (), 
        1
    ) as percentage_of_total,
    MIN(proc_date_formatted) as earliest_date,
    MAX(proc_date_formatted) as latest_date,
    MIN(age_days) as min_age,
    MAX(age_days) as max_age,
    -- Add as_of_date for verification
    MAX(as_of_date) as query_date,
    -- Sample procedures with more debug info
    GROUP_CONCAT(
        CASE WHEN rn <= 3 
        THEN CONCAT(
            ProcNum, ':', 
            proc_date_formatted, ':',
            ProcFee, ':', 
            balance, ':',
            claim_status, ':',
            ProcStatus
        ) 
        END
        SEPARATOR '; '
    ) as sample_procs
FROM Ranked_AR
GROUP BY aging_bucket
ORDER BY 
    CASE aging_bucket
        WHEN 'Current' THEN 1
        WHEN '30-60' THEN 2
        WHEN '60-90' THEN 3
        WHEN '90+' THEN 4
    END; 