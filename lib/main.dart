import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'screens/online_account_screen.dart';
import 'services/padcare_backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PadCareBackend.initialize();
  runApp(const MyApp());
}

const _ink = Color(0xFF142426);
const _muted = Color(0xFF637A83);
const _paper = Color(0xFFE4F8F2);
const _green = Color(0xFF35B9B4);
const _greenPale = Color(0xFFE4F8F2);
const _coral = Color(0xFF116B78);
const _line = Color(0xFFDCECEB);

Widget _softTransition({required Key key, required Widget child}) {
  return AnimatedSwitcher(
    duration: const Duration(milliseconds: 240),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.025),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    ),
    child: KeyedSubtree(key: key, child: child),
  );
}

class MyApp extends StatelessWidget {
  final Widget? home;
  const MyApp({super.key, this.home});

  static bool get isTestMode =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PadCare',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _paper,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _green,
          brightness: Brightness.light,
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _paper,
          foregroundColor: _ink,
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _line),
          ),
        ),
      ),
      home: home ?? (isTestMode ? const AccessGate() : const _AppLandingFlow()),
    );
  }
}

class _AppLandingFlow extends StatefulWidget {
  const _AppLandingFlow();

  @override
  State<_AppLandingFlow> createState() => _AppLandingFlowState();
}

class _AppLandingFlowState extends State<_AppLandingFlow> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() => _showSplash = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return _PadCareSplashScreen(
        onClose: () => setState(() => _showSplash = false),
      );
    }
    return ParentHomeScreen(
      parentName: 'Guest',
      onSignOut: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AccessGate()),
        );
      },
    );
  }
}

enum _PortalRole { teacher, parent }

class AccessGate extends StatefulWidget {
  const AccessGate({super.key});

  @override
  State<AccessGate> createState() => _AccessGateState();
}

