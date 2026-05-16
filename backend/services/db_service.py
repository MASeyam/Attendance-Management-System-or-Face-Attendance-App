import pyodbc

_SERVERS = [
    "AbdulrhmanSeyam",
    "localhost",
    ".",
    "127.0.0.1",
]

_DATABASE = "Attendsystem"
_working_connection_string = None


def _build_connection_string(server: str) -> str:
    return (
        f"DRIVER={{ODBC Driver 17 for SQL Server}};"
        f"SERVER={server};"
        f"DATABASE={_DATABASE};"
        "Trusted_Connection=yes;"
    )


def _find_working_server() -> str:
    for server in _SERVERS:
        cs = _build_connection_string(server)
        try:
            conn = pyodbc.connect(cs, timeout=3)
            conn.close()
            print(f"DB SERVER FOUND: {server}")
            return cs
        except Exception as e:
            print(f"  FAILED {server}: {e}")
    raise RuntimeError(
        "Could not connect to SQL Server with any of the tried server names. "
        "Make sure SQL Server Express is running and the SQL Server Browser service is started."
    )


def test_connection():
    global _working_connection_string
    print("Testing DB connection options...")
    try:
        _working_connection_string = _find_working_server()
        print("DB CONNECTION SUCCESS")
    except RuntimeError as e:
        print(f"DB CONNECTION FAILED: {e}")


def get_db_connection():
    global _working_connection_string
    if _working_connection_string is None:
        _working_connection_string = _find_working_server()
    return pyodbc.connect(_working_connection_string, timeout=5)
