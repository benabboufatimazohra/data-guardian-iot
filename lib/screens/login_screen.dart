import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// SCREEN 1: LoginScreen
/// ─────────────────────────────────────────────────────────────────────────────
///
/// WIDGET TREE:
/// Scaffold
/// └── Stack (for background pattern + centered content)
///     ├── _TechPatternBackground  ← decorative dot pattern
///     └── SafeArea
///         └── Column
///             ├── _BrandHeader          ← top-left logo
///             └── Center
///                 └── SingleChildScrollView
///                     └── _LoginCard    ← the white glass card
///                         ├── _LockIcon
///                         ├── _TitleSection
///                         ├── _LoginForm
///                         ├── _SsoSection
///                         └── _FooterLinks
///
/// KEY CONCEPT — StatefulWidget vs StatelessWidget:
///   We use StatefulWidget here because the form has STATE:
///   - Is the password visible? (bool _passwordVisible)
///   - Is the form loading? (bool _isLoading)
///   When these values change, Flutter re-renders only the affected widgets.
///
///   HTML equivalent: you'd use JS variables + event listeners to update the DOM.
///   Flutter's setState() is like calling document.querySelector().style = ...
///   but Flutter re-renders only the changed widget, not the whole page.
/// ─────────────────────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  /// STATE VARIABLES — these cause re-renders when changed via setState()
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordVisible = false;
  bool _rememberDevice = false;
  bool _isLoading = false;

  /// Don't forget to dispose controllers to avoid memory leaks!
  /// HTML doesn't need this because the browser cleans up form elements.
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// WHERE THE API CALL GOES:
  /// When the user taps "Sign In", we:
  ///  1. Show a loading indicator (setState → _isLoading = true)
  ///  2. Call the auth API
  ///  3. On success, navigate to Dashboard
  ///  4. On error, show a Snackbar
  Future<void> _handleSignIn() async {
    setState(() => _isLoading = true);

    // ─── API call would go here ───────────────────────────────────────────
    // Example:
    // final response = await AuthService.login(
    //   email: _emailController.text,
    //   password: _passwordController.text,
    // );
    // if (response.success) {
    //   Navigator.pushReplacementNamed(context, '/dashboard');
    // } else {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(content: Text(response.error)),
    //   );
    // }
    // ─────────────────────────────────────────────────────────────────────

    // Simulate network delay for now
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,

      /// Stack layers widgets on top of each other.
      /// HTML equivalent: position: relative parent + position: absolute children
      body: Stack(
        children: [
          /// Layer 1: Dot grid background pattern
          /// HTML: background-image: radial-gradient(circle at 2px 2px, ...)
          const _TechPatternBackground(),

          /// Layer 2: Main content
          /// SafeArea prevents content from going under the status bar or notch
          SafeArea(
            child: Column(
              children: [
                /// Top branding bar
                /// HTML: <div class="absolute top-0 left-0 ...">
                _BrandHeader(),

                /// Center the login card vertically in remaining space
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: _LoginCard(
                      emailController: _emailController,
                      passwordController: _passwordController,
                      passwordVisible: _passwordVisible,
                      rememberDevice: _rememberDevice,
                      isLoading: _isLoading,
                      onTogglePassword: () => setState(() => _passwordVisible = !_passwordVisible),
                      onToggleRemember: (val) => setState(() => _rememberDevice = val ?? false),
                      onSignIn: _handleSignIn,
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
// Sub-widget: _TechPatternBackground
// HTML: background-image: radial-gradient dot pattern
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
      ..color = AppColors.primary.withOpacity(0.05)
      ..style = PaintingStyle.fill;

    const spacing = 32.0;
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
// Sub-widget: _BrandHeader
// HTML: <div class="absolute top-0 left-0 w-full flex justify-between p-6">
// ─────────────────────────────────────────────────────────────────────────────
class _BrandHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        /// HTML: justify-between = MainAxisAlignment.spaceBetween
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          /// Logo + App name
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: AppColors.primary, size: 28),
              const SizedBox(width: 8),
              RichText(
                /// RichText lets us mix styles in one line
                /// HTML: DataGuardian <span class="text-primary">IoT</span>
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
            ],
          ),

          /// System status badge — hidden on small screens via MediaQuery
          if (MediaQuery.of(context).size.width > 360)
            RichText(
              text: const TextSpan(
                text: 'System Status: ',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                children: [
                  TextSpan(
                    text: 'Operational',
                    style: TextStyle(color: AppColors.emerald),
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
// Sub-widget: _LoginCard (the glass card container)
// HTML: <div class="w-full max-w-md bg-white/5 backdrop-blur-xl border rounded-xl">
// ─────────────────────────────────────────────────────────────────────────────
class _LoginCard extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool passwordVisible;
  final bool rememberDevice;
  final bool isLoading;
  final VoidCallback onTogglePassword;
  final ValueChanged<bool?> onToggleRemember;
  final VoidCallback onSignIn;

  const _LoginCard({
    required this.emailController,
    required this.passwordController,
    required this.passwordVisible,
    required this.rememberDevice,
    required this.isLoading,
    required this.onTogglePassword,
    required this.onToggleRemember,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      /// Max width like HTML's max-w-md (448px)
      constraints: const BoxConstraints(maxWidth: 448),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        /// HTML: bg-white/5 backdrop-blur-xl = glassmorphism effect
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        children: [
          /// Lock icon hero section
          _LockIconSection(),
          const SizedBox(height: 24),

          /// Title
          const Text('Secure Access', style: AppTextStyles.heading),
          const SizedBox(height: 8),
          const Text(
            'Monitor your infrastructure in real-time',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          /// Email field
          _InputField(
            label: 'Work Email',
            hint: 'name@company.com',
            controller: emailController,
            prefixIcon: Icons.alternate_email,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 20),

          /// Password field
          _PasswordField(
            controller: passwordController,
            isVisible: passwordVisible,
            onToggle: onTogglePassword,
          ),
          const SizedBox(height: 16),

          /// Remember checkbox
          Row(
            children: [
              Checkbox(
                value: rememberDevice,
                onChanged: onToggleRemember,
                activeColor: AppColors.primary,
                side: const BorderSide(color: AppColors.border, width: 1.5),
              ),
              const Text(
                'Remember this device for 30 days',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 20),

          /// Sign In button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading ? null : onSignIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 8,
                shadowColor: AppColors.primary.withOpacity(0.4),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
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

          /// SSO divider
          const _OrDivider(),
          const SizedBox(height: 16),

          /// SSO buttons
          Row(
            children: [
              Expanded(
                child: _SsoButton(
                  label: 'Google',
                  icon: Icons.g_mobiledata,
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SsoButton(
                  label: 'SAML SSO',
                  icon: Icons.terminal,
                  onPressed: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          /// Footer links
          const _FooterLinks(),
        ],
      ),
    );
  }
}

// ─── Lock icon hero section ─────────────────────────────────────────────────
class _LockIconSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(
        child: Icon(Icons.lock_open, color: AppColors.primary, size: 56),
      ),
    );
  }
}

// ─── Reusable text input field ───────────────────────────────────────────────
/// HTML: <input type="email" class="w-full bg-slate-900/50 border...">
class _InputField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData prefixIcon;
  final TextInputType keyboardType;

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
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
            prefixIcon: Icon(prefixIcon, color: AppColors.textMuted, size: 20),
            filled: true,
            fillColor: Colors.black.withOpacity(0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
        ),
      ],
    );
  }
}

// ─── Password field with toggle visibility ───────────────────────────────────
class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final bool isVisible;
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
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Forgot Password?',
                style: TextStyle(fontSize: 12, color: AppColors.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          /// obscureText hides password characters — like type="password" in HTML
          obscureText: !isVisible,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: '••••••••',
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
            prefixIcon: const Icon(Icons.vpn_key_outlined, color: AppColors.textMuted, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                isVisible ? Icons.visibility : Icons.visibility_off,
                color: AppColors.textMuted,
                size: 20,
              ),
              onPressed: onToggle,
            ),
            filled: true,
            fillColor: Colors.black.withOpacity(0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
        ),
      ],
    );
  }
}

// ─── "Or login with" divider ─────────────────────────────────────────────────
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

// ─── SSO option button ───────────────────────────────────────────────────────
class _SsoButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _SsoButton({required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.border),
        backgroundColor: AppColors.surfaceLight.withOpacity(0.3),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

// ─── Footer copyright + links ─────────────────────────────────────────────────
class _FooterLinks extends StatelessWidget {
  const _FooterLinks();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('© 2026 DataGuardian Systems. All rights reserved.', style: AppTextStyles.caption),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Link('Terms of Service'),
            const SizedBox(width: 16),
            _Link('Privacy Policy'),
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
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    );
  }
}

// Export AppTextStyles so login_screen.dart can use it
// (In real project this would be imported from app_colors.dart)
class AppTextStyles {
  static const TextStyle heading = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
  );
  static const TextStyle label = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
    letterSpacing: 1.5,
  );
}