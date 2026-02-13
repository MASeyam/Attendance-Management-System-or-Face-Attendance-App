import 'package:flutter/material.dart';

// Import your screens
// ⚠️ CHECK THESE PATHS: Ensure the files exist in these folders
import 'presentation/instructor_login.dart';

void main() {
  runApp(const AMSApp());
}

class AMSApp extends StatelessWidget {
  const AMSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "AMS Student Portal",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/student_login': (context) => const StudentLogin(),
        '/admin_login': (context) => const AdminLogin(),
        // ✅ The route is named '/instructor_login'
        '/instructor_login': (context) => const InstructorLogin(),
      },
    );
  }
}

// ==========================================
// HOME SCREEN (Menu)
// ==========================================
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Widget _buildRoleCard(
    BuildContext context,
    String title,
    Color color,
    String route,
    IconData icon,
  ) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: color,
        child: SizedBox(
          width: 220,
          height: 120,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 40, color: Colors.white),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AMS Portal")),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. STUDENT
              _buildRoleCard(
                context,
                "Student Login",
                Colors.blueAccent,
                '/student_login',
                Icons.person,
              ),
              const SizedBox(height: 20),

              // 2. ADMIN
              _buildRoleCard(
                context,
                "Admin Login",
                Colors.green,
                '/admin_login',
                Icons.admin_panel_settings,
              ),
              const SizedBox(height: 20),

              // 3. INSTRUCTOR (Fixed)
              _buildRoleCard(
                context,
                "Instructor Login", // Renamed for consistency
                Colors.orange,
                '/instructor_login', // 🔴 FIXED: Matches the route defined above
                Icons.school,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
