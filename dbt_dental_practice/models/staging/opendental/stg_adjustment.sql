with source as (
    select * from {{ source('opendental', 'adjustment') }}
),

renamed as (
    select
        -- Keys
        AdjNum as adjustment_id,
        PatNum as patient_id,
        ProcNum as procedure_id,
        ProvNum as provider_id,
        ClinicNum as clinic_id,
        StatementNum as statement_id,
        AdjType as adjustment_type_id,
        TaxTransID as tax_transaction_id,
        
        -- Adjustment details
        AdjAmt as adjustment_amount,
        AdjNote as adjustment_note,
        
        -- Dates
        AdjDate as adjustment_date,
        ProcDate as procedure_date,
        DateEntry as entry_date,
        
        -- Calculated fields
        CASE 
            WHEN AdjAmt > 0 THEN 'positive'
            WHEN AdjAmt < 0 THEN 'negative'
            ELSE 'zero'
        END as adjustment_direction,
        
        CASE 
            WHEN ProcNum > 0 THEN true
            ELSE false
        END as is_procedure_adjustment,
        
        -- Metadata and system fields
        SecUserNumEntry as created_by_user_id,
        SecDateTEdit as updated_at
    from source
)

select * from renamed
