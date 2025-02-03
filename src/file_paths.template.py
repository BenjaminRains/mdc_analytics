"""
File path management template for data exports and imports.
Provides consistent path handling across the project.
"""

from pathlib import Path
from typing import Dict, Optional
import os

class DataPaths:
    """Manages file paths for data operations"""
    
    def __init__(self, base_dir: Optional[str] = None):
        """
        Initialize path manager with optional base directory override.
        
        Args:
            base_dir: Optional base directory path. Defaults to data directory
        """
        self.base_dir = Path(base_dir) if base_dir else Path('data')
        self._paths: Dict[str, Path] = self._initialize_paths()

    def _initialize_paths(self) -> Dict[str, Path]:
        """Initialize dictionary of file paths"""
        return {
            # Patient data
            "patient": self.base_dir / "patient_data.csv",
            "patientnote": self.base_dir / "patientnote_data.csv",
            
            # Add other paths as needed...
            # Example:
            # "example": self.base_dir / "example_data.csv",
        }

    def get_path(self, key: str) -> Optional[Path]:
        """Get file path by key"""
        return self._paths.get(key)

    def exists(self, key: str) -> bool:
        """Check if file exists"""
        path = self.get_path(key)
        return path.exists() if path else False

    def create_directories(self) -> None:
        """Create necessary directories if they don't exist"""
        self.base_dir.mkdir(parents=True, exist_ok=True)

    def list_available_files(self) -> Dict[str, bool]:
        """List all configured files and their existence status"""
        return {key: self.exists(key) for key in self._paths.keys()}

    @property
    def base_directory(self) -> Path:
        """Get base directory path"""
        return self.base_dir

# Create default instance
data_paths = DataPaths()

def get_file_path(key: str) -> Optional[Path]:
    """Legacy support for get_file_path function"""
    return data_paths.get_path(key) 