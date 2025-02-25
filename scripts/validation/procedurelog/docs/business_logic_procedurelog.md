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

## Fee Structure and Management

### Fee Distribution Patterns
Analysis of procedure fees reveals distinct distribution patterns:
- **Zero Fee Procedures**: 24.80% of all procedures have no fee
  - Most (74.85%) are excluded administrative/diagnostic codes as expected
  - The remainder represent courtesy services or write-offs
- **Standard Service Range**: 34.09% of procedures are under $100, representing routine/preventive services
- **Mid-tier Services**: 32.57% fall in the $100-$499 range
- **High-value Procedures**: Only 8.52% of procedures exceed $500, with just 0.27% above $2,000

### Fee Schedule Adherence
- **High Adherence Rate**: Nearly all procedures under $2,000 match the standard fee schedule (98-99%)
- **Custom Pricing**: Higher-value procedures ($2000+) only match the fee schedule 60.78% of the time
- This indicates the practice follows standardized pricing for routine procedures but customizes fees for major services

### Fee Relationship Categories
Fee relationship analysis shows strong discipline in fee schedule management:
- **Matches Standard**: 74.37% of procedures (27,857) exactly match standard fee schedule rates
- **Fee Missing**: 14.19% of procedures (5,317) have no corresponding fee schedule entry
- **Zero Fee Override**: 5.53% of procedures (2,071) have a standard fee but are set to zero fee
- **Zero Standard Fee**: 5.25% of procedures (1,967) have zero fees in both actual and standard
- **Custom Pricing**: Less than 1% of procedures have custom pricing:
  - Below Standard: 0.49% (183 procedures)
  - Above Standard: 0.17% (64 procedures) with much higher average fees ($3,545.53)

### Fee-Status Relationship
- **Financial Barriers**: Mid to high-value procedures ($500-$1999) show more planned than completed procedures
- **Zero Fee Completion**: Zero-fee procedures have nearly 3x as many completed as planned (2,944 vs 1,059)
- **High-Value Completion**: $2000+ procedures show more completions than planned (41 vs 29), suggesting effective financial pre-authorization

### Fee Impact on Procedure Lifecycle
- **Completion Rate vs. Fee**: Completion rates inversely correlate with procedure cost
- **Treatment Planning**: Higher-cost procedures remain in planned status longer
- **Insurance Coverage Impact**: Procedures with higher coverage rates show faster transition to completed status

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

### Patient Responsibility Patterns
- **Progressive Coverage Decline**: As fee amounts increase, full coverage percentage decreases:
  - Under $100: 53.21% fully covered
  - $100-$249: 48.52% fully covered
  - $500+: Only ~22-25% fully covered
- This aligns with insurance designs that provide better coverage for preventive/diagnostic services

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

### Status Transition Findings
Analysis revealed significant deviations from the documented business rules:

1. **DateComplete field misuse**: 
   - The DateComplete field is populated for 100% of Treatment Planned procedures, contradicting rule #3 above
   - This suggests a data entry practice different from documented rules

2. **Extended transition periods**:
   - Completed procedures remain in status for 57-420 days (avg: 242.5 days)
   - Other statuses show extreme values (up to 739,306 days - over 2,000 years)
   - This indicates likely date handling issues or improper default dates

3. **Status permanence issue**:
   - The extreme "days in status" values suggest procedures may not progress through expected status transitions
   - Terminal statuses (3, 4, 5, 7) appear to be correctly used as permanent states

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

### Appointment Linkage Findings
Analysis revealed unexpected appointment linkage patterns:

1. **Universal appointment linkage**:
   - 100% of procedures in ALL statuses (including Deleted, Condition, etc.) are linked to appointments
   - This contradicts the expectation that only active procedures would have appointment links

2. **Appointment linkage validation**:
   - Although all procedures have appointment links, further validation is needed to verify the appropriateness of these links
   - Further investigation should determine if procedures are correctly linked to relevant appointments

### Fee Setting Rules
1. **Fee Schedule Adherence**: Most procedures (98-99%) should match standard fee schedule
2. **Custom Fee Criteria**:
   - Major procedures (over $2,000) may use custom pricing
   - Adjustments should be documented through the adjustment table, not by altering the base fee
   - Zero fee procedures should generally be limited to excluded codes

3. **Zero Fee Guidelines**:
   - Administrative codes should have zero fees
   - Diagnostic codes may have nominal or zero fees based on insurance contracts
   - Courtesy services should be recorded with standard fees and corresponding adjustments

4. **Fee Schedule Management Patterns**:
   - The practice maintains a highly standardized fee structure with 74.37% exact matches
   - Fee schedule gaps (14.19%) primarily affect low-value or administrative procedures
   - Intentional zero fee overrides (5.53%) are used selectively for specific procedures
   - Custom pricing is restricted to less than 1% of procedures, primarily for high-value services
