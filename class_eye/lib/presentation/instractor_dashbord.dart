import 'package:flutter/material.dart';

class InstructorDashboard extends StatefulWidget {
  final String instructorName;

  const InstructorDashboard({super.key, required this.instructorName});

  @override
  State<InstructorDashboard> createState() => _InstructorDashboardState();
}

class _InstructorDashboardState extends State<InstructorDashboard> {
  // Placeholder list - later we will fetch this from Python
  final List<Map<String, String>> _myCourses = [
    {'name': 'Computer Vision', 'code': 'CS401', 'time': '10:00 AM'},
    {'name': 'Operating Systems', 'code': 'CS302', 'time': '12:30 PM'},
    {'name': 'Embedded Systems', 'code': 'CS405', 'time': '02:00 PM'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      // 1. APP BAR
      appBar: AppBar(
        title: const Text("Instructor Portal"),
        backgroundColor: Colors.orange, // Instructor Theme Color
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Logout Logic: Clear stack and go home
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
          ),
        ],
      ),

      // 2. BODY
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A. Welcome Header
            Text(
              "Welcome,",
              style: TextStyle(fontSize: 20, color: Colors.grey[700]),
            ),
            Text(
              widget.instructorName, // Using the name passed from Login
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 30),

            // B. Section Title
            const Text(
              "My Active Classes",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 15),

            // C. Course List (Scrollable)
            Expanded(
              child: ListView.builder(
                itemCount: _myCourses.length,
                itemBuilder: (context, index) {
                  return _buildCourseCard(_myCourses[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper Widget for the Course Card
  Widget _buildCourseCard(Map<String, String> course) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.orange[100],
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.book, color: Colors.orange),
        ),
        title: Text(
          course['name']!,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text("${course['code']!} • Starts at ${course['time']}"),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey,
        ),
        onTap: () {
          // Future Logic: Go to attendance list for this class
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Selected ${course['name']}")));
        },
      ),
    );
  }
}
