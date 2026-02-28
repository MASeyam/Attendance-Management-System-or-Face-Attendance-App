import csv
import random
import re
from pathlib import Path


TRAIN_DIR = Path("dataset/train")
OUTPUT_CSV = Path("dataset/student_identity_map.csv")

FIRST_NAMES = [
    "Aya", "Mariam", "Salma", "Nour", "Hana", "Laila", "Rana", "Farah", "Dina", "Sara",
    "Mona", "Yasmine", "Hoda", "Nada", "Reem", "Jana", "Lina", "Maya", "Yara", "Noha",
    "Menna", "Amira", "Doaa", "Nadia", "Rania", "Omnia", "Shahd", "Malak", "Asmaa", "Raghad",
    "Zeinab", "Rama", "Nesma", "Riham", "Sondos", "Heba", "Amina", "Lujain", "Khadija", "Rita",
]

LAST_NAMES = [
    "Ali", "Hassan", "Mahmoud", "Ibrahim", "Khaled", "Mostafa", "Samir", "Nabil", "Farid", "Sami",
    "Tarek", "Youssef", "Adel", "Fathy", "Osman", "Hamdy", "Salem", "Ezzat", "Abbas", "Hegazy",
    "Saad", "Ragab", "Gaber", "Shawky", "Badr", "Morsy", "Bakr", "Atef", "Nassar", "Shehata",
    "Gamal", "Awad", "Magdy", "Taher", "Zaki", "Saber", "Rashad", "Yehia", "Kassem", "Mekky",
]


def parse_labeled_folder(folder_name: str):
    m = re.match(r"^(?P<name>.+)\s-\s(?P<id>2022\d{4})$", folder_name)
    if not m:
        return None
    return m.group("name").strip(), m.group("id")


def split_name(full_name: str):
    parts = full_name.strip().split()
    if len(parts) == 1:
        return parts[0], "Student"
    return parts[0], " ".join(parts[1:])


def generate_unique_name(used_names: set[str]):
    while True:
        candidate = f"{random.choice(FIRST_NAMES)} {random.choice(LAST_NAMES)}"
        if candidate not in used_names:
            return candidate


def main():
    if not TRAIN_DIR.exists():
        print(f"Error: '{TRAIN_DIR}' not found.")
        return

    folders = sorted([p for p in TRAIN_DIR.iterdir() if p.is_dir()], key=lambda p: p.name.lower())
    if not folders:
        print("No folders found.")
        return

    parsed_rows = []
    for folder in folders:
        parsed = parse_labeled_folder(folder.name)
        if parsed:
            parsed_rows.append((folder, parsed[0], parsed[1]))

    if not parsed_rows:
        print("No labeled folders found in expected format.")
        return

    used_names = {name for _, name, _ in parsed_rows if not name.startswith("Student ")}
    rename_plan = []

    for folder, full_name, sid in parsed_rows:
        if full_name.startswith("Student "):
            new_name = generate_unique_name(used_names)
            used_names.add(new_name)
            dst_folder_name = f"{new_name} - {sid}"
            rename_plan.append((folder.name, dst_folder_name))

    # Two-phase rename avoids collisions.
    tmp_paths = []
    for i, (src_name, _) in enumerate(rename_plan, start=1):
        src = TRAIN_DIR / src_name
        tmp = TRAIN_DIR / f"__tmp__rnd__{i:04d}__{src_name}"
        src.rename(tmp)
        tmp_paths.append(tmp)

    for tmp_path, (_, dst_name) in zip(tmp_paths, rename_plan):
        dst = TRAIN_DIR / dst_name
        tmp_path.rename(dst)

    # Rebuild mapping CSV.
    final_rows = []
    for folder in sorted([p for p in TRAIN_DIR.iterdir() if p.is_dir()], key=lambda p: p.name.lower()):
        parsed = parse_labeled_folder(folder.name)
        if not parsed:
            continue
        full_name, sid = parsed
        first_name, last_name = split_name(full_name)
        final_rows.append(
            {
                "folder_name": folder.name,
                "student_id": sid,
                "first_name": first_name,
                "last_name": last_name,
                "email": f"{sid}@fue.edu.eg",
            }
        )

    with OUTPUT_CSV.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f, fieldnames=["folder_name", "student_id", "first_name", "last_name", "email"]
        )
        writer.writeheader()
        writer.writerows(final_rows)

    print(f"Renamed placeholders: {len(rename_plan)}")
    print(f"Updated mapping: {OUTPUT_CSV}")


if __name__ == "__main__":
    random.seed(2026)
    main()
