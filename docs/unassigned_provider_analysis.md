# Unassigned Provider Transaction Analysis
## Remaining Transactions Requiring Provider Assignment

This document provides a structured analysis of remaining unassigned provider transactions that require income transfers. Use this framework to track progress and prioritize assignments.

## 1. Summary of Remaining Unassigned Transactions

| Month     | Total Transactions | Total Amount | Status            | Priority |
|-----------|-------------------|--------------|-------------------|----------|
| 2025-01   | 25                | $14,157.60   | Needs Review      | High     |
| 2025-02   | 33                | $26,536.07   | Needs Review      | Critical |
| 2025-03   | [TBD]             | [TBD]        | [Current Month]   | Urgent   |
| **TOTAL** | **58+**           | **$40,693.67+** | **In Progress** | **High** |

## 2. January 2025 Unassigned Transactions Detail

| SplitNum | PayNum | PatNum | PatientName      | SplitAmt | PaymentDate | PayTypeName  | Staff | Suggested Provider | Status |
|----------|--------|--------|------------------|----------|-------------|--------------|-------|-------------------|--------|
| 7820     | 917901 | 31668  | Wallace, Kolleen | $11,000.00 | 2025-01-21 | Check        | [TBD] | [Based on ProcNum] | Open   |
| 7866     | 470237 | 918493 | Spoolstra, Shelley | $2,272.00 | 2025-01-28 | Credit Card  | [TBD] | [Based on ProcNum] | Open   |
| 7727     | 917466 | 27879  | Turner, Bruce    | $1,000.00  | 2025-01-04 | Credit Card  | [TBD] | [Based on ProcNum] | Open   |
| 7734     | 917467 | 27879  | Turner, Bruce    | $-1,000.00 | 2025-01-04 | Patient Refund | [TBD] | [Based on ProcNum] | Open   |
| 7679     | 918069 | 26037  | Niles, Harley    | $174.00    | 2025-01-01 | Income Transfer | [TBD] | [Based on ProcNum] | Open   |
| [Add remaining transactions...] |  |  |  |  |  |  |  |  |  |

## 3. February 2025 Unassigned Transactions Detail

| SplitNum | PayNum | PatNum | PatientName      | SplitAmt | PaymentDate | PayTypeName  | Staff | Suggested Provider | Status |
|----------|--------|--------|------------------|----------|-------------|--------------|-------|-------------------|--------|
| 8118     | 918663 | 31310  | Wade, William    | $10,090.80 | 2025-02-27 | Check        | [TBD] | [Based on ProcNum] | Open   |
| 7897     | 918146 | 12042  | West, William    | $9,733.00  | 2025-02-03 | Check        | [TBD] | [Based on ProcNum] | Open   |
| 8067     | 918526 | 31668  | Wallace, Kolleen | $9,732.00  | 2025-02-19 | Credit Card  | [TBD] | [Based on ProcNum] | Open   |
| 8076     | 918587 | 32615  | Spoolstra, Shelley | $3,000.00 | 2025-02-24 | Credit Card | [TBD] | [Based on ProcNum] | Open   |
| 8072     | 918585 | 12210  | Lynn, Lydia      | $690.50    | 2025-02-24 | Credit Card  | [TBD] | [Based on ProcNum] | Open   |
| [Add remaining transactions...] |  |  |  |  |  |  |  |  |  |

## 4. Prioritization Guidelines

Priority should be assigned to unassigned transactions using these criteria:

1. **Critical Priority**:
   - Transaction amount > $5,000
   - Transaction older than 30 days
   - VIP patient accounts

2. **High Priority**:
   - Transaction amount $1,000-$5,000
   - Transaction 15-30 days old
   - Patients with treatment plan in progress

3. **Medium Priority**:
   - Transaction amount $200-$999
   - Transaction 7-14 days old

4. **Low Priority**:
   - Transaction amount < $200
   - Transaction < 7 days old
   - Patient with no scheduled follow-up

## 5. Provider Assignment Logic

Use the following methods to determine the correct provider assignment:

1. **Clinical Record Method**: 
   - Review appointment history for the patient
   - Identify provider who most recently treated patient within 30 days of payment

2. **Procedure Association Method**:
   - Check if payment date corresponds with procedure completion
   - If ProcNum exists, assign to provider who performed procedure

3. **Treatment Plan Method**:
   - Review patient's treatment plan
   - Assign to provider managing primary treatment

4. **Patient Assignment Method**:
   - Check patient's assigned primary provider in system
   - Default to this provider if no other information available

## 6. Status Tracking

Track the status of each unassigned transaction:

| Status | Description |
|--------|-------------|
| Open | Identified as unassigned, no action taken |
| In Review | Assessment in progress for provider determination |
| Pending Approval | Provider identified, awaiting approval |
| Completed | Income transfer completed |
| No Action Needed | Determined appropriate as unassigned |

## 7. Weekly Progress Summary

Update weekly to track completion:

| Week Ending | Starting Count | Completed | Remaining | Completion % |
|-------------|----------------|-----------|-----------|--------------|
| YYYY-MM-DD | [Initial count] | 0 | [Initial count] | 0% |
| [Next week] | [Remaining] | [Number completed] | [New remaining] | [Percentage] |

## 8. Action Plan

1. **Immediate Actions** (Week 1):
   - Complete provider assignment for all Critical priority transactions
   - Process income transfers for all transactions >$5,000

2. **Short-Term Actions** (Weeks 2-3):
   - Complete provider assignment for all High priority transactions
   - Process income transfers for all transactions $1,000-$5,000

3. **Medium-Term Actions** (Weeks 4-6):
   - Complete remaining Medium and Low priority transactions
   - Document patterns for prevention strategies

4. **Long-Term Prevention** (Ongoing):
   - Implement system validation to prevent unassigned payments
   - Conduct staff training on payment entry requirements
   - Establish daily unassigned payment review 