class _AccessGateState extends State<AccessGate> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _newSchoolController = TextEditingController();
  final List<String> _schoolOptions = [..._staffFacilities];

  _PortalRole? _role;
  bool _registering = false;
  bool _addingSchool = false;
  String _school = 'St. Mary\'s Secondary';

  @override
  void dispose() {
    _nameController.dispose();
    _newSchoolController.dispose();
    super.dispose();
  }

  void _saveSchool() {
    final school = _newSchoolController.text.trim();
    if (school.isEmpty) return;
    setState(() {
      if (!_schoolOptions.contains(school)) _schoolOptions.add(school);
      _school = school;
      _addingSchool = false;
      _newSchoolController.clear();
    });
  }

  void _openPortal() {
    if (!_formKey.currentState!.validate()) return;

    final navigator = Navigator.of(context);
    void onSignOut() {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const AccessGate()),
        (route) => false,
      );
    }

    if (_role == _PortalRole.teacher) {
      navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => HomeScreen(facility: _school, onSignOut: onSignOut),
        ),
      );
    } else {
      navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ParentHomeScreen(
            parentName: _nameController.text.trim().isEmpty
                ? 'Parent account'
                : _nameController.text.trim(),
            onSignOut: onSignOut,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _PageScroll(
          children: [
            const SizedBox(height: 26),
            const _BrandLockup(),
            const SizedBox(height: 34),
            _softTransition(
              key: ValueKey('access-${_role?.name ?? 'roles'}'),
              child: _role == null ? _buildRolePicker() : _buildAccessForm(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openOnlineAccount() async {
    final connected = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const OnlineAccountScreen()),
    );
    if (!mounted || connected != true) return;
    final navigator = Navigator.of(context);
    Map<String, dynamic> profile;
    try {
      profile = await PadCareBackend.loadCurrentProfile();
    } catch (_) {
      // If profile lookup is temporarily unavailable, route to the least-privileged parent view.
      profile = <String, dynamic>{'role': 'parent'};
    }
    if (!mounted) return;
    final role = profile['role']?.toString() ?? 'parent';
    void signOut() {
      PadCareBackend.signOut();
      navigator.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const AccessGate()),
        (route) => false,
      );
    }
    final Widget destination = role == 'schoolStaff'
        ? HomeScreen(
            facility: (profile['facilityName'] ?? profile['facilityId'] ?? 'School').toString(),
            onSignOut: signOut,
          )
        : ParentHomeScreen(
            parentName: PadCareBackend.currentDisplayName,
            onSignOut: signOut,
          );
    navigator.pushReplacement(MaterialPageRoute<void>(builder: (_) => destination));
  }

  Widget _buildRolePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Text(
                'Choose your PadCare access',
                style: TextStyle(
                  color: _ink,
                  fontSize: 25,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => ParentHomeScreen(
                      parentName: 'Guest',
                      onSignOut: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(builder: (_) => const AccessGate()),
                      ),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('Skip to App'),
              style: TextButton.styleFrom(foregroundColor: _green),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Explore PadCare as a school staff member or as a parent or guardian.',
          style: TextStyle(color: _muted, height: 1.5),
        ),
        const SizedBox(height: 24),
        _RoleCard(
          icon: Icons.school_outlined,
          title: 'Senior woman teacher',
          subtitle: 'Preview school stock and review local requests',
          onTap: () => setState(() => _role = _PortalRole.teacher),
        ),
        const SizedBox(height: 12),
        _RoleCard(
          icon: Icons.family_restroom_rounded,
          title: 'Parent or guardian',
          subtitle: 'Submit a local request and choose a school pickup point',
          onTap: () => setState(() => _role = _PortalRole.parent),
        ),
        const SizedBox(height: 22),
        const _PrivacyNote(
          text: 'Requests do not ask for a girl\'s name, age, or class.',
        ),
        const SizedBox(height: 12),
        Center(
          child: FilledButton.tonalIcon(
            onPressed: _openOnlineAccount,
            icon: const Icon(Icons.cloud_outlined),
            label: const Text('Sign in or create online account'),
            style: FilledButton.styleFrom(
              foregroundColor: const Color(0xFF116B78),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => ParentHomeScreen(
                    parentName: 'Guest',
                    onSignOut: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(builder: (_) => const AccessGate()),
                    ),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.home_outlined),
            label: const Text('Enter PadCare Directly'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _green,
              side: const BorderSide(color: _green),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccessForm() {
    final isTeacher = _role == _PortalRole.teacher;
    final roleLabel = isTeacher ? 'teacher' : 'parent';
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => setState(() {
              _role = null;
              _registering = false;
            }),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Choose another access'),
            style: TextButton.styleFrom(foregroundColor: _green),
          ),
          const SizedBox(height: 12),
          Text(
            '${isTeacher ? 'Teacher' : 'Parent'} preview${_registering ? ' setup' : ''}',
            style: const TextStyle(
              color: _ink,
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isTeacher
              ? 'Preview only. Choose a sample school or distribution point.'
              : 'Preview only. Requests stay on this device and are not sent to a school.',
            style: const TextStyle(color: _muted, height: 1.45),
          ),
          const SizedBox(height: 22),
          if (_registering) ...[
            TextFormField(
              key: const ValueKey('account-name'),
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(
                labelText: 'Display name (optional)',
                hintText: 'Used for this preview only',
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (isTeacher) ...[
            if (!_addingSchool)
              DropdownButtonFormField<String>(
                key: const ValueKey('teacher-school-dropdown'),
                initialValue: _school,
                decoration: const InputDecoration(
                  labelText: 'School or distribution point',
                ),
                items: _schoolOptions
                    .map(
                      (facility) => DropdownMenuItem(
                        value: facility,
                        child: Text(facility),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  if (value != null) _school = value;
                }),
              ),
            if (_registering) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      setState(() => _addingSchool = !_addingSchool),
                  icon: Icon(
                    _addingSchool ? Icons.close_rounded : Icons.add_rounded,
                  ),
                  label: Text(
                    _addingSchool ? 'Cancel school entry' : 'Add a school',
                  ),
                ),
              ),
              if (_addingSchool) ...[
                TextFormField(
                  key: const ValueKey('new-school-name'),
                  controller: _newSchoolController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'School name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a school name or cancel to select an existing school'
                      : null,
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey('save-school'),
                    onPressed: _saveSchool,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Use this school'),
                  ),
                ),
                const Text(
                  'This school is added to this preview session only.',
                  style: TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ],
            const SizedBox(height: 16),
          ],
          if (!isTeacher && !_registering) const SizedBox(height: 10),
          FilledButton(
            key: const ValueKey('submit-access'),
            onPressed: _openPortal,
            style: _primaryButtonStyle,
            child: Text(
                'Open $roleLabel preview',
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _registering = !_registering),
              child: Text(
                _registering ? 'Back to preview' : 'Set a display name',
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'No account is created. Preview data is not shared with a school.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

const _staffFacilities = [
  'St. Mary\'s Secondary',
  'Oli Primary School',
  'Ediofe Girls School',
];

const _pickupSchoolsByArea = <String, String>{
  'Oli': 'Oli Primary School',
  'Ediofe': 'Ediofe Girls School',
  'Arua Hill': 'St. Mary\'s Secondary',
};

class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _BrandMark(),
        SizedBox(width: 10),
        Text(
          'PadCare',
          style: TextStyle(
            color: _ink,
            fontSize: 23,
            fontWeight: FontWeight.w800,
          ),
        ),
        Spacer(),
        Text(
          'ARUA CITY',
          style: TextStyle(
            color: _muted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('padcare-logo'),
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CustomPaint(
          painter: const _PadCareLogoPainter(),
          child: Image.asset('assets/icon/app_icon.png', fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class _PadCareLogoPainter extends CustomPainter {
  const _PadCareLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);

    final padPaint = Paint()..color = Colors.white;
    final wingPath = Path()
      ..moveTo(8.5, 8)
      ..lineTo(3.1, 6.1)
      ..quadraticBezierTo(1.9, 5.7, 2.3, 7.1)
      ..lineTo(4.5, 13.7)
      ..quadraticBezierTo(4.8, 14.6, 5.8, 14.2)
      ..lineTo(9, 12.8)
      ..close();
    canvas.drawPath(wingPath, padPaint);
    canvas.save();
    canvas.scale(-1, 1);
    canvas.translate(-24, 0);
    canvas.drawPath(wingPath, padPaint);
    canvas.restore();

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(8, 2.5, 8, 19),
        const Radius.circular(4),
      ),
      padPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(10.2, 4.2, 3.6, 15.5),
        const Radius.circular(1.8),
      ),
      Paint()..color = const Color(0xFFFFD9D0),
    );

    final dropPath = Path()
      ..moveTo(12, 8.1)
      ..cubicTo(10.6, 10, 9.4, 11.5, 9.4, 13.2)
      ..cubicTo(9.4, 14.9, 10.5, 16.1, 12, 16.1)
      ..cubicTo(13.5, 16.1, 14.6, 14.9, 14.6, 13.2)
      ..cubicTo(14.6, 11.5, 13.4, 10, 12, 8.1)
      ..close();
    canvas.drawPath(dropPath, Paint()..color = _coral);
    canvas.drawCircle(
      const Offset(10.9, 12.5),
      0.65,
      Paint()..color = const Color(0xFFFFB6A7),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PadCareLogoPainter oldDelegate) => false;
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _greenPale,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: _green, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: _green, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: _line),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _greenPale,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _green),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _muted),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.facility = 'St. Mary\'s Secondary',
    this.onSignOut,
  });

  final String facility;
  final VoidCallback? onSignOut;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final List<_Supply> _supplies = [
    _Supply(name: 'Reusable pads', onHand: 42, lowAt: 20, unit: 'kits'),
    _Supply(name: 'Disposable pads', onHand: 12, lowAt: 25, unit: 'packs'),
    _Supply(name: 'Soap', onHand: 31, lowAt: 15, unit: 'bars'),
  ];

  List<_LocalRequest> _requests = [];
  bool _loadingLocalData = true;
  bool _localDataFailed = false;

  @override
  void initState() {
    super.initState();
    _loadSchoolData();
  }

  List<_LocalRequest> get _facilityRequests => _requests
      .where((request) => request.school == widget.facility)
      .toList();

  int _reservedFor(String product, {List<_LocalRequest>? requests}) =>
      (requests ?? _requests)
          .where(
            (request) =>
                request.school == widget.facility &&
                request.product == product &&
                (request.status == 'Approved' ||
                    request.status == 'Ready for pickup'),
          )
          .fold(0, (total, request) => total + request.quantity);

  Future<void> _loadSchoolData() async {
    try {
      final data = await _readLocalData();
      var requests = data.requests;
      var remoteInventory = <String, Map<String, int>>{};
      if (PadCareBackend.isSignedIn) {
        try {
          final profile = await PadCareBackend.loadCurrentProfile();
          if (profile['role'] == 'schoolStaff' && profile['facilityId'] is String) {
            remoteInventory = await PadCareBackend.loadInventory(profile['facilityId'] as String);
            final remote = await PadCareBackend.loadFacilityRequests(profile['facilityId'] as String);
            final byId = <String, _LocalRequest>{
              for (final request in requests) request.id: request,
            };
            for (final record in remote) {
              try {
                final request = _LocalRequest.fromJson(Map<String, dynamic>.from(record));
                byId[request.id] = request;
              } catch (_) {}
            }
            requests = byId.values.toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          }
        } catch (_) {
          // Staff can still review local preview data if the network is unavailable.
        }
      }
      if (!mounted) return;
      setState(() {
        _requests = requests;
        for (final supply in _supplies) {
          final liveStock = remoteInventory[supply.name];
          supply.onHand = liveStock?['onHand'] ??
              data.stock[_stockKey(widget.facility, supply.name)] ??
              supply.onHand;
          supply.reserved = liveStock?['reserved'] ?? _reservedFor(supply.name);
        }
        _loadingLocalData = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _localDataFailed = true;
        _loadingLocalData = false;
      });
    }
  }

  int get _lowStockCount =>
        _supplies
          .where((supply) => supply.onHand - supply.reserved <= supply.lowAt)
          .length;

  Future<void> _changeStock(_Supply supply, int delta) async {
    await _setStock(supply, (supply.onHand + delta).clamp(0, 9999));
  }

  Future<void> _setStock(_Supply supply, int quantity) async {
    if (quantity < 0 || quantity > 9999) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a stock quantity from 0 to 9999.')),
      );
      return;
    }
    if (quantity < supply.reserved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stock cannot be lower than reserved requests.')),
      );
      return;
    }
    try {
      final data = await _readLocalData();
      final stock = Map<String, int>.from(data.stock)
        ..[_stockKey(widget.facility, supply.name)] = quantity;
      await _saveLocalData(_LocalData(requests: data.requests, stock: stock));
      var syncFailed = false;
      if (PadCareBackend.isSignedIn) {
        try {
          final profile = await PadCareBackend.loadCurrentProfile();
          if (profile['role'] == 'schoolStaff' && profile['facilityId'] is String) {
            await PadCareBackend.updateInventory(
              facilityId: profile['facilityId'] as String,
              product: supply.name,
              onHand: quantity,
              reserved: supply.reserved,
            );
          }
        } catch (_) {
          syncFailed = true;
        }
      }
      if (!mounted) return;
      setState(() => supply.onHand = quantity);
      if (syncFailed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock saved locally, but online sync failed.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the stock update.')),
      );
    }
  }

  Future<void> _setRequestStatus(
    _LocalRequest request,
    String status,
  ) async {
    final supply = _supplies.firstWhere(
      (item) => item.name == request.product,
      orElse: () => _Supply(
        name: request.product,
        onHand: 0,
        lowAt: 0,
        unit: 'units',
      ),
    );
    final reserved = _reservedFor(request.product);
    if (status == 'Approved' && supply.onHand - reserved < request.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough available stock to approve this request.')),
      );
      return;
    }
    if (status == 'Collected' && supply.onHand < request.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('There is not enough stock to complete this collection.')),
      );
      return;
    }

    try {
      final data = await _readLocalData();
      final updatedRequests = data.requests
          .map((item) => item.id == request.id ? item.withStatus(status) : item)
          .toList();
      final stock = Map<String, int>.from(data.stock);
      if (status == 'Collected') {
        stock[_stockKey(widget.facility, supply.name)] =
            supply.onHand - request.quantity;
      }
      await _saveLocalData(
        _LocalData(requests: updatedRequests, stock: stock),
      );
      var syncFailed = false;
      if (PadCareBackend.isSignedIn) {
        try {
          final profile = await PadCareBackend.loadCurrentProfile();
          if (profile['role'] == 'schoolStaff' && profile['facilityId'] is String) {
            await PadCareBackend.updatePickupRequestStatus(id: request.id, status: status);
            await PadCareBackend.updateInventory(
              facilityId: profile['facilityId'] as String,
              product: supply.name,
              onHand: status == 'Collected'
                  ? supply.onHand - request.quantity
                  : supply.onHand,
              reserved: _reservedFor(supply.name, requests: updatedRequests),
            );
          }
        } catch (_) {
          syncFailed = true;
        }
      }
      if (!mounted) return;
      setState(() {
        _requests = updatedRequests;
        if (status == 'Collected') supply.onHand -= request.quantity;
        for (final item in _supplies) {
          item.reserved = _reservedFor(item.name, requests: updatedRequests);
        }
      });
      if (syncFailed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request status saved locally, but online sync failed.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update this request.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildOverview(),
      _buildRequests(),
      _buildStock(),
      _buildInsights(),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              initials: 'SM',
              onNotificationTap: () => setState(() => _selectedIndex = 1),
              onSignOut: widget.onSignOut,
            ),
            Expanded(
              child: _softTransition(
                key: ValueKey('staff-page-$_selectedIndex'),
                child: pages[_selectedIndex],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        backgroundColor: Colors.white,
        indicatorColor: _greenPale,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment_rounded),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: 'Stock',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Insights',
          ),
        ],
      ),
    );
  }

  Widget _buildOverview() {
    return _PageScroll(
      children: [
        _FacilityHeader(
          eyebrow: 'STAFF DASHBOARD',
          title: widget.facility,
          subtitle: 'Arua City  ·  Teacher preview',
        ),
        const SizedBox(height: 12),
        _PrivacyNote(
          text: PadCareBackend.isSignedIn
              ? 'Online account detected. Staff changes sync only when your role, Firebase rules, and connection allow them; watch for sync warnings.'
              : 'Preview only: staff identity is not verified, and requests and stock are stored on this device.',
        ),
        const SizedBox(height: 20),
        _ImpactStrip(
          requests: _facilityRequests.length,
          lowStock: _lowStockCount,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(child: _SectionTitle('Stock at this point')),
            TextButton(
              onPressed: () => setState(() => _selectedIndex = 2),
              child: const Text('Manage stock'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ..._supplies.map((supply) => _StockSummaryRow(supply: supply)),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(child: _SectionTitle('Recent requests')),
            TextButton(
              onPressed: () => setState(() => _selectedIndex = 1),
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ..._facilityRequests
          .take(2)
          .map((request) => _RequestRow(request: request)),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: () => setState(() => _selectedIndex = 1),
          icon: const Icon(Icons.assignment_outlined),
          label: const Text('Review school requests'),
          style: _primaryButtonStyle,
        ),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'No personal information about girls is stored.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildRequests() {
    final requests = _facilityRequests;
    return _PageScroll(
      children: [
        _FacilityHeader(
          eyebrow: 'SCHOOL REQUESTS',
          title: 'Review requests',
          subtitle: widget.facility,
        ),
        const SizedBox(height: 18),
        _PrivacyNote(
          text: PadCareBackend.isSignedIn
              ? 'Online staff account detected. Remote requests are loaded from the assigned facility when available; local preview data may still appear offline.'
              : 'Preview only: staff identity is not verified. This inbox is only visible on this device.',
        ),
        const SizedBox(height: 14),
        if (_loadingLocalData)
          const Center(child: CircularProgressIndicator())
        else if (_localDataFailed)
          const _PrivacyNote(
            text: 'School requests could not be loaded from this device.',
          )
        else if (requests.isEmpty)
          const _PrivacyNote(
            text: 'No requests are saved for this school on this device.',
          )
        else
          ...requests.map(
            (request) => _TeacherRequestCard(
              request: request,
              available: _supplies
                      .where((supply) => supply.name == request.product)
                      .map((supply) => supply.onHand - supply.reserved)
                      .firstOrNull ??
                  0,
              onApprove: () => _setRequestStatus(request, 'Approved'),
              onDecline: () => _setRequestStatus(request, 'Declined'),
              onReady: () => _setRequestStatus(request, 'Ready for pickup'),
              onCollect: () => _setRequestStatus(request, 'Collected'),
            ),
          ),
      ],
    );
  }

  Widget _buildStock() {
    return _PageScroll(
      children: [
        _FacilityHeader(
          eyebrow: 'INVENTORY',
          title: 'Stock levels',
          subtitle: '${widget.facility}  ·  Sample starting stock',
        ),
        const SizedBox(height: 12),
        _PrivacyNote(
          text: PadCareBackend.isSignedIn
              ? 'Online staff account detected. Inventory sync depends on your assigned facility, Firebase permissions, and connectivity.'
              : 'Preview only: staff identity is not verified. Stock changes are stored on this device.',
        ),
        const SizedBox(height: 18),
        if (_loadingLocalData)
          const Center(child: CircularProgressIndicator())
        else if (_localDataFailed)
          const _PrivacyNote(text: 'Stock data could not be loaded from this device.')
        else if (_lowStockCount > 0)
          _LowStockBanner(count: _lowStockCount)
        else
          const _InStockBanner(),
        const SizedBox(height: 18),
        ..._supplies.map(
          (supply) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _StockManagementCard(
              supply: supply,
              onDecrease: () => _changeStock(supply, -1),
              onIncrease: () => _changeStock(supply, 1),
              onEdit: () => _showStockEditDialog(supply),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Approved requests reserve stock. On-hand stock changes when a request is marked collected.',
          style: TextStyle(color: _muted, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: () => setState(() => _selectedIndex = 1),
          icon: const Icon(Icons.assignment_outlined),
          label: const Text('Review school requests'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _green,
            minimumSize: const Size.fromHeight(50),
            side: const BorderSide(color: _green),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInsights() {
    return _PageScroll(
      children: [
        const _FacilityHeader(
          eyebrow: 'SAMPLE PARTNER DATA',
          title: 'Demand insights',
          subtitle: 'Example figures only  ·  Not connected to live requests',
        ),
        const SizedBox(height: 20),
        const _AggregateNotice(),
        const SizedBox(height: 20),
        const Row(
          children: [
            Expanded(
              child: _StatCard(
                value: '48',
                label: 'Requests this month',
                icon: Icons.assignment_outlined,
                color: _green,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                value: '3',
                label: 'Points need supply',
                icon: Icons.inventory_2_outlined,
                color: _coral,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const _SectionTitle('Demand by supply type'),
        const SizedBox(height: 12),
        const _DemandBar(
          label: 'Disposable pads',
          amount: '27 requests',
          value: .78,
        ),
        const _DemandBar(
          label: 'Reusable pad kits',
          amount: '14 requests',
          value: .48,
        ),
        const _DemandBar(label: 'Soap', amount: '7 requests', value: .27),
        const SizedBox(height: 22),
        const _SectionTitle('Where support is needed'),
        const SizedBox(height: 10),
        const _NeedRow(
          facility: 'Oli Primary School',
          need: 'Disposable pads',
          gap: '18 packs short',
          urgent: true,
        ),
        const _NeedRow(
          facility: 'Ediofe Girls School',
          need: 'Reusable pad kits',
          gap: '9 kits short',
          urgent: false,
        ),
        const _NeedRow(
          facility: 'St. Mary\'s Secondary',
          need: 'Disposable pads',
          gap: '13 packs short',
          urgent: false,
        ),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: () => _showPledgeDialog(context),
          icon: const Icon(Icons.volunteer_activism_outlined),
          label: const Text('Record a supply pledge'),
          style: _primaryButtonStyle,
        ),
        const SizedBox(height: 14),
        const Center(
          child: Text(
            'Counts are combined across facilities. No individual records are shown.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
          ),
        ),
      ],
    );
  }

  Future<void> _showStockEditDialog(_Supply supply) async {
    final controller = TextEditingController(text: '${supply.onHand}');
    final quantity = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update ${supply.name.toLowerCase()}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Current ${supply.unit}'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(controller.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (quantity != null) await _setStock(supply, quantity);
  }

  void _showPledgeDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supply pledge'),
        content: const Text(
          'Pledge tracking will connect to partner accounts when backend services are configured.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

final _primaryButtonStyle = FilledButton.styleFrom(
  backgroundColor: _green,
  foregroundColor: Colors.white,
  minimumSize: const Size.fromHeight(52),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
);

class _Supply {
  _Supply({
    required this.name,
    required this.onHand,
    required this.lowAt,
    required this.unit,
  });

  final String name;
  int onHand;
  final int lowAt;
  final String unit;
  int reserved = 0;
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onNotificationTap,
    this.onSignOut,
    this.initials = 'SM',
  });

  final VoidCallback onNotificationTap;
  final VoidCallback? onSignOut;
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 11, 18, 8),
      child: Row(
        children: [
          const _BrandMark(),
          const SizedBox(width: 9),
          const Text(
            'PadCare',
            style: TextStyle(
              color: _ink,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Request activity',
            onPressed: onNotificationTap,
            icon: const Icon(Icons.notifications_none_rounded),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _ink,
              fixedSize: const Size(42, 42),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            height: 48,
            child: Tooltip(
              message: 'Sign out',
              child: InkWell(
                key: const ValueKey('sign-out-control'),
                onTap: onSignOut,
                customBorder: const CircleBorder(),
                child: Center(
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFE6D5C9),
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Color(0xFF744B38),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({
    super.key,
    required this.parentName,
    required this.onSignOut,
  });

  final String parentName;
  final VoidCallback onSignOut;

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _LocalRequest {
  const _LocalRequest({
    required this.id,
    required this.reference,
    required this.school,
    required this.area,
    required this.product,
    required this.quantity,
    required this.createdAt,
    required this.status,
  });

  final String id;
  final String reference;
  final String school;
  final String area;
  final String product;
  final int quantity;
  final String createdAt;
  final String status;

  Map<String, Object> toJson() => {
    'id': id,
    'reference': reference,
    'school': school,
    'area': area,
    'product': product,
    'quantity': quantity,
    'createdAt': createdAt,
    'status': status,
  };

  factory _LocalRequest.fromJson(Map<String, dynamic> json) => _LocalRequest(
    id: json['id'] as String,
    reference: json['reference'] as String,
    school: json['school'] as String,
    area: json['area'] as String,
    product: json['product'] as String,
    quantity: json['quantity'] as int,
    createdAt: json['createdAt'] as String,
    status: json['status'] as String? ?? 'Pending review',
  );

  _LocalRequest withStatus(String status) => _LocalRequest(
    id: id,
    reference: reference,
    school: school,
    area: area,
    product: product,
    quantity: quantity,
    createdAt: createdAt,
    status: status,
  );
}

const _localStateKey = 'padcare.localState.v1';
const _legacyLocalRequestsKey = 'padcare.localRequests.v1';

class _LocalData {
  const _LocalData({required this.requests, required this.stock});

  final List<_LocalRequest> requests;
  final Map<String, int> stock;

  Map<String, Object> toJson() => {
    'requests': requests.map((request) => request.toJson()).toList(),
    'stock': stock,
  };
}

String _stockKey(String school, String product) => '$school::$product';

Future<_LocalData> _readLocalData() async {
  final preferences = await SharedPreferences.getInstance();
  final current = preferences.getString(_localStateKey) ??
      preferences.getString('padher.localState.v1');
  final legacy = preferences.getString(_legacyLocalRequestsKey) ??
      preferences.getString('padher.localRequests.v1');
  final Object? decoded = current != null
      ? jsonDecode(current)
      : legacy == null
      ? null
      : jsonDecode(legacy);
  final data = decoded is Map
      ? decoded
      : <String, dynamic>{'requests': decoded, 'stock': <String, int>{}};
  final requestData = data['requests'];
  final requests = requestData is List
      ? requestData
            .map(
              (request) => _LocalRequest.fromJson(
                Map<String, dynamic>.from(request as Map),
              ),
            )
            .toList()
      : <_LocalRequest>[];
  final stockData = data['stock'];
  final stock = stockData is Map
      ? stockData.map<String, int>(
          (key, value) => MapEntry(key.toString(), (value as num).toInt()),
        )
      : <String, int>{};
  final retentionCutoff = DateTime.now().subtract(const Duration(days: 30));
  final retainedRequests = requests.where((request) {
    final created = DateTime.tryParse(request.createdAt);
    return created != null && created.isAfter(retentionCutoff);
  }).toList();
  final localData = _LocalData(requests: retainedRequests, stock: stock);
  if (current == null || retainedRequests.length != requests.length) {
    final saved = await preferences.setString(
      _localStateKey,
      jsonEncode(localData.toJson()),
    );
    if (!saved) throw StateError('Local data could not be migrated or cleaned');
  }
  if (legacy != null) {
    await preferences.remove(_legacyLocalRequestsKey);
    await preferences.remove('padher.localRequests.v1');
  }
  if (current == null && preferences.containsKey('padher.localState.v1')) {
    await preferences.remove('padher.localState.v1');
  }
  return localData;
}

Future<void> _saveLocalData(_LocalData data) async {
  final preferences = await SharedPreferences.getInstance();
  final saved = await preferences.setString(
    _localStateKey,
    jsonEncode(data.toJson()),
  );
  if (!saved) throw StateError('Local data could not be saved');
}

enum _SupportSubTab { requestForm, activity, donate }

class _SupportPoint {
  const _SupportPoint({
    required this.id,
    required this.name,
    required this.category,
    required this.area,
    required this.distanceKm,
    required this.hours,
    required this.inStock,
    required this.isVerified,
    required this.directions,
    required this.mapOffsetPercent,
    required this.pinLabel,
    this.supplies = 'Pads & kits',
    this.instructions = 'Walk in and ask for adolescent health or matron desk. Confidential and free.',
    this.latitude,
    this.longitude,
    this.isLive = false,
  });

  final String id;
  final String name;
  final String category;
  final String area;
  final double? distanceKm;
  final String hours;
  final bool inStock;
  final bool isVerified;
  final String directions;
  final Offset mapOffsetPercent;
  final String pinLabel;
  final String supplies;
  final String instructions;
  final double? latitude;
  final double? longitude;
  final bool isLive;

  String get distanceLabel => distanceKm == null
      ? 'Distance unavailable'
      : '${distanceKm!.toStringAsFixed(1)} km away';
}

const _kSupportPoints = <_SupportPoint>[
  _SupportPoint(
    id: 'muni-clinic',
    name: 'Muni Health Centre IV',
    category: 'Clinics',
    area: 'Muni',
    distanceKm: null,
    hours: 'Hours not verified',
    inStock: false,
    isVerified: false,
    directions: 'Sample location — not verified',
    mapOffsetPercent: Offset(0.48, 0.70),
    pinLabel: 'Clinic',
    supplies: 'Supplies not verified',
    instructions: 'Sample listing only. Contact the provider to confirm whether this service is available.',
  ),
  _SupportPoint(
    id: 'arua-hospital',
    name: 'Arua Regional Referral Hospital',
    category: 'Clinics',
    area: 'Arua Central',
    distanceKm: null,
    hours: 'Hours not verified',
    inStock: false,
    isVerified: false,
    directions: 'Sample location — not verified',
    mapOffsetPercent: Offset(0.72, 0.28),
    pinLabel: 'Clinic',
    supplies: 'Supplies not verified',
    instructions: 'Sample listing only. Contact the provider to confirm whether this service is available.',
  ),
  _SupportPoint(
    id: 'ediofe-school',
    name: 'Ediofe Girls School',
    category: 'Schools',
    area: 'Ediofe',
    distanceKm: null,
    hours: 'Hours not verified',
    inStock: false,
    isVerified: false,
    directions: 'Sample location — not verified',
    mapOffsetPercent: Offset(0.24, 0.38),
    pinLabel: 'School',
    supplies: 'Supplies not verified',
    instructions: 'Sample listing only. Contact the provider to confirm whether this service is available.',
  ),
  _SupportPoint(
    id: 'st-marys-school',
    name: 'St. Mary\'s Secondary',
    category: 'Schools',
    area: 'Arua Hill',
    distanceKm: null,
    hours: 'Hours not verified',
    inStock: false,
    isVerified: false,
    directions: 'Sample location — not verified',
    mapOffsetPercent: Offset(0.28, 0.68),
    pinLabel: 'School',
    supplies: 'Supplies not verified',
    instructions: 'Sample listing only. Contact the provider to confirm whether this service is available.',
  ),
  _SupportPoint(
    id: 'oli-primary',
    name: 'Oli Primary School',
    category: 'Schools',
    area: 'Oli',
    distanceKm: null,
    hours: 'Hours not verified',
    inStock: false,
    isVerified: false,
    directions: 'Sample location — not verified',
    mapOffsetPercent: Offset(0.85, 0.54),
    pinLabel: 'School',
    supplies: 'Supplies not verified',
    instructions: 'Sample listing only. Contact the provider to confirm whether this service is available.',
  ),
  _SupportPoint(
    id: 'ceford-ngo',
    name: 'CEFORD Community Centre',
    category: 'NGOs',
    area: 'Arua Central',
    distanceKm: null,
    hours: 'Hours not verified',
    inStock: false,
    isVerified: false,
    directions: 'Sample location — not verified',
    mapOffsetPercent: Offset(0.42, 0.16),
    pinLabel: 'Collect',
    supplies: 'Supplies not verified',
    instructions: 'Sample listing only. Contact the provider to confirm whether this service is available.',
  ),
];

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  int _selectedIndex = 0;
  _SupportSubTab _supportSubTab = _SupportSubTab.requestForm;
  _SupportPoint _selectedMapPoint = _kSupportPoints[1];
  bool _mapViewMode = true;
  StreamSubscription<List<Map<String, dynamic>>>? _providerSubscription;
  List<Map<String, dynamic>> _remoteProviderRecords = <Map<String, dynamic>>[];
  List<_SupportPoint> _liveSupportPoints = <_SupportPoint>[];
  Position? _currentPosition;
  String _selectedCategory = 'All';
  String _providerSearch = '';
  String _selectedMapFilter = 'All providers';
  String _selectedArea = 'Oli';
  String _selectedProduct = 'Disposable pads';
  int _quantity = 4;
  int _selectedDonationAmount = 10000;
  List<_LocalRequest> _localRequests = [];
  bool _loadingRequests = true;
  bool _savingRequest = false;
  bool _requestStorageFailed = false;

  @override
  void initState() {
    super.initState();
    _loadLocalRequests();
    _loadVerifiedProviders();
  }

  @override
  void dispose() {
    _providerSubscription?.cancel();
    super.dispose();
  }

  void _loadVerifiedProviders() {
    if (!PadCareBackend.isConfigured) return;
    try {
      _providerSubscription = PadCareBackend.watchVerifiedProviders().listen(
        (records) {
          _remoteProviderRecords = records;
          _applyVerifiedProviders();
        },
        onError: (Object _) {},
      );
    } catch (_) {
      // Keep the local preview available if the service is unavailable.
    }
  }

  void _applyVerifiedProviders() {
    final now = DateTime.now();
    final points = _remoteProviderRecords.map((record) {
      final latitude = (record['latitude'] as num?)?.toDouble();
      final longitude = (record['longitude'] as num?)?.toDouble();
      final distance = _currentPosition != null && latitude != null && longitude != null
          ? Geolocator.distanceBetween(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
                latitude,
                longitude,
              ) / 1000
          : null;
      final updatedAt = DateTime.tryParse(record['stockUpdatedAtIso']?.toString() ?? '');
      final stockIsFresh = updatedAt != null &&
          !updatedAt.isAfter(now) &&
          now.difference(updatedAt) <= const Duration(hours: 24);
      return _SupportPoint(
        id: record['id']?.toString() ?? '',
        name: record['name']?.toString() ?? 'Support point',
        category: record['category']?.toString() ?? 'Community',
        area: record['area']?.toString() ?? 'Area not provided',
        distanceKm: distance,
        hours: record['hours']?.toString() ?? 'Contact provider to confirm hours',
        inStock: stockIsFresh && record['stockAvailable'] == true,
        isVerified: record['isVerified'] == true,
        directions: record['address']?.toString() ?? record['directions']?.toString() ?? '',
        mapOffsetPercent: const Offset(0.5, 0.5),
        pinLabel: record['category']?.toString() ?? 'Support',
        supplies: record['supplies']?.toString() ?? 'Contact provider for current supplies',
        instructions: record['instructions']?.toString() ?? 'Contact the provider to confirm collection instructions.',
        latitude: latitude,
        longitude: longitude,
        isLive: true,
      );
    }).where((point) => point.id.isNotEmpty && point.name.isNotEmpty).toList();
    if (!mounted) return;
    setState(() {
      _liveSupportPoints = points;
      if (points.isNotEmpty) {
        _selectedMapPoint = points.first;
        _mapViewMode = false;
      }
    });
  }

  Future<void> _requestLocationAndRefresh() async {
    if (!PadCareBackend.isConfigured || _liveSupportPoints.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Live provider discovery is not configured yet. You can still search the sample directory by area.')),
        );
      }
      return;
    }
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location is turned off. You can still browse by area.')),
          );
        }
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission was not granted. Distances remain unavailable; you can still browse by area.')),
          );
        }
        return;
      }
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      _applyVerifiedProviders();
      if (mounted && _liveSupportPoints.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No verified online providers are available yet. Sample points are shown separately.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get your location. You can still search by area.')),
        );
      }
    }
  }

  Future<void> _openExternalDirections(_SupportPoint point) async {
    if (!point.isLive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Directions are unavailable for sample listings. Verified provider directions will appear when the online directory is configured.')),
      );
      return;
    }
    final destination = point.latitude != null && point.longitude != null
        ? '${point.latitude},${point.longitude}'
        : point.directions;
    if (destination.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This provider has no directions listed yet.')),
      );
      return;
    }
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destination,
    });
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open directions on this device.')),
      );
    }
  }

  Future<void> _loadLocalRequests() async {
    try {
      final localData = await _readLocalData();
      var requests = localData.requests;
      if (PadCareBackend.isSignedIn) {
        try {
          final remote = await PadCareBackend.loadMyRequests();
          final byId = <String, _LocalRequest>{
            for (final request in requests) request.id: request,
          };
          for (final record in remote) {
            try {
              final request = _LocalRequest.fromJson(Map<String, dynamic>.from(record));
              byId[request.id] = request;
            } catch (_) {
              // Ignore malformed remote documents; keep valid local data.
            }
          }
          requests = byId.values.toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          await _saveLocalData(_LocalData(requests: requests, stock: localData.stock));
        } catch (_) {
          // Preserve offline functionality if the remote service is unavailable.
        }
      }
      if (!mounted) return;
      setState(() {
        _localRequests = requests;
        _loadingRequests = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingRequests = false;
        _requestStorageFailed = true;
      });
    }
  }

  String get _pickupSchool => _pickupSchoolsByArea[_selectedArea]!;

  void _showPickupDetails() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Area-based pickup match',
                style: TextStyle(
                  color: _ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              _PickupPointCard(
                area: _selectedArea,
                school: _pickupSchool,
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(height: 12),
              const Text(
                'This preview uses a sample catchment map. The school team confirms current stock and collection arrangements.',
                style: TextStyle(color: _muted, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: _primaryButtonStyle,
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitRequest() async {
    if (_loadingRequests || _savingRequest || _requestStorageFailed) return;
    setState(() => _savingRequest = true);

    final now = DateTime.now();
    final request = _LocalRequest(
      id: now.microsecondsSinceEpoch.toString(),
      reference: 'PH-${1000 + now.millisecondsSinceEpoch % 9000}',
      school: _pickupSchool,
      area: _selectedArea,
      product: _selectedProduct,
      quantity: _quantity,
      createdAt: now.toIso8601String(),
      status: 'Pending review',
    );
    final updatedRequests = [request, ..._localRequests];

    try {
      final data = await _readLocalData();
      await _saveLocalData(
        _LocalData(requests: updatedRequests, stock: data.stock),
      );
      var syncFailed = false;
      if (PadCareBackend.isSignedIn) {
        try {
          await PadCareBackend.createPickupRequest(request.toJson());
        } catch (_) {
          syncFailed = true;
        }
      }
      if (!mounted) return;
      setState(() {
        _localRequests = updatedRequests;
        _savingRequest = false;
        _selectedIndex = 3;
        _supportSubTab = _SupportSubTab.activity;
      });
      if (syncFailed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request saved on this device, but online sync failed.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _savingRequest = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save this request on device.')),
      );
    }
  }

  Future<void> _deleteRequest(_LocalRequest request) async {
    if (request.status != 'Pending review') return;
    final updatedRequests = _localRequests
        .where((item) => item.id != request.id)
        .toList();
    try {
      final data = await _readLocalData();
      await _saveLocalData(
        _LocalData(requests: updatedRequests, stock: data.stock),
      );
      var remoteDeleteFailed = false;
      if (PadCareBackend.isSignedIn) {
        try {
          await PadCareBackend.deletePickupRequest(request.id);
        } catch (_) {
          remoteDeleteFailed = true;
        }
      }
      if (!mounted) return;
      setState(() => _localRequests = updatedRequests);
      if (remoteDeleteFailed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request removed locally, but the online copy could not be deleted.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete this saved request.')),
      );
    }
  }

  void _showFacilityDetails(_SupportPoint point) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    point.name,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (point.isVerified)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF7EE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Verified',
                          style: TextStyle(
                            color: Color(0xFF16A34A),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${point.category}  ·  ${point.area}  ·  ${point.distanceLabel}',
              style: const TextStyle(color: _muted, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time_rounded, color: _green, size: 16),
                const SizedBox(width: 6),
                Text(
                  point.hours,
                  style: const TextStyle(color: _ink, fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F7F0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    point.inStock ? '● In Stock' : 'Availability unknown',
                    style: TextStyle(
                      color: point.inStock ? const Color(0xFF116B78) : _muted,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F8F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pickup Instructions & Supplies',
                    style: TextStyle(color: _ink, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    point.instructions,
                    style: const TextStyle(color: _muted, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Available: ${point.supplies}',
                    style: const TextStyle(color: _ink, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openExternalDirections(point),
              icon: const Icon(Icons.directions_outlined),
              label: const Text('Open directions in Google Maps'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF116B78),
                minimumSize: const Size(double.infinity, 46),
                side: const BorderSide(color: Color(0xFFB9E9DE)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _ink,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text('Close'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        _selectedArea = point.area == 'Muni' || point.area == 'Arua Central' ? 'Oli' : point.area;
                        _selectedIndex = 3;
                        _supportSubTab = _SupportSubTab.requestForm;
                      });
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: _ink,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text('Request Pickup'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openDirectionsSheet(_SupportPoint point) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2EF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.directions_rounded, color: _ink),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        point.name,
                        style: const TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${point.distanceLabel}${point.distanceKm == null ? '' : ' · Estimated ${(point.distanceKm! * 12).ceil()} mins walk'}',
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Route steps are illustrative only. Use Google Maps for real directions to verified providers.',
              style: TextStyle(color: _muted, height: 1.45),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _openExternalDirections(point);
              },
              icon: const Icon(Icons.open_in_new_rounded),
              style: FilledButton.styleFrom(
                backgroundColor: _ink,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              label: const Text('Open Google Maps directions'),
            ),
          ],
        ),
      ),
    );
  }


  void _openDonationSheet() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 18),
            const Text('Support PadCare development', style: TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'Choose an optional pledge to support app development, maintenance, and accessibility. This is separate from donating sanitary products. Recording a pledge does not take a payment.',
              style: TextStyle(color: _muted, fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _buildDonationTier('Supporter', 'UGX 5,000', value: 5000, onSelect: () => setModalState(() => _selectedDonationAmount = 5000)),
                const SizedBox(width: 8),
                _buildDonationTier('Builder', 'UGX 10,000', value: 10000, onSelect: () => setModalState(() => _selectedDonationAmount = 10000)),
                const SizedBox(width: 8),
                _buildDonationTier('Champion', 'UGX 20,000', value: 20000, onSelect: () => setModalState(() => _selectedDonationAmount = 20000)),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(this.context);
                if (!PadCareBackend.isSignedIn) {
                  navigator.pop();
                  messenger.showSnackBar(const SnackBar(
                    content: Text('Sign in with an online account to record a pledge. No payment is taken here.'),
                  ));
                  return;
                }
                try {
                  await PadCareBackend.recordDonationPledge(
                    amountUgx: _selectedDonationAmount,
                    purpose: 'PadCare app development',
                  );
                  if (!mounted) return;
                  navigator.pop();
                  messenger.showSnackBar(SnackBar(
                    content: Text('Your UGX $_selectedDonationAmount pledge was recorded. No payment was taken.'),
                  ));
                } catch (_) {
                  if (!mounted) return;
                  messenger.showSnackBar(const SnackBar(
                    content: Text('Could not record your pledge. No payment was taken.'),
                  ));
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF116B78),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Record pledge (no payment)', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildDonationTier(String title, String amount, {required int value, required VoidCallback onSelect}) {
    final selected = _selectedDonationAmount == value;
    return Expanded(
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE6F7F0) : Colors.white,
            border: Border.all(
              color: selected ? const Color(0xFF116B78) : _line,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(title, style: TextStyle(
                color: selected ? const Color(0xFF116B78) : _ink,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              )),
              const SizedBox(height: 4),
              Text(amount, style: const TextStyle(color: _muted, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  void _openAreaSelector() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Your Area in Arua',
              style: TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 12),
            ...['Arua Central', 'Ediofe', 'Oli', 'Ayivu', 'Arua Hill'].map(
              (area) => ListTile(
                title: Text(area, style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: _selectedArea == area || (_selectedArea == 'Oli' && area == 'Arua Central')
                    ? const Icon(Icons.check_circle_rounded, color: _green)
                    : null,
                onTap: () {
                  setState(() => _selectedArea = area == 'Arua Central' ? 'Oli' : area);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSplashScreenModal() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _PadCareSplashScreen(
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _paper,
      body: SafeArea(
        child: Column(
          children: [
            _buildMainTopBar(),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  _buildHome(),
                  _buildFindPads(),
                  _buildLearn(),
                  _buildSupport(),
                  _buildProfile(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFD6F0EA),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: _ink),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_rounded),
            selectedIcon: Icon(Icons.search_rounded, color: _ink),
            label: 'Find Pads',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded, color: _ink),
            label: 'Learn',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline_rounded),
            selectedIcon: Icon(Icons.favorite_rounded, color: _ink),
            label: 'Support',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: _ink),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildMainTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 16, 6),
      child: Row(
        children: [
          const _BrandMark(),
          const SizedBox(width: 8),
          const Text(
            'PadCare',
            style: TextStyle(
              color: _ink,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: _openAreaSelector,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFE4F4F1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFC7E7E2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on, size: 14, color: _ink),
                  const SizedBox(width: 4),
                  Text(
                    _selectedArea == 'Oli' ? 'Arua Central' : _selectedArea,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_drop_down, size: 16, color: _ink),
                ],
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Request activity',
            onPressed: () => setState(() {
              _selectedIndex = 3;
              _supportSubTab = _SupportSubTab.activity;
            }),
            icon: Stack(
              children: [
                const Icon(Icons.notifications_none_rounded, color: _ink),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2EA8B6),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              fixedSize: const Size(40, 40),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 48,
            height: 48,
            child: Tooltip(
              message: 'Sign out',
              child: InkWell(
                key: const ValueKey('sign-out-control'),
                onTap: widget.onSignOut,
                customBorder: const CircleBorder(),
                child: Center(
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFD3EAE5),
                    child: Text(
                      widget.parentName.isEmpty ? 'PA' : widget.parentName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHome() {
    final sourcePoints = _liveSupportPoints.isNotEmpty ? _liveSupportPoints : _kSupportPoints;
    final filteredPoints = sourcePoints.where((p) {
      final query = _providerSearch.trim().toLowerCase();
      if (query.isNotEmpty &&
          ![p.name, p.area, p.directions, p.category]
              .any((value) => value.toLowerCase().contains(query))) {
        return false;
      }
      if (_selectedCategory == 'Schools' && p.category != 'Schools') { return false; }
      if (_selectedCategory == 'Clinics' && p.category != 'Clinics') { return false; }
      if (_selectedCategory == 'NGOs' && p.category != 'NGOs') { return false; }
      if (_selectedCategory == 'Community' && p.category != 'Schools' && p.category != 'NGOs') { return false; }
      return true;
    }).toList();

    return _PageScroll(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hello, there!',
                style: TextStyle(
                  color: _ink,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Let\'s find the support you need.',
                style: TextStyle(
                  color: _muted,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4F8F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFB9E9DE)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFF116B78), size: 20),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        _liveSupportPoints.isEmpty
                            ? 'Preview data: sample locations and distances are illustrative. Confirm availability with providers before travelling.'
                            : 'Live verified provider listings are connected. Stock is displayed only when updated within the last 24 hours.',
                        style: const TextStyle(color: Color(0xFF116B78), fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pickup support near you',
                style: TextStyle(
                  color: _muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => setState(() {
                      _selectedIndex = 3;
                      _supportSubTab = _SupportSubTab.requestForm;
                    }),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                    label: const Text('New request'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE2F3F0),
                      foregroundColor: _ink,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _selectedIndex = 3;
                      _supportSubTab = _SupportSubTab.activity;
                    }),
                    icon: const Icon(Icons.receipt_long_outlined, size: 16),
                    label: const Text('Activity'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _ink,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2EFEF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0C000000),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, color: _muted, size: 21),
              const SizedBox(width: 9),
              Expanded(
                child: TextField(
                  onChanged: (value) => setState(() => _providerSearch = value),
                  decoration: const InputDecoration(
                    hintText: 'Find sanitary pads near you...',
                    hintStyle: TextStyle(color: Color(0xFF88A0A2), fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.tune_rounded, color: _ink, size: 20),
                onPressed: () => setState(() => _selectedIndex = 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2EA8B6), Color(0xFF48C3AF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x332EA8B6),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -10,
                bottom: -15,
                child: Opacity(
                  opacity: 0.18,
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    width: 120,
                    height: 120,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pads are\nwithin reach.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Discover nearby places offering support.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() => _selectedIndex = 1);
                      _requestLocationAndRefresh();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _ink,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Find Pads Near Me',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'Explore Categories',
          style: TextStyle(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 11),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildCategoryChip('🏫 Schools'),
              const SizedBox(width: 8),
              _buildCategoryChip('🏥 Clinics'),
              const SizedBox(width: 8),
              _buildCategoryChip('🤝 NGOs'),
              const SizedBox(width: 8),
              _buildCategoryChip('🏡 Community'),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Nearby Support Points',
                style: TextStyle(
                  color: _ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _selectedIndex = 1),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('See All', style: TextStyle(color: _muted, fontWeight: FontWeight.w700)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios_rounded, size: 12, color: _muted),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...filteredPoints.map((point) => _buildSupportPointCard(point)),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2EFEF)),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              const Text(
                'Every act of care makes a difference.',
                style: TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              FilledButton(
                onPressed: _openDonationSheet,
                style: FilledButton.styleFrom(
                  backgroundColor: _ink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                child: const Text('🎁 Donate to PadCare Project', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCategoryChip(String label) {
    final cleanLabel = label.split(' ').last;
    final selected = _selectedCategory == cleanLabel;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategory = selected ? 'All' : cleanLabel;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _ink : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _ink : const Color(0xFFDCECEB)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _ink,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildSupportPointCard(_SupportPoint point) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5EFEF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE4F4F1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  point.category == 'Clinics' ? Icons.local_hospital_rounded : Icons.school_rounded,
                  color: _ink,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            point.name,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (point.isVerified) ...[
                          const SizedBox(width: 5),
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 16),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${point.distanceLabel}  •  ${point.hours}',
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F7F0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  point.inStock ? '● In Stock' : 'Availability unknown',
                  style: const TextStyle(
                    color: Color(0xFF0D9488),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: () {
                  setState(() => _selectedMapPoint = point);
                  _showFacilityDetails(point);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _ink,
                  side: const BorderSide(color: _ink),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('View Details & Instructions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFindPads() {
    final sourcePoints = _liveSupportPoints.isNotEmpty ? _liveSupportPoints : _kSupportPoints;
    final filtered = sourcePoints.where((p) {
      final query = _providerSearch.trim().toLowerCase();
      if (query.isNotEmpty &&
          ![p.name, p.area, p.directions, p.category]
              .any((value) => value.toLowerCase().contains(query))) {
        return false;
      }
      if (_selectedMapFilter == 'In Stock' && !p.inStock) { return false; }
      if (_selectedMapFilter == 'Verified' && !p.isVerified) { return false; }
      if (_selectedMapFilter == 'NGO & Clinics' && p.category != 'Clinics' && p.category != 'NGOs') { return false; }
      if (_selectedMapFilter == 'Schools' && p.category != 'Schools') { return false; }
      return true;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2EFEF),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          if (_liveSupportPoints.isNotEmpty) {
                            _openExternalDirections(_selectedMapPoint);
                          } else {
                            setState(() => _mapViewMode = true);
                          }
                        },
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _mapViewMode ? _ink : Colors.transparent,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _liveSupportPoints.isNotEmpty ? 'Directions' : 'Map',
                            style: TextStyle(
                              color: _mapViewMode ? Colors.white : _muted,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _mapViewMode = false),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: !_mapViewMode ? _ink : Colors.transparent,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'List',
                            style: TextStyle(
                              color: !_mapViewMode ? Colors.white : _muted,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE0ECEB)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: _muted, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        onChanged: (value) => setState(() => _providerSearch = value),
                        decoration: const InputDecoration(
                          hintText: 'Search town, school, or landmark...',
                          hintStyle: TextStyle(color: Color(0xFF88A0A2), fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.tune_rounded, color: _ink, size: 19),
                      onPressed: () {},
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _liveSupportPoints.isNotEmpty
                      ? 'Live verified providers are listed below. Tap Map to open the selected provider in Google Maps.'
                      : 'Preview only: sample pins and locations are illustrative, not verified real-world pickup points.',
                  style: const TextStyle(color: Color(0xFF116B78), fontSize: 12, height: 1.4),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildMapFilterChip('All providers'),
                    const SizedBox(width: 6),
                    _buildMapFilterChip('In Stock'),
                    const SizedBox(width: 6),
                    _buildMapFilterChip('Verified'),
                    const SizedBox(width: 6),
                    _buildMapFilterChip('NGO & Clinics'),
                    const SizedBox(width: 6),
                    _buildMapFilterChip('Schools'),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _mapViewMode
              ? Stack(
                  children: [
                    Positioned.fill(
                      child: _InteractiveAruaMap(
                        points: filtered,
                        selectedPoint: _selectedMapPoint,
                        onSelect: (pt) => setState(() => _selectedMapPoint = pt),
                      ),
                    ),
                    Positioned(
                      top: 14,
                      right: 14,
                      child: FloatingActionButton.small(
                        heroTag: 'recenter-map',
                        backgroundColor: Colors.white,
                        foregroundColor: _ink,
                        elevation: 3,
                        onPressed: _liveSupportPoints.isNotEmpty
                            ? _requestLocationAndRefresh
                            : () => setState(() => _selectedMapPoint = _kSupportPoints[1]),
                        child: const Icon(Icons.my_location_rounded, size: 20),
                      ),
                    ),
                    Positioned(
                      bottom: 170,
                      right: 14,
                      child: FloatingActionButton.small(
                        heroTag: 'navigate-map',
                        backgroundColor: Colors.white,
                        foregroundColor: _ink,
                        elevation: 3,
                        onPressed: () => _openDirectionsSheet(_selectedMapPoint),
                        child: const Icon(Icons.near_me_rounded, size: 20),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 12,
                      child: _buildMapBottomCard(_selectedMapPoint),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, idx) => _buildSupportPointCard(filtered[idx]),
                ),
        ),
      ],
    );
  }

  Widget _buildMapFilterChip(String label) {
    final selected = _selectedMapFilter == label;
    return InkWell(
      onTap: () => setState(() => _selectedMapFilter = label),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _ink : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? _ink : const Color(0xFFD6E6E4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _ink,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildMapBottomCard(_SupportPoint point) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x220E383A),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    point.name,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (point.isVerified)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF7EE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Verified',
                          style: TextStyle(
                            color: Color(0xFF16A34A),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.turn_right_rounded, color: _muted, size: 16),
                          const SizedBox(width: 5),
                          Text(
                            point.directions,
                            style: const TextStyle(color: _muted, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.navigation_outlined, color: _muted, size: 15),
                          const SizedBox(width: 5),
                          Text(
                            point.distanceLabel,
                            style: const TextStyle(color: _muted, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF16A34A),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            point.inStock ? 'In Stock' : 'Availability unknown',
                            style: const TextStyle(
                              color: Color(0xFF16A34A),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  children: [
                    FilledButton(
                      onPressed: () => _openDirectionsSheet(point),
                      style: FilledButton.styleFrom(
                        backgroundColor: _ink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      ),
                      child: const Text(
                        'Get Directions',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => _showFacilityDetails(point),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _ink,
                        side: const BorderSide(color: _ink),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      ),
                      child: const Text(
                        'Details & Hours',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLearn() {
    return _PageScroll(
      children: [
        const _FacilityHeader(
          eyebrow: 'PERIOD HEALTH & EDUCATION',
          title: 'Learn & Care',
          subtitle: 'Practical, age-appropriate information about periods and product care.',
        ),
        const SizedBox(height: 18),
        _buildLearnCard(
          icon: Icons.calendar_month_rounded,
          title: 'Understanding Your Cycle',
          subtitle: 'The 4 phases of your monthly cycle, tracking symptoms, and natural relief tips.',
          tag: 'Essential Guide',
        ),
        const SizedBox(height: 12),
        _buildLearnCard(
          icon: Icons.eco_rounded,
          title: 'Reusable vs Disposable Pads',
          subtitle: 'Comparing comfort, absorption, cost savings, and environmental protection.',
          tag: 'Product Care',
        ),
        const SizedBox(height: 12),
        _buildLearnCard(
          icon: Icons.water_drop_rounded,
          title: 'Step-by-step Washing & Care',
          subtitle: 'Best practices for soaking, washing, drying under sunlight, and storing reusable kits.',
          tag: 'Hygiene Protocol',
        ),
        const SizedBox(height: 12),
        _buildLearnCard(
          icon: Icons.health_and_safety_rounded,
          title: 'Where to find trusted support',
          subtitle: 'How to approach a school nurse, health worker, clinic, or trusted adult.',
          tag: 'Trusted Support',
        ),
      ],
    );
  }

  void _showLearnArticle(String title) {
    final sections = switch (title) {
      'Understanding Your Cycle' => <String>[
        'Menstrual cycles differ from person to person. The length and symptoms can change during adolescence and across life.',
        'You can note the first day of bleeding, how long it lasts, pain, mood changes, and other symptoms. Tracking is optional; PadCare does not need this information to help find supplies.',
        'Talk to a qualified health worker or trusted adult if bleeding or pain disrupts everyday activities, symptoms worry you, or you have questions about your cycle.',
      ],
      'Reusable vs Disposable Pads' => <String>[
        'Disposable pads are designed for one use. Wrap and place used pads in a bin; do not flush them down a toilet.',
        'Reusable pads can be washed and used again when the product instructions are followed. Make sure they are fully clean and dry before storage.',
        'Choose the option that is comfortable, accessible, and practical for you. Never share used menstrual products.',
      ],
      'Step-by-step Washing & Care' => <String>[
        'Wash your hands before and after changing or cleaning menstrual products.',
        'For reusable pads, follow the care instructions supplied with the product. Wash thoroughly with clean water and soap, rinse well, and dry completely before storing.',
        'Keep clean products in a dry, clean bag or container. If a product changes smell, texture, or condition, stop using it and ask a health worker or supplier for advice.',
      ],
      _ => <String>[
        'For menstrual-health questions, consider speaking with a qualified health worker, school nurse, clinic, or trusted adult.',
        'Ask the provider about privacy, opening hours, costs, and available support before travelling.',
        'PadCare does not currently operate a verified helpline. If you need urgent medical help, contact a local health facility or emergency service.',
      ],
    };
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(color: _ink, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text(
              'General information only — not a diagnosis or a replacement for professional medical advice.',
              style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 16),
            ...sections.map((section) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF116B78), size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(section, style: const TextStyle(color: _ink, height: 1.5))),
                ],
              ),
            )),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF116B78),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLearnCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String tag,
  }) {
    return InkWell(
      onTap: () => _showLearnArticle(title),
      borderRadius: BorderRadius.circular(18),
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4F0EE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE6F5F2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _ink),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F8F6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(color: Color(0xFF2EA8B6), fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: _muted, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildSupport() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFE2EFEF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                _buildSupportSubTabButton('New request', _SupportSubTab.requestForm),
                _buildSupportSubTabButton('Activity', _SupportSubTab.activity),
                _buildSupportSubTabButton('Sponsor', _SupportSubTab.donate),
              ],
            ),
          ),
        ),
        Expanded(
          child: switch (_supportSubTab) {
            _SupportSubTab.requestForm => _buildRequestForm(),
            _SupportSubTab.activity => _buildActivity(),
            _SupportSubTab.donate => _buildSponsor(),
          },
        ),
      ],
    );
  }

  Widget _buildSupportSubTabButton(String label, _SupportSubTab tab) {
    final selected = _supportSubTab == tab;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _supportSubTab = tab),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? _ink : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : _muted,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSponsor() {
    return _PageScroll(
      children: [
        const _FacilityHeader(
          eyebrow: 'COMMUNITY IMPACT',
          title: 'Sponsor PadCare',
          subtitle: 'Support the app that helps people find menstrual-product assistance.',
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE4F0EE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Help keep PadCare improving',
                style: TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your voluntary contribution supports PadCare app development, maintenance, accessibility, and future improvements. It does not directly purchase or distribute sanitary products.',
                style: TextStyle(color: _muted, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _openDonationSheet,
                icon: const Icon(Icons.favorite_rounded),
                label: const Text('Make a Donation to PadCare'),
                style: _primaryButtonStyle,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfile() {
    return _PageScroll(
      children: [
        const _FacilityHeader(
          eyebrow: 'SETTINGS & ACCOUNT',
          title: 'Profile & Access',
          subtitle: 'Manage roles, view splash preview, and local preferences.',
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE4F0EE)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFFE0F2EF),
                child: Text(
                  widget.parentName.isEmpty ? 'PA' : widget.parentName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _ink),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.parentName.isEmpty ? 'Parent account' : widget.parentName,
                      style: const TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    const Text('Parent or guardian access', style: TextStyle(color: _muted, fontSize: 13)),
                    const SizedBox(height: 3),
                    Text('Location: ${_selectedArea == 'Oli' ? 'Arua Central' : _selectedArea}', style: const TextStyle(color: _green, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          tileColor: Colors.white,
          leading: const Icon(Icons.smartphone_rounded, color: Color(0xFF2EA8B6)),
          title: const Text('Preview Splash Screen', style: TextStyle(fontWeight: FontWeight.w700, color: _ink)),
          subtitle: const Text('View the 3D PadCare launch visual'),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
          onTap: _openSplashScreenModal,
        ),
        const SizedBox(height: 10),
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          tileColor: Colors.white,
          leading: const Icon(Icons.school_rounded, color: _ink),
          title: const Text('Switch to Senior Woman Teacher Portal', style: TextStyle(fontWeight: FontWeight.w700, color: _ink)),
          subtitle: const Text('Manage school stock & student requests'),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => HomeScreen(
                  facility: _pickupSchool,
                  onSignOut: widget.onSignOut,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        ListTile(
          key: const ValueKey('sign-out-control-listtile'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          tileColor: Colors.white,
          leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
          title: const Text('Sign out of PadCare', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.redAccent)),
          subtitle: const Text('Return to access selection'),
          onTap: widget.onSignOut,
        ),
        const SizedBox(height: 18),
        const _PrivacyNote(
          text: 'PadCare works offline-first. Your requests are saved only on this device without sharing your identity or tracking data.',
        ),
      ],
    );
  }

  Widget _buildRequestForm() {
    return _PageScroll(
      children: [
        _FacilityHeader(
          eyebrow: 'HOME PICKUP REQUEST',
          title: 'Request supplies',
          subtitle: PadCareBackend.isSignedIn
              ? 'Your request is saved locally first and then synced to your online account when possible.'
              : 'The selected school can review this request in the local preview. It is not sent over the network.',
        ),
        const SizedBox(height: 20),
        const _FieldLabel('Your area'),
        const SizedBox(height: 7),
        DropdownButtonFormField<String>(
          key: const ValueKey('pickup-area-dropdown'),
          initialValue: _selectedArea,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
          items: _pickupSchoolsByArea.keys
              .map((area) => DropdownMenuItem(value: area, child: Text(area)))
              .toList(),
          onChanged: (area) => setState(() {
            if (area != null) _selectedArea = area;
          }),
        ),
        const SizedBox(height: 12),
        _PickupPointCard(
          area: _selectedArea,
          school: _pickupSchool,
          onTap: _showPickupDetails,
        ),
        const SizedBox(height: 19),
        const _FieldLabel('Supply needed'),
        const SizedBox(height: 7),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ProductChoice(
              label: 'Disposable pads',
              selected: _selectedProduct == 'Disposable pads',
              onTap: () => setState(() => _selectedProduct = 'Disposable pads'),
            ),
            _ProductChoice(
              label: 'Reusable pads',
              selected: _selectedProduct == 'Reusable pads',
              onTap: () => setState(() => _selectedProduct = 'Reusable pads'),
            ),
          ],
        ),
        const SizedBox(height: 17),
        const _FieldLabel('Quantity'),
        const SizedBox(height: 7),
        _QuantityControl(
          value: _quantity,
          unit: _selectedProduct == 'Reusable pads' ? 'kits' : 'packs',
          onChanged: (value) => setState(() => _quantity = value),
        ),
        const SizedBox(height: 17),
        const _PrivacyNote(
          text: 'No names or personal details are needed for this request.',
        ),
        const SizedBox(height: 12),
        const _LocalOnlyNotice(),
        const SizedBox(height: 19),
        FilledButton.icon(
          key: const ValueKey('submit-home-request'),
          onPressed: _loadingRequests || _savingRequest || _requestStorageFailed
              ? null
              : _submitRequest,
          icon: Icon(
            _savingRequest ? Icons.hourglass_top_rounded : Icons.save_rounded,
          ),
          label: Text(
            _savingRequest ? 'Submitting request...' : 'Submit request',
          ),
          style: _primaryButtonStyle,
        ),
        const SizedBox(height: 12),
        const Text(
          'Pickup locations shown here use a sample area map. Staff will confirm availability and collection details.',
          style: TextStyle(color: _muted, fontSize: 11, height: 1.45),
        ),
      ],
    );
  }

  Widget _buildActivity() {
    return _PageScroll(
      children: [
        const _FacilityHeader(
          eyebrow: 'PARENT ACCOUNT',
          title: 'Request activity',
          subtitle: 'Check the status and pickup point for your requests.',
        ),
        const SizedBox(height: 20),
        if (_loadingRequests)
          const Center(child: CircularProgressIndicator())
        else if (_requestStorageFailed)
          const _PrivacyNote(
            text: 'Saved requests could not be loaded. No new request was saved.',
          )
        else if (_localRequests.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _line),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Text(
              'No saved requests on this device yet.',
              style: TextStyle(color: _muted, height: 1.5),
            ),
          )
        else ...[
          const _LocalOnlyNotice(),
          const SizedBox(height: 12),
          ..._localRequests.map(
            (request) => _LocalRequestCard(
              key: ValueKey(request.id),
              request: request,
              onDelete: () => _deleteRequest(request),
            ),
          ),
        ],
        const SizedBox(height: 18),
        const _PrivacyNote(
          text: 'The local teacher preview can see the item and quantity. No school is contacted and no child identity is collected.',
        ),
      ],
    );
  }
}

class _InteractiveAruaMap extends StatelessWidget {
  const _InteractiveAruaMap({
    required this.points,
    required this.selectedPoint,
    required this.onSelect,
  });

  final List<_SupportPoint> points;
  final _SupportPoint selectedPoint;
  final ValueChanged<_SupportPoint> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return Stack(
          children: [
            CustomPaint(
              size: Size(w, h),
              painter: _AruaMapPainter(
                selectedPointId: selectedPoint.id,
              ),
            ),
            ...points.map((pt) {
              final x = pt.mapOffsetPercent.dx * w;
              final y = pt.mapOffsetPercent.dy * h;
              final isSelected = pt.id == selectedPoint.id;

              return Positioned(
                left: x - 40,
                top: y - 48,
                child: GestureDetector(
                  onTap: () => onSelect(pt),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x24000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '📍 ${pt.pinLabel}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? const Color(0xFF2EA8B6) : _ink,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        width: isSelected ? 34 : 26,
                        height: isSelected ? 34 : 26,
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF2EA8B6) : _ink,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: isSelected ? 3 : 2),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected ? const Color(0x662EA8B6) : const Color(0x33000000),
                              blurRadius: isSelected ? 12 : 6,
                              spreadRadius: isSelected ? 2 : 0,
                            ),
                          ],
                        ),
                        child: Icon(
                          pt.category == 'Clinics' ? Icons.local_hospital_rounded : Icons.school_rounded,
                          color: Colors.white,
                          size: isSelected ? 18 : 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _AruaMapPainter extends CustomPainter {
  const _AruaMapPainter({
    required this.selectedPointId,
  });

  final String selectedPointId;

  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()..color = const Color(0xFFE4F3EE);
    canvas.drawRect(Offset.zero & size, basePaint);

    final parkPaint = Paint()..color = const Color(0xFFD2EADB);
    final park1 = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.04, size.height * 0.08, size.width * 0.36, size.height * 0.24),
        const Radius.circular(36),
      ));
    canvas.drawPath(park1, parkPaint);

    final park2 = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.65, size.height * 0.12, size.width * 0.35, size.height * 0.28),
        const Radius.circular(46),
      ));
    canvas.drawPath(park2, parkPaint);

    final park3 = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.42, size.height * 0.64, size.width * 0.52, size.height * 0.32),
        const Radius.circular(44),
      ));
    canvas.drawPath(park3, parkPaint);

    final riverPaint = Paint()
      ..color = const Color(0xFFA6D9D0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round;

    final riverPath = Path()
      ..moveTo(size.width * 0.12, 0)
      ..cubicTo(
        size.width * 0.28, size.height * 0.32,
        size.width * 0.14, size.height * 0.62,
        size.width * 0.46, size.height,
      );
    canvas.drawPath(riverPath, riverPaint);

    final roadBorderPaint = Paint()
      ..color = const Color(0xFFDFD7C2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;

    final roadFillPaint = Paint()
      ..color = const Color(0xFFFBF6EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width * 0.48, size.height * 0.46);

    final roadPaths = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(size.width * 0.72, size.height * 0.28)
      ..lineTo(size.width * 0.86, 0)
      ..moveTo(center.dx, center.dy)
      ..lineTo(size.width * 0.24, size.height * 0.38)
      ..lineTo(0, size.height * 0.34)
      ..moveTo(center.dx, center.dy)
      ..lineTo(size.width * 0.28, size.height * 0.68)
      ..lineTo(0, size.height * 0.86)
      ..moveTo(center.dx, center.dy)
      ..lineTo(size.width * 0.62, size.height * 0.68)
      ..lineTo(size.width * 0.84, size.height)
      ..moveTo(center.dx, center.dy)
      ..lineTo(size.width, size.height * 0.54)
      ..moveTo(center.dx, center.dy)
      ..lineTo(size.width * 0.44, 0);

    canvas.drawPath(roadPaths, roadBorderPaint);
    canvas.drawPath(roadPaths, roadFillPaint);

    final minorBorderPaint = Paint()
      ..color = const Color(0xFFE5DEC8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9;
    final minorFillPaint = Paint()
      ..color = const Color(0xFFFBF6EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    final minorPaths = Path()
      ..moveTo(size.width * 0.24, size.height * 0.38)
      ..lineTo(size.width * 0.42, size.height * 0.16)
      ..lineTo(size.width * 0.72, size.height * 0.28)
      ..moveTo(size.width * 0.28, size.height * 0.68)
      ..lineTo(size.width * 0.62, size.height * 0.68);

    canvas.drawPath(minorPaths, minorBorderPaint);
    canvas.drawPath(minorPaths, minorFillPaint);

    canvas.drawCircle(center, 13, Paint()..color = const Color(0xFFDFD7C2));
    canvas.drawCircle(center, 10, Paint()..color = const Color(0xFFFBF6EB));
    canvas.drawCircle(center, 4, Paint()..color = const Color(0xFF498877));

    _drawTree(canvas, Offset(size.width * 0.15, size.height * 0.15));
    _drawTree(canvas, Offset(size.width * 0.24, size.height * 0.13));
    _drawTree(canvas, Offset(size.width * 0.78, size.height * 0.21));
    _drawTree(canvas, Offset(size.width * 0.74, size.height * 0.36));
    _drawTree(canvas, Offset(size.width * 0.12, size.height * 0.53));
    _drawTree(canvas, Offset(size.width * 0.58, size.height * 0.83));

    _drawHighwayBadge(canvas, Offset(size.width * 0.22, size.height * 0.24), '18');
  }

  void _drawTree(Canvas canvas, Offset pos) {
    final foliage = Paint()..color = const Color(0xFF3F7F70);
    final trunk = Paint()..color = const Color(0xFF8D735C)..strokeWidth = 2;
    canvas.drawLine(pos, Offset(pos.dx, pos.dy + 8), trunk);

    final path = Path()
      ..moveTo(pos.dx, pos.dy - 6)
      ..lineTo(pos.dx - 6, pos.dy + 2)
      ..lineTo(pos.dx + 6, pos.dy + 2)
      ..close()
      ..moveTo(pos.dx, pos.dy - 2)
      ..lineTo(pos.dx - 8, pos.dy + 6)
      ..lineTo(pos.dx + 8, pos.dy + 6)
      ..close();
    canvas.drawPath(path, foliage);
  }

  void _drawHighwayBadge(Canvas canvas, Offset pos, String number) {
    final rect = Rect.fromCenter(center: pos, width: 22, height: 16);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = const Color(0xFF2E7D32),
    );
    final textPainter = TextPainter(
      text: TextSpan(
        text: number,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(pos.dx - textPainter.width / 2, pos.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _AruaMapPainter oldDelegate) =>
      oldDelegate.selectedPointId != selectedPointId;
}

class _PadCareSplashScreen extends StatelessWidget {
  const _PadCareSplashScreen({this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8F6),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF35B9B4), Color(0xFFA5EAC5)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              if (onClose != null)
                Positioned(
                  top: 14,
                  right: 14,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: _ink),
                    onPressed: onClose,
                  ),
                ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x281B434D),
                            blurRadius: 28,
                            offset: Offset(0, 14),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: Image.asset(
                          'assets/icon/app_icon.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'PadCare',
                      style: TextStyle(
                        color: Color(0xFF172B36),
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Care within reach.',
                      style: TextStyle(
                        color: Color(0xFF116B78),
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 52),
                    const SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        strokeWidth: 3.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2EA8B6)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocalOnlyNotice extends StatelessWidget {
  const _LocalOnlyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E7),
        border: Border.all(color: const Color(0xFFF0D5B7)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Saved on this device for up to 30 days. It appears in the teacher preview on this device only; it is not sent over the network. Storage is not encrypted.',
        style: TextStyle(color: Color(0xFF754519), fontSize: 12, height: 1.45),
      ),
    );
  }
}

class _LocalRequestCard extends StatelessWidget {
  const _LocalRequestCard({
    super.key,
    required this.request,
    required this.onDelete,
  });

  final _LocalRequest request;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final created = DateTime.tryParse(request.createdAt)?.toLocal();
    final date = created == null
        ? ''
        : '${created.day.toString().padLeft(2, '0')}/${created.month.toString().padLeft(2, '0')}/${created.year}';
    final unit = switch (request.product) {
      'Reusable pads' => 'kits',
      'Soap' => 'bars',
      _ => 'packs',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(15, 14, 8, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.save_outlined, color: _green, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Request ${request.reference}',
                  style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text('${request.quantity} $unit of ${request.product}'),
                const SizedBox(height: 4),
                Text(
                  request.status,
                  style: const TextStyle(color: _green, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pickup: ${request.school} (${request.area})',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  '${PadCareBackend.isSignedIn ? 'Online account · sync status may vary' : 'Not sent over network'}${date.isEmpty ? '' : '  ·  $date'}',
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          ),
          if (request.status == 'Pending review')
            IconButton(
              tooltip: 'Delete saved request',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
              style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _PickupPointCard extends StatelessWidget {
  const _PickupPointCard({
    required this.area,
    required this.school,
    required this.onTap,
  });

  final String area;
  final String school;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _greenPale,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: const ValueKey('pickup-point-details'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: _green.withValues(alpha: 0.12)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.location_on_outlined, color: _green),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pickup school for $area',
                      style: const TextStyle(
                        color: _green,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      school,
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.info_outline_rounded, color: _green, size: 19),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageScroll extends StatelessWidget {
  const _PageScroll({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
  }
}

class _FacilityHeader extends StatelessWidget {
  const _FacilityHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            color: _green,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          title,
          style: const TextStyle(
            color: _ink,
            fontSize: 25,
            height: 1.2,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(subtitle, style: const TextStyle(color: _muted, fontSize: 13)),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: _ink,
        fontSize: 17,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _ImpactStrip extends StatelessWidget {
  const _ImpactStrip({required this.requests, required this.lowStock});

  final int requests;
  final int lowStock;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _green,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.volunteer_activism_outlined,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$requests requests supported this month',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  lowStock == 0
                      ? 'All supplies are above the low-stock mark'
                      : '$lowStock supply type${lowStock == 1 ? '' : 's'} need attention',
                  style: const TextStyle(
                    color: Color(0xFFDDECE5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            color: Colors.white70,
            size: 16,
          ),
        ],
      ),
    );
  }
}

class _StockSummaryRow extends StatelessWidget {
  const _StockSummaryRow({required this.supply});

  final _Supply supply;

  @override
  Widget build(BuildContext context) {
    final available = supply.onHand - supply.reserved;
    final low = available <= supply.lowAt;
    final ratio = (available / (supply.lowAt * 2.5)).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 37,
            height: 37,
            decoration: BoxDecoration(
              color: low ? const Color(0xFFFFE8DE) : _greenPale,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              color: low ? _coral : _green,
              size: 19,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  supply.name,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 5,
                    backgroundColor: const Color(0xFFE8EBE6),
                    color: low ? _coral : _green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$available ${supply.unit} available',
            style: TextStyle(
              color: low ? _coral : _ink,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.request});

  final _LocalRequest request;

  @override
  Widget build(BuildContext context) {
    final approved = request.status == 'Approved' ||
      request.status == 'Ready for pickup' ||
      request.status == 'Collected';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: approved ? _greenPale : const Color(0xFFFFF0E7),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              approved ? Icons.check_rounded : Icons.schedule_rounded,
              color: approved ? _green : const Color(0xFF9A5A24),
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${request.quantity} ${request.product.toLowerCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${request.school}  ·  ${request.status}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            request.status,
            style: TextStyle(
              color: approved ? _green : const Color(0xFF9A5A24),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherRequestCard extends StatelessWidget {
  const _TeacherRequestCard({
    required this.request,
    required this.available,
    required this.onApprove,
    required this.onDecline,
    required this.onReady,
    required this.onCollect,
  });

  final _LocalRequest request;
  final int available;
  final VoidCallback onApprove;
  final VoidCallback onDecline;
  final VoidCallback onReady;
  final VoidCallback onCollect;

  @override
  Widget build(BuildContext context) {
    final unit = switch (request.product) {
      'Reusable pads' => 'kits',
      'Soap' => 'bars',
      _ => 'packs',
    };
    final actions = switch (request.status) {
      'Pending review' => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            key: ValueKey('approve-request-${request.id}'),
            onPressed: onApprove,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Approve'),
          ),
          TextButton.icon(
            key: ValueKey('decline-request-${request.id}'),
            onPressed: onDecline,
            icon: const Icon(Icons.close_rounded),
            label: const Text('Decline'),
          ),
        ],
      ),
      'Approved' => FilledButton.icon(
        key: ValueKey('ready-request-${request.id}'),
        onPressed: onReady,
        icon: const Icon(Icons.inventory_2_outlined),
        label: const Text('Mark ready for pickup'),
      ),
      'Ready for pickup' => FilledButton.icon(
        key: ValueKey('collect-request-${request.id}'),
        onPressed: onCollect,
        icon: const Icon(Icons.done_all_rounded),
        label: const Text('Mark collected'),
      ),
      _ => Text(
        request.status,
        style: const TextStyle(color: _muted, fontWeight: FontWeight.w700),
      ),
    };

    return Container(
      key: ValueKey('teacher-request-${request.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_outlined, color: _green, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Request ${request.reference}',
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                request.status,
                style: const TextStyle(
                  color: _green,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${request.quantity} $unit of ${request.product}',
            style: const TextStyle(color: _ink, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            '${request.area} pickup area  ·  ${request.createdAt.substring(0, 10)}',
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
          if (request.status == 'Pending review' ||
              request.status == 'Approved') ...[
            const SizedBox(height: 8),
            Text(
              '$available $unit available after other reservations',
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          actions,
        ],
      ),
    );
  }
}

class _LowStockBanner extends StatelessWidget {
  const _LowStockBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEE6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0D0C0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: _coral),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count item${count == 1 ? '' : 's'} below the restock threshold',
              style: const TextStyle(
                color: Color(0xFF873E2C),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InStockBanner extends StatelessWidget {
  const _InStockBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _greenPale,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_outline_rounded, color: _green),
          SizedBox(width: 10),
          Text(
            'All supply types are above threshold',
            style: TextStyle(
              color: _green,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _StockManagementCard extends StatelessWidget {
  const _StockManagementCard({
    required this.supply,
    required this.onDecrease,
    required this.onIncrease,
    required this.onEdit,
  });

  final _Supply supply;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final low = supply.onHand - supply.reserved <= supply.lowAt;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 8, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      supply.name,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Restock alert at ${supply.lowAt} ${supply.unit}',
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
                style: TextButton.styleFrom(foregroundColor: _green),
              ),
            ],
          ),
          const Divider(height: 18, color: _line),
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${supply.onHand}',
                        style: TextStyle(
                          color: low ? _coral : _ink,
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(
                        text: ' ${supply.unit} on hand',
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove one ${supply.unit}',
                onPressed: onDecrease,
                icon: const Icon(Icons.remove_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF0F2EE),
                  foregroundColor: _ink,
                  fixedSize: const Size(40, 40),
                ),
              ),
              const SizedBox(width: 5),
              IconButton(
                tooltip: 'Add one ${supply.unit}',
                onPressed: onIncrease,
                icon: const Icon(Icons.add_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: _greenPale,
                  foregroundColor: _green,
                  fixedSize: const Size(40, 40),
                ),
              ),
            ],
          ),
          if (supply.reserved > 0)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${supply.reserved} ${supply.unit} reserved  ·  ${supply.onHand - supply.reserved} available',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AggregateNotice extends StatelessWidget {
  const _AggregateNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _greenPale,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.visibility_outlined, color: _green, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Partner view shows combined supply needs across facilities, never individual requests.',
              style: TextStyle(color: _green, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 108),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: _ink,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
        ],
      ),
    );
  }
}

class _DemandBar extends StatelessWidget {
  const _DemandBar({
    required this.label,
    required this.amount,
    required this.value,
  });

  final String label;
  final String amount;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(amount, style: const TextStyle(color: _muted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: const Color(0xFFE5E9E3),
              color: _green,
            ),
          ),
        ],
      ),
    );
  }
}

class _NeedRow extends StatelessWidget {
  const _NeedRow({
    required this.facility,
    required this.need,
    required this.gap,
    required this.urgent,
  });

  final String facility;
  final String need;
  final String gap;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            urgent ? Icons.priority_high_rounded : Icons.location_on_outlined,
            color: urgent ? _coral : _green,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  facility,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(need, style: const TextStyle(color: _muted, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            gap,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: urgent ? _coral : _ink,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: _ink,
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
    );
  }
}

class _ProductChoice extends StatelessWidget {
  const _ProductChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      labelStyle: TextStyle(
        color: selected ? _green : _ink,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      backgroundColor: Colors.white,
      selectedColor: _greenPale,
      side: BorderSide(color: selected ? _green : _line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}

class _QuantityControl extends StatelessWidget {
  const _QuantityControl({
    required this.value,
    required this.unit,
    required this.onChanged,
  });

  final int value;
  final String unit;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Decrease quantity',
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          Expanded(
            child: Semantics(
              container: true,
              excludeSemantics: true,
              liveRegion: true,
              label: 'Quantity: $value $unit',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: Text(
                      '$value',
                      key: ValueKey(value),
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      unit,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Increase quantity',
            onPressed: () => onChanged(value + 1),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}
