import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../core/api_constants.dart';
import '../../core/theme.dart';

class AddInstructorScreen extends StatefulWidget {
  const AddInstructorScreen({super.key});

  @override
  State<AddInstructorScreen> createState() => _AddInstructorScreenState();
}

class _AddInstructorScreenState extends State<AddInstructorScreen> {
  final _formKey  = GlobalKey<FormState>();
  int _step       = 0;

  final _personalEmailCtrl = TextEditingController();
  final _firstCtrl         = TextEditingController();
  final _lastCtrl          = TextEditingController();
  final _phoneCtrl         = TextEditingController();

  String? _role;
  int? _departmentId;
  List<dynamic> _departments = [];
  String _uniEmail  = '';
  String _password  = '';

  final List<XFile> _photos = [];
  bool   _training   = false;
  String _trainError = '';
  int?   _newId;

  @override
  void initState() {
    super.initState();
    _fetchDepartments();
    _firstCtrl.addListener(_updateUniEmail);
    _lastCtrl.addListener(_updateUniEmail);
  }

  @override
  void dispose() {
    _personalEmailCtrl.dispose();
    _firstCtrl.dispose(); _lastCtrl.dispose(); _phoneCtrl.dispose();
    super.dispose();
  }

  void _updateUniEmail() {
    final first = _firstCtrl.text.trim().toLowerCase();
    final last  = _lastCtrl.text.trim().toLowerCase();
    setState(() => _uniEmail =
        (first.isNotEmpty && last.isNotEmpty) ? '$first.$last@fue.edu.eg' : '');
  }

