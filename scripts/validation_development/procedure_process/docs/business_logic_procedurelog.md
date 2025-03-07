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

### ProcStatus Codes and Distribution (2024 Dataset)
The `ProcStatus` field uses the following values:

1. **Treatment Planned (Status 1)** - 20.38%
   - Represents planned/scheduled procedures
   - No completion dates (0% have DateComplete)
   - Moderate appointment linkage (25.18%)
   - Very low treatment plan date presence (2.30%)
   - Significant increase from historical 6.55%

2. **Completed (Status 2)** - 51.67%
   - Represents completed procedures
   - 100% have completion dates
   - High appointment linkage (90.67%)
   - Strong data consistency
   - Decrease from historical 75.44%

3. **Administrative/Documentation (Status 3)** - 6.00%
   - Almost exclusively zero-fee procedures (99.96%)
   - No appointment links
   - No completion dates
   - Used for "Group Note" entries
   - Increase from historical 4.31%

4. **Existing Prior (Status 4)** - 0.48%
   - Average fee: $246.30
   - No appointment links
   - No completion dates
   - Historical conditions/procedures
   - Decrease from historical 5.05%

5. **Referred (Status 5)** - 1.71%
   - External provider referrals
   - Very low completion date rate (0.94%)
   - No appointment links
   - Increase from historical 0.33%

6. **Ordered/Planned (Status 6)** - 15.83%
   - Average fee: $204.05
   - No appointment links
   - Very low completion dates (0.74%)
   - Very low treatment plan dates (0.46%)
   - Used for preventive care and diagnostics
   - Increase from historical 7.23%

7. **Condition (Status 7)** - 3.88%
   - Purpose requires further investigation
   - No appointment links
   - No completion dates
   - Increase from historical 1.03%
   - Note: Previously thought to represent declined treatment plans, but 3.88% is too low given expected treatment plan acceptance rate of ~70%
   - Further analysis needed to determine actual business purpose

8. **Unknown (Status 8)** - 0.05%
   - Very rarely used
   - No appointment links
   - No completion dates
   - Consistent with historical usage

### Key Status Patterns and Relationships

1. **Completion Date Patterns**
   - Status 2 (Completed): 100% have completion dates
   - Status 5 and 6: <1% have completion dates
   - All other statuses: 0% completion dates

2. **Appointment Linkage Patterns**
   - Status 2: 90.67% have appointments
   - Status 1: 25.18% have appointments
   - All other statuses: No appointment links

3. **Treatment Plan Integration**
   - Generally low across all statuses
   - Status 1: Only 2.30% have treatment plan dates
   - Status 6: Only 0.46% have treatment plan dates

4. **Fee Distribution Patterns**
   - Status 3: 99.96% zero-fee procedures
   - Status 4: Average fee $246.30
   - Status 6: Average fee $204.05

### Notable Changes in Status Distribution

1. **Planning Status Increase**
   - Treatment Planned (1): ↑ from 6.55% to 20.38%
   - Ordered/Planned (6): ↑ from 7.23% to 15.83%
   - Combined planning statuses increased from 13.78% to 36.21%

2. **Completion Status Decrease**
   - Completed (2): ↓ from 75.44% to 51.67%
   - Suggests shift toward more planning-oriented workflow

3. **Administrative Status Changes**
   - Administrative (3): ↑ from 4.31% to 6.00%
   - Status 7: ↑ from 1.03% to 3.88% (purpose needs investigation)
   - Indicates increased documentation but Status 7's role unclear

4. **Historical Status Reduction**
   - Existing Prior (4): ↓ from 5.05% to 0.48%
   - Suggests cleanup of historical conditions

### Areas Requiring Further Investigation

1. **Status 7 Purpose**
   - Current hypothesis of representing declined treatment plans is unlikely
   - 3.88% prevalence is too low for declined plans given expected ~70% acceptance rate
   - Need to analyze:
     - Procedure types commonly marked as Status 7
     - Relationship with treatment planning workflow
     - Temporal patterns (when/how Status 7 is assigned)
     - Associated procedure codes and fees
     - Relationship with other planning statuses (1 and 6)

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
- **Revenue Gap**: $633,938.32 in unrealized revenue for completed procedures

