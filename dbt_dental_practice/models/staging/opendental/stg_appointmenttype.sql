with source as (
    select * from {{ source('opendental', 'appointmenttype') }}
),

renamed as (
    select
        -- Primary key
        AppointmentTypeNum as appointment_type_id,
        
        -- Basic information
        AppointmentTypeName as type_name,
        AppointmentTypeColor as color_value,
        
        -- Display and UI settings
        ItemOrder as sort_order,
        IsHidden as is_hidden,
        
        -- Time pattern (each X represents a 5-minute increment)
        Pattern as time_pattern,
        LENGTH(Pattern) * 5 as duration_minutes,
        
        -- Associated procedure codes
        CodeStr as associated_procedure_codes,
        CodeStrRequired as required_procedure_codes,
        RequiredProcCodesNeeded as minimum_required_codes_count,
        
        -- Scheduling constraints
        BlockoutTypes as blockout_type_list
    from source
)

select * from renamed
