from pathlib import Path
import pandas as pd
from typing import Dict, List

def save_data(
    df: pd.DataFrame, 
    prefix: str,
    output_dir: Path,
    connection_type: str,
    formats: List[str] = ['parquet'],
    compression: str = 'snappy'
) -> Dict[str, Path]:
    """
    Save data in multiple formats
    
    Args:
        df: DataFrame to save
        prefix: Filename prefix
        output_dir: Directory to save files
        connection_type: Type of database connection (e.g., 'local_mariadb', 'local_mysql')
        formats: List of formats to save ['parquet', 'csv']
        compression: Compression type for parquet
    
    Returns:
        Dictionary of format: path pairs
    """
    output_dir.mkdir(parents=True, exist_ok=True)
    base_path = output_dir / f"{prefix}_{connection_type}"
    saved_paths = {}
    
    if 'parquet' in formats:
        parquet_path = base_path.with_suffix('.parquet')
        df.to_parquet(
            parquet_path,
            engine='pyarrow',
            compression=compression,
            index=False
        )
        saved_paths['parquet'] = parquet_path
        
    if 'csv' in formats:
        csv_path = base_path.with_suffix('.csv')
        df.to_csv(csv_path, index=False)
        saved_paths['csv'] = csv_path
    
    return saved_paths