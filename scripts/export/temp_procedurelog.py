import sys
import os
print("Current working directory:", os.getcwd())
print("sys.path:", sys.path)

# Add the project root to sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../../")))

import mysql.connector
import csv

# Import database connection function and file paths
from src.db_config import connect_to_mysql
from src.file_paths import get_file_path

try:
    # Retrieve file path for procedurelog export using the helper function
    output_path = get_file_path("procedurelog")
    if not output_path:
        raise KeyError("File path for 'procedurelog' is missing in file_paths.py")

    # Establish the database connection
    conn = connect_to_mysql()

    # Verify connection
    cursor = conn.cursor()
    cursor.execute("SELECT DATABASE();")
    print(f"Connected to database: {cursor.fetchone()[0]}")   

    # Query to fetch procedurelog data
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
    WHERE ProcDate >= DATE_SUB(CURDATE(), INTERVAL 4 YEAR);
    """

    chunk_size = 10000  # Fetch 10,000 rows at a time
    total_rows = 0  # Keep track of total rows processed

    # Open the file for writing
    with open(output_path, mode="w", newline="", encoding="utf-8") as file:
        writer = csv.writer(file)
        cursor.execute(query)

        # Write headers
        column_names = [desc[0] for desc in cursor.description]
        writer.writerow(column_names)

        # Fetch data in chunks and write to the file
        while True:
            rows = cursor.fetchmany(chunk_size)
            if not rows:
                break
            writer.writerows(rows)
            total_rows += len(rows)
            print(f"Extracted {total_rows} rows so far...")

    print(f"Data extraction completed successfully! Total rows: {total_rows}")
    print(f"Data saved to: {output_path}")

except KeyError as ke:
    print(f"Configuration error: {ke}")
except Exception as e:
    print(f"An unexpected error occurred: {e}")

finally:
    # Ensure the connection is closed
    if 'conn' in locals() and conn.is_connected():
        conn.close()
    print("Connection closed.")
