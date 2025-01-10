import mysql.connector
import pandas as pd
import csv

# Database connection details
conn = mysql.connector.connect(
    host="localhost",
    user="root",
    password="Jibear10Jibear10!",  # Add your password if applicable
    database="opendental_analytics",
    port=3306
)

# Query to fetch data
query = """
SELECT
    ProcNum,
    PatNum,
    AptNum,
    OldCode,
    ProcDate,
    ProcFee,
    Surf,
    ToothNum,
    ToothRange,
    Priority,
    ProcStatus,
    ProvNum,
    CodeNum
FROM procedurelog
WHERE ProcDate >= '2021-01-01';
"""

# Filepath to save the data
output_path = r"C:\Users\rains\mdc_analytics\raw_data\temp_procedurelog.csv"

try:
    chunk_size = 10000  # Fetch 10,000 rows at a time
    total_rows = 0  # Keep track of total rows processed

    # Open file for writing
    with open(output_path, mode="w", newline="", encoding="utf-8") as file:
        writer = csv.writer(file)
        cursor = conn.cursor()
        cursor.execute(query)

        # Write headers
        column_names = [desc[0] for desc in cursor.description]
        writer.writerow(column_names)

        # Fetch data in chunks
        while True:
            rows = cursor.fetchmany(chunk_size)
            if not rows:
                break
            writer.writerows(rows)
            total_rows += len(rows)
            print(f"Extracted {total_rows} rows so far...")

    print(f"Data extraction completed successfully! Total rows: {total_rows}")

except Exception as e:
    print(f"An error occurred: {e}")

finally:
    conn.close()
