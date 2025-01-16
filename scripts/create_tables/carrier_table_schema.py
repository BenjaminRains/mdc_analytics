import pandas as pd
import os

# Define the carrier table schema information with primary and foreign keys
carrier_data = {
    "Column Name": [
        "CarrierNum", "CarrierName", "Address", "Address2", "City", "State", "Zip",
        "Phone", "ElectID", "NoSendElect", "IsCDA", "CDAnetVersion",
        "CanadianNetworkNum", "IsHidden", "CanadianEncryptionMethod",
        "CanadianSupportedTypes", "SecUserNumEntry", "SecDateEntry", "SecDateTEdit",
        "TIN", "CarrierGroupName", "ApptTextBackColor", "IsCoinsuranceInverted",
        "TrustedEtransFlags", "CobInsPaidBehaviorOverride", "EraAutomationOverride",
        "OrthoInsPayConsolidate"
    ],
    "Data Type": [
        "bigint(20)", "varchar(255)", "varchar(255)", "varchar(255)", "varchar(255)",
        "varchar(255)", "varchar(255)", "varchar(255)", "varchar(255)",
        "tinyint(1) unsigned", "tinyint(3) unsigned", "varchar(100)", "bigint(20)",
        "tinyint(4)", "tinyint(4)", "int(11)", "bigint(20)", "date", "timestamp",
        "varchar(255)", "bigint(20)", "int(11)", "tinyint(4)", "tinyint(4)",
        "tinyint(4)", "tinyint(4)", "tinyint(4)"
    ],
    "Default Value": [
        "AUTO_INCREMENT", "''", "''", "''", "''", "''", "''", "''", "''",
        "'0'", "NOT NULL", "''", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL",
        "NOT NULL", "'0001-01-01'", "CURRENT_TIMESTAMP", "NOT NULL", "NOT NULL",
        "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL"
    ],
    "Key Type": [
        "PRIMARY KEY", "INDEX", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE",
        "NONE", "NONE", "NONE", "NONE", "FOREIGN KEY", "NONE", "NONE", "NONE",
        "FOREIGN KEY", "NONE", "NONE", "NONE", "FOREIGN KEY", "NONE", "NONE",
        "NONE", "NONE", "NONE", "NONE"
    ],
    "References": [
        "Self", "None", "None", "None", "None", "None", "None", "None",
        "None", "None", "None", "None", "CanadianNetwork(CanadianNetworkNum)",
        "None", "None", "None", "User(SecUserNumEntry)", "None", "None",
        "None", "CarrierGroup(CarrierGroupName)", "None", "None", "None",
        "None", "None", "None"
    ]
}

# Find the maximum length of lists in the dictionary
max_length = max(len(lst) for lst in carrier_data.values())

# Ensure all lists are of equal length by padding with None
for key in carrier_data:
    current_length = len(carrier_data[key])
    if current_length < max_length:
        carrier_data[key].extend([None] * (max_length - current_length))

# Create DataFrame
df_carrier = pd.DataFrame(carrier_data)

# Get project root and set output path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
file_path_carrier = os.path.join(project_root, "docs", "carrier_table_schema_with_keys.csv")

# Save the DataFrame to CSV
df_carrier.to_csv(file_path_carrier, index=False) 