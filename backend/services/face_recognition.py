import os
import cv2
import numpy as np
import pickle
import time
from insightface.app import FaceAnalysis
from config import BRAIN_FILE, MATCH_THRESHOLD


class FaceEngine:
    def __init__(self):
        print("FaceEngine: Loading AI Models...")
        self.app = FaceAnalysis(name='buffalo_l', providers=['CPUExecutionProvider'])
        self.app.prepare(ctx_id=-1, det_size=(640, 640))
        self.known_faces = []
        self.known_names = []
        self.known_ids   = []
        self.load_brain_from_file()

    def load_brain_from_file(self):
        print(f"FaceEngine: Loading brain from {BRAIN_FILE}...")
        if not os.path.exists(BRAIN_FILE):
            print(f"WARNING: {BRAIN_FILE} not found. Run train.py first.")
            return
        try:
            with open(BRAIN_FILE, 'rb') as f:
                data = pickle.load(f)
            raw = np.asarray(data['embeddings'], dtype=np.float32)
            self.known_faces = raw / (np.linalg.norm(raw, axis=1, keepdims=True) + 1e-6)
            for label in data['names']:
                if " - " in label:
                    name, sid = label.rsplit(" - ", 1)
                else:
                    name, sid = label, "Unknown"
                self.known_names.append(name)
                self.known_ids.append(sid)
            print(f"FaceEngine: Loaded {len(self.known_faces)} faces.")
        except Exception as e:
            print(f"Error loading brain: {e}")

    def reload_brain(self):
        self.known_faces = []
        self.known_names = []
        self.known_ids   = []
        self.load_brain_from_file()

    def add_person(self, label, embedding):
        """Add a single normalized embedding to the in-memory brain and save to disk."""
        norm_emb = embedding / (np.linalg.norm(embedding) + 1e-6)
        if os.path.exists(BRAIN_FILE):
            with open(BRAIN_FILE, 'rb') as f:
                data = pickle.load(f)
        else:
            data = {'embeddings': [], 'names': []}

        # Remove existing entry for same label if present
        pairs = [(e, n) for e, n in zip(data['embeddings'], data['names']) if n != label]
        embs  = [p[0] for p in pairs]
        names = [p[1] for p in pairs]
        embs.append(norm_emb.astype(np.float32))
        names.append(label)
        data['embeddings'] = embs
        data['names']      = names
        with open(BRAIN_FILE, 'wb') as f:
            pickle.dump(data, f)
        self.reload_brain()

    def generate_embedding_from_folder(self, folder_path):
        """Read images from folder, return mean embedding or None."""
        if not os.path.exists(folder_path):
            return None
        embeddings = []
        for fname in os.listdir(folder_path):
            if not fname.lower().endswith(('.jpg', '.jpeg', '.png')):
                continue
            img = cv2.imread(os.path.join(folder_path, fname))
            if img is None:
                continue
            faces = self.app.get(img)
            if len(faces) == 1:
                embeddings.append(faces[0].embedding)
        if not embeddings:
            return None
        avg = np.mean(embeddings, axis=0)
        return avg / (np.linalg.norm(avg) + 1e-6)

    def verify_face(self, image_path):
        img = cv2.imread(image_path)
        if img is None:
            return None, "Invalid Image", 0.0, 0.0, 0.0
        if len(self.known_faces) == 0:
            return None, "Brain not loaded", 0.0, 0.0, 0.0
        t0    = time.time()
        faces = self.app.get(img)
        det_ms = (time.time() - t0) * 1000
        if not faces:
            return None, "No Face Detected", 0.0, det_ms, 0.0
        t1     = time.time()
        face   = faces[0]
        target = face.embedding / (np.linalg.norm(face.embedding) + 1e-6)
        sims   = np.dot(self.known_faces, target)
        idx    = int(np.argmax(sims))
        score  = float(sims[idx])
        rec_ms = (time.time() - t1) * 1000
        return self.known_ids[idx], self.known_names[idx], score, det_ms, rec_ms


engine = FaceEngine()
