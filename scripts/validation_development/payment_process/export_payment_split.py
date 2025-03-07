"""
Export Payment Split Validation Data

This script connects to the specified database, loads a set of common table expressions (CTEs) 
from a separate file, and executes a series of SQL queries for payment split validation. 
The results for each query are exported to separate CSV files. The files are then analyzed 
in notebooks to identify and diagnose issues.

Usage:
    python export_payment_split_validation.py --start-date <YYYY-MM-DD> --end-date <YYYY-MM-DD>
                                                [--output-dir <path>] [--log-dir <path>]
                                                [--database <dbname>] [--queries <names>]
                                                [--connection-type <type>]
                                                [--parallel]

NOTE: The --start-date and --end-date parameters are REQUIRED. All data will be filtered 
to this date range, ensuring consistent results across all validation queries.

The list of queries and the common CTE definitions are stored as separate .sql files in
the 'queries' directory. The CTE file is prepended to each query before execution.
"""

from datetime import datetime, date, timedelta
import os
import logging
import pandas as pd
import re
import sys
from pathlib import Path
import argparse
import csv
import traceback
from dataclasses import dataclass
from typing import Optional, List, Dict, Any, Set, Tuple, NamedTuple
from dotenv import load_dotenv
import tempfile
import subprocess

# Configure basic logging until we can set up proper logging
logging.basicConfig(level=logging.INFO, 
                   format='%(asctime)s - %(levelname)s - %(message)s')

# Add base directory to path for relative imports if needed
script_dir = os.path.dirname(os.path.abspath(__file__))
base_dir = os.path.abspath(os.path.join(script_dir, '../..'))
if base_dir not in sys.path:
    sys.path.insert(0, base_dir)

# Add the src directory to the path to import project modules
src_path = Path(__file__).resolve().parents[3]
sys.path.append(str(src_path))

# Load environment variables from src/.env
env_path = src_path / "src" / ".env"
load_dotenv(dotenv_path=env_path)

# Import the ConnectionFactory from the src module
from src.connections.factory import ConnectionFactory, get_valid_databases

# Import DateRange from utils module
from scripts.validation_development.payment_process.utils.sql_export_utils import DateRange, apply_date_parameters

# Define regex pattern for include directives
INCLUDE_PATTERN = re.compile(r'<<include:([^>]+)>>')

# Add a SQLCache class near the top of the file, right after the imports
class SQLCache:
    """
    Cache for storing processed SQL content to avoid redundant processing.
    """
    def __init__(self):
        self.raw_sql_cache = {}  # Cache for raw SQL file content
        self.processed_sql_cache = {}  # Cache for processed SQL content (after includes)
        self.cte_dependencies = {}  # Cache for CTE dependencies
        self.date_parameterized_sql = {}  # Cache for date-parameterized SQL
        self.cache_hits = 0
        self.cache_misses = 0
    
    def get_raw_sql(self, file_path):
        """Get raw SQL content from cache or read from file."""
        if file_path in self.raw_sql_cache:
            self.cache_hits += 1
            return self.raw_sql_cache[file_path]
        
        self.cache_misses += 1
        # Read file directly instead of calling read_sql_file to avoid recursion
        try:
            with open(file_path, 'r') as f:
                content = f.read()
            self.raw_sql_cache[file_path] = content
            return content
        except Exception as e:
            logging.error(f"Error reading SQL file {file_path}: {str(e)}")
            return ""
    
    def get_processed_sql(self, file_path, base_dir=None):
        """Get processed SQL content (with includes resolved) from cache."""
        cache_key = f"{file_path}:{base_dir}"
        if cache_key in self.processed_sql_cache:
            self.cache_hits += 1
            return self.processed_sql_cache[cache_key]
        
        self.cache_misses += 1
        # Read raw content first (potentially from cache)
        raw_content = self.get_raw_sql(file_path)
        # Process includes
        processed_content = process_includes(raw_content, base_dir, cache=self)
        # Store in cache
        self.processed_sql_cache[cache_key] = processed_content
        return processed_content
    
    def get_parameterized_sql(self, file_path, date_range, base_dir=None):
        """Get SQL content with date parameters applied."""
        cache_key = f"{file_path}:{base_dir}:{date_range}"
        if cache_key in self.date_parameterized_sql:
            self.cache_hits += 1
            return self.date_parameterized_sql[cache_key]
        
        self.cache_misses += 1
        # Get processed content first (potentially from cache)
        processed_content = self.get_processed_sql(file_path, base_dir)
        # Apply date parameters
        parameterized_content = apply_date_parameters(processed_content, date_range)
        # Store in cache
        self.date_parameterized_sql[cache_key] = parameterized_content
        return parameterized_content
    
    def get_stats(self):
        """Get cache statistics."""
        total = self.cache_hits + self.cache_misses
        hit_rate = (self.cache_hits / total * 100) if total > 0 else 0
        return {
            "hits": self.cache_hits,
            "misses": self.cache_misses,
            "hit_rate": hit_rate,
            "raw_entries": len(self.raw_sql_cache),
            "processed_entries": len(self.processed_sql_cache),
            "parameterized_entries": len(self.date_parameterized_sql)
        }

# Create a global SQL cache instance
SQL_CACHE = SQLCache()

# Update the read_sql_file function to use the cache
def read_sql_file(file_path: str) -> str:
    """Read the contents of a SQL file."""
    # Use cache if available, but be careful not to create recursion
    if 'SQL_CACHE' in globals():
        # Check if the file is already in cache to avoid recursion
        if file_path in SQL_CACHE.raw_sql_cache:
            return SQL_CACHE.raw_sql_cache[file_path]
        
        # Read the file directly and store in cache
        try:
            with open(file_path, 'r') as f:
                content = f.read()
            # Store in cache for future lookups
            SQL_CACHE.raw_sql_cache[file_path] = content
            return content
        except Exception as e:
            logging.error(f"Error reading SQL file {file_path}: {str(e)}")
            return ""
    
    # Original implementation as fallback
    try:
        with open(file_path, 'r') as f:
            return f.read()
    except Exception as e:
        logging.error(f"Error reading SQL file {file_path}: {str(e)}")
        return ""

