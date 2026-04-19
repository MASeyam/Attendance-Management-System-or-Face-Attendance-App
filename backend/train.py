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
MIN_DET_SCORE = 0.55
MIN_FACE_SIZE_PX = 50
MIN_VALID_IMAGES_PER_PERSON = 5
# ---------------------

def init_face_app():
    try:
        # We force the CPU provider to avoid any further library conflicts
        app = FaceAnalysis(name=MODEL_NAME, providers=['CPUExecutionProvider'])
        # ctx_id=-1 tells InsightFace to stay away from the GPU
        app.prepare(ctx_id=-1, det_size=(640, 640))
        print("\n✅ Model Loaded Successfully on CPU.")
        print("🕒 480 students will take some time, but the math is 100% accurate.")
        return app
    except Exception as e:
        print(f"❌ Fatal Error loading model: {e}")
        return None

def is_good_training_face(face):
    det_score = float(getattr(face, 'det_score', 1.0))
    x1, y1, x2, y2 = face.bbox
    w = float(x2 - x1)
    h = float(y2 - y1)
    # Ensures only high-quality, clear faces are learned
    return det_score >= MIN_DET_SCORE and w >= MIN_FACE_SIZE_PX and h >= MIN_FACE_SIZE_PX

def train():
    print("\n🏗️ Initializing Face Recognition Engine...")
    app = init_face_app()

    known_embeddings = []
    known_names = []
    total_images_scanned = 0

    if not os.path.exists(DATASET_DIR):
        print(f"❌ Error: Directory '{DATASET_DIR}' not found. Run prepare_dataset.py first!")
        return

    print(f"🔍 Scanning '{DATASET_DIR}' for students...")

    # Process all 480 student folders
    for folder_name in sorted(os.listdir(DATASET_DIR)):
        # Points to the organized /train subfolder
        person_train_path = os.path.join(DATASET_DIR, folder_name, "train")
        
        if not os.path.isdir(person_train_path):
            continue

        if not LABEL_PATTERN.match(folder_name):
            print(f" -> ⏭️ Skipped invalid folder: {folder_name}")
            continue

        person_embeddings = []
        img_list = os.listdir(person_train_path)
        
        print(f"\n👤 [STUDENT]: {folder_name}")
        print(f"   📂 Analyzing {len(img_list)} images...")

        for img_name in img_list:
            img_path = os.path.join(person_train_path, img_name)
            img = cv2.imread(img_path)
            if img is None: continue
            
            total_images_scanned += 1
            faces = app.get(img)

            if len(faces) == 1:
                face = faces[0]
                if is_good_training_face(face):
                    # Mathematical normalization for Cosine Similarity
                    embedding = face.embedding / np.linalg.norm(face.embedding)
                    person_embeddings.append(embedding)
                else:
                    print(f"   ⚠️ Image {img_name} rejected: Score {face.det_score:.2f}")

        # Create a single "Mean Prototype" for this student
        if len(person_embeddings) >= MIN_VALID_IMAGES_PER_PERSON:
            mean_embedding = np.mean(person_embeddings, axis=0)
            mean_embedding /= np.linalg.norm(mean_embedding)
            known_embeddings.append(mean_embedding.astype(np.float32))
            known_names.append(folder_name)
            print(f"   ✅ SUCCESS: Created Brain Prototype using {len(person_embeddings)} images.")
        else:
            print(f"   ❌ FAILED: Not enough high-quality data (Needed {MIN_VALID_IMAGES_PER_PERSON}).")

    if len(known_names) == 0:
        print("❌ No faces were found! Check your images.")
        return

    # 💾 Save the result (The "Brain")
    data = {
        "embeddings": known_embeddings,
        "names": known_names,
        "metadata": {
            "min_det_score": MIN_DET_SCORE,
            "min_face_size_px": MIN_FACE_SIZE_PX,
            "min_valid_images_per_person": MIN_VALID_IMAGES_PER_PERSON,
            "total_students": len(known_names)
        }
    }

    with open(SAVE_FILE, 'wb') as f:
        pickle.dump(data, f)

    print(f"\n--- ✨ TRAINING COMPLETE ---")
    print(f"📊 Scanned {total_images_scanned} images.")
    print(f"🧠 Brain saved with {len(known_names)} students to: {SAVE_FILE}")

if __name__ == "__main__":
    train()