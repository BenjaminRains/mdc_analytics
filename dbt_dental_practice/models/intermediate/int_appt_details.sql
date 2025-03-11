/*
    Intermediate model for appointment details
    Connects appointment data with type information and provider details
    Part of System G: Scheduling & Referrals
*/

WITH appointment_base AS (
    SELECT
        appointment_id,
        patient_id,
        provider_id,
        appointment_date,
        appointment_time,
        appointment_status,
        appointment_type_id,
        is_confirmed,
        is_complete,
        is_hygiene,
        note
    FROM {{ ref('stg_opendental__appointment') }}
),

appointment_types AS (
    SELECT
        appointment_type_id,
        appointment_type_name,
        appointment_length,
        color_override
    FROM {{ ref('stg_opendental__appointmenttype') }}
),

provider_info AS (
    SELECT
        provider_id,
        provider_name,
        provider_specialty
    FROM {{ ref('stg_opendental__provider') }}
)

SELECT
    a.appointment_id,
    a.patient_id,
    a.provider_id,
    a.appointment_date,
    a.appointment_time,
    a.appointment_status,
    a.is_confirmed,
    a.is_complete,
    a.is_hygiene,
    a.note,
    at.appointment_type_id,
    at.appointment_type_name,
    at.appointment_length,
    pr.provider_name,
    pr.provider_specialty,
    CASE
        WHEN a.is_complete = TRUE THEN 'Completed'
        WHEN a.appointment_date < CURRENT_DATE AND a.is_complete = FALSE THEN 'Missed/No-Show'
        WHEN a.is_confirmed = TRUE THEN 'Confirmed'
        ELSE 'Scheduled'
    END AS appointment_status_desc,
    -- Add created_at and updated_at for tracking
    CURRENT_TIMESTAMP as model_created_at,
    CURRENT_TIMESTAMP as model_updated_at
FROM appointment_base a
LEFT JOIN appointment_types at 
    ON a.appointment_type_id = at.appointment_type_id
LEFT JOIN provider_info pr 
    ON a.provider_id = pr.provider_id