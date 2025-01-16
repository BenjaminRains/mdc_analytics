import pandas as pd
import os

# Define the definition table schema information with primary and foreign keys
definition_data = {
    "Column Name": [
        "DefNum", "Category", "ItemOrder", "ItemName", "ItemValue", 
        "ItemColor", "IsHidden"
    ],
    "Data Type": [
        "bigint(20)", "tinyint(3) unsigned", "smallint(5) unsigned", 
        "varchar(255)", "varchar(255)", "int(11)", "tinyint(3) unsigned"
    ],
    "Default Value": [
        "AUTO_INCREMENT", "'0'", "'0'", "''", "''", 
        "'0'", "'0'"
    ],
    "Key Type": [
        "PRIMARY KEY", "NONE", "NONE", "NONE", "NONE", 
        "NONE", "NONE"
    ],
    "References": [
        "Self", "None", "None", "None", "None", 
        "None", "None"
    ]
}

# Create DataFrame
df_definition = pd.DataFrame(definition_data)

# Get project root and set output path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
file_path_definition = os.path.join(project_root, "docs", "definition_table_schema_with_keys.csv")

# Save the DataFrame to CSV
df_definition.to_csv(file_path_definition, index=False)