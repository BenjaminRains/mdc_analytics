import logging
import time
from pathlib import Path
from scripts.export.export_backup_to_local import export_backup_to_local

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

def import_mdc_backup():
    """Exports the latest backup from MDC server and imports to local MySQL"""
    setup_logging()
    import_start = time.time()
    logging.info("Starting database import from MDC server...")
    
    # Export backup to local
    local_db_name = export_backup_to_local()
    
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