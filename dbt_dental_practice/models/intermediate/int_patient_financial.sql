/*
    Intermediate model for patient financial summary
    Aggregates procedures, payments, insurance payments, and adjustments
    Cross-system model connecting Fee Processing, Insurance Processing, and Payment Allocation
*/

WITH patient_procedures AS (
    SELECT
        patient_id,
        SUM(CASE WHEN procedure_status IN ('C', 'EC') THEN fee ELSE 0 END) AS total_completed_procedures,
        SUM(CASE WHEN procedure_status = 'TP' THEN fee ELSE 0 END) AS total_treatment_planned,
        COUNT(CASE WHEN procedure_status IN ('C', 'EC') THEN procedure_id END) AS completed_procedure_count,
        COUNT(CASE WHEN procedure_status = 'TP' THEN procedure_id END) AS planned_procedure_count,
        MIN(CASE WHEN procedure_status IN ('C', 'EC') THEN procedure_date END) AS first_procedure_date,
        MAX(CASE WHEN procedure_status IN ('C', 'EC') THEN procedure_date END) AS last_procedure_date
    FROM {{ ref('int_procedure_complete') }}
    GROUP BY patient_id
),

patient_payments AS (
    SELECT
        patient_id,
        SUM(CASE WHEN is_payment = TRUE THEN split_amount ELSE 0 END) AS total_patient_payments,
        SUM(CASE WHEN is_payment = FALSE THEN split_amount ELSE 0 END) AS total_payment_adjustments,
        COUNT(DISTINCT payment_id) AS payment_count,
        MIN(payment_date) AS first_payment_date,
        MAX(payment_date) AS last_payment_date
    FROM {{ ref('int_payment_allocated') }}
    GROUP BY patient_id
),

insurance_payments AS (
    SELECT
        cp.patient_id,
        SUM(cp.insurance_payment) AS total_insurance_payments,
        SUM(cp.write_off) AS total_write_offs,
        COUNT(DISTINCT cp.claim_id) AS claim_count,
        MIN(c.date_sent) AS first_claim_date,
        MAX(c.date_sent) AS last_claim_date
    FROM {{ ref('int_claim_details') }} cp
    LEFT JOIN {{ ref('stg_opendental__claim') }} c ON cp.claim_id = c.claim_id
    GROUP BY cp.patient_id
),

adjustments AS (
    SELECT
        patient_id,
        SUM(CASE WHEN adjustment_amount > 0 THEN adjustment_amount ELSE 0 END) AS total_positive_adjustments,
        SUM(CASE WHEN adjustment_amount < 0 THEN adjustment_amount ELSE 0 END) AS total_negative_adjustments,
        COUNT(*) AS adjustment_count
    FROM {{ ref('stg_opendental__adjustment') }}
    GROUP BY patient_id
)

SELECT
    p.patient_id,
    p.first_name,
    p.last_name,
    p.family_id,
    -- Procedure totals
    COALESCE(pp.total_completed_procedures, 0) AS total_completed_procedures,
    COALESCE(pp.total_treatment_planned, 0) AS total_treatment_planned,
    COALESCE(pp.completed_procedure_count, 0) AS completed_procedure_count,
    COALESCE(pp.planned_procedure_count, 0) AS planned_procedure_count,
    pp.first_procedure_date,
    pp.last_procedure_date,
    -- Payment totals
    COALESCE(pay.total_patient_payments, 0) AS total_patient_payments,
    COALESCE(pay.total_payment_adjustments, 0) AS total_payment_adjustments,
    COALESCE(pay.payment_count, 0) AS payment_count,
    pay.first_payment_date,
    pay.last_payment_date,
    -- Insurance totals
    COALESCE(ins.total_insurance_payments, 0) AS total_insurance_payments,
    COALESCE(ins.total_write_offs, 0) AS total_write_offs,
    COALESCE(ins.claim_count, 0) AS claim_count,
    ins.first_claim_date,
    ins.last_claim_date,
    -- Adjustment totals
    COALESCE(adj.total_positive_adjustments, 0) AS total_positive_adjustments,
    COALESCE(adj.total_negative_adjustments, 0) AS total_negative_adjustments,
    COALESCE(adj.adjustment_count, 0) AS adjustment_count,
    -- Calculated balance
    COALESCE(pp.total_completed_procedures, 0) 
    - COALESCE(pay.total_patient_payments, 0) 
    - COALESCE(ins.total_insurance_payments, 0) 
    - COALESCE(ins.total_write_offs, 0)
    + COALESCE(adj.total_positive_adjustments, 0) 
    + COALESCE(adj.total_negative_adjustments, 0) AS current_balance,
    -- Add created_at and updated_at for tracking
    CURRENT_TIMESTAMP as model_created_at,
    CURRENT_TIMESTAMP as model_updated_at
FROM {{ ref('int_patient_profile') }} p
LEFT JOIN patient_procedures pp 
    ON p.patient_id = pp.patient_id
LEFT JOIN patient_payments pay 
    ON p.patient_id = pay.patient_id
LEFT JOIN insurance_payments ins 
    ON p.patient_id = ins.patient_id
LEFT JOIN adjustments adj 
    ON p.patient_id = adj.patient_id