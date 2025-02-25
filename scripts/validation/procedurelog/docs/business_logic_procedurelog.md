# ProcedureLog Business Logic

## Overview
This document defines the business logic for analyzing and validating the dental procedure lifecycle. The ProcedureLog table is the central entity recording all dental procedures with their status, fees, and relationships to patients, appointments, and payments.

## Core Entities

### ProcedureLog
The primary table tracking all dental procedures. Key fields include:
- **ProcNum**: Unique identifier for each procedure
- **PatNum**: Patient identifier 
- **ProcDate**: Date the procedure was scheduled or performed
- **DateComplete**: Date the procedure was completed (when applicable)
- **ProcStatus**: Status code indicating the procedure's current state
- **ProcFee**: Fee amount for the procedure
- **CodeNum**: Foreign key to the procedure code definition
- **AptNum**: Appointment number associated with the procedure (if any)

### Status Codes
The `ProcStatus` field uses the following values:
1. **Treatment Planned**: Procedure is planned but not yet performed (20.37% of procedures)
2. **Completed**: Procedure has been performed and completed (51.68% of procedures)
3. **Existing Current**: Existing condition that is currently relevant (6.00% of procedures)
4. **Existing Other**: Existing condition that is not currently relevant (0.48% of procedures)
5. **Referred**: Procedure referred to another provider (1.71% of procedures)
6. **Deleted**: Procedure was deleted/voided (15.83% of procedures)
7. **Condition**: A patient condition rather than a procedure (3.88% of procedures)
8. **Invalid**: Invalid or erroneous procedure entry (0.05% of procedures)

### Related Entities
- **procedurecode**: Defines the type of procedure (e.g., D0120, D1110)
- **appointment**: Appointments associated with procedures (52% of procedures have appointment links)
- **claimproc**: Insurance claim processing for procedures (64.63% of procedures have insurance claims)
- **paysplit**: Direct patient payments for procedures (25.33% of procedures have direct payments)
- **adjustment**: Adjustments applied to procedure fees (3.14% of procedures have adjustments)

## Payment Processing

Payments for procedures can come from multiple sources:
1. **Insurance Payments**: Recorded in `claimproc.InsPayAmt` (primary payment source)
2. **Direct Patient Payments**: Recorded in `paysplit.SplitAmt` (secondary payment source)
3. **Adjustments**: Recorded in `adjustment.AdjAmt` (write-offs, discounts)

### Payment Metrics
- **Total Paid**: Sum of all insurance and direct payments
- **Payment Ratio**: `Total Paid / ProcFee` (percentage of the fee that has been paid)
- **Overall Payment Rate**: 37.90% of all procedures have received payments
- **Total Payments Collected**: $2,789,143.13 across all procedures

### Payment Split Patterns
Payment splits are categorized as:
- **Normal Split**: 1-3 payment entries for a procedure (99.14% of procedures with payments)
- **Complex Split**: 4-15 payment entries (0.86% of procedures with payments)
- **Review Needed**: More than 15 payment entries (none observed in 2024 data)

### Payment by Status
- **Completed (Status 2)**: 73.29% have received payments, with 80.3% overall payment ratio
- **Treatment Planned (Status 1)**: 0.14% have received payments (typically pre-payments/deposits)
- **Other Statuses**: No payment activity observed for statuses 3-8

## Success Criteria

### Target Journey Success
A procedure is considered to have a successful payment journey when:
1. It has a `ProcStatus` of 2 (Completed) AND
2. Either:
   - It has a `ProcFee` of 0 and is not an excluded code, OR
   - It has a `ProcFee` > 0 and has a payment ratio ≥ 95%

### Success Rate Analysis
- **Overall success rate**: 62.84% of completed procedures (12,165 out of 19,358) meet success criteria
- **Breakdown of completed procedures**:
  - With zero fees: 15.2% (2,944 procedures)
  - Meeting 98%+ threshold: 59.7% (11,555 procedures)
  - Meeting 95-98% threshold: 1.3% (250 procedures)
  - Meeting 90-95% threshold: 1.2% (231 procedures)
  - Below 90% threshold: 22.6% (4,378 procedures)
  - No payment received: 11.5% (2,234 procedures)

### Excluded Codes
Certain procedure codes are excluded from payment validation:
- Administrative codes: `D9986` (Missed, 477 procedures), `D9987` (Cancelled, 1,096 procedures)
- Diagnostic codes: `D0120` (3,218 procedures), `D0140` (1,095 procedures), `D0190` (0), `D0350` (272)
- Teledentistry codes: `D9992`, `D9995`, `D9996` (all 0 occurrences)
- Other special codes: `~GRP~` (2,492 procedures), `Watch` (482), `Ztoth` (211), `00040` (478), `D2919` (1,327), `00051` (348), `D0171` (0), `D9430` (1)

## Validation Thresholds

