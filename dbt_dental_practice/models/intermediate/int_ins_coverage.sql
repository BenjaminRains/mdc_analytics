/*
    Intermediate model for patient insurance coverage
    Links patients to their insurance plans and carriers
    Part of System B: Insurance Processing
*/

WITH patient_plans AS (
    SELECT
        patplan_id,
        patient_id,
        inssub_id,
        ordinal,
        relationship_to_subscriber,
        pat_status,
        is_primary
    FROM {{ ref('stg_opendental__patplan') }}
),

insurance_subscribers AS (
    SELECT
        inssub_id,
        subscriber_id,  -- This is typically the patient_id of the subscriber
        plan_id,
        subscriber_name_first,
        subscriber_name_last,
        subscriber_dob
    FROM {{ ref('stg_opendental__inssub') }}
),

insurance_plans AS (
    SELECT
        plan_id,
        carrier_id,
        plan_name,
        plan_type,
        group_name,
        group_num,
        employer_id,
        is_medical,
        plan_note
    FROM {{ ref('stg_opendental__insplan') }}
),

insurance_carriers AS (
    SELECT
        carrier_id,
        carrier_name,
        address,
        address2,
        city,
        state,
        zip,
        phone,
        electronic_id  -- Often the payer ID for electronic claims
    FROM {{ ref('stg_opendental__carrier') }}
),

insurance_verifications AS (
    SELECT
        patient_id,
        inssub_id,
        last_verify_date,
        benefits_note,
        status
    FROM {{ ref('stg_opendental__insverify') }}
    WHERE status IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (PARTITION BY patient_id, inssub_id ORDER BY last_verify_date DESC) = 1
)

SELECT
    pp.patplan_id,
    pp.patient_id,
    pp.inssub_id,
    pp.ordinal,
    pp.relationship_to_subscriber,
    pp.pat_status,
    pp.is_primary,
    is.subscriber_id,
    is.plan_id,
    is.subscriber_name_first,
    is.subscriber_name_last,
    is.subscriber_dob,
    ip.carrier_id,
    ip.plan_name,
    ip.plan_type,
    ip.group_name,
    ip.group_num,
    ip.employer_id,
    ip.is_medical,
    ip.plan_note,
    c.carrier_name,
    c.address,
    c.address2,
    c.city,
    c.state,
    c.zip,
    c.phone,
    c.electronic_id,
    iv.last_verify_date,
    iv.benefits_note,
    iv.status AS verification_status,
    -- Calculated fields
    CASE
        WHEN pp.is_primary = TRUE THEN 'Primary'
        WHEN pp.ordinal = 1 THEN 'Secondary'
        WHEN pp.ordinal = 2 THEN 'Tertiary'
        ELSE 'Other'
    END AS insurance_rank,
    CASE
        WHEN iv.last_verify_date IS NULL THEN 'Never Verified'
        WHEN DATEDIFF(CURRENT_DATE, iv.last_verify_date) > 365 THEN 'Verification Expired'
        ELSE 'Active'
    END AS insurance_status,
    -- Add created_at and updated_at for tracking
    CURRENT_TIMESTAMP as model_created_at,
    CURRENT_TIMESTAMP as model_updated_at
FROM patient_plans pp
LEFT JOIN insurance_subscribers is 
    ON pp.inssub_id = is.inssub_id
LEFT JOIN insurance_plans ip 
    ON is.plan_id = ip.plan_id
LEFT JOIN insurance_carriers c 
    ON ip.carrier_id = c.carrier_id
LEFT JOIN insurance_verifications iv 
    ON pp.patient_id = iv.patient_id 
    AND pp.inssub_id = iv.inssub_id