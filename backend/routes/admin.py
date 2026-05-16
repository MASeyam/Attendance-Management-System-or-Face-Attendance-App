from flask import Blueprint, request, jsonify
from services.db_service import get_db_connection

admin_bp = Blueprint('admin', __name__)


@admin_bp.route('/admin/stats', methods=['GET'])
def admin_stats():
    try:
        conn   = get_db_connection()
        cursor = conn.cursor()

        cursor.execute("SELECT COUNT(*) FROM student")
        total_students = cursor.fetchone()[0]

        cursor.execute("SELECT COUNT(*) FROM instructor")
        total_instructors = cursor.fetchone()[0]

        cursor.execute("SELECT COUNT(*) FROM course")
        total_courses = cursor.fetchone()[0]

        cursor.execute("""
            SELECT COUNT(*) FROM class_session
            WHERE CAST(session_start AS DATE) = CAST(GETDATE() AS DATE)
        """)
        total_sessions_today = cursor.fetchone()[0]

        cursor.execute("""
            SELECT TOP 5
                   d.dispute_id, d.student_id,
                   s.first_name + ' ' + s.last_name AS student_name,
                   c.name AS course_name, d.reason, d.submitted_at
            FROM   disputes      d
            JOIN   student       s  ON s.id = d.student_id
            JOIN   class_session cs ON cs.session_id = d.session_id
            JOIN   course        c  ON c.id = cs.course_id
            WHERE  d.status = 'pending'
            ORDER  BY d.submitted_at DESC
        """)
        pending_disputes = []
        for r in cursor.fetchall():
            pending_disputes.append({
                "dispute_id":   r[0],
                "student_id":   r[1],
                "student_name": r[2],
                "course_name":  r[3],
                "reason":       r[4],
                "submitted_at": r[5].strftime('%Y-%m-%d %H:%M') if r[5] else '',
            })

        conn.close()
        return jsonify({
            "success":              True,
            "total_students":       total_students,
            "total_instructors":    total_instructors,
            "total_courses":        total_courses,
            "total_sessions_today": total_sessions_today,
            "pending_disputes":     pending_disputes,
            "pending_issues":       pending_disputes,  # alias for Flutter
        }), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@admin_bp.route('/admin/audit-logs', methods=['GET'])
def audit_logs():
    try:
        instructor = request.args.get('instructor', '').strip()
        student    = request.args.get('student', '').strip()
        date_from  = request.args.get('date_from')
        date_to    = request.args.get('date_to')

        conn   = get_db_connection()
        cursor = conn.cursor()

        query = """
            SELECT al.log_id, al.old_status, al.new_status,
                   al.student_name, al.editor_name,
                   c.name AS course_name,
                   cs.session_start,
                   al.edited_at
            FROM   attendance_audit_log al
            JOIN   attendance_record    ar ON ar.id = al.attendance_id
            JOIN   class_session        cs ON cs.session_id = al.session_id
            JOIN   course               c  ON c.id = cs.course_id
            WHERE  1=1
        """
        params = []

        if instructor:
            query += " AND al.editor_name LIKE ?"
            params.append(f'%{instructor}%')
        if student:
            query += " AND al.student_name LIKE ?"
            params.append(f'%{student}%')
        if date_from:
            query += " AND CAST(al.edited_at AS DATE) >= ?"
            params.append(date_from)
        if date_to:
            query += " AND CAST(al.edited_at AS DATE) <= ?"
            params.append(date_to)

        query += " ORDER BY al.edited_at DESC"
        cursor.execute(query, params)

        logs = []
        for r in cursor.fetchall():
            logs.append({
                "log_id":          r[0],
                "old_status":      r[1] or '',
                "new_status":      r[2] or '',
                "student_name":    r[3] or '',
                "instructor_name": r[4] or '',
                "course_name":     r[5] or '',
                "session_date":    r[6].strftime('%Y-%m-%d %H:%M') if r[6] else '',
                "timestamp":       r[7].strftime('%Y-%m-%d %H:%M') if r[7] else '',
            })
        conn.close()
        return jsonify({"success": True, "logs": logs}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@admin_bp.route('/admin/attendance-logs', methods=['GET'])
def attendance_logs():
    try:
        course_id  = request.args.get('course_id')
        student_id = request.args.get('student_id')
        date_from  = request.args.get('date_from')
        date_to    = request.args.get('date_to')
        status     = request.args.get('status')

        conn   = get_db_connection()
        cursor = conn.cursor()

        query = """
            SELECT ar.id, s.id, s.first_name + ' ' + s.last_name,
                   c.name, cs.session_start, ar.status, ar.method, ar.marked_at
            FROM   attendance_record ar
            JOIN   student          s  ON s.id  = ar.student_id
            JOIN   class_session    cs ON cs.session_id = ar.session_id
            JOIN   course           c  ON c.id  = cs.course_id
            WHERE  1=1
        """
        params = []

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
        if status:
            query += " AND ar.status = ?"
            params.append(status)

        query += " ORDER BY ar.marked_at DESC"
        cursor.execute(query, params)

        logs = []
        for r in cursor.fetchall():
            logs.append({
                "record_id":     r[0],
                "student_id":    r[1],
                "student_name":  r[2],
                "course_name":   r[3],
                "session_start": r[4].strftime('%Y-%m-%d %H:%M') if r[4] else '',
                "status":        r[5],
                "method":        r[6] or '',
                "marked_at":     r[7].strftime('%Y-%m-%d %H:%M') if r[7] else '',
            })
        conn.close()
        return jsonify({"success": True, "logs": logs}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500