# Update the process_includes function to use the cache
def process_includes(sql_content: str, base_dir: Optional[str] = None, processed_files: Optional[set] = None, processed_ctes: Optional[dict] = None, cache=None) -> str:
    """
    Process include directives in SQL content by replacing <<include:filename.sql>> with 
    the content of the referenced file.
    
    Args:
        sql_content: SQL content to process
        base_dir: The base directory to look for included files (defaults to queries/ctes)
        processed_files: Set of already processed files to prevent infinite recursion
        processed_ctes: Dictionary of already processed CTE names and their contents to prevent duplicates
        cache: SQL cache instance to use
        
    Returns:
        SQL content with includes replaced and properly formatted
    """
    if processed_files is None:
        processed_files = set()
    
    if processed_ctes is None:
        processed_ctes = {}
    
    if base_dir is None:
        base_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'queries', 'ctes')
    
    # Convert base_dir to Path object for easier path manipulation
    base_dir_path = Path(base_dir)
    queries_dir = base_dir_path.parent if base_dir_path.name == 'ctes' else base_dir_path
    
    # Find all include directives in the content
    include_pattern = r'<<include:([^>]+)>>'
    includes = re.findall(include_pattern, sql_content)
    
    if not includes:
        return sql_content
        
    logging.info(f"Found include directives in SQL, processing...")
    
    # Process each include directive
    for include_path in includes:
        # Determine the correct path to the include file
        if include_path.startswith('ctes/'):
            include_file = queries_dir / include_path
        else:
            include_file = base_dir_path / include_path
            if not include_file.exists() and base_dir_path.name != 'ctes':
                include_file = base_dir_path / 'ctes' / include_path
        
        include_path_str = str(include_file)
        
        # Check if file exists
        if not include_file.exists():
            logging.warning(f"Could not find included file: {include_file}")
            sql_content = sql_content.replace(f'<<include:{include_path}>>', '')
            continue
            
        # Skip if we've already processed this file to avoid circular inclusion
        # but don't log a warning, as our CTE topological sorting will handle dependencies
        if include_path_str in processed_files:
            sql_content = sql_content.replace(f'<<include:{include_path}>>', '')
            continue
            
        # Add file to processed files to prevent circular recursion
        processed_files.add(include_path_str)
        
        # Try to get content from cache first
        if cache is not None:
            included_content = cache.get_raw_sql(include_path_str)
            
            # Process includes in the included file recursively
            if included_content:
                processed_included_content = process_includes(
                    included_content,
                    os.path.dirname(include_path_str),
                    processed_files.copy(),  # Use a copy to prevent cross-contamination between branches
                    processed_ctes,
                    cache=cache
                )
        else:
            # Read the include file content directly
            included_content = read_sql_file(include_path_str)
            
            # Process includes in the included file recursively
            if included_content:
                processed_included_content = process_includes(
                    included_content,
                    os.path.dirname(include_path_str),
                    processed_files.copy(),  # Use a copy to prevent cross-contamination between branches
                    processed_ctes
                )
            
        # Replace the include directive with the processed content
        sql_content = sql_content.replace(f'<<include:{include_path}>>', processed_included_content)
    
    logging.info(f"Successfully processed includes in SQL")
    return sql_content

# Get the list of valid databases from environment
try:
    # Use get_valid_databases from factory
    valid_databases = get_valid_databases('LOCAL_VALID_DATABASES')
except Exception as e:
    logging.warning(f"Could not get valid databases: {str(e)}")
    valid_databases = []

# Get default database from environment (use ODDB_NAME as fallback)
default_database = os.getenv('MARIADB_DATABASE') or os.getenv('ODDB_NAME')
if not default_database and valid_databases:
    default_database = valid_databases[0]  # Use first valid database as default if available

# Query descriptions to provide context on what each query analyzes
QUERY_DESCRIPTIONS = {
    'summary': 'High-level summary of payment splits and associated metrics',
    'base_counts': 'Basic count statistics of payments and procedures',
    'source_counts': 'Analysis of payment sources and their distribution',
    'filter_summary': 'Summary of how filters affect the dataset',
    'diagnostic': 'Detailed diagnostic information for troubleshooting',
    'verification': 'Verification of data integrity and consistency',
    'problems': 'Identification of potential issues in payment splits',
    'duplicate_joins': 'Analysis of duplicate join conditions',
    'join_stages': 'Progression of join operations and their effects',
    'daily_patterns': 'Day-by-day analysis of payment patterns',
    'payment_details': 'Detailed information about individual payments',
    'containment': 'Analysis of payment containment relationships',
}

def setup_logging(log_dir='scripts/validation/payment_split/logs'):
    """Set up logging to file and console."""
    # Ensure log directory exists
    os.makedirs(log_dir, exist_ok=True)
    
    # Set up timestamp for log filename
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = os.path.join(log_dir, f"payment_validation_{timestamp}.log")
    
    # Reset logging configuration
    for handler in logging.root.handlers[:]:
        logging.root.removeHandler(handler)
    
    # Configure logging
    logging.basicConfig(
        level=logging.INFO,  # Root logger level set to INFO
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            # File handler with DEBUG level for detailed troubleshooting
            logging.FileHandler(log_file),
            # Console handler with INFO level
            logging.StreamHandler()
        ]
    )
    
    # Set file handler to DEBUG level to capture detailed logs
    logging.getLogger().handlers[0].setLevel(logging.DEBUG)
    # Set console handler to INFO level for cleaner output
    logging.getLogger().handlers[1].setLevel(logging.INFO)
    
    logging.info(f"Logging configured - writing detailed logs to {log_file}")
    return log_file

def ensure_directory_exists(directory):
    """Create directory if it doesn't exist."""
    Path(directory).mkdir(parents=True, exist_ok=True)
    logging.info(f"Ensured directory exists: {directory}")

def load_query_file(query_name: str) -> str:
    """Load a query from the queries directory using pathlib."""
    query_path = Path(__file__).parent / 'queries' / f'{query_name}.sql'
    return read_sql_file(query_path)

