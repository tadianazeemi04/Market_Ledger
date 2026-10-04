import 'package:flutter/material.dart';
import '../constants/enums.dart';
import '../theme/app_colors.dart';

class OrderStatusChip extends StatelessWidget {
  final OrderStatus status;
  final bool isCompact;

  const OrderStatusChip({
    super.key,
    required this.status,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final (bgColor, textColor, icon) = switch (status) {
      OrderStatus.draft => (AppColors.draftBg, AppColors.draftText, Icons.edit_note_rounded),
      OrderStatus.confirmed => (AppColors.confirmedBg, AppColors.confirmedText, Icons.check_circle_outline_rounded),
      OrderStatus.processing => (AppColors.processingBg, AppColors.processingText, Icons.sync_rounded),
      OrderStatus.delivered => (AppColors.deliveredBg, AppColors.deliveredText, Icons.task_alt_rounded),
      OrderStatus.cancelled => (AppColors.cancelledBg, AppColors.cancelledText, Icons.cancel_outlined),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 10,
        vertical: isCompact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isCompact ? 12 : 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              color: textColor,
              fontSize: isCompact ? 11 : 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentStatusChip extends StatelessWidget {
  final PaymentStatus status;
  final bool isCompact;

  const PaymentStatusChip({
    super.key,
    required this.status,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final (bgColor, textColor, icon) = switch (status) {
      PaymentStatus.unpaid => (AppColors.unpaidBg, AppColors.unpaidText, Icons.error_outline_rounded),
      PaymentStatus.partial => (AppColors.partialBg, AppColors.partialText, Icons.timelapse_rounded),
      PaymentStatus.paid => (AppColors.paidBg, AppColors.paidText, Icons.paid_outlined),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 10,
        vertical: isCompact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isCompact ? 12 : 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              color: textColor,
              fontSize: isCompact ? 11 : 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
