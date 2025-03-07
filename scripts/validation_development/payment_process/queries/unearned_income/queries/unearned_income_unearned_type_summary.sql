/*
Payment Type Distribution Query
=========================

Purpose:
- Summarize statistics by payment type (UnearnedType)
- Include both regular payments (Type 0) and unearned income
- Generate aggregated metrics like count, amount, unique patients
- Calculate min, max, and average amounts by type

EXECUTION NOTE:
- This version uses UNION ALL to combine summary and detail queries into a single result set
- The combined query is optimized for export scripts
- Results can be filtered by 'payment_category' in pandas to separate summary from detail rows
- The first row shows the overall summary, followed by individual payment type breakdowns

PANDAS ANALYSIS GUIDE:
=====================================================================
This query outputs payment type distribution data that requires specific handling
in pandas for meaningful insights about payment patterns.

DATA TRANSFORMATIONS:
---------------------------------------------------------------------
- Split data into summary (rows with 'All Payment Types') and detail dataframes
- Convert monetary columns to numeric, handling formatting issues
- Convert percentage strings to numeric values
- Clean category labels to remove type numbers for better visualization
- Ensure count columns are properly formatted as integers

KEY ANALYSIS APPROACHES:
---------------------------------------------------------------------
1. Payment Distribution Analysis
   - Calculate monetary percentages alongside transaction count percentages
   - Create summary tables showing both transaction and amount distributions
   - Compare distributions to identify high-volume but low-value payment types

2. Prepayment Analysis
   - Isolate payment types with negative amounts (typically prepayments)
   - Calculate per-patient metrics and average transaction sizes
   - Analyze how prepayments affect overall payment flow

3. Patient Engagement Analysis
   - Calculate transactions per patient by payment type
   - Estimate patient overlap between different payment categories
   - Identify payment types with high patient engagement

IMPORTANT CONSIDERATIONS:
---------------------------------------------------------------------
1. Negative Values: The prepayment amounts are negative because they represent 
   previously collected funds being applied, not new revenue. When calculating 
   totals or averages, consider whether to use absolute values or maintain 
   directionality based on your analysis goals.

2. Percentage Calculations: The SQL query calculates percentages based on 
   transaction counts, but you may want to calculate percentages based on 
   monetary amounts instead, which can tell a different story.

3. Patient Overlap: Some patients appear in multiple payment type categories, 
   so summing 'unique_patients' across all types will exceed the actual total.

4. Financial Flow Analysis: This data is ideal for understanding how money 
   flows through your system - particularly how prepayments are collected in 
   one period and used in another, which can impact cash flow reporting.
=====================================================================

Date Filter: @start_date to @end_date
*/

-- Include external CTE files
<<include:unearned_income_split_summary_by_type.sql>>
<<include:unearned_income_payment_unearned_type_summary.sql>>

-- Now combine the results and sort by the explicit sort_order column and then by total_splits
SELECT 
    payment_category,
    total_splits,
    total_amount,
    avg_amount,
    unique_patients,
    regular_payment_splits,
    unearned_income_splits,
    regular_payment_amount,
    unearned_income_amount,
    percent_regular_payments,
    percent_unearned_income
FROM (
    SELECT * FROM UnearnedIncomeSplitSummaryByType
    UNION ALL
    SELECT * FROM UnearnedIncomePaymentUnearnedTypeSummary
) combined
ORDER BY sort_order, total_splits DESC; 