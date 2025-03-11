with source as (
    select * from {{ source('opendental', 'allergydef') }}
),

renamed as (
    select
        -- Primary key
        AllergyDefNum as allergy_definition_id,

        -- Relationships
        MedicationNum as medication_id,

        -- Details
        Description as allergy_description,
        UniiCode as unii_code,
        SnomedType as snomed_type,

        -- Status
        IsHidden as is_hidden_flag,

        -- Metadata
        DateTStamp as updated_at
    from source
)

select * from renamed
