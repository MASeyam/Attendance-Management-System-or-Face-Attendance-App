import os
import cv2
import json
import pyodbc
import numpy as np
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

app = Flask(__name__)

# ==========================================
# 2. THE AI BRAIN (FaceEngine)
# ==========================================
class FaceEngine:
    def __init__(self):
        print("⏳ FaceEngine: Loading AI Models... (This may take a moment)")
        self.app = FaceAnalysis(name='buffalo_l', providers=['CPUExecutionProvider'])
        self.app.prepare(ctx_id=0, det_size=(640, 640))
        
        self.known_faces = [] 
        self.known_names = []
        self.known_ids = []
        
        self.reload_faces_from_db()

    def get_db_connection(self):
        conn_str = (
            f"Driver={{SQL Server}};"
            f"Server={SERVER_NAME};"
            f"Database={DATABASE_NAME};"
            f"Trusted_Connection=yes;"
        )
        return pyodbc.connect(conn_str)

    def reload_faces_from_db(self):
        print("🔄 FaceEngine: Syncing with Database...")
        try:
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            query = """
            SELECT id, first_name, last_name, facial_encoding
            FROM student
            WHERE facial_encoding IS NOT NULL
            """
            
            cursor.execute(query)
            rows = cursor.fetchall()
            
            self.known_faces.clear()
            self.known_names.clear()
            self.known_ids.clear()

            for row in rows:
                try:
                    encoding_list = json.loads(row.facial_encoding.strip())
                    encoding = np.array(encoding_list, dtype=np.float32)
                    full_name = f"{row.first_name} {row.last_name}"
                    
                    self.known_faces.append(encoding)
                    self.known_names.append(full_name)
                    self.known_ids.append(str(row.id))
                except Exception as e:
                    print(f"⚠️ Encoding error for student {row.id}: {e}")
            
            conn.close()
            print(f"✅ FaceEngine: Loaded {len(self.known_faces)} students.")
            
        except Exception as e:
            print(f"❌ Database Error during sync: {e}")

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

        max_score = 0.0
        best_id = None
        best_name = None
        
        if not self.known_faces:
            return None, "No Known Faces in DB", 0.0

        for i, known_embedding in enumerate(self.known_faces):
            score = 1 - cosine(known_embedding, target_embedding)
            if score > max_score:
                max_score = score
                best_id = self.known_ids[i]
                best_name = self.known_names[i]

        if max_score > 0.5:
            return best_id, best_name, max_score
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
    return "✅ AMS Server is Running!"

@app.route('/kiosk_scan', methods=['POST'])
def kiosk_scan():
    if 'image' not in request.files or 'classroom_id' not in request.form:
        return jsonify({"match": False, "message": "Missing image or classroom ID"}), 400

    file = request.files['image']
    classroom_id = request.form['classroom_id']
    
    temp_path = "temp_scan.jpg"
    try:
        file.save(temp_path)
    except Exception:
        return jsonify({"match": False, "message": "Failed to save image"}), 500

    try:
        student_id, student_name, confidence = engine.verify_face(temp_path)
    except Exception as e:
        print(f"❌ Face verification error: {e}")
        return jsonify({"match": False, "message": "Verification failed"}), 500
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)

    if not student_id:
        return jsonify({"match": False, "message": "Unknown Face"}), 401

    try:
        conn = engine.get_db_connection()
        cursor = conn.cursor()

        # ✅ FIXED QUERY (TIME vs TIME)
        query = """
        SELECT TOP 1 s.session_id, c.name
        FROM class_session s
        JOIN enrollment e ON s.course_id = e.course_id
        JOIN course c ON s.course_id = c.id
        WHERE 
            e.student_id = ?
            AND s.classroom_id = ?
            AND s.session_status = 'Scheduled'
            AND CAST(s.session_start AS DATE) = CAST(GETDATE() AS DATE)
            AND CAST(GETDATE() AS TIME) >= CAST(s.attendance_start AS TIME)
            AND CAST(GETDATE() AS TIME) <= CAST(s.session_end AS TIME)
        """

        cursor.execute(query, (student_id, classroom_id))
        session = cursor.fetchone()

        if not session:
            conn.close()
            return jsonify({"match": False, "message": "No Active Class Found"}), 403

        session_id, course_name = session

        cursor.execute(
            "SELECT id FROM attendance_record WHERE session_id = ? AND student_id = ?",
            (session_id, student_id)
        )

        if not cursor.fetchone():
            cursor.execute("""
                INSERT INTO attendance_record
                (session_id, student_id, status, marked_at, method)
                VALUES (?, ?, 'Present', GETDATE(), 'FaceID')
            """, (session_id, student_id))
            conn.commit()
            message = f"Welcome, {student_name}!\nClass: {course_name}"
        else:
            message = f"Already Marked!\nClass: {course_name}"

        conn.close()
        return jsonify({
        "match": True,
        "student": student_name,
        "student_id": student_id,   
        "message": message
    }), 200

    except Exception as e:
        print(f"❌ CRITICAL SQL Error: {e}")
        return jsonify({"match": False, "message": "Server Database Error"}), 500

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

        # 1. Try to find the user
        # We check the table schema to see if we need 'name' or 'first_name + last_name'
        # But to be safe, we will write a query that assumes the same structure as Instructor
        # If your student table is different (has only 'name'), this query might fail.
        
        # SAFE QUERY: Select everything and let Python handle the name
        cursor.execute("SELECT * FROM student WHERE id = ? AND password = ?", (student_id, password))
        user = cursor.fetchone()
        
        conn.close()

        if user:
            # DYNAMIC NAME HANDLING
            # We check if the row has 'first_name' or just 'name'
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
        # This will print the exact error to your terminal so you can see it
        return jsonify({"success": False, "message": "Server Error"}), 500
    
# ==========================================
# 6. ADMIN LOGIN ROUTE (Searches 'admin' table)
# ==========================================
@app.route('/admin_login', methods=['POST'])
def admin_login():
    try:
        data = request.get_json()
        username = data.get('username')
        password = data.get('password')

        conn = engine.get_db_connection()
        cursor = conn.cursor()
        
        # 1. Search in the ADMIN table
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


# ==========================================
# 7. INSTRUCTOR LOGIN ROUTE (Searches 'instructor' table)
# ==========================================
@app.route('/instructor_login', methods=['POST'])
def instructor_login():
    try:
        data = request.get_json()
        username = data.get('username')
        password = data.get('password')

        conn = engine.get_db_connection()
        cursor = conn.cursor()
        
        # 🔴 CHANGED HERE: 
        # We now select 'first_name' + 'last_name' because the 'name' column is gone.
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
                # We format the name nicely: "Prof. Mohamed Hussian"
                "name": f"{instructor_user.role}. {instructor_user.full_name}",
                "id": instructor_user.id
            }), 200
        else:
            return jsonify({"success": False, "message": "Invalid Instructor Credentials"}), 401

    except Exception as e:
        print(f"❌ Instructor Login Error: {e}")
        return jsonify({"success": False, "message": "Server Error"}), 500

# ==========================================
# 8. STUDENT HISTORY ROUTE (Make sure this is here!)
# ==========================================
@app.route('/student_history', methods=['POST'])
def student_history():
    try:
        student_id = request.form.get('student_id')
        
        # Fallback: Check JSON if form data is empty (Flutter sometimes sends JSON)
        if not student_id:
            data = request.get_json()
            if data:
                student_id = data.get('student_id')

        if not student_id:
            return jsonify({"success": False, "message": "Student ID is missing"}), 400

        conn = engine.get_db_connection()
        cursor = conn.cursor()

        # The Query
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
