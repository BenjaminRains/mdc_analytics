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
  - 2-3 claims together
  - Similar value claims
- A ClaimProc record is generated for insurance processing
- The insurance carrier/plan receives the claim
- Insurance estimation is received
- Final insurance payment is documented

## Payment Allocation & Reconciliation
- Both insurance and patient payments flow into the **Payment Application** process
- Payments are analyzed by **Split Pattern Analysis**:
  - Normal splits (99.3%): 1-3 splits per payment
  - Complex splits (0.7%): Maximum 2 claims/procedures
- All splits are validated through:
  - Balance calculation
  - Transaction date check against as_of_date
  - AR distribution between patient and insurance
- Transactions dated before as_of_date go to aging analysis
- Transactions after as_of_date are excluded from AR

## Collection Status Flow
- Aging analysis classifies payments into aging buckets
- Collection status is determined as:
  - New → Scheduled
  - Active → Under Follow-up
  - Pending → Outstanding
  - Failed → Follow-up Exhausted
- Collection actions are taken based on status:
  - Start (for Scheduled)
  - Monitor (for Under Follow-up)
  - Chase (for Outstanding)
  - Escalate (for Follow-up Exhausted)
- Actions result in either:
  - Success → Collected
  - Failure → Escalation Options

## Success Criteria
Collection process concludes with:
- Journey Complete (for successful collections)
- Write-off
- Legal Collection
- Collection Agency referral

## Visual Grouping
The process is visually organized into five main sections:
- Fee Processing & Verification (pink)
- Insurance Processing (blue)
- Payment Allocation & Reconciliation (yellow)
- Collection Status Flow (light purple)
- Success Criteria (light yellow)
