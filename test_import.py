
from src.db_config import connect_to_mysql

try:
    conn = connect_to_mysql()
    print("Database connection successful!")
    conn.close()
except Exception as e:
    print("Error connecting to the database:", e)

import sys
print("sys.path:", sys.path)

import mysql
print("mysql module path:", mysql.__file__)

