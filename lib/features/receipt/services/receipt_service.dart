import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../orders/domain/order_model.dart';
import '../../settings/domain/settings_model.dart';

class ReceiptService {
  ReceiptService._();

  static String generateTextSummary(OrderModel order, AppSettings settings) {
    final currency = settings.currency;
    final buffer = StringBuffer();

    buffer.writeln('========================================');
    buffer.writeln('             MARKETLEDGER');
    buffer.writeln('             ORDER RECEIPT');
    buffer.writeln('========================================');
    buffer.writeln('Order #: ${order.orderNumber}');
    buffer.writeln('Date:    ${DateFormatter.formatDateTime(order.orderDate)}');
    buffer.writeln('Status:  ${order.status.label.toUpperCase()} | Payment: ${order.paymentStatus.label.toUpperCase()}');
    if (order.deliveryDate != null) {
      buffer.writeln('Delivery: ${DateFormatter.formatDate(order.deliveryDate)}');
    }
    buffer.writeln('----------------------------------------');

    final customer = order.customer;
    buffer.writeln('CUSTOMER / SHOP:');
    if (customer != null) {
      buffer.writeln('Shop:    ${customer.shopName}');
      buffer.writeln('Owner:   ${customer.ownerName}');
      if (customer.phone.isNotEmpty) buffer.writeln('Phone:   ${customer.phone}');
      if (customer.marketArea.isNotEmpty) buffer.writeln('Area:    ${customer.marketArea}');
      if (customer.address.isNotEmpty) buffer.writeln('Address: ${customer.address}');
    } else {
      buffer.writeln('Customer ID: ${order.customerId}');
    }
    buffer.writeln('----------------------------------------');

    buffer.writeln('ITEMS:');
    if (order.items.isEmpty) {
      buffer.writeln('  (No item details recorded)');
    } else {
      for (int i = 0; i < order.items.length; i++) {
        final item = order.items[i];
        final lineQty = item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toString();
        buffer.writeln('${i + 1}. ${item.productNameSnapshot}');
        buffer.writeln('   $lineQty ${item.unit} x ${CurrencyFormatter.format(item.unitPrice, currency: currency)} = ${CurrencyFormatter.format(item.lineTotal, currency: currency)}');
        if (item.discountAmount > 0) {
          buffer.writeln('   (Item Disc: -${CurrencyFormatter.format(item.discountAmount, currency: currency)})');
        }
      }
    }
    buffer.writeln('----------------------------------------');

    buffer.writeln('Subtotal:        ${CurrencyFormatter.format(order.subtotal, currency: currency)}');
    if (order.discountAmount > 0) {
      buffer.writeln('Order Discount: -${CurrencyFormatter.format(order.discountAmount, currency: currency)}');
    }
    if (order.deliveryCharge > 0) {
      buffer.writeln('Delivery Charge: +${CurrencyFormatter.format(order.deliveryCharge, currency: currency)}');
    }
    buffer.writeln('----------------------------------------');
    buffer.writeln('GRAND TOTAL:     ${CurrencyFormatter.format(order.grandTotal, currency: currency)}');
    buffer.writeln('Advance Paid:    ${CurrencyFormatter.format(order.advanceAmount, currency: currency)}');
    buffer.writeln('OUTSTANDING:     ${CurrencyFormatter.format(order.balanceAmount, currency: currency)}');
    buffer.writeln('----------------------------------------');

    if (order.payments.isNotEmpty) {
      buffer.writeln('PAYMENT LEDGER:');
      for (final p in order.payments) {
        final ref = p.referenceNumber != null && p.referenceNumber!.isNotEmpty ? ' (${p.referenceNumber})' : '';
        buffer.writeln('• ${DateFormatter.formatDate(p.paidAt)}: ${CurrencyFormatter.format(p.amount, currency: currency)} [${p.method.label}]$ref');
      }
      buffer.writeln('----------------------------------------');
    }

    if (order.notes != null && order.notes!.trim().isNotEmpty) {
      buffer.writeln('Notes: ${order.notes!.trim()}');
      buffer.writeln('----------------------------------------');
    }

    buffer.writeln('Sales Representative:');
    buffer.writeln('${settings.salespersonName} (${settings.salespersonPhone})');
    buffer.writeln(settings.companyName);
    buffer.writeln('========================================');
    buffer.writeln('    Thank you for your business!');
    buffer.writeln('========================================');

    return buffer.toString();
  }

  static Future<void> shareReceipt(OrderModel order, AppSettings settings) async {
    final text = generateTextSummary(order, settings);
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: 'MarketLedger Order Summary: ${order.orderNumber}',
      ),
    );
  }

  static Future<void> copyToClipboard(BuildContext context, OrderModel order, AppSettings settings) async {
    final text = generateTextSummary(order, settings);
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order summary copied to clipboard!'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
