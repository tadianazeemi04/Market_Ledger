import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/workflow_guide_dialog.dart';
import '../../customers/presentation/customer_providers.dart';
import '../../dashboard/presentation/dashboard_provider.dart';
import '../../onboarding/presentation/onboarding_screen.dart';
import '../../orders/presentation/order_providers.dart';
import '../../products/presentation/product_providers.dart';
import '../../../core/utils/string_utils.dart';
import 'data_recovery_screen.dart';
import 'settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _companyController;
  late TextEditingController _salespersonNameController;
  late TextEditingController _salespersonPhoneController;
  late TextEditingController _ageController;
  late String _currency;

  bool _initialized = false;
  bool _isSaving = false;
  bool _isLoadingDemo = false;
  bool _isSwitchingBack = false;
  Map<String, dynamic>? _savedUserProfile;

  final List<String> _supportedCurrencies = [
    'PKR (Rs.)',
    'USD (\$)',
    'EUR (€)',
    'GBP (£)',
    'AED (AED)',
    'SAR (SAR)',
    'INR (₹)',
  ];

  void _initFields(AppSettings settings) {
    if (_initialized) {
      if (_companyController.text != settings.companyName ||
          _salespersonNameController.text != settings.salespersonName) {
        _companyController.text = settings.companyName;
        _salespersonNameController.text = settings.salespersonName;
        _salespersonPhoneController.text = settings.salespersonPhone;
        _ageController.text =
            settings.userAge != null ? settings.userAge.toString() : '';
        _currency = _supportedCurrencies.contains(settings.currency)
            ? settings.currency
            : 'PKR (Rs.)';
      }
      return;
    }
    _companyController = TextEditingController(text: settings.companyName);
    _salespersonNameController =
        TextEditingController(text: settings.salespersonName);
    _salespersonPhoneController =
        TextEditingController(text: settings.salespersonPhone);
    _ageController = TextEditingController(
      text: settings.userAge != null ? settings.userAge.toString() : '',
    );
    _currency = _supportedCurrencies.contains(settings.currency)
        ? settings.currency
        : 'PKR (Rs.)';
    _initialized = true;
    _checkSavedAccount();
  }

  Future<void> _checkSavedAccount() async {
    try {
      final profile = await DatabaseHelper.instance.getSavedUserProfile();
      if (mounted) {
        setState(() {
          _savedUserProfile = profile;
        });
      }
    } catch (_) {
      // Gracefully handle uninitialized database in unit tests
    }
  }

  @override
  void dispose() {
    if (_initialized) {
      _companyController.dispose();
      _salespersonNameController.dispose();
      _salespersonPhoneController.dispose();
      _ageController.dispose();
    }
    super.dispose();
  }

  Future<void> _saveSettings(AppSettings currentSettings) async {
    if (!_formKey.currentState!.validate()) return;

    final newCompany = _companyController.text.trim();
    if (newCompany.toLowerCase() !=
        currentSettings.companyName.trim().toLowerCase()) {
      final isTaken =
          await ref.read(settingsRepositoryProvider).isCompanyNameTaken(
                newCompany,
                excludeCompanyName: currentSettings.companyName,
                excludeActiveAccount: true,
              );
      if (isTaken) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'A company named "$newCompany" already exists. Please choose a unique company name.',
              ),
              backgroundColor: AppColors.errorRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final ageText = _ageController.text.trim();
      final age = ageText.isNotEmpty ? int.tryParse(ageText) : null;

      final updated = currentSettings.copyWith(
        companyName: newCompany,
        salespersonName: _salespersonNameController.text.trim(),
        salespersonPhone: _salespersonPhoneController.text.trim(),
        userAge: age,
        currency: _currency,
      );

      await ref.read(settingsProvider.notifier).updateSettings(updated);
      await ref.read(settingsRepositoryProvider).snapshotCurrentAccount();
      ref.invalidate(savedAccountsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully!'),
            backgroundColor: AppColors.emeraldGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _exploreDemoAccount() async {
    final hasExistingProfile =
        _salespersonNameController.text.trim().isNotEmpty;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Explore Demo Account?',
      message: hasExistingProfile
          ? 'Your active account data (${_salespersonNameController.text.trim()}) will be safely preserved. You can switch back at any time from Settings.'
          : 'This will load pre-configured wholesale demo data (shops, orders, products, and advance receipts) for review and testing.',
      confirmLabel: 'Explore Demo Account',
      confirmColor: AppColors.primaryNavy,
      icon: Icons.travel_explore_rounded,
    );

    if (confirmed && mounted) {
      setState(() => _isLoadingDemo = true);
      try {
        await DatabaseHelper.instance.setupDemoAccount();

        // Invalidate providers
        ref.invalidate(settingsProvider);
        ref.invalidate(dashboardProvider);
        ref.invalidate(orderListProvider);
        ref.invalidate(customerListProvider);
        ref.invalidate(productListProvider);
        ref.invalidate(savedAccountsProvider);

        _initialized = false;
        await _checkSavedAccount();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Demo Review Account loaded! You can switch back anytime in Settings.',
              ),
              backgroundColor: AppColors.emeraldGreen,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load demo account: $e'),
              backgroundColor: AppColors.errorRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoadingDemo = false);
      }
    }
  }

  Future<void> _switchToAccount(SavedAccount account) async {
    setState(() => _isSwitchingBack = true);
    try {
      final success = await ref
          .read(settingsRepositoryProvider)
          .switchToSavedAccount(account.id);
      if (!success) {
        throw Exception('Account could not be restored.');
      }

      ref.invalidate(settingsProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(orderListProvider);
      ref.invalidate(customerListProvider);
      ref.invalidate(productListProvider);
      ref.invalidate(savedAccountsProvider);

      _initialized = false;
      await _checkSavedAccount();

      if (mounted) {
        final name = StringUtils.toTitleCase(account.salespersonName);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Switched to $name\'s account (${account.companyName}). All data restored.',
            ),
            backgroundColor: AppColors.emeraldGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to switch account: $e'),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSwitchingBack = false);
    }
  }

  Future<void> _deleteAccount(SavedAccount account) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete Account?',
      message:
          'Are you sure you want to permanently delete ${account.salespersonName}\'s account (${account.companyName})? All local orders, customers, and data for this profile will be permanently removed.',
      confirmLabel: 'Delete Account',
      confirmColor: AppColors.errorRed,
      icon: Icons.delete_forever_rounded,
    );

    if (confirmed && mounted) {
      try {
        await ref
            .read(settingsRepositoryProvider)
            .deleteSavedAccount(account.id);
        ref.invalidate(savedAccountsProvider);
        await _checkSavedAccount();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Account for ${account.companyName} was removed.',
              ),
              backgroundColor: AppColors.emeraldGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete account: $e'),
              backgroundColor: AppColors.errorRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _showAddNewAccountDialog() async {
    final nameCtrl = TextEditingController();
    final companyCtrl = TextEditingController();
    final ageCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final dialogFormKey = GlobalKey<FormState>();
    bool isCreating = false;

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.person_add_rounded, color: AppColors.primaryNavy),
                  SizedBox(width: 10),
                  Text(
                    'Create New Account',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepNavy,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Form(
                    key: dialogFormKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Your current account will remain safely saved in offline storage. You can switch between accounts anytime.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 14),
                        CustomTextField(
                          controller: companyCtrl,
                          label: 'Company / Agency Name',
                          hint: 'e.g. Beta Distributors',
                          prefixIcon: Icons.business_rounded,
                          isRequired: true,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          controller: nameCtrl,
                          label: 'Sales Representative Name',
                          hint: 'e.g. Tariq Mehmood',
                          prefixIcon: Icons.person_outline_rounded,
                          isRequired: true,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z\s\.\-]'),
                            ),
                          ],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            if (RegExp(r'\d').hasMatch(v)) {
                              return 'Name can only contain letters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          controller: ageCtrl,
                          label: 'Age',
                          hint: 'e.g. 28',
                          prefixIcon: Icons.cake_outlined,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (v) {
                            if (v != null && v.trim().isNotEmpty) {
                              final parsed = int.tryParse(v.trim());
                              if (parsed == null) return 'Must be a number';
                              if (parsed < 4) return 'Age must be 4 or older';
                              if (parsed > 120) return 'Invalid age';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          controller: phoneCtrl,
                          label: 'Phone (Optional)',
                          hint: 'e.g. +92 300 1234567',
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isCreating ? null : () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isCreating
                      ? null
                      : () async {
                          if (!dialogFormKey.currentState!.validate()) return;

                          final comp = companyCtrl.text.trim();
                          final name = nameCtrl.text.trim();
                          final ageText = ageCtrl.text.trim();
                          final age =
                              ageText.isNotEmpty ? int.tryParse(ageText) : null;
                          final phone = phoneCtrl.text.trim();

                          // Validate unique company name
                          setDialogState(() => isCreating = true);
                          final isTaken = await ref
                              .read(settingsRepositoryProvider)
                              .isCompanyNameTaken(
                                comp,
                                excludeActiveAccount: false,
                              );

                          if (isTaken) {
                            setDialogState(() => isCreating = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'A company named "$comp" already exists. Please choose a unique company name.',
                                  ),
                                  backgroundColor: AppColors.errorRed,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                            return;
                          }

                          try {
                            await ref
                                .read(settingsRepositoryProvider)
                                .setupCleanUserAccount(
                                  name: name,
                                  company: comp,
                                  age: age,
                                  phone: phone,
                                );

                            ref.invalidate(settingsProvider);
                            ref.invalidate(dashboardProvider);
                            ref.invalidate(orderListProvider);
                            ref.invalidate(customerListProvider);
                            ref.invalidate(productListProvider);
                            ref.invalidate(savedAccountsProvider);

                            _initialized = false;
                            await _checkSavedAccount();

                            if (dialogCtx.mounted) {
                              Navigator.of(dialogCtx).pop();
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Account for ${StringUtils.toTitleCase(name)} ($comp) created successfully!',
                                  ),
                                  backgroundColor: AppColors.emeraldGreen,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (err) {
                            setDialogState(() => isCreating = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('Failed to create account: $err'),
                                  backgroundColor: AppColors.errorRed,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    foregroundColor: AppColors.white,
                  ),
                  child: isCreating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : const Text('Create Account'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _leaveDemoAccount({required bool hasSavedAccount}) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: hasSavedAccount ? 'Create New Account?' : 'Leave Demo Account?',
      message: hasSavedAccount
          ? 'You have a saved account for ${_savedUserProfile?['salespersonName'] ?? 'your profile'}. Creating a new account will leave the demo session and allow you to set up a new profile.'
          : 'Leaving the demo account will reset sample records so you can set up your own salesperson profile.',
      confirmLabel: 'Proceed',
      confirmColor: AppColors.amberAccent,
      icon: Icons.logout_rounded,
    );

    if (confirmed && mounted) {
      try {
        await DatabaseHelper.instance.leaveDemoAccount(clearStash: false);
        ref.invalidate(settingsProvider);
        ref.invalidate(dashboardProvider);
        ref.invalidate(orderListProvider);
        ref.invalidate(customerListProvider);
        ref.invalidate(productListProvider);
        ref.invalidate(savedAccountsProvider);

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const OnboardingScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to leave demo account: $e'),
              backgroundColor: AppColors.errorRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _exportJson() async {
    try {
      final repo = ref.read(settingsRepositoryProvider);
      final jsonStr = await repo.exportAsJsonString();
      await SharePlus.instance.share(
        ShareParams(
          text: jsonStr,
          subject: 'MarketLedger Data Backup (JSON)',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _exportCustomersCsv() async {
    try {
      final repo = ref.read(settingsRepositoryProvider);
      final csvStr = await repo.exportCustomersAsCsv();
      await SharePlus.instance.share(
        ShareParams(
          text: csvStr,
          subject: 'MarketLedger Customers Export (CSV)',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _exportOrdersCsv() async {
    try {
      final repo = ref.read(settingsRepositoryProvider);
      final csvStr = await repo.exportOrdersAsCsv();
      await SharePlus.instance.share(
        ShareParams(
          text: csvStr,
          subject: 'MarketLedger Orders Export (CSV)',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _resetDemoData() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Reset Demo Data?',
      message:
          'This will replace all current orders, customers, and payments with the realistic wholesale demo seed data. This action cannot be undone.',
      confirmLabel: 'Reset Data',
      confirmColor: AppColors.amberAccent,
      icon: Icons.restore_rounded,
    );

    if (confirmed && mounted) {
      try {
        final repo = ref.read(settingsRepositoryProvider);
        await repo.resetToDemoData();

        ref.invalidate(settingsProvider);
        ref.invalidate(dashboardProvider);
        ref.invalidate(orderListProvider);
        ref.invalidate(customerListProvider);
        ref.invalidate(productListProvider);

        _initialized = false;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Demo sample data restored successfully!'),
              backgroundColor: AppColors.emeraldGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reset failed: $e'),
              backgroundColor: AppColors.errorRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final savedAccountsAsync = ref.watch(savedAccountsProvider);
    final savedAccounts = savedAccountsAsync.value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Settings & Profile'),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading settings: $err')),
        data: (settings) {
          _initFields(settings);

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Demo Review Account Card / Switch Option
                if (settings.isDemoAccount) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.emeraldGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.emeraldGreen.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.emeraldGreen,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.verified_user_rounded,
                                color: AppColors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Demo Review Account Active',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.deepNavy,
                                    ),
                                  ),
                                  Text(
                                    'Apple Review & Testing Mode',
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
                        const SizedBox(height: 10),
                        const Text(
                          'You are exploring pre-seeded wholesale data (shops, orders, catalog products, and advances). Apple reviewers and testers can inspect every ledger feature without manual registration.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryText,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (savedAccounts.isNotEmpty) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Saved Accounts (${savedAccounts.length})',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.deepNavy,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _showAddNewAccountDialog,
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Add Account', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...savedAccounts.map((acc) {
                            final titleName = StringUtils.toTitleCase(acc.salespersonName);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppColors.primaryNavy.withValues(alpha: 0.1),
                                    child: Text(
                                      titleName.isNotEmpty ? titleName[0] : 'S',
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
                                          titleName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: AppColors.deepNavy,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          acc.companyName,
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
                                    onPressed: _isSwitchingBack ? null : () => _switchToAccount(acc),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryNavy,
                                      foregroundColor: AppColors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      minimumSize: const Size(60, 34),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text('Switch', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.errorRed),
                                    tooltip: 'Delete Account',
                                    onPressed: () => _deleteAccount(acc),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ] else ...[
                          OutlinedButton.icon(
                            onPressed: () => _leaveDemoAccount(hasSavedAccount: false),
                            icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                            label: const Text(
                              'Leave Demo & Create Your Account',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.deepNavy,
                              side: const BorderSide(
                                color: AppColors.primaryNavy,
                                width: 1.2,
                              ),
                              minimumSize: const Size(double.infinity, 44),
                              backgroundColor: AppColors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  // Accounts & Profiles Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Accounts & Profiles',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.deepNavy,
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _showAddNewAccountDialog,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add Account', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryNavy,
                                side: const BorderSide(color: AppColors.primaryNavy),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                minimumSize: const Size(0, 32),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Active Account Tile
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.emeraldGreen.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.emeraldGreen.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.emeraldGreen,
                                child: Text(
                                  settings.salespersonName.isNotEmpty
                                      ? settings.salespersonName.trim()[0].toUpperCase()
                                      : 'S',
                                  style: const TextStyle(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
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
                                            StringUtils.toTitleCase(settings.salespersonName),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: AppColors.deepNavy,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.emeraldGreen,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'ACTIVE',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      settings.companyName.isNotEmpty
                                          ? settings.companyName
                                          : 'No company name set',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.secondaryText,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Other saved accounts if any
                        Builder(
                          builder: (context) {
                            final otherAccounts = savedAccounts.where((a) {
                              return a.companyName.trim().toLowerCase() !=
                                  settings.companyName.trim().toLowerCase();
                            }).toList();

                            if (otherAccounts.isEmpty) return const SizedBox.shrink();

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 12),
                                Text(
                                  'Other Saved Accounts (${otherAccounts.length})',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.deepNavy,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...otherAccounts.map((acc) {
                                  final formatted = StringUtils.toTitleCase(acc.salespersonName);
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: AppColors.primaryNavy.withValues(alpha: 0.1),
                                          child: Text(
                                            formatted.isNotEmpty ? formatted[0] : 'S',
                                            style: const TextStyle(
                                              color: AppColors.primaryNavy,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                formatted,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                  color: AppColors.deepNavy,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                acc.companyName,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.secondaryText,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        ElevatedButton(
                                          onPressed: _isSwitchingBack
                                              ? null
                                              : () => _switchToAccount(acc),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primaryNavy,
                                            foregroundColor: AppColors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            minimumSize: const Size(54, 30),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                          ),
                                          child: const Text('Switch', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                        ),
                                        const SizedBox(width: 2),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.errorRed),
                                          tooltip: 'Delete Account',
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () => _deleteAccount(acc),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Not currently in demo account: clean Explore Demo Account button
                  ElevatedButton.icon(
                    onPressed: _isLoadingDemo ? null : _exploreDemoAccount,
                    icon: _isLoadingDemo
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                        : const Icon(Icons.travel_explore_rounded, size: 18),
                    label: const Text(
                      'Explore Demo Account',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryNavy,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // In-App Workflow Guide Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'App Workflow Guide & Tour',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepNavy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Learn the 3-step field sales workflow, what each section is for, and how to record orders.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Material(
                        color: Colors.transparent,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryNavy.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.auto_stories_rounded,
                              color: AppColors.primaryNavy,
                              size: 22,
                            ),
                          ),
                          title: const Text(
                            'Open Workflow Guide',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          subtitle: const Text(
                            'Interactive walkthrough & step-by-step instructions',
                            style: TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                          onTap: () => WorkflowGuideDialog.show(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Data Recovery & Trash Option Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Data Recovery & Trash',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepNavy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Recover or permanently remove deleted orders, shops, and products.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Material(
                        color: Colors.transparent,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.emeraldGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.restore_from_trash_rounded,
                              color: AppColors.emeraldGreen,
                              size: 22,
                            ),
                          ),
                          title: const Text(
                            'Recover Deleted Data',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.deepNavy,
                            ),
                          ),
                          subtitle: const Text(
                            'Inspect trash and restore accidentally deleted items',
                            style: TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const DataRecoveryScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Business & Salesperson Profile Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Distributor & Salesperson Profile',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepNavy,
                        ),
                      ),
                      const SizedBox(height: 14),
                      CustomTextField(
                        controller: _companyController,
                        label: 'Company / Agency Name',
                        hint: 'e.g. Alpha Wholesale Distributors',
                        prefixIcon: Icons.business_rounded,
                        isRequired: true,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: _salespersonNameController,
                        label: 'Sales Representative Name',
                        hint: 'e.g. Tariq Mehmood',
                        prefixIcon: Icons.badge_outlined,
                        isRequired: true,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z\s\.\-]'),
                          ),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (RegExp(r'\d').hasMatch(v)) {
                            return 'Name can only contain letters, no numbers';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: _ageController,
                        label: 'Age',
                        hint: 'e.g. 28',
                        prefixIcon: Icons.cake_outlined,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (v) {
                          if (v != null && v.trim().isNotEmpty) {
                            final parsed = int.tryParse(v.trim());
                            if (parsed == null) return 'Must be a number';
                            if (parsed < 4) return 'Age must be 4 or older';
                            if (parsed > 120) return 'Invalid age';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: _salespersonPhoneController,
                        label: 'Salesperson Phone Number',
                        hint: 'e.g. +92 300 1234567',
                        prefixIcon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isSaving
                            ? null
                            : () => _saveSettings(settings),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: AppColors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Save Profile Changes'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Regional & Currency Settings Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Currency & Regional Preferences',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepNavy,
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: _currency,
                        decoration: const InputDecoration(
                          labelText: 'Default Currency Format',
                          prefixIcon: Icon(
                            Icons.monetization_on_outlined,
                            size: 20,
                          ),
                        ),
                        items: _supportedCurrencies.map((c) {
                          return DropdownMenuItem(value: c, child: Text(c));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _currency = val);
                            _saveSettings(settings);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Data Backup & Export Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Data Backup & Export',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepNavy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Export your offline data to CSV or JSON format for accounting and reporting.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Material(
                        color: Colors.transparent,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryNavy.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.table_chart_outlined,
                              color: AppColors.primaryNavy,
                              size: 20,
                            ),
                          ),
                          title: const Text(
                            'Export Orders (CSV)',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: const Text(
                            'Spreadsheet format of all wholesale orders',
                            style: TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                          ),
                          onTap: _exportOrdersCsv,
                        ),
                      ),
                      const Divider(),
                      Material(
                        color: Colors.transparent,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryNavy.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.people_outline_rounded,
                              color: AppColors.primaryNavy,
                              size: 20,
                            ),
                          ),
                          title: const Text(
                            'Export Customers & Shops (CSV)',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: const Text(
                            'Full directory of retailers and coordinates',
                            style: TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                          ),
                          onTap: _exportCustomersCsv,
                        ),
                      ),
                      const Divider(),
                      Material(
                        color: Colors.transparent,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryNavy.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.data_object_rounded,
                              color: AppColors.primaryNavy,
                              size: 20,
                            ),
                          ),
                          title: const Text(
                            'Export Full Database (JSON)',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: const Text(
                            'Complete backup of all tables and ledger records',
                            style: TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                          ),
                          onTap: _exportJson,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Database Reset Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Database Reset & Demo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepNavy,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Restore sample wholesale products, demo shops, and initial orders.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _resetDemoData,
                        icon: const Icon(
                          Icons.restore_rounded,
                          size: 18,
                          color: AppColors.amberAccent,
                        ),
                        label: const Text('Reset to Sample / Demo Data'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.deepNavy,
                          side: const BorderSide(color: AppColors.border),
                          minimumSize: const Size(double.infinity, 46),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Brand Card & Version Info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.inputBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Image.asset(
                        'lib/Logo/MarketLedgerLogo.png',
                        height: 52,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.storefront_rounded,
                          color: AppColors.primaryNavy,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'MarketLedger Mobile',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.deepNavy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Version 1.0.0 • Offline-First Wholesale Ledger',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Designed for field salespeople in busy local markets.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.secondaryText,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}
