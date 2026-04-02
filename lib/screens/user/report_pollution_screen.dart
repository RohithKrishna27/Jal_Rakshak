import 'package:flutter/material.dart';
import 'package:priject_jalrakshak/screens/user/user_screen_welcome.dart';
import 'package:priject_jalrakshak/services/pollution_report_service.dart';

/// Normal user: company name, location, water body, issue type, description → Firestore.
class ReportPollutionScreen extends StatefulWidget {
  const ReportPollutionScreen({super.key});

  @override
  State<ReportPollutionScreen> createState() => _ReportPollutionScreenState();
}

class _ReportPollutionScreenState extends State<ReportPollutionScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _waterBodyController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  String _wasteType = 'Sewage discharge';
  bool _submitting = false;

  static const _wasteTypes = [
    'Sewage discharge',
    'Industrial effluent / chemical',
    'Plastic & solid waste',
    'Foam / oil / grease on water',
    'Fly ash / construction debris',
    'Dead fish / biological stress',
    'Other',
  ];

  @override
  void dispose() {
    _companyController.dispose();
    _waterBodyController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      await PollutionReportService.submit(
        suspectedCompanyName: _companyController.text,
        companyAddress: _locationController.text,
        wasteType: _wasteType,
        description: _descriptionController.text,
        waterBody: _waterBodyController.text,
        locationNotes: '',
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
      _waterBodyController.clear();
      _descriptionController.clear();
      _locationController.clear();
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
              title: 'Welcome — speak up for clean water',
              subtitle:
                  'Your report helps authorities and communities act faster. Add clear details and location hints.',
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
                          'Incident details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _companyController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Company name',
                            hintText: 'Suspected industry or site name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().length < 2)
                              ? 'Enter the company or site name'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _waterBodyController,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Water body',
                            hintText: 'River, drain, lake, or stretch',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Enter the water body'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _wasteType,
                          decoration: const InputDecoration(
                            labelText: 'Issue type',
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
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 5,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            hintText: 'What did you see?',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().length < 15)
                                  ? 'Add at least 15 characters'
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _locationController,
                          maxLines: 2,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Location (optional)',
                            hintText: 'Area, landmark, or address',
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
                            label: Text(_submitting ? 'Submitting…' : 'Submit report'),
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
