/*
    Intermediate model for comprehensive procedure data
    Combines procedure log with codes, fees, and notes
    Part of System A: Fee Processing & Verification
*/

WITH procedure_log AS (
    SELECT
        procedure_id,
        patient_id,
        provider_id,
        procedure_date,
        procedure_status,
        procedure_code,
        fee_schedule_id,
        fee,
        appointment_id,
        clinic_num
    FROM {{ ref('stg_opendental__procedurelog') }}
),

procedure_codes AS (
    SELECT
        procedure_code,
        procedure_description,
        procedure_category,
        is_hygiene
    FROM {{ ref('stg_opendental__procedurecode') }}
),

fee_schedules AS (
    SELECT
        fee_schedule_id,
        fee_schedule_name,
        is_hidden,
        is_global
    FROM {{ ref('stg_opendental__feesched') }}
),

procedure_notes AS (
    SELECT
        procedure_id,
        note AS procedure_note,
        is_signed,
        signed_by_provider_id
    FROM {{ ref('stg_opendental__procnote') }}
)

SELECT
    pl.procedure_id,
    pl.patient_id,
    pl.provider_id,
    pl.procedure_date,
    pl.procedure_status,
    pl.procedure_code,
    pl.fee,
    pl.appointment_id,
    pl.clinic_num,
    pc.procedure_description,
    pc.procedure_category,
    pc.is_hygiene,
    fs.fee_schedule_id,
    fs.fee_schedule_name,
    pn.procedure_note,
    pn.is_signed,
    pn.signed_by_provider_id,
    -- Calculated fields
    CASE
        WHEN pl.procedure_status = 'C' THEN 'Complete'
        WHEN pl.procedure_status = 'EC' THEN 'Existing Complete'
        WHEN pl.procedure_status = 'EO' THEN 'Existing Other'
        WHEN pl.procedure_status = 'R' THEN 'Referred'
        WHEN pl.procedure_status = 'TP' THEN 'Treatment Plan'
        ELSE pl.procedure_status
    END AS procedure_status_desc,
    -- Add created_at and updated_at for tracking
    CURRENT_TIMESTAMP as model_created_at,
    CURRENT_TIMESTAMP as model_updated_at
FROM procedure_log pl
LEFT JOIN procedure_codes pc 
    ON pl.procedure_code = pc.procedure_code
LEFT JOIN fee_schedules fs 
    ON pl.fee_schedule_id = fs.fee_schedule_id
LEFT JOIN procedure_notes pn 
    ON pl.procedure_id = pn.procedure_id