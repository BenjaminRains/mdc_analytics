# Unearned Income Report

## Overview

The Unearned Income Report is designed to track and analyze payments that have not yet been allocated to specific procedures or providers. In OpenDental, these are represented by non-zero UnearnedType values in the paysplit table. This report provides comprehensive insights into prepayments, treatment plan deposits, and other forms of unearned income.

## Business Context

Unearned income represents money received by the practice that has not yet been "earned" by providing dental services. In OpenDental, these are represented by **non-zero** UnearnedType values in the paysplit table:

- **Prepayments** (UnearnedType = 288): Payments received before procedures are performed (0.67% of splits)
- **Treatment Plan Prepayments** (UnearnedType = 439): Deposits specifically for treatment plans (0.02% of splits)
- **Other Unearned Types**: Any other non-zero UnearnedType values defined in the definition table

**IMPORTANT**: UnearnedType = 0 (99.31% of splits) is NOT classified as unearned income in OpenDental. It is the default payment type and does not appear in the definition table. Only payments with UnearnedType > 0 should be considered true unearned income for analysis purposes.

As confirmed in the OpenDental manual:
1. The UnearnedType field is specifically used to "designate a split as Unearned/Prepayment"
2. Regular payments (Type 0) are handled differently from unearned income in the system
3. Income transfers can move unallocated income to unearned types, but this is an explicit process
4. The OpenDental UI only shows unearned types (288, 439) in unearned income reports and totals

Tracking unearned income is critical for:
1. Accurate financial reporting
2. Revenue recognition compliance
3. Patient account management
4. Cash flow analysis
5. Identifying funds that may need to be applied to procedures

## Technical Implementation of UnearnedType in OpenDental

The `UnearnedType` field in the paysplit table serves as a classification mechanism with these key behaviors:

1. **Default Behavior**: When no special designation is needed, UnearnedType = 0 is used (regular income)

2. **Unallocated Payments**: If there is no procedure attached to a paysplit, it "defaults to the type set in Preferences, _Default unearned type for unallocated paysplits_" 

3. **Income Allocation Process**: 
   - UnearnedType values appear when creating manual payment splits in the Payment window
   - When allocating unearned income to procedures, the system creates negative splits with the unearned type and positive splits attached to procedures
   - The Income Transfer Manager can move unallocated payments to the default unearned type

4. **Allocation Rules**:
   - When UnearnedType > 0, the payment appears in the "Unearned" total in the Account module
   - Users can hover over this total to see a breakdown by unearned type
   - Allocations try to match provider, patient, and clinic combinations when redistributing funds

5. **Database Representation**:
   - UnearnedType values are stored as DefNum references to the definition table
   - Type 0 does not exist in the definition table because it's the system default
   - Types 288 and 439 are specifically defined under Category 29 in the definition table

## Report Components

The report consists of several queries that provide different perspectives on unearned income:

### 1. Main Transaction Report

Provides a detailed view of each unearned income transaction with:
- Payment date
- Patient information
- Payment type
- Unearned type
- Split amount
- Category classification
- Payment notes
- Provider information
- Estimated balance at payment date
- Current balance

### 2. Patient Balance Report

Summarizes unearned income by patient with:
- Breakdown by unearned type (Prepayment, Treatment Plan Prepayment, Other)
- Total unearned amount
- Earned amount
- Total balance
- Last payment date
- Days since last payment
- Transaction count

### 3. Summary Statistics

Provides aggregate metrics by:
- Unearned type (with min, max, and average amounts)
- Payment type
- Monthly trends
- Age buckets

### 4. Specialized Reports

Includes targeted analyses for:
- Negative prepayments (potential refunds)
- Top patients with unearned income
- Aging analysis of unearned income
- Credits on accounts

## Technical Implementation

The report is implemented through two main components:
1. A SQL query (`unearned_income_report.sql`) that extracts and processes the data
2. A Jupyter notebook (`unearned_income_analysis.ipynb`) that provides additional analysis and visualizations

### SQL Query Implementation

The `unearned_income_report.sql` script incorporates several optimization techniques:

- **Temporary Tables**: Uses temporary tables like `temp_patient_balances` and `temp_transaction_counts` to improve query performance and organize data
- **Case Statements**: Employs case statements for accurate categorization of unearned income types
- **Date Parameterization**: Allows flexible date range specification with `@FromDate` and `@ToDate` parameters
- **Optimized Joins**: Carefully structured joins to ensure correct relationships while maintaining performance

The query accesses the following tables:
- `paysplit`: Primary source of unearned income data
- `payment`: Payment information
- `patient`: Patient demographics
- `definition`: Lookup values for UnearnedType and PayType
- `PatientBalances`: Current account balances

Key fields in the query:
- `ps.UnearnedType`: Identifies the type of unearned income
- `ps.SplitAmt`: The monetary value of the split
- `ps.DatePay`: When the payment was received
- `ps.PatNum`: Links to patient information
- `ps.ProvNum`: Identifies the provider (0 indicates unallocated)
- `ps.ProcNum`: Identifies the procedure (0 indicates unallocated)

The query produces multiple result sets that can be exported to CSV files for further analysis.

### Jupyter Notebook Analysis

The `unearned_income_analysis.ipynb` notebook provides interactive data exploration and visualization of the exported CSV data. The notebook:

1. **Imports and processes** the CSV files exported from the SQL query
2. **Identifies accounts with unallocated credits** (funds with ProvNum = 0 or ProcNum = 0)
3. **Generates visualizations** to analyze patterns in unearned income:
   - Time series analysis of monthly credit amounts
   - Bar charts of top guarantors by credit amount
   - Distribution analysis of credit amounts
   - Credit amount by adjustment type
   - Credit amount vs. current balance
   - Distribution of credits by transaction count

