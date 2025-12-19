import os
import cv2
import json
import pyodbc
import numpy as np
import pickle
import insightface
from flask import Flask, request, jsonify
from insightface.app import FaceAnalysis
from scipy.spatial.distance import cosine
from datetime import datetime

# ==========================================
# 1. CONFIGURATION
# ==========================================
SERVER_NAME = r'ABDULRHMANSEYAM'
DATABASE_NAME = 'Attendsystem'
BRAIN_FILE = 'face_encodings.pkl'

app = Flask(__name__)

# ==========================================
# 2. THE AI BRAIN (FaceEngine)
# ==========================================
class FaceEngine:
    def __init__(self):
        print("⏳ FaceEngine: Loading AI Models...")
        self.app = FaceAnalysis(name='buffalo_l', providers=['CPUExecutionProvider'])
        self.app.prepare(ctx_id=0, det_size=(640, 640))
        
        self.known_faces = [] 
        self.known_names = []
        self.known_ids = []
        
        self.load_brain_from_file()

    def get_db_connection(self):
        conn_str = (
            f"Driver={{SQL Server}};"
            f"Server={SERVER_NAME};"
            f"Database={DATABASE_NAME};"
            f"Trusted_Connection=yes;"
        )
        return pyodbc.connect(conn_str)

    def load_brain_from_file(self):
        print(f"🔄 FaceEngine: Loading Brain from {BRAIN_FILE}...")
        
        if not os.path.exists(BRAIN_FILE):
            print(f"⚠️ WARNING: {BRAIN_FILE} not found! Run train.py first.")
            return

        try:
            with open(BRAIN_FILE, 'rb') as f:
                data = pickle.load(f)

            self.known_faces = data['embeddings']
            raw_labels = data['names']
            
            self.known_names = []
            self.known_ids = []

            for label in raw_labels:
                try:
                    if " - " in label:
                        name, sid = label.rsplit(" - ", 1)
                    else:
                        name = label
                        sid = "Unknown"

                    self.known_names.append(name)
                    self.known_ids.append(sid)
                except Exception as e:
                    self.known_names.append(label)
                    self.known_ids.append("Unknown")

            print(f"✅ FaceEngine: Loaded {len(self.known_faces)} faces from file.")

        except Exception as e:
            print(f"❌ Error loading brain file: {e}")

    def verify_face(self, image_path):
        img = cv2.imread(image_path)
        if img is None:
            return None, "Invalid Image", 0.0

        faces = self.app.get(img)
        if not faces:
            return None, "No Face Detected", 0.0
        
        faces.sort(
            key=lambda x: (x.bbox[2]-x.bbox[0]) * (x.bbox[3]-x.bbox[1]),
            reverse=True
        )
        target_embedding = faces[0].embedding
        target_embedding = target_embedding / np.linalg.norm(target_embedding)

        if not self.known_faces:
            return None, "System not trained yet", 0.0

        similarities = np.dot(self.known_faces, target_embedding)
        best_idx = np.argmax(similarities)
        max_score = float(similarities[best_idx])

        # Threshold
        if max_score > 0.5:
            return self.known_ids[best_idx], self.known_names[best_idx], max_score
            
        return None, "Unknown Face", max_score

# ==========================================
# 3. INITIALIZE THE BRAIN
# ==========================================
engine = FaceEngine()

# ==========================================
# 4. WEB SERVER ROUTES
# ==========================================
@app.route('/')
def home():
    return "✅ AMS Server is Running (ID ONLY MODE)!"

@app.route('/kiosk_scan', methods=['POST'])
def kiosk_scan():
    # 1. Get Image
    if 'image' not in request.files:
        return jsonify({"match": False, "message": "Missing image"}), 400

    file = request.files['image']
    
    # Save Temp Image
    temp_path = "temp_scan.jpg"
    try:
        file.save(temp_path)
    except Exception:
        return jsonify({"match": False, "message": "Failed to save image"}), 500

    # 2. RUN AI PREDICTION
    try:
        student_id, student_name, confidence = engine.verify_face(temp_path)
    except Exception as e:
        print(f"❌ Face verification error: {e}")
        return jsonify({"match": False, "message": "Verification failed"}), 500
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)

    # 3. RETURN RESULT IMMEDIATELY (No DB Checks)
    if not student_id or student_id == "Unknown":
        print(f"🕵️ Result: Unknown Face (Confidence: {confidence:.2f})")
        return jsonify({"match": False, "message": "Unknown Face"}), 401
    
    # Success!
    print(f"✅ IDENTIFIED: {student_name} (ID: {student_id})")
    
    return jsonify({
        "match": True,
        "student": student_name,
        "student_id": student_id,   
        "message": f"Hello, {student_name}!\nID: {student_id}"
    }), 200

