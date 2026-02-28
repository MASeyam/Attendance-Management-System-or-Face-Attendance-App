import csv
import re
from pathlib import Path


TRAIN_DIR = Path("dataset/train")
OUTPUT_CSV = Path("dataset/student_identity_map.csv")

# Keep these IDs explicitly for your teammates.
TEAMMATE_ASSIGNMENTS = [
    ("Lina Farid", "20223585"),
    ("Maya Nabil", "20223235"),
    ("Yara Sami", "20223008"),
]


def split_name(full_name: str):
    parts = full_name.strip().split()
    if len(parts) == 1:
        return parts[0], "Student"
    return parts[0], " ".join(parts[1:])


def parse_labeled_folder(folder_name: str):
    match = re.match(r"^(?P<name>.+)\s-\s(?P<id>2022\d{4})$", folder_name)
    if not match:
        return None
    return match.group("name").strip(), match.group("id")


def generate_id_pool(reserved_ids: set[str]):
    for n in range(1, 10000):
        sid = f"2022{n:04d}"
        if sid not in reserved_ids:
            yield sid


def main():
    if not TRAIN_DIR.exists():
        print(f"Error: '{TRAIN_DIR}' not found.")
        return

    folders = sorted([p for p in TRAIN_DIR.iterdir() if p.is_dir()], key=lambda p: p.name.lower())
    if not folders:
        print("No folders found in dataset/train.")
        return

    # Existing already-labeled folders (e.g., "Abdulrahman Seyam - 20225389") are preserved.
    existing_labels = {}
    raw_folders = []
    for folder in folders:
        parsed = parse_labeled_folder(folder.name)
        if parsed:
            existing_labels[folder.name] = parsed
        else:
            raw_folders.append(folder)

    reserved_ids = {sid for _, sid in existing_labels.values()}
    reserved_ids.update(sid for _, sid in TEAMMATE_ASSIGNMENTS)

    id_pool = generate_id_pool(reserved_ids)
    rename_plan = []

    # Force-assign teammate IDs to the first raw folders.
    raw_index = 0
    for full_name, sid in TEAMMATE_ASSIGNMENTS:
        if raw_index >= len(raw_folders):
            break
        src = raw_folders[raw_index]
        raw_index += 1
        dst = f"{full_name} - {sid}"
        rename_plan.append((src.name, dst, full_name, sid))

    # Assign remaining raw folders to generated IDs.
    counter = 1
    for i in range(raw_index, len(raw_folders)):
        src = raw_folders[i]
        sid = next(id_pool)
        full_name = f"Student {counter:03d}"
        counter += 1
        dst = f"{full_name} - {sid}"
        rename_plan.append((src.name, dst, full_name, sid))

    # Two-phase rename to avoid collisions.
    tmp_moves = []
    for i, (src_name, _, _, _) in enumerate(rename_plan, start=1):
        src = TRAIN_DIR / src_name
        tmp = TRAIN_DIR / f"__tmp__{i:04d}__{src_name}"
        src.rename(tmp)
        tmp_moves.append(tmp)

    for tmp_path, (_, dst_name, _, _) in zip(tmp_moves, rename_plan):
        dst = TRAIN_DIR / dst_name
        tmp_path.rename(dst)

    # Build final mapping for ALL labeled folders.
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

    OUTPUT_CSV.parent.mkdir(parents=True, exist_ok=True)
    with OUTPUT_CSV.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f, fieldnames=["folder_name", "student_id", "first_name", "last_name", "email"]
        )
        writer.writeheader()
        writer.writerows(final_rows)

    print(f"Renamed {len(rename_plan)} folders.")
    print(f"Generated mapping: {OUTPUT_CSV}")
    print(f"Total labeled folders: {len(final_rows)}")


if __name__ == "__main__":
    main()
