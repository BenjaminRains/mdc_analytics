# Flowchart Explanation

## Procedure & Initial Fee Setting:

- The process starts when a patient undergoes a procedure, which is recorded in the **ProcedureLog**.
- The initial fee is set (but note that discrepancies may occur between the fee recorded in **ProcedureLog** and the **Fee** table).

## Fee Processing & Verification:

- The clinic verifies the fee—using both the **Fee** table (as a potential authoritative source) and a **Fee Schedule Check**.
- If a fee schedule exists, the contracted rates (from **feesched**) update the procedure fee; if not, a business decision process adjusts the fee.

## Discount / Adjustment Processing:

- Before insurance comes into play, any applicable discounts or adjustments (from the **Adjustment** table) are applied to the fee.
- A lookup via the **Definition** table confirms the type of discount, and the procedure fee is adjusted accordingly.

## Insurance Processing:

- A claim is created for the procedure, and details are captured in **ClaimProc**.
- The claim is sent to the insurance carrier, where an estimation process determines the insurance's allowed fee.
- **Bluebook** data (and its log) document the insurance's estimated payment and allowed overrides, feeding into the insurance review process that determines the final insurance payment.

## Payment Allocation & Reconciliation:

- The final insurance payment, along with any patient payments (captured via **Payment** and **PaySplit**), are applied back to update the fee and balances in the **ProcedureLog**.
- These transactions feed into financial reports and reconciliation processes.
