/*
    Intermediate model for payment allocations
    Connects payments with their splits across procedures
    Part of System C: Payment Allocation & Reconciliation
*/

WITH payment_base AS (
    SELECT
        payment_id,
        patient_id,
        payment_date,
        payment_amount,
        payment_type,
        check_num,
        bank_branch,
        payment_source,
        payment_method_id
    FROM {{ ref('stg_opendental__payment') }}
),

payment_splits AS (
    SELECT
        paysplit_id,
        payment_id,
        patient_id,
        procedure_id,
        split_amount,
        is_payment, -- FALSE indicates an adjustment through PaySplit
        provider_id,
        split_type,  -- 0=normal, 288=unearned, 439=TP prepayment
        date_override
    FROM {{ ref('stg_opendental__paysplit') }}
),

procedure_info AS (
    SELECT
        procedure_id,
        procedure_code,
        procedure_date,
        procedure_status
    FROM {{ ref('stg_opendental__procedurelog') }}
    WHERE procedure_id IS NOT NULL
)

SELECT
    ps.paysplit_id,
    ps.payment_id,
    ps.patient_id,
    ps.procedure_id,
    ps.split_amount,
    ps.is_payment,
    ps.provider_id,
    ps.split_type,
    ps.date_override,
    p.payment_date,
    p.payment_amount,
    p.payment_type,
    p.check_num,
    p.bank_branch,
    p.payment_source,
    p.payment_method_id,
    proc.procedure_code,
    proc.procedure_date,
    proc.procedure_status,
    -- Calculated fields
    CASE
        WHEN ps.split_type = 0 THEN 'Normal'
        WHEN ps.split_type = 288 THEN 'Unearned Revenue'
        WHEN ps.split_type = 439 THEN 'Treatment Plan Prepayment'
        ELSE 'Other'
    END AS split_type_desc,
    COALESCE(ps.date_override, p.payment_date) AS effective_date,
    -- For AR calculation
    CASE
        WHEN COALESCE(ps.date_override, p.payment_date) <= CURRENT_DATE THEN TRUE
        ELSE FALSE
    END AS include_in_ar,
    -- Add created_at and updated_at for tracking
    CURRENT_TIMESTAMP as model_created_at,
    CURRENT_TIMESTAMP as model_updated_at
FROM payment_splits ps
LEFT JOIN payment_base p 
    ON ps.payment_id = p.payment_id
LEFT JOIN procedure_info proc 
    ON ps.procedure_id = proc.procedure_id