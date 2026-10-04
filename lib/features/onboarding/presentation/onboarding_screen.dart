import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../main.dart';
import '../../customers/presentation/customer_providers.dart';
import '../../dashboard/presentation/dashboard_provider.dart';
import '../../orders/presentation/order_providers.dart';
import '../../products/presentation/product_providers.dart';
import '../../../core/utils/string_utils.dart';
import '../../settings/data/settings_repository.dart';
import '../../settings/presentation/settings_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _companyController = TextEditingController();

  bool _isSubmitting = false;
  bool _isLoadingDemo = false;
  List<SavedAccount> _savedAccounts = [];

  @override
  void initState() {
    super.initState();
    _checkSavedAccounts();
  }

  Future<void> _checkSavedAccounts() async {
    try {
      final accounts = await DatabaseHelper.instance.getAllSavedAccounts();
      if (mounted) {
        setState(() {
          _savedAccounts =
              accounts.map((m) => SavedAccount.fromMap(m)).toList();
        });
      }
    } catch (_) {
      // Gracefully handle uninitialized database in unit tests
    }
  }

  Future<void> _switchToAccount(SavedAccount account) async {
    setState(() => _isSubmitting = true);
    try {
      final success =
          await DatabaseHelper.instance.switchToSavedAccount(account.id);
      if (!success) {
        throw Exception('Could not switch to saved account.');
      }

      ref.invalidate(settingsProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(orderListProvider);
      ref.invalidate(customerListProvider);
      ref.invalidate(productListProvider);

      if (!mounted) return;

      final restoredName = StringUtils.toTitleCase(account.salespersonName);

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MarketLedgerMainNavigation()),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Welcome back, $restoredName! Switched to ${account.companyName}.',
          ),
          backgroundColor: AppColors.emeraldGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restore account: $e'),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  Future<void> _submitCustomProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final company = _companyController.text.trim();

    // Check if company name is already taken
    final isTaken = await DatabaseHelper.instance.isCompanyNameTaken(
      company,
      excludeActiveAccount: true,
    );
    if (isTaken) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'A company named "$company" already exists. Please choose a unique company name.',
            ),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final name = _nameController.text.trim();
      final age = int.parse(_ageController.text.trim());

      final settingsRepo = SettingsRepository();
      await settingsRepo.setupCleanUserAccount(
        name: name,
        company: company,
        age: age,
      );

      // Invalidate all providers so 0 dummy data is loaded for real user
      ref.invalidate(settingsProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(orderListProvider);
      ref.invalidate(customerListProvider);
      ref.invalidate(productListProvider);

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MarketLedgerMainNavigation()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: $e'),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _launchDemoAccount() async {
    setState(() => _isLoadingDemo = true);
    try {
      // Seeds the full realistic wholesale review data
      await DatabaseHelper.instance.setupDemoAccount();

      // Invalidate all providers so fresh dummy data loads instantly
      ref.invalidate(settingsProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(orderListProvider);
      ref.invalidate(customerListProvider);
      ref.invalidate(productListProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demo Review Account ready with sample wholesale data!'),
          backgroundColor: AppColors.emeraldGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MarketLedgerMainNavigation()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize demo account: $e'),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingDemo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softBackground,
      appBar: AppBar(
        title: const Text('Welcome to MarketLedger'),
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Card
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryNavy.withValues(alpha: 0.1),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'lib/Logo/MarketLedgerLogo.png',
                            width: 64,
                            height: 64,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.storefront_rounded,
                              size: 48,
                              color: AppColors.primaryNavy,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Set Up Your Profile',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.deepNavy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Enter your salesperson details to start recording field wholesale orders locally on this device.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.secondaryText,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (_savedAccounts.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.emeraldGreen.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.emeraldGreen.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.emeraldGreen.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.switch_account_rounded,
                                color: AppColors.emeraldGreen,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _savedAccounts.length == 1
                                        ? 'Saved Account Found'
                                        : 'Saved Accounts (${_savedAccounts.length})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: AppColors.deepNavy,
                                    ),
                                  ),
                                  const Text(
                                    'Switch to your existing account with 1-tap:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.secondaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ..._savedAccounts.map((account) {
                          final formattedName =
                              StringUtils.toTitleCase(account.salespersonName);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.cardSurface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppColors.primaryNavy.withValues(alpha: 0.1),
                                  child: Text(
                                    formattedName.isNotEmpty ? formattedName[0] : 'S',
                                    style: const TextStyle(
                                      color: AppColors.primaryNavy,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        formattedName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: AppColors.deepNavy,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        account.companyName,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.secondaryText,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: _isSubmitting
                                      ? null
                                      : () => _switchToAccount(account),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.emeraldGreen,
                                    foregroundColor: AppColors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    minimumSize: const Size(64, 36),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text(
                                    'Switch',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'OR CREATE A NEW ACCOUNT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 18),
                ],

                // Profile Inputs Container
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Full Name (Strict Text-Only, No numbers allowed)
                      CustomTextField(
                        controller: _nameController,
                        label: 'Full Name',
                        hint: 'e.g. Tariq Mehmood',
                        prefixIcon: Icons.person_outline_rounded,
                        isRequired: true,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s\.\-]')),
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your name';
                          }
                          if (RegExp(r'\d').hasMatch(value)) {
                            return 'Name can only contain letters, no numbers allowed';
                          }
                          if (!RegExp(r'^[a-zA-Z\s\.\-]+$').hasMatch(value.trim())) {
                            return 'Please enter letters only';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Age (Strict Numbers-Only, Min Age 4)
                      CustomTextField(
                        controller: _ageController,
                        label: 'Age',
                        hint: 'e.g. 28',
                        prefixIcon: Icons.cake_outlined,
                        isRequired: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your age';
                          }
                          final parsed = int.tryParse(value.trim());
                          if (parsed == null) {
                            return 'Age must be a valid number';
                          }
                          if (parsed < 4) {
                            return 'Age must be 4 or older';
                          }
                          if (parsed > 120) {
                            return 'Please enter a valid age';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Company Name
                      CustomTextField(
                        controller: _companyController,
                        label: 'Company / Wholesale Agency',
                        hint: 'e.g. Al-Madina Wholesale Distributors',
                        prefixIcon: Icons.business_outlined,
                        isRequired: true,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your company name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Continue Button
                      ElevatedButton(
                        onPressed: _isSubmitting || _isLoadingDemo ? null : _submitCustomProfile,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: AppColors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text('Save & Continue'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const SizedBox(height: 20),

                // Explore Demo Account button without extra details
                OutlinedButton.icon(
                  onPressed: _isSubmitting || _isLoadingDemo ? null : _launchDemoAccount,
                  icon: _isLoadingDemo
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryNavy,
                          ),
                        )
                      : const Icon(Icons.travel_explore_rounded, size: 18),
                  label: const Text(
                    'Explore Demo Account',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryNavy,
                    side: const BorderSide(color: AppColors.primaryNavy, width: 1.5),
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
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
