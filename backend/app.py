import os
import cv2          # OpenCV: Used to read and process images
import json         # JSON: Used to parse data sent from the mobile app
import pyodbc       # PyODBC: Used to connect to SQL Server
import numpy as np  # NumPy: Used for vector math
import pickle       # Pickle: Used to read the 'Brain' file
from flask import Flask, request, jsonify
from insightface.app import FaceAnalysis 
from scipy.spatial.distance import cosine
from datetime import datetime 

# ==========================================
# SECTION 1: CONFIGURATION
# ==========================================
SERVER_NAME = r'ABDULRHMANSEYAM'
DATABASE_NAME = 'Attendsystem'
BRAIN_FILE = 'face_encodings.pkl' 

app = Flask(__name__)

# ==========================================
# SECTION 2: THE AI BRAIN (FaceEngine)
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

        if max_score > 0.5:
            return self.known_ids[best_idx], self.known_names[best_idx], max_score
            
        return None, "Unknown Face", max_score

# ==========================================
# SECTION 3: INITIALIZATION
# ==========================================
engine = FaceEngine()

# ==========================================
# SECTION 4: API ROUTES 
# ==========================================
@app.route('/')
def home():
    return "✅ AMS Server is Running (PRODUCTION MODE)!"

# ------------------------------------------
# A. UNIFIED LOGIN (Replaces the 3 old functions)
# ------------------------------------------
@app.route('/login', methods=['POST'])
def login():
    try:
        data = request.get_json()
        # Accept 'username' OR 'student_id' as the identifier
        identifier = data.get('username') or data.get('student_id')
        password = data.get('password')

        if not identifier or not password:
            return jsonify({"success": False, "message": "Missing Credentials"}), 400

        conn = engine.get_db_connection()
        cursor = conn.cursor()

        # 1. CHECK STUDENT TABLE (Only if identifier is numeric)
        if identifier.isdigit():
            cursor.execute("SELECT id, first_name, last_name FROM student WHERE id = ? AND password = ?", (identifier, password))
            student = cursor.fetchone()
            if student:
                conn.close()
                return jsonify({
                    "success": True,
                    "role": "Student",
                    "id": student.id,
                    "name": f"{student.first_name} {student.last_name}"
                }), 200

        # 2. CHECK INSTRUCTOR TABLE
        cursor.execute("SELECT id, first_name, last_name, role FROM instructor WHERE username = ? AND password = ?", (identifier, password))
        instr = cursor.fetchone()
        if instr:
            conn.close()
            return jsonify({
                "success": True,
                "role": "Instructor",
                "id": instr.id,
                "name": f"{instr.role}. {instr.first_name} {instr.last_name}"
            }), 200

        # 3. CHECK ADMIN TABLE
        cursor.execute("SELECT id, full_name, role FROM admin WHERE username = ? AND password = ?", (identifier, password))
        admin = cursor.fetchone()
        if admin:
            conn.close()
            return jsonify({
                "success": True,
                "role": "Admin", 
                "id": admin.id,
                "name": admin.full_name
            }), 200

        # 4. IF NO MATCH
        conn.close()
        return jsonify({"success": False, "message": "Invalid Credentials"}), 401

    except Exception as e:
        print(f"❌ Login Error: {e}")
        return jsonify({"success": False, "message": "Server Error"}), 500

