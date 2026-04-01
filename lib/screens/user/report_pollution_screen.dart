import 'package:flutter/material.dart';
import 'package:priject_jalrakshak/screens/user/user_screen_welcome.dart';

/// Standalone screen: report pollution (own form state).
class ReportPollutionScreen extends StatefulWidget {
  const ReportPollutionScreen({super.key});

  @override
  State<ReportPollutionScreen> createState() => _ReportPollutionScreenState();
}

class _ReportPollutionScreenState extends State<ReportPollutionScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _waterBodyController = TextEditingController();
  final TextEditingController _issueController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  String _issueType = 'Sewage Discharge';

  @override
  void dispose() {
    _waterBodyController.dispose();
    _issueController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Report submitted. Our team will verify and follow up.',
        ),
        backgroundColor: Color(0xFF15803D),
      ),
    );
    _waterBodyController.clear();
    _issueController.clear();
    _locationController.clear();
    setState(() => _issueType = 'Sewage Discharge');
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
                          controller: _waterBodyController,
                          decoration: const InputDecoration(
                            labelText: 'Water body',
                            hintText: 'e.g. Yamuna — Wazirabad',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Enter water body name'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _issueType,
                          decoration:
                              const InputDecoration(labelText: 'Issue type'),
                          items: const [
                            DropdownMenuItem(
                              value: 'Sewage Discharge',
                              child: Text('Sewage discharge'),
                            ),
                            DropdownMenuItem(
                              value: 'Industrial Waste',
                              child: Text('Industrial waste'),
                            ),
                            DropdownMenuItem(
                              value: 'Plastic Dumping',
                              child: Text('Plastic dumping'),
                            ),
                            DropdownMenuItem(
                              value: 'Foam/Chemical Layer',
                              child: Text('Foam / chemical layer'),
                            ),
                            DropdownMenuItem(
                              value: 'Oil Spill',
                              child: Text('Oil spill'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _issueType = v);
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _issueController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'What did you see?',
                            hintText: 'Describe colour, smell, source if known',
                          ),
                          validator: (v) =>
                              (v == null || v.trim().length < 10)
                                  ? 'Add at least 10 characters'
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _locationController,
                          decoration: const InputDecoration(
                            labelText: 'Location (optional)',
                            hintText: 'Landmark, bridge, or GPS notes',
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0A3D62),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _submit,
                            icon: const Icon(Icons.send_outlined),
                            label: const Text('Submit report'),
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
