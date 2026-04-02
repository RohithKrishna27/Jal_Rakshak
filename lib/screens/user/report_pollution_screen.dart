import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:priject_jalrakshak/screens/user/user_screen_welcome.dart';
import 'package:priject_jalrakshak/services/pollution_report_service.dart';

/// Normal user: photo + suspected company, address, waste type, description → Firestore + Storage.
class ReportPollutionScreen extends StatefulWidget {
  const ReportPollutionScreen({super.key});

  @override
  State<ReportPollutionScreen> createState() => _ReportPollutionScreenState();
}

class _ReportPollutionScreenState extends State<ReportPollutionScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _waterBodyController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationNotesController = TextEditingController();

  String _wasteType = 'Industrial effluent / chemical';
  XFile? _pickedImage;
  Uint8List? _previewBytes;
  bool _submitting = false;

  static const _wasteTypes = [
    'Industrial effluent / chemical',
    'Sewage / domestic waste',
    'Plastic & solid waste',
    'Foam / oil / grease on water',
    'Fly ash / construction debris',
    'Dead fish / biological stress',
    'Other',
  ];

  @override
  void dispose() {
    _companyController.dispose();
    _addressController.dispose();
    _waterBodyController.dispose();
    _descriptionController.dispose();
    _locationNotesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 82,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() {
      _pickedImage = x;
      _previewBytes = bytes;
    });
  }

  void _clearPhoto() {
    setState(() {
      _pickedImage = null;
      _previewBytes = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickedImage == null || _previewBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a photo of the pollution.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await PollutionReportService.submit(
        imageBytes: _previewBytes,
        suspectedCompanyName: _companyController.text,
        companyAddress: _addressController.text,
        wasteType: _wasteType,
        description: _descriptionController.text,
        waterBody: _waterBodyController.text,
        locationNotes: _locationNotesController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Report submitted. Industries can view it under Complaints with your details.',
          ),
          backgroundColor: Color(0xFF15803D),
        ),
      );
      _companyController.clear();
      _addressController.clear();
      _waterBodyController.clear();
      _descriptionController.clear();
      _locationNotesController.clear();
      _clearPhoto();
      setState(() => _wasteType = _wasteTypes.first);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFD),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A3D62),
        title: const Text('Report Pollution'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const UserScreenWelcome(
              icon: Icons.report_problem_outlined,
              title: 'Report what you see',
              subtitle:
                  'Photo + suspected company, address, waste type and description are shared with the industry portal for follow-up.',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Photo of pollution',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Required — helps verify the incident.',
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                        const SizedBox(height: 12),
                        if (_previewBytes != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              _previewBytes!,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Container(
                            height: 160,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade400),
                            ),
                            child: const Icon(Icons.add_a_photo_outlined,
                                size: 48, color: Colors.grey),
                          ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final narrow = constraints.maxWidth < 340;
                            final cam = OutlinedButton.icon(
                              onPressed: _submitting
                                  ? null
                                  : () => _pickImage(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt_outlined, size: 20),
                              label: const Text('Camera'),
                            );
                            final gal = OutlinedButton.icon(
                              onPressed: _submitting
                                  ? null
                                  : () => _pickImage(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library_outlined, size: 20),
                              label: const Text('Gallery'),
                            );
                            if (narrow) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  cam,
                                  const SizedBox(height: 10),
                                  gal,
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: cam),
                                const SizedBox(width: 10),
                                Expanded(child: gal),
                              ],
                            );
                          },
                        ),
                        if (_previewBytes != null)
                          TextButton.icon(
                            onPressed: _submitting ? null : _clearPhoto,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Remove photo'),
                          ),
                        const Divider(height: 32),
                        const Text(
                          'Company & location',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _companyController,
                          decoration: const InputDecoration(
                            labelText: 'Suspected company / industry name',
                            hintText: 'As on signboard or known locally',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().length < 2)
                              ? 'Enter the company or site name'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _addressController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Company or site address',
                            hintText: 'Area, district, pincode if known',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().length < 5)
                              ? 'Enter a clearer address (min 5 characters)'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _waterBodyController,
                          decoration: const InputDecoration(
                            labelText: 'Water body affected',
                            hintText: 'e.g. Yamuna — Wazirabad stretch',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Enter the river / drain / lake name'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Type of waste / pollution',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _wasteType,
                          decoration: const InputDecoration(
                            labelText: 'Waste / pollution type',
                            border: OutlineInputBorder(),
                          ),
                          items: _wasteTypes
                              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                              .toList(),
                          onChanged: _submitting
                              ? null
                              : (v) {
                                  if (v != null) setState(() => _wasteType = v);
                                },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            hintText:
                                'Colour, smell, time of day, how often you see it, any pipes or drains',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().length < 15)
                                  ? 'Add at least 15 characters'
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _locationNotesController,
                          decoration: const InputDecoration(
                            labelText: 'Extra location notes (optional)',
                            hintText: 'Landmark, bridge, GPS from maps app',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0A3D62),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _submitting ? null : _submit,
                            icon: _submitting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_outlined),
                            label: Text(_submitting ? 'Uploading…' : 'Submit report'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