# ------------------------------------------
# B. KIOSK SCAN (Your Original Smart Logic)
# ------------------------------------------
@app.route('/kiosk_scan', methods=['POST'])
def kiosk_scan():
    # 1. Validation
    if 'image' not in request.files or 'classroom_id' not in request.form:
        return jsonify({"match": False, "message": "Missing image or classroom ID"}), 400

    file = request.files['image']
    try:
        current_room_id = int(request.form['classroom_id'])
    except ValueError:
        return jsonify({"match": False, "message": "Invalid Classroom ID format"}), 400
    
    # 2. AI Prediction
    temp_path = "temp_scan.jpg"
    try:
        file.save(temp_path)
        student_id, student_name, confidence = engine.verify_face(temp_path)
    except Exception as e:
        print(f"❌ Face verification error: {e}")
        return jsonify({"match": False, "message": "Verification failed"}), 500
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)

    if not student_id or student_id == "Unknown":
        return jsonify({"match": False, "message": "Couldn't Find You!"}), 401

    # 3. SMART SCHEDULE ANALYSIS
    try:
        conn = engine.get_db_connection()
        cursor = conn.cursor()

        # QUERY: Get ALL classes for this student TODAY
        query = """
        SELECT 
            s.session_id, 
            c.name, 
            s.classroom_id, 
            s.session_start, 
            s.session_end,
            s.session_type
        FROM class_session s
        JOIN enrollment e ON s.course_id = e.course_id
        JOIN course c ON s.course_id = c.id
        WHERE 
            e.student_id = ? 
            AND s.session_status = 'Scheduled'
            AND CAST(s.session_start AS DATE) = CAST(GETDATE() AS DATE)
        """
        
        cursor.execute(query, (student_id,))
        todays_sessions = cursor.fetchall()
        
        if not todays_sessions:
            conn.close()
            return jsonify({
                "match": False, 
                "message": f"Hello {student_name}, you have no classes scheduled for today!"
            }), 403

        now = datetime.now()
        perfect_session = None
        error_messages = []

        for session in todays_sessions:
            s_id, c_name, room_id, start, end, s_type = session
            
            # Helper text for PR/TH
            type_str = "(Practical)" if s_type == 'PR' else "(Theory)"
            full_c_name = f"{c_name} {type_str}"

            is_room_correct = (room_id == current_room_id)
            is_time_correct = (start <= now <= end)

            if is_room_correct and is_time_correct:
                perfect_session = session
                break 
            
            # Error Generation
            if is_time_correct and not is_room_correct:
                error_messages.append(f"Wrong Place! Your {full_c_name} is in Room {room_id}.")
            
            elif is_room_correct and not is_time_correct:
                start_str = start.strftime("%I:%M %p")
                error_messages.append(f"Wrong Time! {full_c_name} starts at {start_str}.")
            
            elif not is_room_correct and not is_time_correct:
                start_str = start.strftime("%I:%M %p")
                error_messages.append(f"Mismatch: {full_c_name} is in Room {room_id} at {start_str}.")

        # 4. HANDLE RESULTS
        if perfect_session:
            s_id, c_name, room_id, start, end, s_type = perfect_session
            type_str = "(Practical)" if s_type == 'PR' else "(Theory)"
            
            # Check duplication
            cursor.execute("SELECT id FROM attendance_record WHERE session_id = ? AND student_id = ?", (s_id, student_id))
            if cursor.fetchone():
                msg = f"Welcome, {student_name}!\nYou are already marked present."
            else:
                cursor.execute("""
                    INSERT INTO attendance_record (session_id, student_id, status, marked_at, method)
                    VALUES (?, ?, 'Present', GETDATE(), 'FaceID')
                """, (s_id, student_id))
                conn.commit()
                msg = f"Welcome, {student_name}!\nAttendance marked for {c_name} {type_str}.\nFocus to get the best marks!"

            conn.close()
            return jsonify({
                "match": True,
                "student": student_name,
                "student_id": student_id,   
                "message": msg
            }), 200

        else:
            conn.close()
            if error_messages:
                final_error = "\n".join(error_messages)
            else:
                final_error = "No active class found for you right now."

            return jsonify({
                "match": False, 
                "message": final_error
            }), 403

    except Exception as e:
        print(f"❌ Server Error: {e}")
        return jsonify({"match": False, "message": "Server Database Error"}), 500

