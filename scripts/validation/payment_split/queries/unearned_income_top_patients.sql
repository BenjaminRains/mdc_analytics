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
df_all = df_combined[df_combined['Payment Type'] == 'All Payment Types']
df_regular = df_combined[df_combined['Payment Type'] == 'Regular Payments (Type 0)']
df_unearned = df_combined[df_combined['Payment Type'] == 'Unearned Income (Type != 0)']

# 3. Data Type Conversions
for df in [df_combined, df_all, df_regular, df_unearned]:
    # Handle dates - ensure proper datetime format
    df['First Payment Date'] = pd.to_datetime(df['First Payment Date'])
    df['Last Payment Date'] = pd.to_datetime(df['Last Payment Date'])
    
    # Round monetary values to 2 decimal places
    for col in ['Total Amount', 'Regular Payment Amount', 'Unearned Income Amount']:
        df[col] = df[col].round(2)
    
    # Fix any floating point precision issues
    df['Regular Payment %'] = df['Regular Payment %'].round(2)
    
    # Add useful derived columns
    df['First Month'] = df['First Payment Date'].dt.to_period('M')
    df['Last Month'] = df['Last Payment Date'].dt.to_period('M')
    df['Months Active'] = ((df['Last Payment Date'].dt.year - df['First Payment Date'].dt.year) * 12 + 
                          (df['Last Payment Date'].dt.month - df['First Payment Date'].dt.month))
    
    # Create categorical columns for better analysis
    df['Payment Category'] = pd.cut(
        df['Regular Payment %'], 
        bins=[-0.001, 0.001, 25, 75, 99.999, 100.001], 
        labels=['All Unearned', 'Mostly Unearned', 'Mixed', 'Mostly Regular', 'All Regular']
    )
    
    df['Duration Category'] = pd.cut(
        df['Days Between First and Last'],
        bins=[-1, 0, 30, 90, 180, 365, float('inf')],
        labels=['Same Day', '1-30 Days', '1-3 Months', '3-6 Months', '6-12 Months', '12+ Months']
    )
    
    # Add transaction size metrics
    df['Avg Transaction Size'] = df['Total Amount'] / df['Transaction Count']
```

KEY ANALYSIS TECHNIQUES:
---------------------------------------------------------------------
1. Payment Pattern Analysis:
```python
# Analysis by payment type section
section_summary = df_combined.groupby('Payment Type').agg({
    'Patient Number': 'nunique',
    'Total Amount': 'sum',
    'Transaction Count': 'sum'
}).rename(columns={'Patient Number': 'Unique Patients'})

# Segmentation by payment composition
pattern_summary = df_all.groupby('Payment Category').agg({
    'Patient Number': 'count',
    'Total Amount': 'sum',
    'Transaction Count': 'sum',
}).rename(columns={'Patient Number': 'Patient Count'})

# Transaction efficiency (amount per transaction)
df_all['Amount per Transaction'] = df_all['Total Amount'] / df_all['Transaction Count']
```

2. Patient Comparison Analysis:
```python
# Find patients with both regular and unearned payments
common_patients = set(df_regular['Patient Number']) & set(df_unearned['Patient Number'])
dual_payment_df = df_all[df_all['Patient Number'].isin(common_patients)]

# Calculate additional metrics for these patients
dual_payment_df['Regular:Unearned Ratio'] = dual_payment_df['Regular Payment Amount'] / dual_payment_df['Unearned Income Amount'].replace(0, np.nan)
```

3. Temporal Analysis:
```python
# Cohort analysis by first payment month
df_all['Cohort'] = df_all['First Payment Date'].dt.to_period('M')
cohort_summary = df_all.groupby('Cohort').agg({
    'Patient Number': 'nunique',
    'Total Amount': 'sum',
    'Transaction Count': 'sum'
}).rename(columns={'Patient Number': 'Unique Patients'})

# Payment velocity (amount per day active)
df_all['Payment Velocity'] = df_all['Total Amount'] / df_all['Days Between First and Last'].replace(0, 1)
```

VISUALIZATION RECOMMENDATIONS:
---------------------------------------------------------------------
```python
# 1. Payment Composition for Top Patients
top10_patients = df_all.nlargest(10, 'Total Amount')
fig, ax = plt.subplots(figsize=(12, 6))
top10_patients.plot(
    kind='barh', 
    x='Patient Name',
    y=['Regular Payment Amount', 'Unearned Income Amount'],
    stacked=True,
    ax=ax
)
plt.title('Payment Composition for Top 10 Patients')
plt.tight_layout()

# 2. Transaction Efficiency Matrix
plt.figure(figsize=(10, 8))
sns.scatterplot(
    data=df_all,
    x='Transaction Count', 
    y='Total Amount',
    hue='Payment Category',
    size='Days Between First and Last',
    sizes=(50, 500),
    alpha=0.7
)
plt.title('Transaction Efficiency by Patient')
plt.xlabel('Number of Transactions')
plt.ylabel('Total Amount ($)')

# 3. Patient Duration and Value
df_all['Duration Days'] = df_all['Days Between First and Last']
duration_pivot = df_all.pivot_table(
    index='Duration Category',
    values=['Total Amount', 'Patient Number', 'Transaction Count'],
    aggfunc={'Total Amount': 'sum', 'Patient Number': 'count', 'Transaction Count': 'sum'}
).rename(columns={'Patient Number': 'Patient Count'})
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

Dependencies:
- CTEs: unearned_income_patient_all_payments, unearned_income_patient_regular_payments, unearned_income_patient_unearned_income
- Date Filter: @start_date to @end_date
*/

-- Set date parameters - uncomment and modify as needed
-- SET @start_date = '2024-01-01';
-- SET @end_date = '2025-02-28';

-- Main query using external CTEs
-- Combine all results and then apply the ORDER BY and LIMIT
(SELECT * FROM all_payments ORDER BY `Total Amount` DESC LIMIT 100)
UNION ALL
(SELECT * FROM regular_payments ORDER BY `Total Amount` DESC LIMIT 100)
UNION ALL
(SELECT * FROM unearned_income ORDER BY `Total Amount` DESC LIMIT 100) 