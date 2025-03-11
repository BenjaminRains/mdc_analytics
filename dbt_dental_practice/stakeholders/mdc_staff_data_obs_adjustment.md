import pandas as pd
import numpy as np
from datetime import datetime
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path

# Set up the path
base_path = Path(r"C:\Users\rains\mdc_analytics\dbt_dental_practice")
data_path = base_path / "models" / "staging" / "data_validation"

# Read the data
df_appt = pd.read_csv(data_path / "appointment_validation.csv")
df_type = pd.read_csv(data_path / "appointmenttype_validation.csv")

# Merge the dataframes
df_combined = df_appt.merge(
    df_type,
    how='left',
    left_on='appointment_type_id',
    right_on='appointment_type_id',
    suffixes=('_appt', '_type')
)

# Create comprehensive validation report
validation_results = []

# 1. Volume Metrics
validation_results.extend([
    {
        'category': 'Volume',
        'metric': 'Total Appointments',
        'value': len(df_appt),
        'percentage': '100%'
    },
    {
        'category': 'Volume',
        'metric': 'Total Appointment Types',
        'value': len(df_type),
        'percentage': '100%'
    }
])

# 2. Appointment Type Status
hidden_types = len(df_type[df_type['is_hidden'] == 1])
active_types = len(df_type[df_type['is_hidden'] == 0])
validation_results.extend([
    {
        'category': 'Type Status',
        'metric': 'Active Appointment Types',
        'value': active_types,
        'percentage': f'{active_types/len(df_type):.1%}'
    },
    {
        'category': 'Type Status',
        'metric': 'Hidden Appointment Types',
        'value': hidden_types,
        'percentage': f'{hidden_types/len(df_type):.1%}'
    }
])

# 3. Pattern Analysis
empty_patterns = len(df_type[df_type['time_pattern'].isnull()])
validation_results.extend([
    {
        'category': 'Patterns',
        'metric': 'Types Without Patterns',
        'value': empty_patterns,
        'percentage': f'{empty_patterns/len(df_type):.1%}'
    },
    {
        'category': 'Patterns',
        'metric': 'Duration Pattern Mismatches',
        'value': len(df_combined[df_combined['duration_minutes_appt'] != df_combined['duration_minutes_type']]),
        'percentage': f'{len(df_combined[df_combined["duration_minutes_appt"] != df_combined["duration_minutes_type"]])/len(df_combined):.1%}'
    }
])

# 4. Usage Analysis
hidden_usage = len(df_combined[df_combined['is_hidden'] == 1])
validation_results.extend([
    {
        'category': 'Usage',
        'metric': 'Appointments Using Hidden Types',
        'value': hidden_usage,
        'percentage': f'{hidden_usage/len(df_combined):.1%}'
    },
    {
        'category': 'Usage',
        'metric': 'Appointments Without Type',
        'value': len(df_combined[df_combined['type_name'].isnull()]),
        'percentage': f'{len(df_combined[df_combined["type_name"].isnull()])/len(df_combined):.1%}'
    }
])

# 5. Procedure Analysis
validation_results.extend([
    {
        'category': 'Procedures',
        'metric': 'Types with Required Procedures',
        'value': len(df_type[df_type['required_procedure_codes'].notna()]),
        'percentage': f'{len(df_type[df_type["required_procedure_codes"].notna()])/len(df_type):.1%}'
    },
    {
        'category': 'Procedures',
        'metric': 'Types with Blockout Constraints',
        'value': len(df_type[df_type['blockout_type_list'].notna()]),
        'percentage': f'{len(df_type[df_type["blockout_type_list"].notna()])/len(df_type):.1%}'
    }
])

# 6. Most Used Types (Top 5)
top_types = df_combined.groupby('type_name')['appointment_id'].count().sort_values(ascending=False).head()
for type_name, count in top_types.items():
    validation_results.append({
        'category': 'Top Types',
        'metric': f'Usage: {type_name}',
        'value': count,
        'percentage': f'{count/len(df_combined):.1%}'
    })

# Create DataFrame and save report
validation_df = pd.DataFrame(validation_results)
output_path = data_path / "appointment_validation_report.csv"
validation_df.to_csv(output_path, index=False)
print("\n=== Validation Report ===")
print(validation_df.to_string())
print(f"\nValidation report has been saved to {output_path}")

# Generate visualizations
plt.figure(figsize=(15, 10))

# 1. Appointment Type Usage
plt.subplot(2, 2, 1)
top_types.plot(kind='bar')
plt.title('Top 5 Appointment Types by Usage')
plt.xticks(rotation=45, ha='right')

# 2. Duration Distribution
plt.subplot(2, 2, 2)
sns.histplot(data=df_combined, x='duration_minutes_appt')
plt.title('Appointment Duration Distribution')

# 3. Pattern Components
plt.subplot(2, 2, 3)
df_type['work_blocks'] = df_type['time_pattern'].str.count('X')
df_type['break_blocks'] = df_type['time_pattern'].str.count('/')
sns.scatterplot(data=df_type[df_type['is_hidden'] == 0], 
                x='work_blocks', 
                y='break_blocks',
                s=100)
plt.title('Work vs Break Blocks in Patterns')

# 4. Hidden vs Active Usage
plt.subplot(2, 2, 4)
hidden_status = df_combined['is_hidden'].value_counts()
plt.pie(hidden_status, labels=['Active', 'Hidden'], autopct='%1.1f%%')
plt.title('Appointments by Type Status')

plt.tight_layout()
plt.savefig(data_path / "appointment_validation_charts.png")
plt.close()

print(f"Visualization saved to {data_path / 'appointment_validation_charts.png'}")