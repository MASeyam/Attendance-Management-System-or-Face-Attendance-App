
import cv2
import numpy as np
import pickle
import os
import re
import time
import random
from insightface.app import FaceAnalysis

# --- CONFIG ---
ROOT_DATASET_DIR = 'dataset/train' 
BRAIN_FILE = 'face_encodings.pkl'
MODEL_NAME = 'buffalo_l'
SIMILARITY_THRESHOLD = 0.45 
SAMPLE_PER_STUDENT = 2 
LABEL_PATTERN = re.compile(r'^.+ - 2022\d{4}$')
#  NEW: Standardize your viewing window
WINDOW_SIZE = (1000, 1000) 

def run_ultimate_audit():
    print("  Initializing Ultimate Audit Engine (Standardized View)...")

    if not os.path.exists(BRAIN_FILE):
        print(f"❌ Brain file '{BRAIN_FILE}' not found. Run train.py first.")
        return

    if not os.path.exists(ROOT_DATASET_DIR):
        print(f"❌ Dataset directory '{ROOT_DATASET_DIR}' not found.")
        return

    # 1. LOAD & NORMALIZE DATABASE
    with open(BRAIN_FILE, 'rb') as f:
        data = pickle.load(f)
    
    names_key = 'names' if 'names' in data else list(data.keys())[0]
    enc_key = 'embeddings' if 'embeddings' in data else 'encodings'
    known_names = data[names_key]
    raw_enc = np.array(data[enc_key])
    known_enc = raw_enc / (np.linalg.norm(raw_enc, axis=1, keepdims=True) + 1e-6)

    # 2. SETUP AI
    app = FaceAnalysis(name=MODEL_NAME, providers=['CPUExecutionProvider'])
    app.prepare(ctx_id=-1, det_size=(640, 640))

    # 3. ANALYTICS TRACKERS
    stats = {'total': 0, 'correct': 0, 'false_accept': 0, 'false_reject': 0, 'no_face': 0}
    det_times, match_times, correct_scores = [], [], []

    # Prepare the window once
    cv2.namedWindow("FUE AMS Audit - Visual Verification", cv2.WINDOW_NORMAL)

    print(f" Starting Visual Audit. Standardized window: {WINDOW_SIZE}")

    # 4. THE LOOP
    for student_folder in os.listdir(ROOT_DATASET_DIR):
        if not LABEL_PATTERN.match(student_folder): continue

        test_path = os.path.join(ROOT_DATASET_DIR, student_folder, 'test')
        if not os.path.exists(test_path): continue

        all_imgs = os.listdir(test_path)
        sample = random.sample(all_imgs, min(len(all_imgs), SAMPLE_PER_STUDENT))

        for img_name in sample:
            img = cv2.imread(os.path.join(test_path, img_name))
            if img is None: continue
            display_img = img.copy()

            stats['total'] += 1
            
            # --- Detection ---
            t0 = time.time()
            faces = app.get(img)
            det_times.append((time.time() - t0) * 1000)

            if not faces:
                print(f" Real: {student_folder} | [NO FACE]")
                stats['no_face'] += 1
                continue

            # --- Matching ---
            face = max(faces, key=lambda x: (x.bbox[2]-x.bbox[0])*(x.bbox[3]-x.bbox[1]))
            t1 = time.time()
            test_vec = face.embedding / (np.linalg.norm(face.embedding) + 1e-6)
            
            similarities = np.dot(known_enc, test_vec)
            best_idx = np.argmax(similarities)
            match_times.append((time.time() - t1) * 1000)

            score = similarities[best_idx]
            pred_name = known_names[best_idx]

            # --- LOGIC & VISUALS ---
            is_match = (pred_name == student_folder)
            is_verified = (is_match and score >= SIMILARITY_THRESHOLD)
            
            color = (0, 255, 0) if is_verified else (0, 0, 255)
            if is_match and not is_verified: color = (0, 165, 255) # Orange

            bbox = face.bbox.astype(int)
            cv2.rectangle(display_img, (bbox[0], bbox[1]), (bbox[2], bbox[3]), color, 2)
            
            # Text logic
            label_text = f"{pred_name.split(' - ')[0]} ({score:.2f})"
            cv2.putText(display_img, label_text, (bbox[0], bbox[1]-10), 
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, color, 2)

            # ---  THE KEY FIX: Standardize Window Size ---
            # We resize AFTER drawing so the boxes stay proportional to the face
            final_view = cv2.resize(display_img, WINDOW_SIZE)
            
            # Add a status banner to the top of the resized window
            banner_color = (20, 20, 20)
            cv2.rectangle(final_view, (0,0), (WINDOW_SIZE[0], 50), banner_color, -1)
            cv2.putText(final_view, f"Testing: {student_folder}", (10, 35), 
                        cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2)

            # Console Feedback
            print(f"Real: {student_folder} |  Pred: {pred_name} |  Score: {score:.4f}")

            # Stats logic
            if is_match:
                if score >= SIMILARITY_THRESHOLD:
                    stats['correct'] += 1
                    correct_scores.append(score)
                else:
                    stats['false_reject'] += 1
            else:
                if score >= SIMILARITY_THRESHOLD:
                    stats['false_accept'] += 1

            # Show the uniform image
            cv2.imshow("FUE AMS Audit - Visual Verification", final_view)
            
            # Increased delay to 100ms so you can actually see the photos fly by
            if cv2.waitKey(100) & 0xFF == ord('q'): break 

    cv2.destroyAllWindows()

    # --- THE PROFESSIONAL REPORT ---
    print("\n" + "═"*65)
    print(f"FUE GRADUATION PROJECT: FINAL BIOMETRIC AUDIT")
    print("═"*65)

    processed = stats['correct'] + stats['false_accept'] + stats['false_reject']
    accuracy = (stats['correct'] / processed * 100) if processed > 0 else 0
    far = (stats['false_accept'] / processed * 100) if processed > 0 else 0
    frr = (stats['false_reject'] / processed * 100) if processed > 0 else 0

    print(f"SYSTEM ACCURACY:    {accuracy:.2f}%")
    print(f"FAR (False Accept): {far:.2f}%  (Security Risk)")
    print(f"FRR (False Reject): {frr:.2f}%  (User Inconvenience)")
    print("-" * 65)
    
    avg_det = np.mean(det_times) if det_times else 0
    avg_match = np.mean(match_times) if match_times else 0
    fps = 1000 / (avg_det + avg_match) if (avg_det + avg_match) > 0 else 0
    
    print(f"Avg Inference:     {avg_det:.1f} ms")
    print(f"Avg Match Math:    {avg_match:.1f} ms")
    print(f" Performance:        {fps:.1f} FPS")
    print("-" * 65)

    if correct_scores:
        print(f" Mean Confidence:    {np.mean(correct_scores):.4f}")
    print(f" Face-Not-Found:     {stats['no_face']}")
    print("═"*65 + "\n")

