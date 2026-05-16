from datetime import datetime
from flask import Blueprint, request, jsonify
from services.db_service import get_db_connection
from services.email_service import send_login_credentials

students_bp = Blueprint('students', __name__)


# ── legacy endpoints (kept for ams_app backward compat) ─────────────────────
@students_bp.route('/get_student_courses', methods=['POST'])
def get_student_courses_legacy():
    try:
        sid    = request.form.get('student_id')
        conn   = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT c.id, c.name, i.first_name + ' ' + i.last_name
            FROM   enrollment e
            JOIN   course     c ON e.course_id     = c.id
            JOIN   instructor i ON c.instructor_id = i.id
            WHERE  e.student_id = ?
        """, (sid,))
        courses = [{"course_id": r[0], "course_name": r[1], "instructor": r[2]}
                   for r in cursor.fetchall()]
        conn.close()
        return jsonify({"success": True, "courses": courses}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@students_bp.route('/get_course_details', methods=['POST'])
def get_course_details_legacy():
    try:
        sid, cid = request.form.get('student_id'), request.form.get('course_id')
        conn     = get_db_connection()
        cursor   = conn.cursor()
        cursor.execute("""
            SELECT cs.session_id, cs.session_type, cs.classroom_id,
                   cs.session_start, cs.session_end,
                   i.first_name + ' ' + i.last_name,
                   ar.marked_at
            FROM   class_session cs
            JOIN   instructor    i  ON cs.instructor_id = i.id
            LEFT JOIN attendance_record ar
                   ON ar.session_id = cs.session_id AND ar.student_id = ?
            WHERE  cs.course_id = ?
            ORDER  BY cs.session_start DESC
        """, (sid, cid))
        schedule = []
        for r in cursor.fetchall():
            schedule.append({
                "session_id": r[0],
                "type":       r[1],
                "room":       r[2],
                "date":       r[3].strftime('%Y-%m-%d %H:%M') if r[3] else '',
                "status":     "Present" if r[6] else "Absent"
            })
        conn.close()
        return jsonify({"success": True, "schedule": schedule}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


# ── new student CRUD endpoints ───────────────────────────────────────────────
@students_bp.route('/students', methods=['GET'])
def get_all_students():
    try:
        conn   = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT id, first_name, last_name, email, phone_number,
                   academic_year, level, group_name, gpa, department_id, date_of_birth
            FROM   student
            ORDER  BY first_name
        """)
        students = []
        for r in cursor.fetchall():
            students.append({
                "id":            r[0],
                "first_name":    r[1],
                "last_name":     r[2],
                "email":         r[3],
                "phone_number":  r[4],
                "academic_year": r[5],
                "level":         r[6],
                "group_name":    r[7],
                "gpa":           float(r[8]) if r[8] is not None else None,
                "department_id": r[9],
                "date_of_birth": r[10].strftime('%Y-%m-%d') if r[10] else None,
            })
        conn.close()
        return jsonify({"success": True, "students": students}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@students_bp.route('/students/<int:student_id>', methods=['GET'])
def get_student(student_id):
    try:
        conn   = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT id, first_name, last_name, email, phone_number,
                   academic_year, level, group_name, gpa, department_id, date_of_birth
            FROM   student WHERE id = ?
        """, (student_id,))
        r = cursor.fetchone()
        conn.close()
        if not r:
            return jsonify({"success": False, "message": "Student not found"}), 404
        return jsonify({
            "success":       True,
            "id":            r[0],
            "first_name":    r[1],
            "last_name":     r[2],
            "email":         r[3],
            "phone_number":  r[4],
            "academic_year": r[5],
            "level":         r[6],
            "group_name":    r[7],
            "gpa":           float(r[8]) if r[8] is not None else None,
            "department_id": r[9],
            "date_of_birth": r[10].strftime('%Y-%m-%d') if r[10] else None,
        }), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@students_bp.route('/students/next-id', methods=['GET'])
def get_next_student_id():
    try:
        year   = datetime.now().year
        prefix = str(year)
        conn   = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "SELECT MAX(id) FROM student WHERE CAST(id AS VARCHAR(20)) LIKE ?",
            (f'{prefix}%',),
        )
        row      = cursor.fetchone()
        conn.close()
        last_id  = row[0]
        if last_id is None:
            seq = 1
        else:
            tail = str(last_id)[len(prefix):]
            seq  = (int(tail) if tail.isdigit() else 0) + 1
        next_id = int(f'{year}{seq:04d}')
        return jsonify({
            'success': True,
            'next_id': next_id,
            'email':   f'{next_id}@fue.edu.eg',
        }), 200
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500


@students_bp.route('/students/create', methods=['POST'])
def create_student():
    try:
        data = request.get_json() or {}
        required = ['id', 'first_name', 'last_name']
        for f in required:
            if not data.get(f):
                return jsonify({"success": False, "message": f"Missing field: {f}"}), 400

        conn   = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO student
              (id, first_name, last_name, email, phone_number, password,
               date_of_birth, academic_year, level, group_name, gpa, department_id)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            data['id'],
            data['first_name'],
            data['last_name'],
            data.get('email'),
            data.get('phone_number'),
            data.get('password'),
            data.get('date_of_birth'),
            data.get('academic_year'),
            data.get('level'),
            data.get('group_name'),
            data.get('gpa'),
            data.get('department_id'),
        ))
        conn.commit()
        conn.close()

        # Send credentials email (non-blocking — failure won't abort the request)
        personal_email = data.get('personal_email', '')
        if personal_email:
            full_name = f"{data['first_name']} {data['last_name']}"
            try:
                send_login_credentials(
                    personal_email=personal_email,
                    full_name=full_name,
                    login_email=data.get('email', ''),
                    password=data.get('password', ''),
                    role='Student',
                )
            except Exception as mail_err:
                print(f'Email send error (non-fatal): {mail_err}')

        return jsonify({"success": True, "message": "Student created"}), 201
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@students_bp.route('/students/<int:student_id>', methods=['DELETE'])
def delete_student(student_id):
    try:
        conn   = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("DELETE FROM student WHERE id=?", (student_id,))
        if cursor.rowcount == 0:
            conn.close()
            return jsonify({"success": False, "message": "Student not found"}), 404
        conn.commit()
        conn.close()
        return jsonify({"success": True, "message": "Student deleted"}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@students_bp.route('/students/<int:student_id>/attendance-summary', methods=['GET'])
def attendance_summary(student_id):
    try:
        conn   = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT
                c.id                                                              AS course_id,
                c.name                                                            AS course_name,
                COUNT(cs.session_id)                                              AS total_sessions,
                SUM(CASE WHEN ar.status = 'Present' THEN 1 ELSE 0 END)           AS present,
                SUM(CASE WHEN ar.status IS NULL OR ar.status != 'Present'
                         THEN 1 ELSE 0 END)                                       AS absent,
                CASE WHEN COUNT(cs.session_id) = 0 THEN 0
                     ELSE CAST(
                         SUM(CASE WHEN ar.status = 'Present' THEN 1 ELSE 0 END) * 100.0
                         / COUNT(cs.session_id) AS DECIMAL(5,2))
                END                                                               AS percentage
            FROM   enrollment    e
            JOIN   course        c  ON e.course_id     = c.id
            JOIN   class_session cs ON cs.course_id    = c.id
            LEFT JOIN attendance_record ar
                   ON ar.session_id = cs.session_id AND ar.student_id = e.student_id
            WHERE  e.student_id = ?
            GROUP  BY c.id, c.name
        """, (student_id,))
        summary = []
        for r in cursor.fetchall():
            summary.append({
                "course_id":      r[0],
                "course_name":    r[1],
                "total_sessions": r[2],
                "present":        r[3] or 0,
                "absent":         r[4] or 0,
                "percentage":     float(r[5]) if r[5] is not None else 0.0,
            })
        conn.close()
        return jsonify({"success": True, "summary": summary}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@students_bp.route('/students/<int:student_id>/attendance-history', methods=['GET'])
def attendance_history(student_id):
    try:
        course_id  = request.args.get('course_id')
        date_from  = request.args.get('date_from')
        date_to    = request.args.get('date_to')

        conn   = get_db_connection()
        cursor = conn.cursor()

        query = """
            SELECT cs.session_id, c.name, cs.session_start,
                   COALESCE(ar.status, 'Absent') AS status,
                   COALESCE(ar.method, '')        AS method
            FROM   enrollment    e
            JOIN   course        c  ON e.course_id  = c.id
            JOIN   class_session cs ON cs.course_id = c.id
            LEFT JOIN attendance_record ar
                   ON ar.session_id = cs.session_id AND ar.student_id = ?
            WHERE  e.student_id = ?
        """
        params = [student_id, student_id]

        if course_id:
            query += " AND c.id = ?"
            params.append(course_id)
        if date_from:
            query += " AND CAST(cs.session_start AS DATE) >= ?"
            params.append(date_from)
        if date_to:
            query += " AND CAST(cs.session_start AS DATE) <= ?"
            params.append(date_to)

        query += " ORDER BY cs.session_start DESC"
        cursor.execute(query, params)

        history = []
        for r in cursor.fetchall():
            history.append({
                "session_id":    r[0],
                "course_name":   r[1],
                "session_start": r[2].strftime('%Y-%m-%d %H:%M') if r[2] else '',
                "status":        r[3],
                "method":        r[4],
            })
        conn.close()
        return jsonify({"success": True, "history": history}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@students_bp.route('/students/<int:student_id>/schedule', methods=['GET'])
def student_schedule(student_id):
    try:
        conn   = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT cs.session_id, c.name, cs.session_start, cs.session_end,
                   cs.classroom_id, cl.building, cs.session_type
            FROM   enrollment    e
            JOIN   course        c  ON e.course_id  = c.id
            JOIN   class_session cs ON cs.course_id = c.id
            LEFT JOIN classroom  cl ON cl.id = cs.classroom_id
            WHERE  e.student_id = ?
              AND  cs.session_start >= GETDATE()
            ORDER  BY cs.session_start ASC
        """, (student_id,))
        sessions = []
        for r in cursor.fetchall():
            sessions.append({
                "session_id":  r[0],
                "course_name": r[1],
                "start":       r[2].strftime('%Y-%m-%d %H:%M') if r[2] else '',
                "end":         r[3].strftime('%Y-%m-%d %H:%M') if r[3] else '',
                "room":        r[4],
                "building":    r[5],
                "type":        r[6],
            })
        conn.close()
        return jsonify({"success": True, "sessions": sessions}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500
