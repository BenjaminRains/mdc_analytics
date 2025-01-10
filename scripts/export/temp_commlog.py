import sys
import os
import mysql.connector
import csv

from src.db_config import connect_to_mysql
from src.file_paths import get_file_path

try:
    # Retrieve file path for commlog export using the helper function
    output_path = get_file_path("commlog")
    if not output_path:
        raise KeyError("File path for 'commlog' is missing in file_paths.py")

    # Establish the database connection
    conn = connect_to_mysql()

    # Verify connection
    cursor = conn.cursor()
    cursor.execute("SELECT DATABASE();")
    print(f"Connected to database: {cursor.fetchone()[0]}")

    # Query to fetch commlog data
    query = """
    SELECT 
        PatNum,
        CommlogNum,
        CommDateTime,
        CommType,
        Note
    FROM 
        commlog
    WHERE 
        CommDateTime >= DATE_SUB(CURDATE(), INTERVAL 4 YEAR);

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
