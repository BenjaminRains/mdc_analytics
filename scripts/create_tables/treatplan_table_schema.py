import pandas as pd
import os

# Define the treatplan table schema information with primary and foreign keys
treatplan_data = {
    "Column Name": [
        "TreatPlanNum", "PatNum", "DateTP", "Heading", "Note", "Signature",
        "SigIsTopaz", "ResponsParty", "DocNum", "TPStatus", "SecUserNumEntry",
        "SecDateEntry", "SecDateTEdit", "UserNumPresenter", "TPType",
        "SignaturePractice", "DateTSigned", "DateTPracticeSigned",
        "SignatureText", "SignaturePracticeText", "MobileAppDeviceNum"
    ],
    "Data Type": [
        "bigint(20)", "bigint(20)", "date", "varchar(255)", "text", "text",
        "tinyint(1)", "bigint(20)", "bigint(20)", "tinyint(4)", "bigint(20)",
        "date", "timestamp", "bigint(20)", "tinyint(4)", "text", "datetime",
        "datetime", "varchar(255)", "varchar(255)", "bigint(20)"
    ],
    "Default Value": [
        "AUTO_INCREMENT", "NOT NULL", "'0001-01-01'", "''", "NULL", "NULL",
        "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL",
        "'0001-01-01'", "CURRENT_TIMESTAMP", "NOT NULL", "NOT NULL",
        "NOT NULL", "'0001-01-01 00:00:00'", "'0001-01-01 00:00:00'",
        "NOT NULL", "NOT NULL", "NOT NULL"
    ],
    "Key Type": [
        "PRIMARY KEY", "FOREIGN KEY", "NONE", "NONE", "NONE", "NONE",
        "NONE", "FOREIGN KEY", "FOREIGN KEY", "NONE", "FOREIGN KEY",
        "NONE", "NONE", "FOREIGN KEY", "NONE", "NONE", "NONE",
        "NONE", "NONE", "NONE", "FOREIGN KEY"
    ],
    "References": [
        "Self", "Patient(PatNum)", "None", "None", "None", "None",
        "None", "ResponsibleParty(ResponsParty)", "Document(DocNum)", "None",
        "User(SecUserNumEntry)", "None", "None", "User(UserNumPresenter)", "None",
        "None", "None", "None", "None", "None", "MobileAppDevice(MobileAppDeviceNum)"
    ]
}

# Find the maximum length of lists in the dictionary
max_length = max(len(lst) for lst in treatplan_data.values())

# Ensure all lists are of equal length by padding with None
for key in treatplan_data:
    current_length = len(treatplan_data[key])
    if current_length < max_length:
        treatplan_data[key].extend([None] * (max_length - current_length))

# Create DataFrame
df_treatplan = pd.DataFrame(treatplan_data)

# Get project root and set output path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
file_path_treatplan = os.path.join(project_root, "docs", "treatplan_table_schema_with_keys.csv")

# Save the DataFrame to CSV
df_treatplan.to_csv(file_path_treatplan, index=False)


