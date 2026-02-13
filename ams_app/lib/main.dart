import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint("Error fetching cameras: $e");
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CameraScreen(),
    );
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  String _serverIp = "";
  String _roomId = "Room Not Set";
  bool _isUploading = false;
  int _selectedCameraIndex = 1; // Default to Front Camera

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initCamera(_selectedCameraIndex);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _serverIp = prefs.getString('server_ip') ?? "";
      _roomId = prefs.getString('room_id') ?? "Room Not Set";
    });
  }

  Future<void> _initCamera(int index) async {
    if (cameras.isEmpty) return;
    _controller = CameraController(
      cameras[index],
      ResolutionPreset.medium, // Lowered slightly for faster upload
      enableAudio: false,
    );
    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  void _switchCamera() {
    if (cameras.length < 2) return;
    _selectedCameraIndex = _selectedCameraIndex == 0 ? 1 : 0;
    _initCamera(_selectedCameraIndex);
  }

  void _showPopup(String title, String message, IconData icon, Color color) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Text(message, style: const TextStyle(fontSize: 16)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
    );
  }

  Future<void> _takePhoto() async {
    if (_isUploading ||
        _controller == null ||
        !_controller!.value.isInitialized)
      return;

    if (_serverIp.isEmpty) {
      _showPopup(
        "Setup Required",
        "Please configure the server IP in the Admin Panel.",
        Icons.settings,
        Colors.orange,
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final photo = await _controller!.takePicture();
      await _uploadImage(File(photo.path));
    } catch (e) {
      _showPopup(
        "Camera Error",
        "Failed to take photo.",
        Icons.error,
        Colors.red,
      );
    }

    setState(() => _isUploading = false);
  }

  Future<void> _uploadImage(File image) async {
    try {
      // Ensure the URL is correctly formatted
      String url =
          _serverIp.startsWith("http") ? _serverIp : "http://$_serverIp";
      // If the user forgot the endpoint, assume /kiosk_scan (Optional safety)
      if (!url.endsWith("/kiosk_scan")) {
        // You might want to remove this if you type the full URL in settings
        // url = "$url/kiosk_scan";
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(url), // Uses the settings IP
      );

      request.fields['classroom_id'] = _roomId;
      request.files.add(await http.MultipartFile.fromPath('image', image.path));

      final response = await request.send();
      final rawBody = await response.stream.bytesToString();

      if (!mounted) return;

      // 1. DECODE JSON FROM PYTHON
      final data = jsonDecode(rawBody);

      // 2. EXTRACT THE SMART MESSAGE
      // This gets the text like "Wrong Place!" or "Welcome!" directly from Python
      final String serverMessage = data['message'] ?? "No message from server.";

      switch (response.statusCode) {
        case 200:
          // ✅ SUCCESS
          _showPopup(
            "Attendance Confirmed",
            serverMessage, // <--- Displays Python's Success Message
            Icons.check_circle,
            Colors.green,
          );
          break;

        case 401:
          // ❌ UNKNOWN FACE
          _showPopup(
            "Face Not Recognized",
            serverMessage, // <--- Displays "Unknown Face"
            Icons.face_retouching_off,
            Colors.red,
          );
          break;

        case 403:
          // ⚠️ WRONG ROOM / TIME
          _showPopup(
            "Attendance Warning",
            serverMessage, // <--- Displays "Wrong Place! Room X..."
            Icons.warning_amber_rounded,
            Colors.orange,
          );
          break;

        default:
          // 🛑 SERVER ERROR
          _showPopup("System Error", serverMessage, Icons.error, Colors.red);
      }
    } catch (e) {
      _showPopup(
        "Connection Error",
        "Unable to reach the server.\nCheck IP: $_serverIp\nError: $e",
        Icons.wifi_off,
        Colors.red,
      );
    }
  }

  void _unlockAdminPanel() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text("Admin Access"),
            content: TextField(
              controller: controller,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "PIN"),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  if (controller.text == "1234") {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminPanel()),
                    ).then((_) => _loadSettings());
                  } else {
                    Navigator.pop(context); // Close dialog first
                    _showPopup(
                      "Access Denied",
                      "Incorrect PIN.",
                      Icons.lock_outline,
                      Colors.red,
                    );
                  }
                },
                child: const Text("Unlock"),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full Screen Camera Preview
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.previewSize!.height,
                height: _controller!.value.previewSize!.width,
                child: CameraPreview(_controller!),
              ),
            ),
          ),

          // Top Bar (Admin + Room ID + Switch Cam)
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FloatingActionButton.small(
                  backgroundColor: Colors.redAccent,
                  onPressed: _unlockAdminPanel,
                  child: const Icon(Icons.settings),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: Text(
                    "Room: $_roomId",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                FloatingActionButton.small(
                  onPressed: _switchCamera,
                  child: const Icon(Icons.flip_camera_ios),
                ),
              ],
            ),
          ),

          // Bottom Capture Button
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _takePhoto,
                child: Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    color: _isUploading ? Colors.grey : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.blueAccent, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child:
                      _isUploading
                          ? const Padding(
                            padding: EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                          : const Icon(
                            Icons.camera_alt,
                            size: 40,
                            color: Colors.blueAccent,
                          ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  final _ipController = TextEditingController();
  final _roomController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _ipController.text = prefs.getString('server_ip') ?? "";
    _roomController.text = prefs.getString('room_id') ?? "";
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();

    // Auto-fix the URL if user forgets 'http://' or endpoint
    String ip = _ipController.text.trim();
    if (ip.isNotEmpty && !ip.startsWith("http")) {
      ip = "http://$ip";
    }
    // Note: In your settings page, you usually just save the BASE URL (e.g., http://192.168.x.x:5001/kiosk_scan)
    // Make sure your Admin panel input matches exactly what Python expects.

    await prefs.setString('server_ip', ip);
    await prefs.setString('room_id', _roomController.text.trim());

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Settings")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "Configuration",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: "Full API URL",
                hintText: "http://192.168.1.5:5001/kiosk_scan",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _roomController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Room ID",
                hintText: "e.g., 101",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.meeting_room),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                ),
                onPressed: _save,
                child: const Text(
                  "Save & Exit",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
