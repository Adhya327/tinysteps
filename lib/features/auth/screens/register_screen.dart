import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_theme.dart';
import '../widgets/auth_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RegisterScreen — Multi-step signup
//   Step 0: Role selection (Parent / Teacher / Admin)
//   Step 1: Account details (all roles)
//   Step 2 (Parents only): First child info
// ─────────────────────────────────────────────────────────────────────────────
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();

  int _step = 0;
  String _selectedRole = 'parent';
  bool _loading = false;

  // ── Common controllers ────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _referralCtrl = TextEditingController();

  // ── Parent-specific ───────────────────────────────────────────────────
  final _emergencyNameCtrl = TextEditingController();
  final _emergencyPhoneCtrl = TextEditingController();
  final _relationCtrl = TextEditingController();

  // ── Parent: first child ───────────────────────────────────────────────
  final _childNameCtrl = TextEditingController();
  DateTime? _childDob;
  String _childGender = 'Not specified';
  final _childAllergyCtrl = TextEditingController();
  final _childMedCtrl = TextEditingController();

  // ── Teacher-specific ──────────────────────────────────────────────────
  final _staffIdCtrl = TextEditingController();
  final _designationCtrl = TextEditingController();

  // ── Admin-specific ────────────────────────────────────────────────────
  final _centerNameCtrl = TextEditingController();
  final _adminDesigCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _obscureConfirm = true;

  // Animation
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  void _goToStep(int step) {
    _animCtrl.reset();
    setState(() => _step = step);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    for (final c in [
      _nameCtrl, _emailCtrl, _phoneCtrl, _passCtrl, _confirmCtrl,
      _referralCtrl, _emergencyNameCtrl, _emergencyPhoneCtrl, _relationCtrl,
      _childNameCtrl, _childAllergyCtrl, _childMedCtrl,
      _staffIdCtrl, _designationCtrl, _centerNameCtrl, _adminDesigCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Submit ────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final meta = <String, dynamic>{
        'full_name': _nameCtrl.text.trim(),
        'role': _selectedRole,
        'phone': _phoneCtrl.text.trim(),
        'referral_code': _referralCtrl.text.trim(),
      };

      switch (_selectedRole) {
        case 'parent':
          meta['emergency_contact_name'] = _emergencyNameCtrl.text.trim();
          meta['emergency_contact_phone'] = _emergencyPhoneCtrl.text.trim();
          meta['relationship'] = _relationCtrl.text.trim();
          meta['child_name'] = _childNameCtrl.text.trim();
          meta['child_dob'] = _childDob != null
              ? _childDob!.toIso8601String().split('T').first : '';
          meta['child_gender'] = _childGender;
          meta['child_allergies'] = _childAllergyCtrl.text.trim();
          meta['child_medical_notes'] = _childMedCtrl.text.trim();
          break;
        case 'teacher':
          meta['staff_id'] = _staffIdCtrl.text.trim();
          meta['designation'] = _designationCtrl.text.trim().isEmpty
              ? 'Teacher' : _designationCtrl.text.trim();
          break;
        case 'admin':
          meta['center_name'] = _centerNameCtrl.text.trim();
          meta['designation'] = _adminDesigCtrl.text.trim().isEmpty
              ? 'Center Director' : _adminDesigCtrl.text.trim();
          break;
      }

      await Supabase.instance.client.auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
        data: meta,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Expanded(child: Text('Account created! Check your email to verify.')),
          ]),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(AppSpacing.md),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
          duration: const Duration(seconds: 5),
        ));
        context.go('/login');
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      final msg = e.message.toLowerCase();
      if (msg.contains('user already registered') ||
          msg.contains('email already in use') ||
          msg.contains('already been registered')) {
        _showEmailInUseDialog();
      } else {
        _showError('Signup failed: ${e.message}');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showEmailInUseDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.bgDarkSurface : AppColors.bgSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
        icon: const Icon(Icons.email_outlined,
            color: AppColors.primary, size: 36),
        title: Text('Email already registered',
            style: AppTextStyles.heading3, textAlign: TextAlign.center),
        content: Text(
          'An account with this email already exists. Did you mean to sign in instead?',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Stay here',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.full)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/login');
            },
            child: const Text('Sign in instead'),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: AppColors.danger,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(AppSpacing.md),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md)),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalSteps = _selectedRole == 'parent' ? 3 : 2;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: [
          // Subtle background blobs
          Positioned(
            bottom: -80,
            left: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary
                    .withValues(alpha: isDark ? 0.08 : 0.10),
              ),
            ),
          ),

          SafeArea(
            child: AbsorbPointer(
              absorbing: _loading,
              child: Column(
                children: [
                  // ── App bar ─────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                          color: cs.onSurface,
                          onPressed: () {
                            if (_step > 0) {
                              _goToStep(_step - 1);
                            } else {
                              context.go('/login');
                            }
                          },
                        ),
                        const Spacer(),
                        if (_step > 0)
                          _StepIndicator(
                              current: _step, total: totalSteps),
                        const Spacer(),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg),
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: SlideTransition(
                          position: _slideAnim,
                          child: _buildCurrentStep(isDark, cs),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Loading spinner overlay ─────────────────────────────────
          if (_loading)
            Container(
              color: Colors.black.withValues(alpha: 0.18),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.bgDarkSurface
                        : AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    boxShadow: AppShadows.floating,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('Setting up your account…',
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }


  Widget _buildCurrentStep(bool isDark, ColorScheme cs) {
    switch (_step) {
      case 0:
        return _RoleSelectionStep(
          selected: _selectedRole,
          onSelect: (role) {
            _selectedRole = role;
            _goToStep(1);
          },
          onLogin: () => context.go('/login'),
          cs: cs,
          isDark: isDark,
        );
      case 1:
        return _DetailsStep(
          formKey: _step1Key,
          role: _selectedRole,
          nameCtrl: _nameCtrl,
          emailCtrl: _emailCtrl,
          phoneCtrl: _phoneCtrl,
          passCtrl: _passCtrl,
          confirmCtrl: _confirmCtrl,
          referralCtrl: _referralCtrl,
          emergencyNameCtrl: _emergencyNameCtrl,
          emergencyPhoneCtrl: _emergencyPhoneCtrl,
          relationCtrl: _relationCtrl,
          staffIdCtrl: _staffIdCtrl,
          designationCtrl: _designationCtrl,
          centerNameCtrl: _centerNameCtrl,
          adminDesigCtrl: _adminDesigCtrl,
          obscurePass: _obscurePass,
          obscureConfirm: _obscureConfirm,
          onTogglePass: () => setState(() => _obscurePass = !_obscurePass),
          onToggleConfirm: () =>
              setState(() => _obscureConfirm = !_obscureConfirm),
          isDark: isDark,
          cs: cs,
          loading: _loading,
          onNext: () {
            if (_step1Key.currentState!.validate()) {
              if (_selectedRole == 'parent') {
                _goToStep(2);   // Parents fill child info next
              } else {
                _submit();       // Others go straight to submit
              }
            }
          },
        );
      case 2:
        return _ChildInfoStep(
          formKey: _step2Key,
          childNameCtrl: _childNameCtrl,
          childDob: _childDob,
          childGender: _childGender,
          allergyCtrl: _childAllergyCtrl,
          medCtrl: _childMedCtrl,
          isDark: isDark,
          cs: cs,
          loading: _loading,
          onPickDob: _pickDob,
          onGenderChange: (v) => setState(() => _childGender = v!),
          onSubmit: () {
            if (_step2Key.currentState!.validate()) _submit();
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365)),
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: AppColors.primary,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _childDob = picked);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 0 — Role Selection
// ─────────────────────────────────────────────────────────────────────────────
class _RoleSelectionStep extends StatelessWidget {
  const _RoleSelectionStep({
    required this.selected,
    required this.onSelect,
    required this.onLogin,
    required this.cs,
    required this.isDark,
  });
  final String selected;
  final void Function(String) onSelect;
  final VoidCallback onLogin;
  final ColorScheme cs;
  final bool isDark;

  static const _roles = [
    {'key': 'parent', 'title': 'Parent', 'sub': "I'm enrolling my child",
     'icon': Icons.family_restroom_rounded, 'color': AppColors.primary},
    {'key': 'teacher', 'title': 'Teacher', 'sub': 'I work at the daycare',
     'icon': Icons.school_rounded, 'color': AppColors.secondary},
    {'key': 'admin', 'title': 'Admin', 'sub': 'I manage the center',
     'icon': Icons.admin_panel_settings_rounded, 'color': AppColors.accent},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.md),
        ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [AppColors.primary, AppColors.secondary],
          ).createShader(b),
          child: Text('Create account',
              style: GoogleFonts.lexend(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('Choose how you\'re joining',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: cs.onSurface.withValues(alpha: 0.5))),
        const SizedBox(height: AppSpacing.xl),

        ..._roles.map((r) {
          final color = r['color'] as Color;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _RoleCard(
              icon: r['icon'] as IconData,
              title: r['title'] as String,
              subtitle: r['sub'] as String,
              color: color,
              isDark: isDark,
              onTap: () => onSelect(r['key'] as String),
            ),
          );
        }),

        const SizedBox(height: AppSpacing.lg),
        GestureDetector(
          onTap: onLogin,
          child: RichText(
            text: TextSpan(
              style: AppTextStyles.bodySmall
                  .copyWith(color: cs.onSurface.withValues(alpha: 0.5)),
              children: [
                const TextSpan(text: 'Already have an account? '),
                TextSpan(
                    text: 'Sign in',
                    style: const TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isDark,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: isDark ? AppColors.bgDarkSurface : AppColors.bgSurface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: cs.outline.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontSize: 17, color: cs.onSurface)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: cs.onSurface.withValues(alpha: 0.5))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: cs.onSurface.withValues(alpha: 0.3), size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 1 — Account details form
// ─────────────────────────────────────────────────────────────────────────────
class _DetailsStep extends StatelessWidget {
  const _DetailsStep({
    required this.formKey,
    required this.role,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.passCtrl,
    required this.confirmCtrl,
    required this.referralCtrl,
    required this.emergencyNameCtrl,
    required this.emergencyPhoneCtrl,
    required this.relationCtrl,
    required this.staffIdCtrl,
    required this.designationCtrl,
    required this.centerNameCtrl,
    required this.adminDesigCtrl,
    required this.obscurePass,
    required this.obscureConfirm,
    required this.onTogglePass,
    required this.onToggleConfirm,
    required this.isDark,
    required this.cs,
    required this.loading,
    required this.onNext,
  });

  final GlobalKey<FormState> formKey;
  final String role;
  final TextEditingController nameCtrl, emailCtrl, phoneCtrl, passCtrl,
      confirmCtrl, referralCtrl, emergencyNameCtrl, emergencyPhoneCtrl,
      relationCtrl, staffIdCtrl, designationCtrl, centerNameCtrl, adminDesigCtrl;
  final bool obscurePass, obscureConfirm, isDark, loading;
  final VoidCallback onTogglePass, onToggleConfirm, onNext;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.md),
          Text('Your details',
              style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: AppSpacing.xs),
          Text('Fill in your account information',
              style: AppTextStyles.bodyMuted
                  .copyWith(color: cs.onSurface.withValues(alpha: 0.5))),
          const SizedBox(height: AppSpacing.lg),

          AuthTextField(
              label: 'Full Name',
              hint: 'Jane Smith',
              controller: nameCtrl,
              icon: Icons.person_outline_rounded,
              validator: _req),
          AuthTextField(
              label: 'Email Address',
              hint: 'jane@example.com',
              controller: emailCtrl,
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              }),
          AuthTextField(
              label: 'Phone Number',
              hint: '+91 98765 43210',
              controller: phoneCtrl,
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: _req),

          // Password
          _PassField(
              label: 'Password',
              hint: '8+ characters',
              ctrl: passCtrl,
              obscure: obscurePass,
              toggle: onTogglePass,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v.length < 8) return 'Min 8 characters';
                return null;
              }),
          _PassField(
              label: 'Confirm Password',
              hint: 'Re-enter password',
              ctrl: confirmCtrl,
              obscure: obscureConfirm,
              toggle: onToggleConfirm,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v != passCtrl.text) return "Passwords don't match";
                return null;
              }),

          AuthTextField(
              label: 'Referral Code',
              hint: 'TINY-XXXX  (from your admin)',
              controller: referralCtrl,
              icon: Icons.vpn_key_outlined,
              validator: _req),

          // Role-specific
          if (role == 'parent') ...[
            const _Divider('Emergency contact'),
            AuthTextField(
                label: 'Contact Name',
                hint: 'John Smith',
                controller: emergencyNameCtrl,
                icon: Icons.contact_emergency_outlined,
                validator: _req),
            AuthTextField(
                label: 'Contact Phone',
                hint: '+91 91234 56789',
                controller: emergencyPhoneCtrl,
                icon: Icons.phone_in_talk_outlined,
                keyboardType: TextInputType.phone,
                validator: _req),
            AuthTextField(
                label: 'Relationship to Child',
                hint: 'Mother / Father / Guardian',
                controller: relationCtrl,
                icon: Icons.people_outline_rounded,
                validator: _req),
          ],

          if (role == 'teacher') ...[
            const _Divider('Professional details'),
            AuthTextField(
                label: 'Staff ID',
                hint: 'EMP-1234 (optional)',
                controller: staffIdCtrl,
                icon: Icons.badge_outlined),
            AuthTextField(
                label: 'Designation',
                hint: 'Lead Teacher / Assistant',
                controller: designationCtrl,
                icon: Icons.work_outline_rounded,
                validator: _req),
          ],

          if (role == 'admin') ...[
            const _Divider('Center details'),
            AuthTextField(
                label: 'Center Name',
                hint: 'Little Stars Daycare',
                controller: centerNameCtrl,
                icon: Icons.business_outlined,
                validator: _req),
            AuthTextField(
                label: 'Your Designation',
                hint: 'Center Director / Manager',
                controller: adminDesigCtrl,
                icon: Icons.manage_accounts_outlined,
                validator: _req),
          ],

          const SizedBox(height: AppSpacing.lg),
          AuthGradientButton(
            label: role == 'parent' ? 'Next: Add child info' : 'Create account',
            icon: role == 'parent'
                ? Icons.arrow_forward_rounded
                : Icons.check_rounded,
            onTap: loading ? null : onNext,
            loading: loading,
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  String? _req(String? v) => v == null || v.isEmpty ? 'Required' : null;
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 2 — First child info (parents only)
// ─────────────────────────────────────────────────────────────────────────────
class _ChildInfoStep extends StatelessWidget {
  const _ChildInfoStep({
    required this.formKey,
    required this.childNameCtrl,
    required this.childDob,
    required this.childGender,
    required this.allergyCtrl,
    required this.medCtrl,
    required this.isDark,
    required this.cs,
    required this.loading,
    required this.onPickDob,
    required this.onGenderChange,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController childNameCtrl, allergyCtrl, medCtrl;
  final DateTime? childDob;
  final String childGender;
  final bool isDark, loading;
  final ColorScheme cs;
  final VoidCallback onPickDob, onSubmit;
  final void Function(String?) onGenderChange;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.md),

          // Header with coral accent icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(Icons.child_care_rounded,
                    color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Your child's info",
                        style: Theme.of(context).textTheme.displayMedium),
                    Text("You can add more children after sign-up",
                        style: AppTextStyles.bodySmall.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.5))),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          AuthTextField(
            label: "Child's Full Name",
            hint: 'Emma Smith',
            controller: childNameCtrl,
            icon: Icons.person_outline_rounded,
            validator: (v) =>
                v == null || v.isEmpty ? 'Required' : null,
          ),

          // Date of birth picker
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Date of Birth", style: AppTextStyles.labelBold
                    .copyWith(color: cs.onSurface)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: onPickDob,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: 15),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.bgDarkMuted : AppColors.bgLight,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                          color: cs.outline.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 20,
                            color: cs.onSurface.withValues(alpha: 0.4)),
                        const SizedBox(width: 12),
                        Text(
                          childDob != null
                              ? '${childDob!.day}/${childDob!.month}/${childDob!.year}'
                              : 'Select date of birth',
                          style: childDob != null
                              ? AppTextStyles.bodyMedium
                                  .copyWith(color: cs.onSurface)
                              : AppTextStyles.bodyMuted.copyWith(
                                  color: cs.onSurface.withValues(alpha: 0.35)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Gender
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gender', style: AppTextStyles.labelBold
                    .copyWith(color: cs.onSurface)),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  decoration: BoxDecoration(
                    color:
                        isDark ? AppColors.bgDarkMuted : AppColors.bgLight,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                        color: cs.outline.withValues(alpha: 0.4)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: childGender,
                      isExpanded: true,
                      dropdownColor: isDark
                          ? AppColors.bgDarkSurface
                          : AppColors.bgSurface,
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: cs.onSurface),
                      items: const [
                        DropdownMenuItem(
                            value: 'Not specified',
                            child: Text('Prefer not to say')),
                        DropdownMenuItem(
                            value: 'Male', child: Text('Male')),
                        DropdownMenuItem(
                            value: 'Female', child: Text('Female')),
                      ],
                      onChanged: onGenderChange,
                    ),
                  ),
                ),
              ],
            ),
          ),

          AuthTextField(
              label: 'Allergies',
              hint: 'None / Peanuts / Dairy... (optional)',
              controller: allergyCtrl,
              icon: Icons.warning_amber_outlined),
          AuthTextField(
              label: 'Medical Notes',
              hint: 'Any conditions the teacher should know (optional)',
              controller: medCtrl,
              icon: Icons.medical_information_outlined),

          const SizedBox(height: AppSpacing.lg),

          // Info note
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'This info is visible to your child\'s assigned teacher and the center admin. You can update it anytime from your profile.',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary.withValues(alpha: 0.85)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          AuthGradientButton(
            label: 'Create account',
            icon: Icons.check_rounded,
            onTap: loading ? null : onSubmit,
            loading: loading,
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
class _PassField extends StatelessWidget {
  const _PassField({
    required this.label,
    required this.hint,
    required this.ctrl,
    required this.obscure,
    required this.toggle,
    this.validator,
  });
  final String label, hint;
  final TextEditingController ctrl;
  final bool obscure;
  final VoidCallback toggle;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AuthTextField(
      label: label,
      hint: hint,
      controller: ctrl,
      icon: Icons.lock_outline_rounded,
      obscureText: obscure,
      validator: validator,
      suffix: IconButton(
        icon: Icon(
          obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 20,
          color: cs.onSurface.withValues(alpha: 0.4),
        ),
        onPressed: toggle,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(
          top: AppSpacing.md, bottom: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
              child: Divider(color: cs.outline.withValues(alpha: 0.4), height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(label,
                style: AppTextStyles.labelMedium
                    .copyWith(color: cs.onSurface.withValues(alpha: 0.45))),
          ),
          Expanded(
              child: Divider(color: cs.outline.withValues(alpha: 0.4), height: 1)),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final active = i < current;
        final dot = i + 1;
        return Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: active ? 28 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: active ? AppColors.primary : AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            if (dot < total) const SizedBox(width: 4),
          ],
        );
      }),
    );
  }
}
