# OpenDental Source Code Investigation
Focus: Account/Balance Calculation Logic

## Investigation Goals
1. Understand how OpenDental calculates procedure balances
2. Identify "paid in full" determination logic
3. Map payment/adjustment flow
4. Document account module architecture

## Starting Points

### 1. Core Classes
Look for these key classes:
```csharp
// Primary business objects
OpenDental.Procedure
OpenDental.Payment
OpenDental.PaySplit
OpenDental.ClaimProc
OpenDental.Adjustment

// Business logic classes
OpenDental.ProcedureLogic
OpenDental.PaymentLogic
OpenDental.ClaimProcLogic
```

### 2. Key Methods
Search for methods containing:
```csharp
// Balance calculation
GetBalance
ComputeBalance
CalculateRemaining
GetPatientPortion

// Payment processing
ComputePayments
ProcessPayment
SplitPayment

// Account status
IsFullyPaid
IsPaidOff
ValidatePayment
```

### 3. UI Entry Points
Look for forms/windows:
```csharp
// Main interfaces
FormAccount
ContrAccount
AccountModule

// Payment interfaces
FormPayment
FormPaySplit
FormProcEdit
```

## Investigation Approach

### 1. Follow the Money
1. Start at payment entry
   - How are payments recorded?
   - Where are splits calculated?
   - What triggers balance updates?

2. Track procedure lifecycle
   - Fee assignment
   - Insurance estimation
   - Payment application
   - Adjustment handling

3. Map balance calculation
   - When is it computed?
   - What components are included?
   - How are edge cases handled?

### 2. Database Integration
Look for:
```csharp
// Data access
TableProcedures
TablePayments
TablePaySplits
TableClaimProcs
TableAdjustments

// Queries/Commands
SELECT
UPDATE
CRUD operations
```

### 3. Business Logic
Search for:
```csharp
// Payment validation
if(payment.Amount...)
if(remaining...)
if(balance...)

// Status checks
if(isPaid...)
if(isComplete...)
if(needsPayment...)
```

## Key Questions

1. Balance Calculation
   - How is procedure balance calculated?
   - When is balance recalculated?
   - What triggers updates?

2. Payment Processing
   - How are payments split?
   - What validates payment amounts?
   - How are overpayments handled?

3. Insurance Integration
   - How are insurance payments tracked?
   - When are estimates updated?
   - How are write-offs handled?

4. Edge Cases
   - Zero fee procedures
   - Bundled procedures
   - Split payments
   - Adjustments

## Search Patterns

### 1. Code Comments
```csharp
// Look for:
"//Calculate balance"
"//Process payment"
"//Update account"
"//Split payment"
```

### 2. Variable Names
```csharp
balance
remaining
paid
procFee
adjustment
payment
```

### 3. SQL Queries
```sql
-- Look for:
SELECT ... FROM procedurelog
JOIN paysplit
JOIN claimproc
JOIN adjustment
```

## Documentation Plan

1. Create class diagram showing:
   - Payment processing flow
   - Balance calculation components
   - Account status determination

2. Document key methods:
   - Purpose
   - Parameters
   - Return values
   - Side effects

3. Map business rules:
   - Payment validation
   - Balance calculation
   - Status determination

4. Note edge cases:
   - Special handling
   - Validation rules
   - Error conditions

## Next Steps

1. Initial Investigation
   - Find main account/payment classes
   - Locate balance calculation logic
   - Identify payment processing flow

2. Deep Dive
   - Map payment application logic
   - Document balance calculation
   - Understand status determination

3. Edge Cases
   - Zero fee handling
   - Adjustment processing
   - Insurance integration
   - Split payment logic

4. Integration Points
   - UI triggers
   - Database updates
   - Business rule validation

## Success Criteria

1. Can explain:
   - How balances are calculated
   - When balances are updated
   - What determines "paid in full"

2. Can map:
   - Payment processing flow
   - Balance calculation components
   - Status determination logic

3. Can document:
   - Edge case handling
   - Validation rules
   - Business logic 