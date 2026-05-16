import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../core/api_constants.dart';
import '../../core/theme.dart';

class AddCourseScreen extends StatefulWidget {
  const AddCourseScreen({super.key});

  @override
  State<AddCourseScreen> createState() => _AddCourseScreenState();
}

class _AddCourseScreenState extends State<AddCourseScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _nameCtrl    = TextEditingController();
  final _creditsCtrl = TextEditingController();
  final _spwCtrl     = TextEditingController();
  final _durCtrl     = TextEditingController();

  int? _departmentId;
  int? _instructorId;
  int? _classroomId;
  DateTime? _startDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  final Set<String> _selectedDays = {};

  List<dynamic> _departments = [];
  List<dynamic> _instructors = [];
  List<dynamic> _classrooms  = [];
  List<dynamic> _students    = [];
  final Set<int> _selectedStudents = {};

  bool _loading    = false;
  bool _submitting = false;
  String _error    = '';

  final _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
    _spwCtrl.addListener(() => setState(() {}));
    _durCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _creditsCtrl.dispose();
    _spwCtrl.dispose(); _durCtrl.dispose();
    super.dispose();
  }

  int get _estimatedSessions {
    final spw = int.tryParse(_spwCtrl.text) ?? 0;
    final dur = int.tryParse(_durCtrl.text) ?? 0;
    return spw * (dur * 4);
  }

  Future<void> _loadDropdowns() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        http.get(Uri.parse(ApiConstants.departments)),
        http.get(Uri.parse(ApiConstants.instructors)),
        http.get(Uri.parse(ApiConstants.classrooms)),
        http.get(Uri.parse(ApiConstants.students)),
      ]);
      if (!mounted) return;
      setState(() {
        _departments = jsonDecode(results[0].body)['departments'] ?? [];
        _instructors = jsonDecode(results[1].body)['instructors'] ?? [];
        _classrooms  = jsonDecode(results[2].body)['classrooms']  ?? [];
        _students    = jsonDecode(results[3].body)['students']    ?? [];
      });
    } catch (_) {
      setState(() => _error = 'Failed to load data.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) {
      setState(() => isStart ? _startTime = picked : _endTime = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null) { _snack('Select a start date'); return; }
    if (_startTime == null) { _snack('Select start time');   return; }
    if (_endTime   == null) { _snack('Select end time');     return; }
    if (_selectedDays.isEmpty) { _snack('Select session days'); return; }

    setState(() => _submitting = true);
    try {
      final res = await http.post(
        Uri.parse(ApiConstants.createCourse),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name':              _nameCtrl.text.trim(),
          'credit_hours':      int.tryParse(_creditsCtrl.text.trim()),
          'department_id':     _departmentId,
          'instructor_id':     _instructorId,
          'classroom_id':      _classroomId,
          'sessions_per_week': int.tryParse(_spwCtrl.text.trim()) ?? 1,
          'duration_months':   int.tryParse(_durCtrl.text.trim()) ?? 1,
          'start_date':        DateFormat('yyyy-MM-dd').format(_startDate!),
          'session_days':      _selectedDays.toList(),
          'start_time':
              '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}',
          'end_time':
              '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}',
          'student_ids': _selectedStudents.toList(),
        }),
      );
      final data = jsonDecode(res.body);
      if (!mounted) return;
      if (data['success'] == true) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Course Created'),
            content: Text(
              'Sessions created: ${data['total_sessions_created']}\n'
              'Students enrolled: ${data['enrollments_created']}',
            ),
            actions: [
              GradientButton(
                label: 'Done',
                icon: Icons.check_rounded,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      } else {
        _snack(data['message'] ?? 'Failed to create course', error: true);
      }
    } catch (_) {
      _snack('Cannot reach server.', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.danger : AppColors.warning,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Course')),
      body: _loading
          ? const AppShimmer(count: 8, itemHeight: 56)
          : Form(
              key: _formKey,
              child: ListView(padding: const EdgeInsets.all(20), children: [
                if (_error.isNotEmpty) ...[
                  Text(_error,
                      style: GoogleFonts.poppins(
                          color: AppColors.danger, fontSize: 13)),
                  const SizedBox(height: 12),
                ],
                FadeInDown(
                    child: _field(_nameCtrl, 'Course Name', required: true)),
                const SizedBox(height: 12),
                FadeInDown(
                  delay: const Duration(milliseconds: 50),
                  child: _field(_creditsCtrl, 'Credit Hours',
                      type: TextInputType.number),
                ),
                const SizedBox(height: 12),
                FadeInDown(
                  delay: const Duration(milliseconds: 100),
                  child: _dropdown<int>(
                      'Department', _departmentId, _departments, 'name',
                      (v) => setState(() => _departmentId = v)),
                ),
                const SizedBox(height: 12),
                FadeInDown(
                  delay: const Duration(milliseconds: 150),
                  child: _dropdown<int>(
                    'Instructor',
                    _instructorId,
                    _instructors
                        .map((i) => {
                              'id': i['id'],
                              'name': '${i['first_name']} ${i['last_name']}'
                            })
                        .toList(),
                    'name',
                    (v) => setState(() => _instructorId = v),
                  ),
                ),
                const SizedBox(height: 12),
                FadeInDown(
                  delay: const Duration(milliseconds: 200),
                  child: _dropdown<int>(
                    'Classroom',
                    _classroomId,
                    _classrooms
                        .map((c) => {
                              'id': c['id'],
                              'name': 'Room ${c['id']} - ${c['building'] ?? ''}'
                            })
                        .toList(),
                    'name',
                    (v) => setState(() => _classroomId = v),
                  ),
                ),
                const SizedBox(height: 12),
                FadeInDown(
                  delay: const Duration(milliseconds: 250),
                  child: Row(children: [
                    Expanded(child: _field(_spwCtrl, 'Sessions/Week',
                        type: TextInputType.number, required: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _field(_durCtrl, 'Duration (months)',
                        type: TextInputType.number, required: true)),
                  ]),
                ),
                if (_estimatedSessions > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Will generate $_estimatedSessions sessions',
                    style: GoogleFonts.poppins(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 12),
                  ),
                ],
                const SizedBox(height: 12),
                FadeInDown(
                  delay: const Duration(milliseconds: 300),
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: Text(
                      _startDate == null
                          ? 'Select start date'
                          : DateFormat('dd MMM yyyy').format(_startDate!),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FadeInDown(
                  delay: const Duration(milliseconds: 340),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Session Days',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: context.clrText)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: _days.map((d) {
                            final selected = _selectedDays.contains(d);
                            return FilterChip(
                              label: Text(d),
                              selected: selected,
                              onSelected: (v) => setState(() =>
                                  v ? _selectedDays.add(d) : _selectedDays.remove(d)),
                              selectedColor: AppColors.accent.withAlpha(40),
                              checkmarkColor: AppColors.accent,
                              labelStyle: TextStyle(
                                  color: selected
                                      ? AppColors.accent
                                      : context.clrSubText,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.normal),
                            );
                          }).toList(),
                        ),
                      ]),
                ),
                const SizedBox(height: 12),
                FadeInDown(
                  delay: const Duration(milliseconds: 380),
                  child: Row(children: [
                    Expanded(child: OutlinedButton.icon(
                      onPressed: () => _pickTime(true),
                      icon: const Icon(Icons.access_time_rounded, size: 16),
                      label: Text(
                          _startTime == null
                              ? 'Start time'
                              : _startTime!.format(context),
                          style: const TextStyle(fontSize: 13)),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(
                      onPressed: () => _pickTime(false),
                      icon: const Icon(Icons.access_time_filled_rounded,
                          size: 16),
                      label: Text(
                          _endTime == null
                              ? 'End time'
                              : _endTime!.format(context),
                          style: const TextStyle(fontSize: 13)),
                    )),
                  ]),
                ),
                const SizedBox(height: 20),
                FadeInDown(
                  delay: const Duration(milliseconds: 420),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Enroll Students',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: context.clrText)),
                        const SizedBox(height: 2),
                        Text('${_selectedStudents.length} selected',
                            style: GoogleFonts.poppins(
                                color: context.clrSubText, fontSize: 12)),
                        const SizedBox(height: 8),
                        Container(
                          height: 220,
                          decoration: BoxDecoration(
                              border: Border.all(
                                  color: AppColors.accent.withAlpha(50)),
                              borderRadius: BorderRadius.circular(12)),
                          child: _students.isEmpty
                              ? const Center(
                                  child: Text('No students available'))
                              : ListView.builder(
                                  itemCount: _students.length,
                                  itemBuilder: (_, i) {
                                    final s   = _students[i];
                                    final sid = s['id'] as int;
                                    return CheckboxListTile(
                                      dense: true,
                                      value: _selectedStudents.contains(sid),
                                      onChanged: (v) => setState(() => v!
                                          ? _selectedStudents.add(sid)
                                          : _selectedStudents.remove(sid)),
                                      title: Text(
                                          '${s['first_name']} ${s['last_name']}',
                                          style: GoogleFonts.poppins(
                                              fontSize: 13)),
                                      subtitle: Text('ID: $sid',
                                          style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              color: context.clrSubText)),
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      activeColor: AppColors.accent,
                                    );
                                  },
                                ),
                        ),
                      ]),
                ),
                const SizedBox(height: 28),
                FadeInUp(
                  delay: const Duration(milliseconds: 460),
                  child: GradientButton(
                    label: 'Create Course',
                    icon: Icons.add_circle_rounded,
                    loading: _submitting,
                    onTap: _submit,
                  ),
                ),
              ]),
            ),
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {TextInputType type = TextInputType.text, bool required = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(labelText: label),
      validator:
          required ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
    );
  }

  Widget _dropdown<T>(String label, T? value, List items, String nameKey,
      void Function(T?) onChange) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: items
          .map<DropdownMenuItem<T>>((item) => DropdownMenuItem<T>(
              value: item['id'] as T,
              child: Text(item[nameKey] ?? '',
                  overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: onChange,
    );
  }
}
