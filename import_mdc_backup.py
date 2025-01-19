import os
import logging
import time
from pathlib import Path
import mysql.connector
from dotenv import load_dotenv
from scripts.export.export_backup_to_local import export_backup_to_local

# Load environment variables
load_dotenv()

def setup_logging():
    """Configure logging for the database import process"""
    log_dir = Path("logs")
    log_dir.mkdir(exist_ok=True)
    
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(log_dir / "database_import.log"),
            logging.StreamHandler()
        ]
    )

def format_time(seconds):
    """Format seconds into hours, minutes, seconds"""
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    seconds = int(seconds % 60)
    return f"{hours:02d}:{minutes:02d}:{seconds:02d}"

def get_latest_backup():
    """Get the name of the most recent backup database (first one after 'opendental')"""
    try:
        config = {
            'host': '192.168.2.10',
            'user': 'bpr',
            'password': os.getenv('MDC_DB_PASSWORD'),
            'port': int(os.getenv('MDC_DB_PORT', '3306'))
        }
        
        logging.info("Connecting to MDC server to find latest backup...")
        conn = mysql.connector.connect(**config)
        
        if conn.is_connected():
            cursor = conn.cursor()
            
            # Get list of backup databases
            cursor.execute("SHOW DATABASES")
            databases = cursor.fetchall()
            
            # Find the backup that comes after 'opendental'
            found_opendental = False
            latest_backup = None
            
            for (db_name,) in databases:
                if not isinstance(db_name, str):
                    continue
                    
                if db_name == 'opendental':
                    found_opendental = True
                    continue
                    
                if found_opendental and db_name.startswith('opendentalbackup_'):
                    latest_backup = db_name
                    break
            
            if not latest_backup:
                raise Exception("No backup database found after 'opendental'")
            
            logging.info(f"Found latest backup: {latest_backup}")
            
            cursor.close()
            conn.close()
            return latest_backup
            
    except mysql.connector.Error as err:
        logging.error(f"MySQL Error: {err}")
        raise
    except Exception as e:
        logging.error(f"Error finding latest backup: {e}")
        raise

def import_mdc_backup():
    """Exports the latest backup from MDC server and imports to local MySQL"""
    setup_logging()
    import_start = time.time()
    logging.info("Starting database import from MDC server...")
    
    # Get latest backup name
    backup_db_name = get_latest_backup()
    logging.info(f"Using backup database: {backup_db_name}")
    
    # Export backup to local
    try:
        local_db_name = export_backup_to_local(backup_db_name)
    except Exception as e:
        logging.error(f"Failed to export backup: {str(e)}")
        raise
    
    # Log completion and duration
    total_duration = time.time() - import_start
    logging.info(f"Database import completed in {format_time(total_duration)}")
    logging.info(f"Database available at: {local_db_name}")
    
    return local_db_name

if __name__ == "__main__":
    try:
        database_name = import_mdc_backup()
        print(f"Database import complete. Database available at: {database_name}")
    except Exception as e:
        logging.error(f"Database import failed: {str(e)}")
        raise 