import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────
// ENTRY POINT
// ─────────────────────────────────────────────────────────────
List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(
    const MaterialApp(
      home: AMSKiosk(),
      debugShowCheckedModeBanner: false,
      title: 'AMS Kiosk',
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// KIOSK STATE MACHINE
// ─────────────────────────────────────────────────────────────
enum KioskState { standby, faceDetected, countdown, scanning, result }

// ─────────────────────────────────────────────────────────────
// MAIN KIOSK WIDGET
// ─────────────────────────────────────────────────────────────
class AMSKiosk extends StatefulWidget {
  const AMSKiosk({super.key});
  @override
  State<AMSKiosk> createState() => _AMSKioskState();
}

class _AMSKioskState extends State<AMSKiosk> with WidgetsBindingObserver {
  // ── Camera ──────────────────────────────────────────────────
  CameraController? _controller;
  int _cameraIndex = 0;
  bool _isCameraInitialized = false;

  // ── ML Kit Face Detector ────────────────────────────────────
  late final FaceDetector _faceDetector;
  bool _isDetecting = false;

  // ── Kiosk State ─────────────────────────────────────────────
  KioskState _state = KioskState.standby;
  int _countdown = 3;
  Timer? _countdownTimer;

  // ── Face bounding box (normalized) ──────────────────────────
  Rect? _faceRect;
  Size? _previewSize;

  // ── Config ──────────────────────────────────────────────────
  String _serverIP = '192.168.1.1';
  String _serverPort = '5001';
  String _classroomId = '101';

  // ── Result ──────────────────────────────────────────────────
  bool _resultSuccess = false;
  String _resultMessage = '';

  // ── Stable-face tracking ────────────────────────────────────
  int _stableFrames = 0;
  static const int _stableFramesRequired = 8;

  // ── Frame throttle (reduce ML Kit log noise) ─────────────────
  int _frameCount = 0;
  static const int _frameSkip = 4; // process 1 in every 4 frames

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        enableContours: false,
        enableClassification: false,
      ),
    );
    _loadSettings();
    _initCamera(_cameraIndex);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_isCameraInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller!.stopImageStream();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera(_cameraIndex);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _faceDetector.close();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ── Settings ─────────────────────────────────────────────────
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _serverIP = prefs.getString('server_ip') ?? '192.168.1.1';
      _serverPort = prefs.getString('server_port') ?? '5001';
      _classroomId = prefs.getString('classroom_id') ?? '101';
    });
  }

  Future<void> _saveSettings(String ip, String port, String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_ip', ip);
    await prefs.setString('server_port', port);
    await prefs.setString('classroom_id', roomId);
    setState(() {
      _serverIP = ip;
      _serverPort = port;
      _classroomId = roomId;
    });
  }

  String get _baseUrl {
    final ip =
        _serverIP.replaceAll('http://', '').replaceAll('/', '').split(':')[0];
    return 'http://$ip:$_serverPort';
  }

  // ── Camera init ──────────────────────────────────────────────
  Future<void> _initCamera(int index) async {
    if (cameras.isEmpty) return;
    final prev = _controller;
    // Mark as uninitialised and clear reference BEFORE disposal so
    // the widget tree never tries to render with a dead controller.
    setState(() {
      _isCameraInitialized = false;
      _controller = null;
      _faceRect   = null;
    });
    if (prev != null) {
      await prev.stopImageStream().catchError((_) {});
      await prev.dispose();
    }

    final cam = cameras[index % cameras.length];
    final ctrl = CameraController(
      cam,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    _controller = ctrl;

    try {
      await ctrl.initialize();
      _previewSize = ctrl.value.previewSize;
      if (mounted) {
        setState(() => _isCameraInitialized = true);
        _startImageStream();
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  void _toggleCamera() {
    _stableFrames = 0;
    _setState(KioskState.standby);
    _cameraIndex = (_cameraIndex + 1) % cameras.length;
    _initCamera(_cameraIndex);
  }

  // ── Image stream → face detection ────────────────────────────
  void _startImageStream() {
    _frameCount = 0;
    _controller?.startImageStream((CameraImage img) async {
      // Throttle: only process every _frameSkip-th frame to cut log noise
      _frameCount++;
      if (_frameCount % _frameSkip != 0) return;
      if (_isDetecting ||
          _state == KioskState.scanning ||
          _state == KioskState.result) {
        return;
      }
      _isDetecting = true;
      try {
        await _processFrame(img);
      } finally {
        _isDetecting = false;
      }
    });
  }

  Future<void> _processFrame(CameraImage img) async {
    final cam = cameras[_cameraIndex % cameras.length];
    final rotation = _rotationFromSensorOrientation(cam.sensorOrientation);

    final inputImage = InputImage.fromBytes(
      bytes: _concatenatePlanes(img.planes),
      metadata: InputImageMetadata(
        size: Size(img.width.toDouble(), img.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: img.planes[0].bytesPerRow,
      ),
    );

    final faces = await _faceDetector.processImage(inputImage);

    if (!mounted) return;

    if (faces.isNotEmpty) {
      final face = faces.first;
      // ML Kit returns boxes in the post-rotation coordinate space.
      // Most Android sensors are landscape (90°/270° orientation), so
      // the rotated display space has its axes swapped vs the raw frame.
      final rotated =
          cam.sensorOrientation == 90 || cam.sensorOrientation == 270;
      final displayW =
          rotated ? img.height.toDouble() : img.width.toDouble();
      final displayH =
          rotated ? img.width.toDouble() : img.height.toDouble();

      // Front cameras are shown mirrored in the preview.
      // Flip the bounding box X so it tracks correctly.
      Rect box = face.boundingBox;
      if (cam.lensDirection == CameraLensDirection.front) {
        box = Rect.fromLTRB(
          displayW - face.boundingBox.right,
          face.boundingBox.top,
          displayW - face.boundingBox.left,
          face.boundingBox.bottom,
        );
      }

      setState(() {
        _faceRect    = box;
        _previewSize = Size(displayW, displayH);
      });
      _stableFrames++;

      if (_state == KioskState.standby &&
          _stableFrames >= _stableFramesRequired) {
        _setState(KioskState.faceDetected);
        _startCountdown();
      }
    } else {
      _stableFrames = 0;
      if (_state == KioskState.faceDetected || _state == KioskState.countdown) {
        _countdownTimer?.cancel();
        _setState(KioskState.standby);
      }
      if (mounted) setState(() => _faceRect = null);
    }
  }

  InputImageRotation _rotationFromSensorOrientation(int orientation) {
    switch (orientation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    int total = 0;
    for (final p in planes) {
      total += p.bytes.length;
    }
    final result = Uint8List(total);
    int offset = 0;
    for (final p in planes) {
      result.setRange(offset, offset + p.bytes.length, p.bytes);
      offset += p.bytes.length;
    }
    return result;
  }

  // ── Countdown → capture ──────────────────────────────────────
  void _startCountdown() {
    _countdown = 3;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        _captureAndSend();
      }
    });
  }

  Future<void> _captureAndSend() async {
    if (_controller == null || !_isCameraInitialized) return;
    _setState(KioskState.scanning);
    _faceRect = null;

    try {
      await _controller!.stopImageStream();
      final XFile photo = await _controller!.takePicture();

      final uri = Uri.parse('$_baseUrl/kiosk_scan');
      final req =
          http.MultipartRequest('POST', uri)
            ..fields['classroom_id'] = _classroomId
            ..files.add(await http.MultipartFile.fromPath('image', photo.path));

      final response = await http.Response.fromStream(
        await req.send(),
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      _showResult(data['match'] == true, data['message']?.toString() ?? '');
    } on SocketException {
      _showResult(false, 'CONNECTION ERROR\nCannot reach server at $_serverIP');
    } on TimeoutException {
      _showResult(false, 'TIMEOUT\nServer did not respond in time.');
    } catch (e) {
      _showResult(false, 'ERROR\n$e');
    }
  }

  void _showResult(bool success, String message) {
    if (!mounted) return;
    setState(() {
      _resultSuccess = success;
      _resultMessage = message;
    });
    _setState(KioskState.result);
  }

  void _dismissResult() {
    _setState(KioskState.standby);
    _stableFrames = 0;
    _startImageStream();
  }

  void _setState(KioskState s) {
    if (mounted) setState(() => _state = s);
  }

  // ── Admin PIN challenge ──────────────────────────────────────
  Future<void> _challengeAdmin() async {
    // Stop detection so it doesn't fight with the dialog's setState calls.
    await _controller?.stopImageStream().catchError((_) {});
    _stableFrames = 0;
    if (mounted) setState(() => _faceRect = null);

    // Capture context-dependent objects before the async gap.
    if (!mounted) return;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final pinCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text(
              'Admin Access',
              style: TextStyle(color: Colors.white),
            ),
            content: TextField(
              controller: pinCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Enter PIN',
                hintStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.blueAccent),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  bool pinOk = false;
                  try {
                    final res = await http
                        .post(
                          Uri.parse('$_baseUrl/verify_admin_pin'),
                          headers: {'Content-Type': 'application/json'},
                          body: jsonEncode({'pin': pinCtrl.text}),
                        )
                        .timeout(const Duration(seconds: 5));
                    pinOk = res.statusCode == 200;
                  } catch (_) {
                    pinOk = pinCtrl.text == '1234';
                  }
                  if (ctx.mounted) Navigator.pop(ctx, pinOk);
                },
                child: const Text('Verify'),
              ),
            ],
          ),
    );

    if (ok == true) {
      await nav.push(
        MaterialPageRoute(
          builder:
              (_) => SettingsPage(
                currentIP: _serverIP,
                currentPort: _serverPort,
                currentRoom: _classroomId,
                onSave: _saveSettings,
              ),
        ),
      );
    } else if (ok == false) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Wrong PIN — access denied.')),
      );
    }

    // Restart face detection regardless of whether settings were opened or PIN was wrong.
    if (mounted) _startImageStream();
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.blueAccent),
              SizedBox(height: 16),
              Text(
                'Starting camera…',
                style: TextStyle(color: Colors.white60, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera preview ──────────────────────────────────
          CameraPreview(_controller!),

          // ── Face bounding box ───────────────────────────────
          if (_faceRect != null && _previewSize != null)
            _FaceOverlay(
              faceRect: _faceRect!,
              previewSize: _previewSize!,
              state: _state,
            ),

          // ── Top status bar ──────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(child: _buildStatusBar()),
          ),

          // ── Countdown ring ───────────────────────────────────
          if (_state == KioskState.countdown)
            Center(child: _CountdownRing(count: _countdown)),

          // ── Scanning spinner ─────────────────────────────────
          if (_state == KioskState.scanning)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: Colors.blueAccent,
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Analyzing…',
                      style: TextStyle(color: Colors.white70, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),

          // ── Result overlay (tap anywhere to dismiss) ─────────
          if (_state == KioskState.result)
            GestureDetector(
              onTap: _dismissResult,
              child: _ResultOverlay(
                success: _resultSuccess,
                message: _resultMessage,
              ),
            ),

          // ── Top-left: settings gear ──────────────────────────
          Positioned(
            top: 50,
            left: 12,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(
                  Icons.settings,
                  color: Colors.white70,
                  size: 28,
                ),
                onPressed: _state == KioskState.scanning ? null : _challengeAdmin,
                tooltip: 'Admin Settings',
              ),
            ),
          ),

          // ── Top-right: flip camera ───────────────────────────
          if (cameras.length > 1)
            Positioned(
              top: 50,
              right: 12,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(
                    Icons.flip_camera_android,
                    color: Colors.white70,
                    size: 28,
                  ),
                  onPressed: _state == KioskState.scanning ? null : _toggleCamera,
                  tooltip: 'Flip Camera',
                ),
              ),
            ),

          // ── Room ID badge ────────────────────────────────────
          Positioned(
            bottom: 24,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Room $_classroomId',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    String label;
    Color color;
    IconData icon;

    switch (_state) {
      case KioskState.standby:
        label = 'Stand in front of camera';
        color = Colors.blueGrey;
        icon = Icons.face;
        break;
      case KioskState.faceDetected:
        label = 'Face detected — hold still';
        color = Colors.amber;
        icon = Icons.face_retouching_natural;
        break;
      case KioskState.countdown:
        label = 'Capturing in $_countdown…';
        color = Colors.orange;
        icon = Icons.timer;
        break;
      case KioskState.scanning:
        label = 'Analyzing…';
        color = Colors.blueAccent;
        icon = Icons.search;
        break;
      case KioskState.result:
        label = _resultSuccess ? 'ACCESS GRANTED' : 'ACCESS DENIED';
        color = _resultSuccess ? Colors.green : Colors.redAccent;
        icon = _resultSuccess ? Icons.check_circle : Icons.cancel;
        break;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(60, 8, 60, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FACE OVERLAY PAINTER
// ─────────────────────────────────────────────────────────────
class _FaceOverlay extends StatelessWidget {
  const _FaceOverlay({
    required this.faceRect,
    required this.previewSize,
    required this.state,
  });
  final Rect faceRect;
  final Size previewSize;
  final KioskState state;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        return CustomPaint(
          painter: _FacePainter(
            faceRect: faceRect,
            previewSize: previewSize,
            screenSize: Size(constraints.maxWidth, constraints.maxHeight),
            state: state,
          ),
        );
      },
    );
  }
}