# Define MariaDB specific SQL validation checks
def check_mariadb_syntax(sql_content: str) -> tuple:
    """
    Perform MariaDB-specific SQL syntax and best practices checks.
    
    Args:
        sql_content: SQL content to check
        
    Returns:
        Tuple of (is_valid, issues_found, warnings_found)
    """
    is_valid = True
    issues = []
    warnings = []
    
    # Check for MariaDB-specific syntax issues
    
    # 1. Check for LIMIT clause in subqueries without ORDER BY
    # MariaDB's behavior with LIMIT without ORDER BY can be unpredictable
    limit_without_order_pattern = r'\(\s*SELECT\s+.*\s+LIMIT\s+\d+(?:\s*,\s*\d+)?\s*\)'
    if re.search(limit_without_order_pattern, sql_content, re.IGNORECASE) and not re.search(r'ORDER\s+BY', sql_content, re.IGNORECASE):
        warnings.append("Found LIMIT in subquery without ORDER BY, which may lead to unpredictable results")
    
    # 2. Check for proper date literal format
    # MariaDB prefers ISO format for date literals
    if re.search(r"'\d{1,2}/\d{1,2}/\d{2,4}'", sql_content):
        warnings.append("Non-ISO date format detected. Use ISO format ('YYYY-MM-DD') for best compatibility")
    
    # 3. Check for JOIN without ON condition
    if re.search(r'JOIN\s+\w+(?:\s+\w+)?\s+(?:ON|USING)', sql_content, re.IGNORECASE) is None and 'JOIN' in sql_content.upper():
        is_valid = False
        issues.append("JOIN without ON or USING clause detected")
    
    # 4. Check for potentially unsafe GROUP BY usage
    # In MariaDB/MySQL, columns in SELECT that aren't aggregated must be in GROUP BY
    group_by_match = re.search(r'GROUP\s+BY\s+(.*?)(?:HAVING|ORDER\s+BY|LIMIT|$)', sql_content, re.IGNORECASE | re.DOTALL)
    select_match = re.search(r'SELECT\s+(.*?)\s+FROM', sql_content, re.IGNORECASE | re.DOTALL)
    
    if group_by_match and select_match:
        group_by_cols = set(re.findall(r'(\w+(?:\.\w+)?)', group_by_match.group(1)))
        select_cols = []
        
        # Extract column names from SELECT, ignoring aggregate functions
        select_text = select_match.group(1)
        # Remove aggregate function expressions
        clean_select = re.sub(r'(COUNT|SUM|AVG|MIN|MAX|GROUP_CONCAT)\s*\([^)]*\)', '', select_text, flags=re.IGNORECASE)
        # Find remaining columns
        select_cols = set(re.findall(r'(\w+(?:\.\w+)?)', clean_select))
        
        # Find columns in SELECT that aren't in GROUP BY
        missing_cols = select_cols - group_by_cols
        if missing_cols and not '*' in select_text:
            warnings.append(f"Columns in SELECT not present in GROUP BY: {', '.join(missing_cols)}. This may cause unpredictable results.")
    
    # 5. Check for SQL_MODE issues
    # MariaDB's default SQL_MODE can cause issues with GROUP BY, strict mode, etc.
    if 'GROUP BY' in sql_content.upper() and not any(fn in sql_content.upper() for fn in ['SUM(', 'COUNT(', 'AVG(', 'MIN(', 'MAX(']):
        warnings.append("GROUP BY without aggregate functions detected. This may behave differently in MariaDB's default SQL_MODE.")
    
    # 6. Check for backtick usage consistency
    # Consistent use of backticks is recommended for MariaDB
    if '`' in sql_content:
        table_pattern = r'FROM\s+([^\s,]+)'
        tables = re.findall(table_pattern, sql_content, re.IGNORECASE)
        for table in tables:
            if not table.startswith('`') and not table.endswith('`') and '.' not in table and not table.upper() in ('WHERE', 'JOIN', 'INNER', 'LEFT', 'RIGHT'):
                warnings.append(f"Inconsistent backtick usage: table '{table}' is not enclosed in backticks")
    
    # 7. Check for deprecated MariaDB syntax
    if 'TYPE=InnoDB' in sql_content:
        warnings.append("Deprecated syntax 'TYPE=InnoDB' detected. Use 'ENGINE=InnoDB' instead.")
    
    return is_valid, issues, warnings

# Update the check_sql_syntax function to include MariaDB-specific checks
def check_sql_syntax(sql_content: str) -> tuple:
    """
    Check SQL syntax for common issues after processing includes.
    
    Args:
        sql_content: SQL content to check
        
    Returns:
        Tuple of (is_valid, issues_found)
    """
    is_valid = True
    issues = []
    
    # Check for unprocessed include directives
    include_matches = INCLUDE_PATTERN.findall(sql_content)
    if include_matches:
        is_valid = False
        issues.append(f"Unprocessed include directives found: {include_matches}")
    
    # Check for multiple WITH statements (MariaDB only supports one)
    with_matches = re.findall(r'^\s*WITH\s+', sql_content, re.MULTILINE | re.IGNORECASE)
    if len(with_matches) > 1:
        is_valid = False
        issues.append(f"Multiple WITH statements found: {len(with_matches)}. MariaDB only supports one WITH clause.")
    
    # Check for missing commas between CTEs
    if re.search(r'\)\s+([A-Za-z][A-Za-z0-9_]*)\s+AS\s*\(', sql_content) and not re.search(r'\),\s+[A-Za-z][A-Za-z0-9_]*\s+AS\s*\(', sql_content):
        is_valid = False
        issues.append("Missing commas between CTE definitions")
    
    # Check for missing semicolons at the end of statements
    if not sql_content.strip().endswith(';'):
        # If this is a SELECT statement and doesn't end with a semicolon, suggest adding one
        if re.search(r'^\s*(?:WITH\s+)?.*SELECT\s', sql_content, re.IGNORECASE | re.DOTALL):
            issues.append("Query does not end with a semicolon, which is recommended for MariaDB statements")
    
    # Very basic checks for common syntax errors
    common_errors = [
        (r'FROM\s+FROM', "Duplicate FROM keyword found"),
        (r'WHERE\s+WHERE', "Duplicate WHERE keyword found"),
        (r'SELECT\s+SELECT', "Duplicate SELECT keyword found"),
        (r'GROUP\s+GROUP', "Duplicate GROUP keyword found"),
        (r'ORDER\s+ORDER', "Duplicate ORDER keyword found"),
        (r'BY\s+BY', "Duplicate BY keyword found"),
        (r'HAVING\s+HAVING', "Duplicate HAVING keyword found"),
        (r'JOIN\s+JOIN', "Duplicate JOIN keyword found"),
        (r'FROM\s+WHERE', "Missing table specification in FROM clause"),
        (r'WHERE\s+ORDER', "Missing condition in WHERE clause"),
        (r'GROUP\s+HAVING', "Missing columns in GROUP BY clause"),
        (r'SELECT\s+FROM', "Missing columns in SELECT clause")
    ]
    
    for pattern, message in common_errors:
        if re.search(pattern, sql_content, re.IGNORECASE):
            is_valid = False
            issues.append(message)
    
    # Run MariaDB-specific syntax checks
    mariadb_valid, mariadb_issues, mariadb_warnings = check_mariadb_syntax(sql_content)
    
    if not mariadb_valid:
        is_valid = False
        issues.extend(mariadb_issues)
    
    # Add warnings as informational issues
    for warning in mariadb_warnings:
        issues.append(f"Warning: {warning}")
    
    return is_valid, issues

