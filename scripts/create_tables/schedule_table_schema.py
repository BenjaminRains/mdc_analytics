import pandas as pd
import os

# Define the schedule table schema information with primary and foreign keys
schedule_data = {
    "Column Name": [
        "ScheduleNum", "SchedDate", "StartTime", "StopTime", "SchedType",
        "ProvNum", "BlockoutType", "Note", "Status", "EmployeeNum",
        "DateTStamp", "ClinicNum"
    ],
    "Data Type": [
        "bigint(20)", "date", "time", "time", "tinyint(3) unsigned",
        "bigint(20)", "bigint(20)", "text", "tinyint(3) unsigned", "bigint(20)",
        "timestamp", "bigint(20)"
    ],
    "Default Value": [
        "AUTO_INCREMENT", "'0001-01-01'", "'00:00:00'", "'00:00:00'", "'0'",
        "NOT NULL", "NOT NULL", "NULL", "'0'", "NOT NULL",
        "CURRENT_TIMESTAMP", "NOT NULL"
    ],
    "Key Type": [
        "PRIMARY KEY", "INDEX", "NONE", "INDEX", "INDEX",
        "FOREIGN KEY", "FOREIGN KEY", "NONE", "NONE", "FOREIGN KEY",
        "NONE", "FOREIGN KEY"
    ],
    "References": [
        "Self", "None", "None", "None", "None",
        "Provider(ProvNum)", "Definition(BlockoutType)", "None", "None", "Employee(EmployeeNum)",
        "None", "Clinic(ClinicNum)"
    ]
}

# Find the maximum length of lists in the dictionary
max_length = max(len(lst) for lst in schedule_data.values())

# Ensure all lists are of equal length by padding with None
for key in schedule_data:
    current_length = len(schedule_data[key])
    if current_length < max_length:
        schedule_data[key].extend([None] * (max_length - current_length))

# Create DataFrame
df_schedule = pd.DataFrame(schedule_data)

# Get project root and set output path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
file_path_schedule = os.path.join(project_root, "docs", "schedule_table_schema_with_keys.csv")

# Save the DataFrame to CSV
df_schedule.to_csv(file_path_schedule, index=False) 