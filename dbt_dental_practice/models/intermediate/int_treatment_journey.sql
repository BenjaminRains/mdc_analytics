/*
    Intermediate model for patient treatment journey
    Tracks flow from appointment through procedure, claim, and payment
    Cross-system model connecting Scheduling, Fee Processing, Insurance Processing, and Payment Allocation
*/

WITH journey_base AS (
    -- Start with completed procedures as the core of the journey
    SELECT
        proc.procedure_id,
        proc.patient_id,
        proc.provider_id,
        proc.procedure_date,
        proc.procedure_code,
        proc.procedure_description,
        proc.procedure_status,
        proc.fee,
        proc.appointment_id,
        pat.first_name AS patient_first_name,
        pat.last_name AS patient_last_name
    FROM {{ ref('int_procedure_complete') }} proc
    JOIN {{ ref('int_patient_profile') }} pat 
        ON proc.patient_id = pat.patient_id
    WHERE proc.procedure_status IN ('C', 'EC')  -- Only completed procedures
),

appointment_info AS (
    SELECT
        appointment_id,
        appointment_date,
        appointment_time,
        appointment_status_desc
    FROM {{ ref('int_appointment_details') }}
    WHERE appointment_id IS NOT NULL
),

claim_info AS (
    SELECT
        procedure_id,
        claim_id,
        claimproc_id,
        date_sent,
        claim_status,
        insurance_estimate,
        insurance_payment,
        write_off,
        date_received,
        tracking_status
    FROM {{ ref('int_claim_details') }}
    WHERE procedure_id IS NOT NULL
),

payment_info AS (
    SELECT
        procedure_id,
        payment_id,
        paysplit_id,
        payment_date,
        split_amount,
        payment_type,
        split_type_desc
    FROM {{ ref('int_payment_allocated') }}
    WHERE procedure_id IS NOT NULL AND is_payment = TRUE
)

SELECT
    jb.procedure_id,
    jb.patient_id,
    jb.provider_id,
    jb.patient_first_name,
    jb.patient_last_name,
    jb.procedure_code,
    jb.procedure_description,
    jb.procedure_date,
    jb.fee AS procedure_fee,
    jb.appointment_id,
    -- Appointment details
    a.appointment_date,
    a.appointment_time,
    a.appointment_status_desc,
    -- Claim details
    c.claim_id,
    c.claimproc_id,
    c.date_sent AS claim_date_sent,
    c.date_received AS claim_date_received,
    c.claim_status,
    c.insurance_estimate,
    c.insurance_payment,
    c.write_off,
    c.tracking_status,
    -- Payment details
    p.payment_id,
    p.paysplit_id,
    p.payment_date,
    p.split_amount AS patient_payment,
    p.payment_type,
    p.split_type_desc,
    -- Timeline calculations
    DATEDIFF(jb.procedure_date, a.appointment_date) AS days_appointment_to_procedure,
    DATEDIFF(c.date_sent, jb.procedure_date) AS days_procedure_to_claim,
    DATEDIFF(c.date_received, c.date_sent) AS days_claim_to_payment,
    DATEDIFF(p.payment_date, jb.procedure_date) AS days_procedure_to_payment,
    -- Status calculations
    CASE
        WHEN c.claim_id IS NULL THEN FALSE
        ELSE TRUE
    END AS has_insurance_claim,
    CASE
        WHEN c.insurance_payment > 0 THEN TRUE
        ELSE FALSE
    END AS has_insurance_payment,
    CASE
        WHEN p.payment_id IS NULL THEN FALSE
        ELSE TRUE
    END AS has_patient_payment,
    -- Financial status
    jb.fee - COALESCE(c.insurance_payment, 0) - COALESCE(c.write_off, 0) - COALESCE(p.split_amount, 0) AS remaining_balance,
    -- Journey timestamp order
    a.appointment_date AS journey_start_date,
    jb.procedure_date,
    c.date_sent AS claim_sent_date,
    c.date_received AS claim_received_date,
    p.payment_date,
    -- Overall journey status
    CASE
        WHEN jb.fee - COALESCE(c.insurance_payment, 0) - COALESCE(c.write_off, 0) - COALESCE(p.split_amount, 0) <= 0 
            THEN 'Complete'
        WHEN c.claim_id IS NOT NULL AND c.insurance_payment IS NULL 
            THEN 'Awaiting Insurance'
        WHEN c.claim_id IS NOT NULL AND c.insurance_payment > 0 AND p.payment_id IS NULL 
            THEN 'Awaiting Patient Payment'
        WHEN c.claim_id IS NULL AND p.payment_id IS NULL 
            THEN 'Unbilled'
        ELSE 'In Progress'
    END AS journey_status,
    -- Add created_at and updated_at for tracking
    CURRENT_TIMESTAMP as model_created_at,
    CURRENT_TIMESTAMP as model_updated_at
FROM journey_base jb
LEFT JOIN appointment_info a 
    ON jb.appointment_id = a.appointment_id
LEFT JOIN claim_info c 
    ON jb.procedure_id = c.procedure_id
LEFT JOIN payment_info p 
    ON jb.procedure_id = p.procedure_id