Key findings from the analysis include:
- 168 guarantors with unallocated credits totaling $65,299.65
- Average credit of $388.69 per guarantor (median of $37.20)
- Significant concentration in a few high-value accounts
- Prepayments represent 94% of unallocated credits
- Most credits occur in accounts with 10-20 transactions
- Specific months (July and November 2024) show unusually high credit activity

## How to Use This Report

### Setting Parameters

At the top of the query, set the date range parameters:
```sql
SET @FromDate = '2024-01-01';
SET @ToDate = '2024-12-31';
```

### Running the Report

1. **Execute the SQL query**:
   - Run the `unearned_income_report.sql` script in your database management tool (e.g., DBeaver)
   - The report consists of multiple queries that should be run sequentially
   - Export the result sets to CSV files

2. **Run the Jupyter notebook analysis**:
   - Open the `unearned_income_analysis.ipynb` notebook
   - Update the file paths to point to your exported CSV files
   - Run all cells to generate the analysis and visualizations

### Interpreting Results

1. **Main Transaction Report**: Review individual unearned income transactions to understand the details of each payment.

2. **Patient Balance Report**: Identify patients with significant unearned income balances who may need follow-up.

3. **Summary Statistics**: Analyze patterns in unearned income by type, payment method, and time period.

4. **Aging Analysis**: Identify old unearned income that might need attention or reclassification.

5. **Negative Prepayments**: Investigate potential refunds or adjustments to understand why they were processed as unearned income.

6. **Visualizations**: Use the generated charts to:
   - Identify trends over time
   - Spot top accounts needing attention
   - Understand the distribution of credit amounts
   - Analyze the relationship between credits and patient balances

## Credit Analysis Insights

The notebook analysis revealed several key insights about unallocated credits:

1. **Temporal Patterns**: Credits show seasonal variations with peaks in July and November.

2. **Distribution Characteristics**: Credits are heavily skewed - most guarantors have small credits while a few have very large amounts.

3. **Account Concentration**: The top 15 guarantors account for a disproportionate share of the total credits.

4. **Transaction Frequency**: Accounts with 10-20 transactions show the highest total credit amounts, suggesting a correlation between transaction frequency and unallocated funds.

5. **Credit vs. Balance Relationship**: There's no strong correlation between account balance and credit amount, indicating credits accumulate independently of overall account status.

## Prepayment Allocation Recommendations

Based on the analysis, the following recommendations have been developed:

1. **Update Intake Processes**: Capture allocation intent at collection and create standardized documentation.

2. **Establish Staff Protocols**: Implement daily reconciliation processes and clear role-based responsibilities.

3. **Implement Technical Solutions**: Configure alerts, reports, and automated processes to identify unallocated funds.

4. **Create a Formal Allocation Workflow**: Establish a structured process from initial collection through resolution.

5. **Resolve Existing Credits**: Prioritize accounts and establish documentation requirements.

6. **Establish Ongoing Monitoring**: Track key performance indicators and conduct regular review meetings.

7. **Implement Safeguards for Special Cases**: Create procedures for insurance overpayments, treatment plan changes, and patient refunds.

A detailed implementation plan has been developed, with an expected 80% reduction in unallocated prepayments within 3 months.

## Common Use Cases

1. **Month-End Financial Reconciliation**: Track total unearned income for accurate financial reporting.

2. **Patient Account Management**: Identify patients with prepayments that need to be applied to procedures.

3. **Revenue Recognition**: Ensure proper accounting of unearned vs. earned income.

4. **Audit Preparation**: Provide detailed documentation of unearned income transactions.

5. **Cash Flow Analysis**: Understand the impact of prepayments on practice cash flow.

## Validation Considerations

When analyzing unearned income, consider:

1. **Negative Values**: May indicate refunds or adjustments that need investigation.

2. **Very Old Prepayments**: May need to be addressed according to practice policy or state regulations regarding unclaimed property.

3. **Large Amounts**: Verify that large prepayments are legitimate and properly documented.

4. **Missing Provider Assignments**: Unassigned providers may indicate incomplete transaction records.

## Troubleshooting

Common issues and solutions:

1. **Performance**: If the query runs slowly, consider narrowing the date range or adding appropriate indexes.

2. **Missing Data**: Ensure that all referenced tables (paysplit, payment, patient, definition) are properly joined.

3. **Balance Calculation**: The estimated balance calculations use cumulative sums which may be resource-intensive on large datasets.

4. **Visualization Issues**: If the notebook visualizations fail, check for:
   - Column naming mismatches between CSV files and notebook code
   - Date format inconsistencies
   - Missing data in critical columns

## Future Enhancements

Potential improvements to consider:

1. **Procedure Linkage**: Add information about planned procedures associated with prepayments.

2. **Insurance Integration**: Include insurance information for prepayments related to insurance claims.

3. **Automated Alerts**: Develop alerts for old prepayments that need attention.

4. **Historical Trending**: Add year-over-year comparison of unearned income patterns.

5. **Predictive Analytics**: Develop models to identify patients likely to have allocation issues.

6. **Integration with Practice Management**: Create direct links to the practice management system for easier allocation.

7. **Credit Allocation Wizard**: Develop an interactive tool to guide staff through the allocation process.

## Related Reports

This report complements other financial analyses:

1. **Payment Split Validation**: General validation of payment splits
2. **Income Production Report**: Overall practice income analysis
3. **Adjustment Analysis Report**: Analysis of adjustments to patient accounts
4. **AR Totals Report**: Accounts receivable analysis 