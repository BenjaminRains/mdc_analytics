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
- **appointment**: Appointments associated with procedures
- **claimproc**: Insurance claim processing for procedures
- **paysplit**: Direct patient payments for procedures
- **adjustment**: Adjustments applied to procedure fees

## Payment Processing

Payments for procedures can come from multiple sources:
1. **Insurance Payments**: Recorded in `claimproc.InsPayAmt` (primary payment source)
2. **Direct Patient Payments**: Recorded in `paysplit.SplitAmt` (secondary payment source)
3. **Adjustments**: Recorded in `adjustment.AdjAmt` (write-offs, discounts)

### Payment Metrics
- **Payment Ratio**: `Total Paid / ProcFee` (percentage of the fee that has been paid)
- **Overall Payment Rate**: 37.90% of all procedures have received payments
- **Collection Rate for Completed**: 80.29% of fees for completed procedures are collected
- **Average Payment Ratio**: 84.33% for completed procedures with fees
- **Revenue Gap**: $669,113.62 in unrealized revenue for completed procedures

### Payment by Status
- **Completed (Status 2)**: 73.29% have received payments
- **Treatment Planned (Status 1)**: 0.14% have received payments (typically pre-payments/deposits)
- **Other Statuses**: No payment activity observed for statuses 3-8

## Success Criteria

A procedure is considered to have a successful payment journey when:
1. It has a `ProcStatus` of 2 (Completed) AND
2. Either:
   - It has a `ProcFee` of 0 and is not an excluded code, OR
   - It has a `ProcFee` > 0 and has a payment ratio ≥ 95%

### Success Rate Analysis
- **Overall success rate**: 62.84% of completed procedures meet success criteria
- **Completed procedures breakdown**:
  - With zero fees: 15.2% (2,944 procedures)
  - No payment received: 11.5% (2,234 procedures)
  - With 95%+ payment: 61.0% (11,805 procedures)

### Excluded Codes
Certain procedure codes are excluded from payment validation, including administrative codes (e.g., D9986, D9987), diagnostic codes (e.g., D0120, D0140), and special codes (e.g., ~GRP~, Watch).
- **Excluded procedures**: 30.7% (11,497) of all procedures use excluded codes
- **Code exclusion impact**: Significantly affects payment validation strategy

## Edge Cases
Analysis identified several edge cases requiring special attention:

- **Completed but unpaid** (5.96% of procedures): Representing unbilled/uncollected revenue
- **Significant overpayment** (3.11% of procedures): Payments exceed 105% of fee
- **Completed but underpaid** (2.11% of procedures): Received less than 50% of fee
- **Non-completed with payment** (0.03% of procedures): Non-completed procedures that received payments
- **Zero-fee payment** (0.02% of procedures): Zero-fee procedures that received payments

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
   - Diagnostic procedures: Often $0 fee or write-offs expected
   - Preventive procedures: 95% collection expected
   - Restorative procedures: 95-98% collection expected
   - Major procedures (over $500): 98% collection expected

2. Multi-procedure bundling:
   - When multiple procedures are performed in a single visit, payment is often applied to the primary procedure
   - Bundled procedures may have disproportionate payment distribution (some 0%, some >100%)

### Procedure Code Validation Rules
1. Certain codes must always have a fee (examples: crowns, fillings, extractions)
2. Certain codes should always have zero fee (examples: status codes, administrative notes)

### Appointment-Procedure Linkage Rules
1. Completed procedures should be linked to an appointment (exception: emergency/walk-in visits)
2. Procedure.ProcDate should typically match Appointment.AptDateTime date
