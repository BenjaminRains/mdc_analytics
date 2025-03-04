# Income Transfer Data Observations
## Analysis of Unassigned Provider Transactions

This document presents a comprehensive analysis of unassigned provider transactions based on data collected from 2024-01 through 2025-02. The findings are intended to identify patterns, root causes, and opportunities for improvement in payment allocation processes.

## 1. Transaction Volume Patterns

### Monthly Transaction Counts
| Month | Transactions | Total Amount | Avg Transaction Value |
|-------|--------------|--------------|----------------------|
| 2024-01 | 11 | $3,543.15 | $322.10 |
| 2024-02 | 14 | $18,539.49 | $1,324.25 |
| 2024-03 | 17 | $2,345.10 | $138.00 |
| 2024-04 | 14 | $20,930.30 | $1,495.02 |
| 2024-05 | 19 | $26,960.20 | $1,418.96 |
| 2024-06 | 19 | $2,678.97 | $141.00 |
| 2024-07 | 18 | $46,184.94 | $2,565.83 |
| 2024-08 | 28 | $2,611.94 | $93.28 |
| 2024-09 | 15 | $1,602.42 | $106.83 |
| 2024-10 | 850 | $-277,899.65 | $-326.94 |
| 2024-11 | 389 | $-15,427.96 | $-39.66 |
| 2024-12 | 46 | $-17.19 | $-0.37 |
| 2025-01 | 28 | $31,811.40 | $1,136.12 |
| 2025-02 | 30 | $-1,117.73 | $-37.26 |

### Key Transaction Volume Observations
1. **Accumulation Pattern**: From January through September 2024, unassigned transactions steadily accumulated, increasing from 11 to 28 per month.
2. **Correction Event**: October 2024 shows a massive spike of 850 transactions, predominantly negative values, indicating a systematic correction effort.
3. **Continued Cleanup**: November 2024 continued the correction pattern with 389 transactions.
4. **Return to Baseline**: By December 2024, transaction volumes began normalizing.
5. **Recent Uptick**: January 2025 showed 28 transactions totaling over $31,800, with February 2025 adding 30 more transactions, indicating ongoing issues with provider assignment.

## 2. Payment Type Analysis

### Distribution by Payment Type
- **Jan-Sep 2024**: 
  - Credit Card: 75.3%
  - Cash: 11.2%
  - Check: 9.6%
  - Care Credit: 3.9%
- **Oct 2024**:
  - Income Transfer: 98.6%
  - Credit Card: 1.1%
  - Cherry: 0.3%
- **Nov 2024-Feb 2025**:
  - Income Transfer: 83.2%
  - Credit Card: 10.1%
  - Check: 3.2%
  - Patient Refund: 2.7%
  - Other: 0.8%

### Key Payment Type Observations
1. **Pre-Correction Methods**: Prior to October 2024, Credit Card payments were the predominant source of unassigned transactions.
2. **Correction Mechanism**: The correction event used Income Transfer as the payment type for reallocating unassigned payments.
3. **Post-Correction Pattern**: New unassigned transactions continued to be primarily Credit Card payments, while corrections used Income Transfer.

## 3. Transaction Amount Patterns

### Top Transaction Amounts by Frequency
- **Pre-October 2024**:
  - $50 (deposits for appointments)
  - $100-$200 (common payment sizes)
  - $1,000+ (large prepayments)
- **October 2024**:
  - $-1,950 (26 occurrences)
  - $-315 (23 occurrences)
  - $-330 (22 occurrences)
  - $-530 (21 occurrences)
  - $-1,825 (19 occurrences)

### Key Amount Observations
1. **Standardized Correction Amounts**: The October correction used standardized negative amounts, suggesting systematic transfer of specific procedure or payment categories.
2. **High-Value Corrections**: Several very large corrections (over $10,000) targeted specific patient accounts with accumulated unassigned payments.
3. **Small Balancing Transactions**: Many very small transactions (under $1) were created to completely zero out accounts.

## 4. Patient Account Patterns

