# OpenDental Payment Transaction Flow

## Core Payment Flow

### 1. Payment Creation
- **Source**: Payments originate from two primary sources:
  - Patient payments (direct)
  - Insurance payments (via claims)
- **Storage**: All payments are recorded in `payment` table
  - `PayNum` (unique identifier)
  - `PayAmt` (total payment amount)
  - `PayType` (links to definition table)
  - `PayDate` (transaction date)

### 2. Payment Splitting
- **Process**: Each payment is split into one or more portions
- **Storage**: Splits recorded in `paysplit` table
  - `SplitNum` (unique identifier)
  - `PayNum` (links to payment)
  - `SplitAmt` (portion of total payment)
  - `ProcNum` (links to procedure, if applicable)
  - `UnearnedType` (payment classification)

### 3. Split Types
Based on analysis, splits fall into three categories:
1. **Regular Payments (Type 0)** - 88.9% of splits
   - Direct application to procedures
   - Immediate revenue recognition
2. **Prepayments (Type 288)** - 10.9% of splits
   - Payment received before procedure
   - Held as unearned revenue
3. **Treatment Plan Prepayments (Type 439)** - 0.2% of splits
   - Specific to treatment plan deposits
   - Highest average amounts

### 4. Split Patterns
- **Normal Pattern** (99.3% of payments)
  - 1 split: 32.3%
  - 2 splits: 25.9%
  - 3 splits: 18.5%
- **Complex Pattern** (0.7% of payments)
  - Multiple claims per procedure (41 payments)
  - Maximum 2 claims per procedure
  - Primarily insurance payments (78% Type 71)
  - All duplicates are legitimate business cases

### 5. Payment Source Analysis
- **Insurance Payments**
  - Tracked through ClaimProc table
  - Requires valid claim relationship
  - Insurance amounts properly tracked per claim
  - Same split can appear in multiple claim contexts
  - Split amounts + Insurance amounts = Total payment

- **Patient Payments**
  - Direct payment application
  - No claim relationship required
  - Equal patient portions across related claims
  - Simpler split patterns

### 6. Payment Validation Rules
1. **Basic Validation**
   - Payment total must equal sum of splits
   - Split amounts must be non-negative
   - Maximum 15 splits per payment (standard)

2. **Date Validation for Accounts Receivable (AR)**
   - AR represents money owed to the practice at a specific point in time
   - The `as_of_date` is the reference date for AR calculations (e.g., end of month)
   - Only payments dated before the `as_of_date` should be included in AR calculations
   - Example:
     - If calculating AR as of March 31, 2024:
     - Include: All payments dated March 31 or earlier
     - Exclude: Any payments dated April 1 or later
   - This ensures:
     - Historical AR reports remain accurate
     - Future-dated payments don't artificially reduce past AR balances
     - Consistent point-in-time financial snapshots

   **AR Aging Buckets**:
   - Current: ≤30 days (39.3% of AR)
   - 30-60 days (11.7% of AR)
   - 60-90 days (12.7% of AR)
   - 90+ days (36.2% of AR)

3. **Split Validation**
   - Split difference tolerance: 0.01
   - Payment-to-fee ratio: 0.95-1.05
   - Zero-fee procedures with payments flagged
   - Allow multiple claims per procedure
   - Maintain patient-claim relationships
   - Verify split amount distribution
   - Track insurance payment history

### 7. Business Logic Implications
- Current logic correctly handles complex splits
- No changes needed to split creation
- Multiple claims per procedure is valid
- Reports should expect 1-2 claims per procedure
- Sum of splits will match payment amount
- Insurance amounts may exceed split amounts
- Same split can appear in multiple claim contexts

### 8. Payment Batch Processing
- **Batch Definition**: A group of claims processed together for insurance submission
- **Batch Rules**:
  - Maximum batch size: 4 claims
  - Maximum unique fees: 3 per batch
  - Minimum days between batches: 1-2 days
  - High-value claims must be isolated

- **Batch Optimization Strategy**:
  1. Split batches > 4 claims
  2. Separate high-value procedures
  3. Group similar fee amounts (within $500 range)
  4. Space out submissions

- **Value-Based Rules**:
  - Isolate claims >$1000
  - Group procedures within $500 ranges
  - Balance total batch value
  - Consider fee complexity

- **Timing Considerations**:
  - Space high-value claims across days
  - Allow 1-2 days between batches
  - Limit same-day submissions
  - Balance urgent claim needs

- **Success Indicators**:
  - Payment ratio > 70%
  - Zero payment rate < 20%
  - Fee consistency within batch
  - Appropriate timing spacing

### 9. Transfer Payment Patterns
- **Transfer Payments**: Internal accounting transactions
  - Used for moving money between accounts/procedures
  - Typically have offsetting positive/negative splits
  - Should net to $0 total impact
  - Normal pattern: 1-3 splits per procedure

- **Split Pattern Warning Signs**:
  - Excessive splits (>100 per procedure)
  - Perfect symmetry in split amounts
  - Identical patterns across procedures
  - High volume of splits in short timeframe

### 10. Procedure-Split Relationships
- **Normal Pattern**:
  - 1-3 splits per procedure
  - Split amounts reflect actual procedure costs
  - Mixed positive/negative allowed for adjustments
  - Multiple procedures per payment common

- **Maximum Limits**:
  - Standard: 15 splits per payment
  - Warning threshold: >100 splits per procedure
  - Critical threshold: >1000 splits per procedure

## Next Steps for Documentation
1. Add detailed insurance payment processing flow
2. Document adjustment handling
3. Expand on AR calculation rules
4. Add payment batch processing logic
5. Include fee schedule interaction details

Note: This is the initial core flow. Further iterations will incorporate insurance claim processing, adjustments, and more complex payment scenarios based on the business logic documents.
