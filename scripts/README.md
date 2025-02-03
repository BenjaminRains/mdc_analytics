# Scripts Directory Structure

## Overview
This directory contains various scripts for data processing and utility functions.

### Directory Structure
- `utils/`: Utility scripts and helper functions
  - `backup_utils/`: Database backup and restore utilities
  - `logging_utils/`: Logging configuration and utilities
- `export/`: Data export scripts for specific use cases

### Usage
- Utility scripts (`utils/`) are meant to be imported and used by other scripts
- Export scripts (`export/`) are standalone scripts for specific data export tasks

### Best Practices
1. Keep utility functions separate from business logic
2. Use consistent logging across all scripts
3. Follow the established connection management patterns
4. Document all scripts and functions 