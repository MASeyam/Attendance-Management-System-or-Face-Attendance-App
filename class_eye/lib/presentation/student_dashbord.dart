import 'dart:convert';
import 'package:class_eye/Screens/course_detail.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:class_eye/core/api_constants.dart'; // ✅ Importing your core constants

// ==========================================
// 1. DATA MODELS
// ==========================================

class StudentCourse {
  final int id;
  final String name;
  final String instructor;

  StudentCourse({
    required this.id,
    required this.name,
    required this.instructor,
  });

  factory StudentCourse.fromJson(Map<String, dynamic> json) {
    return StudentCourse(
      id: json['course_id'],
      name: json['course_name'] ?? "Unknown",
      instructor: json['instructor'] ?? "Unknown",
    );
  }
}

class CourseSession {
  final String type; // PR or TH
  final String room;
  final String date;
  final String time;
  final String status; // Attended, Missed, Upcoming
  final String color; // green, red, blue

  CourseSession({
    required this.type,
    required this.room,
    required this.date,
    required this.time,
    required this.status,
    required this.color,
  });

  factory CourseSession.fromJson(Map<String, dynamic> json) {
    return CourseSession(
      type: json['type'] ?? "",
      room: json['room'] ?? "",
      date: json['date'] ?? "",
      time: json['time'] ?? "",
      status: json['status'] ?? "",
      color: json['ui_color'] ?? "grey",
    );
  }
}

// ==========================================
// 2. SCREEN 1: THE DASHBOARD (List of Courses)
// ==========================================
class StudentDashboard extends StatefulWidget {
  final String studentId;

  const StudentDashboard({super.key, required this.studentId});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  late Future<List<StudentCourse>> _coursesFuture;

  @override
  void initState() {
    super.initState();
    _coursesFuture = fetchCourses();
  }

  Future<List<StudentCourse>> fetchCourses() async {
    try {
      // ✅ USING API CONSTANTS
      final response = await http.post(
        Uri.parse(ApiConstants.studentCoursesEndpoint),
        body: {'student_id': widget.studentId},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          List<dynamic> list = data['courses'];
          return list.map((e) => StudentCourse.fromJson(e)).toList();
        }
      }
      throw Exception("Failed to load courses");
    } catch (e) {
      throw Exception("Connection Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("My Courses"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: FutureBuilder<List<StudentCourse>>(
        future: _coursesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No courses found."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final course = snapshot.data![index];
              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: Colors.indigo.shade100,
                    child: const Icon(Icons.book, color: Colors.indigo),
                  ),
                  title: Text(
                    course.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  subtitle: Text("Instructor: ${course.instructor}"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => CourseDetailScreen(
                              studentId: widget.studentId,
                              courseId: course.id.toString(),
                              courseName: course.name,
                            ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
