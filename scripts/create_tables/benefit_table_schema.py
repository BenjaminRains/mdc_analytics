import pandas as pd
import os

# Define the benefit table schema information with primary and foreign keys
benefit_data = {
    "Column Name": [
        "BenefitNum", "PlanNum", "PatPlanNum", "CovCatNum", "BenefitType",
        "Percent", "MonetaryAmt", "TimePeriod", "QuantityQualifier", "Quantity",
        "CodeNum", "CoverageLevel", "SecDateTEntry", "SecDateTEdit", "CodeGroupNum",
        "TreatArea"
    ],
    "Data Type": [
        "bigint(20)", "bigint(20)", "bigint(20)", "bigint(20)", "tinyint(3) unsigned",
        "tinyint(4)", "double", "tinyint(3) unsigned", "tinyint(3) unsigned",
        "tinyint(3) unsigned", "bigint(20)", "int(11)", "datetime", "timestamp",
        "bigint(20)", "tinyint(4)"
    ],
    "Default Value": [
        "AUTO_INCREMENT", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL",
        "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL",
        "NOT NULL", "NOT NULL", "'0001-01-01 00:00:00'", "CURRENT_TIMESTAMP",
        "NOT NULL", "NOT NULL"
    ],
    "Key Type": [
        "PRIMARY KEY", "FOREIGN KEY", "FOREIGN KEY", "FOREIGN KEY", "INDEX",
        "INDEX", "INDEX", "INDEX", "INDEX", "INDEX",
        "FOREIGN KEY", "INDEX", "INDEX", "INDEX", "FOREIGN KEY",
        "NONE"
    ],
    "References": [
        "Self", "InsurancePlan(PlanNum)", "PatPlan(PatPlanNum)", 
        "CovCat(CovCatNum)", "None", "None", "None", "None", "None", "None",
        "ProcedureCode(CodeNum)", "None", "None", "None", 
        "CodeGroup(CodeGroupNum)", "None"
    ]
}

# Find the maximum length of lists in the dictionary
max_length = max(len(lst) for lst in benefit_data.values())

# Ensure all lists are of equal length by padding with None
for key in benefit_data:
    current_length = len(benefit_data[key])
    if current_length < max_length:
        benefit_data[key].extend([None] * (max_length - current_length))

# Create DataFrame
df_benefit = pd.DataFrame(benefit_data)

# Get project root and set output path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
file_path_benefit = os.path.join(project_root, "docs", "benefit_table_schema_with_keys.csv")

# Save the DataFrame to CSV
df_benefit.to_csv(file_path_benefit, index=False) 