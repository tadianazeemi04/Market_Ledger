import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../domain/customer_model.dart';
import 'customer_providers.dart';

class CustomerFormScreen extends ConsumerStatefulWidget {
  final Customer? customerToEdit;

  const CustomerFormScreen({super.key, this.customerToEdit});

  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _shopNameController;
  late TextEditingController _ownerNameController;
  late TextEditingController _phoneController;
  late TextEditingController _marketAreaController;
  late TextEditingController _addressController;
  late TextEditingController _notesController;

  double? _latitude;
  double? _longitude;
  bool _isCapturingLocation = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.customerToEdit;
    _shopNameController = TextEditingController(text: c?.shopName ?? '');
    _ownerNameController = TextEditingController(text: c?.ownerName ?? '');
    _phoneController = TextEditingController(text: c?.phone ?? '');
    _marketAreaController = TextEditingController(text: c?.marketArea ?? '');
    _addressController = TextEditingController(text: c?.address ?? '');
    _notesController = TextEditingController(text: c?.notes ?? '');
    _latitude = c?.latitude;
    _longitude = c?.longitude;
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _marketAreaController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _captureLocation() async {
    setState(() {
      _isCapturingLocation = true;
    });

    try {
      // 1. Check if location services are enabled
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location services are disabled on this device.'),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () => Geolocator.openLocationSettings(),
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // 2. Check and request permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission was denied.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location permissions are permanently denied.'),
              action: SnackBarAction(
                label: 'App Settings',
                onPressed: () => Geolocator.openAppSettings(),
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // 3. Acquire current location
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Location captured: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
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
            content: Text('Could not capture location: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCapturingLocation = false;
        });
      }
    }
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final repo = ref.read(customerRepositoryProvider);
      final isEditing = widget.customerToEdit != null;
      final now = DateTime.now();

      final customer = Customer(
        id: isEditing ? widget.customerToEdit!.id : const Uuid().v4(),
        shopName: _shopNameController.text.trim(),
        ownerName: _ownerNameController.text.trim(),
        phone: _phoneController.text.trim(),
        marketArea: _marketAreaController.text.trim(),
        address: _addressController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        createdAt: isEditing ? widget.customerToEdit!.createdAt : now,
        updatedAt: now,
      );

      if (isEditing) {
        await repo.updateCustomer(customer);
      } else {
        await repo.createCustomer(customer);
      }

      ref.invalidate(customerListProvider);
      if (isEditing) {
        ref.invalidate(customerDetailProvider(customer.id));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Customer details updated' : 'Shop registered successfully'),
            backgroundColor: AppColors.emeraldGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(customer);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save shop: $e'),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.customerToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Shop / Customer' : 'Register New Shop'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Required basic details card
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
                    'Shop & Owner Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepNavy,
                    ),
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    controller: _shopNameController,
                    label: 'Shop / Business Name',
                    hint: 'e.g. Madina Karyana Store',
                    prefixIcon: Icons.storefront_rounded,
                    isRequired: true,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter the shop name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    controller: _ownerNameController,
                    label: 'Owner / Contact Person',
                    hint: 'e.g. Muhammad Imran',
                    prefixIcon: Icons.person_outline_rounded,
                    isRequired: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s\.\-]')),
                    ],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter the owner name';
                      }
                      if (RegExp(r'\d').hasMatch(v)) {
                        return 'Name can only contain letters, no numbers allowed';
                      }
                      if (!RegExp(r'^[a-zA-Z\s\.\-]+$').hasMatch(v.trim())) {
                        return 'Please enter letters only';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    controller: _phoneController,
                    label: 'Phone / WhatsApp Number',
                    hint: 'e.g. 0300-1234567',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9\+\-\s]')),
                    ],
                    validator: (v) {
                      if (v != null && v.trim().isNotEmpty) {
                        final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                        if (digits.length < 7) {
                          return 'Please enter a valid phone number (at least 7 digits)';
                        }
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Location & Market Area Card
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
                    'Market Location',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepNavy,
                    ),
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    controller: _marketAreaController,
                    label: 'Market / Area / Sector',
                    hint: 'e.g. Main Bazaar, Anarkali',
                    prefixIcon: Icons.map_outlined,
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    controller: _addressController,
                    label: 'Full Street Address',
                    hint: 'Shop number, street name, landmark',
                    prefixIcon: Icons.location_on_outlined,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),

                  // GPS Coordinates Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'GPS Coordinates',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _latitude != null && _longitude != null
                                ? '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
                                : 'No GPS captured yet',
                            style: TextStyle(
                              fontSize: 12,
                              color: _latitude != null ? AppColors.emeraldGreen : AppColors.secondaryText,
                              fontWeight: _latitude != null ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      if (_latitude != null)
                        IconButton(
                          tooltip: 'Clear coordinates',
                          icon: const Icon(Icons.clear_rounded, size: 20, color: AppColors.secondaryText),
                          onPressed: () {
                            setState(() {
                              _latitude = null;
                              _longitude = null;
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _isCapturingLocation ? null : _captureLocation,
                    icon: _isCapturingLocation
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded, size: 18),
                    label: Text(_isCapturingLocation ? 'Capturing Location...' : 'Capture Current GPS Location'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Additional Notes Card
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
                    'Notes & Preferences',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepNavy,
                    ),
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    controller: _notesController,
                    label: 'Shop Notes',
                    hint: 'Delivery timing, payment terms, wholesaler discount notes...',
                    prefixIcon: Icons.notes_rounded,
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            ElevatedButton(
              onPressed: _isSaving ? null : _saveCustomer,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2),
                    )
                  : Text(isEditing ? 'Update Shop Details' : 'Save Shop Record'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
