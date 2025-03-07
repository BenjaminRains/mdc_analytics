/*
Top Patients Payment Analysis Query
====================================

Purpose:
- Identify top patients by both regular payments and unearned income
- Shows distribution between regular payments and unearned income
- Shows transaction count, total amount, and date range for each patient
- Useful for auditing large payments or unusual patient balances

PANDAS ANALYSIS GUIDE:
=====================================================================
The SQL query focuses on basic aggregation, while deeper analysis should happen in pandas.
This guide outlines the recommended approach for analysis.

DATA LOADING & TRANSFORMATION:
---------------------------------------------------------------------
```python
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from datetime import datetime

# 1. Load the single result set from the export
df_combined = pd.read_csv('top_patients_combined.csv')

# 2. Split into component dataframes if needed for separate analysis
df_all = df_combined[df_combined['payment_type'] == 'All Payment Types']
df_regular = df_combined[df_combined['payment_type'] == 'Regular Payments (Type 0)']
df_unearned = df_combined[df_combined['payment_type'] == 'Unearned Income (Type != 0)']

# 3. Data Type Conversions
for df in [df_combined, df_all, df_regular, df_unearned]:
    # Handle dates - ensure proper datetime format
    df['first_payment_date'] = pd.to_datetime(df['first_payment_date'])
    df['last_payment_date'] = pd.to_datetime(df['last_payment_date'])
    
    # Round monetary values to 2 decimal places
    for col in ['total_amount', 'regular_payment_amount', 'unearned_income_amount']:
        df[col] = df[col].round(2)
    
    # Fix any floating point precision issues
    df['regular_payment_percent'] = df['regular_payment_percent'].round(2)
    
    # Add useful derived columns
    df['first_month'] = df['first_payment_date'].dt.to_period('M')
    df['last_month'] = df['last_payment_date'].dt.to_period('M')
    df['months_active'] = ((df['last_payment_date'].dt.year - df['first_payment_date'].dt.year) * 12 + 
                          (df['last_payment_date'].dt.month - df['first_payment_date'].dt.month))
    
    # Create categorical columns for better analysis
    df['payment_category'] = pd.cut(
        df['regular_payment_percent'], 
        bins=[-0.001, 0.001, 25, 75, 99.999, 100.001], 
        labels=['All Unearned', 'Mostly Unearned', 'Mixed', 'Mostly Regular', 'All Regular']
    )
    
    df['duration_category'] = pd.cut(
        df['days_between_first_and_last'],
        bins=[-1, 0, 30, 90, 180, 365, float('inf')],
        labels=['Same Day', '1-30 Days', '1-3 Months', '3-6 Months', '6-12 Months', '12+ Months']
    )
    
    # Add transaction size metrics
    df['avg_transaction_size'] = df['total_amount'] / df['transaction_count']
```

KEY ANALYSIS TECHNIQUES:
---------------------------------------------------------------------
1. Payment Pattern Analysis:
```python
# Analysis by payment type section
section_summary = df_combined.groupby('payment_type').agg({
    'patient_number': 'nunique',
    'total_amount': 'sum',
    'transaction_count': 'sum'
}).rename(columns={'patient_number': 'unique_patients'})

# Segmentation by payment composition
pattern_summary = df_all.groupby('payment_category').agg({
    'patient_number': 'count',
    'total_amount': 'sum',
    'transaction_count': 'sum',
}).rename(columns={'patient_number': 'patient_count'})

# Transaction efficiency (amount per transaction)
df_all['amount_per_transaction'] = df_all['total_amount'] / df_all['transaction_count']
```

2. Patient Comparison Analysis:
```python
# Find patients with both regular and unearned payments
common_patients = set(df_regular['patient_number']) & set(df_unearned['patient_number'])
dual_payment_df = df_all[df_all['patient_number'].isin(common_patients)]

# Calculate additional metrics for these patients
dual_payment_df['regular_unearned_ratio'] = dual_payment_df['regular_payment_amount'] / dual_payment_df['unearned_income_amount'].replace(0, np.nan)
```

3. Temporal Analysis:
```python
# Cohort analysis by first payment month
df_all['cohort'] = df_all['first_payment_date'].dt.to_period('M')
cohort_summary = df_all.groupby('cohort').agg({
    'patient_number': 'nunique',
    'total_amount': 'sum',
    'transaction_count': 'sum'
}).rename(columns={'patient_number': 'unique_patients'})

# Payment velocity (amount per day active)
df_all['payment_velocity'] = df_all['total_amount'] / df_all['days_between_first_and_last'].replace(0, 1)
```

VISUALIZATION RECOMMENDATIONS:
---------------------------------------------------------------------
```python
# 1. Payment Composition for Top Patients
top10_patients = df_all.nlargest(10, 'total_amount')
fig, ax = plt.subplots(figsize=(12, 6))
top10_patients.plot(
    kind='barh', 
    x='patient_name',
    y=['regular_payment_amount', 'unearned_income_amount'],
    stacked=True,
    ax=ax
)
plt.title('Payment Composition for Top 10 Patients')
plt.tight_layout()

# 2. Transaction Efficiency Matrix
plt.figure(figsize=(10, 8))
sns.scatterplot(
    data=df_all,
    x='transaction_count', 
    y='total_amount',
    hue='payment_category',
    size='days_between_first_and_last',
    sizes=(50, 500),
    alpha=0.7
)
plt.title('Transaction Efficiency by Patient')
plt.xlabel('Number of Transactions')
plt.ylabel('Total Amount ($)')

# 3. Patient Duration and Value
df_all['duration_days'] = df_all['days_between_first_and_last']
duration_pivot = df_all.pivot_table(
    index='duration_category',
    values=['total_amount', 'patient_number', 'transaction_count'],
    aggfunc={'total_amount': 'sum', 'patient_number': 'count', 'transaction_count': 'sum'}
).rename(columns={'patient_number': 'patient_count'})
```

POTENTIAL ISSUES TO WATCH FOR:
---------------------------------------------------------------------
- Floating point precision issues in percentage calculations
- Division by zero when calculating ratios (use .replace(0, np.nan) before division)
- Outliers skewing averages - consider median values for better central tendency
- Zero-day duration patients (transactions on same day) affecting time-based analyses
- Extreme transaction counts may indicate data anomalies worth investigating

Additional Note: This query only returns the top 20 patients in each category - for 
complete analysis, you may want to modify the query to return all patients or a larger
subset.
=====================================================================

- Date Filter: @start_date to @end_date variables
*/

-- Include dependent CTEs
<<include:unearned_income_patient_all_payments.sql>>
<<include:unearned_income_patient_regular_payments.sql>>
<<include:unearned_income_patient_unearned_income.sql>>

-- Main query using external CTEs
-- Combine all results and then apply the ORDER BY and LIMIT
(SELECT * FROM UnearnedIncomePatientAllPayments ORDER BY total_amount DESC LIMIT 100)
UNION ALL
(SELECT * FROM UnearnedIncomePatientRegularPayments ORDER BY total_amount DESC LIMIT 100)
UNION ALL
(SELECT * FROM UnearnedIncomePatientUnearnedIncome ORDER BY total_amount DESC LIMIT 100) 