def generate_cte_dependency_graph(cte_dependencies, output_path=None):
    """
    Generate a visualization of CTE dependencies using GraphViz.
    
    Args:
        cte_dependencies: Dictionary mapping CTE names to their dependencies
        output_path: Optional path to save the visualization (without extension)
                    If None, saves to the output directory with timestamp
    
    Returns:
        Path to the generated image file or None if generation failed
    """
    try:
        # Check if we have any dependencies to visualize
        if not cte_dependencies:
            logging.warning("No CTE dependencies to visualize")
            return None
            
        # Import graphviz if available (don't make it a hard dependency)
        try:
            import graphviz
            has_graphviz_lib = True
            logging.info("Using Python graphviz library for dependency visualization")
        except ImportError:
            has_graphviz_lib = False
            logging.warning("Python graphviz library not installed. Install with 'pip install graphviz' for better visualizations.")
            logging.info("Falling back to DOT file generation only")
        
        # Create DOT contents directly (ensures we always generate a DOT file even without the library)
        dot_contents = """digraph "CTE Dependencies" {
            // CTE Dependency Visualization
            rankdir=LR;
            size="10,8";
            ratio=fill;
            fontsize=14;
            ranksep=1.5;
            nodesep=0.5;
            node [shape=box, style=filled, color=lightblue];
        """
        
        # Add nodes for CTEs
        for cte_name in cte_dependencies:
            dot_contents += f'    "{cte_name}" [label="{cte_name}"];\n'
        
        # Add edges for dependencies
        for cte_name, deps in cte_dependencies.items():
            for dep in deps:
                dot_contents += f'    "{dep}" -> "{cte_name}";\n'
        
        # Close DOT file
        dot_contents += "}\n"
        
        # Set default output path if not provided
        if output_path is None:
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            output_dir = Path(os.path.dirname(os.path.abspath(__file__))) / 'output' / 'dependencies'
            output_dir.mkdir(parents=True, exist_ok=True)
            output_path = str(output_dir / f'cte_dependencies_{timestamp}')
        
        # Always write the DOT file
        dot_file = f"{output_path}.dot"
        with open(dot_file, 'w') as f:
            f.write(dot_contents)
        logging.info(f"Generated DOT file at {dot_file}")
        
        # Also write as .gv for compatibility
        gv_file = f"{output_path}.gv"
        with open(gv_file, 'w') as f:
            f.write(dot_contents)
        
        # Try to render using Python library if available
        if has_graphviz_lib:
            try:
                # Create a Digraph object for rendering
                dot = graphviz.Source(dot_contents)
                # Render to PNG
                png_file = dot.render(outfile=f"{output_path}.png", format='png', cleanup=False)
                logging.info(f"Generated dependency visualization PNG at {png_file}")
                return png_file
            except Exception as e:
                logging.warning(f"Error rendering with Python graphviz library: {str(e)}")
                logging.info("Falling back to system graphviz command")
                has_graphviz_lib = False
        
        # Try using system command-line graphviz if Python library failed or is not available
        if not has_graphviz_lib:
            try:
                # Use subprocess to call dot command
                png_file = f"{output_path}.png"
                
                # First try the normal PATH lookup
                try:
                    subprocess.run(['dot', '-Tpng', dot_file, '-o', png_file], 
                                  check=True, capture_output=True, text=True)
                    logging.info(f"Generated dependency visualization PNG at {png_file} using system graphviz")
                    return png_file
                except FileNotFoundError:
                    # If dot command not found, try common installation locations on Windows
                    graphviz_candidates = [
                        r"C:\Program Files\GraphViz\Graphviz-12.2.1-win64\bin\dot.exe",
                        r"C:\Program Files\GraphViz\bin\dot.exe",
                        r"C:\Program Files (x86)\GraphViz\bin\dot.exe",
                        r"C:\GraphViz\bin\dot.exe"
                    ]
                    
                    for dot_path in graphviz_candidates:
                        if os.path.isfile(dot_path):
                            try:
                                subprocess.run([dot_path, '-Tpng', dot_file, '-o', png_file], 
                                              check=True, capture_output=True, text=True)
                                logging.info(f"Generated dependency visualization PNG at {png_file} using {dot_path}")
                                return png_file
                            except subprocess.CalledProcessError as e:
                                logging.warning(f"GraphViz command failed with {dot_path}: {e.stderr}")
                                continue
                    
                    # If we get here, all attempts failed
                    logging.warning("GraphViz not installed or not in PATH. Only DOT file generated.")
                    logging.info("To generate visualizations, install GraphViz from https://graphviz.org/download/")
                    return dot_file
                            
            except subprocess.CalledProcessError as e:
                logging.warning(f"GraphViz system command failed: {e.stderr}")
                return dot_file
        
        return dot_file
        
    except Exception as e:
        logging.error(f"Error generating CTE dependency graph: {str(e)}", exc_info=True)
        return None

