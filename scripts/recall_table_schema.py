import pandas as pd
import os

# Define the recall table schema information with primary and foreign keys
recall_data = {
    "Column Name": [
        "RecallNum", "PatNum", "DateDueCalc", "DateDue", "DatePrevious",
        "RecallInterval", "RecallStatus", "Note", "IsDisabled", "DateTStamp",
        "RecallTypeNum", "DisableUntilBalance", "DisableUntilDate",
        "DateScheduled", "Priority", "TimePatternOverride"
    ],
    "Data Type": [
        "bigint(20)", "bigint(20)", "date", "date", "date",
        "int(11)", "bigint(20)", "text", "tinyint(3) unsigned", "timestamp",
        "bigint(20)", "double", "date", "date", "tinyint(4)", "varchar(255)"
    ],
    "Default Value": [
        "AUTO_INCREMENT", "NOT NULL", "'0001-01-01'", "'0001-01-01'", "'0001-01-01'",
        "'0'", "NOT NULL", "NULL", "'0'", "CURRENT_TIMESTAMP",
        "NOT NULL", "NOT NULL", "'0001-01-01'", "'0001-01-01'", "NOT NULL", "NOT NULL"
    ],
    "Key Type": [
        "PRIMARY KEY", "FOREIGN KEY", "NONE", "INDEX", "INDEX",
        "NONE", "FOREIGN KEY", "NONE", "INDEX", "NONE",
        "FOREIGN KEY", "NONE", "NONE", "INDEX", "NONE", "NONE"
    ],
    "References": [
        "Self", "Patient(PatNum)", "None", "None", "None",
        "None", "Definition(RecallStatus)", "None", "None", "None",
        "RecallType(RecallTypeNum)", "None", "None", "None", "None", "None"
    ]
}

# Find the maximum length of lists in the dictionary
max_length = max(len(lst) for lst in recall_data.values())

# Ensure all lists are of equal length by padding with None
for key in recall_data:
    current_length = len(recall_data[key])
    if current_length < max_length:
        recall_data[key].extend([None] * (max_length - current_length))

# Create DataFrame
df_recall = pd.DataFrame(recall_data)

# Get project root and set output path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
file_path_recall = os.path.join(project_root, "docs", "recall_table_schema_with_keys.csv")

# Save the DataFrame to CSV
df_recall.to_csv(file_path_recall, index=False) 