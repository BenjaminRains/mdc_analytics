# Income Transfer Workflow for OpenDental
## Standard Operating Procedure

This document outlines the proper workflow for identifying, executing, and verifying income transfers in OpenDental. Proper adherence to this procedure will reduce unassigned provider transactions and improve financial reporting accuracy.

## 1. Identifying When Income Transfers Are Needed

### Scenarios Requiring Income Transfer

| Scenario | Description | Priority |
|----------|-------------|----------|
| **Initial Misallocation** | Payment was assigned to incorrect provider at time of entry | High |
| **Unassigned Payment** | Payment was entered without a provider assignment | High |
| **Prepayment Allocation** | Prepayment needs to be allocated to provider who performed work | Medium |
| **Provider Transfer** | Patient transferred between providers during treatment | Medium |
| **Treatment Plan Change** | Original provider differs from provider who performed service | Medium |
| **Provider Left Practice** | Redistributing payments from departing provider | Low |

### Key Indicators

* Provider production report shows discrepancies
* Unassigned provider appears in transaction reports
* Payment split report shows provider ≠ procedure provider 
* Prepayment remains unapplied after procedure completion
* Patient balance shows credit with unassigned provider

## 2. Required Information Before Transfer

Before initiating an income transfer, gather:

- [ ] Patient name and ID
- [ ] Original payment date and amount
- [ ] Current provider assignment (source)
- [ ] Correct provider assignment (destination)
- [ ] Relevant procedure codes
- [ ] Reason for transfer
- [ ] Authorization (if required by amount threshold)

## 3. Income Transfer Process Steps

### A. Accessing the Income Transfer Function

1. Log into OpenDental with appropriate user credentials
2. Navigate to Accounting > Income Transfer
3. Select the patient account requiring income transfer
4. Verify patient information and account status

### B. Executing the Transfer

1. Locate the specific payment requiring transfer in the patient's account
2. Select the income transfer function
3. Document the source provider (current assignment)
4. Select the destination provider (correct assignment)
5. Verify the transfer amount
6. Enter a standardized note (see format below)
7. Complete the transfer
8. Document the SplitNum for reference

### C. Standardized Note Format

All income transfer notes must follow this format:
```
Income Transfer: FROM [source provider] TO [destination provider] - [reason code] - [your initials]
```

Example:
```
Income Transfer: FROM Unassigned TO Dr. Smith - PREPAY ALLOCATION - SW
```

### Reason Codes:
- INITIAL ERROR: Payment was initially assigned incorrectly
- PREPAY ALLOCATION: Allocating prepayment to treating provider
- PROV CHANGE: Provider changed during treatment
- TX PLAN MOD: Treatment plan was modified
- OTHER: Other reason (requires additional explanation)

## 4. Verification Process

### Immediate Verification
Immediately after completing the transfer:

1. Refresh the patient account
2. Verify the payment now shows the correct provider
3. Confirm the transfer note appears correctly
4. Check that patient balance remains unchanged

### Post-Transfer Verification
Within 24 hours:

1. Run the daily split allocation report
2. Verify provider production reports reflect the transfer
3. Check for any unintended consequences (e.g., other allocations affected)

## 5. Common Issues and Troubleshooting

| Issue | Potential Cause | Solution |
|-------|-----------------|----------|
| Transfer not showing in reports | Report parameters incorrect | Adjust date ranges and filters |
| Provider still shows as unassigned | Transfer not completed properly | Repeat transfer process |
| Multiple transfers created | Duplicate process execution | Contact system administrator |
| Transfer amount incorrect | Split payment not fully selected | Cancel and restart with correct amount |
| System error during transfer | Software or connection issue | Document error, contact IT support |

## 6. Approval Requirements

| Transfer Amount | Approval Required |
|-----------------|-------------------|
| < $500 | Self-verification |
| $500 - $1,000 | Team lead verification |
| > $1,000 | Manager approval required |
| > $5,000 | Director/owner approval required |

## 7. Documentation and Record Keeping

For each income transfer, the following must be documented:

- Date and time of transfer
- Staff member performing transfer
- Source and destination providers
- Amount transferred
- Reason for transfer
- Approval (if required)
- Verification completion

## 8. Monitoring and Analytics

### Daily Monitoring
- Review all new income transfers
- Verify proper documentation
- Check for patterns requiring system or process changes

