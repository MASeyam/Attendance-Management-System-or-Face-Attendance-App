from flask import Blueprint, request, jsonify
from services.db_service import get_db_connection

issues_bp = Blueprint('issues', __name__)

VALID_VERDICTS = {'accepted', 'declined'}


@issues_bp.route('/issues/create', methods=['POST'])
def create_issue():
    try:
        data       = request.get_json() or {}
        student_id = data.get('student_id')
        session_id = data.get('session_id')
        reason     = data.get('reason', '')

        if not all([student_id, session_id, reason]):
            return jsonify({"success": False, "message": "Missing required fields"}), 400

        conn   = get_db_connection()
        cursor = conn.cursor()

        cursor.execute("""
            INSERT INTO disputes (student_id, session_id, reason, status, submitted_at)
            VALUES (?, ?, ?, 'pending', GETDATE())
        """, (student_id, session_id, reason))

        # Mark attendance as 'issued' so the status is visible in reports
        cursor.execute(
            "SELECT id FROM attendance_record WHERE student_id=? AND session_id=?",
            (student_id, session_id)
        )
        existing = cursor.fetchone()
        if existing:
            cursor.execute(
                "UPDATE attendance_record SET status='issued', last_updated=GETDATE() "
                "WHERE student_id=? AND session_id=?",
                (student_id, session_id)
            )
        else:
            cursor.execute(
                "INSERT INTO attendance_record (session_id, student_id, status, method, marked_at) "
                "VALUES (?, ?, 'issued', 'Manual', GETDATE())",
                (session_id, student_id)
            )

        conn.commit()
        conn.close()
        return jsonify({"success": True, "message": "Issue submitted"}), 201
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@issues_bp.route('/issues/instructor/<int:instructor_id>', methods=['GET'])
def get_instructor_issues(instructor_id):
    try:
        conn   = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT d.dispute_id, d.student_id,
                   s.first_name + ' ' + s.last_name AS student_name,
                   c.name AS course_name,
                   cs.session_start, d.reason, d.status,
                   d.submitted_at, d.instructor_reply, d.handled_at
            FROM   disputes      d
            JOIN   student       s  ON s.id  = d.student_id
            JOIN   class_session cs ON cs.session_id = d.session_id
            JOIN   course        c  ON c.id  = cs.course_id
            WHERE  cs.instructor_id = ?
            ORDER  BY d.submitted_at DESC
        """, (instructor_id,))
        issues = []
        for r in cursor.fetchall():
            issues.append({
                "issue_id":         r[0],
                "dispute_id":       r[0],   # backward compat
                "student_id":       r[1],
                "student_name":     r[2],
                "course_name":      r[3],
                "session_start":    r[4].strftime('%Y-%m-%d %H:%M') if r[4] else '',
                "reason":           r[5],
                "status":           r[6],
                "submitted_at":     r[7].strftime('%Y-%m-%d %H:%M') if r[7] else '',
                "instructor_reply": r[8],
                "handled_at":       r[9].strftime('%Y-%m-%d %H:%M') if r[9] else '',
            })
        conn.close()
        return jsonify({"success": True, "issues": issues}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@issues_bp.route('/issues/<int:issue_id>/handle', methods=['PUT'])
def handle_issue(issue_id):
    try:
        data             = request.get_json() or {}
        verdict          = data.get('verdict', '').lower().strip()
        instructor_reply = data.get('instructor_reply', '')
        handled_by       = data.get('handled_by')

        if verdict not in VALID_VERDICTS:
            return jsonify({
                "success": False,
                "message": f"Missing or invalid verdict. Must be one of: {sorted(VALID_VERDICTS)}"
            }), 400

        conn   = get_db_connection()
        cursor = conn.cursor()

        cursor.execute(
            "SELECT student_id, session_id FROM disputes WHERE dispute_id=?",
            (issue_id,)
        )
        row = cursor.fetchone()
        if not row:
            conn.close()
            return jsonify({"success": False, "message": "Issue not found"}), 404

        student_id, session_id = row

        # Write verdict ('accepted' or 'declined') directly as the new status
        cursor.execute("""
            UPDATE disputes
            SET    status=?, instructor_reply=?, handled_at=GETDATE(), handled_by=?
            WHERE  dispute_id=?
        """, (verdict, instructor_reply, handled_by, issue_id))

        # Resolve the attendance record regardless of verdict
        cursor.execute("""
            UPDATE attendance_record
            SET    status='resolved', last_updated=GETDATE()
            WHERE  student_id=? AND session_id=?
        """, (student_id, session_id))

        conn.commit()
        conn.close()
        return jsonify({"success": True, "message": f"Issue {verdict}"}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@issues_bp.route('/students/<int:student_id>/issues', methods=['GET'])
def get_student_issues(student_id):
    try:
        conn   = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT d.dispute_id, c.name AS course_name,
                   cs.session_start, d.reason, d.status,
                   d.instructor_reply, d.submitted_at, d.handled_at
            FROM   disputes      d
            JOIN   class_session cs ON cs.session_id = d.session_id
            JOIN   course        c  ON c.id = cs.course_id
            WHERE  d.student_id = ?
            ORDER  BY d.submitted_at DESC
        """, (student_id,))
        issues = []
        for r in cursor.fetchall():
            issues.append({
                "issue_id":          r[0],
                "course_name":       r[1],
                "session_start":     r[2].strftime('%Y-%m-%d %H:%M') if r[2] else '',
                "reason":            r[3],
                "status":            r[4],
                "instructor_reply":  r[5],
                "submitted_at":      r[6].strftime('%Y-%m-%d %H:%M') if r[6] else '',
                "handled_at":        r[7].strftime('%Y-%m-%d %H:%M') if r[7] else '',
            })
        conn.close()
        return jsonify({"success": True, "issues": issues}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500
