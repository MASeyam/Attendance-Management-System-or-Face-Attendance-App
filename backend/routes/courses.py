from datetime import datetime, timedelta
from flask import Blueprint, request, jsonify
from services.db_service import get_db_connection

courses_bp = Blueprint('courses', __name__)

_DAY_MAP = {
    'mon': 0, 'tue': 1, 'wed': 2, 'thu': 3, 'fri': 4, 'sat': 5, 'sun': 6,
}


def _parse_session_days(days_list):
    result = []
    for d in days_list:
        key = d.lower()[:3]
        if key in _DAY_MAP:
            result.append(_DAY_MAP[key])
    return result


def _generate_dates(start_date, target_weekdays, total_count):
    dates = []
    current = start_date
    while len(dates) < total_count:
        if current.weekday() in target_weekdays:
            dates.append(current)
        current += timedelta(days=1)
    return dates


@courses_bp.route('/courses', methods=['GET'])
def get_all_courses():
    try:
        conn   = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT c.id, c.name, c.credit_hours, c.department_id,
                   d.name                                  AS department_name,
                   c.instructor_id,
                   i.first_name + ' ' + i.last_name        AS instructor_name,
                   (SELECT COUNT(*) FROM enrollment e WHERE e.course_id = c.id) AS enrolled_count
            FROM   course      c
            LEFT JOIN department d ON d.id = c.department_id
            LEFT JOIN instructor i ON i.id = c.instructor_id
            ORDER  BY c.name
        """)
        courses = []
        for r in cursor.fetchall():
            courses.append({
                "id":              r[0],
                "name":            r[1],
                "credit_hours":    r[2],
                "department_id":   r[3],
                "department_name": r[4],
                "instructor_id":   r[5],
                "instructor_name": r[6],
                "enrolled_count":  r[7],
            })
        conn.close()
        return jsonify({"success": True, "courses": courses}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@courses_bp.route('/courses/create', methods=['POST'])
def create_course():
    try:
        data = request.get_json() or {}
        required = ['name', 'instructor_id', 'sessions_per_week',
                    'duration_months', 'start_date', 'session_days',
                    'start_time', 'end_time']
        for f in required:
            if not data.get(f) and data.get(f) != 0:
                return jsonify({"success": False, "message": f"Missing field: {f}"}), 400

        name             = data['name']
        credit_hours     = data.get('credit_hours')
        department_id    = data.get('department_id')
        instructor_id    = data['instructor_id']
        classroom_id     = data.get('classroom_id')
        sessions_per_week = int(data['sessions_per_week'])
        duration_months  = int(data['duration_months'])
        start_date_str   = data['start_date']
        session_days     = data['session_days']
        start_time_str   = data['start_time']
        end_time_str     = data['end_time']
        student_ids      = data.get('student_ids', [])

        start_date = datetime.strptime(start_date_str, '%Y-%m-%d').date()
        total_sessions = sessions_per_week * (duration_months * 4)
        target_weekdays = _parse_session_days(session_days)

        conn   = get_db_connection()
        cursor = conn.cursor()

        # Insert course
        cursor.execute("""
            INSERT INTO course (name, credit_hours, department_id, instructor_id)
            OUTPUT INSERTED.id
            VALUES (?, ?, ?, ?)
        """, (name, credit_hours, department_id, instructor_id))
        course_id = cursor.fetchone()[0]

        # Generate session dates
        session_dates = _generate_dates(
            datetime.combine(start_date, datetime.min.time()),
            target_weekdays,
            total_sessions
        )

        sessions_created = 0
        for dt in session_dates:
            session_start = datetime.strptime(
                f"{dt.strftime('%Y-%m-%d')} {start_time_str}", '%Y-%m-%d %H:%M'
            )
            session_end = datetime.strptime(
                f"{dt.strftime('%Y-%m-%d')} {end_time_str}", '%Y-%m-%d %H:%M'
            )
            cursor.execute("""
                INSERT INTO class_session
                  (course_id, instructor_id, classroom_id, session_type,
                   session_start, session_end, session_status)
                VALUES (?, ?, ?, 'Lecture', ?, ?, 'Scheduled')
            """, (course_id, instructor_id, classroom_id, session_start, session_end))
            sessions_created += 1

        # Enroll students
        enrollments_created = 0
        for sid in student_ids:
            try:
                cursor.execute("""
                    INSERT INTO enrollment (student_id, course_id, status, enrolled_date)
                    VALUES (?, ?, 'Enrolled', GETDATE())
                """, (sid, course_id))
                enrollments_created += 1
            except Exception:
                pass  # Skip duplicate enrollments

        conn.commit()
        conn.close()
        return jsonify({
            "success":              True,
            "course_id":            course_id,
            "total_sessions_created": sessions_created,
            "enrollments_created":  enrollments_created,
        }), 201
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@courses_bp.route('/classrooms', methods=['GET'])
def get_classrooms():
    try:
        conn   = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT id, building, capacity FROM classroom ORDER BY id")
        classrooms = [{"id": r[0], "building": r[1], "capacity": r[2]}
                      for r in cursor.fetchall()]
        conn.close()
        return jsonify({"success": True, "classrooms": classrooms}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@courses_bp.route('/departments', methods=['GET'])
def get_departments():
    try:
        conn   = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT id, name FROM department ORDER BY name")
        departments = [{"id": r[0], "name": r[1]} for r in cursor.fetchall()]
        conn.close()
        return jsonify({"success": True, "departments": departments}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500
