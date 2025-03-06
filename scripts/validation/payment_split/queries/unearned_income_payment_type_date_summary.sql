/*
Payment Type Date Summary Query
========================

Purpose:
- Combines payment type and date analysis in one comprehensive view
- Shows payment type distribution by month for trend analysis
- Includes regular vs unearned income breakdown

Analysis Guide:
------------------------
This query produces a single result set with three sections (identified by the 'Section' column):
'All Payment Types', 'Regular Payments', and 'Unearned Income'.

Key Analysis Steps:
1. Filter by Section for focused analysis (e.g., df[df['Section']=='All Payment Types'])
2. Convert 'Payment Month' to datetime: df['Date'] = pd.to_datetime(df['Payment Month'] + '-01')
3. Analyze payment methods over time using pivot tables
4. Compare regular vs unearned payment patterns
5. Visualize with stacked charts to show payment composition changes

Sample Code:
```python
# Essential transformations
df['Date'] = pd.to_datetime(df['Payment Month'] + '-01')
df_all = df[df['Section'] == 'All Payment Types']

# Payment method trend analysis
method_trend = df_all.pivot_table(
    values='Total Amount', 
    index='Date',
    columns='Payment Type',
    aggfunc='sum'
)

# Regular vs Unearned composition
composition = df_all.groupby('Date').agg({
    'Regular Payment Amount': 'sum',
    'Unearned Income Amount': 'sum'
})
```

Notes:
- Credit cards typically dominate transaction volume
- Income Transfer transactions typically net to zero but show money movement
- Watch for negative values in refunds that may impact analysis

Dependencies: CTEs: unearned_income_all_payment_types, unearned_income_regular_payments, unearned_income_unearned_payments
Date Filter: @start_date to @end_date
*/

-- Set date parameters - uncomment and modify as needed for dbeaver
-- SET @start_date = '2024-01-01';
-- SET @end_date = '2025-02-28';

-- Main query combining results from all CTEs
-- Combine all CTEs into a single result set
SELECT * FROM all_payment_types
UNION ALL
SELECT * FROM regular_payments
UNION ALL
SELECT * FROM unearned_income
ORDER BY `Section`, `Payment Month`, `Total Amount` DESC 