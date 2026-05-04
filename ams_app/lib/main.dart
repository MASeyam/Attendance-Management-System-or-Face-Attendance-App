import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(
    const MaterialApp(home: AMSKiosk(), debugShowCheckedModeBanner: false),
  );
}

class AMSKiosk extends StatefulWidget {
  const AMSKiosk({super.key});
  @override
  State<AMSKiosk> createState() => _AMSKioskState();
}

class _AMSKioskState extends State<AMSKiosk> {
  CameraController? _controller;
  bool isProcessing = false;
  String statusMessage = "Standing By...";
  Color statusColor = Colors.blueGrey;
  String serverIP = "192.168.1.1";

  // 🔄 New Variable to track camera index
  int _selectedCameraIndex = 1;

  @override
  void initState() {
    super.initState();
    _loadIP();
    _initCamera(_selectedCameraIndex);
  }

  // 🛠️ Helper to initialize camera (handles swapping)
  Future<void> _initCamera(int index) async {
    if (_controller != null) {
      await _controller!.dispose();
    }
    _controller = CameraController(cameras[index], ResolutionPreset.high);
    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  // 🔄 Toggle Function
  void _toggleCamera() {
    if (cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex == 0) ? 1 : 0;
    _initCamera(_selectedCameraIndex);
  }

  _loadIP() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => serverIP = prefs.getString('server_ip') ?? "192.168.1.1");
  }

  void _challengeAdmin() {
    TextEditingController pinController = TextEditingController();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Admin Authentication"),
            content: TextField(
              controller: pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: "Enter PIN"),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  if (pinController.text == "1234") {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => SettingsPage(
                              currentIP: serverIP,
                              onSave: (newIP) {
                                setState(() => serverIP = newIP);
                              },
                            ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Wrong PIN! Access Denied."),
                      ),
                    );
                  }
                },
                child: const Text("Verify"),
              ),
            ],
          ),
    );
  }

  void showAuditAlert(bool success, String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF121212),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: BorderSide(color: success ? Colors.green : Colors.red),
            ),
            title: Text(
              success ? "SUCCESS" : "FAILED",
              style: TextStyle(
                color: success ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
    );
  }

  Future<void> captureAndVerify() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        isProcessing)
      return;

    String cleanIP =
        serverIP.replaceAll("http://", "").replaceAll("/", "").split(":")[0];

    setState(() {
      isProcessing = true;
      statusMessage = "ANALYZING...";
      statusColor = Colors.orange;
    });

    try {
      XFile image = await _controller!.takePicture();
      var uri = Uri.parse('http://$cleanIP:5001/kiosk_scan');
      var request = http.MultipartRequest('POST', uri);

      request.fields['classroom_id'] = "101";
      request.files.add(await http.MultipartFile.fromPath('image', image.path));

      var response = await http.Response.fromStream(await request.send());
      var data = jsonDecode(response.body);

      showAuditAlert(data['match'], data['message']);
      setState(() {
        statusMessage = data['match'] ? "VERIFIED" : "REJECTED";
        statusColor = data['match'] ? Colors.green : Colors.red;
      });
    } catch (e) {
      showAuditAlert(false, "CONNECTION ERROR\nTarget IP: $cleanIP\n$e");
    } finally {
      setState(() => isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized)
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: CameraPreview(_controller!)),

          // ⚙️ THE GEAR BUTTON (Top Left)
          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.settings, color: Colors.white, size: 30),
              onPressed: _challengeAdmin,
            ),
          ),

          // 🔄 NEW: THE FLIP BUTTON (Top Right)
          Positioned(
            top: 50,
            right: 20,
            child: IconButton(
              icon: const Icon(
                Icons.flip_camera_android,
                color: Colors.white,
                size: 30,
              ),
              onPressed: _toggleCamera,
            ),
          ),

          Positioned(
            top: 50,
            left: 80,
            right: 80, // Updated to give room for the flip button
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: captureAndVerify,
                child: Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: Icon(
                    isProcessing ? Icons.hourglass_top : Icons.camera_alt,
                    size: 40,
                    color: Colors.white,
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

class SettingsPage extends StatelessWidget {
  final String currentIP;
  final Function(String) onSave;
  const SettingsPage({
    super.key,
    required this.currentIP,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    TextEditingController controller = TextEditingController(text: currentIP);
    return Scaffold(
      appBar: AppBar(
        title: const Text("System Settings"),
        backgroundColor: Colors.blueGrey,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: "Server IP Address",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('server_ip', controller.text);
                onSave(controller.text);
                Navigator.pop(context);
              },
              child: const Text("SAVE CONFIGURATION"),
            ),
          ],
        ),
      ),
    );
  }
}
