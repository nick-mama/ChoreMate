import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/household_service.dart';
import '../../../shared/widgets/app_logo.dart';
import '../../../shared/widgets/primary_button.dart';

class HouseholdSetupPage extends StatefulWidget {
  const HouseholdSetupPage({super.key});

  @override
  State<HouseholdSetupPage> createState() => _HouseholdSetupPageState();
}

class _HouseholdSetupPageState extends State<HouseholdSetupPage> {
  final _service = HouseholdService();
  final _authService = AuthService();
  final nameController = TextEditingController();
  final codeController = TextEditingController();
  final emailController = TextEditingController();

  bool loading = false;
  String errorMessage = '';
  bool showError = false;
  int selectedTab = 0;

  String get _currentUsername {
    final user = FirebaseAuth.instance.currentUser;
    // prefer displayName; if none, use email
    return user?.displayName ?? user?.email ?? 'Unknown';
  }

  @override
  void dispose() {
    nameController.dispose();
    codeController.dispose();
    emailController.dispose();
    super.dispose();
  }

  Future<void> _createHousehold() async {
    if (nameController.text.trim().isEmpty) {
      setState(() {
        showError = true;
        errorMessage = 'Please enter a household name.';
      });
      return;
    }

    setState(() {
      loading = true;
      showError = false;
    });

    try {
      await _service.createHousehold(nameController.text.trim());
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRouter.shell);
    } catch (e) {
      setState(() {
        showError = true;
        errorMessage = 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _joinByCode() async {
    if (codeController.text.trim().isEmpty) {
      setState(() {
        showError = true;
        errorMessage = 'Please enter an invite code.';
      });
      return;
    }

    setState(() {
      loading = true;
      showError = false;
    });

    try {
      await _service.joinByCode(codeController.text.trim());
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRouter.shell);
    } catch (e) {
      setState(() {
        showError = true;
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _joinByEmail() async {
    if (emailController.text.trim().isEmpty) {
      setState(() {
        showError = true;
        errorMessage = 'Please enter an email address.';
      });
      return;
    }

    setState(() {
      loading = true;
      showError = false;
    });

    try {
      final householdId = await _service.getCurrentHouseholdId();
      if (householdId == null) {
        setState(() {
          showError = true;
          errorMessage = 'You need to create a household first.';
          loading = false;
        });
        return;
      }
      await _service.inviteByEmail(emailController.text.trim(), householdId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Roommate added successfully.')),
      );
      emailController.clear();
    } catch (e) {
      setState(() {
        showError = true;
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _signOut() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRouter.login,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),

                    const Center(
                      child: AppLogo(type: LogoType.wordmark, width: 220),
                    ),

                    const SizedBox(height: 40),

                    const Text(
                      'Set up your household',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Create a new household or join an existing one.',
                      style: TextStyle(fontSize: 16, color: AppColors.muted),
                    ),

                    const SizedBox(height: 28),

                    Row(
                      children: [
                        _TabButton(
                          label: 'Create',
                          selected: selectedTab == 0,
                          onTap: () => setState(() {
                            selectedTab = 0;
                            showError = false;
                          }),
                        ),
                        const SizedBox(width: 12),
                        _TabButton(
                          label: 'Join by Code',
                          selected: selectedTab == 1,
                          onTap: () => setState(() {
                            selectedTab = 1;
                            showError = false;
                          }),
                        ),
                        const SizedBox(width: 12),
                        _TabButton(
                          label: 'Invite',
                          selected: selectedTab == 2,
                          onTap: () => setState(() {
                            selectedTab = 2;
                            showError = false;
                          }),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    if (selectedTab == 0) ...[
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          hintText: 'Household name',
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (showError)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            errorMessage,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      PrimaryButton(
                        label: loading ? 'Creating...' : 'Create Household',
                        onPressed: loading ? null : _createHousehold,
                      ),
                    ],

                    if (selectedTab == 1) ...[
                      TextField(
                        controller: codeController,
                        decoration: const InputDecoration(
                          hintText: 'Invite code',
                        ),
                        inputFormatters: [UpperCaseTextFormatter()],
                      ),
                      const SizedBox(height: 24),
                      if (showError)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            errorMessage,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      PrimaryButton(
                        label: loading ? 'Joining...' : 'Join Household',
                        onPressed: loading ? null : _joinByCode,
                      ),
                    ],

                    if (selectedTab == 2) ...[
                      const Text(
                        'Enter the email address of someone you want to add to your household. They must already have a ChoreMate account.',
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.muted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          hintText: 'Roommate email',
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 24),
                      if (showError)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            errorMessage,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      PrimaryButton(
                        label: loading ? 'Inviting...' : 'Add Roommate',
                        onPressed: loading ? null : _joinByEmail,
                      ),
                    ],

                    const SizedBox(height: 36),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.muted,
                        ),
                        children: [
                          TextSpan(text: 'Logged in as $_currentUsername • '),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.baseline,
                            baseline: TextBaseline.alphabetic,
                            child: GestureDetector(
                              onTap: _signOut,
                              child: const Text(
                                'Sign out',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: AppColors.blue, // brand link blue
                                  decorationColor: AppColors.blue,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.blue : AppColors.field,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.muted,
          ),
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
