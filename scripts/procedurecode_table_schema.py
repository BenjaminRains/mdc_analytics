import pandas as pd
import os

# Define the procedurecode table schema information with primary and foreign keys
procedurecode_data = {
    "Column Name": [
        "CodeNum", "ProcCode", "Descript", "AbbrDesc", "ProcTime", "ProcCat",
        "TreatArea", "NoBillIns", "IsProsth", "DefaultNote", "IsHygiene",
        "GTypeNum", "AlternateCode1", "MedicalCode", "IsTaxed", "PaintType",
        "GraphicColor", "LaymanTerm", "IsCanadianLab", "PreExisting", "BaseUnits",
        "SubstitutionCode", "SubstOnlyIf", "DateTStamp", "IsMultiVisit",
        "DrugNDC", "RevenueCodeDefault", "ProvNumDefault", "CanadaTimeUnits",
        "IsRadiology", "DefaultClaimNote", "DefaultTPNote", "BypassGlobalLock",
        "TaxCode", "PaintText", "AreaAlsoToothRange", "DiagnosticCodes"
    ],
    "Data Type": [
        "bigint(20)", "varchar(15)", "varchar(255)", "varchar(50)", "varchar(24)",
        "bigint(20)", "tinyint(3) unsigned", "tinyint(1) unsigned",
        "tinyint(1) unsigned", "text", "tinyint(1) unsigned",
        "smallint(5) unsigned", "varchar(15)", "varchar(15)", "tinyint(3) unsigned",
        "tinyint(4)", "int(11)", "varchar(255)", "tinyint(3) unsigned",
        "tinyint(1)", "int(11)", "varchar(25)", "int(11)", "timestamp",
        "tinyint(4)", "varchar(255)", "varchar(255)", "bigint(20)", "double",
        "tinyint(4)", "text", "text", "tinyint(4)", "varchar(16)",
        "varchar(255)", "tinyint(4)", "varchar(255)"
    ],
    "Default Value": [
        "AUTO_INCREMENT", "''", "''", "''", "''", "NOT NULL", "'0'", "'0'",
        "'0'", "NULL", "'0'", "'0'", "''", "''", "NOT NULL", "NOT NULL",
        "NOT NULL", "''", "NOT NULL", "'0'", "NOT NULL", "NULL", "NOT NULL",
        "CURRENT_TIMESTAMP", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL",
        "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL",
        "NOT NULL", "NOT NULL", "NOT NULL"
    ],
    "Key Type": [
        "PRIMARY KEY", "INDEX", "NONE", "NONE", "NONE", "FOREIGN KEY",
        "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE",
        "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE",
        "NONE", "NONE", "NONE", "NONE", "NONE", "FOREIGN KEY", "NONE",
        "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE"
    ],
    "References": [
        "Self", "None", "None", "None", "None", "Definition(ProcCat)",
        "None", "None", "None", "None", "None", "None", "None", "None",
        "None", "None", "None", "None", "None", "None", "None", "None",
        "None", "None", "None", "None", "None", "Provider(ProvNumDefault)", "None",
        "None", "None", "None", "None", "None", "None", "None", "None"
    ]
}

# Find the maximum length of lists in the dictionary
max_length = max(len(lst) for lst in procedurecode_data.values())

# Ensure all lists are of equal length by padding with None
for key in procedurecode_data:
    current_length = len(procedurecode_data[key])
    if current_length < max_length:
        procedurecode_data[key].extend([None] * (max_length - current_length))

# Create DataFrame
df_procedurecode = pd.DataFrame(procedurecode_data)

# Get project root and set output path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
file_path_procedurecode = os.path.join(project_root, "docs", "procedurecode_table_schema_with_keys.csv")

# Save the DataFrame to CSV
df_procedurecode.to_csv(file_path_procedurecode, index=False) 