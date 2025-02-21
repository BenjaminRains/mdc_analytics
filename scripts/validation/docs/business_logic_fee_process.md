# Treatment Journey Business Logic

## Overview
This document outlines the business logic for tracking procedures from treatment planning through payment completion in OpenDental. It serves as the foundation for the treatment journey ML analysis.

## Core Components

### 1. Procedure Fees
- **Base Fee (`procedurelog.ProcFee`)**
  - Two primary standard tiers identified:
    - $1,950 tier (197 procedures, 72 distinct dates)
    - $1,288 tier (661 procedures, 214 distinct dates)
  - Other procedures (16,368 procedures) average $135.37
  - Large fee procedures (18 cases) average $8,067.06

- **Fee Schedule System (`fee`)**
  - Multiple fee schedules can exist for same procedure
  - Each fee entry has unique `FeeNum`
  - Links:
    - `procedurelog.CodeNum` → `fee.CodeNum`
    - `fee.OldCode` tracks CDT codes

### 2. Insurance Claims
- **Claim Status Distribution (`claimproc.Status`)**
  - Status = 1 (34.39%): Active claims
    - Can be in various payment states:
      - No payments (InsPayEst = 0, InsPayAmt = 0)
      - Pending payments (InsPayEst > 0, InsPayAmt = 0)
      - Partial payments (InsPayAmt < InsPayEst)
      - Complete payments (InsPayAmt ≥ InsPayEst)
  - Status = 3 (57.84%): Adjustment entries
    - Always has FeeBilled = 0
    - Always has InsPayEst = 0
    - Can have non-zero InsPayAmt (including negative)
  - Status = 0 (0.63%): New claims
  - Status = 2 (0.77%): Pre-authorizations
  - Status = 4 (2.88%): Payment adjustments
  - Status = 6 (2.25%): Voided estimates
  - Status = 7 (1.24%): Legacy/unused

### 3. Payments and Adjustments
- **Insurance Payments**
  - Must be dated before the as_of_date for AR calculations
  - Payments after as_of_date should not affect historical AR
  - Future-dated payments should be excluded from AR totals

- **Adjustments (`adjustment`)**
  - Common Issues Identified:
    - Decimal point errors (e.g., -$27,680 should be -$276.80)
    - Large negative adjustments (69 cases, total $137,192)
    - Times larger than fee: ranging from 1.02x to 83.88x
  
  - **Adjustment Types**:
    - Type 473: Warranty adjustments
    - Type 474: Provider discretionary
    - Type 481: Balance adjustments
    - Type 488: Standard discounts
    - Types 186/188: Insurance-related

### 4. Payment Processing
- **AR Aging Calculation**
  - Based on fixed reference date (as_of_date)
  - Aging buckets:
    - Current: ≤30 days (39.3% of AR)
    - 30-60 days (11.7% of AR)
    - 60-90 days (12.7% of AR)
    - 90+ days (36.2% of AR)
  - Balance calculation must consider:
    - Only payments before as_of_date
    - Only adjustments before as_of_date
    - Exclude future-dated transactions

## Validation Rules
1. **Fee Validation**
   - Flag fees outside standard tiers
   - Monitor frequency of large fee procedures
   - Check for decimal point errors in adjustments

2. **Payment Validation**
   - Maximum 15 splits per payment
   - Split difference tolerance: 0.01
   - Payment-to-fee ratio: 0.95-1.05
   - Review all zero-fee procedures with payments

3. **Duplicate Detection**
   - Check same-day procedures with identical fees
   - Monitor sequential ProcNum patterns
   - Track batch entry vs. manual entry patterns

## Risk Management
1. **High-Risk Patterns**
   - Multiple procedures same day/fee
   - Adjustments > 10x procedure fee
   - Payments with >15 splits
   - Zero-fee procedures with payments

2. **Monitoring Metrics**
   - Track adjustment size distribution
   - Monitor split pattern changes
   - Review duplicate entry patterns
   - Track payment-to-fee ratios

## Notes
- Focus on standard fee tier compliance
- Monitor adjustment decimal accuracy
- Review batch entry procedures
- Validate complex payment splits

# Business Logic: Fee to Payment Process