### Weekly Unassigned Provider Report Process
1. **Report Generation (Every Monday)**
   - Run the unassigned provider transaction SQL query
   - Export results to a formatted table 
   - Distribute to billing staff and providers
   - Save as "[YYYY-MM-DD]_unassigned_provider_report.txt" for tracking

2. **Assignment Session (Monday Morning)**
   - 15-minute team meeting to review the report
   - Assign high-priority transactions to specific staff members
   - Document assignments in shared tracking sheet

3. **Completion Deadline**
   - Critical priority: Same day (Monday)
   - High priority: By Wednesday
   - Medium priority: By Friday
   - Low priority: By next Monday

4. **Verification Process**
   - Team lead verifies all critical and high priority assignments
   - Run verification query each morning to track progress
   - Update completion status in tracking sheet

5. **Weekly Metrics**
   - Total unassigned transactions (trend over time)
   - Completion rate (% resolved within deadline)
   - Staff performance metrics
   - Root causes identified

6. **Key Performance Indicators**
   - Target: Zero "Critical" priority transactions at end of each week
   - Target: <5 new unassigned transactions per week
   - Target: >95% resolution of all identified transactions each week

### Weekly Reporting
- Total number and value of income transfers
- Transfers by reason code
- Transfers by staff member
- Provider impact analysis

### Monthly Analysis
- Identify root causes of transfers
- Assess staff training needs
- Evaluate process effectiveness
- Recommend system or procedure changes

## 9. Training Requirements

All staff performing income transfers must:
1. Complete initial income transfer training
2. Demonstrate proficiency in the process
3. Complete refresher training annually
4. Review updated procedures as released

## 10. Audit Procedures

Income transfers will be audited:
- Randomly (10% of all transfers)
- For all transfers over $1,000
- For any provider with transfers exceeding 5% of monthly production
- As part of quarterly financial reviews

## 11. Bulk Income Transfer Protocol

For scenarios requiring multiple transfers (as occurred in October 2024):

1. **Planning**:
   - Document all transfers needed in a spreadsheet
   - Get management approval for the bulk operation
   - Schedule during non-peak hours

2. **Execution**:
   - Use consistent amounts and note formats
   - Process patient by patient to avoid confusion
   - Document progress in real-time
   - Have a second team member verify as you go

3. **Verification**:
   - Run reports immediately after completion
   - Schedule follow-up verification 24 hours later
   - Document any discrepancies

## 12. Current Priority Transfer Protocol (March 2025)

To address the 58 remaining unassigned transactions identified in our analysis:

1. **High-Value Transaction Procedure**:
   - **Focus**: Four transactions over $9,000 each (Total: $40,555.80)
   - **Timing**: Complete within 48 hours
   - **Process**:
     * Review patient appointment history for each account
     * Verify suggested provider based on most recent appointment
     * Execute transfers with comprehensive notes
     * Notify providers of significant production changes
     * Include "March 2025 Cleanup" in transfer notes

2. **Mid-Value Transaction Procedure**:
   - **Focus**: Transactions between $500-$9,000 (approximately 10 transactions)
   - **Timing**: Complete within one week
   - **Process**:
     * Batch process by staff member who entered original transaction
     * Have each staff member review and approve provider assignment
     * Include standardized notation referencing this cleanup initiative

3. **Low-Value Transaction Procedure**:
   - **Focus**: Remaining transactions under $500
   - **Timing**: Complete within two weeks
   - **Process**:
     * Group by provider and patient when possible
     * Process in batches of 10-15 transactions
     * Validate against patient appointment history

4. **Progress Tracking**:
   - Daily update of completion rates
   - Document transaction numbers processed
   - Track by priority category
   - Report daily to management until complete

## Implementation Timeline

| Phase | Duration | Activities |
|-------|----------|------------|
| 1: Training | 1 week | Staff training on new procedures |
| 2: Supervised Operation | 2 weeks | Transfers performed under supervision |
| 3: Audit Period | 1 month | 100% audit of all transfers |
| 4: Normal Operation | Ongoing | Regular process with standard audit rates |
| 5: March 2025 Cleanup | 2 weeks | Process all 58 identified transactions |

## Attachments and Resources

- OpenDental UI reference guide
- Sample reports for verification
- Quick reference guide for common scenarios
- Link to income_transfer_data_obs.md for pattern analysis
- Active unassigned provider transaction report (March 3, 2025)

