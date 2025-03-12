with source as (
    select * from {{ source('opendental', 'payment') }}
),

renamed as (
    select
        -- Primary key
        PayNum as payment_id,

        -- Relationships
        PatNum as patient_id,
        ClinicNum as clinic_id,
        PayType as payment_type_id,
        DepositNum as deposit_id,
        SecUserNumEntry as created_by_user_id,

        -- Payment details
        PayDate as payment_date,
        PayAmt as payment_amount,
        MerchantFee as merchant_fee,
        CheckNum as check_number,
        BankBranch as bank_branch,
        ExternalId as external_id,

        -- Status flags
        IsSplit as is_split_flag,
        IsRecurringCC as is_recurring_cc_flag,
        IsCcCompleted as is_cc_completed_flag,
        PaymentStatus as payment_status,
        ProcessStatus as process_status,
        PaymentSource as payment_source,

        -- Recurring payment info
        RecurringChargeDate as recurring_charge_date,

        -- Dates
        DateEntry as entry_date,
        SecDateTEdit as updated_at,

        -- Notes (may contain PHI)
        PayNote as payment_notes,
        Receipt as receipt_text,

        -- Add metadata
        current_timestamp() as _loaded_at
    from source
)

select * from renamed