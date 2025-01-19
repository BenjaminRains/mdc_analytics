import logging
from pathlib import Path
from scripts.export.export_backup_to_local import export_backup_to_local

def setup_logging():
    """Configure logging for the export/import process"""
    log_dir = Path("logs")
    log_dir.mkdir(exist_ok=True)
    
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(log_dir / "export_import.log"),
            logging.StreamHandler()
        ]
    )

def run_export_import():
    """Runs the database export and import process"""
    setup_logging()
    logging.info("Starting export/import process...")
    
    # Export backup to local
    local_db_name = export_backup_to_local()
    
    logging.info(f"Export/import complete. Database created: {local_db_name}")
    return local_db_name

if __name__ == "__main__":
    database_name = run_export_import()
    print(f"Database export/import complete. Database available at: {database_name}") 