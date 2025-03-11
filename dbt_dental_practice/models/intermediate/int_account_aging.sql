/*
    Intermediate model for account aging
    Calculates aging buckets for accounts receivable
    Part of System D: AR Analysis
*/

WITH procedure_balances AS (
    -- Calculate current balance for each completed procedure
    SELECT
        p.procedure_id,
        p.patient_id,
        pat.family_id,
        p.procedure_date,
        p.fee,
        p.procedure_status,
        -- Sum all payments and adjustments
        COALESCE(SUM(ps.split_amount), 0) AS patient_payments,
        COALESCE(SUM(cp.insurance_payment), 0) AS insurance_payments,
        COALESCE(SUM(cp.write_off), 0) AS insurance_writeoffs,
        -- Calculate remaining balance
        p.fee - COALESCE(SUM(ps.split_amount), 0) - 
                COALESCE(SUM(cp.insurance_payment), 0) - 
                COALESCE(SUM(cp.write_off), 0) AS remaining_balance,
        -- Calculate days since procedure
        DATEDIFF(CURRENT_DATE, p.procedure_date) AS days_since_procedure
    FROM {{ ref('int_procedure_complete') }} p
    JOIN {{ ref('int_patient_profile') }} pat 
        ON p.patient_id = pat.patient_id
    LEFT JOIN {{ ref('int_payment_allocated') }} ps 
        ON p.procedure_id = ps.procedure_id AND ps.is_payment = TRUE
    LEFT JOIN {{ ref('int_claim_details') }} cp 
        ON p.procedure_id = cp.procedure_id
    WHERE p.procedure_status IN ('C', 'EC') -- Only completed procedures
    GROUP BY 
        p.procedure_id,
        p.patient_id,
        pat.family_id,
        p.procedure_date,
        p.fee,
        p.procedure_status
),

family_aging AS (
    -- Aggregate to family level with aging buckets
    SELECT
        family_id,
        SUM(CASE WHEN remaining_balance > 0 THEN remaining_balance ELSE 0 END) AS total_balance,
        -- Aging buckets
        SUM(CASE WHEN days_since_procedure <= 30 AND remaining_balance > 0 
                THEN remaining_balance ELSE 0 END) AS current_0_30,
        SUM(CASE WHEN days_since_procedure > 30 AND days_since_procedure <= 60 AND remaining_balance > 0 
                THEN remaining_balance ELSE 0 END) AS aging_31_60,
        SUM(CASE WHEN days_since_procedure > 60 AND days_since_procedure <= 90 AND remaining_balance > 0 
                THEN remaining_balance ELSE 0 END) AS aging_61_90,
        SUM(CASE WHEN days_since_procedure > 90 AND remaining_balance > 0 
                THEN remaining_balance ELSE 0 END) AS aging_91_plus,
        -- Procedure counts by aging
        COUNT(CASE WHEN days_since_procedure <= 30 AND remaining_balance > 0 
                THEN procedure_id END) AS current_procedure_count,
        COUNT(CASE WHEN days_since_procedure > 30 AND days_since_procedure <= 60 AND remaining_balance > 0 
                THEN procedure_id END) AS aging_31_60_procedure_count,
        COUNT(CASE WHEN days_since_procedure > 60 AND days_since_procedure <= 90 AND remaining_balance > 0 
                THEN procedure_id END) AS aging_61_90_procedure_count,
        COUNT(CASE WHEN days_since_procedure > 90 AND remaining_balance > 0 
                THEN procedure_id END) AS aging_91_plus_procedure_count,
        -- Family totals
        COUNT(DISTINCT patient_id) AS patient_count,
        COUNT(DISTINCT CASE WHEN remaining_balance > 0 THEN procedure_id END) AS outstanding_procedure_count,
        MAX(days_since_procedure) AS oldest_balance_days
    FROM procedure_balances
    WHERE remaining_balance > 0
    GROUP BY family_id
),

