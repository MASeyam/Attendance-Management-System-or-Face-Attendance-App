USE [master]
GO

-- =============================================
-- DROP AND RECREATE DATABASE
-- =============================================
IF EXISTS (SELECT name FROM sys.databases WHERE name = N'Attendsystem')
BEGIN
    ALTER DATABASE [Attendsystem] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [Attendsystem];
END
GO

CREATE DATABASE [Attendsystem]
ON PRIMARY 
( NAME = N'Attendsystem', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\Attendsystem.mdf', SIZE = 8192KB, MAXSIZE = UNLIMITED, FILEGROWTH = 65536KB )
LOG ON 
( NAME = N'Attendsystem_log', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\Attendsystem_log.ldf', SIZE = 8192KB, MAXSIZE = 2048GB, FILEGROWTH = 65536KB )
GO

USE [Attendsystem]
GO

-- =============================================
-- TABLES
-- =============================================

-- DEPARTMENT
CREATE TABLE [dbo].[department](
    [id]   [int] IDENTITY(1,1) NOT NULL,
    [name] [nvarchar](100) NOT NULL,
    PRIMARY KEY CLUSTERED ([id] ASC)
)
GO

-- ADMIN
CREATE TABLE [dbo].[admin](
    [id]           [int] IDENTITY(1,1) NOT NULL,
    [username]     [nvarchar](50)  NOT NULL UNIQUE,
    [password]     [nvarchar](255) NOT NULL,
    [full_name]    [nvarchar](100) NOT NULL,
    [email]        [nvarchar](100) NULL,
    [phone_number] [nvarchar](20)  NULL,
    [role]         [nvarchar](50)  NULL DEFAULT ('Moderator'),
    [created_at]   [datetime]      NULL DEFAULT (getdate()),
    PRIMARY KEY CLUSTERED ([id] ASC)
)
GO

-- INSTRUCTOR
CREATE TABLE [dbo].[instructor](
    [id]              [int] IDENTITY(1,1) NOT NULL,
    [first_name]      [nvarchar](50)  NOT NULL,
    [last_name]       [nvarchar](50)  NOT NULL,
    [email]           [nvarchar](100) NULL UNIQUE,
    [phone_number]    [nvarchar](20)  NULL,
    [department_id]   [int]           NULL,
    [password]        [nvarchar](255) NULL DEFAULT ('admin123'),
    [role]            [nvarchar](50)  NULL,
    [username]        [nvarchar](50)  NULL,
    [photo_path]      [nvarchar](255) NULL,
    [facial_encoding] [nvarchar](max) NULL,
    PRIMARY KEY CLUSTERED ([id] ASC)
)
GO

-- STUDENT
CREATE TABLE [dbo].[student](
    [id]              [int]           NOT NULL,
    [first_name]      [nvarchar](50)  NOT NULL,
    [last_name]       [nvarchar](50)  NOT NULL,
    [email]           [nvarchar](100) NULL UNIQUE,
    [phone_number]    [nvarchar](20)  NULL,
    [password]        [nvarchar](255) NULL DEFAULT ('123456'),
    [date_of_birth]   [date]          NULL,
    [academic_year]   [nvarchar](20)  NULL,
    [gpa]             [decimal](3,2)  NULL,
    [level]           [int]           NULL,
    [group_name]      [nvarchar](20)  NULL,
    [photo_path]      [nvarchar](255) NULL,
    [facial_encoding] [nvarchar](max) NULL,
    [department_id]   [int]           NULL,
    PRIMARY KEY CLUSTERED ([id] ASC)
)
GO

-- CAMERA
CREATE TABLE [dbo].[camera](
    [id]       [int] IDENTITY(1,1) NOT NULL,
    [location] [nvarchar](100) NULL,
    PRIMARY KEY CLUSTERED ([id] ASC)
)
GO

-- CLASSROOM
CREATE TABLE [dbo].[classroom](
    [id]        [int]          NOT NULL,
    [building]  [nvarchar](50) NULL,
    [capacity]  [int]          NULL,
    [camera_id] [int]          NULL,
    PRIMARY KEY CLUSTERED ([id] ASC)
)
GO

-- COURSE
CREATE TABLE [dbo].[course](
    [id]            [int] IDENTITY(1,1) NOT NULL,
    [name]          [nvarchar](100) NOT NULL,
    [credit_hours]  [int]  NULL,
    [department_id] [int]  NULL,
    [instructor_id] [int]  NULL,
    PRIMARY KEY CLUSTERED ([id] ASC)
)
GO

-- COURSE ASSIGNMENT
CREATE TABLE [dbo].[course_assignment](
    [assignment_id] [int] IDENTITY(1,1) NOT NULL,
    [course_id]     [int]          NULL,
    [instructor_id] [int]          NULL,
    [role]          [nvarchar](50) NULL DEFAULT ('Lecturer'),
    [semester]      [nvarchar](20) NULL,
    [academic_year] [nvarchar](20) NULL,
    PRIMARY KEY CLUSTERED ([assignment_id] ASC)
)
GO

-- ENROLLMENT
CREATE TABLE [dbo].[enrollment](
    [enrollment_id] [int] IDENTITY(1,1) NOT NULL,
    [student_id]    [int]          NULL,
    [course_id]     [int]          NULL,
    [status]        [nvarchar](50) NULL DEFAULT ('Enrolled'),
    [enrolled_date] [date]         NULL DEFAULT (getdate()),
    [semester]      [nvarchar](20) NULL,
    [academic_year] [nvarchar](20) NULL,
    PRIMARY KEY CLUSTERED ([enrollment_id] ASC)
)
GO

-- CLASS SESSION
CREATE TABLE [dbo].[class_session](
    [session_id]       [int] IDENTITY(1,1) NOT NULL,
    [course_id]        [int]          NULL,
    [instructor_id]    [int]          NULL,
    [classroom_id]     [int]          NULL,
    [session_type]     [nvarchar](50) NULL,
    [session_start]    [datetime]     NULL,
    [session_end]      [datetime]     NULL,
    [session_status]   [nvarchar](20) NULL DEFAULT ('Scheduled'),
    [attendance_start] [datetime]     NULL,
    [attendance_end]   [datetime]     NULL,
    PRIMARY KEY CLUSTERED ([session_id] ASC)
)
GO

-- ATTENDANCE RECORD
CREATE TABLE [dbo].[attendance_record](
    [id]           [int] IDENTITY(1,1) NOT NULL,
    [session_id]   [int]          NULL,
    [student_id]   [int]          NULL,
    [method]       [nvarchar](50) NULL DEFAULT ('FaceID'),
    [status]       [nvarchar](50) NULL, -- Present | Absent | issued | resolved
    [marked_at]    [datetime]     NULL DEFAULT (getdate()),
    [last_updated] [datetime]     NULL DEFAULT (getdate()),
    PRIMARY KEY CLUSTERED ([id] ASC)
)
GO

-- ATTEMPT LOG
CREATE TABLE [dbo].[attempt_log](
    [log_id]        [int] IDENTITY(1,1) NOT NULL,
    [student_id]    [int]          NULL,
    [session_id]    [int]          NULL,
    [status]        [nvarchar](50) NULL,
    [image_metadata][nvarchar](max)NULL,
    [attempt_time]  [datetime]     NULL DEFAULT (getdate()),
    PRIMARY KEY CLUSTERED ([log_id] ASC)
)
GO

-- DISPUTES
CREATE TABLE [dbo].[disputes](
    [dispute_id]      [int] IDENTITY(1,1) NOT NULL,
    [student_id]      [int]          NULL,
    [session_id]      [int]          NULL,
    [reason]          [nvarchar](max)NULL,
    [status]          [nvarchar](20) NULL DEFAULT ('pending'), -- pending | accepted | declined
    [submitted_at]    [datetime]     NULL DEFAULT (getdate()),
    [instructor_reply][nvarchar](max)NULL,
    [handled_at]      [datetime]     NULL,
    [handled_by]      [int]          NULL,
    PRIMARY KEY CLUSTERED ([dispute_id] ASC)
)
GO

-- ATTENDANCE AUDIT LOG
CREATE TABLE [dbo].[attendance_audit_log](
    [log_id]        [int] IDENTITY(1,1) NOT NULL,
    [attendance_id] [int]           NULL,
    [session_id]    [int]           NULL,
    [student_id]    [int]           NULL,
    [student_name]  [nvarchar](100) NULL,
    [editor_id]     [int]           NULL,
    [editor_name]   [nvarchar](100) NULL,
    [old_status]    [nvarchar](50)  NULL,
    [new_status]    [nvarchar](50)  NULL,
    [edited_at]     [datetime]      NULL DEFAULT (getdate()),
    PRIMARY KEY CLUSTERED ([log_id] ASC)
)
GO

-- NOTIFICATIONS
CREATE TABLE [dbo].[notifications](
    [notification_id] [int] IDENTITY(1,1) NOT NULL,
    [user_id]         [int]           NULL,
    [user_role]       [nvarchar](20)  NULL, -- student | instructor | admin
    [title]           [nvarchar](100) NULL,
    [body]            [nvarchar](max) NULL,
    [is_read]         [bit]           NULL DEFAULT (0),
    [created_at]      [datetime]      NULL DEFAULT (getdate()),
    PRIMARY KEY CLUSTERED ([notification_id] ASC)
)
GO

-- =============================================
-- FOREIGN KEYS
-- =============================================

ALTER TABLE [dbo].[instructor]        ADD FOREIGN KEY([department_id]) REFERENCES [dbo].[department]([id])
ALTER TABLE [dbo].[student]           ADD FOREIGN KEY([department_id]) REFERENCES [dbo].[department]([id])
ALTER TABLE [dbo].[classroom]         ADD FOREIGN KEY([camera_id])     REFERENCES [dbo].[camera]([id])
ALTER TABLE [dbo].[course]            ADD FOREIGN KEY([department_id]) REFERENCES [dbo].[department]([id])
ALTER TABLE [dbo].[course]            ADD FOREIGN KEY([instructor_id]) REFERENCES [dbo].[instructor]([id])
ALTER TABLE [dbo].[course_assignment] ADD FOREIGN KEY([course_id])     REFERENCES [dbo].[course]([id])
ALTER TABLE [dbo].[course_assignment] ADD FOREIGN KEY([instructor_id]) REFERENCES [dbo].[instructor]([id])
ALTER TABLE [dbo].[enrollment]        ADD FOREIGN KEY([student_id])    REFERENCES [dbo].[student]([id]) ON DELETE CASCADE
ALTER TABLE [dbo].[enrollment]        ADD FOREIGN KEY([course_id])     REFERENCES [dbo].[course]([id])
ALTER TABLE [dbo].[class_session]     ADD FOREIGN KEY([course_id])     REFERENCES [dbo].[course]([id])
ALTER TABLE [dbo].[class_session]     ADD FOREIGN KEY([instructor_id]) REFERENCES [dbo].[instructor]([id])
ALTER TABLE [dbo].[class_session]     ADD FOREIGN KEY([classroom_id])  REFERENCES [dbo].[classroom]([id])
ALTER TABLE [dbo].[attendance_record] ADD FOREIGN KEY([session_id])    REFERENCES [dbo].[class_session]([session_id])
ALTER TABLE [dbo].[attendance_record] ADD FOREIGN KEY([student_id])    REFERENCES [dbo].[student]([id]) ON DELETE CASCADE
ALTER TABLE [dbo].[attempt_log]       ADD FOREIGN KEY([session_id])    REFERENCES [dbo].[class_session]([session_id])
ALTER TABLE [dbo].[attempt_log]       ADD FOREIGN KEY([student_id])    REFERENCES [dbo].[student]([id])
ALTER TABLE [dbo].[disputes]          ADD FOREIGN KEY([student_id])    REFERENCES [dbo].[student]([id])
ALTER TABLE [dbo].[disputes]          ADD FOREIGN KEY([session_id])    REFERENCES [dbo].[class_session]([session_id])
ALTER TABLE [dbo].[disputes]          ADD FOREIGN KEY([handled_by])    REFERENCES [dbo].[instructor]([id])
GO

-- =============================================
-- SEED DATA
-- =============================================

-- Department
INSERT INTO [dbo].[department] ([name]) VALUES ('Computer Science')
GO

-- Admin
INSERT INTO [dbo].[admin] ([username], [password], [full_name], [email], [role])
VALUES ('admin', 'Admin@1234', 'System Administrator', 'admin@fue.edu.eg', 'SuperAdmin')
GO

-- =============================================
-- INSTRUCTORS
-- =============================================

-- Prof. Mohamed Hussien
INSERT INTO [dbo].[instructor] ([first_name], [last_name], [email], [phone_number], [department_id], [password], [role], [username])
VALUES ('Mohamed', 'Hussien', 'mohamed.hussien@fue.edu.eg', '01000000001', 1, 'Prof@1234', 'Professor', 'mohamed.hussien')

-- TA: Tasnim Salah
INSERT INTO [dbo].[instructor] ([first_name], [last_name], [email], [phone_number], [department_id], [password], [role], [username])
VALUES ('Tasnim', 'Salah', 'tasnim.salah@fue.edu.eg', '01000000002', 1, 'TA@1234', 'Teaching Assistant', 'tasnim.salah')

-- Dummy instructors
INSERT INTO [dbo].[instructor] ([first_name], [last_name], [email], [phone_number], [department_id], [password], [role], [username])
VALUES ('Ahmed', 'Hassan', 'ahmed.hassan@fue.edu.eg', '01000000003', 1, 'Pass@1234', 'Lecturer', 'ahmed.hassan')

INSERT INTO [dbo].[instructor] ([first_name], [last_name], [email], [phone_number], [department_id], [password], [role], [username])
VALUES ('Sara', 'Mostafa', 'sara.mostafa@fue.edu.eg', '01000000004', 1, 'Pass@1234', 'Lecturer', 'sara.mostafa')
GO

-- =============================================
-- STUDENTS
-- =============================================

-- Team Members
INSERT INTO [dbo].[student] ([id], [first_name], [last_name], [email], [phone_number], [password], [academic_year], [gpa], [level], [group_name], [department_id])
VALUES (20225389, 'Abdulrahman', 'Seyam',      '20225389@fue.edu.eg', '01000000010', 'AbdX@1234', '2025-2026', 3.80, 3, 'G1', 1)

INSERT INTO [dbo].[student] ([id], [first_name], [last_name], [email], [phone_number], [password], [academic_year], [gpa], [level], [group_name], [department_id])
VALUES (20223585, 'Fatma',        'Abdelhamid', '20223585@fue.edu.eg', '01000000011', 'Fat@1234',  '2025-2026', 3.50, 3, 'G1', 1)

INSERT INTO [dbo].[student] ([id], [first_name], [last_name], [email], [phone_number], [password], [academic_year], [gpa], [level], [group_name], [department_id])
VALUES (20223235, 'Nancy',        'Ashraf',     '20223235@fue.edu.eg', '01000000012', 'Nan@1234',  '2025-2026', 3.60, 3, 'G1', 1)

INSERT INTO [dbo].[student] ([id], [first_name], [last_name], [email], [phone_number], [password], [academic_year], [gpa], [level], [group_name], [department_id])
VALUES (20223008, 'Salma',        'Ibrahim',    '20223008@fue.edu.eg', '01000000013', 'Sal@1234',  '2025-2026', 3.70, 3, 'G1', 1)

-- Dummy students
INSERT INTO [dbo].[student] ([id], [first_name], [last_name], [email], [phone_number], [password], [academic_year], [gpa], [level], [group_name], [department_id])
VALUES (20221001, 'Omar',   'Khalid',  '20221001@fue.edu.eg', '01000000020', 'Pass@1234', '2025-2026', 2.90, 3, 'G2', 1)

INSERT INTO [dbo].[student] ([id], [first_name], [last_name], [email], [phone_number], [password], [academic_year], [gpa], [level], [group_name], [department_id])
VALUES (20221002, 'Nour',   'Ahmed',   '20221002@fue.edu.eg', '01000000021', 'Pass@1234', '2025-2026', 3.10, 3, 'G2', 1)

INSERT INTO [dbo].[student] ([id], [first_name], [last_name], [email], [phone_number], [password], [academic_year], [gpa], [level], [group_name], [department_id])
VALUES (20221003, 'Youssef','Tarek',   '20221003@fue.edu.eg', '01000000022', 'Pass@1234', '2025-2026', 2.75, 3, 'G1', 1)

INSERT INTO [dbo].[student] ([id], [first_name], [last_name], [email], [phone_number], [password], [academic_year], [gpa], [level], [group_name], [department_id])
VALUES (20221004, 'Hana',   'Mahmoud', '20221004@fue.edu.eg', '01000000023', 'Pass@1234', '2025-2026', 3.40, 3, 'G2', 1)
GO

-- =============================================
-- CAMERAS & CLASSROOMS
-- =============================================

INSERT INTO [dbo].[camera] ([location]) VALUES ('Room 101 - Front')
INSERT INTO [dbo].[camera] ([location]) VALUES ('Room 202 - Front')
INSERT INTO [dbo].[camera] ([location]) VALUES ('Room 305 - Front')
GO

INSERT INTO [dbo].[classroom] ([id], [building], [capacity], [camera_id]) VALUES (101, 'Building A', 40, 1)
INSERT INTO [dbo].[classroom] ([id], [building], [capacity], [camera_id]) VALUES (202, 'Building B', 35, 2)
INSERT INTO [dbo].[classroom] ([id], [building], [capacity], [camera_id]) VALUES (305, 'Building C', 50, 3)
GO

-- =============================================
-- COURSES
-- =============================================

INSERT INTO [dbo].[course] ([name], [credit_hours], [department_id], [instructor_id]) VALUES ('Machine Learning',             3, 1, 1)
INSERT INTO [dbo].[course] ([name], [credit_hours], [department_id], [instructor_id]) VALUES ('Computer Vision',              3, 1, 1)
INSERT INTO [dbo].[course] ([name], [credit_hours], [department_id], [instructor_id]) VALUES ('Mobile Application Development',3, 1, 3)
INSERT INTO [dbo].[course] ([name], [credit_hours], [department_id], [instructor_id]) VALUES ('Database Systems',             3, 1, 4)
GO

-- =============================================
-- COURSE ASSIGNMENTS
-- =============================================

INSERT INTO [dbo].[course_assignment] ([course_id], [instructor_id], [role], [semester], [academic_year]) VALUES (1, 1, 'Professor',          'Spring', '2025-2026')
INSERT INTO [dbo].[course_assignment] ([course_id], [instructor_id], [role], [semester], [academic_year]) VALUES (1, 2, 'Teaching Assistant',  'Spring', '2025-2026')
INSERT INTO [dbo].[course_assignment] ([course_id], [instructor_id], [role], [semester], [academic_year]) VALUES (2, 1, 'Professor',          'Spring', '2025-2026')
INSERT INTO [dbo].[course_assignment] ([course_id], [instructor_id], [role], [semester], [academic_year]) VALUES (3, 3, 'Lecturer',           'Spring', '2025-2026')
INSERT INTO [dbo].[course_assignment] ([course_id], [instructor_id], [role], [semester], [academic_year]) VALUES (4, 4, 'Lecturer',           'Spring', '2025-2026')
GO

-- =============================================
-- ENROLLMENTS
-- =============================================

-- Machine Learning (course 1)
INSERT INTO [dbo].[enrollment] ([student_id],[course_id],[status],[semester],[academic_year]) VALUES (20225389,1,'Enrolled','Spring','2025-2026')
INSERT INTO [dbo].[enrollment] ([student_id],[course_id],[status],[semester],[academic_year]) VALUES (20223585,1,'Enrolled','Spring','2025-2026')
INSERT INTO [dbo].[enrollment] ([student_id],[course_id],[status],[semester],[academic_year]) VALUES (20223235,1,'Enrolled','Spring','2025-2026')
INSERT INTO [dbo].[enrollment] ([student_id],[course_id],[status],[semester],[academic_year]) VALUES (20223008,1,'Enrolled','Spring','2025-2026')
INSERT INTO [dbo].[enrollment] ([student_id],[course_id],[status],[semester],[academic_year]) VALUES (20221001,1,'Enrolled','Spring','2025-2026')
INSERT INTO [dbo].[enrollment] ([student_id],[course_id],[status],[semester],[academic_year]) VALUES (20221002,1,'Enrolled','Spring','2025-2026')
INSERT INTO [dbo].[enrollment] ([student_id],[course_id],[status],[semester],[academic_year]) VALUES (20221003,1,'Enrolled','Spring','2025-2026')
INSERT INTO [dbo].[enrollment] ([student_id],[course_id],[status],[semester],[academic_year]) VALUES (20221004,1,'Enrolled','Spring','2025-2026')

-- Computer Vision (course 2)
INSERT INTO [dbo].[enrollment] ([student_id],[course_id],[status],[semester],[academic_year]) VALUES (20225389,2,'Enrolled','Spring','2025-2026')
INSERT INTO [dbo].[enrollment] ([student_id],[course_id],[status],[semester],[academic_year]) VALUES (20223585,2,'Enrolled','Spring','2025-2026')
INSERT INTO [dbo].[enrollment] ([student_id],[course_id],[status],[semester],[academic_year]) VALUES (20223235,2,'Enrolled','Spring','2025-2026')
INSERT INTO [dbo].[enrollment] ([student_id],[course_id],[status],[semester],[academic_year]) VALUES (20223008,2,'Enrolled','Spring','2025-2026')
INSERT INTO [dbo].[enrollment] ([student_id],[course_id],[status],[semester],[academic_year]) VALUES (20221001,2,'Enrolled','Spring','2025-2026')
INSERT INTO [dbo].[enrollment] ([student_id],[course_id],[status],[semester],[academic_year]) VALUES (20221002,2,'Enrolled','Spring','2025-2026')

-- Mobile App Dev (course 3)
INSERT INTO [dbo].[enrollment] ([student_id],[course_id],[status],[semester],[academic_year]) VALUES (20225389,3,'Enrolled','Spring','2025-2026')
INSERT INTO [dbo].[enrollment] ([student_id],[course_id],[status],[semester],[academic_year]) VALUES (20223585,3,'Enrolled','Spring','2025-2026')
INSERT INTO [dbo].[enrollment] ([student_id],[course_id],[status],[semester],[academic_year]) VALUES (20223235,3,'Enrolled','Spring','2025-2026')
INSERT INTO [dbo].[enrollment] ([student_id],[course_id],[status],[semester],[academic_year]) VALUES (20223008,3,'Enrolled','Spring','2025-2026')
INSERT INTO [dbo].[enrollment] ([student_id],[course_id],[status],[semester],[academic_year]) VALUES (20221003,3,'Enrolled','Spring','2025-2026')
INSERT INTO [dbo].[enrollment] ([student_id],[course_id],[status],[semester],[academic_year]) VALUES (20221004,3,'Enrolled','Spring','2025-2026')

-- Database Systems (course 4)
INSERT INTO [dbo].[enrollment] ([student_id],[course_id],[status],[semester],[academic_year]) VALUES (20225389,4,'Enrolled','Spring','2025-2026')
INSERT INTO [dbo].[enrollment] ([student_id],[course_id],[status],[semester],[academic_year]) VALUES (20223585,4,'Enrolled','Spring','2025-2026')
INSERT INTO [dbo].[enrollment] ([student_id],[course_id],[status],[semester],[academic_year]) VALUES (20223235,4,'Enrolled','Spring','2025-2026')
INSERT INTO [dbo].[enrollment] ([student_id],[course_id],[status],[semester],[academic_year]) VALUES (20223008,4,'Enrolled','Spring','2025-2026')
INSERT INTO [dbo].[enrollment] ([student_id],[course_id],[status],[semester],[academic_year]) VALUES (20221001,4,'Enrolled','Spring','2025-2026')
INSERT INTO [dbo].[enrollment] ([student_id],[course_id],[status],[semester],[academic_year]) VALUES (20221002,4,'Enrolled','Spring','2025-2026')
INSERT INTO [dbo].[enrollment] ([student_id],[course_id],[status],[semester],[academic_year]) VALUES (20221003,4,'Enrolled','Spring','2025-2026')
INSERT INTO [dbo].[enrollment] ([student_id],[course_id],[status],[semester],[academic_year]) VALUES (20221004,4,'Enrolled','Spring','2025-2026')
GO

-- =============================================
-- SESSIONS (auto-generated style)
-- 2x per week, 8 weeks = 16 sessions per course
-- =============================================

-- Machine Learning: Mon/Wed 09:00-10:30 Room 101 (instructor_id=1)
DECLARE @ml_start DATE = '2026-05-11'
DECLARE @i INT = 0
WHILE @i < 8
BEGIN
    INSERT INTO [dbo].[class_session] ([course_id],[instructor_id],[classroom_id],[session_type],[session_start],[session_end],[session_status])
    VALUES (1,1,101,'Lecture',
        CAST(DATEADD(DAY,@i*7,@ml_start) AS DATETIME) + CAST('09:00:00' AS DATETIME),
        CAST(DATEADD(DAY,@i*7,@ml_start) AS DATETIME) + CAST('10:30:00' AS DATETIME),
        'Scheduled')

    INSERT INTO [dbo].[class_session] ([course_id],[instructor_id],[classroom_id],[session_type],[session_start],[session_end],[session_status])
    VALUES (1,1,101,'Lecture',
        CAST(DATEADD(DAY,@i*7+2,@ml_start) AS DATETIME) + CAST('09:00:00' AS DATETIME),
        CAST(DATEADD(DAY,@i*7+2,@ml_start) AS DATETIME) + CAST('10:30:00' AS DATETIME),
        'Scheduled')

    SET @i = @i + 1
END
GO

-- Computer Vision: Tue/Thu 11:00-12:30 Room 202 (instructor_id=1)
DECLARE @cv_start DATE = '2026-05-12'
DECLARE @j INT = 0
WHILE @j < 8
BEGIN
    INSERT INTO [dbo].[class_session] ([course_id],[instructor_id],[classroom_id],[session_type],[session_start],[session_end],[session_status])
    VALUES (2,1,202,'Lecture',
        CAST(DATEADD(DAY,@j*7,@cv_start) AS DATETIME) + CAST('11:00:00' AS DATETIME),
        CAST(DATEADD(DAY,@j*7,@cv_start) AS DATETIME) + CAST('12:30:00' AS DATETIME),
        'Scheduled')

    INSERT INTO [dbo].[class_session] ([course_id],[instructor_id],[classroom_id],[session_type],[session_start],[session_end],[session_status])
    VALUES (2,1,202,'Lecture',
        CAST(DATEADD(DAY,@j*7+2,@cv_start) AS DATETIME) + CAST('11:00:00' AS DATETIME),
        CAST(DATEADD(DAY,@j*7+2,@cv_start) AS DATETIME) + CAST('12:30:00' AS DATETIME),
        'Scheduled')

    SET @j = @j + 1
END
GO

-- Mobile App Dev: Mon/Wed 13:00-14:30 Room 305 (instructor_id=3)
DECLARE @mob_start DATE = '2026-05-11'
DECLARE @k INT = 0
WHILE @k < 8
BEGIN
    INSERT INTO [dbo].[class_session] ([course_id],[instructor_id],[classroom_id],[session_type],[session_start],[session_end],[session_status])
    VALUES (3,3,305,'Lecture',
        CAST(DATEADD(DAY,@k*7,@mob_start) AS DATETIME) + CAST('13:00:00' AS DATETIME),
        CAST(DATEADD(DAY,@k*7,@mob_start) AS DATETIME) + CAST('14:30:00' AS DATETIME),
        'Scheduled')

    INSERT INTO [dbo].[class_session] ([course_id],[instructor_id],[classroom_id],[session_type],[session_start],[session_end],[session_status])
    VALUES (3,3,305,'Lecture',
        CAST(DATEADD(DAY,@k*7+2,@mob_start) AS DATETIME) + CAST('13:00:00' AS DATETIME),
        CAST(DATEADD(DAY,@k*7+2,@mob_start) AS DATETIME) + CAST('14:30:00' AS DATETIME),
        'Scheduled')

    SET @k = @k + 1
END
GO

-- Database Systems: Tue/Thu 08:00-09:30 Room 101 (instructor_id=4)
DECLARE @db_start DATE = '2026-05-12'
DECLARE @l INT = 0
WHILE @l < 8
BEGIN
    INSERT INTO [dbo].[class_session] ([course_id],[instructor_id],[classroom_id],[session_type],[session_start],[session_end],[session_status])
    VALUES (4,4,101,'Lecture',
        CAST(DATEADD(DAY,@l*7,@db_start) AS DATETIME) + CAST('08:00:00' AS DATETIME),
        CAST(DATEADD(DAY,@l*7,@db_start) AS DATETIME) + CAST('09:30:00' AS DATETIME),
        'Scheduled')

    INSERT INTO [dbo].[class_session] ([course_id],[instructor_id],[classroom_id],[session_type],[session_start],[session_end],[session_status])
    VALUES (4,4,101,'Lecture',
        CAST(DATEADD(DAY,@l*7+2,@db_start) AS DATETIME) + CAST('08:00:00' AS DATETIME),
        CAST(DATEADD(DAY,@l*7+2,@db_start) AS DATETIME) + CAST('09:30:00' AS DATETIME),
        'Scheduled')

    SET @l = @l + 1
END
GO

-- =============================================
-- ATTENDANCE RECORDS (sessions 1 & 2 = ML)
-- =============================================

-- Session 1 - Machine Learning
INSERT INTO [dbo].[attendance_record] ([session_id],[student_id],[method],[status]) VALUES (1,20225389,'FaceID','present')
INSERT INTO [dbo].[attendance_record] ([session_id],[student_id],[method],[status]) VALUES (1,20223585,'FaceID','present')
INSERT INTO [dbo].[attendance_record] ([session_id],[student_id],[method],[status]) VALUES (1,20223235,'FaceID','absent')
INSERT INTO [dbo].[attendance_record] ([session_id],[student_id],[method],[status]) VALUES (1,20223008,'FaceID','present')
INSERT INTO [dbo].[attendance_record] ([session_id],[student_id],[method],[status]) VALUES (1,20221001,'FaceID','absent')
INSERT INTO [dbo].[attendance_record] ([session_id],[student_id],[method],[status]) VALUES (1,20221002,'FaceID','present')
INSERT INTO [dbo].[attendance_record] ([session_id],[student_id],[method],[status]) VALUES (1,20221003,'FaceID','present')
INSERT INTO [dbo].[attendance_record] ([session_id],[student_id],[method],[status]) VALUES (1,20221004,'FaceID','absent')

-- Session 2 - Machine Learning
INSERT INTO [dbo].[attendance_record] ([session_id],[student_id],[method],[status]) VALUES (2,20225389,'FaceID','present')
INSERT INTO [dbo].[attendance_record] ([session_id],[student_id],[method],[status]) VALUES (2,20223585,'FaceID','absent')
INSERT INTO [dbo].[attendance_record] ([session_id],[student_id],[method],[status]) VALUES (2,20223235,'FaceID','present')
INSERT INTO [dbo].[attendance_record] ([session_id],[student_id],[method],[status]) VALUES (2,20223008,'FaceID','present')
INSERT INTO [dbo].[attendance_record] ([session_id],[student_id],[method],[status]) VALUES (2,20221001,'FaceID','present')
INSERT INTO [dbo].[attendance_record] ([session_id],[student_id],[method],[status]) VALUES (2,20221002,'FaceID','absent')
INSERT INTO [dbo].[attendance_record] ([session_id],[student_id],[method],[status]) VALUES (2,20221003,'FaceID','present')
INSERT INTO [dbo].[attendance_record] ([session_id],[student_id],[method],[status]) VALUES (2,20221004,'FaceID','present')

-- Session 17 - Computer Vision (first CV session)
INSERT INTO [dbo].[attendance_record] ([session_id],[student_id],[method],[status]) VALUES (17,20225389,'FaceID','present')
INSERT INTO [dbo].[attendance_record] ([session_id],[student_id],[method],[status]) VALUES (17,20223585,'FaceID','present')
INSERT INTO [dbo].[attendance_record] ([session_id],[student_id],[method],[status]) VALUES (17,20223235,'FaceID','present')
INSERT INTO [dbo].[attendance_record] ([session_id],[student_id],[method],[status]) VALUES (17,20223008,'FaceID','absent')
INSERT INTO [dbo].[attendance_record] ([session_id],[student_id],[method],[status]) VALUES (17,20221001,'FaceID','present')
INSERT INTO [dbo].[attendance_record] ([session_id],[student_id],[method],[status]) VALUES (17,20221002,'FaceID','present')
GO

-- =============================================
-- DISPUTES
-- =============================================

-- Nancy disputes her absence in ML Session 1
INSERT INTO [dbo].[disputes] ([student_id],[session_id],[reason],[status])
VALUES (20223235, 1, 'I was present in class but the system marked me absent. Camera may have missed me due to seating position.', 'pending')

-- Omar disputes his absence in ML Session 1
INSERT INTO [dbo].[disputes] ([student_id],[session_id],[reason],[status])
VALUES (20221001, 1, 'I attended the session but was marked absent. I sat in the back row near the window.', 'pending')

-- Fatma dispute - already handled
INSERT INTO [dbo].[disputes] ([student_id],[session_id],[reason],[status],[instructor_reply],[handled_at],[handled_by])
VALUES (20223585, 2, 'I was in class for ML Session 2 but marked absent.', 'handled', 
        'Verified with class photos. Attendance updated to present.', GETDATE(), 1)
GO

-- =============================================
-- NOTIFICATIONS
-- =============================================

INSERT INTO [dbo].[notifications] ([user_id],[user_role],[title],[body],[is_read])
VALUES (20223235,'student','Attendance Marked','Your attendance for Machine Learning Session 2 has been recorded as present.',0)

INSERT INTO [dbo].[notifications] ([user_id],[user_role],[title],[body],[is_read])
VALUES (1,'instructor','New Dispute','Student Nancy Ashraf submitted a dispute for Machine Learning Session 1.',0)

INSERT INTO [dbo].[notifications] ([user_id],[user_role],[title],[body],[is_read])
VALUES (20225389,'student','Session Starting','Machine Learning session starts in 15 minutes. Room 101, Building A.',1)

INSERT INTO [dbo].[notifications] ([user_id],[user_role],[title],[body],[is_read])
VALUES (20221001,'student','Dispute Update','Your dispute for ML Session 1 is under review by the instructor.',0)

INSERT INTO [dbo].[notifications] ([user_id],[user_role],[title],[body],[is_read])
VALUES (20223585,'student','Dispute Resolved','Your dispute for ML Session 2 has been resolved. Attendance updated.',1)
GO

USE [master]
GO
ALTER DATABASE [Attendsystem] SET READ_WRITE
GO