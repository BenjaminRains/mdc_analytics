-- Description: Monthly trends with additional metrics
-- Dependent CTEs: date_params.sql, status_7_base.sql
-- Date range: 2024-01-01 to 2025-01-01
MonthlyTrends AS (
    SELECT 
        DATE_FORMAT(ProcDate, '%Y-%m') as month,
        COUNT(*) as total_procedures,
        COUNT(DISTINCT PatNum) as unique_patients,
        COUNT(DISTINCT ProvNum) as unique_providers,
        COUNT(DISTINCT ProcCat) as unique_categories,
        -- Fee metrics
        AVG(ProcFee) as avg_fee,
        SUM(CASE WHEN ProcFee > 0 THEN 1 ELSE 0 END) as with_fee_count,
        -- Category metrics
        SUM(CASE WHEN ProcCat = '250' THEN 1 ELSE 0 END) as cat_250_count,
        COUNT(DISTINCT CASE WHEN ProcCat = '250' THEN PatNum END) as cat_250_patients,
        -- Treatment plan and appointment metrics
        SUM(has_treatment_plan) as treatment_plan_count,
        COUNT(DISTINCT CASE WHEN has_treatment_plan = 1 THEN treatment_plan_date END) as unique_plan_dates,
        SUM(has_appointment) as appointment_count,
        COUNT(DISTINCT CASE WHEN has_appointment = 1 THEN DATE(appointment_date) END) as unique_appt_dates,
        -- Volume metrics by classification
        SUM(CASE WHEN volume_flag = 'Extreme' THEN 1 ELSE 0 END) as extreme_volume_procedures,
        SUM(CASE WHEN volume_flag = 'High' THEN 1 ELSE 0 END) as high_volume_procedures,
        SUM(CASE WHEN volume_flag = 'Medium' THEN 1 ELSE 0 END) as medium_volume_procedures,
        COUNT(DISTINCT CASE WHEN volume_flag IN ('High', 'Extreme') THEN PatNum END) as high_volume_patients
    FROM Status7Base
    GROUP BY DATE_FORMAT(ProcDate, '%Y-%m')
    ORDER BY month
)