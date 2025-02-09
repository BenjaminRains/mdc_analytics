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
- **Adjustment Types**:
  - `adjustment.AdjAmt`: Represents discounts or other fee modifications.
  - `adjustment.AdjType`: Links to `definition.DefNum` for adjustment categorization.
- **Adjustment Logic**:
  - **Hypothesis**: Discounts are stored in `adjustment.AdjAmt` and categorized by `AdjType`.

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

- **Procedurelog.ProcFee**: The clinic fee for the procedure before insurance, adjustments, discounts, write-offs. (Strong Hypothesis)

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

QUERY 1 from: fee_and_payment_process_validation.sql
Purpose: To validate the fee population logic in the procedurelog table by comparing recorded procedure fees with clinic fees and procedure descriptions.
Selected Columns:
pl.ProcNum: The unique identifier for each procedure.
pl.CodeNum: The code number associated with the procedure, used to link with fee and procedure description.
pl.ProcFee: The fee recorded for the procedure in the procedurelog.
pl.PatNum: The patient number, identifying the patient who underwent the procedure.
pl.ProcDate: The date when the procedure was performed.
f.Amount AS clinic_fee: The fee amount from the fee table, representing the clinic's standard fee for the procedure.
pc.Descript AS procedure_description: A descriptive name for the procedure, retrieved from the procedurecode table.
Joins:
The query joins the procedurelog table with the fee table using the CodeNum field to compare the recorded procedure fee with the clinic's standard fee.
It also joins the procedurelog table with the procedurecode table using the CodeNum field to retrieve descriptive names for the procedures.
Filters:
The query filters records to include only those procedures with a ProcStatus of 2, which typically indicates completed procedures.
It restricts the results to procedures performed within the last four years, using the DATE_SUB function to calculate the date range.


QUERY 2 from: fee_and_payment_process_validation.sql
This SQL query is designed to analyze how discounts and adjustments are applied within a healthcare system by examining records in the adjustment table. It also provides context for each adjustment by joining with the definition table to retrieve descriptive names for adjustment types.
Purpose: To understand the application of discounts and other adjustments by examining adjustment records over the past four years.
Selected Columns:
a.AdjNum: The unique identifier for each adjustment record.
a.AdjAmt: The amount of the adjustment, which could represent a discount or other financial modification.
a.AdjType: The type of adjustment, represented by a numerical code.
a.PatNum: The patient number, identifying the patient associated with the adjustment.
a.AdjDate: The date when the adjustment was applied.
d.ItemName AS adjustment_type_name: A descriptive name for the adjustment type, retrieved from the definition table.
Joins:
The query joins the adjustment table with the definition table using the AdjType and DefNum fields. This join allows the query to replace numerical adjustment type codes with human-readable names, making the data easier to interpret.
Filters:
The query filters records to include only those adjustments that occurred within the last four years. This is achieved using the DATE_SUB function to calculate the date range.


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