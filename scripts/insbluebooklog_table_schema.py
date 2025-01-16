import pandas as pd
import os

# Define the insbluebooklog table schema information with primary and foreign keys
insbluebooklog_data = {
    "Column Name": [
        "InsBlueBookLogNum", "ClaimProcNum", "AllowedFee", "DateTEntry", "Description"
    ],
    "Data Type": [
        "bigint(20)", "bigint(20)", "double", "datetime", "text"
    ],
    "Default Value": [
        "AUTO_INCREMENT", "NOT NULL", "NOT NULL", "'0001-01-01 00:00:00'", "NOT NULL"
    ],
    "Key Type": [
        "PRIMARY KEY", "FOREIGN KEY", "NONE", "NONE", "NONE"
    ],
    "References": [
        "Self", "ClaimProc(ClaimProcNum)", "None", "None", "None"
    ]
}

# Create DataFrame
df_insbluebooklog = pd.DataFrame(insbluebooklog_data)

# Get project root and set output path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
file_path_insbluebooklog = os.path.join(project_root, "docs", "insbluebooklog_table_schema_with_keys.csv")

# Save the DataFrame to CSV
df_insbluebooklog.to_csv(file_path_insbluebooklog, index=False) 