if __name__ == "__main__":
    run_ultimate_audit()

# # full test folder in each student
# import cv2
# import numpy as np
# import pickle
# import os
# import re
# import time
# from insightface.app import FaceAnalysis

# # --- CONFIG ---
# ROOT_DATASET_DIR = 'dataset/train' 
# BRAIN_FILE = 'face_encodings.pkl'
# MODEL_NAME = 'buffalo_l'
# SIMILARITY_THRESHOLD = 0.45 
# LABEL_PATTERN = re.compile(r'^.+ - 2022\d{4}$')

# def run_full_audit():
#     print("🏗️  Initializing Full Marathon Audit (All Images + Visuals)...")
    
#     # 1. LOAD & NORMALIZE DATABASE
#     if not os.path.exists(BRAIN_FILE):
#         print(f"❌ Error: {BRAIN_FILE} not found!")
#         return

#     with open(BRAIN_FILE, 'rb') as f:
#         data = pickle.load(f)
    
#     names_key = 'names' if 'names' in data else list(data.keys())[0]
#     enc_key = 'embeddings' if 'embeddings' in data else 'encodings'
#     known_names = data[names_key]
#     raw_enc = np.array(data[enc_key])
#     known_enc = raw_enc / (np.linalg.norm(raw_enc, axis=1, keepdims=True) + 1e-6)

#     # 2. SETUP AI
#     app = FaceAnalysis(name=MODEL_NAME, providers=['CPUExecutionProvider'])
#     app.prepare(ctx_id=-1, det_size=(640, 640))

#     # 3. ANALYTICS TRACKERS
#     stats = {'total': 0, 'correct': 0, 'false_accept': 0, 'false_reject': 0, 'no_face': 0}
#     det_times, match_times, correct_scores = [], [], []

#     print(f"🔍 Starting Full Audit. This will process EVERY image. Press 'q' to quit.")

#     # 4. THE MARATHON LOOP
#     for student_folder in os.listdir(ROOT_DATASET_DIR):
#         if not LABEL_PATTERN.match(student_folder): continue

