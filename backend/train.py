import os
import cv2
import numpy as np
import pickle
import re
from insightface.app import FaceAnalysis

# --- CONFIGURATION ---
DATASET_DIR = 'dataset/train'      # Where your photo folders are
SAVE_FILE = 'face_encodings.pkl'   # The file where we save the "Brain"
MODEL_NAME = 'buffalo_l'           # The most accurate model
LABEL_PATTERN = re.compile(r'^.+ - 2022\d{4}$')
MIN_DET_SCORE = 0.65
MIN_FACE_SIZE_PX = 90
MIN_VALID_IMAGES_PER_PERSON = 5
# ---------------------


def init_face_app():
    try:
        app = FaceAnalysis(name=MODEL_NAME, providers=['CUDAExecutionProvider', 'CPUExecutionProvider'])
        app.prepare(ctx_id=0, det_size=(640, 640))
        print("Using GPU for training.")
        return app
    except Exception:
        app = FaceAnalysis(name=MODEL_NAME, providers=['CPUExecutionProvider'])
        app.prepare(ctx_id=-1, det_size=(640, 640))
        print("Using CPU for training.")
        return app


def is_good_training_face(face):
    det_score = float(getattr(face, 'det_score', 1.0))
    x1, y1, x2, y2 = face.bbox
    w = float(x2 - x1)
    h = float(y2 - y1)
    return det_score >= MIN_DET_SCORE and w >= MIN_FACE_SIZE_PX and h >= MIN_FACE_SIZE_PX


def train():
    print("Loading Model...")
    app = init_face_app()

    known_embeddings = []
    known_names = []

    if not os.path.exists(DATASET_DIR):
        print(f"Error: Directory '{DATASET_DIR}' not found.")
        return

    print(f"Scanning '{DATASET_DIR}' for faces...")

    valid_people = 0
    skipped_people = 0

    for folder_name in sorted(os.listdir(DATASET_DIR)):
        folder_path = os.path.join(DATASET_DIR, folder_name)

        if not os.path.isdir(folder_path):
            continue

        if not LABEL_PATTERN.match(folder_name):
            print(f" -> Skipped invalid label format: {folder_name}")
            skipped_people += 1
            continue

        person_label = folder_name
        print(f" -> Processing: {person_label}")

        person_embeddings = []
        images_processed = 0
        for img_name in sorted(os.listdir(folder_path)):
            img_path = os.path.join(folder_path, img_name)

            img = cv2.imread(img_path)
            if img is None:
                continue

            faces = app.get(img)

            if len(faces) == 1:
                face = faces[0]
                if not is_good_training_face(face):
                    continue

                embedding = face.embedding
                embedding = embedding / np.linalg.norm(embedding)

                person_embeddings.append(embedding)
                images_processed += 1

        if images_processed < MIN_VALID_IMAGES_PER_PERSON:
            print(f"    Skipped (only {images_processed} clean images).")
            skipped_people += 1
            continue

        # One robust prototype embedding per person (better against noisy samples)
        mean_embedding = np.mean(person_embeddings, axis=0)
        mean_embedding = mean_embedding / np.linalg.norm(mean_embedding)
        known_embeddings.append(mean_embedding.astype(np.float32))
        known_names.append(person_label)
        valid_people += 1
        print(f"    Learned {images_processed} clean images -> 1 prototype.")

    if len(known_names) == 0:
        print("No faces were found! Check your images.")
        return

    data = {
        "embeddings": known_embeddings,
        "names": known_names,
        "metadata": {
            "min_det_score": MIN_DET_SCORE,
            "min_face_size_px": MIN_FACE_SIZE_PX,
            "min_valid_images_per_person": MIN_VALID_IMAGES_PER_PERSON,
        }
    }

    with open(SAVE_FILE, 'wb') as f:
        pickle.dump(data, f)

    print(f"\n--- SUCCESS ---")
    print(f"Model trained on {valid_people} people.")
    print(f"Skipped people: {skipped_people}")
    print(f"Brain saved to: {SAVE_FILE}")

if __name__ == "__main__":
    train()
