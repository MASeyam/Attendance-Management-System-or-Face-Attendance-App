# 📸 Smart Face Attendance System

A full-stack mobile attendance solution that uses AI to verify student identity, location, and class schedules in real-time.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)
![SQL Server](https://img.shields.io/badge/SQL%20Server-CC2927?style=for-the-badge&logo=microsoft-sql-server&logoColor=white)

## 🚀 Features
* **AI Face Recognition:** Uses InsightFace (ArcFace) for high-accuracy matching.
* **Context Awareness:** Verifies if the student is in the **Right Room** at the **Right Time**.
* **Mobile App:** Built with Flutter for Android/iOS.
* **Backend:** Python Flask API + MS SQL Server Database.

---

## 🛠️ Prerequisites
* **Python 3.11** (Strictly required for InsightFace compatibility).
* **Flutter SDK**.
* **Microsoft SQL Server**.

---

## 📝 Step 1: Database Setup
1. Open **SQL Server Management Studio (SSMS)**.
2. Open the file located at: `database/init_db.sql`.
3. Click **Execute** to build the database and create a test class session.

---

## ⚙️ Step 2: Backend Setup (Python)

1.  **Navigate to the backend:**
    ```bash
    cd backend
    ```

2.  **Install Dependencies:**
    ```bash
    pip install flask numpy opencv-python insightface pyodbc
    ```

3.  **Configure Server Name:**
    * Open `app.py` and `enroll.py`.
    * Find the line: `SERVER_NAME = r'YOUR_SERVER_NAME'`.
    * Replace `YOUR_SERVER_NAME` with your actual SQL Server Name (e.g., `DESKTOP-XYZ`).

4.  **Register a Student (Enrollment):**
    * Take a photo of yourself and name it **`student.jpg`**.
    * Place it inside the `backend/` folder.
    * Run the enrollment script:
    ```bash
    py -3.11 enroll.py
    ```
    * *Success Message:* `✅ SUCCESS! Registered: [Name] - [ID]`

5.  **Start the API Server:**
    ```bash
    py -3.11 app.py
    ```
    * *The server will start at `http://0.0.0.0:5000`.*

---

## 📱 Step 3: Mobile App Setup (Flutter)

1.  **Configure Network:**
    * Open a terminal and find your IPv4 Address:
        * **Windows:** `ipconfig`
        * **Mac/Linux:** `ifconfig`
    * Open `lib/main.dart` in the project.
    * Find the line:
        ```dart
        final uri = Uri.parse('http://YOUR_LOCAL_IP:5000/verify-face');
        ```
    * Replace `YOUR_LOCAL_IP` with your actual IPv4 address (e.g., `192.168.1.15`).

2.  **Run the App:**
    * Connect your physical device (Phone) via USB.
    * Ensure the Phone and PC are on the **same WiFi network**.
    * Run the command:
    ```bash
    flutter run
    ```

---

## ❓ Troubleshooting

**Q: Connection Failed / Connection Refused?**
* Check that your Phone and PC are on the same WiFi.
* Disable **Windows Firewall** temporarily to test.
* Ensure the IP address in `lib/main.dart` matches your PC's current IP.

**Q: "No match" result?**
* Ensure `enroll.py` was run successfully.
* Check if the class time in the database is valid for "Right Now" (The setup script handles this automatically, but if you restarted the SQL server days later, you might need to re-run the `INSERT INTO class_session` query).

**Q: Python "Module not found"?**
* Ensure you are using Python 3.11: `py -3.11 app.py`.