## Overview
This document outlines the business logic for the fee assignment, adjustment, and payment processes in OpenDental. It aims to clarify how fees are set, adjusted, and paid, and to develop a strategy for further understanding through database queries.

## Fee Assignment
- **Procedure Codes**: Each procedure has a CDT code (e.g., D9230) linked to a default fee.
- **Fee Sources**:
  - `procedurelog.ProcFee`: Stores the clinic fee for each procedure.
  - `procedurecode`: Contains descriptions and default fees.
  - `fee`: Maps CDT codes to fee amounts.
- **Hypothesis**: `procedurelog.ProcFee` is populated from `fee.Amount` based on `procedurecode.CodeNum`.

## Adjustments
- **Adjustment Records (`adjustment` table)**
  - `adjustment.AdjAmt`: Stores all fee modifications including:
    - Discounts
    - Write-offs
    - Other fee adjustments
  - `adjustment.AdjType`: Links to `definition.DefNum` for categorization
    - Each adjustment type has a specific meaning defined in the definition table
    - Helps track the reason for each adjustment

## Payments
- **Payment Sources**:
  - Payments can be from insurance or patients.
  - `payment`, `paysplit`, `claimpayment` tables manage payment records.
- **Insurance Payments**:
  - `claimproc` and `claim` tables handle insurance-related fees.
- **Hypothesis**: Insurance amounts ("Allowed", "Pri Ins", "Sec Ins") are separate from clinic fees.

## Strategy for Database Queries
1. **Fee Assignment Queries**:
   - Query `procedurelog` and `fee` to verify fee population logic.
   - Check `procedurecode` for default fee settings.

2. **Adjustment Queries**:
   - Analyze `adjustment` table to understand discount application.
   - Query `definition` to categorize `AdjType`.

3. **Payment Queries**:
   - Investigate `claimproc` and `claim` for insurance payment details.
   - Query `payment` and `paysplit` for patient payment records.

## Next Steps
1. **Query Development**:
   - Develop SQL queries to test hypotheses about fee assignment and adjustments.
   - Validate insurance payment logic through targeted queries.

2. **Documentation**:
   - Update this document with findings from database queries.
   - Create flow diagrams to visualize fee and payment processes.

3. **Collaboration**:
   - Share insights with the team to refine understanding.
   - Collaborate on further investigation and testing.

## Notes
- Focus on understanding the relationship between procedure codes and fees.
- Clarify how adjustments impact the final fee.
- Ensure insurance payments are accurately reflected in the system.

---

This document serves as a readme for the business logic of the fee to payment process. It includes fee-related tables and their business logic. Fee fields are found in the following tables: `procedurelog`, `fee`, `feesched`, `adjustment`, `claimproc`, `claim`.

- **Procedurelog.ProcFee**: The clinic fee for the procedure before insurance, adjustments, discounts. (Strong Hypothesis)

### Investigations
- `pl.ProcFee` =? `f.Amount` from FeeSchedule table. **Investigate**
- `f.OldCode` and `f.CodeNum` could be related to `pc.CodeNum` and `pl.CodeNum`.
- `pl.OldCode` and `f.OldCode` could be related.
- `pl.ProcFee` is associated with `f.FeeNum`. **Investigate**
- `feesched` is mostly out of network insurance. **Investigate**
- `feesched.FeeSchedType` **Investigate distribution**

