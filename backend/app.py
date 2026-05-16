import os
import time
from flask import Flask, request, jsonify

from config import MATCH_THRESHOLD
from services.face_recognition import engine
from services.db_service import get_db_connection, test_connection

from routes.auth          import auth_bp
from routes.students      import students_bp
from routes.instructors   import instructors_bp
from routes.sessions      import sessions_bp
from routes.issues        import issues_bp
from routes.courses       import courses_bp
from routes.notifications import notifications_bp
from routes.admin         import admin_bp
from routes.train         import train_bp

test_connection()

app = Flask(__name__)

# ── Register all blueprints ──────────────────────────────────────────────────
app.register_blueprint(auth_bp)
app.register_blueprint(students_bp)
app.register_blueprint(instructors_bp)
app.register_blueprint(sessions_bp)
app.register_blueprint(issues_bp)
app.register_blueprint(courses_bp)
app.register_blueprint(notifications_bp)
app.register_blueprint(admin_bp)
app.register_blueprint(train_bp)


# ── Root health check ────────────────────────────────────────────────────────
@app.route('/')
def home():
    return "AMS Server is Running!", 200


# ── Kiosk face scan (core AI endpoint — stays in app.py) ────────────────────
def _perf_str(confidence, det_ms, rec_ms, total_ms):
    return (
        f"Performance Audit:\n"
        f"Confidence: {confidence*100:.2f}%\n"
        f"Detection: {det_ms:.1f}ms\n"
        f"Recognition: {rec_ms:.1f}ms\n"
        f"Total: {total_ms:.1f}ms\n"
        f"────────────────────\n"
    )


@app.route('/kiosk_scan', methods=['POST'])
def kiosk_scan():
    total_start = time.time()

    if 'image' not in request.files or 'classroom_id' not in request.form:
        return jsonify({"match": False, "message": "Missing image or classroom_id"}), 400

    file = request.files['image']
    try:
        current_room_id = int(request.form['classroom_id'])
    except (ValueError, TypeError):
        return jsonify({"match": False, "message": "Invalid classroom_id"}), 400

    temp_path = f"temp_scan_{int(time.time()*1000)}.jpg"
    try:
        file.save(temp_path)
        student_id, student_name, confidence, det_ms, rec_ms = engine.verify_face(temp_path)
    except Exception as e:
        return jsonify({"match": False, "message": f"AI Error: {e}"}), 500
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)

    total_ms = (time.time() - total_start) * 1000
    perf     = _perf_str(confidence, det_ms, rec_ms, total_ms)

    if not student_id or student_id == "Unknown" or confidence < MATCH_THRESHOLD:
        return jsonify({"match": False, "message": perf + "Result: Unknown Face"}), 401

    try:
        conn   = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT TOP 1 s.session_id, c.name
            FROM   class_session s
            JOIN   enrollment    e ON s.course_id = e.course_id
            JOIN   course        c ON s.course_id = c.id
            WHERE  e.student_id = ?
              AND  CAST(s.session_start AS DATE) = CAST(GETDATE() AS DATE)
            ORDER  BY s.session_start ASC
        """, (student_id,))
        row = cursor.fetchone()

        if row:
            s_id, c_name = row
            cursor.execute(
                "SELECT id FROM attendance_record WHERE session_id=? AND student_id=?",
                (s_id, student_id)
            )
            if cursor.fetchone():
                msg = f"Already marked present for {c_name}."
            else:
                cursor.execute(
                    "INSERT INTO attendance_record "
                    "(session_id, student_id, status, marked_at, method) "
                    "VALUES (?, ?, 'Present', GETDATE(), 'FaceID')",
                    (s_id, student_id)
                )
                conn.commit()
                msg = f"Attendance marked!\nCourse: {c_name}"
        else:
            msg = "Identity verified.\n(No session scheduled today)"

        conn.close()
        return jsonify({
            "match":        True,
            "message":      perf + f"IDENTITY VERIFIED\nStudent: {student_name}\nID: {student_id}\n{msg}",
            "student_name": student_name,
        }), 200

    except Exception as e:
        return jsonify({
            "match":        True,
            "message":      perf + f"IDENTITY VERIFIED\nStudent: {student_name}\n(DB: {str(e)})",
            "student_name": student_name,
        }), 200


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=False)
