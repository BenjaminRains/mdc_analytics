/*
Payment Type Date Summary Query
========================

Purpose:
- Combines payment type and date analysis in one comprehensive view
- Shows payment type distribution by month for trend analysis
- Includes regular vs unearned income breakdown

Analysis Guide:
------------------------
This query produces a single result set with three sections (identified by the 'section' column):
'All Payment Types', 'Regular Payments', and 'Unearned Income'.

Key Analysis Steps:
1. Filter by Section for focused analysis (e.g., df[df['section']=='All Payment Types'])
2. Convert 'payment_month' to datetime: df['date'] = pd.to_datetime(df['payment_month'] + '-01')
3. Analyze payment methods over time using pivot tables
4. Compare regular vs unearned payment patterns
5. Visualize with stacked charts to show payment composition changes

Sample Code:
```python
# Essential transformations
df['date'] = pd.to_datetime(df['payment_month'] + '-01')
df_all = df[df['section'] == 'All Payment Types']

# Payment method trend analysis
method_trend = df_all.pivot_table(
    values='total_amount', 
    index='date',
    columns='payment_type',
    aggfunc='sum'
)

# Regular vs Unearned composition
composition = df_all.groupby('date').agg({
    'regular_payment_amount': 'sum',
    'unearned_income_amount': 'sum'
})
```

Notes:
- Credit cards typically dominate transaction volume
- Income Transfer transactions typically net to zero but show money movement
- Watch for negative values in refunds that may impact analysis

Date Filter: @start_date to @end_date variables
*/

-- Include dependent CTEs
<<include:unearned_income_all_payment_types.sql>>
<<include:unearned_income_regular_payments.sql>>
<<include:unearned_income_unearned_payments.sql>>

SELECT * FROM UnearnedIncomeAllPaymentTypes
UNION ALL
SELECT * FROM UnearnedIncomeRegularPayments
UNION ALL
SELECT * FROM UnearnedIncomeUnearnedPayments
ORDER BY section, payment_month, total_amount DESC 