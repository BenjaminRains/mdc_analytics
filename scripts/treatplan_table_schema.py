import pandas as pd
import os

# Update the table schema to include information about primary and foreign keys
data_with_keys = {
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
        "None", "ResponsibleParty(ResponsParty)", "Document(DocNum)", "None", "User(SecUserNumEntry)", 
        "None", "None", "User(UserNumPresenter)", "None", "None", "None", 
        "None", "None", "None", "MobileDevice(MobileAppDeviceNum)"
    ]
}

# Create a DataFrame
df_with_keys = pd.DataFrame(data_with_keys)

# Get project root and set output path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
file_path_with_keys = os.path.join(project_root, "docs", "treatplan_table_schema_with_keys.csv")

# Save the DataFrame to CSV
df_with_keys.to_csv(file_path_with_keys, index=False)


