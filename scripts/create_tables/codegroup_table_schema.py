import pandas as pd
import os

# Define the codegroup table schema information with primary and foreign keys
codegroup_data = {
    "Column Name": [
        "CodeGroupNum", "GroupName", "ProcCodes", "ItemOrder", "CodeGroupFixed", "IsHidden"
    ],
    "Data Type": [
        "bigint(20)", "varchar(50)", "text", "int(11)", "tinyint(4)", "tinyint(4)"
    ],
    "Default Value": [
        "AUTO_INCREMENT", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL"
    ],
    "Key Type": [
        "PRIMARY KEY", "NONE", "NONE", "NONE", "NONE", "NONE"
    ],
    "References": [
        "Self", "None", "None", "None", "None", "None"
    ]
}

# Create DataFrame
df_codegroup = pd.DataFrame(codegroup_data)

# Get project root and set output path
project_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
file_path_codegroup = os.path.join(project_root, "docs", "opendental_schemas", "codegroup_table_schema_with_keys.csv")

# Create the directory if it doesn't exist
os.makedirs(os.path.dirname(file_path_codegroup), exist_ok=True)

# Save the DataFrame to CSV
df_codegroup.to_csv(file_path_codegroup, index=False) 