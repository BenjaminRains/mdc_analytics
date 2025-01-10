# database configuration file
## db_config.py


def connect_to_mysql():
    """
    Returns a connection object for the MySQL database.
    """
    import mysql.connector

    return mysql.connector.connect(
        host="localhost",
        user="root",
        password="Jibear10Jibear10!", 
        database="opendental_analytics",
        port=3306
    )




