from pathlib import Path
import pandas as pd
from src.file_paths import DataPaths

def save_data(df: pd.DataFrame, prefix: str) -> Path:
    """Save data to CSV and Parquet"""
    data_paths = DataPaths()
    output_dir = data_paths.base_dir / "processed" / "treatment_journey_ml"
    output_dir.mkdir(parents=True, exist_ok=True)
    
    timestamp = pd.Timestamp.now().strftime("%Y%m%d_%H%M%S")
    base_path = output_dir / f"{prefix}_{timestamp}"
    
    # Save as parquet
    parquet_path = base_path.with_suffix('.parquet')
    df.to_parquet(parquet_path, index=False)
    
    # Save as CSV
    csv_path = base_path.with_suffix('.csv')
    df.to_csv(csv_path, index=False)
    
    return parquet_path