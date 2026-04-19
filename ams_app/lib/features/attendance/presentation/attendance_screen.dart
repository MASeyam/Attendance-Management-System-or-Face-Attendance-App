import 'package:ams_app/core/constants/app_constants.dart';
import 'package:ams_app/core/widgets/kiosk_status_card.dart';
import 'package:ams_app/features/attendance/controller/attendance_controller.dart';
import 'package:ams_app/features/settings/models/app_settings.dart';
import 'package:ams_app/features/settings/presentation/admin_settings_screen.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late final AttendanceController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AttendanceController()..initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openAdminPanel() async {
    final pinController = TextEditingController();
    final unlocked = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Admin Access'),
            content: TextField(
              controller: pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'PIN',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(
                    context,
                  ).pop(pinController.text == AppConstants.adminPin);
                },
                child: const Text('Unlock'),
              ),
            ],
          ),
    );
    pinController.dispose();

    if (!mounted || unlocked != true) {
      return;
    }

    await _controller.pauseScanning();
    if (!mounted) {
      return;
    }

    final updatedSettings = await Navigator.of(context).push<AppSettings>(
      MaterialPageRoute(
        builder:
            (_) => AdminSettingsScreen(initialSettings: _controller.settings),
      ),
    );

    if (!mounted) {
      return;
    }

    if (updatedSettings != null) {
      await _controller.saveSettings(updatedSettings);
    } else {
      await _controller.refreshSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.isInitializing) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          body: Stack(
            children: [
              Positioned.fill(child: _buildCameraLayer()),
              Positioned.fill(child: _buildFocusOverlay()),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                  child: Column(
                    children: [
                      _buildTopBar(),
                      const Spacer(),
                      KioskStatusCard(
                        title: _controller.statusTitle,
                        message: _controller.statusMessage,
                        icon: _statusIcon(_controller.statusTone),
                        color: _statusColor(_controller.statusTone),
                        loading:
                            _controller.statusTone == KioskStatusTone.progress,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCameraLayer() {
    final cameraController = _controller.cameraController;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final previewSize = cameraController.value.previewSize;
    if (previewSize == null) {
      return CameraPreview(cameraController);
    }

    return ColoredBox(
      color: Colors.black,
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewSize.height,
          height: previewSize.width,
          child: CameraPreview(cameraController),
        ),
      ),
    );
  }

  Widget _buildFocusOverlay() {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 240,
          height: 320,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.7),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 22,
                spreadRadius: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        FloatingActionButton.small(
          heroTag: 'settings',
          backgroundColor: Colors.redAccent,
          onPressed: _openAdminPanel,
          child: const Icon(Icons.settings),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Room ${_controller.settings.roomLabel}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Automatic face capture kiosk',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.74),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        FloatingActionButton.small(
          heroTag: 'switch_camera',
          onPressed:
              _controller.canSwitchCamera && !_controller.isBusy
                  ? _controller.switchCamera
                  : null,
          child: const Icon(Icons.flip_camera_ios),
        ),
      ],
    );
  }

  Color _statusColor(KioskStatusTone tone) {
    switch (tone) {
      case KioskStatusTone.success:
        return Colors.greenAccent.shade400;
      case KioskStatusTone.warning:
        return Colors.orangeAccent.shade200;
      case KioskStatusTone.error:
        return Colors.redAccent.shade200;
      case KioskStatusTone.progress:
        return Colors.lightBlueAccent.shade200;
      case KioskStatusTone.neutral:
        return Colors.white;
    }
  }

  IconData _statusIcon(KioskStatusTone tone) {
    switch (tone) {
      case KioskStatusTone.success:
        return Icons.check_circle_outline;
      case KioskStatusTone.warning:
        return Icons.warning_amber_rounded;
      case KioskStatusTone.error:
        return Icons.error_outline;
      case KioskStatusTone.progress:
        return Icons.hourglass_top_rounded;
      case KioskStatusTone.neutral:
        return Icons.center_focus_strong;
    }
  }
}
