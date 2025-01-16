import pandas as pd
import os

# Define the procnote table schema information with primary and foreign keys
procnote_data = {
    "Column Name": [
        "ProcNoteNum", "PatNum", "ProcNum", "EntryDateTime", "UserNum",
        "Note", "SigIsTopaz", "Signature"
    ],
    "Data Type": [
        "bigint(20)", "bigint(20)", "bigint(20)", "datetime", "bigint(20)",
        "text", "tinyint(3) unsigned", "text"
    ],
    "Default Value": [
        "AUTO_INCREMENT", "NOT NULL", "NOT NULL", "'0001-01-01 00:00:00'", "NOT NULL",
        "NULL", "NOT NULL", "NULL"
    ],
    "Key Type": [
        "PRIMARY KEY", "FOREIGN KEY", "FOREIGN KEY", "NONE", "FOREIGN KEY",
        "NONE", "NONE", "NONE"
    ],
    "References": [
        "Self", "Patient(PatNum)", "ProcedureLog(ProcNum)", "None", "User(UserNum)",
        "None", "None", "None"
    ]
}

# Find the maximum length of lists in the dictionary
max_length = max(len(lst) for lst in procnote_data.values())

# Ensure all lists are of equal length by padding with None
for key in procnote_data:
    current_length = len(procnote_data[key])
    if current_length < max_length:
        procnote_data[key].extend([None] * (max_length - current_length))

# Create DataFrame
df_procnote = pd.DataFrame(procnote_data)

# Get project root and set output path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
file_path_procnote = os.path.join(project_root, "docs", "procnote_table_schema_with_keys.csv")

# Save the DataFrame to CSV
df_procnote.to_csv(file_path_procnote, index=False) 