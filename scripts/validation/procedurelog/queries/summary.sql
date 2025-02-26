-- Procedure Log Summary Query
-- Provides overall metrics for procedure validation
-- CTEs used: ExcludedCodes, BaseProcedures, PaymentActivity, SuccessCriteria

-- Define excluded codes that are exempt from payment validation
WITH ExcludedCodes AS (
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
    WHERE pl.ProcDate >= '2024-01-01' AND pl.ProcDate < '2024-12-31'  -- Fixed date range for testing
),

-- Payment information for procedures
PaymentActivity AS (
    SELECT 
        pl.ProcNum,
        pl.ProcFee,
        COALESCE(SUM(cp.InsPayAmt), 0) AS insurance_paid,
        COALESCE(SUM(ps.SplitAmt), 0) AS direct_paid,
        COALESCE(SUM(cp.InsPayAmt), 0) + COALESCE(SUM(ps.SplitAmt), 0) AS total_paid,
        CASE 
            WHEN pl.ProcFee > 0 THEN 
                (COALESCE(SUM(cp.InsPayAmt), 0) + COALESCE(SUM(ps.SplitAmt), 0)) / pl.ProcFee 
            ELSE NULL 
        END AS payment_ratio
    FROM BaseProcedures pl
    LEFT JOIN claimproc cp ON pl.ProcNum = cp.ProcNum AND cp.InsPayAmt > 0
    LEFT JOIN paysplit ps ON pl.ProcNum = ps.ProcNum AND ps.SplitAmt > 0
    GROUP BY pl.ProcNum, pl.ProcFee
),

-- Success criteria evaluation
SuccessCriteria AS (
    SELECT
        bp.ProcNum,
        bp.ProcStatus,
        bp.ProcFee,
        bp.CodeCategory,
        pa.total_paid,
        pa.payment_ratio,
        CASE
            -- Case 1: Completed procedure with zero fee (not excluded)
            WHEN bp.ProcStatus = 2 AND bp.ProcFee = 0 AND bp.CodeCategory = 'Standard' THEN TRUE
            -- Case 2: Completed procedure with fee >= 95% paid
            WHEN bp.ProcStatus = 2 AND bp.ProcFee > 0 AND pa.payment_ratio >= 0.95 THEN TRUE
            -- All other cases are not successful
            ELSE FALSE
        END AS is_successful
    FROM BaseProcedures bp
    LEFT JOIN PaymentActivity pa ON bp.ProcNum = pa.ProcNum
)

-- Main Summary Query
SELECT
    COUNT(*) AS total_procedures,
    SUM(CASE WHEN ProcStatus = 2 THEN 1 ELSE 0 END) AS completed_procedures,
    SUM(CASE WHEN ProcStatus = 1 THEN 1 ELSE 0 END) AS treatment_planned_procedures,
    SUM(CASE WHEN ProcStatus = 6 THEN 1 ELSE 0 END) AS deleted_procedures,
    SUM(CASE WHEN CodeCategory = 'Excluded' THEN 1 ELSE 0 END) AS excluded_code_procedures,
    SUM(CASE WHEN ProcFee = 0 THEN 1 ELSE 0 END) AS zero_fee_procedures,
    SUM(CASE WHEN ProcFee > 0 THEN 1 ELSE 0 END) AS with_fee_procedures,
    
    -- Calculate payment statistics
    AVG(CASE WHEN ProcStatus = 2 AND ProcFee > 0 THEN payment_ratio ELSE NULL END) AS avg_payment_ratio_completed,
    SUM(CASE WHEN ProcStatus = 2 AND payment_ratio >= 0.95 THEN 1 ELSE 0 END) AS completed_with_95pct_payment,
    
    -- Calculate success rate
    SUM(CASE WHEN is_successful THEN 1 ELSE 0 END) AS successful_procedures,
    ROUND(100.0 * SUM(CASE WHEN is_successful THEN 1 ELSE 0 END) / 
           NULLIF(SUM(CASE WHEN ProcStatus = 2 THEN 1 ELSE 0 END), 0), 2) AS success_rate_pct,
    
    -- Financial metrics
    SUM(ProcFee) AS total_fees,
    SUM(CASE WHEN ProcStatus = 2 THEN ProcFee ELSE 0 END) AS completed_fees,
    SUM(CASE WHEN ProcStatus = 2 THEN total_paid ELSE 0 END) AS completed_paid,
    ROUND(100.0 * SUM(CASE WHEN ProcStatus = 2 THEN total_paid ELSE 0 END) / 
           NULLIF(SUM(CASE WHEN ProcStatus = 2 THEN ProcFee ELSE 0 END), 0), 2) AS completed_payment_pct
FROM (
    SELECT 
        bp.*,
        pa.total_paid,
        pa.payment_ratio,
        sc.is_successful
    FROM BaseProcedures bp
    LEFT JOIN PaymentActivity pa ON bp.ProcNum = pa.ProcNum
    LEFT JOIN SuccessCriteria sc ON bp.ProcNum = sc.ProcNum
) AS combined_data; 