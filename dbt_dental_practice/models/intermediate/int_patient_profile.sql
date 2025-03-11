WITH patient_base AS (
    SELECT
        patient_id,
        first_name,
        last_name,
        birthdate,
        phone,
        email,
        zipcode
    FROM {{ ref('stg_opendental__patient') }}
),

patient_family AS (
    SELECT
        patient_id,
        family_id
    FROM {{ ref('stg_opendental__patientlink') }}
),

zip_info AS (
    SELECT
        zipcode,
        city,
        state
    FROM {{ ref('stg_opendental__zipcode') }}
)

SELECT
    p.patient_id,
    p.first_name,
    p.last_name,
    p.birthdate,
    p.phone,
    p.email,
    pf.family_id,
    z.city,
    z.state,
    -- Add created_at and updated_at for tracking
    CURRENT_TIMESTAMP as model_created_at,
    CURRENT_TIMESTAMP as model_updated_at
FROM patient_base p
LEFT JOIN patient_family pf 
    ON p.patient_id = pf.patient_id
LEFT JOIN zip_info z 
    ON p.zipcode = z.zipcode