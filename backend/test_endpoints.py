"""
AMS Endpoint Test Suite
Run: python test_endpoints.py
Requires server running: python app.py
"""
import sys
import requests

BASE = "http://localhost:5001"
results = []


def test(label, method, path, **kwargs):
    url = BASE + path
    try:
        resp = getattr(requests, method)(url, timeout=10, **kwargs)
        body = resp.json()
        # Consider success if HTTP 2xx OR body has success=True
        ok = resp.status_code < 400 or body.get("success") is True
        status = "PASS" if ok else "FAIL"
        detail = "" if ok else f"HTTP {resp.status_code} | {body}"
    except Exception as e:
        status = "FAIL"
        detail = str(e)
    results.append((label, method.upper(), status, detail))
    icon = "[OK]" if status == "PASS" else "[!!]"
    print(f"  {icon} {method.upper():6} {path:50} {status}", end="")
    if detail:
        print(f"\n       >> {detail}", end="")
    print()
    return status == "PASS"


print("\n" + "="*70)
print("  AMS ENDPOINT TEST SUITE")
print("="*70)

# ── AUTH ──────────────────────────────────────────────────────────────────────
print("\n[AUTH]")
test("Student Login",    "post", "/auth/student/login",
     json={"email": "20225389@fue.edu.eg", "password": "AbdX@1234"})
test("Instructor Login", "post", "/auth/instructor/login",
     json={"email": "mohamed.hussien@fue.edu.eg", "password": "Prof@1234"})
test("Admin Login",      "post", "/auth/admin/login",
     json={"username": "admin", "password": "Admin@1234"})

# ── STUDENTS ──────────────────────────────────────────────────────────────────
print("\n[STUDENTS]")
test("All Students",        "get", "/students")
test("Single Student",      "get", "/students/20225389")
test("Attendance Summary",  "get", "/students/20225389/attendance-summary")
test("Attendance History",  "get", "/students/20225389/attendance-history")
test("Schedule",            "get", "/students/20225389/schedule")

# ── INSTRUCTORS ───────────────────────────────────────────────────────────────
print("\n[INSTRUCTORS]")
test("All Instructors",    "get", "/instructors")
test("Single Instructor",  "get", "/instructors/1")
test("Today Sessions",     "get", "/instructors/1/sessions/today")
test("Reports",            "get", "/instructors/1/reports")

# ── SESSIONS ──────────────────────────────────────────────────────────────────
print("\n[SESSIONS]")
test("Session Attendance", "get", "/sessions/1/attendance")
test("Open Session",       "put", "/sessions/1/open")
test("Close Session",      "put", "/sessions/1/close")

# ── ATTENDANCE ────────────────────────────────────────────────────────────────
print("\n[ATTENDANCE]")
# Get a real attendance ID first, then update it
try:
    r = requests.get(f"{BASE}/sessions/1/attendance", timeout=10).json()
    records = r.get("records", [])
    atid = next((rec["attendance_id"] for rec in records if rec.get("attendance_id")), None)
except Exception:
    atid = None

if atid:
    test("Update Attendance", "put", f"/attendance/{atid}/update",
         json={"status": "Present"})
else:
    results.append(("Update Attendance", "PUT", "SKIP", "No attendance_id found in session 1"))
    print(f"  [--] PUT    /attendance/<id>/update                              SKIP (no record in session 1)")

# ── DISPUTES ──────────────────────────────────────────────────────────────────
print("\n[DISPUTES]")
test("Instructor Disputes", "get",  "/disputes/instructor/1")
test("Create Dispute",      "post", "/disputes/create",
     json={"student_id": 20223235, "session_id": 1, "reason": "Test dispute from test_endpoints.py"})

# ── COURSES ───────────────────────────────────────────────────────────────────
print("\n[COURSES]")
test("All Courses",   "get", "/courses")
test("Classrooms",    "get", "/classrooms")
test("Departments",   "get", "/departments")

# ── NOTIFICATIONS ─────────────────────────────────────────────────────────────
print("\n[NOTIFICATIONS]")
test("Notifications", "get", "/notifications/20225389/student")

# ── ADMIN ─────────────────────────────────────────────────────────────────────
print("\n[ADMIN]")
test("Admin Stats",       "get", "/admin/stats")
test("Attendance Logs",   "get", "/admin/attendance-logs")

# ── SUMMARY TABLE ─────────────────────────────────────────────────────────────
passed = sum(1 for r in results if r[2] == "PASS")
failed = sum(1 for r in results if r[2] == "FAIL")
skipped = sum(1 for r in results if r[2] == "SKIP")

print("\n" + "="*70)
print(f"  SUMMARY  — {passed} PASS  |  {failed} FAIL  |  {skipped} SKIP")
print("="*70)
print(f"\n{'Endpoint':<35} {'Method':<8} {'Status':<8} Fix Applied")
print("-"*80)
for label, method, status, detail in results:
    fix = detail[:40] + "…" if len(detail) > 40 else detail
    print(f"{label:<35} {method:<8} {status:<8} {fix}")

sys.exit(0 if failed == 0 else 1)
