import os
from flask import Blueprint, request, jsonify
from services.face_recognition import engine
from services.db_service import get_db_connection
from config import DATASET_DIR

train_bp = Blueprint('train', __name__)


@train_bp.route('/reload_brain', methods=['POST'])
def reload_brain():
    engine.reload_brain()
    return jsonify({"success": True,
                    "message": f"Brain reloaded: {len(engine.known_faces)} faces"}), 200


@train_bp.route('/train/student/<student_id>', methods=['POST'])
def train_student(student_id):
    try:
        folder = os.path.join(DATASET_DIR, str(student_id))
        if not os.path.exists(folder):
            return jsonify({"success": False,
                            "message": f"Photo folder not found: {folder}"}), 404

        embedding = engine.generate_embedding_from_folder(folder)
        if embedding is None:
            return jsonify({"success": False,
                            "message": "No valid faces found in uploaded photos"}), 422

        conn   = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT first_name, last_name FROM student WHERE id=?", (student_id,))
        row = cursor.fetchone()
        if row:
            label = f"{row[0]} {row[1]} - {student_id}"
            import json
            cursor.execute(
                "UPDATE student SET facial_encoding=? WHERE id=?",
                (json.dumps(embedding.tolist()), student_id)
            )
            conn.commit()
        else:
            label = f"Student - {student_id}"
        conn.close()

        engine.add_person(label, embedding)
        return jsonify({
            "success": True,
            "message": f"Training complete for student {student_id}",
            "total_faces": len(engine.known_faces),
        }), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@train_bp.route('/train/instructor/<int:instructor_id>', methods=['POST'])
def train_instructor(instructor_id):
    try:
        folder = os.path.join(DATASET_DIR, f"instructor_{instructor_id}")
        if not os.path.exists(folder):
            return jsonify({"success": False,
                            "message": f"Photo folder not found: {folder}"}), 404

        embedding = engine.generate_embedding_from_folder(folder)
        if embedding is None:
            return jsonify({"success": False,
                            "message": "No valid faces found in uploaded photos"}), 422

        conn   = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT first_name, last_name FROM instructor WHERE id=?", (instructor_id,))
        row = cursor.fetchone()
        label = f"{row[0]} {row[1]} - INS{instructor_id}" if row else f"Instructor - {instructor_id}"
        conn.close()

        engine.add_person(label, embedding)
        return jsonify({
            "success": True,
            "message": f"Training complete for instructor {instructor_id}",
            "total_faces": len(engine.known_faces),
        }), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@train_bp.route('/train/upload/<path:person_id>', methods=['POST'])
def upload_photos(person_id):
    """
    Receive photos from the Flutter admin app and save them to the dataset folder.
    person_id can be a student_id (numeric) or 'instructor_{id}'.
    """
    try:
        if 'photos' not in request.files:
            return jsonify({"success": False, "message": "No photos in request"}), 400

        folder = os.path.join(DATASET_DIR, str(person_id))
        os.makedirs(folder, exist_ok=True)

        files = request.files.getlist('photos')
        if len(files) < 5:
            return jsonify({"success": False,
                            "message": "Minimum 5 photos required"}), 400

        saved = 0
        for i, f in enumerate(files):
            if f.filename:
                ext  = os.path.splitext(f.filename)[1] or '.jpg'
                path = os.path.join(folder, f"photo_{i+1}{ext}")
                f.save(path)
                saved += 1

        return jsonify({"success": True, "saved": saved, "folder": folder}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500
