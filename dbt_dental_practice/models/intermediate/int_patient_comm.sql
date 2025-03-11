/*
    Intermediate model for patient communications
    Consolidates communication logs with context
    Part of System F: Patient-Clinic Communications
*/

WITH comm_logs AS (
    SELECT
        commlog_id,
        patient_id,
        user_id,
        comm_date,
        comm_time,
        mode_type,
        comm_type,
        note,
        sent_status,
        is_urgent
    FROM {{ ref('stg_opendental__commlog') }}
),

patient_data AS (
    SELECT
        patient_id,
        first_name,
        last_name,
        phone,
        email
    FROM {{ ref('int_patient_profile') }}
),

user_data AS (
    SELECT
        user_id,
        user_name,
        user_type
    FROM {{ ref('stg_opendental__userod') }}
)

SELECT
    cl.commlog_id,
    cl.patient_id,
    cl.user_id,
    cl.comm_date,
    cl.comm_time,
    cl.mode_type,
    cl.comm_type,
    cl.note,
    cl.sent_status,
    cl.is_urgent,
    pd.first_name AS patient_first_name,
    pd.last_name AS patient_last_name,
    pd.phone AS patient_phone,
    pd.email AS patient_email,
    ud.user_name,
    ud.user_type,
    -- Derive timestamps
    DATETIME(cl.comm_date, IFNULL(cl.comm_time, '00:00:00')) AS comm_datetime,
    -- Categorize communication types
    CASE
        WHEN cl.comm_type = 'ApptRemind' THEN 'Appointment Reminder'
        WHEN cl.comm_type = 'Billing' THEN 'Billing Communication'
        WHEN cl.comm_type = 'Collection' THEN 'Collection Notice'
        WHEN cl.comm_type = 'Recall' THEN 'Recall Reminder'
        WHEN cl.comm_type = 'Insurance' THEN 'Insurance Verification'
        WHEN cl.comm_type = 'Treatment' THEN 'Treatment Plan'
        ELSE cl.comm_type
    END AS comm_type_desc,
    -- Categorize communication modes
    CASE
        WHEN cl.mode_type = 'Email' THEN 'Email'
        WHEN cl.mode_type = 'Phone' THEN 'Phone Call'
        WHEN cl.mode_type = 'Text' THEN 'Text Message'
        WHEN cl.mode_type = 'Mail' THEN 'Postal Mail'
        WHEN cl.mode_type = 'InPerson' THEN 'In Person'
        WHEN cl.mode_type = 'Portal' THEN 'Patient Portal'
        ELSE cl.mode_type
    END AS mode_type_desc,
    -- Delivery status
    CASE
        WHEN cl.sent_status = 'Sent' THEN 'Sent'
        WHEN cl.sent_status = 'Received' THEN 'Received/Read'
        WHEN cl.sent_status = 'Failed' THEN 'Failed'
        WHEN cl.sent_status = 'Pending' THEN 'Pending'
        ELSE 'Unknown'
    END AS delivery_status,
    -- Add created_at and updated_at for tracking
    CURRENT_TIMESTAMP as model_created_at,
    CURRENT_TIMESTAMP as model_updated_at
FROM comm_logs cl
LEFT JOIN patient_data pd 
    ON cl.patient_id = pd.patient_id
LEFT JOIN user_data ud 
    ON cl.user_id = ud.user_id