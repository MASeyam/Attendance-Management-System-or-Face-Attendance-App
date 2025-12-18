import cv2
import pyodbc
import os
import random
import string
import smtplib
import json
import numpy as np
import insightface
from insightface.app import FaceAnalysis
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

# ==========================================
# 1. MANUAL ENV LOADER (No Library Needed)
# ==========================================
def load_env_manual():
    """Reads .env file without needing python-dotenv library"""
    env_path = '.env'
    if not os.path.exists(env_path):
        print("⚠️ Warning: .env file not found.")
        return
    
    with open(env_path, 'r') as f:
        for line in f:
            # Skip comments and empty lines
            if line.strip().startswith('#') or not line.strip():
                continue
            if '=' in line:
                key, value = line.strip().split('=', 1)
                # Remove quotes if they exist
                value = value.strip('"').strip("'")
                os.environ[key] = value

# Load the secrets immediately
load_env_manual()

# ==========================================
# 2. CONFIGURATION
# ==========================================
SERVER_NAME = r'ABDULRHMANSEYAM'
DATABASE_NAME = 'Attendsystem'

SENDER_EMAIL = os.environ.get("EMAIL_USER")
SENDER_PASS = os.environ.get("EMAIL_PASS")

# Initialize InsightFace (The "Brain")
# This will download a model (~300MB) on the very first run only.
print("⏳ Loading InsightFace AI... (This might take a moment)")
model = FaceAnalysis(name='buffalo_l', providers=['CPUExecutionProvider'])
model.prepare(ctx_id=0, det_size=(640, 640))

def get_db_connection():
    return pyodbc.connect(f"Driver={{SQL Server}};Server={SERVER_NAME};Database={DATABASE_NAME};Trusted_Connection=yes;")

def generate_password(length=6):
    chars = string.ascii_letters + string.digits
    return ''.join(random.choice(chars) for _ in range(length))

def send_email(personal_email, school_email, password, name):
    if not SENDER_EMAIL: 
        print("⚠️ Email skipped (Credentials missing).")
        return
    try:
        msg = MIMEMultipart()
        msg['From'] = SENDER_EMAIL
        msg['To'] = personal_email
        msg['Subject'] = "Welcome to FUE Attendance System"
        body = f"Hello {name},\n\nYour account is ready.\n\nLogin: {school_email}\nPass: {password}"
        msg.attach(MIMEText(body, 'plain'))
        
        server = smtplib.SMTP('smtp.gmail.com', 587)
        server.starttls()
        server.login(SENDER_EMAIL, SENDER_PASS)
        server.send_message(msg)
        server.quit()
        print(f"✅ Email sent to {personal_email}")
    except Exception as e:
        print(f"❌ Email Error: {e}")

def get_insightface_embedding(folder_path):
    embeddings = []
    if not os.path.exists(folder_path):
        print(f"❌ Error: Folder '{folder_path}' not found.")
        return None

    files = [f for f in os.listdir(folder_path) if f.lower().endswith(('.jpg', '.png', '.jpeg'))]
    print(f"📂 Found {len(files)} images. Analyzing...")

    for file in files:
        img_path = os.path.join(folder_path, file)
        img = cv2.imread(img_path)
        if img is None: continue

        faces = model.get(img)
        if len(faces) > 0:
            embeddings.append(faces[0].embedding)

    if not embeddings: return None
    
    # Average and Normalize
    avg_embedding = np.mean(embeddings, axis=0)
    avg_embedding = avg_embedding / np.linalg.norm(avg_embedding)
    return avg_embedding.tolist()

# ==========================================
# 3. MAIN LOGIC
# ==========================================
def main():
    print("\n--- NEW STUDENT REGISTRATION (InsightFace) ---")
    
    id_num = input("Enter Student ID: ").strip()
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # Check if exists
    cursor.execute("SELECT id FROM student WHERE id = ?", (id_num,))
    if cursor.fetchone():
        print(f"❌ Student ID {id_num} already exists.")
        conn.close()
        return

    first_name = input("Enter First Name: ").strip()
    last_name = input("Enter Last Name: ").strip()
    personal_email = input("Enter Personal Email: ").strip()
    folder_path = input("Enter Photos Folder Path: ").strip()

    print("\n🔍 Processing Biometric Data...")
    face_data = get_insightface_embedding(folder_path)

    if not face_data:
        print("❌ No faces found.")
        conn.close()
        return

    face_json = json.dumps(face_data)
    school_email = f"{id_num}@fue.edu.eg"
    password = generate_password()

    try:
        cursor.execute("""
            INSERT INTO student (id, first_name, last_name, email, password, facial_encoding) 
            VALUES (?, ?, ?, ?, ?, ?)
        """, (id_num, first_name, last_name, school_email, password, face_json))
        
        conn.commit()
        print("✅ Student Saved Successfully!")
        
        if personal_email:
            send_email(personal_email, school_email, password, first_name)

    except Exception as e:
        print(f"❌ Database Error: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    main()