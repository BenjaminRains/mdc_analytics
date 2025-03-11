# DBT Intermediate Models Plan for Dental Practice

## Overview
The intermediate layer will transform our staging tables into business-focused models that align with the key systems in our dental practice workflow. The goal is to create consolidated models that can be easily used for downstream analytics.

## Naming Convention
- Prefix all intermediate models with `int_`
- Group-related models with a common prefix after `int_`, e.g., `int_patient_`
- Use active verbs for transformed or aggregated models, e.g., `int_payment_allocated`

## Model Organization

### 1. Patient 360 Models
```sql
-- int_patient_profile
-- Consolidates patient demographic, family, and contact information
SELECT
  p.patient_id,
  p.first_name,
  p.last_name,
  p.birthdate,
  p.phone,
  p.email,
  pl.family_id,
  zc.city,
  zc.state,
  -- Additional patient information
FROM {{ ref('stg_opendental__patient') }} p
LEFT JOIN {{ ref('stg_opendental__patientlink') }} pl ON p.patient_id = pl.patient_id
LEFT JOIN {{ ref('stg_opendental__zipcode') }} zc ON p.zipcode = zc.zipcode
```

### 2. Appointment & Scheduling Models
```sql
-- int_appointment_details
-- Enhanced appointment information with provider, type, and status
SELECT
  a.appointment_id,
  a.patient_id,
  a.provider_id,
  a.appointment_date,
  a.appointment_time,
  a.appointment_status,
  at.appointment_type_name,
  at.appointment_length,
  pr.provider_name,
  -- Additional appointment details
FROM {{ ref('stg_opendental__appointment') }} a
LEFT JOIN {{ ref('stg_opendental__appointmenttype') }} at ON a.appointment_type_id = at.appointment_type_id
LEFT JOIN {{ ref('stg_opendental__provider') }} pr ON a.provider_id = pr.provider_id
```

### 3. Procedure & Fee Models
```sql
-- int_procedure_complete
-- Comprehensive procedure data with codes, fees, and providers
SELECT
  pl.procedure_id,
  pl.patient_id,
  pl.provider_id,
  pl.procedure_date,
  pl.procedure_status,
  pc.procedure_code,
  pc.procedure_description,
  f.fee_amount,
  fs.fee_schedule_name,
  pn.procedure_note,
  -- Additional procedure information
FROM {{ ref('stg_opendental__procedurelog') }} pl
LEFT JOIN {{ ref('stg_opendental__procedurecode') }} pc ON pl.procedure_code = pc.procedure_code
LEFT JOIN {{ ref('stg_opendental__fee') }} f ON pl.procedure_code = f.procedure_code AND f.fee_schedule_id = pl.fee_schedule_id
LEFT JOIN {{ ref('stg_opendental__feesched') }} fs ON f.fee_schedule_id = fs.fee_schedule_id
LEFT JOIN {{ ref('stg_opendental__procnote') }} pn ON pl.procedure_id = pn.procedure_id
```

### 4. Insurance & Claims Models
```sql
-- int_insurance_coverage
-- Patient insurance coverage details
SELECT
  pp.patient_id,
  pp.patplan_id,
  is.inssub_id,
  is.subscriber_id,
  ip.carrier_id,
  ip.plan_name,
  ip.plan_type,
  c.carrier_name,
  c.carrier_address,
  c.carrier_phone,
  -- Additional insurance information
FROM {{ ref('stg_opendental__patplan') }} pp
LEFT JOIN {{ ref('stg_opendental__inssub') }} is ON pp.inssub_id = is.inssub_id
LEFT JOIN {{ ref('stg_opendental__insplan') }} ip ON is.plan_id = ip.plan_id
LEFT JOIN {{ ref('stg_opendental__carrier') }} c ON ip.carrier_id = c.carrier_id

-- int_claim_details
-- Claim details with procedures and status
SELECT
  c.claim_id,
  c.patient_id,
  c.carrier_id,
  c.date_sent,
  c.date_received,
  c.claim_status,
  c.claim_amount,
  cp.claimproc_id,
  cp.procedure_id,
  cp.status_code,
  cp.insurance_estimate,
  cp.insurance_payment,
  ct.tracking_status,
  ct.tracking_note,
  -- Additional claim information
FROM {{ ref('stg_opendental__claim') }} c
LEFT JOIN {{ ref('stg_opendental__claimproc') }} cp ON c.claim_id = cp.claim_id
LEFT JOIN {{ ref('stg_opendental__claimtracking') }} ct ON c.claim_id = ct.claim_id
```

### 5. Payment & AR Models
```sql
-- int_payment_allocated
-- Payments with allocation to procedures
SELECT
  p.payment_id,
  p.patient_id,
  p.payment_date,
  p.payment_amount,
  p.payment_type,
  ps.paysplit_id,
  ps.procedure_id,
  ps.split_amount,
  ps.provider_id,
  -- Additional payment information
FROM {{ ref('stg_opendental__payment') }} p
LEFT JOIN {{ ref('stg_opendental__paysplit') }} ps ON p.payment_id = ps.payment_id

-- int_adjustment_details
-- Account adjustments with context
SELECT
  a.adjustment_id,
  a.patient_id,
  a.adjustment_date,
  a.adjustment_amount,
  a.adjustment_type,
  a.provider_id,
  a.procedure_id,
  -- Additional adjustment information  
FROM {{ ref('stg_opendental__adjustment') }} a
```

