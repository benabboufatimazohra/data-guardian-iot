import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/auth_service.dart';
import '../database/database_helper.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// SCREEN 1: LoginScreen
/// ─────────────────────────────────────────────────────────────────────────────
/// OVERFLOW FIX (1.2 px RIGHT):
///   The _BrandHeader Row used mainAxisAlignment.spaceBetween with two
///   unconstrained RichText children. On screens ≈ 361–370 px wide the sum
///   of their natural widths exceeded the available row width by ~1 px.
///   Fix: wrap both children in Flexible so they can shrink and RichText
///   gets overflow: TextOverflow.ellipsis as a safety net.
/// ─────────────────────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool   _passwordVisible = false;
  bool   _rememberDevice  = false;
  bool   _isLoading       = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    setState(() { _isLoading = true; _errorMessage = null; });

    final email    = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() { _isLoading = false; _errorMessage = 'Veuillez remplir tous les champs.'; });
      return;
    }

    final success = await AuthService.instance.login(email, password);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      setState(() => _errorMessage = 'Email ou mot de passe incorrect.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          const _TechPatternBackground(),
          SafeArea(
            child: Column(
              children: [
                _BrandHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: _LoginCard(
                      emailController:    _emailController,
                      passwordController: _passwordController,
                      passwordVisible:    _passwordVisible,
                      rememberDevice:     _rememberDevice,
                      isLoading:          _isLoading,
                      errorMessage:       _errorMessage,
                      onTogglePassword:   () => setState(() => _passwordVisible = !_passwordVisible),
                      onToggleRemember:   (val) => setState(() => _rememberDevice = val ?? false),
                      onSignIn:           _handleSignIn,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TechPatternBackground
// ─────────────────────────────────────────────────────────────────────────────
class _TechPatternBackground extends StatelessWidget {
  const _TechPatternBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomPaint(painter: _DotGridPainter()),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    const spacing   = 32.0;
    const dotRadius = 1.0;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// _BrandHeader — OVERFLOW FIX APPLIED HERE
// ─────────────────────────────────────────────────────────────────────────────
class _BrandHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ── FIX: wrap in Flexible so it can shrink on narrow screens ──────
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_outlined, color: AppColors.primary, size: 28),
                const SizedBox(width: 8),
                Flexible(
                  child: RichText(
                    overflow: TextOverflow.ellipsis, // safety net
                    text: const TextSpan(
                      text: 'DataGuardian ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      children: [
                        TextSpan(
                          text: 'IoT',
                          style: TextStyle(color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── FIX: wrap status badge in Flexible too ────────────────────────
          if (MediaQuery.of(context).size.width > 360)
            Flexible(
              child: RichText(
                overflow: TextOverflow.ellipsis,
                text: const TextSpan(
                  text: 'Statut : ',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  children: [
                    TextSpan(
                      text: 'Opérationnel',
                      style: TextStyle(color: AppColors.emerald),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _LoginCard
// ─────────────────────────────────────────────────────────────────────────────
class _LoginCard extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool    passwordVisible;
  final bool    rememberDevice;
  final bool    isLoading;
  final String? errorMessage;
  final VoidCallback         onTogglePassword;
  final ValueChanged<bool?>  onToggleRemember;
  final VoidCallback         onSignIn;

  const _LoginCard({
    required this.emailController,
    required this.passwordController,
    required this.passwordVisible,
    required this.rememberDevice,
    required this.isLoading,
    this.errorMessage,
    required this.onTogglePassword,
    required this.onToggleRemember,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 448),
      padding:     const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color:         Colors.white.withValues(alpha: 0.05),
        borderRadius:  BorderRadius.circular(16),
        border:        Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color:     Colors.black.withValues(alpha: 0.4),
            blurRadius: 40,
            offset:    const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        children: [
          _LockIconSection(),
          const SizedBox(height: 24),
          const Text('Secure Access', style: AppTextStyles.heading),
          const SizedBox(height: 8),
          const Text(
            'Monitor your infrastructure in real-time',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          _InputField(
            label:        'Work Email',
            hint:         'name@company.com',
            controller:   emailController,
            prefixIcon:   Icons.alternate_email,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 20),

          _PasswordField(
            controller: passwordController,
            isVisible:  passwordVisible,
            onToggle:   onTogglePassword,
          ),
          const SizedBox(height: 16),

          // ── OVERFLOW FIX: Expanded on Text prevents 1.2px right overflow ──
          Row(
            children: [
              Checkbox(
                value:       rememberDevice,
                onChanged:   onToggleRemember,
                activeColor: AppColors.primary,
                side: const BorderSide(color: AppColors.border, width: 1.5),
              ),
              const Expanded(
                child: Text(
                  'Remember this device for 30 days',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  softWrap: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Error message
          if (errorMessage != null) ...[
            Container(
              width:  double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color:        AppColors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border:       Border.all(color: AppColors.red.withValues(alpha: 0.3)),
              ),
              child: Text(
                errorMessage!,
                style: const TextStyle(fontSize: 13, color: AppColors.red),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
          ],

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading ? null : onSignIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:         const EdgeInsets.symmetric(vertical: 16),
                shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation:       8,
                shadowColor:     AppColors.primary.withValues(alpha: 0.4),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width:  20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 32),

          const _OrDivider(),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(child: _SsoButton(label: 'Google',   icon: Icons.g_mobiledata, onPressed: () {})),
              const SizedBox(width: 16),
              Expanded(child: _SsoButton(label: 'SAML SSO', icon: Icons.terminal,     onPressed: () {})),
            ],
          ),
          const SizedBox(height: 32),

          const _FooterLinks(),
        ],
      ),
    );
  }
}

// ─── Lock icon hero section ───────────────────────────────────────────────────
class _LockIconSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width:  double.infinity,
      height: 120,
      decoration: BoxDecoration(
        color:         AppColors.surfaceLight,
        borderRadius:  BorderRadius.circular(10),
      ),
      child: const Center(
        child: Icon(Icons.lock_open, color: AppColors.primary, size: 56),
      ),
    );
  }
}

// ─── Reusable text input field ────────────────────────────────────────────────
class _InputField extends StatelessWidget {
  final String                label;
  final String                hint;
  final TextEditingController controller;
  final IconData              prefixIcon;
  final TextInputType         keyboardType;

  const _InputField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.prefixIcon,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 8),
        TextField(
          controller:   controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText:    hint,
            hintStyle:   const TextStyle(color: AppColors.textMuted, fontSize: 14),
            prefixIcon:  Icon(prefixIcon, color: AppColors.textMuted, size: 20),
            filled:      true,
            fillColor:   Colors.black.withValues(alpha: 0.3),
            border:       OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
        ),
      ],
    );
  }
}

// ─── Password field ───────────────────────────────────────────────────────────
class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final bool         isVisible;
  final VoidCallback onToggle;

  const _PasswordField({
    required this.controller,
    required this.isVisible,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Password', style: AppTextStyles.caption),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                padding:         EdgeInsets.zero,
                minimumSize:     Size.zero,
                tapTargetSize:   MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Forgot Password?',
                  style: TextStyle(fontSize: 12, color: AppColors.primary)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller:  controller,
          obscureText: !isVisible,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText:    '••••••••',
            hintStyle:   const TextStyle(color: AppColors.textMuted, fontSize: 14),
            prefixIcon:  const Icon(Icons.vpn_key_outlined, color: AppColors.textMuted, size: 20),
            suffixIcon:  IconButton(
              icon: Icon(isVisible ? Icons.visibility : Icons.visibility_off,
                  color: AppColors.textMuted, size: 20),
              onPressed: onToggle,
            ),
            filled:      true,
            fillColor:   Colors.black.withValues(alpha: 0.3),
            border:       OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
        ),
      ],
    );
  }
}

// ─── OR divider ───────────────────────────────────────────────────────────────
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border, thickness: 0.5)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('OR LOGIN WITH', style: AppTextStyles.label),
        ),
        const Expanded(child: Divider(color: AppColors.border, thickness: 0.5)),
      ],
    );
  }
}