  String _generatePassword() {
    const chars = 'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789@#!';
    final rng   = Random.secure();
    return List.generate(10, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  Future<void> _fetchDepartments() async {
    try {
      final res  = await http.get(Uri.parse(ApiConstants.departments));
      final data = jsonDecode(res.body);
      if (data['success'] == true && mounted) {
        setState(() => _departments = data['departments']);
      }
    } catch (_) {}
  }

  void _goToStep2() {
    if (!_formKey.currentState!.validate()) return;
    if (_role == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a role'),
            backgroundColor: AppColors.warning),
      );
      return;
    }
    setState(() { _password = _generatePassword(); _step = 1; });
  }

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 85);
    if (picked.isNotEmpty) setState(() { _photos.clear(); _photos.addAll(picked); });
  }

  Future<void> _runTraining() async {
    if (_photos.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload at least 5 photos'),
            backgroundColor: AppColors.warning),
      );
      return;
    }
    setState(() { _training = true; _trainError = ''; });
    try {
      // Create instructor first to get ID
      final createRes = await http.post(
        Uri.parse(ApiConstants.createInstructor),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'first_name':     _firstCtrl.text.trim(),
          'last_name':      _lastCtrl.text.trim(),
          'email':          _uniEmail,
          'personal_email': _personalEmailCtrl.text.trim(),
          'phone_number':   _phoneCtrl.text.trim(),
          'password':       _password,
          'role':           _role,
          'username': '${_firstCtrl.text.trim().toLowerCase()}.${_lastCtrl.text.trim().toLowerCase()}',
          'department_id':  _departmentId,
        }),
      );
      final createData = jsonDecode(createRes.body);
      if (createData['success'] != true) {
        throw Exception(createData['message'] ?? 'Create failed');
      }
      _newId = createData['id'] as int?;

      // Upload photos
      final uploadReq = http.MultipartRequest(
          'POST', Uri.parse(ApiConstants.uploadPhotos('instructor_$_newId')));
      for (final photo in _photos) {
        uploadReq.files.add(await http.MultipartFile.fromPath('photos', photo.path));
      }
      final uploadRes  = await uploadReq.send();
      final uploadBody = jsonDecode(await uploadRes.stream.bytesToString());
      if (uploadBody['success'] != true) {
        throw Exception(uploadBody['message'] ?? 'Upload failed');
      }

      // Train
      final trainRes  = await http.post(
          Uri.parse(ApiConstants.trainInstructor(_newId!)));
      final trainData = jsonDecode(trainRes.body);
      if (trainData['success'] != true) {
        throw Exception(trainData['message'] ?? 'Training failed');
      }

      if (!mounted) return;
      setState(() => _step = 2);
    } catch (e) {
      setState(() => _trainError = e.toString());
    } finally {
      if (mounted) setState(() => _training = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Step 1: Info', 'Step 2: Photos', 'Step 3: Done'];
    return Scaffold(
      appBar: AppBar(title: Text(titles[_step])),
      body: [_buildStep1(), _buildStep2(), _buildStep3()][_step],
    );
  }

  // ─── STEP 1 ────────────────────────────────────────────────────────────────
  Widget _buildStep1() {
    return Form(
      key: _formKey,
      child: ListView(padding: const EdgeInsets.all(20), children: [
        FadeInDown(
          duration: const Duration(milliseconds: 200),
          child: Row(children: [
            Expanded(child: _field(_firstCtrl, 'First Name', required: true)),
            const SizedBox(width: 12),
            Expanded(child: _field(_lastCtrl, 'Last Name', required: true)),
          ]),
        ),

        if (_uniEmail.isNotEmpty) ...[
          const SizedBox(height: 6),
          FadeIn(
            duration: const Duration(milliseconds: 200),
            child: Row(children: [
              const Icon(Icons.email_outlined, size: 14, color: AppColors.accent),
              const SizedBox(width: 6),
              Text(_uniEmail,
                  style: GoogleFonts.poppins(
                      color: AppColors.accent, fontSize: 12)),
            ]),
          ),
        ],

        const SizedBox(height: 12),

        FadeInDown(
          delay: const Duration(milliseconds: 40),
          duration: const Duration(milliseconds: 200),
          child: TextFormField(
            controller: _personalEmailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Personal Email',
              hintText: 'instructor@gmail.com',
              prefixIcon: Icon(Icons.email_rounded),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Personal email is required';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
        ),

        const SizedBox(height: 12),

        FadeInDown(
          delay: const Duration(milliseconds: 80),
          duration: const Duration(milliseconds: 200),
          child: _field(_phoneCtrl, 'Phone'),
        ),

        const SizedBox(height: 12),

        FadeInDown(
          delay: const Duration(milliseconds: 120),
          duration: const Duration(milliseconds: 200),
          child: DropdownButtonFormField<String>(
            value: _role,
            decoration: const InputDecoration(labelText: 'Role'),
            items: ['Professor', 'Lecturer', 'TA']
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: (v) => setState(() => _role = v),
          ),
        ),

        const SizedBox(height: 12),

        FadeInDown(
          delay: const Duration(milliseconds: 160),
          duration: const Duration(milliseconds: 200),
          child: DropdownButtonFormField<int>(
            value: _departmentId,
            decoration: const InputDecoration(labelText: 'Department'),
            items: _departments
                .map<DropdownMenuItem<int>>((d) => DropdownMenuItem(
                    value: d['id'] as int, child: Text(d['name'])))
                .toList(),
            onChanged: (v) => setState(() => _departmentId = v),
          ),
        ),

        const SizedBox(height: 28),

        FadeInUp(
          delay: const Duration(milliseconds: 200),
          duration: const Duration(milliseconds: 200),
          child: GradientButton(
            label: 'Next: Upload Photos',
            icon: Icons.arrow_forward_rounded,
            onTap: _goToStep2,
          ),
        ),
      ]),
    );
  }

  // ─── STEP 2 ────────────────────────────────────────────────────────────────
  Widget _buildStep2() {
    return ListView(padding: const EdgeInsets.all(20), children: [
      FadeInDown(
        duration: const Duration(milliseconds: 200),
        child: Text('Upload Photos for ${_firstCtrl.text}',
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w700,
                color: context.clrText)),
      ),
      const SizedBox(height: 4),
      Text('Upload at least 5 clear face photos.',
          style: GoogleFonts.poppins(color: context.clrSubText, fontSize: 13)),
      const SizedBox(height: 20),
      FadeInUp(
        delay: const Duration(milliseconds: 60),
        duration: const Duration(milliseconds: 200),
        child: _photos.isEmpty
            ? GestureDetector(
                onTap: _pickPhotos,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: AppColors.accent.withAlpha(80),
                        width: 2,
                        style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(16),
                    color: AppColors.accent.withAlpha(10),
                  ),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_photo_alternate_rounded,
                            size: 48, color: AppColors.accent),
                        const SizedBox(height: 8),
                        Text('Tap to select photos',
                            style: GoogleFonts.poppins(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w500)),
                      ]),
                ),
              )
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8),
                  itemCount: _photos.length,
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(File(_photos[i].path), fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 8),
                Text('${_photos.length} photo(s) selected',
                    style: GoogleFonts.poppins(
                        color: context.clrSubText, fontSize: 13)),
                TextButton.icon(
                  onPressed: _pickPhotos,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Change photos'),
                ),
              ]),
      ),
      const SizedBox(height: 16),
      FadeInUp(
        delay: const Duration(milliseconds: 100),
        duration: const Duration(milliseconds: 200),
        child: Card(
          color: context.clrAccent.withAlpha(15),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.lock_rounded, color: AppColors.accent, size: 16),
                  const SizedBox(width: 8),
                  Text('Generated Password:',
                      style: GoogleFonts.poppins(
                          color: context.clrSubText, fontSize: 12)),
                ]),
                const SizedBox(height: 4),
                Text(_password,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: context.clrText,
                        letterSpacing: 1)),
              ],
            ),
          ),
        ),
      ),
      if (_trainError.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(_trainError,
            style: GoogleFonts.poppins(color: AppColors.danger, fontSize: 13)),
      ],
      const SizedBox(height: 24),
      FadeInUp(
        delay: const Duration(milliseconds: 140),
        duration: const Duration(milliseconds: 200),
        child: GradientButton(
          label: _training ? 'Processing…' : 'Create & Train',
          icon: Icons.face_retouching_natural_rounded,
          loading: _training,
          onTap: _runTraining,
        ),
      ),
    ]);
  }

  // ─── STEP 3 ────────────────────────────────────────────────────────────────
  Widget _buildStep3() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: FadeInUp(
          duration: const Duration(milliseconds: 200),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(20),
                  shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 48),
            ),
            const SizedBox(height: 20),
            Text('${_firstCtrl.text} ${_lastCtrl.text} added!',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w700,
                    color: context.clrText),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  _credRow(context, 'Uni Email', _uniEmail),
                  const SizedBox(height: 6),
                  _credRow(context, 'Password', _password),
                  if (_personalEmailCtrl.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _credRow(context, 'Sent to', _personalEmailCtrl.text.trim()),
                  ],
                ]),
              ),
            ),
            const SizedBox(height: 32),
            GradientButton(
              label: 'Done',
              icon: Icons.check_rounded,
              onTap: () => Navigator.pop(context),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _credRow(BuildContext ctx, String label, String value) {
    return Row(children: [
      SizedBox(
        width: 72,
        child: Text('$label:',
            style: GoogleFonts.poppins(color: ctx.clrSubText, fontSize: 12)),
      ),
      Expanded(
        child: Text(value,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, fontSize: 13,
                color: ctx.clrText)),
      ),
    ]);
  }

  Widget _field(TextEditingController ctrl, String label,
      {bool required = false}) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(labelText: label),
      validator:
          required ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
    );
  }
}
