import os
import cv2         
import json         
import pyodbc       
import numpy as np  
import pickle       
import time
from flask import Flask, request, jsonify
from insightface.app import FaceAnalysis 
from datetime import datetime 

# ==========================================
# SECTION 1: CONFIGURATION
# ==========================================
SERVER_NAME = r'ABDULRHMANSEYAM'
DATABASE_NAME = 'Attendsystem'
BRAIN_FILE = 'face_encodings.pkl' 
MATCH_THRESHOLD = 0.5
MIN_SCORE_GAP = 0.03
MIN_DET_SCORE_VERIFY = 0.60
MIN_FACE_SIZE_VERIFY = 90

app = Flask(__name__)

# ==========================================
# SECTION 2: THE AI BRAIN (FaceEngine)
# ==========================================
class FaceEngine:
    def __init__(self):
        print("⏳ FaceEngine: Loading AI Models...")
        self.app = FaceAnalysis(name='buffalo_l', providers=['CPUExecutionProvider'])
        self.app.prepare(ctx_id=-1, det_size=(640, 640))
        
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
            print(f"⚠️ WARNING: {BRAIN_FILE} not found!")
            return

        try:
            with open(BRAIN_FILE, 'rb') as f:
                data = pickle.load(f)

            raw_embeddings = np.asarray(data['embeddings'], dtype=np.float32)
            # Normalize for better accuracy
            self.known_faces = raw_embeddings / (np.linalg.norm(raw_embeddings, axis=1, keepdims=True) + 1e-6)
            
            raw_labels = data['names']
            self.known_names = []
            self.known_ids = []

            for label in raw_labels:
                if " - " in label:
                    name, sid = label.rsplit(" - ", 1)
                else:
                    name, sid = label, "Unknown"
                self.known_names.append(name)
                self.known_ids.append(sid)

            print(f"✅ FaceEngine: Loaded {len(self.known_faces)} faces.")
        except Exception as e:
            print(f"❌ Error loading brain: {e}")

    # --- FIXED: Now properly inside the class ---
    def verify_face(self, image_path):
        img = cv2.imread(image_path)
        if img is None: return None, "Invalid Image", 0.0, 0.0, 0.0

        # Timing Detection
        t_start_det = time.time()
        faces = self.app.get(img)
        det_ms = (time.time() - t_start_det) * 1000

        if not faces: return None, "No Face Detected", 0.0, det_ms, 0.0

        # Timing Recognition
        t_start_rec = time.time()
        face = faces[0]
        
        # Normalize target
        target_embedding = face.embedding / (np.linalg.norm(face.embedding) + 1e-6)
        
        similarities = np.dot(self.known_faces, target_embedding)
        best_idx = int(np.argmax(similarities))
        max_score = float(similarities[best_idx])
        rec_ms = (time.time() - t_start_rec) * 1000

        return self.known_ids[best_idx], self.known_names[best_idx], max_score, det_ms, rec_ms

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