def get_ctes(date_range: DateRange = None) -> str:
    """
    Load and combine all CTE definitions.
    
    Args:
        date_range: Optional date range to apply to queries
        
    Returns:
        Combined CTE SQL content
    """
    # Find all CTE files
    cte_dir = Path(os.path.dirname(os.path.abspath(__file__))) / 'queries' / 'ctes'
    if not cte_dir.exists():
        logging.error(f"CTE directory not found: {cte_dir}")
        return ""
    
    # Get all SQL files
    cte_files = list(cte_dir.glob('*.sql'))
    if not cte_files:
        logging.warning(f"No CTE files found in {cte_dir}")
        return ""
    
    logging.info(f"Found {len(cte_files)} CTE definition files")
    
    # Track processed dependencies to avoid duplicates
    dependencies_processed = set()
    all_ctes = []
    processed_cte_names = set()
    
    # Dictionary to store CTE definitions with their name as key
    cte_definitions = {}
    
    # Dictionary to track dependencies between CTEs
    cte_dependencies = {}
    
    # First pass: load all CTE definitions and extract their names
    for cte_file in cte_files:
        try:
            logging.debug(f"Loading CTE file: {cte_file}")
            
            # Skip if already processed
            if str(cte_file) in dependencies_processed:
                logging.debug(f"Already processed CTE file: {cte_file}")
                continue
            
            # Read the file content
            cte_content = read_sql_file(str(cte_file))
            if not cte_content:
                logging.warning(f"Empty or invalid CTE file: {cte_file}")
                continue
                
            # Process includes within the CTE
            cte_content = process_includes(cte_content)
            
            # Add to processed dependencies
            dependencies_processed.add(str(cte_file))
            
            # Check for SQL syntax issues
            is_valid, issues = check_sql_syntax(cte_content)
            if not is_valid:
                logging.warning(f"SQL syntax issues in {cte_file} after processing includes:")
                for issue in issues:
                    logging.warning(f"  - {issue}")
            
            # Apply date parameters
            if cte_content:
                cte_content = apply_date_parameters(cte_content, date_range)
                
                # Extract just the CTE definition (strip out any WITH keywords)
                # Look for pattern like "WITH CTE_Name AS (" or just "CTE_Name AS ("
                cte_content = cte_content.strip()
                cte_match = re.search(r'(?:WITH\s+)?(\w+\s+AS\s*\(.*)', cte_content, re.DOTALL | re.IGNORECASE)
                if cte_match:
                    cte_definition = cte_match.group(1).strip()
                    
                    # Extract CTE name
                    cte_name_match = re.match(r'^(\w+)\s+AS\s*\(', cte_definition)
                    if cte_name_match:
                        cte_name = cte_name_match.group(1)
                        
                        # Store the CTE definition with its name
                        cte_with_comment = f"""
-- From {cte_file.name}
{cte_definition}"""
                        cte_definitions[cte_name] = cte_with_comment
                        
                        # Initialize empty dependency list for this CTE
                        cte_dependencies[cte_name] = set()
                        
                        logging.debug(f"Identified CTE: {cte_name} from {cte_file.name}")
                    else:
                        logging.warning(f"Could not extract CTE name from {cte_file.name}")
                else:
                    logging.warning(f"Could not extract CTE definition from {cte_file.name}")
        except Exception as e:
            logging.error(f"Error loading CTE file {cte_file}: {str(e)}", exc_info=True)
    
    # Second pass: analyze dependencies between CTEs
    for cte_name, cte_definition in cte_definitions.items():
        # Look for references to other CTEs in this definition
        for other_cte_name in cte_definitions.keys():
            if other_cte_name != cte_name and re.search(r'\b' + re.escape(other_cte_name) + r'\b', cte_definition):
                # This CTE depends on other_cte_name
                cte_dependencies[cte_name].add(other_cte_name)
                logging.debug(f"CTE {cte_name} depends on {other_cte_name}")
    
    # Store dependencies in the cache for visualization
    SQL_CACHE.cte_dependencies = cte_dependencies
    
    # Function to perform topological sort
    def topological_sort():
        # Track visited nodes and detect cycles
        visited = set()
        temp_visited = set()
        result = []
        
        def visit(node):
            if node in temp_visited:
                # This is a cycle, but we'll still include the node
                logging.warning(f"Circular dependency detected involving CTE: {node}")
                return
            
            if node in visited:
                return
                
            temp_visited.add(node)
            
            # Visit dependencies first
            for dependency in cte_dependencies.get(node, set()):
                visit(dependency)
                
            temp_visited.remove(node)
            visited.add(node)
            result.append(node)
            
        # Visit each node
        for node in list(cte_dependencies.keys()):
            if node not in visited:
                visit(node)
                
        return result
    
    # Get sorted CTEs
    sorted_ctes = topological_sort()
    logging.info(f"Ordered {len(sorted_ctes)} CTEs based on dependencies")
    
    # Build the combined CTEs in the sorted order
    all_ctes = [cte_definitions[cte_name] for cte_name in sorted_ctes]
    
    # Join all CTEs with appropriate separators and WITH clause
    if not all_ctes:
        logging.warning("No CTEs were loaded successfully")
        return ""
    
    # Start with the WITH keyword
    combined_ctes = "WITH "
    
    # Add each CTE with proper comma separation
    for i, cte_definition in enumerate(all_ctes):
        if i > 0:
            # If not the first CTE, add a comma and newline
            combined_ctes += ",\n"
        
        # Add the CTE definition, ensuring it doesn't have a leading WITH
        if i == 0:
            # For the first CTE, we might need to strip "WITH" keyword if present
            clean_cte = re.sub(r'^\s*WITH\s+', '', cte_definition.strip(), flags=re.IGNORECASE)
            combined_ctes += clean_cte
        else:
            # For subsequent CTEs, just strip any WITH keyword
            clean_cte = re.sub(r'^\s*WITH\s+', '', cte_definition.strip(), flags=re.IGNORECASE)
            combined_ctes += clean_cte
    
    logging.info(f"Combined {len(all_ctes)} CTEs into query structure")
    
    # Final check on combined CTEs
    is_valid, issues = check_sql_syntax(combined_ctes)
    if not is_valid:
        logging.warning("SQL syntax issues in combined CTEs:")
        for issue in issues:
            logging.warning(f"  - {issue}")
    
    return combined_ctes

def extract_ctes_and_query(sql_content):
    """
    Extract all CTE definitions and the main query from SQL content.
    Handles multiple CTEs and properly separates them from the main query.
    Also adds missing commas between CTE definitions automatically.
    
    Args:
        sql_content: The SQL content to parse
        
    Returns:
        tuple: (CTEs as string, main query as string)
    """
    # Split the SQL content into lines for easier processing
    lines = sql_content.split('\n')
    
    # Keep track of CTEs and the main query
    cte_lines = []
    current_cte_lines = []
    main_query_lines = []
    in_cte = False
    open_parens = 0
    
    # Regular expression to match the start of a CTE definition
    cte_pattern = re.compile(r'^\s*(WITH\s+)?([A-Za-z][A-Za-z0-9_]*)\s+AS\s*\(\s*$', re.IGNORECASE)
    
    # Process each line
    for i, line in enumerate(lines):
        # Skip empty lines and comments at the beginning
        stripped_line = line.strip()
        if not stripped_line or stripped_line.startswith('--'):
            continue
            
        # Check if this line contains the start of a CTE
        cte_match = cte_pattern.match(stripped_line)
        
        if cte_match and not in_cte:
            # Found the start of a CTE
            in_cte = True
            open_parens = 1  # Count the opening parenthesis
            
            # Check if this is the first CTE with a WITH keyword
            with_keyword = cte_match.group(1)
            if with_keyword:
                current_cte_lines.append(stripped_line)
            else:
                # If not the first CTE, we might need to add the WITH keyword
                if not cte_lines:
                    current_cte_lines.append(f"WITH {stripped_line}")
                else:
                    current_cte_lines.append(stripped_line)
        elif in_cte:
            # We're inside a CTE definition
            current_cte_lines.append(stripped_line)
            
            # Count parentheses to track nesting
            open_parens += stripped_line.count('(')
            open_parens -= stripped_line.count(')')
            
            # Check if we've closed all parentheses for this CTE
            if open_parens == 0:
                # This CTE is complete
                cte_lines.append('\n'.join(current_cte_lines))
                current_cte_lines = []
                in_cte = False
        else:
            # We're in the main query
            main_query_lines.append(stripped_line)
    
    # If we still have an open CTE, add it
    if current_cte_lines:
        cte_lines.append('\n'.join(current_cte_lines))
    
    # Combine all main query lines
    main_query = '\n'.join(main_query_lines)
    
    # Handle the case where the main query is part of the last CTE
    # This happens when there's a SELECT statement right after the last CTE without proper separation
    if cte_lines and not main_query:
        select_match = re.search(r'(SELECT\s+.+)', cte_lines[-1], re.IGNORECASE | re.DOTALL)
        if select_match:
            main_query = select_match.group(1).strip()
            # Remove the main query part from the last CTE
            cte_lines[-1] = cte_lines[-1][:select_match.start(1)].rstrip()
    
    # Combine all CTEs into a single string with proper WITH clause and commas if needed
    if cte_lines:
        # Process the first CTE
        first_cte = cte_lines[0]
        if first_cte.strip().upper().startswith('WITH '):
            all_ctes = first_cte
        else:
            all_ctes = 'WITH ' + first_cte
        
        # Add remaining CTEs with proper commas
        for cte in cte_lines[1:]:
            # Check if the previous CTE ends with ')' and the current one starts with a CTE name
            # If so, add a comma between them
            all_ctes += ',\n' + cte
    else:
        all_ctes = ''
    
    # Add a semicolon to the main query if it doesn't have one and is not empty
    if main_query and not main_query.strip().endswith(';'):
        main_query = main_query.rstrip() + ';'
    
    return all_ctes, main_query