# ==========================================
# (Login Routes kept same as before)
# ==========================================
@app.route('/login', methods=['POST'])
def login():
    try:
        data = request.get_json()
        student_id = data.get('student_id')
        password = data.get('password')

        if not student_id or not password:
            return jsonify({"success": False, "message": "Missing ID or Password"}), 400

        conn = engine.get_db_connection()
        cursor = conn.cursor()

        cursor.execute("SELECT * FROM student WHERE id = ? AND password = ?", (student_id, password))
        user = cursor.fetchone()
        conn.close()

        if user:
            if hasattr(user, 'first_name') and hasattr(user, 'last_name'):
                full_name = f"{user.first_name} {user.last_name}"
            elif hasattr(user, 'name'):
                full_name = user.name
            else:
                full_name = "Student"

            return jsonify({
                "success": True, 
                "message": "Login Successful",
                "name": full_name,
                "student_id": student_id
            }), 200
        else:
            return jsonify({"success": False, "message": "Invalid ID or Password"}), 401

    except Exception as e:
        print(f"❌ Student Login Error: {e}")
        return jsonify({"success": False, "message": "Server Error"}), 500

@app.route('/admin_login', methods=['POST'])
def admin_login():
    try:
        data = request.get_json()
        username = data.get('username')
        password = data.get('password')

        conn = engine.get_db_connection()
        cursor = conn.cursor()
        
        query = "SELECT id, full_name, role FROM admin WHERE username = ? AND password = ?"
        cursor.execute(query, (username, password))
        admin_user = cursor.fetchone()
        conn.close()

        if admin_user:
            return jsonify({
                "success": True, 
                "message": "Admin Login Successful",
                "name": admin_user.full_name,
                "role": admin_user.role
            }), 200
        else:
            return jsonify({"success": False, "message": "Invalid Admin Credentials"}), 401

    except Exception as e:
        print(f"❌ Admin Login Error: {e}")
        return jsonify({"success": False, "message": "Server Error"}), 500

@app.route('/instructor_login', methods=['POST'])
def instructor_login():
    try:
        data = request.get_json()
        username = data.get('username')
        password = data.get('password')

        conn = engine.get_db_connection()
        cursor = conn.cursor()
        
        query = """
            SELECT id, (first_name + ' ' + last_name) as full_name, role 
            FROM instructor 
            WHERE username = ? AND password = ?
        """
        cursor.execute(query, (username, password))
        instructor_user = cursor.fetchone()
        conn.close()

        if instructor_user:
            return jsonify({
                "success": True, 
                "message": "Instructor Login Successful",
                "name": f"{instructor_user.role}. {instructor_user.full_name}",
                "id": instructor_user.id
            }), 200
        else:
            return jsonify({"success": False, "message": "Invalid Instructor Credentials"}), 401

    except Exception as e:
        print(f"❌ Instructor Login Error: {e}")
        return jsonify({"success": False, "message": "Server Error"}), 500

@app.route('/student_history', methods=['POST'])
def student_history():
    try:
        student_id = request.form.get('student_id')
        
        if not student_id:
            data = request.get_json()
            if data:
                student_id = data.get('student_id')

        if not student_id:
            return jsonify({"success": False, "message": "Student ID is missing"}), 400

        conn = engine.get_db_connection()
        cursor = conn.cursor()

        query = """
        SELECT 
            c.name, 
            s.session_start, 
            a.status, 
            a.marked_at
        FROM attendance_record a
        JOIN class_session s ON a.session_id = s.session_id
        JOIN course c ON s.course_id = c.id
        WHERE a.student_id = ?
        ORDER BY s.session_start DESC
        """
        
        cursor.execute(query, (student_id,))
        rows = cursor.fetchall()

        history = []
        for row in rows:
            history.append({
                "course": row.name,
                "date": str(row.session_start),
                "status": row.status,
                "check_in": str(row.marked_at)
            })

        conn.close()
        return jsonify({"success": True, "data": history}), 200

    except Exception as e:
        print(f"❌ History Error: {e}")
        return jsonify({"success": False, "message": "Server Error fetching history"}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)