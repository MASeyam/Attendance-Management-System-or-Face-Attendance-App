import os
import cv2
import numpy as np
import pickle
from insightface.app import FaceAnalysis

# --- CONFIGURATION ---
DATASET_DIR = 'dataset/train'      # Where your photo folders are
SAVE_FILE = 'face_encodings.pkl'   # The file where we save the "Brain"
MODEL_NAME = 'buffalo_l'           # The most accurate model
# ---------------------

def train():
    # 1. Initialize the InsightFace Model
    # ctx_id=0 for GPU, -1 for CPU
    print("Loading Model...")
    app = FaceAnalysis(name=MODEL_NAME, providers=['CUDAExecutionProvider', 'CPUExecutionProvider'])
    app.prepare(ctx_id=0, det_size=(640, 640))

    known_embeddings = []
    known_names = []
    
    # 2. Loop through every folder in dataset/train
    if not os.path.exists(DATASET_DIR):
        print(f"Error: Directory '{DATASET_DIR}' not found.")
        return

    print(f"Scanning '{DATASET_DIR}' for faces...")
    
    for folder_name in os.listdir(DATASET_DIR):
        folder_path = os.path.join(DATASET_DIR, folder_name)
        
        # We only care about folders
        if not os.path.isdir(folder_path):
            continue
            
        # The folder name IS the label (e.g., "Abdulrahman Seyam - 20225389")
        person_label = folder_name
        
        print(f" -> Processing: {person_label}")
        
        # Scan images inside the folder
        images_processed = 0
        for img_name in os.listdir(folder_path):
            img_path = os.path.join(folder_path, img_name)
            
            # Read image
            img = cv2.imread(img_path)
            if img is None: continue
            
            # Detect faces
            faces = app.get(img)
            
            # STRICT RULE: We only learn if there is exactly ONE face.
            # If there are 0 or 2+ faces, we might learn the wrong person.
            if len(faces) == 1:
                # Get the "Math" (Embedding)
                embedding = faces[0].embedding
                
                # NORMALIZE (Crucial for accuracy)
                embedding = embedding / np.linalg.norm(embedding)
                
                known_embeddings.append(embedding)
                known_names.append(person_label)
                images_processed += 1
        
        print(f"    Learned {images_processed} images.")

    # 3. Save the "Brain" to a file
    if len(known_names) == 0:
        print("No faces were found! Check your images.")
        return

    data = {
        "embeddings": known_embeddings,
        "names": known_names
    }

    with open(SAVE_FILE, 'wb') as f:
        pickle.dump(data, f)
        
    print(f"\n--- SUCCESS ---")
    print(f"Model trained on {len(set(known_names))} people.")
    print(f"Brain saved to: {SAVE_FILE}")

if __name__ == "__main__":
    train()