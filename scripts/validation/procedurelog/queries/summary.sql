-- Procedure Log Summary Query
-- Provides overall metrics for procedure validation

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