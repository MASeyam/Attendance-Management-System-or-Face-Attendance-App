-- =======================================================
-- 📸 SMART FACE ATTENDANCE - DATABASE SETUP SCRIPT
-- =======================================================
-- Run this entire script in Microsoft SQL Server Management Studio (SSMS).
-- It creates the database, schema, and populates necessary dummy data.

CREATE DATABASE Attendsystem;
GO

USE Attendsystem;
GO

-- 1. CREATE TABLES
-- =======================================================

CREATE TABLE department (
    id INT PRIMARY KEY IDENTITY(1,1),
    name VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE instructor (
    id INT PRIMARY KEY IDENTITY(1,1),
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE,
    department_id INT,
    phone_number VARCHAR(15)
);

CREATE TABLE student (
    id INT PRIMARY KEY, -- Manual ID entry allowed for University IDs
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100),
    phone_number VARCHAR(15),
    date_of_birth DATE,
    academic_year VARCHAR(20),
    facial_encoding VARBINARY(MAX) -- Stores AI Embeddings
);

CREATE TABLE course (
    id INT PRIMARY KEY IDENTITY(1,1),
    name VARCHAR(100) NOT NULL,
    credit_hours INT,
    instructor_id INT,
    department_id INT
);

CREATE TABLE camera (id INT PRIMARY KEY IDENTITY(1,1), location VARCHAR(100));

CREATE TABLE classroom (
    id INT PRIMARY KEY IDENTITY(1,1), 
    building VARCHAR(100), 
    capacity INT, 
    camera_id INT
);

CREATE TABLE class_session (
    session_id INT PRIMARY KEY IDENTITY(1,1),
    course_id INT,
    session_type VARCHAR(20),
    expected_students INT,
    attendance_start DATETIME,
    attendance_end DATETIME,
    session_start DATETIME,
    session_end DATETIME,
    instructor_id INT,
    classroom_id VARCHAR(50) -- Matches QR Code Room ID (e.g., '101')
);

CREATE TABLE enrollment (
    enrollment_id INT PRIMARY KEY IDENTITY(1,1),
    student_id INT,
    course_id INT,
    status VARCHAR(20),
    enrolled_date DATETIME,
    semester VARCHAR(10),
    academic_year INT
);

CREATE TABLE attendance_record (
    id INT PRIMARY KEY IDENTITY(1,1),
    session_id INT,
    student_id INT,
    method VARCHAR(30),
    status VARCHAR(20),
    marked_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 2. INSERT DUMMY DATA (Environment Setup)
-- =======================================================
INSERT INTO department (name) VALUES ('Computer Science'), ('Electrical Engineering');
INSERT INTO instructor (first_name, last_name, email, department_id) VALUES ('Alice', 'Dr', 'alice@uni.edu', 1);
INSERT INTO course (name, credit_hours, instructor_id, department_id) VALUES ('Introduction to Programming', 3, 1, 1);
INSERT INTO camera (location) VALUES ('Building A - Main');
INSERT INTO classroom (building, capacity, camera_id) VALUES ('Building A', 50, 1);

-- 3. CREATE LIVE SESSION (Valid for "Right Now")
-- =======================================================
-- This query dynamically creates a class that started 2 hours ago and ends in 5 hours.
-- It ensures the app works immediately whenever you test it.
INSERT INTO class_session (course_id, session_type, attendance_start, attendance_end, session_start, session_end, instructor_id, classroom_id)
VALUES (
    1, 
    'Lecture', 
    DATEADD(HOUR, -2, GETDATE()), 
    DATEADD(HOUR, 5, GETDATE()), 
    DATEADD(HOUR, -2, GETDATE()), 
    DATEADD(HOUR, 5, GETDATE()), 
    1, 
    '101'
);

PRINT 'Database Setup Complete. Class Session is Active for Room 101.';