#         test_path = os.path.join(ROOT_DATASET_DIR, student_folder, 'test')
#         if not os.path.exists(test_path): continue

#         # 🔥 NO SAMPLING: We take the full list of images
#         all_imgs = os.listdir(test_path)

#         for img_name in all_imgs:
#             img = cv2.imread(os.path.join(test_path, img_name))
#             if img is None: continue
#             display_img = img.copy()

#             stats['total'] += 1
            
#             # --- Detection Speed ---
#             t0 = time.time()
#             faces = app.get(img)
#             det_times.append((time.time() - t0) * 1000)

#             if not faces:
#                 print(f"🚫 Real: {student_folder} | [NO FACE]")
#                 stats['no_face'] += 1
#                 continue

#             # --- Matching Speed ---
#             face = max(faces, key=lambda x: (x.bbox[2]-x.bbox[0])*(x.bbox[3]-x.bbox[1]))
#             t1 = time.time()
#             test_vec = face.embedding / (np.linalg.norm(face.embedding) + 1e-6)
            
#             similarities = np.dot(known_enc, test_vec)
#             best_idx = np.argmax(similarities)
#             match_times.append((time.time() - t1) * 1000)

#             score = similarities[best_idx]
#             pred_name = known_names[best_idx]

#             # --- LOGIC & VISUALS ---
#             is_match = (pred_name == student_folder)
#             is_verified = (is_match and score >= SIMILARITY_THRESHOLD)
            
#             # Color logic: Green = Success, Orange = Right person but low score, Red = Wrong person
#             color = (0, 255, 0) if is_verified else (0, 0, 255)
#             if is_match and not is_verified: color = (0, 165, 255) 

#             bbox = face.bbox.astype(int)
#             cv2.rectangle(display_img, (bbox[0], bbox[1]), (bbox[2], bbox[3]), color, 2)
#             label = f"{pred_name.split(' - ')[0]} ({score:.2f})"
#             cv2.putText(display_img, label, (bbox[0], bbox[1]-10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2)

#             status_icon = "✅" if is_verified else "❌"
#             print(f"{status_icon} Total: {stats['total']} | Real: {student_folder} | 🔥 Score: {score:.4f}")

#             if is_match:
#                 if score >= SIMILARITY_THRESHOLD:
#                     stats['correct'] += 1
#                     correct_scores.append(score)
#                 else:
#                     stats['false_reject'] += 1
#             else:
#                 if score >= SIMILARITY_THRESHOLD:
#                     stats['false_accept'] += 1

#             # Show image
#             cv2.imshow("FUE AMS Marathon Audit", display_img)
#             if cv2.waitKey(1) & 0xFF == ord('q'): 
#                 print("🛑 User stopped the audit early.")
#                 break 

#     cv2.destroyAllWindows()

#     # --- 📊 FINAL PROFESSIONAL REPORT ---
#     print("\n" + "═"*65)
#     print(f"🏆 FINAL GRADUATION AUDIT: COMPLETE DATASET RESULTS")
#     print("═"*65)

#     processed = stats['correct'] + stats['false_accept'] + stats['false_reject']
#     accuracy = (stats['correct'] / processed * 100) if processed > 0 else 0
#     far = (stats['false_accept'] / processed * 100) if processed > 0 else 0
#     frr = (stats['false_reject'] / processed * 100) if processed > 0 else 0

#     print(f"✅ FINAL SYSTEM ACCURACY: {accuracy:.2f}%")
#     print(f"🛡️  FAR (Security Risk):   {far:.2f}%")
#     print(f"⚠️  FRR (User Friction):  {frr:.2f}%")
#     print("-" * 65)
    
#     avg_det = np.mean(det_times) if det_times else 0
#     avg_match = np.mean(match_times) if match_times else 0
#     fps = 1000 / (avg_det + avg_match) if (avg_det + avg_match) > 0 else 0
    
#     print(f"⏱️  Avg Inference:        {avg_det:.1f} ms")
#     print(f"⏱️  Avg Match Math:       {avg_match:.1f} ms")
#     print(f"🚀 Performance:           {fps:.1f} FPS")
#     print("-" * 65)

#     if correct_scores:
#         print(f"💡 Mean Confidence:       {np.mean(correct_scores):.4f}")
#     print(f"🚫 Total No-Face:         {stats['no_face']}")
#     print("═"*65 + "\n")

# if __name__ == "__main__":
#     run_full_audit()

