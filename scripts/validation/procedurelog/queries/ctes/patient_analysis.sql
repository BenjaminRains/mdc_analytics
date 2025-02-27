-- Dependent CTEs: date_params.sql, status_7_base.sql
-- Date range: 2024-01-01 to 2025-01-01
-- Description: Patient analysis with visit metrics

PatientAnalysis AS (
    SELECT 
        s7.PatNum,
        COUNT(*) as status_7_count,
        COUNT(DISTINCT s7.CodeNum) as unique_procedures,
        COUNT(DISTINCT s7.ProcDate) as unique_dates,
        -- Fee metrics
        SUM(s7.ProcFee) as total_fees,
        COUNT(DISTINCT CASE WHEN s7.ProcFee > 0 THEN s7.ProcNum END) as procedures_with_fees,
        -- Date range metrics
        MIN(s7.ProcDate) as first_status_7,
        MAX(s7.ProcDate) as last_status_7,
        DATEDIFF(MAX(s7.ProcDate), MIN(s7.ProcDate)) + 1 as date_span_days,
        -- Category metrics: numeric count of distinct procedure categories
        COUNT(DISTINCT s7.ProcCat) as procedure_categories_count,
        COUNT(DISTINCT s7.ProcCat) as unique_categories,
        SUM(CASE WHEN s7.ProcCat = '250' THEN 1 ELSE 0 END) as cat_250_count,
        -- Volume metrics
        MAX(s7.procs_per_day) as max_procs_per_day,
        AVG(s7.procs_per_day) as avg_procs_per_day,
        MAX(s7.procs_per_category_per_day) as max_procs_per_cat_per_day,
        COUNT(DISTINCT CASE WHEN s7.volume_flag IN ('High', 'Extreme') THEN s7.ProcDate END) as high_volume_dates,
        -- Treatment plan and appointment metrics
        SUM(s7.has_treatment_plan) as treatment_plan_count,
        COUNT(DISTINCT CASE WHEN s7.has_treatment_plan = 1 THEN s7.treatment_plan_date END) as unique_plan_dates,
        SUM(s7.has_appointment) as appointment_count,
        COUNT(DISTINCT CASE WHEN s7.has_appointment = 1 THEN DATE(s7.appointment_date) END) as unique_appt_dates,
        -- Status transition metrics
        COUNT(DISTINCT pl_other.ProcStatus) as other_status_count,
        GROUP_CONCAT(DISTINCT CAST(pl_other.ProcStatus AS CHAR)) as other_statuses,
        -- Data quality flag
        CASE 
            WHEN MAX(s7.procs_per_day) > 100 THEN 'Review Required - Extreme'
            WHEN MAX(s7.procs_per_day) > 50 THEN 'Review Required - High'
            WHEN COUNT(*) > 200 THEN 'Review Required - Total'
            ELSE 'Normal'
        END as data_quality_flag
    FROM Status7Base s7
    LEFT JOIN procedurelog pl_other ON s7.PatNum = pl_other.PatNum 
        AND pl_other.ProcStatus != 7
        AND pl_other.ProcDate >= (SELECT start_date FROM DateParams)
        AND pl_other.ProcDate < (SELECT end_date FROM DateParams)
    GROUP BY s7.PatNum
)