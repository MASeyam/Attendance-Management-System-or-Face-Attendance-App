import bcrypt
from flask import Blueprint, request, jsonify
from services.db_service import get_db_connection
from config import ADMIN_PIN

auth_bp = Blueprint('auth', __name__)


def _check_password(plain, stored):
    if not stored:
        return False
    stored = stored.strip()
    if stored.startswith('$2b$') or stored.startswith('$2a$'):
        return bcrypt.checkpw(plain.encode(), stored.encode())
    return plain == stored


def _hash_password(plain):
    return bcrypt.hashpw(plain.encode(), bcrypt.gensalt()).decode()


# ── legacy unified login (kept for ams_app backward compat) ─────────────────
@auth_bp.route('/login', methods=['POST'])
def login():
    try:
        data       = request.get_json()
        identifier = data.get('username') or data.get('student_id', '')
        password   = data.get('password', '')
        conn       = get_db_connection()
        cursor     = conn.cursor()

        if str(identifier).isdigit():
            cursor.execute(
                "SELECT id, first_name, last_name, password FROM student WHERE id=?",
                (identifier,)
            )
            row = cursor.fetchone()
            if row and _check_password(password, row[3] or ''):
                conn.close()
                return jsonify({"success": True, "role": "Student",
                                "id": row[0], "name": f"{row[1]} {row[2]}"}), 200

        cursor.execute(
            "SELECT id, first_name, last_name, role, password FROM instructor WHERE username=?",
            (identifier,)
        )
        row = cursor.fetchone()
        if row and _check_password(password, row[4] or ''):
            conn.close()
            return jsonify({"success": True, "role": row[3] or "Instructor",
                            "id": row[0], "name": f"{row[1]} {row[2]}"}), 200

        conn.close()
        return jsonify({"success": False, "message": "Invalid credentials"}), 401
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@auth_bp.route('/verify_admin_pin', methods=['POST'])
def verify_admin_pin():
    data = request.get_json() or {}
    if data.get('pin', '') == ADMIN_PIN:
        return jsonify({"success": True}), 200
    return jsonify({"success": False, "message": "Wrong PIN"}), 401


# ── new role-specific login endpoints ────────────────────────────────────────
@auth_bp.route('/auth/student/login', methods=['POST'])
def student_login():
    try:
        data     = request.get_json() or {}
        email    = data.get('email', '').strip()
        password = data.get('password', '')
        conn     = get_db_connection()
        cursor   = conn.cursor()
        cursor.execute("""
            SELECT id, first_name, last_name, email, password,
                   academic_year, level, group_name, gpa, department_id
            FROM   student
            WHERE  email = ?
        """, (email,))
        row = cursor.fetchone()
        conn.close()
        if not row or not _check_password(password, row[4] or ''):
            return jsonify({"success": False, "message": "Invalid email or password"}), 401
        return jsonify({
            "success":       True,
            "id":            row[0],
            "first_name":    row[1],
            "last_name":     row[2],
            "email":         row[3],
            "academic_year": row[5],
            "level":         row[6],
            "group_name":    row[7],
            "gpa":           float(row[8]) if row[8] is not None else None,
            "department_id": row[9],
        }), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@auth_bp.route('/auth/instructor/login', methods=['POST'])
def instructor_login():
    try:
        data     = request.get_json() or {}
        email    = data.get('email', '').strip()
        password = data.get('password', '')
        conn     = get_db_connection()
        cursor   = conn.cursor()
        cursor.execute("""
            SELECT id, first_name, last_name, email, password, role, department_id
            FROM   instructor
            WHERE  email = ?
        """, (email,))
        row = cursor.fetchone()
        conn.close()
        if not row or not _check_password(password, row[4] or ''):
            return jsonify({"success": False, "message": "Invalid email or password"}), 401
        return jsonify({
            "success":       True,
            "id":            row[0],
            "first_name":    row[1],
            "last_name":     row[2],
            "email":         row[3],
            "role":          row[5],
            "department_id": row[6],
        }), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@auth_bp.route('/auth/admin/login', methods=['POST'])
def admin_login():
    try:
        data     = request.get_json() or {}
        username = data.get('username', '').strip()
        password = data.get('password', '')
        conn     = get_db_connection()
        cursor   = conn.cursor()
        cursor.execute(
            "SELECT id, username, password, full_name, email, role FROM admin WHERE username=?",
            (username,)
        )
        row = cursor.fetchone()
        conn.close()
        if not row or not _check_password(password, row[2] or ''):
            return jsonify({"success": False, "message": "Invalid username or password"}), 401
        return jsonify({
            "success":   True,
            "id":        row[0],
            "username":  row[1],
            "full_name": row[3],
            "email":     row[4],
            "role":      row[5],
        }), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@auth_bp.route('/auth/change-password', methods=['PUT'])
def change_password():
    try:
        data         = request.get_json() or {}
        user_id      = data.get('user_id')
        role         = data.get('role', '').lower()
        old_password = data.get('old_password', '')
        new_password = data.get('new_password', '')

        if not all([user_id, role, old_password, new_password]):
            return jsonify({"success": False, "message": "Missing required fields"}), 400

        conn   = get_db_connection()
        cursor = conn.cursor()

        table_map = {'student': 'student', 'instructor': 'instructor', 'admin': 'admin'}
        table = table_map.get(role)
        if not table:
            conn.close()
            return jsonify({"success": False, "message": "Invalid role"}), 400

        cursor.execute(f"SELECT password FROM {table} WHERE id=?", (user_id,))
        row = cursor.fetchone()
        if not row or not _check_password(old_password, row[0] or ''):
            conn.close()
            return jsonify({"success": False, "message": "Old password is incorrect"}), 401

        new_hash = _hash_password(new_password)
        cursor.execute(f"UPDATE {table} SET password=? WHERE id=?", (new_hash, user_id))
        conn.commit()
        conn.close()
        return jsonify({"success": True, "message": "Password updated"}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500
