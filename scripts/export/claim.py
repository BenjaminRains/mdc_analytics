import os
import mysql.connector
import csv
import logging
from src.db_config import connect_to_mysql
from src.file_paths import get_file_path

# Get the root directory explicitly, regardless of the current working directory
root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../"))  # Navigate to /mdc_analytics/
logs_dir = os.path.join(root_dir, "logs")  # Define the /logs/ directory
os.makedirs(logs_dir, exist_ok=True)  # Ensure the /logs/ directory exists

log_file_path = os.path.join(logs_dir, "data_export.log")  # Log file in /logs/

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    handlers=[
        logging.StreamHandler(),  # Log to console
        logging.FileHandler(log_file_path, mode="w")  # Log file in /logs/
    ]
)

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

def export_data():
    """
    Main function to export data based on the 'claim_query'.
    """
    try:
        # Retrieve file path for claim_query export using the helper function
        output_path = get_file_path("claim_query")
        if not output_path:
            raise KeyError("File path for 'claim_query' is missing in file_paths.py")

        # Check if the output file exists and log a warning
        if os.path.exists(output_path):
            logging.warning(f"Output file '{output_path}' already exists and will be overwritten.")

        # Retrieve SQL query from file
        query = get_sql_query("claim_query")

        chunk_size = 10000  # Fetch 10,000 rows at a time
        total_rows = 0  # Keep track of total rows processed

        # Use context managers for safe handling of connections and cursors
        with connect_to_mysql() as conn:
            with conn.cursor() as cursor:
                cursor.execute("SELECT DATABASE();")
                db_name = cursor.fetchone()[0]
                logging.info(f"Connected to database: {db_name}")

                cursor.execute(query)

                # Open the file for writing (overwrites if the file already exists)
                with open(output_path, mode="w", newline="", encoding="utf-8") as file:
                    writer = csv.writer(file)

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
                        logging.info(f"Extracted {total_rows} rows so far...")

        logging.info(f"Data extraction completed successfully! Total rows: {total_rows}")
        logging.info(f"Data saved to: {output_path}")

    except KeyError as ke:
        logging.error(f"Configuration error: {ke}")
    except FileNotFoundError as fe:
        logging.error(f"SQL file error: {fe}")
    except Exception as e:
        logging.error(f"An unexpected error occurred: {e}")

if __name__ == "__main__":
    export_data()
