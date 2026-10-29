import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/firebase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.initialize();
  runApp(const MyApp());
}

const _ink = Color(0xFF172B36);
const _muted = Color(0xFF6B8487);
const _paper = Color(0xFFF7FCFA);
const _green = Color(0xFF35B9B4);
const _deepTeal = Color(0xFF116B78);
const _mint = Color(0xFFA5EAC5);
const _greenPale = Color(0xFFE4F8F2);
const _coral = Color(0xFF0D9488);
const _line = Color(0xFFDCECEB);

const _fontHeading = 'SF Pro Display';
const _fontSubheading = 'SF Pro Display';
const _fontBody = 'SF Pro Display';

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
        fontFamily: _fontBody,
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontFamily: _fontHeading),
          displayMedium: TextStyle(fontFamily: _fontHeading),
          displaySmall: TextStyle(fontFamily: _fontHeading),
          headlineLarge: TextStyle(fontFamily: _fontHeading),
          headlineMedium: TextStyle(fontFamily: _fontHeading),
          headlineSmall: TextStyle(fontFamily: _fontHeading),
          titleLarge: TextStyle(fontFamily: _fontSubheading),
          titleMedium: TextStyle(fontFamily: _fontSubheading),
          titleSmall: TextStyle(fontFamily: _fontSubheading),
          bodyLarge: TextStyle(fontFamily: _fontBody),
          bodyMedium: TextStyle(fontFamily: _fontBody),
          bodySmall: TextStyle(fontFamily: _fontBody),
        ),
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
    return const AccessGate();
  }
}

enum _PortalRole { teacher, parent }

enum _AuthTab { signUp, login, guest }

class AccessGate extends StatefulWidget {
  const AccessGate({super.key});

  @override
  State<AccessGate> createState() => _AccessGateState();
}

class _AccessGateState extends State<AccessGate> {
  final _formKey = GlobalKey<FormState>();
  final _loginFormKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _newSchoolController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final List<String> _schoolOptions = [..._staffFacilities];

  _AuthTab _currentTab = MyApp.isTestMode ? _AuthTab.signUp : _AuthTab.login;
  _PortalRole? _role;
  bool _registering = false;
  bool _addingSchool = false;
  bool _obscurePassword = true;
  String _school = 'St. Mary\'s Secondary';

