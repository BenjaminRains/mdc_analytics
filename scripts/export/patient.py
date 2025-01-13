import sys
import os
import mysql.connector
import csv

# Import database connection function and file paths
from src.db_config import connect_to_mysql
from src.file_paths import get_file_path

def get_sql_query(file_name):
    """
    Reads and returns the SQL query from a file.
    :param file_name: Name of the SQL file (without extension).
    :return: The SQL query as a string.
    """
    sql_directory = os.path.join(os.path.dirname(__file__), "sql")
    sql_file_path = os.path.join(sql_directory, f"{file_name}.sql")
    
    if not os.path.exists(sql_file_path):
        raise FileNotFoundError(f"SQL file '{file_name}.sql' not found in the 'sql' directory.")
    
    with open(sql_file_path, "r", encoding="utf-8") as file:
        return file.read()

try:
    # Retrieve file path for patient export using the helper function
    output_path = get_file_path("patient")
    if not output_path:
        raise KeyError("File path for 'patient' is missing in file_paths.py")

    # Establish the database connection
    conn = connect_to_mysql()

    # Verify connection
    cursor = conn.cursor()
    cursor.execute("SELECT DATABASE();")
    print(f"Connected to database: {cursor.fetchone()[0]}")

    # Retrieve SQL query from file
    query = get_sql_query("patient_query")

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
except FileNotFoundError as fe:
    print(f"SQL file error: {fe}")
except Exception as e:
    print(f"An unexpected error occurred: {e}")

finally:
    # Ensure the connection is closed
    if 'conn' in locals() and conn.is_connected():
        conn.close()
    print("Connection closed.")