### Top Patient Accounts by Transaction Volume (October 2024)
1. Kramer, Allen (39 transactions)
2. Ciesielski, Gene (35 transactions)
3. Brooks, Calvin (22 transactions)
4. Beckwith, David (21 transactions)
5. Blonski, Lawrence (21 transactions)

### Top Patient Accounts by Total Amount (October 2024)
1. Hein, Raymond (-$50,000.00)
2. Kramer, Allen (-$38,418.00)
3. Ludington, Diane (-$25,500.00)
4. Herrod, Cassandra (-$21,264.00)
5. Mauger, Thomas (-$19,500.00)

### Key Patient Account Observations
1. **Concentration Pattern**: A small number of patients accounted for a large percentage of unassigned value.
2. **Historical Accumulation**: High-value patients had accumulated unassigned payments over extended periods.
3. **VIP Patients**: Many of the largest corrections were for high-value patients with complex treatment plans.

## 5. Note Pattern Analysis

### Common Note Formats (October 2024)
1. No note (368 transactions)
2. "INCOME TRANSFER CD" (193 transactions)
3. "Income transfer. -SW" (188 transactions)
4. "income transfer. -SW" (24 transactions)
5. "Income transfer. SW" (23 transactions)

### Key Note Observations
1. **Staff Identification**: Two primary staff members (CD and SW) conducted the bulk of corrections.
2. **Inconsistent Formatting**: Minor variations in note format (capitalization, punctuation) suggest manual entry.
3. **Missing Documentation**: Many transactions had no explanatory note, reducing audit trail quality.

## 6. Temporal Patterns

### Day-of-Week Distribution
- **Pre-Correction Period**:
  - Monday/Tuesday: 42% of unassigned transactions
  - Friday: 23% of unassigned transactions
  - Weekend: <5% of unassigned transactions
- **Correction Period (Oct-Nov 2024)**:
  - Concentrated around month-end (29th-31st)
  - Tuesday and Wednesday overrepresented

### Key Temporal Observations
1. **Batch Processing**: Corrections were performed in batches, likely during dedicated administrative time.
2. **End-of-Month Focus**: Many corrections occurred at month-end, suggesting financial reporting deadlines drove correction timing.
3. **Business Hour Pattern**: Unassigned transactions originally occurred during peak business hours, suggesting time pressure as a contributing factor.

## 7. Root Cause Analysis

### Primary Contributing Factors
1. **User Interface Issues**:
   - Provider field not prominently displayed or required during payment entry
   - Different workflow paths leading to inconsistent provider assignment

2. **Training Gaps**:
   - Staff possibly unaware of financial reporting impact of unassigned providers
   - Inconsistent understanding of when provider assignment is necessary

3. **Process Design Flaws**:
   - Disconnection between clinical workflows and payment processing
   - Batch payment processing separating provider information from transaction entry

4. **System Limitations**:
   - Lack of validation preventing completion of transactions without provider
   - Missing reports to quickly identify unassigned transactions for correction

5. **Workload Factors**:
   - High transaction volume periods show increased unassigned rates
   - Credit card processing during busy periods particularly affected

## 8. Impact Analysis

### Financial Reporting Impact
- Inaccurate provider production reporting
- Distorted provider compensation calculations
- Misallocated revenue in financial statements
- Compliance risks for insurance payments

### Operational Impact
- Staff time required for corrections (estimated 40+ hours for October correction)
- Audit complexity and difficulty tracking payment history
- Patient statement confusion when transfers occur
- Management reporting reliability issues

## 9. Recommendations

### Immediate Actions
1. **Process Enhancement**:
   - Implement mandatory provider field for all payment entries
   - Create daily report of unassigned payments for immediate correction
   - Standardize note format for all transfers with required fields
   - **Prioritize the four largest transactions over $9,000 each for immediate resolution**
   - **Implement weekly unassigned provider transaction report process**

2. **Training**:
   - Conduct focused training on provider assignment importance
   - Create quick reference guide for payment entry process
   - Provide feedback to staff with high unassigned rates
   - **Target training for specific staff members (Sophie, Emily, Chelsea, Melanie) who frequently process unassigned transactions**
   - **Review the weekly unassigned provider report in staff meetings**

