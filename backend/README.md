# AMS Backend — How to Run the Full Project

## Requirements
- Python 3.10 or 3.11
- Flutter 3.7+
- Microsoft SQL Server 2019+ (or SQL Server Express)
- All pip packages listed in `requirements.txt`

---

## Step 1: Database Setup

1. Open **SQL Server Management Studio (SSMS)**
2. Connect to your SQL Server instance
3. Open and run the file: `database_scripts/init_db.sql`
4. This creates the `Attendsystem` database with all tables

**Required tables** (some must be added manually if missing):
```sql
-- Run this in SSMS after init_db.sql if columns are missing:
ALTER TABLE student ADD level INT, group_name NVARCHAR(50), gpa DECIMAL(4,2), department_id INT;
ALTER TABLE student ADD photo_path NVARCHAR(255);

-- Create disputes table:
CREATE TABLE disputes (
    dispute_id      INT IDENTITY(1,1) PRIMARY KEY,
    student_id      INT NOT NULL,
    session_id      INT NOT NULL,
    reason          NVARCHAR(MAX),
    status          NVARCHAR(20) DEFAULT 'pending',
    submitted_at    DATETIME DEFAULT GETDATE(),
    instructor_reply NVARCHAR(MAX),
    handled_at      DATETIME,
    handled_by      INT
);

-- Create notifications table:
CREATE TABLE notifications (
    notification_id INT IDENTITY(1,1) PRIMARY KEY,
    user_id         INT NOT NULL,
    user_role       NVARCHAR(20) NOT NULL,
    title           NVARCHAR(200),
    body            NVARCHAR(MAX),
    is_read         BIT DEFAULT 0,
    created_at      DATETIME DEFAULT GETDATE()
);
```

**Connection string format:**
```
Driver={SQL Server};Server=YOUR_PC_NAME\SQLEXPRESS;Database=Attendsystem;Trusted_Connection=yes;
```

---

## Step 2: Backend Server

1. Copy `.env.example` to `.env`:
   ```
   copy .env.example .env
   ```

2. Fill in your `.env` file:
   ```
   DB_SERVER=YOUR_PC_NAME\SQLEXPRESS   # Your SQL Server instance name
   DB_NAME=Attendsystem
   ADMIN_PIN=1234
   EMAIL_USER=your_gmail@gmail.com      # For sending credentials to new users
   EMAIL_PASS=your_gmail_app_password   # Gmail App Password (not your login password)
   ```

3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

4. Train the face recognition model (first time only):
   ```bash
   python train.py
   ```
   This reads from `dataset/train/` and creates `face_encodings.pkl`.

5. Start the server:
   ```bash
   python app.py
   ```
   Server runs on port **5001**.

6. Verify it's running — open in browser:
   ```
   http://localhost:5001/
   ```
   You should see: `AMS Server is Running!`

---

## Step 3: ClassEye Flutter App

1. Open `class_eye/lib/core/api_constants.dart`

2. Change `baseUrl` to your **laptop's local IP** (not localhost):
   ```dart
   static const String baseUrl = 'http://192.168.X.X:5001';
   ```
   Find your IP with: `ipconfig` (Windows) → look for IPv4 Address

3. Install Flutter dependencies:
   ```bash
   cd class_eye
   flutter pub get
   ```

4. Connect your Android phone to the **same WiFi** as your laptop

5. Run the app:
   ```bash
   flutter run
   ```

**Test accounts:**
| Role       | Login                          | Password   |
|------------|--------------------------------|------------|
| Student    | 20225389@fue.edu.eg            | AbdX@1234  |
| Instructor | mohamed.hussien@fue.edu.eg     | Prof@1234  |
| Admin      | admin (username)               | Admin@1234 |

---

## Step 4: AMS App (Face Recognition Kiosk)

Located in `/ams_app`. Same Flutter run instructions apply.

The kiosk app sends images to `/kiosk_scan` on the backend server. Make sure the server IP is set correctly in the ams_app's constants file.

---

## Troubleshooting

### DB Connection Errors
- Verify `DB_SERVER` in `.env` matches your SQL Server instance name exactly
- In SSMS → right-click server → Properties → see the server name
- Enable TCP/IP in SQL Server Configuration Manager
- Make sure SQL Server Browser service is running

### Server Not Reachable from Phone
- Both phone and laptop must be on **same WiFi network**
- Use `ipconfig` to find your laptop's IPv4 address
- Try pinging your laptop from the phone
- Check Windows Firewall — allow port 5001 inbound:
  ```
  netsh advfirewall firewall add rule name="AMS Backend" protocol=TCP dir=in localport=5001 action=allow
  ```

### Face Recognition Not Loading
- Run `python train.py` first to generate `face_encodings.pkl`
- Ensure `dataset/train/` contains student folders with at least 5 images each
- Folder name format: `Firstname Lastname - StudentID`

### Common Flutter Build Errors
- Run `flutter clean && flutter pub get` after any dependency changes
- If `image_picker` fails on Android, check `android/app/src/main/AndroidManifest.xml` has camera permissions
- For `shared_preferences` issues, ensure `minSdkVersion` in `android/app/build.gradle` is 21+