@app.route('/kiosk_scan', methods=['POST'])
def kiosk_scan():
    total_start = time.time()
    
    if 'image' not in request.files or 'classroom_id' not in request.form:
        return jsonify({"match": False, "message": "Missing image or classroom ID"}), 400

    file = request.files['image']
    try:
        current_room_id = int(request.form['classroom_id'])
    except:
        return jsonify({"match": False, "message": "Invalid Classroom ID"}), 400
    
    temp_path = "temp_scan.jpg"
    try:
        file.save(temp_path)
        # Call the engine
        student_id, student_name, confidence, det_ms, rec_ms = engine.verify_face(temp_path)
    except Exception as e:
        return jsonify({"match": False, "message": f"AI Error: {e}"}), 500
    finally:
        if os.path.exists(temp_path): os.remove(temp_path)

    total_ms = (time.time() - total_start) * 1000
    perf_metrics = (
        f"📊 Performance Audit:\n"
        f"◦ Confidence: {confidence*100:.2f}%\n"
        f"◦ Detection: {det_ms:.1f}ms\n"
        f"◦ Recognition: {rec_ms:.1f}ms\n"
        f"◦ Total Latency: {total_ms:.1f}ms\n"
        f"────────────────────\n"
    )
    if not student_id or student_id == "Unknown" or confidence < MATCH_THRESHOLD:
        return jsonify({"match": False, "message": perf_metrics + "Result: Unknown Face"}), 401

    # 👉 INSERT THE "SUCCESS BYPASS" RIGHT HERE:
    return jsonify({
        "match": True, 
        "message": perf_metrics + f"✅ IDENTITY VERIFIED\nStudent: {student_name}\nID: {student_id}"
    }), 200


    # if not student_id or student_id == "Unknown" or confidence < MATCH_THRESHOLD:
    #     return jsonify({"match": False, "message": perf_metrics + "Result: Unknown Face"}), 401

    # --- SMART SCHEDULE ANALYSIS ---
    # try:
    #     conn = engine.get_db_connection()
    #     cursor = conn.cursor()
    #     query = """
    #     SELECT s.session_id, c.name, s.classroom_id, s.session_start, s.session_end, s.session_type
    #     FROM class_session s
    #     JOIN enrollment e ON s.course_id = e.course_id
    #     JOIN course c ON s.course_id = c.id
    #     WHERE e.student_id = ? 
    #         AND s.session_status = 'Scheduled'
    #         AND CAST(s.session_start AS DATE) = CAST(GETDATE() AS DATE)
    #     """
    #     cursor.execute(query, (student_id,))
    #     todays_sessions = cursor.fetchall()
        
    #     if not todays_sessions:
    #         conn.close()
    #         return jsonify({"match": False, "message": perf_metrics + f"Hi {student_name}, no classes today!"}), 403

    #     now = datetime.now()
    #     perfect_session = None
    #     error_messages = []

    #     for session in todays_sessions:
    #         s_id, c_name, room_id, start, end, s_type = session
    #         is_room_correct = (room_id == current_room_id)
    #         is_time_correct = (start <= now <= end)

    #         if is_room_correct and is_time_correct:
    #             perfect_session = session
    #             break 
            
    #         if is_time_correct and not is_room_correct:
    #             error_messages.append(f"📍 Wrong Room! Go to Room {room_id}.")
    #         elif is_room_correct and not is_time_correct:
    #             error_messages.append(f"⏰ Wrong Time! Starts at {start.strftime('%I:%M %p')}.")

    #     if perfect_session:
    #         s_id, c_name, _, _, _, _ = perfect_session
    #         cursor.execute("SELECT id FROM attendance_record WHERE session_id = ? AND student_id = ?", (s_id, student_id))
    #         if cursor.fetchone():
    #             msg = "Already marked present!"
    #         else:
    #             cursor.execute("INSERT INTO attendance_record (session_id, student_id, status, marked_at, method) VALUES (?, ?, 'Present', GETDATE(), 'FaceID')", (s_id, student_id))
    #             conn.commit()
    #             msg = f"✅ Attendance marked for {c_name}."
    #         conn.close()
    #         return jsonify({"match": True, "message": perf_metrics + msg}), 200
    #     else:
    #         conn.close()
    #         return jsonify({"match": False, "message": perf_metrics + ("\n".join(error_messages) if error_messages else "No active class.")}), 403
    # except Exception as e:
    #     return jsonify({"match": False, "message": f"DB Error: {e}"}), 500

# --- DASHBOARD & LOGIN (Kept exactly as requested) ---

@app.route('/login', methods=['POST'])
def login():
    try:
        data = request.get_json()
        identifier = data.get('username') or data.get('student_id')
        password = data.get('password')
        conn = engine.get_db_connection()
        cursor = conn.cursor()
        if identifier.isdigit():
            cursor.execute("SELECT id, first_name, last_name FROM student WHERE id = ? AND password = ?", (identifier, password))
            res = cursor.fetchone()
            if res: return jsonify({"success": True, "role": "Student", "id": res.id, "name": f"{res.first_name} {res.last_name}"}), 200
        cursor.execute("SELECT id, first_name, last_name, role FROM instructor WHERE username = ? AND password = ?", (identifier, password))
        res = cursor.fetchone()
        if res: return jsonify({"success": True, "role": "Instructor", "id": res.id, "name": f"{res.first_name} {res.last_name}"}), 200
        return jsonify({"success": False, "message": "Invalid Credentials"}), 401
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500

@app.route('/get_student_courses', methods=['POST'])
def get_student_courses():
    try:
        sid = request.form.get('student_id')
        conn = engine.get_db_connection()
        cursor = conn.cursor()
        query = "SELECT c.id, c.name, i.first_name + ' ' + i.last_name FROM enrollment e JOIN course c ON e.course_id = c.id JOIN instructor i ON c.instructor_id = i.id WHERE e.student_id = ?"
        cursor.execute(query, (sid,))
        courses = [{"course_id": r[0], "course_name": r[1], "instructor": r[2]} for r in cursor.fetchall()]
        conn.close()
        return jsonify({"success": True, "courses": courses}), 200
    except Exception as e: return jsonify({"success": False, "message": str(e)}), 500

@app.route('/get_course_details', methods=['POST'])
def get_course_details():
    try:
        sid, cid = request.form.get('student_id'), request.form.get('course_id')
        conn = engine.get_db_connection()
        cursor = conn.cursor()
        query = "SELECT cs.session_id, cs.session_type, cs.classroom_id, cs.session_start, cs.session_end, i.first_name + ' ' + i.last_name, ar.marked_at FROM class_session cs JOIN instructor i ON cs.instructor_id = i.id LEFT JOIN attendance_record ar ON ar.session_id = cs.session_id AND ar.student_id = ? WHERE cs.course_id = ?"
        cursor.execute(query, (sid, cid))
        rows = cursor.fetchall()
        schedule = []
        for r in rows:
            schedule.append({"session_id": r[0], "type": r[1], "room": r[2], "date": r[3].strftime('%Y-%m-%d'), "status": "✅" if r[6] else "❌"})
        conn.close()
        return jsonify({"success": True, "schedule": schedule}), 200
    except Exception as e: return jsonify({"success": False, "message": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=False)