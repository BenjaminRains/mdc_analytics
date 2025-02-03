import pandas as pd
from datetime import datetime
import logging
from pathlib import Path
from src.connections.factory import ConnectionFactory
from scripts.utils.logging_utils.setup_logging import setup_logging

def read_sql_file(file_path: str) -> str:
    """Read SQL query from file"""
    with open(file_path, 'r') as file:
        return file.read()

def export_unscheduled_patients(database_name: str = None) -> None:
    """Export unscheduled patients data to CSV and Parquet"""
    try:
        # Create connection
        mariadb_conn = ConnectionFactory.create_connection('local_mariadb', database_name)
        
        # Read SQL query
        sql_path = "scripts/reports/unscheduled_patients_report.sql"
        query = read_sql_file(sql_path)
        
        # Execute query using connection context manager
        with mariadb_conn.get_connection() as conn:
            df = pd.read_sql(query, conn)
        
        # Create exports directory
        export_dir = Path("data/processed")
        export_dir.mkdir(parents=True, exist_ok=True)
        
        # Generate timestamp
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # Export files
        parquet_path = export_dir / f"unscheduled_patients_{timestamp}.parquet"
        csv_path = export_dir / f"unscheduled_patients_{timestamp}.csv"
        
        df.to_parquet(parquet_path, index=False)
        df.to_csv(csv_path, index=False)
        
        # Log summary
        logging.info("\nExport Summary:")
        logging.info(f"Database: {database_name or 'Default DB'}")
        logging.info(f"Total records: {len(df)}")
        logging.info(f"Columns: {', '.join(df.columns)}")
        if len(df) > 0:
            logging.info(f"Date range: {df['LastAptDateTime'].min()} to {df['LastAptDateTime'].max()}")
        logging.info(f"Files exported to:\n{parquet_path}\n{csv_path}")
        
    except Exception as e:
        logging.error(f"Export failed: {str(e)}")
        raise

if __name__ == "__main__":
    setup_logging("unscheduled_patients_export.log")
    export_unscheduled_patients() 