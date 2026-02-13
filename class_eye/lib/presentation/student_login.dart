import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'student_dashbord.dart';
import '../core/api_constants.dart';

class StudentLogin extends StatefulWidget {
  const StudentLogin({super.key});

  @override
  State<StudentLogin> createState() => _StudentLoginState();
}

class _StudentLoginState extends State<StudentLogin> {
  // 1. Controllers to capture what the user types
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // 2. Variable to control the loading spinner
  bool _isLoading = false;

  // 3. THE LOGIC FUNCTION
  Future<void> _login() async {
    // A. Check if the text boxes are empty
    if (!_formKey.currentState!.validate()) return;

    // B. Start the loading spinner
    setState(() => _isLoading = true);

    try {
      // C. Send the data to Python
      final response = await http.post(
        Uri.parse(ApiConstants.loginEndpoint),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "student_id": _studentIdController.text.trim(),
          "password": _passwordController.text.trim(),
        }),
      );

      // D. Read the answer from Python
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        // ✅ SUCCESS
        if (!mounted) return;

        // Show Welcome Message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Welcome, ${data['name']}!"),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to the History Screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) => StudentDashboard(
                  studentId: _studentIdController.text.trim(),
                ),
          ),
        );
      } else {
        // ❌ FAILURE (Wrong Password)
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? "Login failed"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // ⚠️ ERROR (Server down or wrong IP)
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Connection Error: Is the server running? ($e)"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      // E. Stop the loading spinner
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Student Login")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // STUDENT ID INPUT
              TextFormField(
                controller: _studentIdController,
                keyboardType: TextInputType.number, // Number pad only
                decoration: const InputDecoration(
                  labelText: "Student ID",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) => value!.isEmpty ? "Enter your ID" : null,
              ),
              const SizedBox(height: 20),

              // PASSWORD INPUT
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true, // Hides the text
                validator:
                    (value) => value!.isEmpty ? "Enter your Password" : null,
              ),
              const SizedBox(height: 30),

              // LOGIN BUTTON
              ElevatedButton(
                onPressed: _isLoading ? null : _login, // Disable if loading
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.blueAccent,
                ),
                child:
                    _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                          "LOGIN",
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