### Payment Source Distribution
- **No Payment Links**: 27.87% of procedures have no payment links whatsoever
- **Insurance Only/Unpaid**: 24.41% of procedures have insurance records but no actual payments
- **Mixed Sources/Fully Paid**: 22.44% of procedures have both insurance and direct payments and are fully paid
- **Insurance Only/Fully Paid**: 11.12% of procedures are paid entirely through insurance
- **Direct Payment Only/Fully Paid**: 6.20% of procedures are paid entirely through direct payments
- **Partial Payment Categories**: The remaining 8.0% are distributed across various partial payment states

### Payment Link Patterns
- **Completion Rate Correlation**: Procedures with any payment source have extremely high completion rates (99-100%)
- **No-Payment Completion Gap**: Procedures without payment links show only 11.54% completion rate
- **Insurance Link Efficiency**: Insurance-only fully paid procedures show a slight overpayment pattern (100.37%)
- **Mixed Source Overpayment**: Mixed payment sources show 123.6% payment rate, indicating systematic overpayment
- **Zero Insurance Pattern**: 2,602 fully paid procedures with mixed sources have zero insurance payments despite having insurance records

### Payment Split Processing Anomaly
- **System Anomaly Period**: Beginning July 2024, the system exhibits anomalous payment split generation
- **Split Pattern Evolution**:
  - Normal period (Jan-Jun 2024): 2-10 splits per payment (baseline)
  - Initial anomalies (Jul 2024): Occasional spikes to 40 splits per payment
  - Escalation period (Aug-Oct 2024): Regular spikes of 100-400 splits per payment
  - Peak anomaly (Nov 2024): Over 450 splits per payment on average
- **Affected Transaction Types**: Primarily Type 0 transfers (98.3%) with $0 payment amounts
- **Split Payment Impact**: Mixed payment sources show significantly elevated payment ratios (123.6%), likely influenced by this anomaly
- **Business Impact**: This anomaly affects payment split data interpretation but does not cause direct financial errors

### Payment Timing Patterns
- **Direct Payments**: Average 1,021 days for fully paid procedures, suggesting historical data processing
- **Mixed Sources**: Average 569 days for fully paid procedures with both payment types
- **Partial Payments**: Much longer average timing (2,916 days for direct partial, 3,283 days for mixed partial)
- **Payment Urgency Correlation**: Procedures with higher fees typically receive expedited payment processing

### Payment Distribution Patterns
- **Binary Payment Pattern**: Procedures strongly polarize between fully paid (69.49%) and completely unpaid (14.30%)
- **Limited Partial Payments**: Only 14.56% of procedures fall in partial payment categories (1-95%)
- **Transitional Band Scarcity**: Very few procedures (1.64%) fall in the 95-98% category
- **Full Payment Dominance**: The 98-100%+ category accounts for 82.6% of all collected revenue

### Payment Ratio Benchmarks
- **98-100%+**: 69.49% of procedures (target zone for routine payments)
- **95-98%**: 1.64% of procedures (minimal transition zone)
- **90-95%**: 1.36% of procedures
- **75-90%**: 4.37% of procedures
- **50-75%**: 3.85% of procedures
- **1-50%**: 4.98% of procedures
- **No Payment**: 14.30% of procedures

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

### Adjustment Recording Changes
- **Adjustment System Modification**: According to stakeholder information, extensive changes were made to adjustment recording methodologies during 2024
- **Timing Impact**: These changes potentially affect how payments and adjustments are calculated and reported in the latter part of 2024
- **Interpretation Caution**: Payment and adjustment patterns observed in the later months of 2024 may reflect these system changes rather than business process changes
- **Comparative Analysis Limitation**: Direct comparisons between early 2024 and late 2024 adjustment/payment patterns should account for these methodological changes

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

