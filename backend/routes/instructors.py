from flask import Blueprint, request, jsonify
from services.db_service import get_db_connection
from services.email_service import send_login_credentials

instructors_bp = Blueprint('instructors', __name__)


# ── legacy endpoint (kept for ams_app backward compat) ──────────────────────
@instructors_bp.route('/get_instructor_courses', methods=['POST'])
def get_instructor_courses_legacy():
    try:
        iid    = request.form.get('instructor_id')
        conn   = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT c.id, c.name, c.credit_hours,
                   (SELECT COUNT(*) FROM enrollment e WHERE e.course_id = c.id) AS enrolled
            FROM   course c
            WHERE  c.instructor_id = ?
        """, (iid,))
        courses = [{"course_id": r[0], "course_name": r[1],
                    "credit_hours": r[2], "enrolled_count": r[3]}
                   for r in cursor.fetchall()]
        conn.close()
        return jsonify({"success": True, "courses": courses}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


# ── new instructor CRUD endpoints ────────────────────────────────────────────
@instructors_bp.route('/instructors', methods=['GET'])
def get_all_instructors():
    try:
        conn   = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT id, first_name, last_name, email, phone_number,
                   role, username, department_id
            FROM   instructor
            ORDER  BY first_name
        """)
        instructors = []
        for r in cursor.fetchall():
            instructors.append({
                "id":            r[0],
                "first_name":    r[1],
                "last_name":     r[2],
                "email":         r[3],
                "phone_number":  r[4],
                "role":          r[5],
                "username":      r[6],
                "department_id": r[7],
            })
        conn.close()
        return jsonify({"success": True, "instructors": instructors}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@instructors_bp.route('/instructors/<int:instructor_id>', methods=['GET'])
def get_instructor(instructor_id):
    try:
        conn   = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT id, first_name, last_name, email, phone_number,
                   role, username, department_id
            FROM   instructor WHERE id = ?
        """, (instructor_id,))
        r = cursor.fetchone()
        conn.close()
        if not r:
            return jsonify({"success": False, "message": "Instructor not found"}), 404
        return jsonify({
            "success":       True,
            "id":            r[0],
            "first_name":    r[1],
            "last_name":     r[2],
            "email":         r[3],
            "phone_number":  r[4],
            "role":          r[5],
            "username":      r[6],
            "department_id": r[7],
        }), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@instructors_bp.route('/instructors/create', methods=['POST'])
def create_instructor():
    try:
        data = request.get_json() or {}
        required = ['first_name', 'last_name']
        for f in required:
            if not data.get(f):
                return jsonify({"success": False, "message": f"Missing field: {f}"}), 400

        conn   = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO instructor
              (first_name, last_name, email, phone_number, password,
               role, username, department_id)
            OUTPUT INSERTED.id
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            data['first_name'],
            data['last_name'],
            data.get('email'),
            data.get('phone_number'),
            data.get('password'),
            data.get('role', 'Lecturer'),
            data.get('username'),
            data.get('department_id'),
        ))
        new_id = cursor.fetchone()[0]
        conn.commit()
        conn.close()

        personal_email = data.get('personal_email', '')
        if personal_email:
            full_name = f"{data['first_name']} {data['last_name']}"
            try:
                send_login_credentials(
                    personal_email=personal_email,
                    full_name=full_name,
                    login_email=data.get('email', ''),
                    password=data.get('password', ''),
                    role=data.get('role', 'Instructor'),
                )
            except Exception as mail_err:
                print(f'Email send error (non-fatal): {mail_err}')

        return jsonify({"success": True, "id": new_id, "message": "Instructor created"}), 201
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@instructors_bp.route('/instructors/<int:instructor_id>', methods=['DELETE'])
def delete_instructor(instructor_id):
    try:
        conn   = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("DELETE FROM instructor WHERE id=?", (instructor_id,))
        if cursor.rowcount == 0:
            conn.close()
            return jsonify({"success": False, "message": "Instructor not found"}), 404
        conn.commit()
        conn.close()
        return jsonify({"success": True, "message": "Instructor deleted"}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@instructors_bp.route('/instructors/<int:instructor_id>/sessions/today', methods=['GET'])
def sessions_today(instructor_id):
    try:
        conn   = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT cs.session_id, c.name, cs.session_start, cs.session_end,
                   cs.classroom_id, cl.building, cs.session_status,
                   (SELECT COUNT(*) FROM enrollment e WHERE e.course_id = c.id) AS total_enrolled,
                   (SELECT COUNT(*) FROM attendance_record ar
                    WHERE ar.session_id = cs.session_id AND ar.status = 'Present')  AS present_count
            FROM   class_session cs
            JOIN   course        c  ON c.id  = cs.course_id
            LEFT JOIN classroom  cl ON cl.id = cs.classroom_id
            WHERE  cs.instructor_id = ?
              AND  CAST(cs.session_start AS DATE) = CAST(GETDATE() AS DATE)
            ORDER  BY cs.session_start ASC
        """, (instructor_id,))
        sessions = []
        for r in cursor.fetchall():
            sessions.append({
                "session_id":     r[0],
                "course_name":    r[1],
                "start":          r[2].strftime('%Y-%m-%d %H:%M') if r[2] else '',
                "end":            r[3].strftime('%Y-%m-%d %H:%M') if r[3] else '',
                "room":           r[4],
                "building":       r[5],
                "session_status": r[6],
                "total_enrolled": r[7],
                "present_count":  r[8],
            })
        conn.close()
        return jsonify({"success": True, "sessions": sessions}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@instructors_bp.route('/instructors/<int:instructor_id>/reports', methods=['GET'])
def instructor_reports(instructor_id):
    try:
        course_id  = request.args.get('course_id')
        student_id = request.args.get('student_id')
        date_from  = request.args.get('date_from')
        date_to    = request.args.get('date_to')

        conn   = get_db_connection()
        cursor = conn.cursor()

        query = """
            SELECT s.id, s.first_name + ' ' + s.last_name, c.name,
                   cs.session_start, COALESCE(ar.status, 'Absent'), COALESCE(ar.method, '')
            FROM   class_session    cs
            JOIN   course           c  ON c.id  = cs.course_id
            JOIN   enrollment       e  ON e.course_id = c.id
            JOIN   student          s  ON s.id  = e.student_id
            JOIN attendance_record ar
                   ON ar.session_id = cs.session_id AND ar.student_id = s.id
            WHERE  cs.instructor_id = ?
        """
        params = [instructor_id]

        if course_id:
            query += " AND c.id = ?"
            params.append(course_id)
        if student_id:
            query += " AND s.id = ?"
            params.append(student_id)
        if date_from:
            query += " AND CAST(cs.session_start AS DATE) >= ?"
            params.append(date_from)
        if date_to:
            query += " AND CAST(cs.session_start AS DATE) <= ?"
            params.append(date_to)

        query += " ORDER BY cs.session_start DESC"
        cursor.execute(query, params)

        records = []
        for r in cursor.fetchall():
            records.append({
                "student_id":    r[0],
                "student_name":  r[1],
                "course_name":   r[2],
                "session_start": r[3].strftime('%Y-%m-%d %H:%M') if r[3] else '',
                "status":        r[4],
                "method":        r[5],
            })
        conn.close()

        total_present  = sum(1 for r in records if r['status'] == 'Present')
        total_absent   = sum(1 for r in records if r['status'] == 'Absent')
        total_issues   = sum(1 for r in records if r['status'] in ('issued', 'resolved', 'disputed'))

        return jsonify({
            "success":        True,
            "records":        records,
            "total_present":  total_present,
            "total_absent":   total_absent,
            "total_disputed": total_issues,
            "total_issues":   total_issues,
        }), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500