### 6. Communication Models
```sql
-- int_patient_communication
-- All patient communications consolidated
SELECT
  cl.commlog_id,
  cl.patient_id,
  cl.comm_date,
  cl.comm_type,
  cl.comm_mode,
  cl.comm_subject,
  cl.comm_note,
  cl.user_id,
  -- Additional communication information
FROM {{ ref('stg_opendental__commlog') }} cl
```

### 7. Referral Models
```sql
-- int_referral_complete
-- Complete referral information
SELECT
  r.referral_id,
  r.patient_id,
  r.provider_id,
  r.referral_type,
  r.referral_date,
  r.referral_to,
  r.referral_from,
  r.referral_reason,
  ra.ref_attachment_id,
  ra.attachment_type,
  -- Additional referral information
FROM {{ ref('stg_opendental__referral') }} r
LEFT JOIN {{ ref('stg_opendental__refattach') }} ra ON r.referral_id = ra.referral_id
```

### 8. AR Aging Models
```sql
-- int_account_aging
-- Age accounts receivable by aging buckets
SELECT
  fa.family_id,
  fa.as_of_date,
  fa.total_amount,
  fa.current_amount,
  fa.amount_30_60,
  fa.amount_60_90,
  fa.amount_over_90,
  -- Additional aging information
FROM {{ ref('stg_opendental__famaging') }} fa
```

## Cross-System Intermediate Models

These models connect across different business systems to provide comprehensive views:

### 1. Patient Financial Summary
```sql
-- int_patient_financial
-- Complete financial picture of patient
SELECT
  p.patient_id,
  p.first_name,
  p.last_name,
  SUM(pl.fee) as total_treatment_value,
  SUM(ps.split_amount) as total_patient_payments,
  SUM(cp.insurance_payment) as total_insurance_payments,
  SUM(a.adjustment_amount) as total_adjustments,
  -- Calculate outstanding balance
  SUM(pl.fee) - SUM(ps.split_amount) - SUM(cp.insurance_payment) - SUM(a.adjustment_amount) as current_balance,
  -- Additional financial metrics
FROM {{ ref('int_patient_profile') }} p
LEFT JOIN {{ ref('int_procedure_complete') }} pl ON p.patient_id = pl.patient_id
LEFT JOIN {{ ref('int_payment_allocated') }} ps ON p.patient_id = ps.patient_id
LEFT JOIN {{ ref('int_claim_details') }} cp ON p.patient_id = cp.patient_id
LEFT JOIN {{ ref('int_adjustment_details') }} a ON p.patient_id = a.patient_id
GROUP BY p.patient_id, p.first_name, p.last_name
```

### 2. Treatment Journey
```sql
-- int_treatment_journey
-- End-to-end patient treatment journey
SELECT
  p.patient_id,
  a.appointment_id,
  a.appointment_date,
  pl.procedure_id,
  pl.procedure_code,
  pl.procedure_description,
  c.claim_id,
  c.claim_status,
  ps.payment_id,
  ps.split_amount,
  -- Journey timestamps
  a.appointment_date as journey_start_date,
  pl.procedure_date,
  c.date_sent as claim_sent_date,
  c.date_received as claim_received_date,
  ps.payment_date as payment_date,
  -- Additional journey information
FROM {{ ref('int_patient_profile') }} p
LEFT JOIN {{ ref('int_appointment_details') }} a ON p.patient_id = a.patient_id
LEFT JOIN {{ ref('int_procedure_complete') }} pl ON a.appointment_id = pl.appointment_id
LEFT JOIN {{ ref('int_claim_details') }} c ON pl.procedure_id = c.procedure_id
LEFT JOIN {{ ref('int_payment_allocated') }} ps ON pl.procedure_id = ps.procedure_id
```

## Implementation Strategy

1. **Build foundation models first**:
   - Start with patient_profile, procedure_complete, and appointment_details
   - These provide the core entities for other models

2. **Layer in financial models**:
   - Build insurance_coverage, claim_details, payment_allocated
   - These capture the financial flow from procedure to payment

3. **Add communication and referral models**:
   - Build patient_communication and referral_complete
   - These track patient touchpoints outside of direct treatment

4. **Create cross-system models last**:
   - patient_financial and treatment_journey models connect systems
   - These provide the comprehensive views needed for analytics

5. **Testing strategy**:
   - Test entity relationships across models
   - Verify reconciliation between financial models
   - Validate aging calculations against source system

## Documentation Requirements

Document each intermediate model with:
1. Model purpose and business context
2. Relationship to the business process flow chart systems
3. Key transformations applied
4. Known edge cases or data quality issues
5. Example queries for common use cases