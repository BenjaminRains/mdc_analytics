import logging
from pathlib import Path
from scripts.export.export_backup_to_local import export_backup_to_local
from scripts.generate.treatment_journey_dataset import generate_treatment_journey_dataset

def setup_logging():
    """Configure logging for the pipeline"""
    log_dir = Path("logs")
    log_dir.mkdir(exist_ok=True)
    
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(log_dir / "pipeline.log"),
            logging.StreamHandler()
        ]
    )

def run_pipeline():
    """Runs the complete data pipeline"""
    setup_logging()
    logging.info("Starting pipeline...")
    
    # Create necessary directories
    Path("data/raw").mkdir(parents=True, exist_ok=True)
    Path("data/processed").mkdir(parents=True, exist_ok=True)
    
    # Step 1: Export backup to local
    local_db_name = export_backup_to_local()
    
    # Step 2: Generate dataset
    dataset_path = generate_treatment_journey_dataset(local_db_name)
    
    logging.info(f"Pipeline complete. Dataset at: {dataset_path}")
    return dataset_path

if __name__ == "__main__":
    dataset_path = run_pipeline()
    print(f"Pipeline complete. Dataset available at: {dataset_path}") 