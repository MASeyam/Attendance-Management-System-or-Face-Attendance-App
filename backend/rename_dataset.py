import os

# --- CONFIGURATION ---
TARGET_DIR = "dataset/train"   # Where your folders are
MAX_IMAGES = 20                # Keep only this many images
# ---------------------

def reduce_dataset():
    if not os.path.exists(TARGET_DIR):
        print(f"❌ Error: Cannot find directory '{TARGET_DIR}'")
        return

    print(f"--- Reducing images to {MAX_IMAGES} per person ---")
    
    total_deleted = 0

    # Loop through every person folder
    for folder_name in os.listdir(TARGET_DIR):
        folder_path = os.path.join(TARGET_DIR, folder_name)
        
        if not os.path.isdir(folder_path):
            continue

        # Get all image files in the folder
        all_files = os.listdir(folder_path)
        
        # Filter to keep only images (just in case)
        images = [f for f in all_files if f.lower().endswith(('.png', '.jpg', '.jpeg'))]
        
        # Sort them to delete the random/later ones reliably
        images.sort()

        if len(images) > MAX_IMAGES:
            # Calculate how many to remove
            num_to_remove = len(images) - MAX_IMAGES
            files_to_delete = images[MAX_IMAGES:] # Slice the list from 20 onwards
            
            print(f"✂️  {folder_name}: Removing {num_to_remove} extra images...")

            for img_name in files_to_delete:
                file_path = os.path.join(folder_path, img_name)
                try:
                    os.remove(file_path)
                    total_deleted += 1
                except Exception as e:
                    print(f"   ⚠️ Could not delete {img_name}: {e}")

    print(f"\n--- Done! Deleted {total_deleted} excess images. ---")

if __name__ == "__main__":
    reduce_dataset()