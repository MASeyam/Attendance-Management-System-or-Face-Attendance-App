import os
from dotenv import load_dotenv

load_dotenv()

SERVER_NAME   = os.getenv('DB_SERVER',  'localhost')
DATABASE_NAME = os.getenv('DB_NAME',    'Attendsystem')
ADMIN_PIN     = os.getenv('ADMIN_PIN',  '1234')
EMAIL_USER    = os.getenv('EMAIL_USER', '')
EMAIL_PASS    = os.getenv('EMAIL_PASS', '')

MATCH_THRESHOLD      = 0.50
MIN_DET_SCORE_VERIFY = 0.60
MIN_FACE_SIZE_VERIFY = 90
BRAIN_FILE           = 'face_encodings.pkl'
DATASET_DIR          = 'dataset'
