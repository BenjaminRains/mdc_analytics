/*
    Intermediate model for insurance claim details
    Combines claim data with procedures and tracking status
    Part of System B: Insurance Processing
*/

WITH claim_base AS (
    SELECT
        claim_id,
        patient_id,
        inssub_id,
        date_sent,
        date_received,
        status,
        claim_type,
        plan_id,
        date_service,
        date_creation,
        carrier_id,
        claim_form_id,
        claim_fee
    FROM {{ ref('stg_opendental__claim') }}
),

claim_procedures AS (
    SELECT
        claimproc_id,
        claim_id,
        patient_id,
        provider_id,
        procedure_id,
        status,
        date_received,
        procedure_date,
        insurance_estimate,
        insurance_payment,
        write_off,
        remarks
    FROM {{ ref('stg_opendental__claimproc') }}
),

claim_payments AS (
    SELECT
        claim_payment_id,
        claim_id,
        carrier_id,
        check_date,
        check_num,
        check_amount,
        bank_branch,
        note
    FROM {{ ref('stg_opendental__claimpayment') }}
),

claim_tracking AS (
    SELECT
        claim_id,
        status AS tracking_status,
        date_tracked,
        note AS tracking_note
    FROM {{ ref('stg_opendental__claimtracking') }}
    WHERE status IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (PARTITION BY claim_id ORDER BY date_tracked DESC) = 1
),

procedures_info AS (
    SELECT
        procedure_id,
        procedure_code,
        procedure_date,
        fee
    FROM {{ ref('stg_opendental__procedurelog') }}
)

SELECT
    cb.claim_id,
    cb.patient_id,
    cb.inssub_id,
    cb.plan_id,
    cb.carrier_id,
    cb.date_sent,
    cb.date_received,
    cb.status AS claim_status,
    cb.claim_type,
    cb.date_service,
    cb.date_creation,
    cb.claim_form_id,
    cb.claim_fee,
    cp.claimproc_id,
    cp.provider_id,
    cp.procedure_id,
    cp.status AS claimproc_status,
    cp.date_received AS claimproc_date_received,
    cp.insurance_estimate,
    cp.insurance_payment,
    cp.write_off,
    cp.remarks,
    ct.tracking_status,
    ct.date_tracked,
    ct.tracking_note,
    cpm.claim_payment_id,
    cpm.check_date,
    cpm.check_num,
    cpm.check_amount,
    pi.procedure_code,
    pi.procedure_date,
    pi.fee AS procedure_fee,
    -- Calculated fields
    DATEDIFF(COALESCE(cb.date_received, CURRENT_DATE), cb.date_sent) AS days_to_process,
    CASE
        WHEN cb.status = 'S' THEN 'Sent'
        WHEN cb.status = 'R' THEN 'Received'
        WHEN cb.status = 'W' THEN 'Waiting to Send'
        WHEN cb.status = 'H' THEN 'History'
        ELSE 'Unknown'
    END AS claim_status_desc,
    CASE
        WHEN cp.status = 'R' THEN 'Received'
        WHEN cp.status = 'P' THEN 'Paid'
        WHEN cp.status = 'S' THEN 'Split'
        WHEN cp.status = 'E' THEN 'Estimate'
        WHEN cp.status = 'W' THEN 'WriteOff'
        WHEN cp.status = 'D' THEN 'Denied'
        ELSE cp.status
    END AS claimproc_status_desc,
    -- Add created_at and updated_at for tracking
    CURRENT_TIMESTAMP as model_created_at,
    CURRENT_TIMESTAMP as model_updated_at
FROM claim_base cb
LEFT JOIN claim_procedures cp 
    ON cb.claim_id = cp.claim_id
LEFT JOIN claim_tracking ct 
    ON cb.claim_id = ct.claim_id
LEFT JOIN claim_payments cpm 
    ON cb.claim_id = cpm.claim_id
LEFT JOIN procedures_info pi 
    ON cp.procedure_id = pi.procedure_id