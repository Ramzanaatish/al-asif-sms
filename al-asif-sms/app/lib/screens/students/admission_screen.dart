import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../models/student.dart';
import '../../providers/academics_provider.dart';
import '../../providers/student_provider.dart';
import '../../services/urdu_transliterate.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/school_app_bar.dart';
import '../../widgets/ui_helpers.dart';

/// The New Student form, exactly like the HTML (Complete v7) New Student
/// popup: photo, name + Urdu auto-fill, father + Urdu, mother + Urdu,
/// Section, Group, New/Old Admission, class, B-Form, contact, and the
/// admission-no preview. Urdu auto-fills from the English name with the
/// HTML's own transliterator, and the teacher can always correct the
/// Urdu text by hand. The same form edits an existing student (the
/// HTML's Edit button opens the same popup pre-filled).
class AdmissionScreen extends StatefulWidget {
  final Student? student;

  const AdmissionScreen({super.key, this.student});

  @override
  State<AdmissionScreen> createState() => _AdmissionScreenState();
}

class _AdmissionScreenState extends State<AdmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _nameUrdu = TextEditingController();
  final _father = TextEditingController();
  final _fatherUrdu = TextEditingController();
  final _mother = TextEditingController();
  final _motherUrdu = TextEditingController();
  final _section = TextEditingController();
  final _group = TextEditingController();
  final _bform = TextEditingController();
  final _contact = TextEditingController();

  // The HTML's nsNameUrduManual flags: once the teacher types in an
  // Urdu field, typing the English name no longer overwrites it.
  bool _nameUrduManual = false;
  bool _fatherUrduManual = false;
  bool _motherUrduManual = false;

  String _admStatus = 'New';
  int? _classId;
  bool _busy = false;

  XFile? _pickedPhoto;
  String? _existingPhotoPath;

  bool get _isEdit => widget.student != null;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    if (s != null) {
      _name.text = s.name;
      // The HTML pre-fills the Urdu fields with the stored value, or
      // the transliteration when nothing was stored.
      _nameUrdu.text = urduName(s.nameUrdu, s.name);
      _father.text = s.guardianName;
      _fatherUrdu.text = urduName(s.fatherUrdu, s.guardianName);
      _mother.text = s.motherName;
      _motherUrdu.text = urduName(s.motherNameUrdu, s.motherName);
      _section.text = s.sectionName;
      _group.text = s.groupName;
      _bform.text = s.bForm;
      _contact.text = s.guardianPhone;
      _admStatus = s.admStatus;
      _classId = s.classId;
      _existingPhotoPath = s.photoPath;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AcademicsProvider>().loadClasses();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _nameUrdu.dispose();
    _father.dispose();
    _fatherUrdu.dispose();
    _mother.dispose();
    _motherUrdu.dispose();
    _section.dispose();
    _group.dispose();
    _bform.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 400,
        imageQuality: 80,
      );
      if (picked == null) return;
      setState(() => _pickedPhoto = picked);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  void _choosePhoto() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Stores the picked photo as photos/<admissionNo>.jpg in the app
  /// documents folder and returns its path. The photo is local-only:
  /// it never syncs to the server (the server stores only the path).
  Future<String?> _storePhoto(String admissionNo) async {
    if (_pickedPhoto == null) return _existingPhotoPath;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/photos');
    await dir.create(recursive: true);
    final target = '${dir.path}/$admissionNo.jpg';
    await File(_pickedPhoto!.path).copy(target);
    return target;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_classId == null) {
      showSnack(context, 'Please select a class.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final body = <String, dynamic>{
        'name': _name.text.trim(),
        'name_urdu': _nameUrdu.text.trim(),
        'guardian_name': _father.text.trim(),
        'father_urdu': _fatherUrdu.text.trim(),
        'mother_name': _mother.text.trim(),
        'mother_name_urdu': _motherUrdu.text.trim(),
        'group_name': _group.text.trim(),
        'adm_status': _admStatus,
        'class_id': _classId,
        'b_form': _bform.text.trim(),
        'guardian_phone': _contact.text.trim(),
        'guardian_relation': 'Father',
      };
      // The HTML's Section is a free-text field; the app keeps the
      // section as a name on the student record for display.
      if (_section.text.trim().isNotEmpty) {
        body['section_name'] = _section.text.trim();
      }
      final provider = context.read<StudentProvider>();
      if (_isEdit) {
        final s = widget.student!;
        final photoPath = await _storePhoto(s.admissionNo);
        if (photoPath != null) body['photo_path'] = photoPath;
        await provider.updateStudent(s.id, body);
        if (!mounted) return;
        showSnack(context, 'Student updated.');
      } else {
        final created = await provider.admit(body);
        final photoPath = await _storePhoto(created.admissionNo);
        if (photoPath != null) {
          await provider.updateStudent(created.id, {
            'photo_path': photoPath,
          });
        }
        if (!mounted) return;
        showSnack(context, 'Student admitted.');
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _photoPreview() {
    final Widget image;
    if (_pickedPhoto != null) {
      image = Image.file(
        File(_pickedPhoto!.path),
        width: 96,
        height: 120,
        fit: BoxFit.cover,
      );
    } else if (_existingPhotoPath != null &&
        _existingPhotoPath!.isNotEmpty &&
        File(_existingPhotoPath!).existsSync()) {
      image = Image.file(
        File(_existingPhotoPath!),
        width: 96,
        height: 120,
        fit: BoxFit.cover,
      );
    } else {
      image = Container(
        width: 96,
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.black26),
        ),
        child: const Icon(Icons.person, size: 48, color: Colors.black38),
      );
    }
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: image,
        ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          icon: const Icon(Icons.photo_camera, size: 16),
          label: const Text('Photo'),
          onPressed: _busy ? null : _choosePhoto,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final classes = context.watch<AcademicsProvider>().classes;

    return Scaffold(
      appBar: SchoolAppBar(
        title: _isEdit
            ? 'Edit Student — ${widget.student!.admissionNo}'
            : 'New Student',
      ),
      body: classes.isEmpty
          ? const LoadingView()
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _photoPreview(),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _name,
                                    decoration:
                                        fieldDecoration('Student name'),
                                    validator: (v) =>
                                        v == null || v.trim().isEmpty
                                            ? 'Required'
                                            : null,
                                    onChanged: (v) {
                                      if (!_nameUrduManual) {
                                        _nameUrdu.text = transliterate(v);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: _nameUrdu,
                                    decoration: fieldDecoration(
                                        'نام (اردو) — خود بھی بدل سکتے ہیں'),
                                    onChanged: (_) =>
                                        _nameUrduManual = true,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _father,
                                    decoration:
                                        fieldDecoration('Father name'),
                                    onChanged: (v) {
                                      if (!_fatherUrduManual) {
                                        _fatherUrdu.text = transliterate(v);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: _fatherUrdu,
                                    decoration: fieldDecoration(
                                        'والد کا نام (اردو) — خود بھی بدل سکتے ہیں'),
                                    onChanged: (_) =>
                                        _fatherUrduManual = true,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _mother,
                                    decoration:
                                        fieldDecoration('Mother name'),
                                    onChanged: (v) {
                                      if (!_motherUrduManual) {
                                        _motherUrdu.text = transliterate(v);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: _motherUrdu,
                                    decoration: fieldDecoration(
                                        'والدہ کا نام (اردو) — خود بھی بدل سکتے ہیں'),
                                    onChanged: (_) =>
                                        _motherUrduManual = true,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _section,
                          decoration:
                              fieldDecoration('Section (e.g. A)'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _group,
                          decoration:
                              fieldDecoration('Group (e.g. Science)'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _admStatus,
                          decoration: fieldDecoration('Admission'),
                          items: const ['New', 'Old']
                              .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                      s == 'New' ? 'New Admission' : 'Old Admission')))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _admStatus = v ?? 'New'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          value: _classId,
                          decoration: fieldDecoration('Class *'),
                          items: classes
                              .map((c) => DropdownMenuItem<int?>(
                                  value: c.id, child: Text(c.name)))
                              .toList(),
                          onChanged: (v) => setState(() {
                            _classId = v;
                          }),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _bform,
                          decoration: fieldDecoration(
                              'B-Form number (e.g. 35202-1234567-1)'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _contact,
                          decoration: fieldDecoration(
                              'Contact number (e.g. 0300-1234567)'),
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (!_isEdit)
                    FutureBuilder<String>(
                      future: context
                          .read<StudentProvider>()
                          .nextAdmissionNo(),
                      builder: (ctx, snap) => Text(
                        'Admission no: ${snap.data ?? '…'}',
                        style: const TextStyle(
                            fontSize: 13, color: Colors.black54),
                      ),
                    )
                  else
                    Text(
                      'Admission no: ${widget.student!.admissionNo}',
                      style: const TextStyle(
                          fontSize: 13, color: Colors.black54),
                    ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('Save Student'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              _busy ? null : () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
