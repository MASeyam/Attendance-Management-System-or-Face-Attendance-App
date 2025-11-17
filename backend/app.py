# ============================================================================
# ATTENDANCE SYSTEM BACKEND (PYTHON)
# ============================================================================
# TODO for Backend Team:
# 1. This file is the "Server". It receives the photo from the Mobile App.
# 2. You need to install these libraries (add them to requirements.txt):
#    - flask (for the API)
#    - face-recognition (for the logic)
#    - opencv-python (cv2)
#    - mysql-connector-python (to talk to the database)
# ============================================================================

# import flask
# import face_recognition
# import mysql.connector

# 1. SETUP FLASK APP
# app = Flask(__name__)

# 2. DATABASE CONNECTION
# TODO: Create a function here to connect to MySQL.
# def get_db_connection():
#     pass

# 3. API ROUTE: REGISTER STUDENT
# TODO: Create a route that accepts a Name + Photo to save a new student to the DB.
# @app.route('/register', methods=['POST'])
# def register():
#     pass

# 4. API ROUTE: MARK ATTENDANCE
# TODO: This is the most important part!
# - Receive an image from the Flutter app.
# - Convert it to a format 'face_recognition' understands.
# - Compare it with faces in the database.
# - If match found -> Insert into 'attendance_logs' table.
# - Return JSON response: {"status": "success", "student": "Name"}
# @app.route('/scan', methods=['POST'])
# def scan_face():
#     pass

# if __name__ == '__main__':
#     app.run(host='0.0.0.0', port=5000, debug=True)