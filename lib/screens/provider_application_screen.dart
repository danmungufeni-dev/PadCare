import 'package:flutter/material.dart';

import '../services/padcare_backend.dart';

class ProviderApplicationScreen extends StatefulWidget {
  const ProviderApplicationScreen({super.key});

  @override
  State<ProviderApplicationScreen> createState() => _ProviderApplicationScreenState();
}

class _ProviderApplicationScreenState extends State<ProviderApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _organisation = TextEditingController();
  final _facility = TextEditingController();
  final _area = TextEditingController();
  final _address = TextEditingController();
  final _description = TextEditingController();
  final _instructions = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _submittedId;

  @override
  void dispose() {
    _organisation.dispose();
    _facility.dispose();
    _area.dispose();
    _address.dispose();
    _description.dispose();
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    if (!PadCareBackend.isConfigured || !PadCareBackend.isSignedIn) {
      setState(() => _error =
          'Sign in with an online PadCare account first. Firebase must be configured to send an application for review.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await PadCareBackend.submitProviderApplication(
        organisationName: _organisation.text,
        facilityName: _facility.text,
        area: _area.text,
        address: _address.text,
        description: _description.text,
        pickupInstructions: _instructions.text,
      );
      if (mounted) setState(() => _submittedId = id);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'We could not submit this application. Check your connection, account email, and Firebase rules, then try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    int maxLength = 240,
    bool required = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: label, alignLabelWithHint: maxLines > 1),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (required && text.isEmpty) return 'Please enter $label.';
          if (text.length > maxLength) return 'Please shorten this field.';
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = PadCareBackend.isConfigured && PadCareBackend.isSignedIn;
    return Scaffold(
      appBar: AppBar(title: const Text('List a pickup location')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFE4F8F2),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.volunteer_activism_rounded, size: 30, color: Color(0xFF116B78)),
                  SizedBox(height: 10),
                  Text('Help make pads easier to find',
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                  SizedBox(height: 8),
                  Text(
                    'Schools, community organisations, clinics, and other supporters can apply to list a collection point. An application is private until a trusted PadCare administrator reviews it.',
                    style: TextStyle(height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!signedIn)
              const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: Text(
                  'You are in local preview mode. Sign in with a configured online account before submitting.',
                  style: TextStyle(color: Color(0xFF637A83), height: 1.45),
                ),
              ),
            if (_submittedId != null) ...[
              const Icon(Icons.check_circle_outline_rounded, size: 44, color: Color(0xFF16845B)),
              const SizedBox(height: 10),
              const Text('Application submitted for review',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text(
                'Your location is not public or verified yet. A trusted administrator must review and provision the listing.',
                style: TextStyle(height: 1.5),
              ),
              const SizedBox(height: 8),
              SelectableText('Application reference: $_submittedId'),
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ] else ...[
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _field(_organisation, 'Organisation name', maxLength: 120),
                    _field(_facility, 'Pickup location name', maxLength: 120),
                    _field(_area, 'Area or town', maxLength: 100),
                    _field(_address, 'Address or directions', maxLength: 240),
                    _field(_description, 'What support is available?', maxLines: 3, maxLength: 1000),
                    _field(_instructions, 'Collection instructions (optional)',
                        maxLines: 3, maxLength: 500, required: false),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(_error!, style: const TextStyle(color: Colors.redAccent, height: 1.4)),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded),
                label: Text(_busy ? 'Submitting…' : 'Submit for review'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF116B78),
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Submitting does not create a public listing, verify stock, or grant staff access. Do not include sensitive information about the people who collect supplies.',
                style: TextStyle(color: Color(0xFF637A83), fontSize: 12, height: 1.45),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
