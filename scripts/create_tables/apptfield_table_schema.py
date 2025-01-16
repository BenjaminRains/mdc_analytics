import pandas as pd
import os

# Define the apptfield table schema information with primary and foreign keys
apptfield_data = {
    "Column Name": [
        "ApptFieldNum", "AptNum", "FieldName", "FieldValue"
    ],
    "Data Type": [
        "bigint(20)", "bigint(20)", "varchar(255)", "text"
    ],
    "Default Value": [
        "AUTO_INCREMENT", "NOT NULL", "NOT NULL", "NOT NULL"
    ],
    "Key Type": [
        "PRIMARY KEY", "FOREIGN KEY", "NONE", "NONE"
    ],
    "References": [
        "Self", "Appointment(AptNum)", "None", "None"
    ]
}

# Find the maximum length of lists in the dictionary
max_length = max(len(lst) for lst in apptfield_data.values())

# Ensure all lists are of equal length by padding with None
for key in apptfield_data:
    current_length = len(apptfield_data[key])
    if current_length < max_length:
        apptfield_data[key].extend([None] * (max_length - current_length))

# Create DataFrame
df_apptfield = pd.DataFrame(apptfield_data)

# Get project root and set output path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
file_path_apptfield = os.path.join(project_root, "docs", "apptfield_table_schema_with_keys.csv")

# Save the DataFrame to CSV
df_apptfield.to_csv(file_path_apptfield, index=False) 