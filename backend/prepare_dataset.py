import os
import shutil
import random
import csv
from pathlib import Path

# --- CONFIGURATION ---
# Check your folder: Is it "raw_download/train" or just "raw_download"?
RAW_TRAIN_DIR = Path("dataset/raw_download/train") 
OUTPUT_DIR = Path("dataset/train")
MAP_FILE = Path("dataset/student_identity_map.csv")

MAX_IMAGES_PER_PERSON = 50 
TRAIN_SPLIT = 0.7 

# Name lists for the new students
FIRST_NAMES = ["Aya", "Mariam", "Salma", "Nour", "Hana", "Laila", "Rana", "Farah", "Dina", "Sara", "Mona", "Yasmine", "Hoda", "Nada", "Reem", "Jana", "Lina", "Maya", "Yara", "Noha", "Menna", "Amira", "Doaa", "Nadia", "Rania", "Omnia", "Shahd", "Malak", "Asmaa", "Raghad", "Zeinab", "Rama", "Nesma", "Riham", "Sondos", "Heba", "Amina", "Lujain", "Khadija", "Rita"]
LAST_NAMES = ["Ali", "Hassan", "Mahmoud", "Ibrahim", "Khaled", "Mostafa", "Samir", "Nabil", "Farid", "Sami", "Tarek", "Youssef", "Adel", "Fathy", "Osman", "Hamdy", "Salem", "Ezzat", "Abbas", "Hegazy", "Saad", "Ragab", "Gaber", "Shawky", "Badr", "Morsy", "Bakr", "Atef", "Nassar", "Shehata", "Gamal", "Awad", "Magdy", "Taher", "Zaki", "Saber", "Rashad", "Yehia", "Kassem", "Mekky"]

def load_existing_mapping():
    mapping = {}
    if MAP_FILE.exists():
        with open(MAP_FILE, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                mapping[row['student_id']] = f"{row['first_name']} {row['last_name']}"
    return mapping

def generate_unique_name(used_names):
    while True:
        name = f"{random.choice(FIRST_NAMES)} {random.choice(LAST_NAMES)}"
        if name not in used_names:
            return name

def main():
    random.seed(2026)
    
    # --- PATH DEBUGGER ---
    print(f"🔍 Checking source path: {RAW_TRAIN_DIR.absolute()}")
    
    if not RAW_TRAIN_DIR.exists():
        print(f"❌ ERROR: I cannot find the folder: {RAW_TRAIN_DIR}")
        print(f"Check your 'backend' folder. Do you see 'raw_download' with 'train' inside it?")
        return

    # Create output directory safely (NO rmtree!)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    existing_map = load_existing_mapping()
    used_names = set(existing_map.values())
    
    all_raw_folders = sorted([f for f in RAW_TRAIN_DIR.iterdir() if f.is_dir()])
    print(f"📦 Found {len(all_raw_folders)} students. Starting...")

    final_rows = []

    for i, folder in enumerate(all_raw_folders):
        student_id = f"2022{1001 + i:04d}" 
        full_name = existing_map.get(student_id, generate_unique_name(used_names))
        used_names.add(full_name)

        folder_label = f"{full_name} - {student_id}"
        person_path = OUTPUT_DIR / folder_label
        train_path = person_path / "train"
        test_path = person_path / "test"
        
        train_path.mkdir(parents=True, exist_ok=True)
        test_path.mkdir(parents=True, exist_ok=True)

        images = [img for img in folder.iterdir() if img.suffix.lower() in ['.jpg', '.jpeg', '.png']]
        random.shuffle(images)
        
        selected = images[:MAX_IMAGES_PER_PERSON]
        split_idx = int(len(selected) * TRAIN_SPLIT)
        
        for img in selected[:split_idx]:
            shutil.copy(img, train_path / img.name)
        for img in selected[split_idx:]:
            shutil.copy(img, test_path / img.name)

        name_parts = full_name.split(maxsplit=1)
        final_rows.append({
            "folder_name": folder_label, "student_id": student_id,
            "first_name": name_parts[0], "last_name": name_parts[1] if len(name_parts) > 1 else "Student",
            "email": f"{student_id}@fue.edu.eg"
        })

        if (i + 1) % 50 == 0:
            print(f"✅ Processed {i + 1} students...")

    with open(MAP_FILE, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=["folder_name", "student_id", "first_name", "last_name", "email"])
        writer.writeheader()
        writer.writerows(final_rows)

    print(f"\n✨ Done! 480 students ready at {OUTPUT_DIR}")

if __name__ == "__main__":
    main()