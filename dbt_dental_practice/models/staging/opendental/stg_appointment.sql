with source as (
    select * from {{ source('opendental', 'appointment') }}
),

renamed as (
    select
        -- Keys
        AptNum as appointment_id,
        PatNum as patient_id,
        ProvNum as provider_id,
        ProvHyg as hygienist_id,
        Assistant as assistant_id,
        ClinicNum as clinic_id,
        Op as operatory_id,
        AppointmentTypeNum as appointment_type_id,
        NextAptNum as next_appointment_id,
        UnschedStatus as unscheduled_status_id,
        InsPlan1 as primary_insurance_plan_id,
        InsPlan2 as secondary_insurance_plan_id,
        
        -- Appointment timing
        AptDateTime as appointment_datetime,
        DATE(AptDateTime) as appointment_date,
        TIME(AptDateTime) as appointment_time,
        DateTimeAskedToArrive as asked_to_arrive_datetime,
        DateTimeArrived as arrived_datetime,
        DateTimeSeated as seated_datetime,
        DateTimeDismissed as dismissed_datetime,
        
        -- Patient flow calculations
        CASE 
            WHEN DateTimeArrived > '0001-01-01 00:00:00' 
            THEN TIMESTAMPDIFF(MINUTE, DateTimeAskedToArrive, DateTimeArrived) 
            ELSE NULL 
        END as minutes_arrival_difference,
        
        CASE 
            WHEN DateTimeSeated > '0001-01-01 00:00:00' AND DateTimeArrived > '0001-01-01 00:00:00'
            THEN TIMESTAMPDIFF(MINUTE, DateTimeArrived, DateTimeSeated) 
            ELSE NULL 
        END as wait_time_minutes,
        
        CASE 
            WHEN DateTimeDismissed > '0001-01-01 00:00:00' AND DateTimeSeated > '0001-01-01 00:00:00'
            THEN TIMESTAMPDIFF(MINUTE, DateTimeSeated, DateTimeDismissed) 
            ELSE NULL 
        END as chair_time_minutes,
        
        -- Appointment details
        AptStatus as appointment_status,
        Pattern as time_pattern,
        PatternSecondary as secondary_time_pattern,
        LENGTH(Pattern) * 5 as duration_minutes,
        TimeLocked as is_time_locked,
        Priority as priority,
        
        -- Confirmation
        Confirmed as confirmation_status,
        
        -- Classification flags
        IsHygiene as is_hygiene_appointment,
        IsNewPatient as is_new_patient,
        
        -- Display settings
        ColorOverride as color_override,
        ProcsColored as colored_procedures,
        ProvBarText as provider_bar_text,
        
        -- Procedure information
        ProcDescript as procedure_description,
        Note as appointment_note,
        
        -- Metadata
        DateTStamp as updated_at,
        SecUserNumEntry as created_by_user_id,
        SecDateTEntry as created_at,
        ItemOrderPlanned as planned_order
    from source
)

select * from renamed