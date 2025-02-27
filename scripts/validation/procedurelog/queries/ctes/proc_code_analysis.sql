-- Dependent CTEs: date_params.sql, status_7_base.sql
-- Date range: 2024-01-01 to 2025-01-01
-- Description: Procedure code analysis

ProcCodeAnalysis AS (
    SELECT 
        ProcCode,
        ProcDescription,
        ProcCat,
        COUNT(*) as procedure_count,
        COUNT(DISTINCT PatNum) as unique_patients,
        COUNT(DISTINCT ProvNum) as unique_providers,
        -- Fee metrics
        SUM(CASE WHEN ProcFee > 0 THEN 1 ELSE 0 END) as with_fee_count,
        AVG(ProcFee) as avg_fee,
        MIN(ProcDate) as first_occurrence,
        MAX(ProcDate) as last_occurrence,
        -- Treatment plan and appointment metrics
        SUM(has_treatment_plan) as treatment_plan_count,
        AVG(CASE WHEN has_treatment_plan = 1 THEN DATEDIFF(ProcDate, treatment_plan_date) END) as avg_days_since_plan,
        SUM(has_appointment) as appointment_count,
        AVG(CASE WHEN has_appointment = 1 THEN DATEDIFF(ProcDate, appointment_date) END) as avg_days_since_appt,
        -- Volume metrics
        SUM(CASE WHEN volume_flag = 'Extreme' THEN 1 ELSE 0 END) as extreme_volume_days,
        SUM(CASE WHEN volume_flag IN ('High', 'Extreme') THEN 1 ELSE 0 END) as high_volume_days,
        -- Category 250 specific metrics
        SUM(CASE WHEN ProcCat = '250' THEN 1 ELSE 0 END) as cat_250_count,
        COUNT(DISTINCT CASE WHEN ProcCat = '250' THEN PatNum END) as cat_250_patients
    FROM Status7Base
    GROUP BY ProcCode, ProcDescription, ProcCat
    HAVING COUNT(*) > 5
    ORDER BY COUNT(*) DESC
)