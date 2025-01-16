import pandas as pd
import os

# Define the adjustment table schema information with primary and foreign keys
adjustment_data = {
    "Column Name": [
        "AdjNum", "AdjDate", "AdjAmt", "PatNum", "AdjType", "ProvNum", "AdjNote", 
        "ProcDate", "ProcNum", "DateEntry", "ClinicNum", "StatementNum", 
        "SecUserNumEntry", "SecDateTEdit", "TaxTransID"
    ],
    "Data Type": [
        "bigint(20)", "date", "double", "bigint(20)", "bigint(20)", "bigint(20)", "text", 
        "date", "bigint(20)", "date", "bigint(20)", "bigint(20)", 
        "bigint(20)", "timestamp", "bigint(20)"
    ],
    "Default Value": [
        "AUTO_INCREMENT", "'0001-01-01'", "'0'", "NOT NULL", "NOT NULL", "NOT NULL", "NULL", 
        "'0001-01-01'", "NOT NULL", "'0001-01-01'", "NOT NULL", "NOT NULL", 
        "NOT NULL", "CURRENT_TIMESTAMP", "NOT NULL"
    ],
    "Key Type": [
        "PRIMARY KEY", "NONE", "NONE", "FOREIGN KEY", "FOREIGN KEY", "FOREIGN KEY", "NONE", 
        "NONE", "FOREIGN KEY", "NONE", "FOREIGN KEY", "FOREIGN KEY", 
        "FOREIGN KEY", "NONE", "FOREIGN KEY"
    ],
    "References": [
        "Self", "None", "None", "Patient(PatNum)", "AdjustmentType(AdjType)", "Provider(ProvNum)", "None", 
        "None", "Procedure(ProcNum)", "None", "Clinic(ClinicNum)", "Statement(StatementNum)", 
        "User(SecUserNumEntry)", "None", "TaxTransaction(TaxTransID)"
    ]
}

# Create DataFrame
df_adjustment = pd.DataFrame(adjustment_data)

# Get project root and set output path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
file_path_adjustment = os.path.join(project_root, "docs", "adjustment_table_schema_with_keys.csv")

# Save the DataFrame to CSV
df_adjustment.to_csv(file_path_adjustment, index=False)
