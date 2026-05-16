from flask import Blueprint, request, jsonify
from services.db_service import get_db_connection

notifications_bp = Blueprint('notifications', __name__)


@notifications_bp.route('/notifications/<int:user_id>/<user_role>', methods=['GET'])
def get_notifications(user_id, user_role):
    try:
        conn   = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT notification_id, title, body, is_read, created_at
            FROM   notifications
            WHERE  user_id = ? AND user_role = ?
            ORDER  BY created_at DESC
        """, (user_id, user_role))
        items = []
        for r in cursor.fetchall():
            items.append({
                "notification_id": r[0],
                "title":           r[1],
                "body":            r[2],
                "is_read":         bool(r[3]),
                "created_at":      r[4].strftime('%Y-%m-%d %H:%M') if r[4] else '',
            })
        conn.close()
        return jsonify({"success": True, "notifications": items}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@notifications_bp.route('/notifications/<int:notification_id>/read', methods=['PUT'])
def mark_read(notification_id):
    try:
        conn   = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "UPDATE notifications SET is_read=1 WHERE notification_id=?",
            (notification_id,)
        )
        if cursor.rowcount == 0:
            conn.close()
            return jsonify({"success": False, "message": "Notification not found"}), 404
        conn.commit()
        conn.close()
        return jsonify({"success": True, "message": "Marked as read"}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500
