import pandas as pd
import os

# Define the perioexam table schema information with primary and foreign keys
perioexam_data = {
    "Column Name": [
        "PerioExamNum", "PatNum", "ExamDate", "ProvNum", "DateTMeasureEdit", "Note"
    ],
    "Data Type": [
        "bigint(20)", "bigint(20)", "date", "bigint(20)", "datetime", "text"
    ],
    "Default Value": [
        "AUTO_INCREMENT", "NOT NULL", "'0001-01-01'", "NOT NULL", "'0001-01-01 00:00:00'", "NOT NULL"
    ],
    "Key Type": [
        "PRIMARY KEY", "FOREIGN KEY", "NONE", "FOREIGN KEY", "NONE", "NONE"
    ],
    "References": [
        "Self", "Patient(PatNum)", "None", "Provider(ProvNum)", "None", "None"
    ]
}

# Find the maximum length of lists in the dictionary
max_length = max(len(lst) for lst in perioexam_data.values())

# Ensure all lists are of equal length by padding with None
for key in perioexam_data:
    current_length = len(perioexam_data[key])
    if current_length < max_length:
        perioexam_data[key].extend([None] * (max_length - current_length))

# Create DataFrame
df_perioexam = pd.DataFrame(perioexam_data)

# Get project root and set output path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
file_path_perioexam = os.path.join(project_root, "docs", "perioexam_table_schema_with_keys.csv")

# Save the DataFrame to CSV
df_perioexam.to_csv(file_path_perioexam, index=False) 