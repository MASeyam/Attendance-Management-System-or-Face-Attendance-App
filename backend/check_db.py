import pyodbc

conn = pyodbc.connect("Driver={SQL Server};Server=localhost;Database=Attendsystem;Trusted_Connection=yes;")
cursor = conn.cursor()

print("=== TABLES ===")
cursor.execute("SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' ORDER BY TABLE_NAME")
for row in cursor.fetchall():
    print(" ", row[0])

print("\n=== STUDENT COLUMNS ===")
cursor.execute("SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='student' ORDER BY ORDINAL_POSITION")
for row in cursor.fetchall():
    print(f"  {row[0]} ({row[1]})")

print("\n=== INSTRUCTOR COLUMNS ===")
cursor.execute("SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='instructor' ORDER BY ORDINAL_POSITION")
for row in cursor.fetchall():
    print(f"  {row[0]} ({row[1]})")

print("\n=== ADMIN TABLE (if exists) ===")
cursor.execute("SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='admin' ORDER BY ORDINAL_POSITION")
for row in cursor.fetchall():
    print(f"  {row[0]} ({row[1]})")

conn.close()
