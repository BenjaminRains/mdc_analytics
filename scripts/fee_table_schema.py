import pandas as pd
import os

# Define the fee table schema information with primary and foreign keys
fee_data = {
    "Column Name": [
        "FeeNum", "Amount", "OldCode", "FeeSched", "UseDefaultFee", 
        "UseDefaultCov", "CodeNum", "ClinicNum", "ProvNum", "SecUserNumEntry",
        "SecDateEntry", "SecDateTEdit"
    ],
    "Data Type": [
        "bigint(20)", "double", "varchar(15)", "bigint(20)", "tinyint(1) unsigned",
        "tinyint(1) unsigned", "bigint(20)", "bigint(20)", "bigint(20)", "bigint(20)",
        "date", "timestamp"
    ],
    "Default Value": [
        "AUTO_INCREMENT", "'0'", "''", "NOT NULL", "'0'",
        "'0'", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL",
        "'0001-01-01'", "CURRENT_TIMESTAMP"
    ],
    "Key Type": [
        "PRIMARY KEY", "NONE", "INDEX", "FOREIGN KEY", "NONE",
        "NONE", "FOREIGN KEY", "FOREIGN KEY", "FOREIGN KEY", "FOREIGN KEY",
        "NONE", "NONE"
    ],
    "References": [
        "Self", "None", "None", "FeeSched(FeeSched)", "None",
        "None", "ProcedureCode(CodeNum)", "Clinic(ClinicNum)", "Provider(ProvNum)", "User(SecUserNumEntry)",
        "None", "None"
    ]
}

# Create DataFrame
df_fee = pd.DataFrame(fee_data)

# Get project root and set output path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
file_path_fee = os.path.join(project_root, "docs", "fee_table_schema_with_keys.csv")

# Save the DataFrame to CSV
df_fee.to_csv(file_path_fee, index=False) 