def balance_parentheses(sql_content: str) -> str:
    """
    Ensure that parentheses are balanced in the SQL content.
    If there are more opening parentheses than closing ones, add the missing closing parentheses.
    
    Args:
        sql_content: SQL content to check
        
    Returns:
        SQL content with balanced parentheses
    """
    # Count parentheses excluding those in string literals and comments
    open_count = 0
    close_count = 0
    in_string = False
    string_char = None
    in_comment = False
    in_line_comment = False
    
    for i, char in enumerate(sql_content):
        # Check for string boundaries
        if char in ("'", '"') and not in_comment and not in_line_comment:
            if not in_string:
                in_string = True
                string_char = char
            elif char == string_char:
                # Check for escaped quotes
                if i > 0 and sql_content[i-1] == '\\':
                    # This is an escaped quote
                    pass
                else:
                    in_string = False
                    string_char = None
        
        # Check for comment boundaries
        elif char == '-' and i+1 < len(sql_content) and sql_content[i+1] == '-' and not in_string and not in_comment:
            in_line_comment = True
        elif char == '\n' and in_line_comment:
            in_line_comment = False
        elif char == '/' and i+1 < len(sql_content) and sql_content[i+1] == '*' and not in_string and not in_comment:
            in_comment = True
        elif char == '*' and i+1 < len(sql_content) and sql_content[i+1] == '/' and in_comment:
            in_comment = False
        
        # Count parentheses only outside of strings and comments
        elif not in_string and not in_comment and not in_line_comment:
            if char == '(':
                open_count += 1
            elif char == ')':
                close_count += 1
    
    # Add missing parentheses
    if open_count > close_count:
        # Add missing closing parentheses at the end
        sql_content = sql_content.rstrip() + ')' * (open_count - close_count)
        logging.info(f"Added {open_count - close_count} closing parentheses to balance the SQL")
    elif close_count > open_count:
        # Add missing opening parentheses at the beginning
        sql_content = '(' * (close_count - open_count) + sql_content.lstrip()
        logging.info(f"Added {close_count - open_count} opening parentheses to balance the SQL")
    
    return sql_content

def get_query(query_name: str, date_range: DateRange = None) -> dict:
    """
    Get a query by name, process its includes, and apply date parameters.
    
    Args:
        query_name: Name of the query file (without .sql extension)
        date_range: DateRange object with start and end dates
        
    Returns:
        Dict with {'name': query_name, 'sql': sql_content}
    """
    # Add .sql extension if missing
    if not query_name.endswith('.sql'):
        query_name += '.sql'
        
    # Get the query file path
    query_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'queries')
    query_file = os.path.join(query_dir, query_name)
    
    # Verify the file exists
    if not os.path.exists(query_file):
        logging.error(f"Query file not found: {query_file}")
        return {'name': query_name, 'sql': '', 'error': 'Query file not found'}
        
    try:
        logging.info(f"Found include directives in {query_name}, processing...")
        
        # Use cache to get processed SQL with parameters applied
        sql_content = SQL_CACHE.get_parameterized_sql(query_file, date_range, query_dir)
        
        # Extract CTEs and main query, balance parentheses
        ctes, main_query = extract_ctes_and_query(sql_content)
        
        # Ensure ctes is a string, not a list
        if isinstance(ctes, list):
            ctes = "\n".join(ctes)
        
        # Get the list of all pre-defined CTEs for this date range (which already includes "WITH")
        predefined_ctes = get_ctes(date_range)
        
        # Combine the CTEs and main query
        if predefined_ctes and ctes:
            # Both predefined CTEs and query-specific CTEs
            
            # If query-specific CTEs have "WITH", strip it
            if ctes.strip().upper().startswith('WITH '):
                query_ctes = ctes.strip()[5:].strip()
            else:
                query_ctes = ctes.strip()
            
            # If predefined CTEs have WITH but no ending comma, add one
            if predefined_ctes.strip().endswith(')') or not predefined_ctes.strip().endswith(','):
                predefined_ctes = predefined_ctes.rstrip() + ','
            
            # Combine everything
            final_sql = predefined_ctes + "\n" + query_ctes + "\n" + main_query
            
        elif predefined_ctes:
            # Only predefined CTEs
            final_sql = predefined_ctes + "\n" + main_query
            
        elif ctes:
            # Only query-specific CTEs
            final_sql = ctes + "\n" + main_query
            
        else:
            # No CTEs at all
            final_sql = main_query
                
        # Balance parentheses in the final SQL
        final_sql = balance_parentheses(final_sql)
        
        # Perform SQL syntax check
        is_valid, issues = check_sql_syntax(final_sql)
        if not is_valid:
            logging.warning(f"SQL syntax issues in query {query_name}:")
            for issue in issues:
                logging.warning(f"  - {issue}")
                
        return {'name': query_name, 'sql': final_sql}
        
    except Exception as e:
        logging.error(f"Error processing query {query_name}: {str(e)}", exc_info=True)
        return {'name': query_name, 'sql': '', 'error': str(e)}