## Revision History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | 2024-03-05 | Initial document creation | MDC Analytics |
| 2.0 | 2025-03-04 | Major revision with bulk transfer protocol | MDC Analytics |
| 2.1 | 2025-03-05 | Added current priority protocol and updated data | MDC Analytics |
| 2.2 | 2025-03-05 | Added weekly unassigned provider report process | MDC Analytics |

---

**Approved by**: ________________________  
**Date**: _______________________________ 

---

## Appendix A: Unassigned Payments Analysis

### Current Issues Analysis

Based on a comprehensive analysis of unassigned provider transactions, the following patterns have been identified:

#### Key Contributors

1. **User Patterns**: 
   - Sophie (18 transactions, 31%) is the primary contributor to unassigned payments
   - Emily, Chelsea, and Melanie each contributed approximately 10 transactions
   - Even providers (Dr. Kamp and Dr. Schneiss) have processed 11 transactions without provider assignment

2. **Payment Types**:
   - Credit Card transactions represent the majority of unassigned payments
   - Patient Refund transactions are the second most common type
   - Many transactions are new patient deposits and phone payments

3. **Time Patterns**:
   - January 2025 had 28 unassigned transactions totaling $31,811.40
   - February 2025 had 30 unassigned transactions with a net value of $-1,117.73
   - Four transactions exceed $9,000 each, representing the highest priority for correction

4. **Provider Associations**:
   - Dr. Timothy Kamp and Dr. Beau Schneiss are the suggested providers for most unassigned transactions
   - Proper provider allocation will significantly impact their production numbers

### Root Causes

The analysis reveals several likely root causes:

1. **Training Gaps**: Users, particularly Sophie, may not understand the importance of assigning providers to payments or the financial impact of unassigned payments.

2. **System Design Issues**: The payment entry screen may not make the provider field mandatory or prominent enough during the payment entry process.

3. **Workflow Disconnects**: Payments are likely being processed separately from treatment documentation, causing disconnection between provider information and the payment process.

4. **Time Pressure**: Transaction patterns suggest higher workloads may be leading to shortcuts in data entry.

5. **Credit Card Processing**: The predominance of credit card transactions suggests a specific issue in how these payments are being processed in the system.

### Action Requirements

Based on March 2025 analysis of the 58 remaining unassigned transactions:

1. **Critical Priority (Complete by March 7, 2025)**
   - Process all 28 January transactions
   - Prioritize the four large transactions over $9,000 each
   - Ensure proper documentation for all transfers

2. **High/Medium Priority (Complete by March 14, 2025)**
   - Process remaining February transactions
   - Conduct training for top contributors (Sophie, Emily, Chelsea, Melanie)
   - Implement daily verification process

3. **Preventive Measures (Implement by March 31, 2025)**
   - Add provider field validation to payment entry screen
   - Create automated daily report of unassigned transactions
   - Develop staff performance metrics that include unassigned rate

This cleanup effort should target 100% resolution of all identified transactions by March 15, 2025, with preventive measures fully implemented by March 31, 2025. 

## 13. Weekly Unassigned Provider Report SQL

To generate the weekly unassigned provider report, use the following SQL query:

