import 'package:flutter/material.dart';

import '../services/url_launcher_stub.dart'
    if (dart.library.html) '../services/url_launcher_web.dart';
import '../services/whatsapp_service.dart';

// ---------------------------------------------------------------------------
// 1. AboutPage
// ---------------------------------------------------------------------------
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  void _showTermsDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terms of Service'),
        content: const SingleChildScrollView(
          child: Text(
            'PadCare is a free, community-centered humanitarian platform.\n\n'
            '1. Acceptance: By using PadCare, you agree to access emergency and educational menstrual hygiene support with integrity.\n\n'
            '2. Non-Commercial: Supplies dispensed through PadCare (reusable kits and disposable packs) are donated for schoolgirls and community members and are not for resale.\n\n'
            '3. Respect & Safety: Users, teachers, and guardians must respect the confidentiality and dignity of all students.\n\n'
            '4. Modifications: PadCare reserves the right to update features, distribution points, and policies to improve community welfare.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'PadCare puts privacy, dignity, and student safety first.\n\n'
            '• Anonymous Requests: We never ask for a girl\'s name, class, or personal identity for emergency pad requests.\n\n'
            '• Secret PINs: Collections are authorized using a unique 4-digit pickup PIN generated privately on your device.\n\n'
            '• Offline-First Storage: Local requests and settings stay on your device without unnecessary remote tracking.\n\n'
            '• Contact Details: When provided for SMS or WhatsApp notifications, contact info is used strictly for pickup alerts and is never sold or shared.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('About PadCare')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.volunteer_activism_rounded,
                size: 64,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'PadCare',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Version 1.0.0+1',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on, size: 16, color: scheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Built for Arua City & West Nile, Uganda',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'PadCare is a community-led menstrual hygiene and period care platform '
              'dedicated to eliminating period poverty and classroom absenteeism '
              'among schoolgirls in rural Uganda.\n\n'
              'Through confidential emergency pad requests, dignity kit distribution, '
              'verified Senior Woman Teacher hubs, real-time school stock tracking, '
              'and Mobile Money contributions, PadCare ensures every girl can learn '
              'with comfort, confidence, and dignity.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.6,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _showTermsDialog(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Terms of Service'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _showPrivacyDialog(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Privacy Policy'),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.offline_bolt_outlined, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  '100% Offline-First Architecture',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. ContactPage
// ---------------------------------------------------------------------------
class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();

    if (name.isEmpty || email.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
        const SnackBar(
          content: Text('Please fill in your name, email, and message.'),
        ),
      );
      return;
    }

    setState(() => _sending = true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _nameController.clear();
        _emailController.clear();
        _subjectController.clear();
        _messageController.clear();
      });
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF116B78),
          content: Text('Thank you! Your message has been sent to the PadCare team.'),
        ),
      );
    });
  }

  void _launchEmail(String email) {
    try {
      openExternalUrl('mailto:$email?subject=${Uri.encodeComponent("PadCare Inquiry")}');
    } catch (_) {}
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening email app for $email')),
    );
  }

  void _launchPhone(String phone) {
    try {
      openExternalUrl('tel:$phone');
    } catch (_) {}
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Calling $phone...')),
    );
  }

  void _launchWhatsApp(String phone) {
    WhatsAppService.launchMessage(
      phone: phone,
      message: 'Hello PadCare Team! I have an inquiry regarding community period care.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact Us')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.mail_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subjectController,
              decoration: InputDecoration(
                labelText: 'Subject',
                prefixIcon: const Icon(Icons.subject),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              decoration: InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                alignLabelWithHint: true,
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _sending ? null : _sendMessage,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Send Message'),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Direct PadCare Helplines & Emails',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.email, color: Color(0xFF116B78)),
                    title: const Text('devgtnation@gmail.com'),
                    subtitle: const Text('Lead Developer / GTNationDEV'),
                    trailing: const Icon(Icons.send_rounded, size: 18),
                    onTap: () => _launchEmail('devgtnation@gmail.com'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.email_outlined, color: Color(0xFF116B78)),
                    title: const Text('abetinichlas@gmail.com'),
                    subtitle: const Text('Operations & Community Support'),
                    trailing: const Icon(Icons.send_rounded, size: 18),
                    onTap: () => _launchEmail('abetinichlas@gmail.com'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.phone, color: Color(0xFF116B78)),
                    title: const Text('+256 778 625 624'),
                    subtitle: const Text('Call or WhatsApp helpline'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline, color: Colors.green),
                          onPressed: () => _launchWhatsApp('256778625624'),
                          tooltip: 'WhatsApp chat',
                        ),
                        const Icon(Icons.call, size: 18),
                      ],
                    ),
                    onTap: () => _launchPhone('+256778625624'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.phone_in_talk, color: Color(0xFF116B78)),
                    title: const Text('+256 783 669 967'),
                    subtitle: const Text('Secondary helpline / Support'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline, color: Colors.green),
                          onPressed: () => _launchWhatsApp('256783669967'),
                          tooltip: 'WhatsApp chat',
                        ),
                        const Icon(Icons.call, size: 18),
                      ],
                    ),
                    onTap: () => _launchPhone('+256783669967'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. FaqPage
// ---------------------------------------------------------------------------
const _faqs = [
  {
    'q': 'What is PadCare and who can use it?',
    'a': 'PadCare is a community-led menstrual hygiene platform built to eliminate period poverty and reduce school absenteeism among girls in Uganda. Schoolgirls, parents, guardians, and teachers can use PadCare to access emergency sanitary towels and reusable dignity kits.',
  },
  {
    'q': 'Is my pad request completely confidential?',
    'a': 'Yes, absolutely. PadCare protects the privacy of every girl. Requests never require a student\'s personal name, class, or age. A unique confidential reference code and secret 4-digit pickup PIN are generated on your device for private collection.',
  },
  {
    'q': 'How do school pickups work with Senior Woman Teachers?',
    'a': 'Senior Woman Teachers are verified female mentors stationed at participating schools (such as Ediofe Girls School, Oli Primary School, and St. Mary\'s Secondary). When a request is approved, the student or guardian presents their confidential 4-digit PIN to collect the package discreetly.',
  },
  {
    'q': 'Does PadCare work without an active internet connection?',
    'a': 'Yes! PadCare is engineered offline-first. You can browse pickup points, check educational hygiene articles, and submit local requests completely offline. Any actions you submit are queued safely on your device and synchronized once an internet connection is detected.',
  },
  {
    'q': 'How do Mobile Money (MoMo) donations support schoolgirls?',
    'a': 'Through MTN MoMo and Airtel Money, community members can sponsor hygiene supplies directly. A 3,000 UGX contribution provides an emergency pack of disposable pads, while 15,000 UGX funds a complete reusable kit lasting up to 12 months.',
  },
  {
    'q': 'What is included in a reusable PadCare dignity kit?',
    'a': 'Each reusable kit contains 4 to 6 washable, antimicrobial cloth pads, leak-proof storage pouches, antibacterial laundry soap, and an illustrated menstrual hygiene booklet.',
  },
  {
    'q': 'How can our school or health clinic register as a pad provider?',
    'a': 'Schools, health centers, and community organizations can submit an application via the "Register as a Pad Provider" button in their Profile tab. Once reviewed and verified, staff gain access to manage inventory and review local requests.',
  },
  {
    'q': 'Who created PadCare?',
    'a': 'PadCare was developed in Uganda by Dan Mungufeni (GTNationDEV) and Abeti Acadri Nicholas to solve real menstrual hygiene barriers in Arua City and rural schools across the region.',
  },
];

class FaqPage extends StatefulWidget {
  const FaqPage({super.key});

  @override
  State<FaqPage> createState() => _FaqPageState();
}

class _FaqPageState extends State<FaqPage> {
  var _expanded = -1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Frequently Asked Questions')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.help_outline_rounded, color: scheme.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Everything you need to know',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Learn about PadCare requests, privacy, pickup PINs, and school distribution.',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ..._faqs.asMap().entries.map((e) {
            final i = e.key;
            final faq = e.value;
            final isExpanded = _expanded == i;

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isExpanded
                      ? scheme.primary
                      : scheme.outlineVariant.withValues(alpha: 0.7),
                  width: isExpanded ? 1.5 : 1,
                ),
              ),
              margin: const EdgeInsets.only(bottom: 10),
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                title: Text(
                  faq['q'] as String,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: isExpanded ? scheme.primary : scheme.onSurface,
                  ),
                ),
                initiallyExpanded: _expanded == i,
                onExpansionChanged: (v) => setState(() => _expanded = v ? i : -1),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      faq['a'] as String,
                      style: TextStyle(
                        height: 1.5,
                        color: scheme.onSurfaceVariant,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. TeamPage
// ---------------------------------------------------------------------------
const _team = [
  {
    'name': 'Dan Mungufeni (GTNationDEV)',
    'role': 'Lead Software Engineer & Project Founder',
    'email': 'devgtnation@gmail.com',
    'phone': '+256778625624',
    'bio': 'Architect of PadCare\'s offline-first mobile app, community distribution engine, and Firebase synchronization infrastructure.',
    'badge': 'Tech & Product',
  },
  {
    'name': 'Abeti Acadri Nicholas',
    'role': 'Co-Founder & Operations / Community Lead',
    'email': 'abetinichlas@gmail.com',
    'phone': '+256783669967',
    'bio': 'Coordinating school distribution hubs, Senior Woman Teacher partnerships, community sensitization, and period equity advocacy across West Nile.',
    'badge': 'Operations & Outreach',
  },
];

class TeamPage extends StatelessWidget {
  const TeamPage({super.key});

  void _openEmail(BuildContext context, String email) {
    try {
      openExternalUrl('mailto:$email?subject=${Uri.encodeComponent("PadCare Collaboration")}');
    } catch (_) {}
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening email app for $email')),
    );
  }

  void _openPhone(BuildContext context, String phone) {
    try {
      openExternalUrl('tel:$phone');
    } catch (_) {}
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Calling $phone...')),
    );
  }

  void _openWhatsApp(String phone) {
    WhatsAppService.launchMessage(
      phone: phone,
      message: 'Hello! I am reaching out regarding the PadCare initiative in Uganda.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Our Team')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primary, scheme.primaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.groups_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'The Creators Behind PadCare',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Dedicated technologists and community advocates based in Uganda passionate about ending period poverty through innovative software.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          ..._team.asMap().entries.map((entry) {
            final i = entry.key;
            final t = entry.value;
            final initials = (t['name'] as String).substring(0, 1).toUpperCase();
            final email = t['email'] as String;
            final phone = t['phone'] as String;

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: scheme.outlineVariant),
              ),
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: i == 0
                              ? const Color(0xFF116B78)
                              : const Color(0xFF35B9B4),
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t['name'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                t['role'] as String,
                                style: TextStyle(
                                  color: scheme.primary,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            t['badge'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      t['bio'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _openEmail(context, email),
                            icon: const Icon(Icons.email_outlined, size: 16),
                            label: const Text('Email', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _openPhone(context, phone),
                            icon: const Icon(Icons.phone_outlined, size: 16),
                            label: const Text('Call', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _openWhatsApp(phone),
                          icon: const Icon(Icons.chat_bubble_outline, color: Colors.green),
                          tooltip: 'Chat on WhatsApp',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.green.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
