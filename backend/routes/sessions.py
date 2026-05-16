from flask import Blueprint, request, jsonify, make_response
from services.db_service import get_db_connection

sessions_bp = Blueprint('sessions', __name__)


# ── legacy endpoints (kept for ams_app backward compat) ─────────────────────
@sessions_bp.route('/get_course_sessions', methods=['POST'])
def get_course_sessions_legacy():
    try:
        cid    = request.form.get('course_id')
        conn   = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT cs.session_id, cs.session_type, cs.classroom_id,
                   cs.session_start, cs.session_end, cs.session_status,
                   (SELECT COUNT(*) FROM attendance_record ar
                    WHERE ar.session_id = cs.session_id AND ar.status = 'Present') AS present_count
            FROM   class_session cs
            WHERE  cs.course_id = ?
            ORDER  BY cs.session_start DESC
        """, (cid,))
        sessions = []
        for r in cursor.fetchall():
            sessions.append({
                "session_id":    r[0],
                "type":          r[1],
                "room":          r[2],
                "start":         r[3].strftime('%Y-%m-%d %H:%M') if r[3] else '',
                "end":           r[4].strftime('%Y-%m-%d %H:%M') if r[4] else '',
                "status":        r[5],
                "present_count": r[6]
            })
        conn.close()
        return jsonify({"success": True, "sessions": sessions}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@sessions_bp.route('/get_session_attendance', methods=['POST'])
def get_session_attendance_legacy():
    try:
        sid    = request.form.get('session_id')
        conn   = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT s.id, s.first_name + ' ' + s.last_name,
                   COALESCE(ar.status, 'Absent') AS status,
                   ar.marked_at, ar.id AS attendance_id
            FROM   enrollment    e
            JOIN   class_session cs ON cs.session_id = ?
            JOIN   student       s  ON s.id = e.student_id
            LEFT JOIN attendance_record ar
                   ON ar.session_id = cs.session_id AND ar.student_id = s.id
            WHERE  e.course_id = cs.course_id
            ORDER  BY s.first_name
        """, (sid,))
        records = []
        for r in cursor.fetchall():
            records.append({
                "student_id":    r[0],
                "student_name":  r[1],
                "status":        r[2],
                "marked_at":     r[3].strftime('%H:%M:%S') if r[3] else '',
                "attendance_id": r[4],
            })
        conn.close()
        return jsonify({"success": True, "records": records}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@sessions_bp.route('/start_session', methods=['POST'])
def start_session_legacy():
    try:
        sid    = request.form.get('session_id')
        conn   = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "UPDATE class_session SET session_status='Active', "
            "attendance_start=GETDATE() WHERE session_id=?", (sid,)
        )
        conn.commit()
        conn.close()
        return jsonify({"success": True, "message": "Session started"}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@sessions_bp.route('/end_session', methods=['POST'])
def end_session_legacy():
    try:
        sid    = request.form.get('session_id')
        conn   = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "UPDATE class_session SET session_status='Completed', "
            "attendance_end=GETDATE() WHERE session_id=?", (sid,)
        )
        conn.commit()
        conn.close()
        return jsonify({"success": True, "message": "Session ended"}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@sessions_bp.route('/export_attendance', methods=['GET'])
def export_attendance_legacy():
    try:
        sid    = request.args.get('session_id')
        conn   = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT s.id, s.first_name + ' ' + s.last_name AS student_name,
                   COALESCE(ar.status, 'Absent') AS status,
                   COALESCE(CONVERT(VARCHAR, ar.marked_at, 120), '') AS marked_at,
                   c.name AS course_name,
                   cs.session_start, cs.classroom_id
            FROM   enrollment    e
            JOIN   class_session cs ON cs.session_id = ?
            JOIN   course        c  ON c.id = cs.course_id
            JOIN   student       s  ON s.id = e.student_id
            LEFT JOIN attendance_record ar
                   ON ar.session_id = cs.session_id AND ar.student_id = s.id
            WHERE  e.course_id = cs.course_id
            ORDER  BY s.first_name
        """, (sid,))
        rows = cursor.fetchall()
        conn.close()
        lines = ["Student ID,Student Name,Status,Marked At,Course,Session Start,Room"]
        for r in rows:
            lines.append(f"{r[0]},{r[1]},{r[2]},{r[3]},{r[4]},{r[5]},{r[6]}")
        csv_content = "\n".join(lines)
        response = make_response(csv_content)
        response.headers["Content-Disposition"] = f"attachment; filename=attendance_session_{sid}.csv"
        response.headers["Content-Type"] = "text/csv"
        return response
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ── new session endpoints ────────────────────────────────────────────────────
@sessions_bp.route('/sessions/<int:session_id>/open', methods=['PUT'])
def open_session(session_id):
    try:
        conn   = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "UPDATE class_session SET session_status='Open', attendance_start=GETDATE() "
            "WHERE session_id=?", (session_id,)
        )
        if cursor.rowcount == 0:
            conn.close()
            return jsonify({"success": False, "message": "Session not found"}), 404
        conn.commit()
        conn.close()
        return jsonify({"success": True, "message": "Session opened"}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@sessions_bp.route('/sessions/<int:session_id>/close', methods=['PUT'])
def close_session(session_id):
    try:
        conn   = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "UPDATE class_session SET session_status='Closed', attendance_end=GETDATE() "
            "WHERE session_id=?", (session_id,)
        )
        if cursor.rowcount == 0:
            conn.close()
            return jsonify({"success": False, "message": "Session not found"}), 404
        conn.commit()
        conn.close()
        return jsonify({"success": True, "message": "Session closed"}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@sessions_bp.route('/sessions/<int:session_id>/attendance', methods=['GET'])
def session_attendance(session_id):
    try:
        conn   = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT s.id, s.first_name + ' ' + s.last_name,
                   COALESCE(ar.status, 'Absent') AS status,
                   ar.marked_at, ar.id AS attendance_id, ar.method
            FROM   enrollment    e
            JOIN   class_session cs ON cs.session_id = ?
            JOIN   student       s  ON s.id = e.student_id
            LEFT JOIN attendance_record ar
                   ON ar.session_id = cs.session_id AND ar.student_id = s.id
            WHERE  e.course_id = cs.course_id
            ORDER  BY s.first_name
        """, (session_id,))
        records = []
        for r in cursor.fetchall():
            records.append({
                "student_id":    r[0],
                "student_name":  r[1],
                "status":        r[2],
                "marked_at":     r[3].strftime('%Y-%m-%d %H:%M') if r[3] else '',
                "attendance_id": r[4],
                "method":        r[5] or '',
            })
        conn.close()
        return jsonify({"success": True, "records": records}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@sessions_bp.route('/attendance/<int:attendance_id>/update', methods=['PUT'])
def update_attendance(attendance_id):
    try:
        data         = request.get_json() or {}
        status       = data.get('status')
        if not status:
            return jsonify({"success": False, "message": "Missing status"}), 400

        editor_id    = data.get('editor_id')
        editor_name  = data.get('editor_name', '')
        old_status   = data.get('old_status', '')
        student_name = data.get('student_name', '')
        session_id   = data.get('session_id')

        conn   = get_db_connection()
        cursor = conn.cursor()

        cursor.execute(
            "SELECT student_id FROM attendance_record WHERE id=?",
            (attendance_id,)
        )
        row = cursor.fetchone()
        if not row:
            conn.close()
            return jsonify({"success": False, "message": "Record not found"}), 404
        student_id = row[0]

        cursor.execute(
            "UPDATE attendance_record SET status=?, last_updated=GETDATE() WHERE id=?",
            (status, attendance_id)
        )

        if editor_id:
            try:
                cursor.execute("""
                    INSERT INTO attendance_audit_log
                        (attendance_id, session_id, student_id, student_name,
                         editor_id, editor_name, old_status, new_status)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """, (attendance_id, session_id, student_id, student_name,
                      editor_id, editor_name, old_status, status))
            except Exception:
                pass

        conn.commit()
        conn.close()
        return jsonify({"success": True, "message": "Attendance updated"}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500
