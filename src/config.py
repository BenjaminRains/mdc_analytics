"""
MDC Analytics Configuration Module

This module provides centralized configuration for file paths and other settings.
It uses a hybrid approach that allows both default paths and environment variable overrides.
"""
import os
from pathlib import Path
from typing import Optional, Union


# Determine project root with multiple fallback mechanisms
def find_project_root() -> Path:
    """
    Find the project root directory using multiple strategies:
    1. Check for MDC_ANALYTICS_ROOT environment variable
    2. Look for the location of this config.py file
    3. Find 'mdc_analytics' directory in current path
    4. Fall back to current working directory
    """
    # Strategy 1: Environment variable
    env_root = os.environ.get("MDC_ANALYTICS_ROOT")
    if env_root:
        return Path(env_root)
    
    # Strategy 2: Location of this config file
    config_path = Path(__file__).resolve()
    if "mdc_analytics" in str(config_path):
        # Walk up to find mdc_analytics root
        current = config_path.parent
        while current.name != "mdc_analytics" and current != current.parent:
            current = current.parent
        if current.name == "mdc_analytics":
            return current
    
    # Strategy 3: Search upward from current directory
    current = Path.cwd()
    while current != current.parent:
        if current.name == "mdc_analytics":
            return current
        current = current.parent
    
    # Strategy 4: Fallback to CWD with warning
    print("WARNING: Could not determine project root. Using current directory.")
    return Path.cwd()


# Set project root
PROJECT_ROOT = find_project_root()


# Data directory paths
class DataPaths:
    """Container for all data paths used in the project."""

    @property
    def base_data_dir(self) -> Path:
        """Base directory for validation data"""
        return PROJECT_ROOT / "scripts" / "validation"
    
    def validation_dir(self, module: str) -> Path:
        """Get the validation directory for a specific module"""
        return self.base_data_dir / module
    
    def data_dir(self, module: str, subdir: Optional[str] = None) -> Path:
        """
        Get the data directory for a specific validation module
        
        Args:
            module: The validation module name (e.g., 'payment_split')
            subdir: Optional subdirectory within the data directory
            
        Returns:
            Path to the requested data directory
        """
        path = self.validation_dir(module) / "data"
        if subdir:
            path = path / subdir
        return path
    
    # Specific data directories as properties for convenience
    @property
    def payment_split(self) -> Path:
        return self.data_dir("payment_split")
    
    # Payment split subdirectories - these are actual subdirectories
    def payment_split_subdir(self, subdir: str) -> Path:
        """Get a specific subdirectory within payment_split data directory"""
        return self.data_dir("payment_split", subdir)
    
    @property
    def income_transfer(self) -> Path:
        """Path to income transfer directory under payment_split"""
        return self.payment_split / "income_transfer"
    
    @property
    def split_validation(self) -> Path:
        """Path to split validation directory under payment_split"""
        return self.payment_split / "split_validation"
    
    @property
    def unearned_income(self) -> Path:
        """Path to unearned income directory under payment_split"""
        return self.payment_split / "unearned_income"
    
    @property
    def income_transfer_indicators(self) -> Path:
        """Path to income transfer indicators directory under payment_split"""
        return self.payment_split_subdir("income_transfer_indicators")
    
    @property
    def payment_split_validation(self) -> Path:
        """Path to payment split validation directory under payment_split"""
        return self.payment_split_subdir("payment_split_validation")
    
    @property
    def procedurelog(self) -> Path:
        return self.data_dir("procedurelog")
    
    @property
    def adjustments(self) -> Path:
        return self.data_dir("adjustments")
    
    @property
    def appointments(self) -> Path:
        return self.data_dir("appointments")
    
    @property
    def fee_feeschedule(self) -> Path:
        return self.data_dir("fee_feeschedule")
    
    @property
    def insurance(self) -> Path:
        return self.data_dir("insurance")
    
    @property
    def treatment_plan(self) -> Path:
        return self.data_dir("treatment_plan")
    
    @property
    def communication(self) -> Path:
        return self.data_dir("communication")


# Create a singleton instance for easy import
data_paths = DataPaths()


# Helper functions
def resolve_path(path: Union[str, Path]) -> Path:
    """Resolves a path relative to the project root if it's not absolute"""
    path_obj = Path(path)
    if path_obj.is_absolute():
        return path_obj
    return PROJECT_ROOT / path_obj


def get_notebook_relative_path(notebook_path: Union[str, Path], target_path: Union[str, Path]) -> Path:
    """
    Calculate a path relative to a notebook's location
    
    Args:
        notebook_path: Path to the notebook (or its directory)
        target_path: Target path to resolve relative to notebook
        
    Returns:
        Resolved path
    """
    notebook_dir = Path(notebook_path)
    if notebook_dir.is_file():
        notebook_dir = notebook_dir.parent
    
    target = Path(target_path)
    if target.is_absolute():
        return target
    
    # Calculate relative path from notebook to project root
    rel_to_root = os.path.relpath(PROJECT_ROOT, notebook_dir)
    return Path(rel_to_root) / target


# Print configuration information for debugging
def print_config_info():
    """Print current configuration information for debugging"""
    print(f"Project Root: {PROJECT_ROOT}")
    print(f"Environment Override Used: {'Yes' if os.environ.get('MDC_ANALYTICS_ROOT') else 'No'}")
    print("\nData Directories:")
    for module in [
        "payment_split", "procedurelog", "adjustments", "appointments", 
        "fee_feeschedule", "insurance", "treatment_plan", "communication"
    ]:
        path = getattr(data_paths, module)
        print(f"  - {module}: {path}")
        print(f"    Exists: {path.exists()}")
    
    # Print payment_split subdirectories
    print("\nPayment Split Subdirectories:")
    for subdir in ["income_transfer_indicators", "payment_split_validation", "unassigned_by_month"]:
        path = getattr(data_paths, subdir)
        print(f"  - {subdir}: {path}")
        print(f"    Exists: {path.exists()}")


if __name__ == "__main__":
    # When run directly, print configuration information
    print_config_info() 