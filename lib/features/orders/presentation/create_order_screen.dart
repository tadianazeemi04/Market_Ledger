import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/status_chips.dart';
import '../../customers/domain/customer_model.dart';
import '../../customers/presentation/customer_form_screen.dart';
import '../../customers/presentation/customer_providers.dart';
import '../../dashboard/presentation/dashboard_provider.dart';
import '../../products/domain/product_model.dart';
import '../../products/presentation/product_providers.dart';
import '../../settings/presentation/settings_provider.dart';
import '../domain/order_item_model.dart';
import '../domain/order_model.dart';
import 'order_detail_screen.dart';
import 'order_providers.dart';

class LineItemDraft {
  String id;
  String productId;
  String productName;
  String unit;
  double unitPrice;
  double quantity;
  double discount;

  LineItemDraft({
    required this.id,
    required this.productId,
    required this.productName,
    required this.unit,
    required this.unitPrice,
    this.quantity = 1.0,
    this.discount = 0.0,
  });

  double get lineTotal {
    final raw = (quantity * unitPrice) - discount;
    return raw > 0 ? raw : 0.0;
  }
}

class CreateOrderScreen extends ConsumerStatefulWidget {
  final Customer? preselectedCustomer;
  final OrderModel? orderToEdit;

  const CreateOrderScreen({
    super.key,
    this.preselectedCustomer,
    this.orderToEdit,
  });

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();

  Customer? _selectedCustomer;
  late String _orderNumber;
  late DateTime _orderDate;
  DateTime? _deliveryDate;
  OrderStatus _status = OrderStatus.confirmed;
  PaymentMethod _paymentMethod = PaymentMethod.cash;

  final List<LineItemDraft> _items = [];

  final TextEditingController _orderDiscountController = TextEditingController(text: '0');
  final TextEditingController _deliveryChargeController = TextEditingController(text: '0');
  final TextEditingController _advancePaymentController = TextEditingController(text: '0');
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _paymentRefController = TextEditingController();

  bool _isLoadingNumber = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedCustomer = widget.preselectedCustomer;
    _orderDate = DateTime.now();