- **Completed but unpaid** (5.96% of procedures): 2,234 procedures are marked as completed but have zero payment, representing $598,497.50 in uncollected revenue
- **Significant overpayment** (3.11% of procedures): 1,166 procedures received payments exceeding 105% of their fee, with an average payment of 154.72% of the fee amount
- **Completed but underpaid** (2.11% of procedures): 790 procedures received less than 50% of their fee, with an average collection rate of only 28.47%, representing $169,318.01 in potential lost revenue
- **Minor overpayment** (0.46% of procedures): 173 procedures received between 100-105% of their fee, possibly representing acceptable administrative adjustments
- **Non-completed with payment** (0.03% of procedures): 10 non-completed procedures received payments, with an extremely high average fee ($5,631.64) suggesting deposits for expensive procedures
- **Zero-fee payment** (0.02% of procedures): 7 procedures with $0 fee received payments totaling $606, indicating potential fee coding errors

### Edge Case Distribution Patterns
- Critical payment issues affect 11.69% of all procedures
- Revenue collection issues (unpaid and underpaid) represent a total of $767,815.51 in potential lost revenue
- Overpayment concerns (significant and minor) affect 1,339 procedures and represent approximately $210,278 in excess payments
- The presence of high-value non-completed procedures with payments suggests a deposit system for expensive treatments

### Business Impact
- The combination of underpayment and overpayment issues suggests inconsistent payment processing rather than a uniform policy
- The strong completion-payment correlation (99.8-100% of procedures with any payment are completed) confirms the critical relationship between payment and procedure lifecycle management
- The clustering of unpaid procedures around specific price points indicates targeted collection strategies may be needed at these thresholds

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

## Temporal Patterns and Lifecycle Management

### Monthly Procedure Lifecycle Patterns
Analysis of monthly procedure data reveals consistent patterns in how procedures move through their lifecycle:

1. **Status Distribution Consistency**:
   - Completed procedures maintain a consistent ~50% of monthly volume
   - Planned procedures maintain ~16-22% of monthly volume
   - Deleted procedures consistently represent 15-17% of all procedures monthly

2. **Completion Timing**:
   - Procedures typically move to completed status within the same month as creation
   - Certain procedure types show longer planned-to-completed transitions, particularly higher value services

3. **Deletion Patterns**:
   - The consistent 15-17% deletion rate across all months indicates a standardized workflow rather than episodic cleanup
   - This suggests planned procedures have a predictable abandonment rate that should be factored into capacity planning

### Seasonal Business Patterns

1. **Volume Fluctuations**:
   - January and October show higher procedure volume (3,738 and 3,607 respectively)
   - February and December show lower procedure volume (2,995 and 2,628 respectively)
   - These patterns likely reflect seasonal patient behavior and practice scheduling

2. **Payment Processing Efficiency**:
   - June shows the highest success rate (70.52%) and payment efficiency
   - September shows lower success rates (57.82%) despite normal volume
   - December shows substantially degraded performance (34.01% success rate)

3. **Revenue Cycle Indicators**:
   - Q2 (Apr-Jun) shows strongest payment performance (82-85% payment rates)
   - Month-end processing likely affects early-month performance
   - Year-end processing shows significant impact on December metrics

### Financial Workflow Patterns

1. **Procedure-Payment Latency**:
   - Most completed procedures receive payment within the same month
   - ~10% of procedures show payment delays extending 1-6+ months
   - The payment lag increases with procedure complexity and fee amount

2. **Payment Processing Timeline**:
   - Insurance payments typically post within 30 days of procedure completion
   - Patient responsibility portions show longer collection timelines
   - The year-end processing backlog significantly affects December procedures

3. **Fiscal Year Impacts**:
   - Year-end impacts both procedure scheduling (lower December volume)
   - End-of-year insurance benefit depletion likely contributes to lower completion rates in Q4
   - Revenue recognition timing creates artificial payment performance degradation in December

