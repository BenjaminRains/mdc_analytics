/*
  PAYMENT VALIDATION RULES
  =======================
  
  Purpose:
  Validates payment data patterns and business rules discovered during analysis.
  
  Key Validation Rules:
  1. Payment Type Rules:
     - Type 0: Administrative entries, must have $0 amount
     - Type 72: Refund entries, must have negative amounts
     - Other Types: Can have negative amounts if properly documented
  
  2. Negative Payment Rules:
     - Type 72: Expected to be negative (refunds)
     - Other Types: Allowed if payment_notes indicate:
       * Refunds
       * Reversals
       * Cash returns
     
  3. Observed Payment Type Patterns:
     - Type 69: High value payments (avg $964), can have refunds
     - Type 70: Regular payments (avg $307), can have same-day reversals
     - Type 71: Most common type (avg $296)
     - Type 574: Very high value (avg $17,693)
  
  Last Updated: 2024-03-XX
*/

with payment_data as (
    select * from {{ ref('stg_payment') }}
    where payment_date between '2022-02-28' and '2025-02-28'
),

validation_checks as (
    -- 1. Type 0 Validation
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

    -- 2. Type 72 Validation
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

    -- 3. Negative Amount Validation
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
    payment_id