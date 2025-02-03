from pathlib import Path
import logging
import pandas as pd
from datetime import datetime
from typing import Optional

from scripts.base.etl_base import ETLJob
from scripts.base.index_manager import IndexManager
from src.connections.factory import ConnectionFactory
from src.file_paths import DataPaths
from .transform import transform_data, calculate_metrics

class TreatmentJourneyETL(ETLJob):
    """ETL job for generating treatment journey dataset"""
    
    def __init__(self, database_name: str):
        super().__init__(database_name)
        # Use DataPaths for SQL files
        self.sql_dir = Path("scripts/sql/treatment_journey_ml")
        self.query_path = self.sql_dir / "query.sql"
        self.indexes_path = self.sql_dir / "indexes.sql"
        self.chunk_size = 10000
    
    def setup(self) -> None:
        """Setup required indexes"""
        self.logger.info("Setting up indexes...")
        index_manager = IndexManager(self.database_name)
        index_manager.setup_indexes(self.indexes_path)
    
    def extract(self) -> pd.DataFrame:
        """Execute main query with chunking"""
        self.logger.info("Extracting data...")
        
        with open(self.query_path, 'r') as f:
            query = f.read()
        
        chunks = []
        total_rows = 0
        
        conn = ConnectionFactory.create_connection('local_mariadb', self.database_name)
        with conn.get_connection() as connection:
            with connection.cursor(dictionary=True) as cursor:
                cursor.execute(query)
                while True:
                    chunk = cursor.fetchmany(self.chunk_size)
                    if not chunk:
                        break
                    chunks.append(pd.DataFrame(chunk))
                    total_rows += len(chunk)
                    self.logger.info(f"Processed {total_rows:,} rows...")
        
        return pd.concat(chunks, ignore_index=True)
    
    def transform(self, df: pd.DataFrame) -> pd.DataFrame:
        """Apply transformations using transform module"""
        self.logger.info("Transforming data...")
        df = transform_data(df)
        
        # Calculate and log metrics
        metrics = calculate_metrics(df)
        self.logger.info("Dataset metrics: %s", metrics)
        
        return df
    
    def load(self, df: pd.DataFrame) -> Path:
        """Save dataset to parquet"""
        self.logger.info("Saving dataset...")
        
        output_dir = Path("data/processed")
        output_dir.mkdir(parents=True, exist_ok=True)
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_path = output_dir / f"treatment_journey_{self.database_name}_{timestamp}.parquet"
        
        df.to_parquet(
            output_path,
            engine='pyarrow',
            compression='snappy',
            index=False
        )
        
        return output_path

def main(database_name: str) -> Optional[Path]:
    """Run the treatment journey ETL job"""
    try:
        etl_job = TreatmentJourneyETL(database_name)
        return etl_job.run()
    except Exception as e:
        logging.error(f"ETL job failed: {str(e)}")