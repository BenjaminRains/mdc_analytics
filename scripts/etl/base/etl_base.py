from abc import ABC, abstractmethod
from pathlib import Path
import logging
from typing import Optional
import pandas as pd
from src.file_paths import DataPaths

class ETLJob(ABC):
    """Base class for ETL jobs"""
    
    def __init__(self, database_name: str):
        self.database_name = database_name
        self.logger = logging.getLogger(self.__class__.__name__)
        self.data_paths = DataPaths()  # Initialize DataPaths
    
    @abstractmethod
    def setup(self) -> None:
        """Setup required for the ETL job (e.g., indexes)"""
        pass
    
    @abstractmethod
    def extract(self) -> pd.DataFrame:
        """Extract data from source"""
        pass
    
    @abstractmethod
    def transform(self, df: pd.DataFrame) -> pd.DataFrame:
        """Transform the data"""
        pass
    
    def load(self, df: pd.DataFrame) -> Path:
        """Load data to destination"""
        output_dir = self.data_paths.base_dir / "processed"
        output_dir.mkdir(parents=True, exist_ok=True)
        
        timestamp = pd.Timestamp.now().strftime("%Y%m%d_%H%M%S")
        output_path = output_dir / f"{self.__class__.__name__}_{timestamp}.parquet"
        
        df.to_parquet(
            output_path,
            engine='pyarrow',
            compression='snappy',
            index=False
        )
        return output_path
    
    def run(self) -> Path:
        """Run the complete ETL job"""
        self.logger.info(f"Starting ETL job for {self.database_name}")
        
        try:
            self.setup()
            df = self.extract()
            df = self.transform(df)
            output_path = self.load(df)
            self.logger.info(f"ETL job completed. Output saved to: {output_path}")
            return output_path
        except Exception as e:
            self.logger.error(f"ETL job failed: {str(e)}")
            raise
