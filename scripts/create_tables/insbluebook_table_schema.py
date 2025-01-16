import pandas as pd
import os

# Define the insbluebook table schema information with primary and foreign keys
insbluebook_data = {
    "Column Name": [
        "InsBlueBookNum", "ProcCodeNum", "CarrierNum", "PlanNum", "GroupNum",
        "InsPayAmt", "AllowedOverride", "DateTEntry", "ProcNum", "ProcDate",
        "ClaimType", "ClaimNum"
    ],
    "Data Type": [
        "bigint(20)", "bigint(20)", "bigint(20)", "bigint(20)", "varchar(25)",
        "double", "double", "datetime", "bigint(20)", "date",
        "varchar(10)", "bigint(20)"
    ],
    "Default Value": [
        "AUTO_INCREMENT", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL",
        "NOT NULL", "NOT NULL", "'0001-01-01 00:00:00'", "NOT NULL", "'0001-01-01'",
        "NOT NULL", "NOT NULL"
    ],
    "Key Type": [
        "PRIMARY KEY", "FOREIGN KEY", "FOREIGN KEY", "FOREIGN KEY", "NONE",
        "NONE", "NONE", "NONE", "FOREIGN KEY", "NONE",
        "NONE", "FOREIGN KEY"
    ],
    "References": [
        "Self", "ProcedureCode(ProcCodeNum)", "Carrier(CarrierNum)", "InsPlan(PlanNum)", "None",
        "None", "None", "None", "Procedure(ProcNum)", "None",
        "None", "Claim(ClaimNum)"
    ]
}

# Create DataFrame
df_insbluebook = pd.DataFrame(insbluebook_data)

# Get project root and set output path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
file_path_insbluebook = os.path.join(project_root, "docs", "insbluebook_table_schema_with_keys.csv")

# Save the DataFrame to CSV
df_insbluebook.to_csv(file_path_insbluebook, index=False) 