### Fee Thresholds
- **Zero Fee**: Procedures with `ProcFee` = 0 (24.80% of procedures)
- **Under $100**: Procedures with fee < $100 (34.09% of procedures)
- **$100-$249**: Procedures with fee between $100-$249 (19.94% of procedures)
- **$250-$499**: Procedures with fee between $250-$499 (12.63% of procedures)
- **$500-$999**: Procedures with fee between $500-$999 (1.61% of procedures)
- **$1000-$1999**: Procedures with fee between $1000-$1999 (6.64% of procedures)
- **$2000+**: Procedures with fee ≥ $2000 (0.27% of procedures, max $25,500)

### Payment Ratio Thresholds
- **Strict (98%)**: Payment ratio ≥ 98% (11,555 completed procedures, 59.7%)
- **Current (95%)**: Payment ratio ≥ 95% (11,805 completed procedures, 61.0%)
- **Lenient (90%)**: Payment ratio ≥ 90% (12,036 completed procedures, 62.2%)
- **Below 90%**: Payment ratio < 90% (4,378 completed procedures, 22.6%)

### Zero-Fee Analysis
- **Excluded codes with zero fees**:
  - Completed (status 2): 2,584 procedures across 6 codes
  - Existing Current (status 3): 2,241 procedures
  - Treatment Planned (status 1): 744 procedures
- **Standard procedures with zero fees**:
  - Completed (status 2): 360 procedures across 44 codes
  - Referred (status 5): 614 procedures across 20 codes
  - Condition (status 7): 578 procedures
  - Deleted (status 6): 379 procedures

## Edge Cases
Analysis identified several edge cases requiring special attention:

- **Normal** (88.31%, 33,079 procedures): Follow expected payment patterns
- **Completed but unpaid** (5.96%, 2,234 procedures): Completed procedures with zero payments, representing $598,497.50 in unbilled/uncollected revenue across 110 procedure codes
- **Significant overpayment** (3.11%, 1,166 procedures): Payments exceed 105% of fee (154.72% average payment rate), resulting in $210,277.91 in excess payments
- **Completed but underpaid** (2.11%, 790 procedures): Received less than 50% of fee, with only 28.47% average collection rate, representing $169,318.01 in potential lost revenue
- **Minor overpayment** (0.46%, 173 procedures): Payments between 100-105% of fee
- **Non-completed with payment** (0.03%, 10 procedures): Non-completed procedures that received payments
- **Zero-fee payment** (0.02%, 7 procedures): Zero-fee procedures that received payments

### Monthly Pattern of Unpaid Procedures
Unpaid completed procedures follow a temporal pattern:

- **December**: 448 unpaid procedures ($80,931.00, avg $180.65)
- **September**: 234 unpaid procedures ($34,641.00, avg $148.04)
- **October**: 226 unpaid procedures ($62,571.00, avg $276.86)
- **May**: 173 unpaid procedures ($40,833.00, avg $236.03)
- **January**: 172 unpaid procedures ($52,108.00, avg $302.95)
- **March**: 161 unpaid procedures ($60,601.00, avg $376.40)
- **November**: 156 unpaid procedures ($32,559.00, avg $208.71)
- **July**: 151 unpaid procedures ($39,524.00, avg $261.75)
- **February**: 139 unpaid procedures ($41,562.00, avg $299.01)
- **April**: 131 unpaid procedures ($60,893.00, avg $464.83)
- **August**: 126 unpaid procedures ($33,529.00, avg $266.10)
- **June**: 117 unpaid procedures ($58,745.50, avg $502.10)

## Business Rules

### Status Transition Rules
1. Valid procedure status transitions:
   - Treatment Planned (1) → Completed (2) (primary intended flow)
   - Treatment Planned (1) → Deleted (6) (for canceled procedures)
   - Treatment Planned (1) → Referred (5) (when referring out)
   - Any status → Deleted (6) (administrative correction)

2. Statuses that should never transition once set:
   - Existing Current (3) and Existing Other (4) (represent patient conditions)
   - Condition (7) (permanent clinical notation)

3. DateComplete field should only be populated when ProcStatus = 2 (Completed)

### Payment Processing Rules
1. Collection expectation varies by procedure category:
   - Diagnostic procedures: Often $0 fee or write-off expected
   - Preventive procedures: 95% collection expected
   - Restorative procedures: 95-98% collection expected
   - Major procedures (over $500): 98% collection expected

2. Payment timing expectations:
   - Insurance payments typically received 15-45 days after procedure completion
   - Direct patient payments expected same-day for cash/card payments
   - Procedures without payments after 90 days require validation

3. Multi-procedure bundling:
   - When multiple procedures are performed in a single visit, payment is often applied to the primary procedure
   - Bundled procedures may have disproportionate payment distribution (some 0%, some >100%)

### Procedure Code Validation Rules
1. Certain codes must always have a fee (examples: crowns, fillings, extractions)
2. Certain codes should always have zero fee (examples: status codes, administrative notes)
3. Code-specific payment expectations based on insurance contracts vs. fee schedules

### Appointment-Procedure Linkage Rules
1. Completed procedures should be linked to an appointment (exception: emergency/walk-in visits)
2. Multiple procedures can be linked to a single appointment
3. Procedure.ProcDate should typically match Appointment.AptDateTime date
