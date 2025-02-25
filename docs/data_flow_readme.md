# Payment Processing Data Flow

## Patient and Procedure
- The process starts when a patient undergoes a procedure, which is recorded in the **ProcedureLog**
- Each procedure has a unique ProcNum, associated fee (ProcFee), and status (ProcStatus)

## Fee Processing & Verification
- Initial clinic fee is set based on standard tiers from the **Clinic Fee Source**
- A **Fee Schedule Check** determines if contracted rates exist
  - If no schedule exists, goes through a fee setting decision process
  - If schedule exists, contracted rates are applied and update the clinic fee
- The final verified/updated fee is recorded back in the ProcedureLog

## Insurance Processing
- A claim is created (with ClaimNum and Status) for the procedure
- Claims go through **Batch Analysis** which evaluates:
  - Batch size
  - Timing
  - Value
- **Batch Submission** optimizes claims by grouping:
  - Maximum 4 claims per batch
  - Similar value claims
  - Spacing high-value claims across days
- A ClaimProc record is generated for insurance processing
- The insurance carrier/plan receives the claim
- Insurance estimation is received
- Final insurance payment is documented

## Payment Allocation & Reconciliation
- Both insurance and patient payments flow into the **Payment** table
  - Each payment has PayNum, PayAmt, PayType, and PayDate
- Payments are split into portions recorded in the **PaySplit** table
  - Each split has SplitNum, PayNum, SplitAmt, and ProcNum
- Splits are classified into three types:
  - **Regular Payments (Type 0)** - 88.9% of splits (direct application)
  - **Prepayments (Type 288)** - 10.9% of splits (unearned revenue)
  - **Treatment Plan Prepayments (Type 439)** - 0.2% of splits (plan deposits)
- **Transfer Payments** are special transactions that:
  - Net to $0 total impact
  - Have offsetting positive/negative splits
  - Move money between accounts/procedures
- All splits are analyzed by **Split Pattern Analysis**:
  - Normal pattern (99.3%): 1-3 splits per payment
  - Complex pattern (0.7%): Max 2 claims per procedure
- Payment validation rules ensure:
  - Sum of splits equals payment amount
  - Non-negative split amounts
  - Standard limit of 15 splits per payment
- Transaction date validation checks against as_of_date:
  - Payments before as_of_date are included in AR Analysis
  - Payments after as_of_date are excluded from AR

## AR Analysis
- Aging analysis classifies AR into buckets:
  - Current: ≤30 days (39.3% of AR)
  - 30-60 days (11.7% of AR)
  - 60-90 days (12.7% of AR)
  - 90+ days (36.2% of AR)

## Collection Process
- Collection status determines appropriate actions
- Collection actions are taken based on account status
- Actions result in either:
  - Success → Collected
  - Failure → Escalation Options

## Success Criteria
Collection process concludes with:
- Journey Complete (for successful collections)
- Escalation options for unresolved accounts

## Visual Grouping
The process is visually organized into five main sections:
- Fee Processing & Verification (pink)
- Insurance Processing (blue)
- Payment Allocation & Reconciliation (yellow)
- AR Analysis (light purple)
- Collection Process (light green)