### Adjustment Table
- `adjustment.AdjType` links to `definition.DefNum` and `definition.ItemName` and `definition.ItemValue`. (Note: `df.ItemValue` is not numeric; it's a string.)

### Claimproc Table Fee Related Fields
- Note: Claim fees are all insurance-related and aren't set by the clinic.
- Except for `claimproc.FeeBilled`. This needs investigation.
- NOTE: A full claim table investigation and distribution needs to be done.
- feesched is mostly out of network insurance. 
- feesched.FeeSchedType **Investigate distribution**
- claimproc.FeeBilled, claimproc.InsPayEst, claimproc.DedApplied, claimproc.InsPayAmt, claimproc.WriteOff, 
- claimproc.AllowedOverride, claimproc.BaseEst, claimproc.DedEst, claimproc.InsEstTotal

### Claim Table Fee Related Fields
- `claim.ClaimFee`, `claim.InsPayEst`, `claim.InsPayAmt`, `claim.DedApplied`
- NOTE: `claim.ClaimType` contains values 'P', 'S'. P could be a partial claim, or it could be a primary claim. Needs investigation.
- NOTE: `claim.ClaimStatus` contains values 'W', 'H', 'S', and others. Investigate the meaning of each.
- claim.ClaimFee, claim.InsPayEst, claim.InsPayAmt, claim.DedApplied
- NOTE: claim.ClaimType contains values 'P', 'S'. P could be a partial claim, or it could be a primary claim. Needs investigation. 
- NOTE: claim.ClaimStatus contains values 'W', 'H', 'S', and others. Investigate the meaning of each. 

payments are separate from fees. Payments can come from insurance and patients. 
payment related tables: payment, paysplit, claimpayment, 

claimpayment table:
-- claimpayment.CheckAmt
NOTE: claimpayment.IsPartial is a boolean
NOTE: claimpayment.PayType could link to definition.DefNum. Investigate. 

payment table:
-- payment.PayAmt
NOTE: payment.IsSplit link to paysplit
NOTE: payment.PayNum links to paysplit
NOTE: payment.PayType links to definition.DefNum. Investigate. 
NOTE: payment.PatNum links to patient.PatNum
NOTE: payment.PayNote contains insurance and patient payment information.

paysplit table:
-- paysplit.SplitAmt
NOTE: paysplit.PatNum links to patient.PatNum
NOTE: paysplit.UnearnedType needs investigation. check definition.DefNum
NOTE: paysplit.ProcNum links to procedurelog.ProcNum. Some values are 0 because they aren't linked to a procedure. 

#### Paysplit Table
- `paysplit.SplitAmt`
- Note: `paysplit.PatNum` links to `patient.PatNum`.
- Note: `paysplit.UnearnedType` needs investigation. Check `definition.DefNum`.
- Note: `paysplit.ProcNum` links to `procedurelog.ProcNum`. Some values are 0 because they aren't linked to a procedure.


### Query 3 Insurance Fee Documentation: fee_and_payment_process_validation.sql
This query is designed to provide a comprehensive view of how insurance fees are documented and linked across various tables in the OpenDental database. It combines information from the `claimproc`, `claim`, `insplan`, `feesched`, `insbluebook`, and `insbluebooklog` tables to offer insights into the insurance fee documentation process.

#### Key Components

- **Claim Processing Details**:
  - `cp.ClaimNum`, `cp.FeeBilled`, `cp.InsPayEst`, `cp.InsPayAmt`, `cp.WriteOff`: These columns provide basic details about the claim processing, including the claim number, billed fee, estimated insurance payment, actual insurance payment, and any write-offs.

- **Claim Details**:
  - `c.DateService`, `c.PlanNum`, `c.PatNum`: These columns include the date of service, plan number, and patient number associated with each claim.

- **Fee Schedule Details**:
  - `fs.Description AS fee_schedule_description`, `fs.FeeSchedType`: These columns provide information about the fee schedule associated with each insurance plan, including a description and the type of fee schedule. Note that the insurance fee schedules are not they way the clinic bills the patient. The clinic is mostly out of network. 

- **Insurance Plan Details**:
  - `ip.GroupName AS insurance_group_name`, `ip.PlanType AS insurance_plan_type`: These columns offer insights into the insurance plan, including the group name and plan type.

- **Insurance Bluebook Details**:
  - `ibb.InsPayAmt AS bluebook_ins_pay_amt`, `ibb.AllowedOverride AS bluebook_allowed_override`: These columns from the `insbluebook` table record what the insurance carrier says they will pay for specific procedures, plans, and carriers.

- **Insurance Bluebook Log Details**:
  - `ibbl.AllowedFee AS bluebook_log_allowed_fee`, `ibbl.Description AS bluebook_log_description`: These columns from the `insbluebooklog` table provide log details, including the allowed fee and a description.

#### Joins and Filters

- **Joins**:
  - The query joins `claimproc` with `claim` to get claim details.
  - It joins `claim` with `insplan` to get insurance plan details.
  - It joins `insplan` with `feesched` to get fee schedule details.
  - It uses `LEFT JOIN` with `insbluebook` to include insurance payment records.
  - It uses `LEFT JOIN` with `insbluebooklog` to include log details.

- **Filters**:
  - The query filters for claims with a `Status` of 1 or 2, indicating specific claim statuses.
  - It limits the results to claims with a `DateService` within the last 4 years to focus on recent data.

- **Limit**:
  - The query is limited to return a maximum of 1,000,000 records to ensure efficient processing.

This query helps validate and analyze the insurance fee documentation process, providing a detailed view of how fees are set and recorded in relation to insurance plans and fee schedules.




From fee_and_payment_process_validation.sql
query 4
Purpose: This query is designed to investigate insurance payment details by joining the claimproc, claim, and claimpayment tables.
Columns Selected:
cp.ClaimNum: The claim number.
cp.FeeBilled: The fee billed for the claim.
cp.InsPayEst: The estimated insurance payment.
cp.InsPayAmt: The actual insurance payment amount.
cp.WriteOff: The amount written off.
c.DateService: The date of service.
c.PlanNum: The plan number.
c.PatNum: The patient number.
clp.CheckAmt: The check amount from the claim payment.
clp.ClaimPaymentNum: The claim payment number.
Joins:
Joins claimproc with claim on ClaimNum.
Joins claimproc with claimpayment on ClaimPaymentNum.
Filters:
Filters for cp.Status values of 1 or 2.
Limits the results to claims with a DateService within the last 4 years.

## Insurance Claims Status (claimproc.Status)
Based on analysis of the claimproc table, we've identified key status values:

### Status = 1 (34.39% of claims)
- Represents active/valid claims
- Associated with completed procedures (ProcStatus = 2)
- Can have:
  - No payments (InsPayEst = 0, InsPayAmt = 0)
  - Pending payments (InsPayEst > 0, InsPayAmt = 0)
  - Completed payments (InsPayEst > 0, InsPayAmt > 0)
- DateInsFinalized can be pending ('0001-01-01') or have actual dates

### Status = 3 (57.84% of claims)
- Most common status
- Not linked to active procedures (no matches in procedurelog)
- Characteristics:
  - Always has FeeBilled = 0
  - Always has InsPayEst = 0
  - Can have non-zero InsPayAmt (including negative values)
  - Never has DateInsFinalized (always '0001-01-01')
- Likely represents adjustment entries, voided claims, or payment corrections

### Status = 0 (0.63% of claims)
- Appears to represent new or pending insurance claims
- Characteristics:
  - Has FeeBilled values (non-zero)
  - May have InsPayEst values (estimated insurance payments)
  - Always has InsPayAmt = 0 (no actual payments yet)
  - DateInsFinalized is always '0001-01-01' (not finalized)
  - No WriteOffs
  - May have DedApplied (deductible amounts)
  - InsEstTotal matches InsPayEst
- Likely represents claims that have been submitted but not yet processed by insurance

### Status = 2 (0.77% of claims)
- Appears to represent pre-authorization or pre-estimate claims
- Characteristics:
  - Has significant FeeBilled values (often larger procedures)
  - Usually has InsPayEst values (estimated insurance payments)
  - Always has InsPayAmt = 0 (no actual payments)
  - DateCP is often '0001-01-01' (no payment date)
  - DateInsFinalized is always '0001-01-01' (not finalized)
  - No WriteOffs
  - No DedApplied
  - InsEstTotal matches InsPayEst
- Likely represents claims that need pre-authorization or are in pre-estimate status

### Status = 4 (2.88% of claims)
- Appears to represent payment adjustments or corrections
- Characteristics:
  - Always has FeeBilled = 0
  - Usually has InsPayEst = 0
  - Has varying InsPayAmt values (both positive and negative)
  - DateCP and DateInsFinalized usually match and are set
  - No WriteOffs
  - No DedApplied
  - InsEstTotal often differs from InsPayAmt
  - Can have negative payment amounts (indicating reversals/corrections)
- Likely represents payment adjustments, corrections, or supplemental payments after the initial claim processing

### Status = 6 (2.25% of claims)
- Appears to represent voided or cancelled estimates
- Characteristics:
  - Always has FeeBilled = 0
  - May have InsPayEst values (estimated insurance payments)
  - Always has InsPayAmt = 0 (no actual payments)
  - DateInsFinalized is always '0001-01-01' (never finalized)
  - No WriteOffs
  - No DedApplied
  - InsEstTotal matches InsPayEst when present
  - Many entries have all zero values
- Likely represents voided estimates or cancelled claims before payment processing

### Status = 7 (1.24% of claims)
- No active records found in recent data
- May be a legacy or reserved status
- Further investigation needed to understand historical usage

## Summary of Claim Status Values
1. **Status = 0 (0.63%)**: New/pending insurance claims with no payments yet
2. **Status = 1 (34.39%)**: Active claims with completed procedures
3. **Status = 2 (0.77%)**: Pre-authorization or pre-estimate claims
4. **Status = 3 (57.84%)**: Adjustment entries, voided claims, or payment corrections
5. **Status = 4 (2.88%)**: Payment adjustments and supplemental payments
6. **Status = 6 (2.25%)**: Voided or cancelled estimates
7. **Status = 7 (1.24%)**: Currently unused (possibly legacy or reserved)

### Investigation Needed
Further analysis required for remaining status values:
- Status = 7 (1.24%)

### Insurance Claims and Fee Processing

#### Fee Calculation Methods
1. **UCR (Usual, Customary, and Reasonable) Fee**
   - Typically calculated as 85% of the standard fee
   - Example: "Rule Type: UCR Fee. Allowed amount: 164.05 (85% of UCR fee)"

2. **Historical Claims Matching**
   - Several matching methods used:
     - Insurance Plan matching
     - Insurance Carrier matching
     - Insurance Group Number matching
   - Uses either Average or Most Recent amounts

#### Insurance Payment Structure
- **Billed Amount** (`FeeBilled`): Original amount charged
- **Estimated Payment** (`InsPayEst`): Expected insurance payment
- **Actual Payment** (`InsPayAmt`): Amount insurance actually paid
- **Write-off** (`WriteOff`): Amount written off by insurance

#### Fee Schedule System
- Standard fee schedule is baseline
- Insurance companies may have their own fee schedules
- Bluebook system tracks:
  - `bluebook_ins_pay_amt`: Insurance payment history
  - `bluebook_allowed_override`: Manual overrides
  - `bluebook_log_allowed_fee`: Calculated allowed amounts

#### Payment Determination Rules
1. **Insurance Plan Based**
   - Matches against specific insurance plan history
   - Example: "Allowed fees from received claims with matching Insurance Plan"

2. **Carrier Based**
   - Uses broader carrier-level fee agreements
   - Example: "Allowed fees from received claims with matching Insurance Carrier"

3. **Group Based**
   - Matches against insurance group history
   - Example: "Allowed fees from received claims with matching Insurance Group Number"

#### Key Validation Points
1. Actual payments (`InsPayAmt`) can differ from estimates (`InsPayEst`)
2. Multiple fee calculation methods may apply to same procedure
3. Historical payment patterns influence future allowances
4. Manual overrides are possible through bluebook system

## Payment Types and Unearned Revenue

### UnearnedType in PaySplit Table
- **Type 0 (88.9% of splits)**
  - Represents regular payments
  - No definition entry (NULL in ItemName) - *Need to verify if this is correct*
  - Most common type
  - Direct payment applied to procedures

- **Type 288 (10.9% of splits)**
  - Represents prepayments
  - Links to definition table with ItemName "Prepayment"
  - Used when payment is received before procedures

- **Type 439 (0.2% of splits)**
  - Represents treatment plan prepayments
  - Links to definition table with ItemName "Treat Plan Prepayment"
  - Used for treatment plan deposits

### Questions to Verify
1. Why do regular payments (Type 0) not have definition entries?
2. Are there any other UnearnedType values we should expect?
3. Should we add validation to ensure UnearnedType values are always valid?

## Payment Processing Findings

### Payment Split Patterns
1. **Split Distribution**
   - 76% of payments have 1-3 splits
     - 1 split: 32.3% (6,007 payments)
     - 2 splits: 25.9% (4,818 payments)
     - 3 splits: 18.5% (3,443 payments)
   - Complex payments can have up to 51 splits
   - Larger split counts correlate with higher payment amounts

2. **Payment Types (UnearnedType)**
   - Type 0 (Regular Payments): 99%
     - Mean amount: $595.31
     - High variability (std: $2,443.89)
     - Can have negative amounts (adjustments/refunds)
   - Type 288 (Prepayments): ~0.8%
     - Mean amount: $1,465.10
     - Used for advance payments
   - Type 439 (Treatment Plan Prepayments): ~0.2%
     - Mean amount: $6,518.78
     - Highest average amount
     - Used for large treatment plans

3. **Zero-Amount Splits**
   - Extremely rare (8 out of 49,409 splits = 0.016%)
   - All zero splits are part of valid, balanced payments
   - Occur in both regular payments and prepayments
   - Often associated with unallocated portions of payments

### Fee Distribution
1. **Procedure Fee Patterns**
   - Most fees cluster below $500
   - Highest fees:
     - Orthodontics (Code 479): $3,500
     - Implant-supported dentures (Code 720): $3,380
     - Immediate dentures (Codes 181, 182): ~$2,175
   - No negative fees found in production data

2. **Insurance Payment Accuracy**
   - 96% of payments differ from estimates
   - Very low overpayment rate (0.1% of claims)
   - Strong correlation between estimates and actual payments
   - Outliers typically represent complex procedures or multiple tooth treatments

### Data Integrity
1. **Payment Split Integrity**
   - Perfect matching between PayAmt and sum(SplitAmt)
   - No mismatches found in 18,573 payments analyzed
   - Split amounts properly distribute total payment

2. **Validation Rules**
   - Flag payments with >15 splits for review
   - Monitor zero-amount splits
   - Track UnearnedType distribution changes
   - Verify large payment amounts (>$10,000)
   - Check negative payments for proper documentation

### Business Process Implications
1. **Payment Processing**
   - Regular payments (Type 0) don't require definition entries
   - Prepayments are properly tracked with specific types
   - Split system handles complex payment scenarios effectively

2. **Fee Management**
   - Fee structure shows consistent patterns by procedure type
   - Insurance estimates are generally conservative
   - Payment tracking system maintains high data integrity

### Payment Split Analysis Findings

1. **Split Pattern Distribution**
   - Average splits per payment: 9.15
   - Normal splits (1-3): 12,653 cases
   - Complex splits (4-15): 401 cases
   - Review needed (>15): 16 cases
   - Maximum observed splits: 16 per procedure

2. **Payment Success Criteria Refinement**
   - Zero fee procedures are automatically successful
   - Normal split patterns (1-3):
     - Must be within 5% of ProcFee (0.95 to 1.05 range)
     - No split difference > 0.01
   - Complex split patterns (4-15):
     - Only valid with active insurance claims
     - Must have Status = 1
     - Total paid must be within 5% of ProcFee
   - Review needed:
     - Any procedure with >15 splits
     - Split differences > 0.01
     - Overpayment cases

3. **Risk Patterns**
   - High split counts correlate with payment issues
   - Multiple small splits on large procedures need review
   - Zero-fee procedures receiving payments require validation
   - Split differences, even small ones, indicate potential issues

4. **Payment Integrity Metrics**
   - Split difference tolerance: 0.01
   - Payment-to-fee ratio tolerance: 5%
   - Maximum recommended splits: 15
   - Minimum split amount: No specific limit, but small splits need review

### Business Process Implications

1. **Payment Processing Guidelines**
   - Normal splits (1-3) are preferred for standard procedures
   - Complex splits (4-15) should only occur with insurance involvement
   - Any procedure requiring >15 splits needs management review
   - Zero-fee procedures should not have payment splits

2. **Risk Management**
   - Monitor split pattern distributions monthly
   - Review all procedures with >15 splits
   - Investigate procedures with payment-to-fee ratios outside 0.95-1.05 range
   - Track overpayment cases for process improvement

# Payment Split Validation Update

## Revised Split Pattern Understanding

### 1. Normal Payment Patterns (99.3% of cases)
- Single claim per procedure
- 1-3 splits most common
- Direct relationship between procedure and payment

### 2. Complex Insurance Patterns (0.7% of cases)
- Multiple claims per procedure (max 2 claims)
- Legitimate business cases identified:
  - Insurance reprocessing (Type 71: 78% of cases)
  - Patient payments (Type 69: 7.3%)
  - Other types (14.7%: Types 391, 70, 412)
- Split characteristics:
  - Equal patient portions across related claims
  - Insurance amounts tracked per claim
  - Total splits match payment amount

## Updated Validation Rules

### 1. Split Pattern Validation
- Allow up to 2 claims per procedure
- Verify split amount distribution
- Track insurance payment history
- Monitor claim relationships

### 2. Payment Integrity Checks
- Split difference tolerance: 0.01
- Payment-to-fee ratio: 0.95-1.05
- Maximum splits per payment: 15
- Maximum claims per procedure: 2

### 3. Risk Management
- Flag payments with:
  - Multiple claims per procedure
  - Complex split patterns
  - Insurance reprocessing (Type 71)
  - Split differences > 0.01

## Business Process Implications

### 1. Payment Processing
- Accept multiple claims as valid
- Maintain patient-claim relationships
- Track insurance payment history
- Document complex split rationale

### 2. Reporting Considerations
- Expect 1-2 claims per procedure
- Sum splits to match payment
- Track insurance amounts separately
- Monitor split pattern changes

### 3. System Validation
- Allow legitimate duplicate joins
- Verify split amount totals
- Track claim relationships
- Monitor payment types

# Insurance Claim Validation Analysis

## Batch Submission Patterns

### 1. Optimal Batch Characteristics
- Size: 2-3 claims per batch
- Maximum recommended: 4 claims
- Unique fees: Maximum 3 per batch
- Same-day claims: Maximum 3 per batch

### 2. Risk Factors
- Batch size > 4 claims (20% risk increase)
- Mixed fee types (25% risk increase)
- High-value claims >$1000 (30% risk increase)
- Multiple same-day claims (15% risk increase)
- Large fee variations (10% risk increase)

### 3. Success Patterns
- Similar-value procedures grouped together
- Spacing between high-value submissions
- 1-2 day gaps between batches
- Consistent fee types within batch

## Data Quality Observations

### 1. Payment Success Indicators
- Zero payment rate < 20%
- Payment ratio > 70%
- Consistent fee types
- Appropriate batch spacing

### 2. Risk Indicators
- High-value claims mixed with low-value
- Excessive same-day submissions
- Mixed fee types in single batch
- Large batch sizes (>4 claims)

### 3. Batch Optimization Strategy
- Split batches > 4 claims
- Separate high-value procedures
- Group similar fee amounts
- Space out submissions

## Business Logic Implications

### 1. Claim Submission Rules
- Maximum batch size: 4 claims
- Maximum unique fees: 3 per batch
- Minimum days between batches: 1-2
- High-value claim isolation required

### 2. Fee Grouping Logic
- Group procedures within $500 range
- Separate claims >$1000
- Maximum 3 same-day claims
- Similar-value grouping preferred

### 3. Timing Considerations
- Space high-value claims across days
- Allow 1-2 days between batches
- Limit same-day submissions
- Balance urgent claim needs

### 4. Value-Based Rules
- Isolate claims >$1000
- Group within $500 ranges
- Total batch value limits
- Consider fee complexity

## Validation Metrics

### 1. Batch Quality Metrics
- Batch size distribution
- Fee variation within batch
- Same-day claim count
- Payment success rate

### 2. Risk Assessment
- High-value presence
- Fee mix complexity
- Batch timing patterns
- Size compliance

### 3. Success Indicators
- Payment ratio > 70%
- Zero payment rate < 20%
- Fee consistency
- Appropriate spacing

## Implementation Recommendations

### 1. System Controls
- Enforce batch size limits
- Flag high-risk combinations
- Track submission timing
- Monitor fee groupings

### 2. Process Improvements
- Optimize batch creation
- Implement fee grouping
- Manage submission timing
- Track success patterns

### 3. Monitoring Requirements
- Track batch success rates
- Monitor risk indicators
- Measure timing compliance
- Validate fee groupings