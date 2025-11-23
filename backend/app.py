import os
import cv2
import numpy as np
import pyodbc
from flask import Flask, request, jsonify
from insightface.app import FaceAnalysis

app = Flask(__name__)

# --- CONFIGURATION ---
SERVER_NAME = r'ABDULRHMANSEYAM'
DATABASE_NAME = 'Attendsystem' 
THRESHOLD = 0.5 

# --- LOAD AI ---
print("Loading AI Model...")
face_app = FaceAnalysis(name="buffalo_l", providers=['CPUExecutionProvider'])
face_app.prepare(ctx_id=0, det_size=(640, 640))
print("AI Ready.")

known_embeddings = []
known_ids = []
known_names = []

def load_data():
    global known_embeddings, known_ids, known_names
    known_embeddings = []
    known_ids = []
    known_names = []

    try:
        conn = pyodbc.connect(
            f"Driver={{SQL Server}};Server={SERVER_NAME};Database={DATABASE_NAME};Trusted_Connection=yes;"
        )
        cursor = conn.cursor()
        
        # Get ID and Full Name
        cursor.execute("SELECT id, first_name, last_name, facial_encoding FROM student")
        rows = cursor.fetchall()
        
        for uid, first, last, emb_bytes in rows:
            if emb_bytes:
                emb = np.frombuffer(emb_bytes, dtype=np.float32)
                known_ids.append(uid)
                # Store full name
                known_names.append(f"{first} {last}")
                known_embeddings.append(emb)
                
        print(f"Data Loaded: {len(known_ids)} students.")
        conn.close()
    except Exception as e:
        print(f"DB Error: {e}")

load_data()

def cosine_similarity(a, b):
    return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))

def check_schedule(student_id, room_id):
    try:
        conn = pyodbc.connect(
            f"Driver={{SQL Server}};Server={SERVER_NAME};Database={DATABASE_NAME};Trusted_Connection=yes;"
        )
        cursor = conn.cursor()
        
        # LOGIC: Matches Enrollment + Room + Time
        query = """
        SELECT cs.session_id
        FROM class_session cs
        JOIN enrollment e ON cs.course_id = e.course_id
        WHERE e.student_id = ?
          AND cs.classroom_id = ?
          AND GETDATE() BETWEEN cs.session_start AND cs.session_end
        """
        
        cursor.execute(query, (student_id, room_id))
        result = cursor.fetchone()
        
        if result:
            # Mark Attendance silently
            try:
                cursor.execute("""
                    INSERT INTO attendance_record (session_id, student_id, method, status)
                    VALUES (?, ?, 'Facial Recognition', 'Present')
                """, (result[0], student_id))
                conn.commit()
            except:
                pass 
            return True
        else:
            return False
            
    except:
        return False
    finally:
        conn.close()

@app.route('/verify-face', methods=['POST'])
def verify_face():
    # 1. FAIL SAFE RESPONSE
    fail_response = jsonify({"match": False, "message": "No match"})

    if 'photo' not in request.files:
        return fail_response
    
    file = request.files['photo']
    try:
        file_bytes = np.frombuffer(file.read(), np.uint8)
        frame = cv2.imdecode(file_bytes, cv2.IMREAD_COLOR)

        faces = face_app.get(frame)
        if len(faces) == 0:
            return fail_response

        captured_emb = faces[0].normed_embedding

        # 2. CHECK IDENTITY
        best_match_id = -1
        best_name = ""
        highest_sim = 0
        is_match = False

        for i, target_emb in enumerate(known_embeddings):
            sim = cosine_similarity(captured_emb, target_emb)
            if sim > highest_sim:
                highest_sim = sim
            if sim > THRESHOLD:
                is_match = True
                best_match_id = known_ids[i]
                best_name = known_names[i]
                break 

        if not is_match:
            return fail_response

        # 3. CHECK SCHEDULE (Time & Room)
        current_room = '101'
        
        if check_schedule(best_match_id, current_room):
            # --- THIS IS THE OUTPUT YOU WANTED ---
            return jsonify({
                "match": True, 
                "message": f"Welcome {best_name} - {best_match_id}"
            }), 200
        else:
            return fail_response

    except:
        return fail_response

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)