// ─── SSO button ───────────────────────────────────────────────────────────────
class _SsoButton extends StatelessWidget {
  final String     label;
  final IconData   icon;
  final VoidCallback onPressed;

  const _SsoButton({required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side:            const BorderSide(color: AppColors.border),
        backgroundColor: AppColors.surfaceLight.withValues(alpha: 0.3),
        padding:         const EdgeInsets.symmetric(vertical: 14),
        shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.textPrimary, size: 18),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ─── Footer links ─────────────────────────────────────────────────────────────
class _FooterLinks extends StatelessWidget {
  const _FooterLinks();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('© 2026 DataGuardian Systems. All rights reserved.',
            style: AppTextStyles.caption),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Link('Terms'),
            const SizedBox(width: 16),
            _Link('Privacy'),
            const SizedBox(width: 16),
            _Link('Support'),
          ],
        ),
      ],
    );
  }
}

class _Link extends StatelessWidget {
  final String text;
  const _Link(this.text);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Text(text,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
    );
  }
}

// ─── AppTextStyles ────────────────────────────────────────────────────────────
class AppTextStyles {
  static const TextStyle heading = TextStyle(
    fontSize: 22, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary, letterSpacing: -0.5,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 12, color: AppColors.textSecondary,
  );
  static const TextStyle label = TextStyle(
    fontSize: 10, fontWeight: FontWeight.w700,
    color: AppColors.textSecondary, letterSpacing: 1.5,
  );
}
