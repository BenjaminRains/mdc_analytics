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
- Results can be filtered by 'Payment Category' in pandas to separate summary from detail rows
- The first row shows the overall summary, followed by individual payment type breakdowns

PANDAS ANALYSIS GUIDE:
=====================================================================
This payment type distribution data requires specific handling in pandas
to extract meaningful insights about payment patterns.

DATA LOADING & TRANSFORMATIONS:
---------------------------------------------------------------------
```python
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

# Load the unified query results
df_combined = pd.read_csv('payment_distribution.csv')

# Split into summary and detail dataframes
df_summary = df_combined[df_combined['Payment Category'] == 'All Payment Types']
df_by_type = df_combined[df_combined['Payment Category'] != 'All Payment Types']

# Data Type Transformations
for df in [df_combined, df_summary, df_by_type]:
    # Convert monetary columns to numeric, handling potential formatting issues
    for col in ['Total Amount', 'Avg Amount', 'Regular Payment Amount', 'Unearned Income Amount']:
        df[col] = pd.to_numeric(df[col], errors='coerce')
    
    # Convert percentage strings to numeric values
    for col in ['% Regular Payments', '% Unearned Income']:
        if col in df.columns:
            # Remove % symbol if present and convert to numeric
            df[col] = df[col].astype(str).str.replace('%', '').astype(float)
    
    # Ensure count columns are integers
    for col in ['Total Splits', 'Regular Payment Splits', 'Unearned Income Splits', 'Unique Patients']:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors='coerce').fillna(0).astype(int)

# Create clean category labels for plotting
if 'Payment Category' in df_by_type.columns:
    df_by_type['Category Label'] = df_by_type['Payment Category'].str.replace(r' \(Type \d+\)', '', regex=True)
```

KEY ANALYSIS APPROACHES:
---------------------------------------------------------------------
1. Payment Distribution Analysis
```python
# Calculate actual monetary percentages (different from transaction count percentages)
total_amount = df_summary['Total Amount'].iloc[0]
df_by_type['Amount Percentage'] = (df_by_type['Total Amount'] / total_amount * 100).round(1)

# Create a summary table with both transaction and amount percentages
payment_distribution = pd.DataFrame({
    'Payment Type': df_by_type['Category Label'],
    'Transaction Count': df_by_type['Total Splits'],
    'Transaction %': (df_by_type['Total Splits'] / df_by_type['Total Splits'].sum() * 100).round(1),
    'Amount': df_by_type['Total Amount'],
    'Amount %': df_by_type['Amount Percentage']
})
```

2. Prepayment Analysis (Critical for Understanding Negative Values)
```python
# Isolate prepayment types and analyze their patterns
prepayment_df = df_by_type[df_by_type['Total Amount'] < 0]

# Calculate per-patient metrics
if len(prepayment_df) > 0:
    prepayment_df['Avg Per Patient'] = prepayment_df['Total Amount'] / prepayment_df['Unique Patients']
    
    # Estimate average prepayment application size
    prepayment_df['Avg Transaction Size'] = prepayment_df['Total Amount'] / prepayment_df['Total Splits']
```

3. Patient Engagement Analysis
```python
# Calculate transactions per patient by payment type
df_by_type['Transactions per Patient'] = df_by_type['Total Splits'] / df_by_type['Unique Patients']

# Estimate overlap between patient groups
total_patients = df_summary['Unique Patients'].iloc[0]
sum_of_patients_by_type = df_by_type['Unique Patients'].sum()
patient_overlap = sum_of_patients_by_type - total_patients
overlap_percentage = (patient_overlap / total_patients * 100).round(1)

print(f"Estimated patients with multiple payment types: {overlap_percentage}%")
```

VISUALIZATION RECOMMENDATIONS:
---------------------------------------------------------------------
```python
# 1. Payment Type Distribution - Transaction Count vs Amount
fig, ax = plt.subplots(1, 2, figsize=(15, 6))

# Transaction count distribution
df_by_type.plot(
    kind='pie', 
    y='Total Splits',
    labels=df_by_type['Category Label'],
    autopct='%1.1f%%',
    ax=ax[0]
)
ax[0].set_title('Transaction Count Distribution')
ax[0].set_ylabel('')

# Amount distribution (with special handling for negative values)
colors = ['green' if x >= 0 else 'red' for x in df_by_type['Total Amount']]
df_by_type.plot(
    kind='bar',
    x='Category Label',
    y='Total Amount',
    ax=ax[1],
    color=colors
)
ax[1].set_title('Total Amount by Payment Type')
ax[1].axhline(y=0, color='black', linestyle='-', alpha=0.3)

plt.tight_layout()

# 2. Average Transaction Size Analysis
plt.figure(figsize=(10, 6))
sns.barplot(
    data=df_by_type,
    x='Category Label',
    y='Avg Amount'
)
plt.title('Average Amount per Transaction by Payment Type')
plt.axhline(y=0, color='black', linestyle='-', alpha=0.3)
plt.xticks(rotation=45)
plt.tight_layout()

# 3. Patient Engagement by Payment Type
plt.figure(figsize=(10, 6))
sns.barplot(
    data=df_by_type,
    x='Category Label',
    y='Transactions per Patient'
)
plt.title('Average Transactions per Patient by Payment Type')
plt.xticks(rotation=45)
plt.tight_layout()
```

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
   so summing 'Unique Patients' across all types will exceed the actual total.

4. Financial Flow Analysis: This data is ideal for understanding how money 
   flows through your system - particularly how prepayments are collected in 
   one period and used in another, which can impact cash flow reporting.
=====================================================================

Dependencies:
- CTEs: unearned_income_split_summary_by_type, unearned_income_payment_unearned_type_summary  

Date Filter: @start_date to @end_date
*/

-- Set date parameters - uncomment and modify as needed
-- SET @start_date = '2024-01-01';
-- SET @end_date = '2025-02-28';

-- Include external CTE files
<<include:ctes/unearned_income_split_summary_by_type.sql>>
<<include:ctes/unearned_income_payment_unearned_type_summary.sql>>

-- Now combine the results and sort by the explicit sort_order column and then by Total Splits
SELECT 
    `Payment Category`,
    `Total Splits`,
    `Total Amount`,
    `Avg Amount`,
    `Unique Patients`,
    `Regular Payment Splits`,
    `Unearned Income Splits`,
    `Regular Payment Amount`,
    `Unearned Income Amount`,
    `% Regular Payments`,
    `% Unearned Income`
FROM (
    SELECT * FROM unearned_income_split_summary_by_type
    UNION ALL
    SELECT * FROM unearned_income_payment_unearned_type_summary
) combined
ORDER BY sort_order, `Total Splits` DESC; 