with source as (
    select * from {{ source('opendental', 'allergy') }}
),

renamed as (
    select
        -- Primary key
        AllergyNum as allergy_id,

        -- Relationships
        AllergyDefNum as allergy_definition_id,
        PatNum as patient_id,

        -- Allergy details
        Reaction as reaction_description,
        SnomedReaction as snomed_reaction_code,
        StatusIsActive as is_active_flag,

        -- Dates
        DateAdverseReaction as adverse_reaction_date,
        DateTStamp as updated_at
    from source
)

select * from renamed