patient_aging AS (
    -- Aggregate to patient level with aging buckets
    SELECT
        patient_id,
        family_id,
        SUM(CASE WHEN remaining_balance > 0 THEN remaining_balance ELSE 0 END) AS total_balance,
        -- Aging buckets
        SUM(CASE WHEN days_since_procedure <= 30 AND remaining_balance > 0 
                THEN remaining_balance ELSE 0 END) AS current_0_30,
        SUM(CASE WHEN days_since_procedure > 30 AND days_since_procedure <= 60 AND remaining_balance > 0 
                THEN remaining_balance ELSE 0 END) AS aging_31_60,
        SUM(CASE WHEN days_since_procedure > 60 AND days_since_procedure <= 90 AND remaining_balance > 0 
                THEN remaining_balance ELSE 0 END) AS aging_61_90,
        SUM(CASE WHEN days_since_procedure > 90 AND remaining_balance > 0 
                THEN remaining_balance ELSE 0 END) AS aging_91_plus,
        -- Procedure counts
        COUNT(DISTINCT CASE WHEN remaining_balance > 0 THEN procedure_id END) AS outstanding_procedure_count,
        MAX(days_since_procedure) AS oldest_balance_days
    FROM procedure_balances
    WHERE remaining_balance > 0
    GROUP BY patient_id, family_id
)

-- Final output combining both family and patient level aging
SELECT
    pa.patient_id,
    p.first_name,
    p.last_name,
    pa.family_id,
    -- Patient-level aging
    pa.total_balance AS patient_balance,
    pa.current_0_30 AS patient_current_0_30,
    pa.aging_31_60 AS patient_aging_31_60,
    pa.aging_61_90 AS patient_aging_61_90,
    pa.aging_91_plus AS patient_aging_91_plus,
    pa.outstanding_procedure_count AS patient_outstanding_procedures,
    pa.oldest_balance_days AS patient_oldest_days,
    -- Family-level aging
    fa.total_balance AS family_balance,
    fa.current_0_30 AS family_current_0_30,
    fa.aging_31_60 AS family_aging_31_60,
    fa.aging_61_90 AS family_aging_61_90,
    fa.aging_91_plus AS family_aging_91_plus,
    fa.outstanding_procedure_count AS family_outstanding_procedures,
    fa.oldest_balance_days AS family_oldest_days,
    fa.patient_count AS family_patient_count,
    -- Calculated fields and risk indicators
    CASE
        WHEN fa.aging_91_plus > 0 THEN 'High Risk'
        WHEN fa.aging_61_90 > 0 THEN 'Medium Risk'
        WHEN fa.aging_31_60 > 0 THEN 'Low Risk'
        ELSE 'Current'
    END AS collection_risk_level,
    CASE
        WHEN fa.aging_91_plus > 0 THEN TRUE
        ELSE FALSE
    END AS flag_for_collections,
    -- Percentage calculations for aging buckets (patient level)
    CASE 
        WHEN pa.total_balance = 0 THEN 0
        ELSE ROUND((pa.current_0_30 / pa.total_balance) * 100, 2)
    END AS patient_current_percent,
    CASE 
        WHEN pa.total_balance = 0 THEN 0
        ELSE ROUND((pa.aging_31_60 / pa.total_balance) * 100, 2)
    END AS patient_31_60_percent,
    CASE 
        WHEN pa.total_balance = 0 THEN 0
        ELSE ROUND((pa.aging_61_90 / pa.total_balance) * 100, 2)
    END AS patient_61_90_percent,
    CASE 
        WHEN pa.total_balance = 0 THEN 0
        ELSE ROUND((pa.aging_91_plus / pa.total_balance) * 100, 2)
    END AS patient_91_plus_percent,
    -- Add created_at and updated_at for tracking
    CURRENT_TIMESTAMP as model_created_at,
    CURRENT_TIMESTAMP as model_updated_at
FROM patient_aging pa
JOIN {{ ref('int_patient_profile') }} p 
    ON pa.patient_id = p.patient_id
JOIN family_aging fa 
    ON pa.family_id = fa.family_id
WHERE pa.total_balance > 0