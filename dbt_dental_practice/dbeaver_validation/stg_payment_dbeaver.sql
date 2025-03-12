/*
  DEVELOPMENT VERSION FOR DBEAVER TESTING
  DBT Version: models/staging/sql_validation/stg_payment_validation.sql
  
  Changes needed for DBT:
  - Replace direct table references with {{ ref() }}
  - Remove _dev suffix from filename
*/
-- Replace {{ ref('stg_payment') }} with direct table reference
with payment_data as (
    select 
        PayNum as payment_id,
        PatNum as patient_id,
        PayType as payment_type_id,
        PayAmt as payment_amount,
        PayDate as payment_date,
        PayNote as payment_notes
    from opendental_analytics_opendentalbackup_02_28_2025.payment
    where PayDate between '2022-02-28' and '2025-02-28'
),

validation_checks as (
    -- Type 0 validation (should always be zero)
    select 
        'type_0_nonzero' as check_name,
        payment_id,
        payment_type_id,
        payment_amount,
        payment_date,
        payment_notes,
        'Error: Type 0 payment with non-zero amount' as validation_message
    from payment_data
    where payment_type_id = 0 and payment_amount != 0

    union all

    -- Type 72 validation (should always be negative)
    select 
        'type_72_positive' as check_name,
        payment_id,
        payment_type_id,
        payment_amount,
        payment_date,
        payment_notes,
        'Error: Type 72 payment with non-negative amount' as validation_message
    from payment_data
    where payment_type_id = 72 and payment_amount >= 0

    union all

    -- Negative amount validation (excluding reversals with notes)
    select 
        'unexpected_negative' as check_name,
        payment_id,
        payment_type_id,
        payment_amount,
        payment_date,
        payment_notes,
        'Warning: Negative amount needs review' as validation_message
    from payment_data
    where payment_amount < 0 
    and payment_type_id != 72
    and payment_notes not like '%refund%'
    and payment_notes not like '%reversal%'
    and payment_notes not like '%given back%'
)

select * from validation_checks
where validation_message is not null
order by 
    case 
        when validation_message like 'Error%' then 1
        when validation_message like 'Warning%' then 2
        else 3
    end,
    payment_type_id,
    payment_id;