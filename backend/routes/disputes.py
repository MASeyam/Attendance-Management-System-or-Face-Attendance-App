from flask import Blueprint, request, jsonify
from services.db_service import get_db_connection

disputes_bp = Blueprint('disputes', __name__)


@disputes_bp.route('/disputes/create', methods=['POST'])
def create_dispute():
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

        # Update or insert attendance record with status 'disputed'
        cursor.execute(
            "SELECT id FROM attendance_record WHERE student_id=? AND session_id=?",
            (student_id, session_id)
        )
        existing = cursor.fetchone()
        if existing:
            cursor.execute(
                "UPDATE attendance_record SET status='disputed', last_updated=GETDATE() "
                "WHERE student_id=? AND session_id=?",
                (student_id, session_id)
            )
        else:
            cursor.execute(
                "INSERT INTO attendance_record (session_id, student_id, status, method, marked_at) "
                "VALUES (?, ?, 'disputed', 'Manual', GETDATE())",
                (session_id, student_id)
            )

        conn.commit()
        conn.close()
        return jsonify({"success": True, "message": "Dispute submitted"}), 201
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@disputes_bp.route('/disputes/instructor/<int:instructor_id>', methods=['GET'])
def get_instructor_disputes(instructor_id):
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
        disputes = []
        for r in cursor.fetchall():
            disputes.append({
                "dispute_id":      r[0],
                "student_id":      r[1],
                "student_name":    r[2],
                "course_name":     r[3],
                "session_start":   r[4].strftime('%Y-%m-%d %H:%M') if r[4] else '',
                "reason":          r[5],
                "status":          r[6],
                "submitted_at":    r[7].strftime('%Y-%m-%d %H:%M') if r[7] else '',
                "instructor_reply": r[8],
                "handled_at":      r[9].strftime('%Y-%m-%d %H:%M') if r[9] else '',
            })
        conn.close()
        return jsonify({"success": True, "disputes": disputes}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@disputes_bp.route('/disputes/<int:dispute_id>/handle', methods=['PUT'])
def handle_dispute(dispute_id):
    try:
        data             = request.get_json() or {}
        instructor_reply = data.get('instructor_reply', '')
        handled_by       = data.get('handled_by')

        conn   = get_db_connection()
        cursor = conn.cursor()

        cursor.execute(
            "SELECT student_id, session_id FROM disputes WHERE dispute_id=?",
            (dispute_id,)
        )
        row = cursor.fetchone()
        if not row:
            conn.close()
            return jsonify({"success": False, "message": "Dispute not found"}), 404

        student_id, session_id = row

        cursor.execute("""
            UPDATE disputes
            SET    status='handled', instructor_reply=?, handled_at=GETDATE(), handled_by=?
            WHERE  dispute_id=?
        """, (instructor_reply, handled_by, dispute_id))

        cursor.execute("""
            UPDATE attendance_record
            SET    status='resolved', last_updated=GETDATE()
            WHERE  student_id=? AND session_id=?
        """, (student_id, session_id))

        conn.commit()
        conn.close()
        return jsonify({"success": True, "message": "Dispute handled"}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500