  @override
  void dispose() {
    _nameController.dispose();
    _newSchoolController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    final result = await AuthService.signIn(
      email: email.isEmpty ? 'guest@padcare.org' : email,
      password: password.isEmpty ? 'padcare123' : password,
    );

    if (!mounted) return;

    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Login failed'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final navigator = Navigator.of(context);
    void onSignOut() {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const AccessGate()),
        (route) => false,
      );
    }

    if (email.toLowerCase().contains('teacher') || _role == _PortalRole.teacher) {
      navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => HomeScreen(facility: _school, onSignOut: onSignOut),
        ),
      );
    } else {
      navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ParentHomeScreen(
            parentName: email.isNotEmpty ? email.split('@').first : 'Amina N.',
            onSignOut: onSignOut,
          ),
        ),
      );
    }
  }

  void _enterAsGuest() {
    final navigator = Navigator.of(context);
    void onSignOut() {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const AccessGate()),
        (route) => false,
      );
    }

    navigator.pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ParentHomeScreen(
          parentName: 'Guest Community Member',
          onSignOut: onSignOut,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 960;

    return Scaffold(
      backgroundColor: const Color(0xFF0F4D57),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 20 : 12,
              vertical: isWide ? 16 : 10,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 1040,
                minHeight: isWide ? 620 : 0,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(isWide ? 36 : 24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x38000000),
                      blurRadius: 36,
                      offset: Offset(0, 16),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: isWide
                    ? IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 6,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                                child: _buildLeftContent(),
                              ),
                            ),
                            const Expanded(
                              flex: 5,
                              child: Padding(
                                padding: EdgeInsets.all(14),
                                child: _AuthArtCard(),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(20),
                        child: _buildLeftContent(),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeftContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _BrandLockup(),
        const SizedBox(height: 18),
        _buildTabBar(),
        const SizedBox(height: 12),
        _softTransition(
          key: ValueKey('tab-${_currentTab.name}-${_role?.name ?? 'norole'}'),
          child: _buildTabBody(),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _buildTabItem(label: 'Sign Up', tab: _AuthTab.signUp),
          _buildTabItem(label: 'Login', tab: _AuthTab.login),
          _buildTabItem(label: 'Enter as Guest', tab: _AuthTab.guest),
        ],
      ),
    );
  }

  Widget _buildTabItem({required String label, required _AuthTab tab}) {
    final isSelected = _currentTab == tab;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _currentTab = tab;
            if (tab != _AuthTab.signUp) {
              _role = null;
            }
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? _deepTeal : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x33116B78),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF475569),
              fontWeight: FontWeight.w700,
              fontSize: 13,
              fontFamily: _fontSubheading,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBody() {
    switch (_currentTab) {
      case _AuthTab.signUp:
        return _role == null ? _buildRolePicker() : _buildAccessForm();
      case _AuthTab.login:
        return _buildLoginView();
      case _AuthTab.guest:
        return _buildGuestView();
    }
  }

  Widget _buildRolePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose your PadCare access',
          style: TextStyle(
            color: _ink,
            fontSize: 25,
            height: 1.2,
            fontWeight: FontWeight.w800,
            fontFamily: _fontHeading,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Explore PadCare as a school staff member or as a parent or guardian.',
          style: TextStyle(color: _muted, height: 1.5, fontFamily: _fontBody),
        ),
        const SizedBox(height: 20),
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
        const SizedBox(height: 18),
        const _PrivacyNote(
          text: 'Requests do not ask for a girl\'s name, age, or class.',
        ),
        const SizedBox(height: 18),
        Center(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => ParentHomeScreen(
                    parentName: 'Amina N.',
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
              foregroundColor: _deepTeal,
              side: const BorderSide(color: _deepTeal),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Already have an account? ',
                style: TextStyle(color: _muted, fontSize: 13, fontFamily: _fontBody),
              ),
              TextButton(
                onPressed: () => setState(() => _currentTab = _AuthTab.login),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: _deepTeal,
                ),
                child: const Text(
                  'Login',
                  style: TextStyle(fontWeight: FontWeight.w700, fontFamily: _fontSubheading),
                ),
              ),
            ],
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
            style: TextButton.styleFrom(foregroundColor: _deepTeal),
          ),
          const SizedBox(height: 12),
          Text(
            '${isTeacher ? 'Teacher' : 'Parent'} preview${_registering ? ' setup' : ''}',
            style: const TextStyle(
              color: _ink,
              fontSize: 25,
              fontWeight: FontWeight.w800,
              fontFamily: _fontHeading,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isTeacher
                ? 'Preview only. Choose a sample school or distribution point.'
                : 'Preview only. Requests stay on this device and are not sent to a school.',
            style: const TextStyle(color: _muted, height: 1.45, fontFamily: _fontBody),
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
                isExpanded: true,
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
            style: FilledButton.styleFrom(
              backgroundColor: _deepTeal,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              'Open $roleLabel preview',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontFamily: _fontSubheading,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _registering = !_registering),
              child: Text(
                _registering ? 'Back to preview' : 'Set a display name',
                style: const TextStyle(fontFamily: _fontSubheading),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'No account is created. Preview data is not shared with a school.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 11, height: 1.4, fontFamily: _fontBody),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginView() {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text(
            'Welcome back',
            style: TextStyle(
              color: _ink,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              fontFamily: _fontHeading,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Sign in to access school stock and request management.',
            style: TextStyle(
              color: _muted,
              fontSize: 14,
              fontFamily: _fontBody,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            key: const ValueKey('login-email'),
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email address',
              hintText: 'teacher@school.org or parent@gmail.com',
              prefixIcon: const Icon(Icons.mail_outline_rounded, color: _deepTeal, size: 20),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _deepTeal, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('login-password'),
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your password',
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: _deepTeal, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: _muted,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _deepTeal, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password reset instructions sent if email exists.')),
                );
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Forgot password?',
                style: TextStyle(
                  color: _deepTeal,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: _fontSubheading,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              key: const ValueKey('submit-login'),
              onPressed: _handleLogin,
              style: FilledButton.styleFrom(
                backgroundColor: _deepTeal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'Login',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFamily: _fontSubheading,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Don\'t have an account? ',
                  style: TextStyle(color: _muted, fontSize: 13, fontFamily: _fontBody),
                ),
                TextButton(
                  onPressed: () => setState(() => _currentTab = _AuthTab.signUp),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: _deepTeal,
                  ),
                  child: const Text(
                    'Sign Up',
                    style: TextStyle(fontWeight: FontWeight.w700, fontFamily: _fontSubheading),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.explore_rounded,
              color: _deepTeal,
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Center(
          child: Text(
            'Guest Access',
            style: TextStyle(
              color: _ink,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              fontFamily: _fontHeading,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text(
            'No signup or password required to browse and request supplies.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _muted,
              fontSize: 14,
              height: 1.4,
              fontFamily: _fontBody,
            ),
          ),
        ),
        const SizedBox(height: 14),
        const _PrivacyNote(
          text: 'Requests do not ask for a girl\'s name, age, or class.',
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: _enterAsGuest,
            icon: const Icon(Icons.home_outlined),
            label: const Text(
              'Enter PadCare Directly',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                fontFamily: _fontSubheading,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _deepTeal,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _currentTab = _AuthTab.signUp;
                _role = _PortalRole.teacher;
              });
            },
            icon: const Icon(Icons.school_outlined, size: 18),
            label: const Text('Try Teacher Demo Access'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _deepTeal,
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Want to register your school or account? ',
                style: TextStyle(color: _muted, fontSize: 13, fontFamily: _fontBody),
              ),
              TextButton(
                onPressed: () => setState(() => _currentTab = _AuthTab.signUp),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: _deepTeal,
                ),
                child: const Text(
                  'Sign Up',
                  style: TextStyle(fontWeight: FontWeight.w700, fontFamily: _fontSubheading),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AuthArtCard extends StatelessWidget {
  const _AuthArtCard();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
        ),
        child: CustomPaint(
          painter: const _WaveArtPainter(),
          child: Stack(
            children: [
              Positioned(
                top: 24,
                left: 24,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0x1FFFFFFF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0x33FFFFFF),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Safe • Free • Anonymous',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFamily: _fontSubheading,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 32,
                left: 28,
                right: 28,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pads within reach,\nfor every student.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                        fontFamily: _fontHeading,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Connecting community pickup points with care and privacy across Arua City.',
                      style: TextStyle(
                        color: const Color(0xBFFFFFFF),
                        fontSize: 14,
                        height: 1.45,
                        fontFamily: _fontBody,
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

class _WaveArtPainter extends CustomPainter {
  const _WaveArtPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1. Base deep midnight-blue to indigo background
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF090D24),
          Color(0xFF0F1B4C),
          Color(0xFF1E3A8A),
          Color(0xFF080D21),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // 2. Glowing back wave (violet / royal blue)
    final backWave = Path();
    backWave.moveTo(0, size.height * 0.28);
    backWave.cubicTo(
      size.width * 0.35, size.height * 0.15,
      size.width * 0.65, size.height * 0.52,
      size.width, size.height * 0.38,
    );
    backWave.lineTo(size.width, size.height);
    backWave.lineTo(0, size.height);
    backWave.close();

    final backPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF2563EB),
          Color(0xFF1D4ED8),
          Color(0xFF0A1033),
        ],
      ).createShader(rect);
    canvas.drawPath(backWave, backPaint);

    // 3. Smooth curving deep blue 3D valley wave
    final midWave = Path();
    midWave.moveTo(0, size.height * 0.55);
    midWave.cubicTo(
      size.width * 0.28, size.height * 0.32,
      size.width * 0.72, size.height * 0.72,
      size.width, size.height * 0.48,
    );
    midWave.lineTo(size.width, size.height);
    midWave.lineTo(0, size.height);
    midWave.close();

    final midPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF1E40AF),
          Color(0xFF172554),
          Color(0xFF030712),
        ],
      ).createShader(rect);
    canvas.drawPath(midWave, midPaint);

    // 4. Foreground smooth wave contour
    final foreWave = Path();
    foreWave.moveTo(0, size.height * 0.72);
    foreWave.cubicTo(
      size.width * 0.4, size.height * 0.52,
      size.width * 0.68, size.height * 0.85,
      size.width, size.height * 0.65,
    );
    foreWave.lineTo(size.width, size.height);
    foreWave.lineTo(0, size.height);
    foreWave.close();

    final forePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF1E3A8A),
          Color(0xFF0A0F29),
        ],
      ).createShader(rect);
    canvas.drawPath(foreWave, forePaint);

    // 5. Glowing lavender/lilac rim edge
    final rimPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Color(0xFFC7D2FE),
          Color(0xFFA5B4FC),
          Color(0xFF6366F1),
          Colors.transparent,
        ],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    final rimPath = Path();
    rimPath.moveTo(0, size.height * 0.55);
    rimPath.cubicTo(
      size.width * 0.28, size.height * 0.32,
      size.width * 0.72, size.height * 0.72,
      size.width, size.height * 0.48,
    );
    canvas.drawPath(rimPath, rimPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
      mainAxisSize: MainAxisSize.min,
      children: [
        _BrandMark(),
        SizedBox(width: 8),
        Text(
          'PadCare',
          style: TextStyle(
            color: _ink,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            fontFamily: _fontHeading,
          ),
        ),
        SizedBox(width: 8),
        Text(
          'ARUA CITY',
          style: TextStyle(
            color: _muted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            fontFamily: _fontSubheading,
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
      if (!mounted) return;
      setState(() {
        _requests = data.requests;
        for (final supply in _supplies) {
          supply.onHand =
              data.stock[_stockKey(widget.facility, supply.name)] ??
              supply.onHand;
          supply.reserved = _reservedFor(supply.name);
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
      unawaited(
        FirestoreService.updateSchoolStock(
          schoolName: widget.facility,
          kitsOnHand: stock[_stockKey(widget.facility, 'Emergency period kits')] ?? 0,
          packsOnHand: stock[_stockKey(widget.facility, 'Disposable pad packs')] ?? 0,
        ),
      );
      if (!mounted) return;
      setState(() => supply.onHand = quantity);
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
      unawaited(FirestoreService.updateRequestStatus(request.id, status));
      if (!mounted) return;
      setState(() {
        _requests = updatedRequests;
        if (status == 'Collected') supply.onHand -= request.quantity;
        for (final item in _supplies) {
          item.reserved = _reservedFor(item.name, requests: updatedRequests);
        }
      });
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
        const _PrivacyNote(
          text: 'Preview only: staff identity is not verified, and requests and stock are stored on this device.',
        ),
        const SizedBox(height: 20),
        _ImpactStrip(
          requests: _facilityRequests.length,
          lowStock: _lowStockCount,
        ),
        const SizedBox(height: 14),
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
        const _PrivacyNote(
          text: 'Preview only: staff identity is not verified. This inbox is only visible on this device.',
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
        const _PrivacyNote(
          text: 'Preview only: staff identity is not verified. Stock changes are stored on this device.',
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
        const SizedBox(height: 14),
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
    this.phone = '+256 772 100 200',
    this.lastUpdated = 'Today at 09:00 AM',
  });

  final String id;
  final String name;
  final String category;
  final String area;
  final double distanceKm;
  final String hours;
  final bool inStock;
  final bool isVerified;
  final String directions;
  final Offset mapOffsetPercent;
  final String pinLabel;
  final String supplies;
  final String instructions;
  final String phone;
  final String lastUpdated;
}

const _kSupportPoints = <_SupportPoint>[
  _SupportPoint(
    id: 'muni-clinic',
    name: 'Muni Health Centre IV',
    category: 'Clinics',
    area: 'Muni',
    distanceKm: 0.8,
    hours: 'Open until 5:00 PM',
    inStock: true,
    isVerified: true,
    directions: 'Muni Junction, Rhinocamp Rd',
    mapOffsetPercent: Offset(0.42, 0.42),
    pinLabel: 'Clinic',
    supplies: 'Disposable & Reusable pads',
    instructions: 'Report to outpatient clinic room 3. Supplies provided immediately with discretion.',
    phone: '+256 772 450 119',
    lastUpdated: 'Today at 08:30 AM',
  ),
  _SupportPoint(
    id: 'arua-hospital',
    name: 'Arua Regional Referral Hospital',
    category: 'Clinics',
    area: 'Arua Central',
    distanceKm: 1.1,
    hours: 'Open 24/7',
    inStock: true,
    isVerified: true,
    directions: 'Directions, & conflow',
    mapOffsetPercent: Offset(0.50, 0.48),
    pinLabel: 'Clinic',
    supplies: 'Emergency hospital stock',
    instructions: 'Maternity & Youth Friendly Corner. Open 24/7 with trained female nursing staff.',
    phone: '+256 476 420 021',
    lastUpdated: 'Today at 09:15 AM',
  ),
  _SupportPoint(
    id: 'ediofe-school',
    name: 'Ediofe Girls School',
    category: 'Schools',
    area: 'Ediofe',
    distanceKm: 1.4,
    hours: 'Open until 4:30 PM',
    inStock: true,
    isVerified: true,
    directions: 'Ediofe Mission Road',
    mapOffsetPercent: Offset(0.63, 0.42),
    pinLabel: 'School',
    supplies: 'Reusable pad kits & disposable',
    instructions: 'Senior Woman Teacher office near the administration block.',
    phone: '+256 782 300 812',
    lastUpdated: 'Yesterday at 04:00 PM',
  ),
  _SupportPoint(
    id: 'st-marys-school',
    name: 'St. Mary\'s Secondary',
    category: 'Schools',
    area: 'Arua Hill',
    distanceKm: 2.0,
    hours: 'Open until 5:00 PM',
    inStock: true,
    isVerified: true,
    directions: 'Arua Hill Avenue',
    mapOffsetPercent: Offset(0.42, 0.55),
    pinLabel: 'School',
    supplies: 'Kits & packs for pickup',
    instructions: 'School health liaison office. Parent & student collections welcome.',
    phone: '+256 774 912 345',
    lastUpdated: 'Today at 10:00 AM',
  ),
  _SupportPoint(
    id: 'ceford-ngo',
    name: 'CEFORD Community Centre',
    category: 'NGOs',
    area: 'Arua Central',
    distanceKm: 1.8,
    hours: 'Open until 5:00 PM',
    inStock: true,
    isVerified: true,
    directions: 'Catholic Diocese, Central',
    mapOffsetPercent: Offset(0.61, 0.55),
    pinLabel: 'Collect',
    supplies: 'Emergency distribution hub',
    instructions: 'Community empowerment desk, ground floor reception.',
    phone: '+256 476 422 555',
    lastUpdated: 'Today at 11:30 AM',
  ),
  _SupportPoint(
    id: 'oli-primary',
    name: 'Oli Primary School',
    category: 'Schools',
    area: 'Oli',
    distanceKm: 2.5,
    hours: 'Open until 4:00 PM',
    inStock: true,
    isVerified: true,
    directions: 'Oli Division Road',
    mapOffsetPercent: Offset(0.61, 0.60),
    pinLabel: 'School',
    supplies: 'School stock & parent pickups',
    instructions: 'Staffroom counseling corner, ask for Senior Woman Teacher.',
    phone: '+256 752 118 900',
    lastUpdated: 'Today at 07:45 AM',
  ),
];

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  int _selectedIndex = 0;
  _SupportSubTab _supportSubTab = _SupportSubTab.requestForm;
  _SupportPoint _selectedMapPoint = _kSupportPoints[1];
  bool _mapViewMode = true;
  String _selectedCategory = 'All';
  String _selectedMapFilter = 'Open Now';
  String _selectedArea = 'Arua Central';
  String _selectedProduct = 'Disposable pads';
  int _quantity = 4;
  List<_LocalRequest> _localRequests = [];
  bool _loadingRequests = true;
  bool _savingRequest = false;
  bool _requestStorageFailed = false;

  final TextEditingController _homeSearchController = TextEditingController();
  final TextEditingController _mapSearchController = TextEditingController();
  String _homeSearchQuery = '';
  String _mapSearchQuery = '';

  final Set<String> _favoritePointIds = {'muni-clinic'};
  String _userDisplayName = '';
  String _selectedLearnCategory = 'All';

  @override
  void initState() {
    super.initState();
    _userDisplayName = widget.parentName;
    _loadLocalRequests();
  }

  @override
  void dispose() {
    _homeSearchController.dispose();
    _mapSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadLocalRequests() async {
    try {
      final localData = await _readLocalData();
      if (!mounted) return;
      setState(() {
        _localRequests = localData.requests;
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

  String get _pickupSchool {
    final areaKey = _selectedArea == 'Arua Central' ? 'Oli' : _selectedArea;
    return _pickupSchoolsByArea[areaKey] ?? 'Oli Primary School';
  }

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
      area: _selectedArea == 'Arua Central' ? 'Ediofe' : _selectedArea,
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
      unawaited(FirestoreService.saveRequest(request.toJson()));
      if (!mounted) return;
      setState(() {
        _localRequests = updatedRequests;
        _savingRequest = false;
        _selectedIndex = 3;
        _supportSubTab = _SupportSubTab.activity;
      });
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
      unawaited(FirestoreService.saveRequest(request.toJson()));
      if (!mounted) return;
      setState(() => _localRequests = updatedRequests);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete this saved request.')),
      );
    }
  }

  void _showFacilityDetails(_SupportPoint point) {
    final isFav = _favoritePointIds.contains(point.id);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD3DFDC),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              if (point.isVerified) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${point.category}  ·  ${point.area}  ·  ${point.distanceKm} km away',
                            style: const TextStyle(color: _muted, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isFav ? const Color(0xFFE11D48) : _muted,
                      ),
                      onPressed: () {
                        setState(() {
                          if (isFav) {
                            _favoritePointIds.remove(point.id);
                          } else {
                            _favoritePointIds.add(point.id);
                          }
                        });
                        setSheetState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isFav ? 'Removed from saved places' : 'Saved to favorites!'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F9F7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFD6EAE5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule_rounded, color: _deepTeal, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        point.hours,
                        style: const TextStyle(color: _ink, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF7EE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          point.inStock ? '● In Stock' : '● Limited Stock',
                          style: const TextStyle(
                            color: Color(0xFF16A34A),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Current Supplies On-Site',
                  style: TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE4F0EE)),
                  ),
                  child: Column(
                    children: [
                      _buildSupplyInventoryItem('Disposable Pads (10/pack)', '78 packs', true),
                      const Divider(height: 16, color: Color(0xFFEBF3F1)),
                      _buildSupplyInventoryItem('Reusable Pad Kits (4/kit)', '35 kits', true),
                      const Divider(height: 16, color: Color(0xFFEBF3F1)),
                      _buildSupplyInventoryItem('Hygiene & Antiseptic Soap', '24 bars', true),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Last verified: ${point.lastUpdated} by trained matron',
                          style: const TextStyle(color: _muted, fontSize: 11, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Collection & Pickup Instructions',
                  style: TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FCFA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE0EFEB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        point.instructions,
                        style: const TextStyle(color: _ink, fontSize: 13, height: 1.5),
                      ),
                      const SizedBox(height: 10),
                      const Row(
                        children: [
                          Icon(Icons.lock_outline_rounded, color: _deepTeal, size: 15),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Anonymous & free. No registration fees or personal data requested.',
                              style: TextStyle(color: _deepTeal, fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Authorized Contact',
                  style: TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE4F0EE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.phone_outlined, color: _deepTeal, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        point.phone,
                        style: const TextStyle(color: _ink, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      const Spacer(),
                      FilledButton.tonal(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Dialing ${point.phone}...')),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE4F8F2),
                          foregroundColor: _deepTeal,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Call', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _ink,
                          side: const BorderSide(color: Color(0xFFC7E0DC)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _openDirectionsSheet(point);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _deepTeal,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.directions_rounded, size: 18),
                            SizedBox(width: 6),
                            Text('Directions', style: TextStyle(fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSupplyInventoryItem(String name, String qty, bool available) {
    return Row(
      children: [
        Icon(
          available ? Icons.check_circle_outline_rounded : Icons.highlight_off_rounded,
          color: available ? const Color(0xFF16A34A) : Colors.orange,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          qty,
          style: TextStyle(
            color: available ? _ink : _muted,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _openDirectionsSheet(_SupportPoint point) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD0DFDC),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4F8F2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.directions_rounded, color: _deepTeal, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        point.name,
                        style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 17),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${point.distanceKm} km away  ·  Estimated 14 mins walk',
                        style: const TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDirectionStep('1', 'Head towards Arua Town Main Roundabout.', '250m'),
            _buildDirectionStep('2', 'Follow ${point.directions}.', '650m'),
            _buildDirectionStep('3', 'Arrive at ${point.name} entrance on your right.', '200m'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Starting live route guidance to ${point.name}...')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _deepTeal,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text(
                'Start Walking Navigation',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectionStep(String step, String desc, String dist) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: const Color(0xFFE4F8F2),
            child: Text(
              step,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _deepTeal),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(desc, style: const TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w600)),
                Text(dist, style: const TextStyle(color: _muted, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openDonationSheet() {
    int selectedAmount = 45000;
    String selectedMethod = 'MTN Mobile Money';
    final phoneController = TextEditingController(text: '+256 772 ');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(22, 16, 22, MediaQuery.of(context).viewInsets.bottom + 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD0DFDC),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Row(
                children: [
                  Text('🎁', style: TextStyle(fontSize: 22)),
                  SizedBox(width: 8),
                  Text(
                    'Donate to PadCare Project',
                    style: TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Voluntary contributions support the developer and ongoing app infrastructure (distinct from donating sanitary pads to community members).',
                style: TextStyle(color: _muted, fontSize: 12.5, height: 1.45),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _buildDonationTierWidget('1 Kit', 'UGX 15,000', 15000, selectedAmount == 15000, () => setSheetState(() => selectedAmount = 15000)),
                  const SizedBox(width: 8),
                  _buildDonationTierWidget('3 Kits', 'UGX 45,000', 45000, selectedAmount == 45000, () => setSheetState(() => selectedAmount = 45000), popular: true),
                  const SizedBox(width: 8),
                  _buildDonationTierWidget('1 Term', 'UGX 80,000', 80000, selectedAmount == 80000, () => setSheetState(() => selectedAmount = 80000)),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Payment Method',
                style: TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: ['MTN Mobile Money', 'Airtel Money', 'Card'].map((method) {
                  final isSel = selectedMethod == method;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(method),
                      selected: isSel,
                      onSelected: (_) => setSheetState(() => selectedMethod = method),
                      selectedColor: const Color(0xFFE4F8F2),
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSel ? _deepTeal : _ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                      side: BorderSide(color: isSel ? _deepTeal : const Color(0xFFD6ECE6)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: selectedMethod == 'Card' ? 'Card Number or Phone' : 'Mobile Money Phone Number',
                  prefixIcon: const Icon(Icons.payment_rounded, color: _deepTeal),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showDonationSuccessDialog(selectedAmount, selectedMethod);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _deepTeal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(
                  'Contribute UGX ${selectedAmount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDonationTierWidget(String title, String amount, int val, bool selected, VoidCallback onTap, {bool popular = false}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE4F8F2) : Colors.white,
            border: Border.all(
              color: selected ? _deepTeal : (popular ? _green : _line),
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              if (popular)
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: _deepTeal,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Popular', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                ),
              Text(
                title,
                style: TextStyle(
                  color: selected ? _deepTeal : _ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                amount,
                style: const TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDonationSuccessDialog(int amount, String method) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 30,
              backgroundColor: Color(0xFFEAF7EE),
              child: Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              'Thank You for Caring!',
              style: TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              'Your developer contribution of UGX ${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} via $method has been confirmed.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FCFA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD6ECE6)),
              ),
              child: Text(
                'Receipt ref: PC-DON-${DateTime.now().millisecondsSinceEpoch % 100000}',
                style: const TextStyle(color: _deepTeal, fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done', style: TextStyle(color: _deepTeal, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _openAreaSelector() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
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
                trailing: _selectedArea == area
                    ? const Icon(Icons.check_circle_rounded, color: _deepTeal)
                    : null,
                onTap: () {
                  setState(() => _selectedArea = area);
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
            selectedIcon: Icon(Icons.home_rounded, color: _deepTeal),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_rounded),
            selectedIcon: Icon(Icons.search_rounded, color: _deepTeal),
            label: 'Find Pads',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded, color: _deepTeal),
            label: 'Learn',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline_rounded),
            selectedIcon: Icon(Icons.favorite_rounded, color: _deepTeal),
            label: 'Support',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: _deepTeal),
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
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
              fontFamily: _fontHeading,
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
                  const Icon(Icons.location_on, size: 14, color: _deepTeal),
                  const SizedBox(width: 4),
                  Text(
                    _selectedArea,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFamily: _fontSubheading,
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
                      _userDisplayName.isEmpty ? 'PA' : _userDisplayName.substring(0, 1).toUpperCase(),
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
    final filteredPoints = _kSupportPoints.where((p) {
      if (_homeSearchQuery.isNotEmpty) {
        final q = _homeSearchQuery;
        final match = p.name.toLowerCase().contains(q) ||
            p.area.toLowerCase().contains(q) ||
            p.category.toLowerCase().contains(q) ||
            p.supplies.toLowerCase().contains(q);
        if (!match) return false;
      }
      if (_selectedCategory == 'Schools' && p.category != 'Schools') return false;
      if (_selectedCategory == 'Clinics' && p.category != 'Clinics') return false;
      if (_selectedCategory == 'NGOs' && p.category != 'NGOs') return false;
      if (_selectedCategory == 'Community' && p.category != 'Schools' && p.category != 'NGOs') return false;
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
                  fontFamily: _fontHeading,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Let\'s find the support you need.',
                style: TextStyle(
                  color: _muted,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  fontFamily: _fontBody,
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
            borderRadius: BorderRadius.circular(18),
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
                  controller: _homeSearchController,
                  onChanged: (val) => setState(() => _homeSearchQuery = val.trim().toLowerCase()),
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
                icon: const Icon(Icons.tune_rounded, color: _deepTeal, size: 20),
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
                  opacity: 0.22,
                  child: Image.asset(
                    'assets/padcare_icon.png',
                    width: 125,
                    height: 125,
                    errorBuilder: (context, error, stackTrace) => Image.asset(
                      'assets/icon/app_icon.png',
                      width: 125,
                      height: 125,
                    ),
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
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                      fontFamily: _fontHeading,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Discover nearby places offering support.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      fontFamily: _fontBody,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() => _selectedIndex = 1),
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
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, fontFamily: _fontSubheading),
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
            fontFamily: _fontHeading,
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
              const SizedBox(width: 8),
              _buildCategoryChip('📦 Other Providers'),
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
                  fontFamily: _fontHeading,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFE4F8F2),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFC8EBE1)),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Every act of care\nmakes a difference.',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _openDonationSheet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _deepTeal,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🎁', style: TextStyle(fontSize: 13)),
                    SizedBox(width: 5),
                    Text(
                      'Donate to PadCare Project',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, fontFamily: _fontSubheading),
                    ),
                  ],
                ),
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
          color: selected ? _deepTeal : _mint.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _deepTeal : const Color(0xFFDCECEB)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _ink,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            fontFamily: _fontSubheading,
          ),
        ),
      ),
    );
  }

  Widget _buildSupportPointCard(_SupportPoint point) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2EFEF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C0E383A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                              fontFamily: _fontSubheading,
                            ),
                          ),
                        ),
                        if (point.isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 17),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${point.distanceKm} km away  •  ${point.hours}',
                      style: const TextStyle(color: _muted, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF7EE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF16A34A),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            point.inStock ? 'In Stock' : 'Limited Stock',
                            style: const TextStyle(
                              color: Color(0xFF16A34A),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFE4F8F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFC7EFE4)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x102EA8B6),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: Image.asset(
                      'assets/padcare_icon.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Image.asset(
                        'assets/icon/app_icon.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _showFacilityDetails(point),
              style: OutlinedButton.styleFrom(
                foregroundColor: _deepTeal,
                side: const BorderSide(color: Color(0xFF98D7CD), width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'View Details & Instructions',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: _deepTeal,
                  fontFamily: _fontSubheading,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFindPads() {
    final filtered = _kSupportPoints.where((p) {
      if (_mapSearchQuery.isNotEmpty) {
        final q = _mapSearchQuery;
        final match = p.name.toLowerCase().contains(q) ||
            p.area.toLowerCase().contains(q) ||
            p.category.toLowerCase().contains(q) ||
            p.directions.toLowerCase().contains(q);
        if (!match) return false;
      }
      if (_selectedMapFilter == 'In Stock' && !p.inStock) return false;
      if (_selectedMapFilter == 'Verified' && !p.isVerified) return false;
      if (_selectedMapFilter == 'NGO & Clinics' && p.category != 'Clinics' && p.category != 'NGOs') return false;
      if (_selectedMapFilter == 'Schools' && p.category != 'Schools') return false;
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
                  color: const Color(0xFFE6EEEC),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _mapViewMode = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _mapViewMode ? _deepTeal : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Map',
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
                      child: GestureDetector(
                        onTap: () => setState(() => _mapViewMode = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: !_mapViewMode ? _deepTeal : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
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
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFD6ECE6)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: _muted, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _mapSearchController,
                        onChanged: (val) => setState(() => _mapSearchQuery = val.trim().toLowerCase()),
                        decoration: const InputDecoration(
                          hintText: 'Search town, school, or landmark...',
                          hintStyle: TextStyle(color: Color(0xFF88A0A2), fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE4F8F2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.tune_rounded, color: _deepTeal, size: 18),
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildMapFilterChip('Open Now'),
                    const SizedBox(width: 8),
                    _buildMapFilterChip('In Stock'),
                    const SizedBox(width: 8),
                    _buildMapFilterChip('Verified'),
                    const SizedBox(width: 8),
                    _buildMapFilterChip('NGO & Clinics'),
                    const SizedBox(width: 8),
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
                        foregroundColor: _deepTeal,
                        elevation: 3,
                        onPressed: () => setState(() => _selectedMapPoint = _kSupportPoints[1]),
                        child: const Icon(Icons.my_location_rounded, size: 20),
                      ),
                    ),
                    Positioned(
                      bottom: 185,
                      right: 14,
                      child: FloatingActionButton.small(
                        heroTag: 'navigate-map',
                        backgroundColor: Colors.white,
                        foregroundColor: _deepTeal,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _deepTeal : _mint.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? _deepTeal : const Color(0xFFD0E6E2)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _ink,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildMapBottomCard(_SupportPoint point) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F0E383A),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD0DFDC),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  point.name,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
              ),
              if (point.isVerified) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF7EE),
                    borderRadius: BorderRadius.circular(14),
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
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.directions_rounded, color: _muted, size: 16),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            point.directions,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _muted, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.near_me_outlined, color: _muted, size: 15),
                        const SizedBox(width: 6),
                        Text(
                          '${point.distanceKm} km away',
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
                          point.inStock ? 'In Stock' : 'Limited',
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
              const SizedBox(width: 12),
              Column(
                children: [
                  ElevatedButton(
                    onPressed: () => _openDirectionsSheet(point),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _deepTeal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                    ),
                    child: const Text(
                      'Get Directions',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => _showFacilityDetails(point),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _deepTeal,
                      side: const BorderSide(color: _deepTeal, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                    ),
                    child: const Text(
                      'Details & Hours',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLearn() {
    final articles = [
      _LearnArticle(
        tag: 'Essential Guide',
        category: 'Cycle',
        title: 'Understanding Your Menstrual Cycle',
        subtitle: 'The 4 phases of your monthly cycle, tracking symptoms, and natural cramp relief.',
        icon: Icons.calendar_month_rounded,
        content: [
          'The menstrual cycle is a natural, monthly process designed by nature. A healthy cycle typically lasts between 21 and 35 days.',
          '• Phase 1: Menstruation (Days 1–5): The uterus sheds its inner lining. Drink plenty of clean water, rest, and use clean pads.',
          '• Phase 2: Follicular Phase (Days 6–13): Estrogen levels rise, energy and focus increase naturally.',
          '• Phase 3: Ovulation (Day 14): An egg is released from the ovary.',
          '• Phase 4: Luteal Phase (Days 15–28): Progesterone increases. You may experience mild premenstrual symptoms (PMS) such as mood fluctuations or light cramping.',
          'Tip: Use a small notebook or calendar to track your day 1 each month so you are always prepared.',
        ],
      ),
      _LearnArticle(
        tag: 'Product Care',
        category: 'Products',
        title: 'Reusable vs Disposable Pads',
        subtitle: 'Comparing comfort, absorption, cost savings, and environmental protection.',
        icon: Icons.eco_rounded,
        content: [
          'Both reusable cloth pads and disposable pads provide hygienic protection. Choosing the right product depends on your daily lifestyle.',
          '• Reusable Cloth Kits: Made from soft cotton and waterproof PUL backing. With proper washing and sunlight drying, one kit lasts 2 to 3 years. Excellent for saving money and protecting the environment.',
          '• Disposable Pads: Convenient for travel and long journeys. Feature an absorbent core and adhesive wings.',
          '• Important Disposal Rule: Never flush disposable pads into toilets or pit latrines. Always wrap securely in paper and dispose in an incinerator or designated waste bin.',
        ],
      ),
      _LearnArticle(
        tag: 'Hygiene Protocol',
        category: 'Hygiene',
        title: 'Step-by-step Washing & Care',
        subtitle: 'Best practices for soaking in cold water, washing, drying under sunlight, and storing reusable kits.',
        icon: Icons.water_drop_rounded,
        content: [
          'Keeping your reusable pads clean prevents bacterial growth, skin chafing, and reproductive tract infections.',
          '• Step 1 — Cold Soak: Soak used pads in cold or room-temperature water for 20 minutes. (Never use hot water first as it sets stains).',
          '• Step 2 — Wash: Lather thoroughly with mild laundry soap and rub gently with your hands.',
          '• Step 3 — Rinse: Rinse with clean water until the water runs completely clear.',
          '• Step 4 — Direct Sunlight Drying: Hang pads outside in direct sunlight. Sunlight UV rays act as a powerful natural disinfectant.',
          '• Step 5 — Storage: Store completely dry pads in a clean, ventilated cloth bag until next use.',
        ],
      ),
      _LearnArticle(
        tag: 'Myths vs Facts',
        category: 'Myths',
        title: 'Dispelling Period Myths & Taboos',
        subtitle: 'Overcoming stigma and cultural misconceptions in schools and communities.',
        icon: Icons.psychology_alt_rounded,
        content: [
          'Menstruation is completely normal and healthy. Stigma has no place in our schools or homes.',
          '• Myth: You should not bathe or wash hair during your period.\n• Fact: Warm bathing eases muscle cramps, eliminates odor, and keeps you feeling refreshed.',
          '• Myth: Period blood is dirty or harmful.\n• Fact: Menstrual blood is ordinary blood and natural uterine tissue. It is not toxic.',
          '• Myth: Physical activity is dangerous during periods.\n• Fact: Light jogging, walking, and sports release endorphins that naturally alleviate period pain.',
        ],
      ),
      _LearnArticle(
        tag: 'Healthcare Advice',
        category: 'Medical',
        title: 'When to Seek Healthcare Advice',
        subtitle: 'Knowing when to consult a nurse, clinical officer, or youth counselor.',
        icon: Icons.health_and_safety_rounded,
        content: [
          'While mild cramping and mood changes are normal, certain symptoms indicate you should visit a health center:',
          '• Extreme pelvic pain that prevents you from standing or attending class despite resting.',
          '• Bleeding so heavy that you soak through two or more pads every hour for multiple consecutive hours.',
          '• Menstrual bleeding lasting longer than 7 consecutive days.',
          '• Foul-smelling discharge, unusual itching, or unexplained fever.',
          '• Free Arua Youth Health Helpline: Dial 0800 200 600 (toll-free) to speak privately with an adolescent nurse.',
        ],
      ),
    ];

    final filteredArticles = articles.where((a) {
      if (_selectedLearnCategory == 'All') return true;
      return a.category == _selectedLearnCategory;
    }).toList();

    return _PageScroll(
      children: [
        const _FacilityHeader(
          eyebrow: 'PERIOD HEALTH & EDUCATION',
          title: 'Learn & Care',
          subtitle: 'Empowering guides, cycle tracking, and safe hygiene tips.',
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['All', 'Cycle', 'Products', 'Hygiene', 'Myths', 'Medical'].map((cat) {
              final isSel = _selectedLearnCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(cat),
                  selected: isSel,
                  onSelected: (_) => setState(() => _selectedLearnCategory = cat),
                  selectedColor: _deepTeal,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    color: isSel ? Colors.white : _ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                  side: BorderSide(color: isSel ? _deepTeal : const Color(0xFFD6ECE6)),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        ...filteredArticles.map((art) => _buildLearnArticleCard(art)),
      ],
    );
  }

  Widget _buildLearnArticleCard(_LearnArticle article) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4F0EE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080E383A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openArticleDetail(article),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4F8F2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(article.icon, color: _deepTeal, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF7EE),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          article.tag,
                          style: const TextStyle(color: Color(0xFF16A34A), fontSize: 10, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        article.title,
                        style: const TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        article.subtitle,
                        style: const TextStyle(color: _muted, fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openArticleDetail(_LearnArticle article) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD3DFDC),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4F8F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  article.tag,
                  style: const TextStyle(color: _deepTeal, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                article.title,
                style: const TextStyle(color: _ink, fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                article.subtitle,
                style: const TextStyle(color: _muted, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 18),
              const Divider(color: Color(0xFFE8EFEF)),
              const SizedBox(height: 12),
              ...article.content.map(
                (paragraph) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(
                    paragraph,
                    style: const TextStyle(color: _ink, fontSize: 14, height: 1.6),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Finished Reading'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _deepTeal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
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
            color: selected ? _deepTeal : Colors.transparent,
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
          subtitle: 'Support young girls staying in school with dignity.',
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
                'Help keep schoolgirls in class',
                style: TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                '1 out of 10 schoolgirls in rural Uganda misses class every month during their period. Your direct donation supplies verified reusable hygiene kits.',
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
                  _userDisplayName.isEmpty ? 'PA' : _userDisplayName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _deepTeal),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userDisplayName.isEmpty ? 'Parent account' : _userDisplayName,
                      style: const TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    const Text('Parent or guardian access', style: TextStyle(color: _muted, fontSize: 13)),
                    const SizedBox(height: 3),
                    Text('Location: $_selectedArea', style: const TextStyle(color: _deepTeal, fontSize: 12, fontWeight: FontWeight.w700)),
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
          leading: const Icon(Icons.smartphone_rounded, color: _deepTeal),
          title: const Text('Preview Splash Screen', style: TextStyle(fontWeight: FontWeight.w700, color: _ink)),
          subtitle: const Text('View the 3D PadCare launch visual'),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
          onTap: _openSplashScreenModal,
        ),
        const SizedBox(height: 10),
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          tileColor: Colors.white,
          leading: const Icon(Icons.app_registration_rounded, color: _deepTeal),
          title: const Text('Register as a Pad Provider', style: TextStyle(fontWeight: FontWeight.w700, color: _ink)),
          subtitle: const Text('Register your school, clinic, or NGO distribution hub'),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
          onTap: _openProviderRegistrationModal,
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

  void _openProviderRegistrationModal() {
    final facilityNameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    String facilityType = 'School';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(22, 16, 22, MediaQuery.of(context).viewInsets.bottom + 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD0DFDC),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Register as a Pad Provider',
                style: TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Schools, clinics, and NGOs can list their collection point after verification by our community team.',
                style: TextStyle(color: _muted, fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                initialValue: facilityType,
                decoration: InputDecoration(
                  labelText: 'Provider Type',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                items: ['School', 'Clinic', 'NGO', 'Community Center', 'Individual']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => facilityType = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: facilityNameCtrl,
                decoration: InputDecoration(
                  labelText: 'Facility / Organization Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressCtrl,
                decoration: InputDecoration(
                  labelText: 'Address / Landmark in Arua',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contactCtrl,
                decoration: InputDecoration(
                  labelText: 'Liaison Person & Phone (e.g. Senior Woman Teacher)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Provider application submitted for verification review!'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _deepTeal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Submit Provider Registration', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestForm() {
    return _PageScroll(
      children: [
        const _FacilityHeader(
          eyebrow: 'HOME PICKUP REQUEST',
          title: 'Request supplies',
          subtitle: 'The selected school can review this request in the local preview.',
        ),
        const SizedBox(height: 20),
        const _FieldLabel('Your area'),
        const SizedBox(height: 7),
        DropdownButtonFormField<String>(
          key: const ValueKey('pickup-area-dropdown'),
          initialValue: _selectedArea == 'Arua Central' ? 'Oli' : _selectedArea,
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
            _ProductChoice(
              label: 'Soap',
              selected: _selectedProduct == 'Soap',
              onTap: () => setState(() => _selectedProduct = 'Soap'),
            ),
          ],
        ),
        const SizedBox(height: 19),
        _FieldLabel(
          _selectedProduct == 'Reusable pads'
              ? 'Number of kits'
              : _selectedProduct == 'Soap'
              ? 'Number of bars'
              : 'Number of packs',
        ),
        const SizedBox(height: 7),
        _QuantityControl(
          value: _quantity,
          unit: _selectedProduct == 'Reusable pads'
              ? 'kits'
              : _selectedProduct == 'Soap'
              ? 'bars'
              : 'packs',
          onChanged: (value) => setState(() => _quantity = value),
        ),
        const SizedBox(height: 14),
        FilledButton(
          key: const ValueKey('submit-home-request'),
          onPressed: _submitRequest,
          style: _primaryButtonStyle,
          child: _savingRequest
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : const Text('Save request on this device'),
        ),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'No names or personal details are needed. Saved locally on this device only.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
          ),
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

class _LearnArticle {
  const _LearnArticle({
    required this.tag,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.content,
  });

  final String tag;
  final String category;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> content;
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
              final icon = pt.category == 'Clinics'
                  ? Icons.local_hospital_rounded
                  : (pt.category == 'Schools' ? Icons.school_rounded : Icons.volunteer_activism_rounded);

              return Positioned(
                left: x - 35,
                top: y - 55,
                child: _MapTeardropPin(
                  label: pt.pinLabel,
                  icon: icon,
                  isSelected: isSelected,
                  onTap: () => onSelect(pt),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _MapTeardropPin extends StatelessWidget {
  const _MapTeardropPin({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pinColor = isSelected ? const Color(0xFF116B78) : const Color(0xFF2EA8B6);
    final size = isSelected ? 40.0 : 30.0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
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
                  color: Color(0x28000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('📍', style: TextStyle(fontSize: 9)),
                const SizedBox(width: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? const Color(0xFF116B78) : _ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          CustomPaint(
            size: Size(size, size * 1.25),
            painter: _TeardropPinPainter(
              color: pinColor,
              isSelected: isSelected,
            ),
            child: SizedBox(
              width: size,
              height: size * 1.25,
              child: Padding(
                padding: EdgeInsets.only(bottom: size * 0.25),
                child: Center(
                  child: Icon(
                    icon,
                    size: isSelected ? 18 : 14,
                    color: Colors.white,
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

class _TeardropPinPainter extends CustomPainter {
  final Color color;
  final bool isSelected;
  const _TeardropPinPainter({required this.color, this.isSelected = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = w / 2;

    final path = Path()
      ..moveTo(r, h)
      ..cubicTo(w * 0.12, h * 0.65, 0, h * 0.45, 0, r)
      ..arcToPoint(Offset(w, r), radius: Radius.circular(r))
      ..cubicTo(w, h * 0.45, w * 0.88, h * 0.65, r, h)
      ..close();

    final shadowPaint = Paint()
      ..color = const Color(0x38000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(path.shift(const Offset(0, 2)), shadowPaint);

    final fillPaint = Paint()..color = color;
    canvas.drawPath(path, fillPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 2.5 : 1.8;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _TeardropPinPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.isSelected != isSelected;
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

    final center = Offset(size.width * 0.50, size.height * 0.48);

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
      backgroundColor: const Color(0xFFE4F8F2),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE4F8F2), Color(0xFFD6F2EA)],
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
                          errorBuilder: (context, error, stackTrace) => Image.asset(
                            'assets/padcare_icon.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'PadCare',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        fontFamily: _fontHeading,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Care within reach.',
                      style: TextStyle(
                        color: Color(0xFF5A7E82),
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.1,
                        fontFamily: _fontSubheading,
                      ),
                    ),
                    const SizedBox(height: 36),
                    SizedBox(
                      width: 90,
                      height: 90,
                      child: Lottie.asset(
                        'assets/loading-transparent.json',
                        repeat: true,
                        errorBuilder: (context, error, stackTrace) => const SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            strokeWidth: 3.5,
                            valueColor: AlwaysStoppedAnimation<Color>(_green),
                          ),
                        ),
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
                  'Not sent over network${date.isEmpty ? '' : '  ·  $date'}',
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