3. **Monitoring**:
   - Establish weekly unassigned payment report review
   - Set threshold alerts for unassigned payment spikes
   - Create dashboard for tracking unassigned payment trends
   - **Implement daily verification of all transactions over $5,000**
   - **Track weekly metrics on resolution rates and new unassigned transactions**

### Long-Term Improvements
1. **System Enhancements**:
   - Request software enhancement to prevent unassigned payments
   - Develop automated suggestions for provider assignment
   - Create validation rules for payment entry

2. **Process Redesign**:
   - Evaluate payment workflow to better integrate with clinical process
   - Consider point-of-service payment collection to ensure provider assignment
   - Implement pre-posting review step for payment batches

3. **Audit Framework**:
   - Establish quarterly audit of provider assignments
   - Create reconciliation process for unassigned payments
   - Develop training based on audit findings

## 10. Current State Analysis (March 2025)

### Latest Transaction Details
As of March 2025, there are 58 remaining unassigned provider transactions from January and February 2025 requiring attention:

#### Priority Breakdown
- **Critical**: 28 transactions (January transactions)
- **High**: 19 transactions
- **Medium**: 8 transactions
- **Low**: 3 transactions

#### Large Transactions
Four transactions represent over $40,000 in unassigned income:
- Wallace, Kolleen: $11,000.00 (Jan 21) and $9,732.00 (Feb 19) 
- Wade, William: $10,090.80 (Feb 27)
- West, William: $9,733.00 (Feb 03)

#### Staff Patterns
Staff members entering unassigned transactions:
- Sophie: 18 transactions (31%)
- Emily: 10 transactions (17%)
- Chelsea: 10 transactions (17%)
- Melanie: 9 transactions (16%)
- Dr. Kamp/Dr. Schneiss: 11 transactions (19%)

#### Transaction Notes
Notable patterns in the transaction notes:
1. Many transactions have no explanatory note (67%)
2. Transactions with notes often indicate:
   - Income transfers of credits
   - Reallocation of overpayments
   - New patient deposits
   - Phone payments

### Action Items for Current Transactions
1. **Critical Category (Next 48 Hours)**:
   - Process all four transactions over $9,000
   - Address all January transactions with ages over 45 days
   - Verify provider suggestions for Wallace, Wade, and West accounts

2. **High Category (This Week)**:
   - Process February transactions with values over $500 or ages over 20 days
   - Standardize notes for all transfers performed

3. **Medium/Low Category (Next Two Weeks)**:
   - Process remaining transactions based on provider availability
   - Document reasons for original unassigned status

4. **Prevention (Immediate Implementation)**:
   - Daily review of all new transactions to catch unassigned providers
   - Weekly reconciliation of transaction report focusing on common staff contributors

### Sustainable Monitoring Solution

A critical breakthrough has been achieved with the development of a comprehensive unassigned provider transaction report that:

1. **Provides Complete Information**: Delivers all necessary details for staff to quickly identify and resolve unassigned transactions.

2. **Implements Smart Prioritization**: Automatically categorizes transactions as Critical, High, Medium, or Low based on amount and age.

3. **Suggests Providers**: Uses patient appointment history to recommend the most likely provider for each transaction.

4. **Tracks Age and Staff**: Shows how old each transaction is and which staff member entered it, enabling targeted training.

5. **Weekly Process**: Implementing a regular Monday morning review will ensure unassigned transactions are addressed promptly rather than accumulating.

The formalized weekly report process, with clear ownership, deadlines, and metrics, transforms this from a reactive cleanup effort to a proactive maintenance process that will prevent future accumulation of unassigned transactions.

## 11. Conclusion

The analysis of unassigned provider transactions reveals a systematic issue that accumulated over time, culminating in a major correction event in October 2024. While significant progress was made during that correction period, new unassigned transactions continue to appear in the system, particularly in January and February 2025.

By implementing the recommended actions, with particular focus on the current state analysis and prioritized transactions, we anticipate reducing unassigned provider transactions by over 90% and establishing a sustainable process to prevent future accumulation.

The persistence of unassigned transactions in 2025 indicates that additional staff training and system controls are still needed to fully address the root causes identified in this analysis. 