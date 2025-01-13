import os
import csv
import logging
from mysql.connector import connect
from src.db_config import connect_to_mysql
from src.file_paths import get_file_path

# Ensure the logs directory exists
root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../"))  # Navigate to /mdc_analytics/
logs_dir = os.path.join(root_dir, "logs")  # Define the /logs/ directory
os.makedirs(logs_dir, exist_ok=True)  # Create the logs directory if it doesn't exist

# Define log file path
log_file_path = os.path.join(logs_dir, "data_export.log")

# Configure logging
logging.basicConfig(
    level=logging.INFO,  # Set the global logging level
    format="%(asctime)s - %(levelname)s - %(message)s",
    handlers=[
        logging.StreamHandler(),  # Log to console
        logging.FileHandler(log_file_path, mode="w")  # Log to the data_export.log file
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

def execute_query(query, chunk_size=10000):
    """
    Executes a SQL query and yields results in chunks.
    :param query: SQL query to execute.
    :param chunk_size: Number of rows to fetch per chunk.
    :return: Generator yielding rows.
    """
    with connect_to_mysql() as conn:
        with conn.cursor() as cursor:
            cursor.execute(query)
            logging.info("Query executed successfully.")
            column_names = [desc[0] for desc in cursor.description]  # Get column headers
            yield column_names  # Yield headers first
            
            while True:
                rows = cursor.fetchmany(chunk_size)
                if not rows:
                    break
                yield rows

def write_csv(output_path, column_names, data):
    """
    Writes data to a CSV file.
    :param output_path: Path to save the CSV file.
    :param column_names: List of column headers.
    :param data: Iterable data rows to write.
    """
    with open(output_path, mode="w", newline="", encoding="utf-8") as file:
        writer = csv.writer(file)
        writer.writerow(column_names)  # Write headers
        writer.writerows(data)
    logging.info(f"Data written to file: {output_path}")

def export_data(table_name):
    """
    Exports data by executing a query and saving the result to a CSV file.
    :param table_name: Name of the table (used for both the SQL file and output file key).
    """
    try:
        output_path = get_file_path(f"{table_name}_query")
        if not output_path:
            raise KeyError(f"File path for '{table_name}_query' is missing in file_paths.py")

        if os.path.exists(output_path):
            logging.warning(f"Output file '{output_path}' already exists and will be overwritten.")

        query = get_sql_query(f"{table_name}_query")

        with open(output_path, mode="w", newline="", encoding="utf-8") as file:
            writer = csv.writer(file)
            rows_iter = execute_query(query)
            
            # Write column headers
            column_names = next(rows_iter)
            writer.writerow(column_names)
            
            # Write data rows
            for rows in rows_iter:
                writer.writerows(rows)

        logging.info(f"Data export completed for table: {table_name}")

    except KeyError as ke:
        logging.error(f"Configuration error: {ke}")
    except FileNotFoundError as fe:
        logging.error(f"SQL file error: {fe}")
    except Exception as e:
        logging.error(f"An unexpected error occurred: {e}")

if __name__ == "__main__":
    # Automatically generate the list of tables from file_paths
    from src.file_paths import file_paths  # Import the file_paths dictionary

    tables = [key.replace("_query", "") for key in file_paths.keys() if key.endswith("_query")]

    logging.info(f"Tables to export: {tables}")

    for table in tables:
        export_data(table)

    # Log summary at the end of the script
    logging.info(f"Export process completed. Total tables exported: {len(tables)}.")

