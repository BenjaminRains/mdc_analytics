import pandas as pd
import os

# Define the periomeasure table schema information with primary and foreign keys
periomeasure_data = {
    "Column Name": [
        "PerioMeasureNum", "PerioExamNum", "SequenceType", "IntTooth", "ToothValue",
        "MBvalue", "Bvalue", "DBvalue", "MLvalue", "Lvalue", "DLvalue",
        "SecDateTEntry", "SecDateTEdit"
    ],
    "Data Type": [
        "bigint(20)", "bigint(20)", "tinyint(3) unsigned", "smallint(6)", "smallint(6)",
        "smallint(6)", "smallint(6)", "smallint(6)", "smallint(6)", "smallint(6)", 
        "smallint(6)", "datetime", "timestamp"
    ],
    "Default Value": [
        "AUTO_INCREMENT", "NOT NULL", "'0'", "NOT NULL", "NOT NULL",
        "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL",
        "'0001-01-01 00:00:00'", "CURRENT_TIMESTAMP"
    ],
    "Key Type": [
        "PRIMARY KEY", "FOREIGN KEY", "NONE", "NONE", "NONE",
        "NONE", "NONE", "NONE", "NONE", "NONE", "NONE",
        "INDEX", "INDEX"
    ],
    "References": [
        "Self", "PerioExam(PerioExamNum)", "None", "None", "None",
        "None", "None", "None", "None", "None", "None",
        "None", "None"
    ]
}

# Find the maximum length of lists in the dictionary
max_length = max(len(lst) for lst in periomeasure_data.values())

# Ensure all lists are of equal length by padding with None
for key in periomeasure_data:
    current_length = len(periomeasure_data[key])
    if current_length < max_length:
        periomeasure_data[key].extend([None] * (max_length - current_length))

# Create DataFrame
df_periomeasure = pd.DataFrame(periomeasure_data)

# Get project root and set output path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
file_path_periomeasure = os.path.join(project_root, "docs", "periomeasure_table_schema_with_keys.csv")

# Save the DataFrame to CSV
df_periomeasure.to_csv(file_path_periomeasure, index=False) 