```sql
-- Query for unassigned provider transactions with suggested providers and prioritization
SELECT 
    'PaySplit' AS TransactionType,
    ps.SplitNum AS TransactionNum,
    ps.PayNum,
    ps.PatNum,
    CONCAT(p.LName, ', ', p.FName) AS PatientName,
    ps.SplitAmt,
    pay.PayDate AS TransactionDate,
    -- Map payment type using definition table
    (SELECT d.ItemName 
     FROM definition d 
     WHERE d.Category = 24  -- Payment Type category
     AND d.DefNum = pay.PayType) AS PayTypeName,
    ps.ProcNum,
    pay.PayNote AS Note,
    u.UserName AS EnteredBy,
    CASE 
        WHEN prov.FName IS NULL THEN 'Unassigned'
        ELSE CONCAT(prov.LName, ', ', prov.FName)
    END AS CurrentProvider,
    -- Suggested provider based on most recent appointment
    (SELECT 
        CONCAT(prov2.LName, ', ', prov2.FName)
     FROM appointment a
     JOIN provider prov2 ON a.ProvNum = prov2.ProvNum
     WHERE a.PatNum = ps.PatNum
       AND a.AptDateTime <= pay.PayDate
     ORDER BY a.AptDateTime DESC
     LIMIT 1) AS SuggestedProvider,
    DATEDIFF(CURRENT_DATE, pay.PayDate) AS DaysOld,
    CASE
        WHEN DATEDIFF(CURRENT_DATE, pay.PayDate) > 30 THEN 'Critical'
        WHEN ABS(ps.SplitAmt) > 5000 THEN 'Critical'
        WHEN ABS(ps.SplitAmt) BETWEEN 1000 AND 5000 OR DATEDIFF(CURRENT_DATE, pay.PayDate) BETWEEN 15 AND 30 THEN 'High'
        WHEN ABS(ps.SplitAmt) BETWEEN 200 AND 999 OR DATEDIFF(CURRENT_DATE, pay.PayDate) BETWEEN 7 AND 14 THEN 'Medium'
        ELSE 'Low'
    END AS Priority
FROM paysplit ps
LEFT JOIN patient p ON ps.PatNum = p.PatNum
LEFT JOIN payment pay ON ps.PayNum = pay.PayNum
LEFT JOIN provider prov ON ps.ProvNum = prov.ProvNum
LEFT JOIN userod u ON ps.SecUserNumEntry = u.UserNum
WHERE ps.ProvNum = 0  -- Unassigned provider
AND pay.PayDate >= DATE_SUB(CURRENT_DATE, INTERVAL 90 DAY)  -- Focus on last 90 days, adjust as needed
AND ps.PayPlanNum = 0  -- Not attached to payment plan

UNION ALL

-- Add adjustments with unassigned providers
SELECT 
    'Adjustment' AS TransactionType,
    adj.AdjNum AS TransactionNum,
    0 AS PayNum,  -- Placeholder for adjustment records
    adj.PatNum,
    CONCAT(p.LName, ', ', p.FName) AS PatientName,
    adj.AdjAmt AS SplitAmt,
    adj.AdjDate AS TransactionDate,
    -- Get adjustment type name
    (SELECT d.ItemName 
     FROM definition d 
     WHERE d.Category = 16  -- Adjustment Type category
     AND d.DefNum = adj.AdjType) AS PayTypeName,
    adj.ProcNum,
    adj.AdjNote AS Note,
    u.UserName AS EnteredBy,
    CASE 
        WHEN prov.FName IS NULL THEN 'Unassigned'
        ELSE CONCAT(prov.LName, ', ', prov.FName)
    END AS CurrentProvider,
    -- Suggested provider based on most recent appointment
    (SELECT 
        CONCAT(prov2.LName, ', ', prov2.FName)
     FROM appointment a
     JOIN provider prov2 ON a.ProvNum = prov2.ProvNum
     WHERE a.PatNum = adj.PatNum
       AND a.AptDateTime <= adj.AdjDate
     ORDER BY a.AptDateTime DESC
     LIMIT 1) AS SuggestedProvider,
    DATEDIFF(CURRENT_DATE, adj.AdjDate) AS DaysOld,
    CASE
        WHEN DATEDIFF(CURRENT_DATE, adj.AdjDate) > 30 THEN 'Critical'
        WHEN ABS(adj.AdjAmt) > 5000 THEN 'Critical'
        WHEN ABS(adj.AdjAmt) BETWEEN 1000 AND 5000 OR DATEDIFF(CURRENT_DATE, adj.AdjDate) BETWEEN 15 AND 30 THEN 'High'
        WHEN ABS(adj.AdjAmt) BETWEEN 200 AND 999 OR DATEDIFF(CURRENT_DATE, adj.AdjDate) BETWEEN 7 AND 14 THEN 'Medium'
        ELSE 'Low'
    END AS Priority
FROM adjustment adj
LEFT JOIN patient p ON adj.PatNum = p.PatNum
LEFT JOIN provider prov ON adj.ProvNum = prov.ProvNum
LEFT JOIN userod u ON adj.SecUserNumEntry = u.UserNum
WHERE adj.ProvNum = 0  -- Unassigned provider
AND adj.AdjDate >= DATE_SUB(CURRENT_DATE, INTERVAL 90 DAY)  -- Focus on last 90 days, adjust as needed

ORDER BY Priority, ABS(SplitAmt) DESC;
```

### Report Formatting Configuration

Export the SQL results as a tab-delimited or pipe-delimited text file for maximum readability. Configure the export to preserve column formatting.

### Archiving Reports

Save all weekly reports in: `scripts/validation/payment_split/reports/weekly_unassigned/`

This maintains a historical record of unassigned transactions and resolution progress over time. 