    if (widget.orderToEdit != null) {
      final o = widget.orderToEdit!;
      _selectedCustomer = o.customer;
      _orderNumber = o.orderNumber;
      _orderDate = o.orderDate;
      _deliveryDate = o.deliveryDate;
      _status = o.status;
      _orderDiscountController.text = o.discountAmount.toStringAsFixed(0);
      _deliveryChargeController.text = o.deliveryCharge.toStringAsFixed(0);
      _advancePaymentController.text = o.advanceAmount.toStringAsFixed(0);
      _notesController.text = o.notes ?? '';
      _isLoadingNumber = false;

      for (final item in o.items) {
        _items.add(LineItemDraft(
          id: item.id,
          productId: item.productId,
          productName: item.productNameSnapshot,
          unit: item.unit,
          unitPrice: item.unitPrice,
          quantity: item.quantity,
          discount: item.discountAmount,
        ));
      }
    } else {
      _loadNextOrderNumber();
    }
  }

  @override
  void dispose() {
    _orderDiscountController.dispose();
    _deliveryChargeController.dispose();
    _advancePaymentController.dispose();
    _notesController.dispose();
    _paymentRefController.dispose();
    super.dispose();
  }

  Future<void> _loadNextOrderNumber() async {
    try {
      final repo = ref.read(orderRepositoryProvider);
      final num = await repo.generateNextOrderNumber(_orderDate);
      if (mounted) {
        setState(() {
          _orderNumber = num;
          _isLoadingNumber = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _orderNumber = 'ML-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
          _isLoadingNumber = false;
        });
      }
    }
  }

  // Financial Computations
  double get _subtotal {
    double sum = 0;
    for (final item in _items) {
      sum += item.lineTotal;
    }
    return sum;
  }

  double get _orderDiscount => double.tryParse(_orderDiscountController.text.trim()) ?? 0.0;
  double get _deliveryCharge => double.tryParse(_deliveryChargeController.text.trim()) ?? 0.0;
  double get _advancePayment => double.tryParse(_advancePaymentController.text.trim()) ?? 0.0;

  double get _grandTotal {
    final raw = (_subtotal - _orderDiscount + _deliveryCharge);
    return raw > 0 ? raw : 0.0;
  }

  double get _remainingBalance {
    final raw = _grandTotal - _advancePayment;
    return raw > 0 ? raw : 0.0;
  }

  PaymentStatus get _computedPaymentStatus {
    return PaymentStatus.calculate(_grandTotal, _advancePayment);
  }

  void _openCustomerPicker() async {
    final customers = await ref.read(customerRepositoryProvider).getCustomers();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = customers.where((c) {
              final term = query.toLowerCase();
              return c.shopName.toLowerCase().contains(term) ||
                  c.ownerName.toLowerCase().contains(term) ||
                  c.marketArea.toLowerCase().contains(term);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Shop / Customer',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepNavy,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          Navigator.of(sheetCtx).pop();
                          final newCustomer = await Navigator.of(context).push<Customer>(
                            MaterialPageRoute(builder: (_) => const CustomerFormScreen()),
                          );
                          if (newCustomer != null && mounted) {
                            setState(() {
                              _selectedCustomer = newCustomer;
                            });
                          }
                        },
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Add New'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search shop or owner...',
                      prefixIcon: Icon(Icons.search_rounded, size: 20),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onChanged: (val) {
                      setModalState(() {
                        query = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('No shops found.'))
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final c = filtered[index];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primaryNavy.withAlpha(25),
                                  child: const Icon(Icons.storefront_rounded, color: AppColors.primaryNavy, size: 20),
                                ),
                                title: Text(
                                  c.shopName,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text(
                                  '${c.ownerName} • ${c.marketArea}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                                ),
                                onTap: () {
                                  setState(() {
                                    _selectedCustomer = c;
                                  });
                                  Navigator.of(sheetCtx).pop();
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openProductPicker() async {
    final products = await ref.read(productRepositoryProvider).getProducts(activeOnly: true);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = products.where((p) {
              final term = query.toLowerCase();
              return p.name.toLowerCase().contains(term) || p.sku.toLowerCase().contains(term);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add Products to Order',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepNavy,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(sheetCtx).pop();
                          _showCustomProductDialog();
                        },
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Custom Item'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search product or SKU...',
                      prefixIcon: Icon(Icons.search_rounded, size: 20),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onChanged: (val) {
                      setModalState(() {
                        query = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('Product not in catalog.'),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(sheetCtx).pop();
                                    _showCustomProductDialog(defaultName: query);
                                  },
                                  icon: const Icon(Icons.add_rounded, size: 16),
                                  label: const Text('Add As Quick Product'),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final p = filtered[index];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                title: Text(
                                  p.name,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                                subtitle: Text(
                                  'SKU: ${p.sku.isNotEmpty ? p.sku : 'N/A'} • Unit: ${p.unit}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                                ),
                                trailing: Text(
                                  CurrencyFormatter.format(p.unitPrice),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.deepNavy,
                                    fontSize: 14,
                                  ),
                                ),
                                onTap: () {
                                  Navigator.of(sheetCtx).pop();
                                  _promptItemDetails(p);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _promptItemDetails(Product product) {
    final qtyController = TextEditingController(text: '1');
    final priceController = TextEditingController(text: product.unitPrice.toStringAsFixed(0));
    final discountController = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            double currentQty = double.tryParse(qtyController.text) ?? 1.0;
            double currentPrice = double.tryParse(priceController.text) ?? product.unitPrice;
            double currentDisc = double.tryParse(discountController.text) ?? 0.0;
            double itemTotal = (currentQty * currentPrice - currentDisc).clamp(0.0, double.infinity);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                product.name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.deepNavy),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unit: ${product.unit}',
                      style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                    ),
                    const SizedBox(height: 14),
                    // Quantity Stepper
                    Row(
                      children: [
                        const Text('Quantity:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.primaryNavy),
                          onPressed: () {
                            if (currentQty > 1) {
                              qtyController.text = (currentQty - 1).toStringAsFixed(0);
                              setDialogState(() {});
                            }
                          },
                        ),
                        SizedBox(
                          width: 60,
                          child: TextField(
                            controller: qtyController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                            ),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryNavy),
                          onPressed: () {
                            qtyController.text = (currentQty + 1).toStringAsFixed(0);
                            setDialogState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: priceController,
                      label: 'Unit Price (${product.unit})',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: discountController,
                      label: 'Item Discount (optional)',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.inputBackground,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Line Total:', style: TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                            CurrencyFormatter.format(itemTotal),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.deepNavy,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final qty = double.tryParse(qtyController.text) ?? 1.0;
                    final price = double.tryParse(priceController.text) ?? product.unitPrice;
                    final disc = double.tryParse(discountController.text) ?? 0.0;

                    if (qty <= 0 || price < 0) return;

                    setState(() {
                      _items.add(LineItemDraft(
                        id: const Uuid().v4(),
                        productId: product.id,
                        productName: product.name,
                        unit: product.unit,
                        unitPrice: price,
                        quantity: qty,
                        discount: disc,
                      ));
                    });
                    Navigator.of(dialogCtx).pop();
                  },
                  child: const Text('Add to Order'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCustomProductDialog({String? defaultName}) {
    final nameController = TextEditingController(text: defaultName ?? '');
    final unitController = TextEditingController(text: 'pcs');
    final priceController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Quick Product', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: nameController,
                  label: 'Product Name',
                  isRequired: true,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: unitController,
                        label: 'Unit',
                        isRequired: true,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomTextField(
                        controller: priceController,
                        label: 'Unit Price',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        isRequired: true,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        validator: (v) {
                          if (v == null || double.tryParse(v) == null) return 'Valid price';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  controller: qtyController,
                  label: 'Quantity',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final price = double.parse(priceController.text.trim());
              final qty = double.tryParse(qtyController.text.trim()) ?? 1.0;
              final pId = const Uuid().v4();

              // Also persist product to catalog so it's reusable!
              final newProd = Product(
                id: pId,
                name: nameController.text.trim(),
                sku: 'QCK-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
                unit: unitController.text.trim(),
                unitPrice: price,
                isActive: true,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              final nav = Navigator.of(dialogCtx);
              await ref.read(productRepositoryProvider).createProduct(newProd);
              ref.invalidate(productListProvider);

              setState(() {
                _items.add(LineItemDraft(
                  id: const Uuid().v4(),
                  productId: pId,
                  productName: newProd.name,
                  unit: newProd.unit,
                  unitPrice: price,
                  quantity: qty,
                  discount: 0.0,
                ));
              });

              nav.pop();
            },
            child: const Text('Add to Order'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveOrder({required bool asDraft}) async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a customer or shop for this order.'),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one product item to the order.'),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final orderRepo = ref.read(orderRepositoryProvider);
      final isEditing = widget.orderToEdit != null;
      final now = DateTime.now();

      final orderId = isEditing ? widget.orderToEdit!.id : const Uuid().v4();

      final targetStatus = asDraft ? OrderStatus.draft : _status;

      final domainItems = _items.map((i) {
        return OrderItem(
          id: i.id,
          orderId: orderId,
          productId: i.productId,
          productNameSnapshot: i.productName,
          quantity: i.quantity,
          unit: i.unit,
          unitPrice: i.unitPrice,
          discountAmount: i.discount,
          lineTotal: i.lineTotal,
        );
      }).toList();

      final orderModel = OrderModel(
        id: orderId,
        orderNumber: _orderNumber,
        customerId: _selectedCustomer!.id,
        orderDate: _orderDate,
        deliveryDate: _deliveryDate,
        status: targetStatus,
        subtotal: _subtotal,
        discountAmount: _orderDiscount,
        deliveryCharge: _deliveryCharge,
        grandTotal: _grandTotal,
        advanceAmount: _advancePayment,
        balanceAmount: _remainingBalance,
        paymentStatus: _computedPaymentStatus,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        createdAt: isEditing ? widget.orderToEdit!.createdAt : now,
        updatedAt: now,
      );

      if (isEditing) {
        await orderRepo.updateOrder(
          order: orderModel,
          items: domainItems,
        );
      } else {
        await orderRepo.createOrder(
          order: orderModel,
          items: domainItems,
          initialPaymentMethod: _paymentMethod,
          paymentRef: _paymentRefController.text.trim().isNotEmpty ? _paymentRefController.text.trim() : null,
          paymentNote: 'Advance paid on order booking',
        );
      }

      ref.invalidate(orderListProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(customerDetailProvider(_selectedCustomer!.id));
      ref.invalidate(customerOrdersProvider(_selectedCustomer!.id));
      if (isEditing) {
        ref.invalidate(orderDetailProvider(orderId));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(asDraft ? 'Order saved as draft' : 'Order booked successfully: $_orderNumber'),
            backgroundColor: AppColors.emeraldGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );

        if (isEditing) {
          Navigator.of(context).pop();
        } else {
          // Replace with order details
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => OrderDetailScreen(orderId: orderId),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save order: $e'),
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
    final isEditing = widget.orderToEdit != null;
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.value ?? const AppSettings();

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Order $_orderNumber' : 'New Wholesale Order'),
      ),
      body: _isLoadingNumber
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Order Header & Metadata Card
                  _buildHeaderCard(),
                  const SizedBox(height: 16),

                  // Customer Selection Card
                  _buildCustomerSelectorCard(),
                  const SizedBox(height: 16),

                  // Line Items Card
                  _buildItemsCard(settings),
                  const SizedBox(height: 16),

                  // Calculations & Financial Breakdown Card
                  _buildFinancialSummaryCard(settings),
                  const SizedBox(height: 16),

                  // Order Status & Notes Card
                  _buildStatusAndNotesCard(),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving ? null : () => _saveOrder(asDraft: true),
                          child: const Text('Save as Draft'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : () => _saveOrder(asDraft: false),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2),
                                )
                              : Text(isEditing ? 'Save Changes' : 'Confirm Order'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ORDER NUMBER',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.secondaryText, letterSpacing: 0.5),
              ),
              const SizedBox(height: 2),
              Text(
                _orderNumber,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryNavy,
                ),
              ),
            ],
          ),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _orderDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (picked != null) {
                setState(() {
                  _orderDate = picked;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primaryNavy),
                  const SizedBox(width: 6),
                  Text(
                    DateFormatter.formatDate(_orderDate),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSelectorCard() {
    return Container(
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
                'Customer / Retailer',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepNavy,
                ),
              ),
              TextButton.icon(
                onPressed: _openCustomerPicker,
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: Text(_selectedCustomer == null ? 'Select Shop' : 'Change'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_selectedCustomer == null)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _openCustomerPicker,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.inputBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_location_alt_outlined, color: AppColors.primaryNavy, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Tap to choose or register a shop',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryNavy.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.storefront_rounded, color: AppColors.primaryNavy, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedCustomer!.shopName,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        Text(
                          '${_selectedCustomer!.ownerName} • ${_selectedCustomer!.marketArea}',
                          style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                        ),
                        if (_selectedCustomer!.phone.isNotEmpty)
                          Text(
                            _selectedCustomer!.phone,
                            style: const TextStyle(fontSize: 11, color: AppColors.primaryNavy, fontWeight: FontWeight.w500),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemsCard(AppSettings settings) {
    return Container(
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
              Text(
                'Order Items (${_items.length})',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepNavy,
                ),
              ),
              TextButton.icon(
                onPressed: _openProductPicker,
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                label: const Text('+ Add Item'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  const Icon(Icons.shopping_basket_outlined, size: 36, color: AppColors.secondaryText),
                  const SizedBox(height: 8),
                  const Text(
                    'No products added yet',
                    style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.secondaryText),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _openProductPicker,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add Products'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(140, 38),
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              separatorBuilder: (_, _) => const Divider(height: 16),
              itemBuilder: (context, index) {
                final item = _items[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity} ${item.unit} x ${CurrencyFormatter.format(item.unitPrice, currency: settings.currency)}',
                            style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                          ),
                          if (item.discount > 0)
                            Text(
                              'Disc: -${CurrencyFormatter.format(item.discount, currency: settings.currency)}',
                              style: const TextStyle(fontSize: 11, color: AppColors.errorRed, fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(item.lineTotal, currency: settings.currency),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.deepNavy),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.errorRed),
                      onPressed: () {
                        setState(() {
                          _items.removeAt(index);
                        });
                      },
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummaryCard(AppSettings settings) {
    return Container(
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
            'Payment & Calculations',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.deepNavy,
            ),
          ),
          const SizedBox(height: 14),

          // Subtotal
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal:', style: TextStyle(color: AppColors.secondaryText, fontSize: 14)),
              Text(
                CurrencyFormatter.format(_subtotal, currency: settings.currency),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Order Discount & Delivery Charge inputs
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  controller: _orderDiscountController,
                  label: 'Discount',
                  prefixIcon: Icons.local_offer_outlined,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomTextField(
                  controller: _deliveryChargeController,
                  label: 'Delivery Charge',
                  prefixIcon: Icons.delivery_dining_outlined,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 10),

          // Grand Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Grand Total:',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.deepNavy),
              ),
              Text(
                CurrencyFormatter.format(_grandTotal, currency: settings.currency),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppColors.primaryNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Advance payment & Method
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  controller: _advancePaymentController,
                  label: 'Advance Paid',
                  prefixIcon: Icons.payments_outlined,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
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
                      initialValue: _paymentMethod,
                      isExpanded: true,
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
                      items: PaymentMethod.values.map((m) {
                        return DropdownMenuItem(value: m, child: Text(m.label, style: const TextStyle(fontSize: 13)));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _paymentMethod = val);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (_paymentMethod != PaymentMethod.cash && _advancePayment > 0) ...[
            CustomTextField(
              controller: _paymentRefController,
              label: 'Transaction Reference # (Optional)',
              hint: 'e.g. Bank slip or JazzCash TID',
              prefixIcon: Icons.receipt_outlined,
            ),
            const SizedBox(height: 12),
          ],

          // Balance & Status Display
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Remaining Balance:', style: TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.format(_remainingBalance, currency: settings.currency),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _remainingBalance > 0 ? AppColors.amberAccent : AppColors.emeraldGreen,
                      ),
                    ),
                  ],
                ),
                PaymentStatusChip(status: _computedPaymentStatus),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusAndNotesCard() {
    return Container(
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
            'Order Status & Delivery Date',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.deepNavy,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Order Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<OrderStatus>(
                      initialValue: _status,
                      isExpanded: true,
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
                      items: OrderStatus.values.map((s) {
                        return DropdownMenuItem(value: s, child: Text(s.label, style: const TextStyle(fontSize: 13)));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _status = val);
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
                    const Text('Delivery Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _deliveryDate ?? DateTime.now().add(const Duration(days: 1)),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setState(() => _deliveryDate = picked);
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
                              _deliveryDate != null ? DateFormatter.formatDate(_deliveryDate) : 'Select Date',
                              style: TextStyle(
                                fontSize: 13,
                                color: _deliveryDate != null ? AppColors.primaryText : AppColors.secondaryText,
                              ),
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
          const SizedBox(height: 14),
          CustomTextField(
            controller: _notesController,
            label: 'Order Notes & Instructions',
            hint: 'Special delivery requests, packaging notes, wholesale discounts...',
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}
