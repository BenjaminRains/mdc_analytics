import os
import csv
import logging
from src.db_config import connect_to_mysql_localhost
from src.file_paths import file_paths

# Configure logging
log_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "logs")
os.makedirs(log_dir, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    handlers=[
        logging.FileHandler(os.path.join(log_dir, "local_export.log")),
        logging.StreamHandler()
    ]
)

def get_sql_query(table_name):
    """Reads SQL query from the sql directory"""
    sql_directory = os.path.join(os.path.dirname(__file__), "sql")
    sql_file_path = os.path.join(sql_directory, f"{table_name}_query.sql")
    
    with open(sql_file_path, "r", encoding="utf-8") as file:
        return file.read()

def export_local_tables(chunk_size=10000):
    """
    Export specified tables from local opendental_analytics database using chunked processing.
    Only exports tables that have corresponding SQL queries defined in file_paths.py.
    
    Args:
        chunk_size: Number of records to process at once (default: 10000)
    """
    conn = connect_to_mysql_localhost()
    tables_to_export = [key.replace("_query", "") for key in file_paths if key.endswith("_query")]
    successful_exports = []
    failed_exports = []
    
    logging.info(f"Preparing to export {len(tables_to_export)} tables: {', '.join(tables_to_export)}")
    
    for table_name in tables_to_export:
        output_path = file_paths[f"{table_name}_query"]
        
        try:
            query = get_sql_query(table_name)
            
            with conn.cursor() as cursor:
                cursor.execute(query)
                headers = [desc[0] for desc in cursor.description]
                
                with open(output_path, 'w', newline='', encoding='utf-8') as f:
                    writer = csv.writer(f)
                    writer.writerow(headers)
                    
                    while True:
                        rows = cursor.fetchmany(chunk_size)
                        if not rows:
                            break
                        writer.writerows(rows)
                        logging.info(f"Exported {len(rows)} rows for {table_name}")
                    
                logging.info(f"Completed export of {table_name} to {output_path}")
                successful_exports.append(table_name)
                
        except Exception as e:
            logging.error(f"Failed to export {table_name}: {e}")
            failed_exports.append(table_name)
            
    conn.close()
    
    # Log summary of exports
    logging.info("\n=== Export Summary ===")
    logging.info(f"Successfully exported {len(successful_exports)} tables: {', '.join(successful_exports)}")
    if failed_exports:
        logging.warning(f"Failed to export {len(failed_exports)} tables: {', '.join(failed_exports)}")

if __name__ == "__main__":
    logging.info("Starting export of specified tables from local database...")
    export_local_tables()
    logging.info("Export completed") 