# ------------------------------------------
# C. STUDENT DASHBOARD APIs
# ------------------------------------------
@app.route('/get_student_courses', methods=['POST'])
def get_student_courses():
    try:
        student_id = request.form.get('student_id')
        conn = engine.get_db_connection()
        cursor = conn.cursor()
        
        query = """
        SELECT c.id, c.name, i.first_name + ' ' + i.last_name as instructor
        FROM enrollment e
        JOIN course c ON e.course_id = c.id
        JOIN instructor i ON c.instructor_id = i.id
        WHERE e.student_id = ?
        """
        cursor.execute(query, (student_id,))
        courses = []
        for row in cursor.fetchall():
            courses.append({
                "course_id": row.id,
                "course_name": row.name,
                "instructor": row.instructor
            })
            
        conn.close()
        return jsonify({"success": True, "courses": courses}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500

@app.route('/get_course_details', methods=['POST'])
def get_course_details():
    try:
        student_id = request.form.get('student_id')
        course_id = request.form.get('course_id')
        
        conn = engine.get_db_connection()
        cursor = conn.cursor()

        query = """
        SELECT 
            cs.session_id, cs.session_type, cs.classroom_id, 
            cs.session_start, cs.session_end, 
            i.first_name + ' ' + i.last_name as instructor_name,
            ar.marked_at
        FROM class_session cs
        JOIN instructor i ON cs.instructor_id = i.id
        LEFT JOIN attendance_record ar 
            ON ar.session_id = cs.session_id AND ar.student_id = ?
        WHERE cs.course_id = ?
        ORDER BY cs.session_start ASC
        """
        cursor.execute(query, (student_id, course_id))
        rows = cursor.fetchall()
        
        schedule = []
        now = datetime.now()

        for row in rows:
            s_id, s_type, room, start, end, instr, marked_at = row
            type_str = "Practical (Lab)" if s_type == 'PR' else "Theoretical (Lecture)"
            
            status = ""
            color = ""
            if marked_at:
                status = "✅ Attended"
                color = "green"
            elif start < now:
                status = "❌ Missed"
                color = "red"
            else:
                status = "📅 Upcoming"
                color = "blue"

            schedule.append({
                "session_id": s_id,
                "type": type_str,
                "room": f"Room {room}",
                "instructor": instr,
                "date": start.strftime('%Y-%m-%d'),
                "time": f"{start.strftime('%I:%M %p')} - {end.strftime('%I:%M %p')}",
                "status": status,
                "ui_color": color
            })

        conn.close()
        return jsonify({"success": True, "schedule": schedule}), 200

    except Exception as e:
        print(f"Error: {e}")
        return jsonify({"success": False, "message": "Server Error"}), 500

# ------------------------------------------
# D. INSTRUCTOR DASHBOARD APIs
# ------------------------------------------
@app.route('/get_my_courses', methods=['POST'])
def get_my_courses():
    try:
        instructor_id = request.form.get('instructor_id')
        conn = engine.get_db_connection()
        cursor = conn.cursor()
        
        query = "SELECT id, name, credit_hours FROM course WHERE instructor_id = ?"
        cursor.execute(query, (instructor_id,))
        courses = []
        for row in cursor.fetchall():
            courses.append({
                "id": row.id,
                "name": row.name,
                "credits": row.credit_hours
            })
            
        conn.close()
        return jsonify({"success": True, "courses": courses}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500

@app.route('/get_session_attendance', methods=['POST'])
def get_session_attendance():
    try:
        course_id = request.form.get('course_id')
        date_str = request.form.get('date', datetime.now().strftime('%Y-%m-%d'))
        
        conn = engine.get_db_connection()
        cursor = conn.cursor()

        query = """
        SELECT 
            st.first_name + ' ' + st.last_name AS student_name,
            st.id AS student_id,
            CASE WHEN ar.marked_at IS NOT NULL THEN 'Present' ELSE 'Absent' END AS status,
            ISNULL(FORMAT(ar.marked_at, 'hh:mm tt'), '--') AS check_in_time,
            cs.session_type
        FROM enrollment e
        JOIN student st ON e.student_id = st.id
        JOIN class_session cs ON cs.course_id = e.course_id
        LEFT JOIN attendance_record ar ON ar.student_id = st.id AND ar.session_id = cs.session_id
        WHERE e.course_id = ? AND CAST(cs.session_start AS DATE) = ?
        ORDER BY st.first_name
        """
        cursor.execute(query, (course_id, date_str))
        rows = cursor.fetchall()
        
        attendance_list = []
        for row in rows:
            attendance_list.append({
                "name": row.student_name,
                "id": row.student_id,
                "status": row.status,
                "time": row.check_in_time,
                "type": row.session_type
            })

        conn.close()
        return jsonify({"success": True, "data": attendance_list}), 200

    except Exception as e:
        print(f"Error: {e}")
        return jsonify({"success": False, "message": "Server Error"}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=False)