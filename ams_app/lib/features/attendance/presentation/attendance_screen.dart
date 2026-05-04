import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/attendance_service.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  File? _image;
  bool _isLoading = false;
  Map<String, dynamic>? _result; // holds what server sends back
  String? _error;

  Future<void> _captureAndRecognize() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked == null) return;

    setState(() {
      _image = File(picked.path);
      _isLoading = true;
      _result = null;
      _error = null;
    });

    try {
      final result = await AttendanceService().recognizeFace(_image!);
      setState(() => _result = result);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Face Attendance')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Preview of taken photo
            if (_image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(_image!, height: 250, fit: BoxFit.cover),
              ),
            const SizedBox(height: 24),

            // The button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _captureAndRecognize,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Take Photo & Recognize'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
            const SizedBox(height: 32),

            // Loading
            if (_isLoading) const CircularProgressIndicator(),

            // Results from server
            if (_result != null) ...[
              const Text(
                'Result:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:
                        _result!.entries
                            .map(
                              (e) => Text(
                                '${e.key}: ${e.value}',
                                style: const TextStyle(fontSize: 16),
                              ),
                            )
                            .toList(),
                  ),
                ),
              ),
            ],

            // Error
            if (_error != null)
              Text('Error: $_error', style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}
