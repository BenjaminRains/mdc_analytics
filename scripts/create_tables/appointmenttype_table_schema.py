import pandas as pd
import os

# Define the appointmenttype table schema information with primary and foreign keys
appointmenttype_data = {
    "Column Name": [
        "AppointmentTypeNum", "AppointmentTypeName", "AppointmentTypeColor",
        "ItemOrder", "IsHidden", "Pattern", "CodeStr", "CodeStrRequired",
        "RequiredProcCodesNeeded", "BlockoutTypes"
    ],
    "Data Type": [
        "bigint(20)", "varchar(255)", "int(11)", "int(11)", "tinyint(4)",
        "varchar(255)", "varchar(4000)", "varchar(4000)", "tinyint(4)",
        "varchar(255)"
    ],
    "Default Value": [
        "AUTO_INCREMENT", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL",
        "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL"
    ],
    "Key Type": [
        "PRIMARY KEY", "NONE", "NONE", "NONE", "NONE",
        "NONE", "NONE", "NONE", "NONE", "NONE"
    ],
    "References": [
        "Self", "None", "None", "None", "None",
        "None", "None", "None", "None", "None"
    ]
}

# Find the maximum length of lists in the dictionary
max_length = max(len(lst) for lst in appointmenttype_data.values())

# Ensure all lists are of equal length by padding with None
for key in appointmenttype_data:
    current_length = len(appointmenttype_data[key])
    if current_length < max_length:
        appointmenttype_data[key].extend([None] * (max_length - current_length))

# Create DataFrame
df_appointmenttype = pd.DataFrame(appointmenttype_data)

# Get project root and set output path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
file_path_appointmenttype = os.path.join(project_root, "docs", "appointmenttype_table_schema_with_keys.csv")

# Save the DataFrame to CSV
df_appointmenttype.to_csv(file_path_appointmenttype, index=False) 