def get_exports(date_range: DateRange = None) -> list:
    """
    Get the list of export queries to run.
    
    Args:
        date_range: DateRange object with start and end dates
        
    Returns:
        List of export configurations
    """
    # Require a DateRange to be provided
    if date_range is None:
        raise ValueError("Date range must be provided")
    
    # List of allowed queries to process
    allowed_queries = [
        "base_counts.sql",
        "containment.sql",
        "daily_patterns.sql",
        "diagnostic.sql",
        "duplicate_joins.sql",
        "filter_summary.sql",
        "join_stages.sql",
        "payment_details.sql",
        "problems.sql",
        "source_counts.sql",
        "summary.sql",
        "verification.sql"
    ]
    
    # Get available export queries
    query_exports = []
    queries_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'queries')
    
    if os.path.isdir(queries_dir):
        # Process only the allowed query files
        for query_file in allowed_queries:
            query_path = os.path.join(queries_dir, query_file)
            if os.path.exists(query_path):
                query_name = os.path.splitext(query_file)[0]
                query_exports.append(query_name)
                logging.info(f"Found query file: {query_file}")
            else:
                logging.warning(f"Query file not found: {query_file}")
    
    if not query_exports:
        # Raise an error when no queries are found
        error_msg = "No query files found in the queries directory or none of the allowed queries exist"
        logging.error(error_msg)
        raise ValueError(error_msg)
    
    # Create the export configurations
    exports = []
    for query_name in query_exports:
        query_config = get_query(query_name, date_range=date_range)
        if query_config:  # Only add if we got a valid config
            exports.append(query_config)
            logging.info(f"Prepared export configuration for: {query_name}")
    
    return exports

def analyze_execution_plan(sql_content: str, connection) -> tuple:
    """
    Analyze the execution plan of a SQL query to detect potential performance issues.
    
    Args:
        sql_content: SQL content to analyze
        connection: Database connection to use
        
    Returns:
        Tuple of (plan_available, warnings)
    """
    warnings = []
    plan_available = False
    
    try:
        # Check if this is a SELECT query (EXPLAIN only works on SELECT)
        if not re.match(r'^\s*(?:WITH\s+.*\s+)?SELECT', sql_content, re.IGNORECASE | re.DOTALL):
            return False, ["Execution plan analysis only available for SELECT queries"]
        
        # Add EXPLAIN prefix to the query
        explain_query = "EXPLAIN " + sql_content
        
        # Execute the EXPLAIN query
        cursor = connection.cursor(dictionary=True)
        cursor.execute(explain_query)
        explain_results = cursor.fetchall()
        cursor.close()
        
        if not explain_results:
            return False, ["No execution plan available"]
        
        plan_available = True
        
        # Analyze for common performance issues
        
        # Check for full table scans (no index usage)
        full_scans = [row for row in explain_results if row.get('key') is None and row.get('table') is not None]
        if full_scans:
            tables = [row.get('table') for row in full_scans]
            warnings.append(f"Full table scan detected on table(s): {', '.join(tables)}. Consider adding indexes.")
        
        # Check for temporary tables
        temp_tables = [row for row in explain_results if 
                      row.get('Extra') and ('Using temporary' in row.get('Extra'))]
        if temp_tables:
            warnings.append("Query uses temporary tables which can impact performance. Consider optimizing GROUP BY or ORDER BY clauses.")
        
        # Check for filesorts
        filesorts = [row for row in explain_results if 
                    row.get('Extra') and ('Using filesort' in row.get('Extra'))]
        if filesorts:
            warnings.append("Query uses filesort which can impact performance. Consider adding indexes for ORDER BY columns.")
        
        # Check for high row counts
        high_rows = [row for row in explain_results if 
                     row.get('rows') and int(row.get('rows')) > 10000]
        if high_rows:
            tables = [row.get('table') for row in high_rows]
            warnings.append(f"Query processes large number of rows for table(s): {', '.join(tables)}. Consider adding filters or refining joins.")
        
        return plan_available, warnings
        
    except Exception as e:
        logging.warning(f"Error analyzing execution plan: {str(e)}")
        return False, [f"Error analyzing execution plan: {str(e)}"]

def process_single_export(connection_type, database, export, output_dir, date_range):
    """
    Process a single export configuration.
    
    Args:
        connection_type: Type of database connection to use
        database: Database name to connect to
        export: Export configuration
        output_dir: Directory for output files
        date_range: DateRange object with start and end dates
        
    Returns:
        True if successful, False otherwise
    """
    query_name = export['name']
    logging.info(f"Processing export: {query_name}")
    
    # Get query with includes and CTEs processed
    query_config = get_query(query_name, date_range)
    if 'error' in query_config:
        logging.error(f"Error with query {query_name}: {query_config['error']}")
        return False
    
    sql_content = query_config['sql']
    
    # Validate the SQL content before execution
    is_valid, issues = check_sql_syntax(sql_content)
    if not is_valid:
        logging.warning(f"SQL syntax issues in {query_name}:")
        for issue in issues:
            logging.warning(f"  - {issue}")
    
    # If there are just warnings but query is valid, proceed with execution
    if is_valid or any(issue.startswith("Warning:") for issue in issues):
        logging.info(f"Executing main query for {query_name}")
        
        try:
            # Create database connection
            conn = ConnectionFactory.create_connection(connection_type, database)
            # Use a more generic logging message that doesn't rely on the 'host' attribute
            logging.info(f"Connected to {connection_type} for database {database}")
            
            # Analyze execution plan before running the actual query
            plan_available, plan_warnings = analyze_execution_plan(sql_content, conn)
            if plan_available:
                if plan_warnings:
                    logging.info(f"Execution plan analysis for {query_name}:")
                    for warning in plan_warnings:
                        logging.info(f"  - {warning}")
                else:
                    logging.info(f"Execution plan for {query_name} shows no performance concerns")
            
            # Execute the query
            cursor = conn.cursor()
            cursor.execute(sql_content)
            
            # Get column names and results
            columns = [column[0] for column in cursor.description]
            results = cursor.fetchall()
            
            # Write results to CSV file
            output_file = os.path.join(output_dir, f"{query_name}.csv")
            with open(output_file, 'w', newline='') as csvfile:
                writer = csv.writer(csvfile)
                writer.writerow(columns)  # Write header
                writer.writerows(results)  # Write data rows
                
            logging.info(f"Exported {len(results)} rows to {output_file}")
            
            # Close the cursor and connection
            cursor.close()
            conn.close()
            logging.info("Database connection closed")
            
            return True
            
        except Exception as e:
            logging.error(f"Error executing query {query_name}: {str(e)}", exc_info=True)
            return False
    else:
        logging.error(f"Skipping query {query_name} due to SQL syntax issues")
        return False