class _FacePainter extends CustomPainter {
  const _FacePainter({
    required this.faceRect,
    required this.previewSize,
    required this.screenSize,
    required this.state,
  });

  final Rect faceRect;
  final Size previewSize;
  final Size screenSize;
  final KioskState state;

  @override
  void paint(Canvas canvas, Size size) {
    final Color color;
    switch (state) {
      case KioskState.faceDetected:
        color = Colors.amber;
        break;
      case KioskState.countdown:
        color = Colors.orange;
        break;
      default:
        color = Colors.blueAccent;
    }

    final scaleX = screenSize.width / previewSize.width;
    final scaleY = screenSize.height / previewSize.height;

    final scaled = Rect.fromLTRB(
      faceRect.left * scaleX,
      faceRect.top * scaleY,
      faceRect.right * scaleX,
      faceRect.bottom * scaleY,
    );

    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;

    const cornerLen = 20.0;

    // Draw corner brackets instead of full rectangle
    final corners = [
      // top-left
      [
        Offset(scaled.left, scaled.top + cornerLen),
        Offset(scaled.left, scaled.top),
        Offset(scaled.left + cornerLen, scaled.top),
      ],
      // top-right
      [
        Offset(scaled.right - cornerLen, scaled.top),
        Offset(scaled.right, scaled.top),
        Offset(scaled.right, scaled.top + cornerLen),
      ],
      // bottom-left
      [
        Offset(scaled.left, scaled.bottom - cornerLen),
        Offset(scaled.left, scaled.bottom),
        Offset(scaled.left + cornerLen, scaled.bottom),
      ],
      // bottom-right
      [
        Offset(scaled.right - cornerLen, scaled.bottom),
        Offset(scaled.right, scaled.bottom),
        Offset(scaled.right, scaled.bottom - cornerLen),
      ],
    ];

    for (final pts in corners) {
      final path =
          Path()
            ..moveTo(pts[0].dx, pts[0].dy)
            ..lineTo(pts[1].dx, pts[1].dy)
            ..lineTo(pts[2].dx, pts[2].dy);
      canvas.drawPath(path, paint);
    }

    // Glow
    canvas.drawRect(
      scaled,
      Paint()
        ..color = color.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_FacePainter old) =>
      old.faceRect != faceRect || old.state != state;
}

// ─────────────────────────────────────────────────────────────
// COUNTDOWN RING WIDGET
// ─────────────────────────────────────────────────────────────
class _CountdownRing extends StatelessWidget {
  const _CountdownRing({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black54,
        border: Border.all(color: Colors.orange, width: 3),
      ),
      child: Center(
        child: Text(
          '$count',
          style: const TextStyle(
            color: Colors.orange,
            fontSize: 48,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// RESULT OVERLAY
// ─────────────────────────────────────────────────────────────
class _ResultOverlay extends StatelessWidget {
  const _ResultOverlay({required this.success, required this.message});
  final bool success;
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = success ? Colors.green : Colors.redAccent;
    return Container(
      color: Colors.black87,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color, width: 2),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 24),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                success ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: color,
                size: 64,
              ),
              const SizedBox(height: 12),
              Text(
                success ? 'ACCESS GRANTED' : 'ACCESS DENIED',
                style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SETTINGS PAGE
// ─────────────────────────────────────────────────────────────
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.currentIP,
    required this.currentPort,
    required this.currentRoom,
    required this.onSave,
  });
  final String currentIP;
  final String currentPort;
  final String currentRoom;
  final Future<void> Function(String ip, String port, String roomId) onSave;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _ipCtrl;
  late final TextEditingController _portCtrl;
  late final TextEditingController _roomCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ipCtrl = TextEditingController(text: widget.currentIP);
    _portCtrl = TextEditingController(text: widget.currentPort);
    _roomCtrl = TextEditingController(text: widget.currentRoom);
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _portCtrl.dispose();
    _roomCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Settings'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFF121212),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'NETWORK',
              style: TextStyle(
                color: Colors.blueAccent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            _buildField(
              controller: _ipCtrl,
              label: 'Server IP Address',
              hint: '192.168.1.100',
              icon: Icons.dns,
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            _buildField(
              controller: _portCtrl,
              label: 'Server Port',
              hint: '5001',
              icon: Icons.settings_ethernet,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            const Text(
              'KIOSK',
              style: TextStyle(
                color: Colors.blueAccent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            _buildField(
              controller: _roomCtrl,
              label: 'Classroom ID',
              hint: '101',
              icon: Icons.meeting_room,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed:
                    _saving
                        ? null
                        : () async {
                          setState(() => _saving = true);
                          final nav = Navigator.of(context);
                          await widget.onSave(
                            _ipCtrl.text.trim(),
                            _portCtrl.text.trim(),
                            _roomCtrl.text.trim(),
                          );
                          nav.pop();
                        },
                icon:
                    _saving
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.save),
                label: Text(_saving ? 'Saving…' : 'Save Configuration'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        labelStyle: const TextStyle(color: Colors.white60),
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.blueAccent),
        ),
      ),
    );
  }
}
