-- Status 7 Analysis Query
-- Analyzes characteristics and patterns of procedures with Status 7
-- Date filter: 2024-01-01 to 2025-01-01
-- Dependent CTEs: date_params.sql, status_7_base.sql, proc_code_analysis.sql, patient_analysis.sql, status_transitions.sql, monthly_trends.sql

SELECT 
    'Procedure Code Distribution' as analysis_type,
    JSON_OBJECT(
        'proc_code', ProcCode,
        'description', ProcDescription,
        'category', ProcCat,
        'count', procedure_count,
        'patients', unique_patients,
        'providers', unique_providers,
        'fee_count', with_fee_count,
        'avg_fee', avg_fee,
        'treatment_plans', treatment_plan_count,
        'avg_days_since_plan', avg_days_since_plan,
        'appointments', appointment_count,
        'avg_days_since_appt', avg_days_since_appt,
        'extreme_volume_days', extreme_volume_days,
        'high_volume_days', high_volume_days,
        'cat_250_count', cat_250_count,
        'cat_250_patients', cat_250_patients,
        'date_range', JSON_ARRAY(first_occurrence, last_occurrence)
    ) as analysis_data
FROM ProcCodeAnalysis
WHERE procedure_count > 5

UNION ALL

SELECT 
    'Patient Patterns' as analysis_type,
    JSON_OBJECT(
        'patient_id', PatNum,
        'status_7_count', status_7_count,
        'unique_procedures', unique_procedures,
        'unique_dates', unique_dates,
        'total_fees', total_fees,
        'procedures_with_fees', procedures_with_fees,
        'date_span_days', date_span_days,
        'max_procs_per_day', max_procs_per_day,
        'avg_procs_per_day', avg_procs_per_day,
        'max_procs_per_cat_per_day', max_procs_per_cat_per_day,
        'high_volume_dates', high_volume_dates,
        'treatment_plans', treatment_plan_count,
        'unique_plan_dates', unique_plan_dates,
        'appointments', appointment_count,
        'unique_appt_dates', unique_appt_dates,
        'unique_categories', unique_categories,
        'cat_250_count', cat_250_count,
        'procedure_categories', procedure_categories,
        'other_status_count', other_status_count,
        'other_statuses', other_statuses,
        'data_quality_flag', data_quality_flag,
        'date_range', JSON_ARRAY(first_status_7, last_status_7)
    ) as analysis_data
FROM PatientAnalysis
WHERE status_7_count > 1

UNION ALL

SELECT 
    'Status Transitions' as analysis_type,
    JSON_OBJECT(
        'proc_num', ProcNum,
        'patient_id', PatNum,
        'code_num', CodeNum,
        'proc_code', ProcCode,
        'category', ProcCat,
        'status_7_date', status_7_date,
        'has_plan', has_treatment_plan,
        'plan_date', treatment_plan_date,
        'has_appt', has_appointment,
        'appt_date', appointment_date,
        'volume_flag', volume_flag,
        'nearby_changes', nearby_status_changes
    ) as analysis_data
FROM StatusTransitions
WHERE nearby_status_changes IS NOT NULL

UNION ALL

SELECT 
    'Monthly Trends' as analysis_type,
    JSON_OBJECT(
        'month', month,
        'total_procedures', total_procedures,
        'unique_patients', unique_patients,
        'unique_providers', unique_providers,
        'unique_categories', unique_categories,
        'avg_fee', avg_fee,
        'with_fee_count', with_fee_count,
        'cat_250_count', cat_250_count,
        'cat_250_patients', cat_250_patients,
        'treatment_plan_count', treatment_plan_count,
        'unique_plan_dates', unique_plan_dates,
        'appointment_count', appointment_count,
        'unique_appt_dates', unique_appt_dates,
        'extreme_volume_procedures', extreme_volume_procedures,
        'high_volume_procedures', high_volume_procedures,
        'medium_volume_procedures', medium_volume_procedures,
        'high_volume_patients', high_volume_patients
    ) as analysis_data
FROM MonthlyTrends
ORDER BY analysis_type; 