def export_validation_results(connection_type, database, start_date, end_date,
                         queries=None, output_dir=None):
    """
    Main function to export validation results.
    
    Args:
        connection_type: Type of database connection to use
        database: Database name to connect to
        start_date: Start date for queries (YYYY-MM-DD)
        end_date: End date for queries (YYYY-MM-DD)
        queries: List of query names to run, or None for all
        output_dir: Directory to write output files to, or None for default
    """
    # Validate inputs
    if not connection_type or not database:
        logging.error("Connection type and database must be specified")
        return
        
    # Parse dates
    try:
        start_date_obj = datetime.strptime(start_date, '%Y-%m-%d').date()
        end_date_obj = datetime.strptime(end_date, '%Y-%m-%d').date()
        date_range = DateRange(start_date=start_date_obj, end_date=end_date_obj)
    except ValueError as e:
        logging.error(f"Invalid date format: {str(e)}")
        return
        
    logging.info(f"Starting export with database: {database}")
    logging.info(f"Date range: {start_date} to {end_date}")
    
    # Create output directory based on date range
    date_str = f"{start_date.replace('-', '')}_to_{end_date.replace('-', '')}"
    if output_dir is None:
        output_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'output', date_str)
    
    ensure_directory_exists(output_dir)
    logging.info(f"Output directory: {output_dir}")
    
    # Get list of available queries
    available_exports = get_exports(date_range)
    available_query_names = [export['name'] for export in available_exports]
    
    # Validate requested queries
    if queries and queries != ['all']:
        # Verify all requested queries exist
        for query in queries:
            if query not in available_query_names:
                logging.warning(f"Requested query not found: {query}")
                
        # Filter exports to only the requested ones
        exports_to_process = [export for export in available_exports if export['name'] in queries]
    else:
        # Process all available queries
        exports_to_process = available_exports
        logging.info(f"Processing all {len(exports_to_process)} available queries")
        
    # Process each export
    successful_exports = 0
    for export in exports_to_process:
        try:
            process_single_export(connection_type, database, export, output_dir, date_range)
            successful_exports += 1
        except Exception as e:
            logging.error(f"Error processing export {export['name']}: {str(e)}", exc_info=True)
    
    # Log SQL cache statistics
    cache_stats = SQL_CACHE.get_stats()
    logging.info(f"SQL Cache statistics:")
    logging.info(f"  - Cache hits: {cache_stats['hits']}")
    logging.info(f"  - Cache misses: {cache_stats['misses']}")
    logging.info(f"  - Hit rate: {cache_stats['hit_rate']:.2f}%")
    logging.info(f"  - Raw SQL entries: {cache_stats['raw_entries']}")
    logging.info(f"  - Processed SQL entries: {cache_stats['processed_entries']}")
    logging.info(f"  - Parameterized SQL entries: {cache_stats['parameterized_entries']}")
    
    logging.info(f"Export completed: {successful_exports}/{len(exports_to_process)} successful")

def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description='Export payment validation data')
    
    # Add arguments
    parser.add_argument('--start-date', 
                        required=True,
                        help='Start date (YYYY-MM-DD)')
    
    parser.add_argument('--end-date', 
                        required=True,
                        help='End date (YYYY-MM-DD)')
    
    parser.add_argument('--database', 
                        required=True,
                        help='Database name')
    
    parser.add_argument('--connection-type', 
                        default='local_mariadb',
                        choices=['local_mariadb', 'remote_mariadb'],
                        help='Connection type')
    
    parser.add_argument('--output-dir', 
                        help='Output directory for CSV files')
    
    parser.add_argument('--queries', 
                        nargs='+',
                        help='Specific queries to run (space-separated)')
    
    parser.add_argument('--log-level',
                        default='INFO',
                        choices=['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'],
                        help='Logging level')
    
    parser.add_argument('--generate-dependency-graph', action='store_true',
                        help='Generate a visualization of CTE dependencies')
    
    return parser.parse_args()

def main():
    """Main entry point for the script."""
    args = parse_args()
    
    # Set up logging
    setup_logging()
    
    # Set log level
    log_level = getattr(logging, args.log_level)
    logging.getLogger().setLevel(log_level)
    
    # Log script start
    logging.info("=" * 80)
    logging.info("STARTING PAYMENT VALIDATION EXPORT PROCESS")
    logging.info(f"Date range: {args.start_date} to {args.end_date}")
    logging.info(f"Database: {args.database}")
    logging.info(f"Connection type: {args.connection_type}")
    if args.output_dir:
        logging.info(f"Output directory: {args.output_dir}")
    if args.queries:
        logging.info(f"Queries: {', '.join(args.queries)}")
    else:
        logging.info(f"Running all available queries")
    logging.info("=" * 80)
    
    try:
        # Export validation results
        export_validation_results(
            args.connection_type,
            args.database,
            args.start_date,
            args.end_date,
            args.queries,
            args.output_dir
        )
        
        # Generate dependency graph if requested
        if args.generate_dependency_graph:
            logging.info("=" * 80)
            logging.info("GENERATING CTE DEPENDENCY VISUALIZATION")
            if hasattr(SQL_CACHE, 'cte_dependencies') and SQL_CACHE.cte_dependencies:
                dependency_count = sum(len(deps) for deps in SQL_CACHE.cte_dependencies.values())
                logging.info(f"Found {len(SQL_CACHE.cte_dependencies)} CTEs with {dependency_count} dependencies")
                logging.info("Generating visualization...")
                
                output_path = generate_cte_dependency_graph(SQL_CACHE.cte_dependencies)
                if output_path:
                    logging.info(f"Dependency visualization created successfully")
                    logging.info(f"Output file: {output_path}")
                else:
                    logging.error("Failed to generate dependency visualization")
            else:
                logging.warning("No CTE dependencies found to visualize")
                logging.info("This likely means no CTEs were loaded or analyzed during the export process")
        
    except Exception as e:
        logging.critical(f"Unhandled exception: {str(e)}", exc_info=True)
        return 1
        
    logging.info("=" * 80)
    logging.info("EXPORT PROCESS COMPLETED SUCCESSFULLY")
    return 0

if __name__ == "__main__":
    main()
