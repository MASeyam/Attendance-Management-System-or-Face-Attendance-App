import cv2
import numpy as np
import pyodbc
from insightface.app import FaceAnalysis

# --- CONFIG ---
SERVER_NAME = r'ABDULRHMANSEYAM'
DATABASE_NAME = 'Attendsystem' 

# --- YOUR REAL DETAILS ---
MY_ID = 20225389
MY_FIRST_NAME = "Abdulrahman"
MY_LAST_NAME = "Seyam"
MY_EMAIL = "20225389@fue.edu.eg" 
MY_PHONE = "01013348636"                  
MY_IMAGE = "student.jpg"

print("Loading AI...")
app = FaceAnalysis(name="buffalo_l", providers=['CPUExecutionProvider'])
app.prepare(ctx_id=0, det_size=(640, 640))

try:
    conn = pyodbc.connect(
        f"Driver={{SQL Server}};Server={SERVER_NAME};Database={DATABASE_NAME};Trusted_Connection=yes;"
    )
    cursor = conn.cursor()
    print("Connected to DB.")
except Exception as e:
    print(f"DB Error: {e}")
    exit()

def register_me():
    print(f"Reading {MY_IMAGE}...")
    img = cv2.imread(MY_IMAGE)
    if img is None:
        print("Error: student.jpg not found.")
        return
        
    faces = app.get(img)
    if len(faces) == 0:
        print("Error: No face detected.")
        return

    embedding_bytes = faces[0].normed_embedding.tobytes() 

    try:
        # 1. ALLOW CUSTOM ID
        cursor.execute("SET IDENTITY_INSERT student ON")

        # 2. INSERT REAL DATA
        print(f"Inserting {MY_FIRST_NAME}...")
        cursor.execute("""
            INSERT INTO student (id, first_name, last_name, email, phone_number, date_of_birth, academic_year, facial_encoding) 
            VALUES (?, ?, ?, ?, ?, '2002-01-01', 'Senior', ?)
            """, (MY_ID, MY_FIRST_NAME, MY_LAST_NAME, MY_EMAIL, MY_PHONE, embedding_bytes))
        
        # 3. RESET INSERT RULE
        cursor.execute("SET IDENTITY_INSERT student OFF")
        
        # 4. ENROLL IN COURSE
        cursor.execute("""
            INSERT INTO enrollment (student_id, course_id, status, enrolled_date, semester, academic_year)
            VALUES (?, 1, 'Active', GETDATE(), 'Fall', 2025)
        """, (MY_ID))
        
        conn.commit()
        print(f"✅ SUCCESS! Registered: {MY_FIRST_NAME} {MY_LAST_NAME} - {MY_ID}")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        print("(If the error is 'Violation of PRIMARY KEY', you forgot to run the delete SQL script first!)")

if __name__ == "__main__":
    register_me()