### Time Boundary Considerations
   - Analysis is limited to procedures and payments recorded in 2024
   - Payment activity occurring in 2025 for late-2024 procedures is not captured
   - This creates a "right-censoring" effect where recent procedures appear to have lower payment rates
   - Q4 2024 metrics (especially December) require cautious interpretation due to incomplete payment cycles
   - Year-over-year comparisons should account for this time boundary effect when evaluating performance trends
   - Procedures from earlier months (Jan-Sep 2024) provide more reliable performance indicators due to more complete payment cycles

### Pre-Payment Patterns

1. **Deposit Handling**:
   - Only 0.14% of treatment planned procedures show any payments
   - These represent pre-payments or deposits for planned services
   - Deposits are more common for higher-value planned procedures

2. **Plan-to-Complete Conversion**:
   - Higher success and payment rates in mid-year (Q2) correspond to higher plan-to-complete conversion
   - Financial pre-approval appears most effective for >$2,000 procedures (higher completion than planning rate)
   - The conversion rate declines in September and December, suggesting insurance benefit cycle effects

### Unpaid Procedure Patterns

1. **Fee Structure Impact on Payment Probability**:
   - Procedures with fees below $300 have higher payment completion rates
   - High-value procedures ($1,000+) show elevated unpaid rates (12.83% of high-value procedures remain unpaid)
   - This suggests tiered collection strategies based on procedure value

2. **Procedure Type Payment Patterns**:
   - Elective cosmetic procedures show higher unpaid rates (8.72% vs. practice average of 5.96%)
   - Preventive procedures show the lowest unpaid rates (3.15%)
   - Emergency procedures fall between these extremes (5.67%)
   
3. **Monthly Unpaid Distribution**:
   - Each month consistently generates 100-150 unpaid procedures (baseline rate)
   - April and June show more efficient payment collection (lowest unpaid counts outside December)
   - September-October show elevated unpaid counts despite normal procedure volume
   - This pattern indicates a cyclical workflow where certain procedures consistently remain unpaid

4. **Price Sensitivity Thresholds**:
   - Unpaid procedures cluster around specific price points ($500-600, $1200-1500, $2800-3000)
   - These clusters likely represent specific procedure types with payment collection challenges
   - The presence of these thresholds suggests the need for targeted financial workflows for procedures at these price points

### Appointment-Procedure Relationship Patterns

1. **Appointment Status Distribution**:
   - Nearly half (48.03%) of all procedures have "Unknown" appointment status
   - 46.86% are linked to completed appointments
   - Only 5.11% are distributed across other appointment statuses (UnschedList: 3.35%, Broken: 1.75%, Scheduled: 0.01%)

2. **Status-Specific Financial Patterns**:
   - Procedures with "Complete" appointment status show strong financial performance (80.96% payment rate)
   - Procedures with "Unknown" appointment status show extremely poor payment performance (2.92% payment rate)
   - Higher-value procedures ($400.15 avg) are disproportionately represented in the Unknown category
   - The strong correlation between appointment completion status and payment suggests appointment tracking directly impacts revenue cycle

3. **Appointment Association Impact**:
   - Procedures linked to completed appointments show near-perfect procedure completion rates (99.99%)
   - Procedures with unknown appointment status show very low completion rates (10.03%)
   - This suggests appointment status is a strong predictor of procedure completion and payment outcomes

   
   

DateComplete Missing for Non-Completed Procedures

If a procedure is not truly finished or has a status like “Planned” or “Referred Out,” you’d expect no DateComplete.
High missingness can be legitimate rather than a data error.
AptDateTime Missing for Non-Scheduled Work

Procedures that didn’t require or never had an appointment (e.g., certain administrative codes, external referrals) wouldn’t have an AptDateTime.
TreatPlanDate Underused or Documented Elsewhere

Many clinics don’t fill out the TreatPlanDate field if they track treatment planning in a different module or skip it altogether.
The near 99% missing rate suggests a systemic workflow gap rather than random data entry errors.
PerioExamDate Only Applies to Certain Procedures

About 44% are missing. It may be that only certain categories (e.g., periodontal codes) require a perio exam.
If a clinic doesn’t do full perio charting for every patient, the PerioExamDate will remain blank.
