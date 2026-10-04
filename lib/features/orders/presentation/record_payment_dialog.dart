import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../dashboard/presentation/dashboard_provider.dart';
import '../../payments/presentation/payment_providers.dart';
import '../../settings/presentation/settings_provider.dart';
import '../domain/order_model.dart';
import 'order_providers.dart';

class RecordPaymentDialog extends ConsumerStatefulWidget {
  final OrderModel order;

  const RecordPaymentDialog({super.key, required this.order});

  static Future<bool?> show(BuildContext context, OrderModel order) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DisplayFeatureSubScreen(
        anchorPoint: Offset.zero,
        child: RecordPaymentDialog(order: order),
      ),
    );
  }

  @override
  ConsumerState<RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends ConsumerState<RecordPaymentDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _amountController;
  final TextEditingController _refController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  PaymentMethod _method = PaymentMethod.cash;
  DateTime _paidAt = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Default to remaining balance
    _amountController = TextEditingController(
      text: widget.order.balanceAmount > 0
          ? widget.order.balanceAmount.toStringAsFixed(0)
          : '0',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _refController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) return;

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(paymentRepositoryProvider);
      await repo.recordPayment(
        orderId: widget.order.id,
        amount: amount,
        method: _method,
        referenceNumber: _refController.text.trim().isNotEmpty ? _refController.text.trim() : null,
        note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
        paidAt: _paidAt,
      );

      ref.invalidate(orderDetailProvider(widget.order.id));
      ref.invalidate(orderPaymentsProvider(widget.order.id));
      ref.invalidate(orderListProvider);
      ref.invalidate(dashboardProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment of ${CurrencyFormatter.format(amount)} recorded successfully!'),
            backgroundColor: AppColors.emeraldGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record payment: $e'),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.value ?? const AppSettings();

    final inputAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final remainingAfterPayment = (widget.order.balanceAmount - inputAmount).clamp(0.0, double.infinity);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Record Payment',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepNavy,
                    ),
                  ),
                  Text(
                    'Balance: ${CurrencyFormatter.format(widget.order.balanceAmount, currency: settings.currency)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.amberAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Amount Field with quick fill button
              CustomTextField(
                controller: _amountController,
                label: 'Payment Amount',
                prefixIcon: Icons.payments_outlined,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                isRequired: true,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                onChanged: (_) => setState(() {}),
                suffix: TextButton(
                  onPressed: () {
                    _amountController.text = widget.order.balanceAmount.toStringAsFixed(0);
                    setState(() {});
                  },
                  child: const Text('Full Balance', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Please enter payment amount';
                  final val = double.tryParse(v);
                  if (val == null || val <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Payment Method & Date
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment Method',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryText),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<PaymentMethod>(
                          initialValue: _method,
                          isExpanded: true,
                          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
                          items: PaymentMethod.values.map((m) {
                            return DropdownMenuItem(value: m, child: Text(m.label, style: const TextStyle(fontSize: 12)));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _method = val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment Date',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryText),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _paidAt,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              setState(() => _paidAt = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.inputBackground,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  DateFormatter.formatDate(_paidAt),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.secondaryText),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              CustomTextField(
                controller: _refController,
                label: 'Reference # / Cheque / TID (Optional)',
                hint: 'e.g. CQ-90218, TID-771829',
                prefixIcon: Icons.tag_rounded,
              ),
              const SizedBox(height: 12),

              CustomTextField(
                controller: _noteController,
                label: 'Payment Note (Optional)',
                hint: 'e.g. Received cash at market visit',
                prefixIcon: Icons.edit_note_rounded,
              ),
              const SizedBox(height: 16),

              // Preview Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.inputBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('New Remaining Balance:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(
                      CurrencyFormatter.format(remainingAfterPayment, currency: settings.currency),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: remainingAfterPayment == 0 ? AppColors.emeraldGreen : AppColors.amberAccent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _isSaving ? null : _submitPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emeraldGreen,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2),
                      )
                    : const Text('Save Payment'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
