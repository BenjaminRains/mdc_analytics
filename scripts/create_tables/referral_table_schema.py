import pandas as pd
import os

# Define the referral table schema information with primary and foreign keys
referral_data = {
    "Column Name": [
        "ReferralNum", "LName", "FName", "MName", "SSN", "UsingTIN", "Specialty",
        "ST", "Telephone", "Address", "Address2", "City", "Zip", "Note",
        "Phone2", "IsHidden", "NotPerson", "Title", "EMail", "PatNum",
        "NationalProvID", "Slip", "IsDoctor", "IsTrustedDirect", "DateTStamp",
        "IsPreferred", "BusinessName", "DisplayNote"
    ],
    "Data Type": [
        "bigint(20)", "varchar(100)", "varchar(100)", "varchar(100)", "varchar(9)",
        "tinyint(1) unsigned", "bigint(20)", "varchar(2)", "varchar(10)",
        "varchar(100)", "varchar(100)", "varchar(100)", "varchar(10)", "text",
        "varchar(30)", "tinyint(1) unsigned", "tinyint(1) unsigned", "varchar(255)",
        "varchar(255)", "bigint(20)", "varchar(255)", "bigint(20)", "tinyint(4)",
        "tinyint(4)", "timestamp", "tinyint(4)", "varchar(255)", "varchar(4000)"
    ],
    "Default Value": [
        "AUTO_INCREMENT", "''", "''", "''", "''", "'0'", "NOT NULL", "''", "''",
        "''", "''", "''", "''", "NULL", "''", "'0'", "'0'", "''", "''",
        "NOT NULL", "NULL", "NOT NULL", "NOT NULL", "NOT NULL", "CURRENT_TIMESTAMP",
        "NOT NULL", "NOT NULL", "NOT NULL"
    ],
    "Key Type": [
        "PRIMARY KEY", "NONE", "NONE", "NONE", "NONE", "NONE", "FOREIGN KEY",
        "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE",
        "NONE", "NONE", "NONE", "NONE", "FOREIGN KEY", "NONE", "NONE",
        "NONE", "NONE", "NONE", "NONE", "NONE", "NONE"
    ],
    "References": [
        "Self", "None", "None", "None", "None", "None", "Definition(Specialty)",
        "None", "None", "None", "None", "None", "None", "None", "None",
        "None", "None", "None", "None", "Patient(PatNum)", "None", "None",
        "None", "None", "None", "None", "None", "None"
    ]
}

# Find the maximum length of lists in the dictionary
max_length = max(len(lst) for lst in referral_data.values())

# Ensure all lists are of equal length by padding with None
for key in referral_data:
    current_length = len(referral_data[key])
    if current_length < max_length:
        referral_data[key].extend([None] * (max_length - current_length))

# Create DataFrame
df_referral = pd.DataFrame(referral_data)

# Get project root and set output path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
file_path_referral = os.path.join(project_root, "docs", "referral_table_schema_with_keys.csv")

# Save the DataFrame to CSV
df_referral.to_csv(file_path_referral, index=False) 