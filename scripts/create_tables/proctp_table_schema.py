import pandas as pd
import os

# Define the proctp table schema information with primary and foreign keys
proctp_data = {
    "Column Name": [
        "ProcTPNum", "TreatPlanNum", "PatNum", "ProcNumOrig", "ItemOrder",
        "Priority", "ToothNumTP", "Surf", "ProcCode", "Descript", "FeeAmt",
        "PriInsAmt", "SecInsAmt", "PatAmt", "Discount", "Prognosis", "Dx",
        "ProcAbbr", "SecUserNumEntry", "SecDateEntry", "SecDateTEdit",
        "FeeAllowed", "TaxAmt", "ProvNum", "DateTP", "ClinicNum", "CatPercUCR"
    ],
    "Data Type": [
        "bigint(20)", "bigint(20)", "bigint(20)", "bigint(20)", 
        "smallint(5) unsigned", "bigint(20)", "varchar(255)", "varchar(255)",
        "varchar(15)", "varchar(255)", "double", "double", "double", "double",
        "double", "varchar(255)", "varchar(255)", "varchar(50)", "bigint(20)",
        "date", "timestamp", "double", "double", "bigint(20)", "date",
        "bigint(20)", "double"
    ],
    "Default Value": [
        "AUTO_INCREMENT", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL",
        "NOT NULL", "''", "''", "NULL", "''", "NOT NULL", "NOT NULL",
        "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL",
        "NOT NULL", "'0001-01-01'", "CURRENT_TIMESTAMP", "NOT NULL", "NOT NULL",
        "NOT NULL", "'0001-01-01'", "NOT NULL", "NOT NULL"
    ],
    "Key Type": [
        "PRIMARY KEY", "FOREIGN KEY", "FOREIGN KEY", "FOREIGN KEY", "NONE",
        "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE",
        "NONE", "NONE", "NONE", "NONE", "NONE", "FOREIGN KEY", "NONE",
        "NONE", "NONE", "NONE", "FOREIGN KEY", "NONE", "FOREIGN KEY", "NONE"
    ],
    "References": [
        "Self", "TreatPlan(TreatPlanNum)", "Patient(PatNum)", 
        "ProcedureLog(ProcNumOrig)", "None", "None", "None", "None", "None",
        "None", "None", "None", "None", "None", "None", "None", "None",
        "None", "User(SecUserNumEntry)", "None", "None", "None", "None",
        "Provider(ProvNum)", "None", "Clinic(ClinicNum)", "None"
    ]
}

# Find the maximum length of lists in the dictionary
max_length = max(len(lst) for lst in proctp_data.values())

# Ensure all lists are of equal length by padding with None
for key in proctp_data:
    current_length = len(proctp_data[key])
    if current_length < max_length:
        proctp_data[key].extend([None] * (max_length - current_length))

# Create DataFrame
df_proctp = pd.DataFrame(proctp_data)

# Get project root and set output path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
file_path_proctp = os.path.join(project_root, "docs", "proctp_table_schema_with_keys.csv")

# Save the DataFrame to CSV
df_proctp.to_csv(file_path_proctp, index=False) 