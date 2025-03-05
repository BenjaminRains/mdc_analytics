# Fix for data directory path issue
# Copy this into your notebook

from pathlib import Path

# Update the data directory path to point to the correct location
# This is a relative path from the notebook location to the data directory
DATA_DIR = Path('../data/income_transfer_indicators')

# Function to load the most recent CSV files
def load_most_recent_data():
    """
    Load the most recent CSV files from the data directory
    Returns a dictionary of dataframes
    """
    # Get all CSV files in the directory
    csv_files = list(DATA_DIR.glob('*.csv'))
    
    # If no files, return empty dict
    if not csv_files:
        print("No CSV files found.")
        print(f"Looking in directory: {DATA_DIR.resolve()}")
        return {}
    
    # Get the most recent export date from filenames
    # Format: income_transfer_QUERYNAME_YYYYMMDD.csv
    dates = [f.name.split('_')[-1].replace('.csv', '') for f in csv_files if '_20' in f.name]
    if not dates:
        print("No valid dated CSV files found.")
        return {}
    
    most_recent_date = max(dates)
    print(f"Loading data from {most_recent_date}")
    
    # Load all CSV files for the most recent date
    dataframes = {}
    for csv_file in csv_files:
        if most_recent_date in csv_file.name:
            # Extract query name from filename
            # Format: income_transfer_QUERYNAME_YYYYMMDD.csv
            parts = csv_file.name.split('_')
            if len(parts) >= 3:
                # Join all middle parts to get the query name
                query_name = '_'.join(parts[2:-1])  # Skip first two parts (income_transfer) and last part (date.csv)
                
                print(f"Loading {query_name}...")
                import pandas as pd
                df = pd.read_csv(csv_file)
                dataframes[query_name] = df
    
    return dataframes

# Load the data
data = load_most_recent_data()

# Display available datasets
if data:
    print("\nAvailable datasets:")
    for name, df in data.items():
        print(f"- {name}: {df.shape[0]} rows, {df.shape[1]} columns")
else:
    print("No data available. Please run the export script first.") 