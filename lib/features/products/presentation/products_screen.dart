import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/foldable_two_pane.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../settings/presentation/settings_provider.dart';
import '../domain/product_model.dart';
import 'product_providers.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedProductId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddEditProductModal([Product? product]) {
    final isEditing = product != null;
    final nameController = TextEditingController(text: product?.name ?? '');
    final skuController = TextEditingController(text: product?.sku ?? '');
    final unitController = TextEditingController(text: product?.unit ?? 'pcs');
    final priceController = TextEditingController(text: product != null ? product.unitPrice.toStringAsFixed(0) : '');
    bool isActive = product?.isActive ?? true;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DisplayFeatureSubScreen(
          anchorPoint: Offset.zero,
          child: StatefulBuilder(
          builder: (context, setModalState) {
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
                key: formKey,
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
                      Text(
                        isEditing ? 'Edit Product' : 'Add New Product',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepNavy,
                        ),
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: nameController,
                        label: 'Product Name',
                        hint: 'e.g. Super Basmati Rice 25kg',
                        prefixIcon: Icons.inventory_2_outlined,
                        isRequired: true,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Product name is required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              controller: skuController,
                              label: 'SKU / Code',
                              hint: 'e.g. RCE-025',
                              prefixIcon: Icons.qr_code_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CustomTextField(
                              controller: unitController,
                              label: 'Unit',
                              hint: 'Bag, Tin, Carton, kg',
                              prefixIcon: Icons.straighten_rounded,
                              isRequired: true,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Unit is required';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: priceController,
                        label: 'Selling Price',
                        hint: 'e.g. 7400',
                        prefixIcon: Icons.payments_outlined,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        isRequired: true,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Price is required';
                          final numVal = double.tryParse(v);
                          if (numVal == null || numVal <= 0) return 'Enter a valid price';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Active in Catalog',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryText,
                          ),
                        ),
                        subtitle: const Text(
                          'Available for salesmen to select in orders',
                          style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
                        ),
                        value: isActive,
                        activeThumbColor: AppColors.primaryNavy,
                        onChanged: (val) {
                          setModalState(() {
                            isActive = val;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          final price = double.parse(priceController.text.trim());
                          final repo = ref.read(productRepositoryProvider);

                          final p = Product(
                            id: isEditing ? product.id : const Uuid().v4(),
                            name: nameController.text.trim(),
                            sku: skuController.text.trim(),
                            unit: unitController.text.trim(),
                            unitPrice: price,
                            isActive: isActive,
                            createdAt: isEditing ? product.createdAt : DateTime.now(),
                            updatedAt: DateTime.now(),
                          );

                          final nav = Navigator.of(sheetContext);
                          final messenger = ScaffoldMessenger.of(context);

                          if (isEditing) {
                            await repo.updateProduct(p);
                          } else {
                            await repo.createProduct(p);
                          }

                          ref.invalidate(productListProvider);
                          if (mounted) {
                            nav.pop();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(isEditing ? 'Product updated' : 'Product added to catalog'),
                                backgroundColor: AppColors.emeraldGreen,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        child: Text(isEditing ? 'Update Product' : 'Add to Catalog'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productListProvider);
    final activeOnly = ref.watch(productActiveOnlyProvider);
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.value ?? const AppSettings();

    final allProducts = productsAsync.value ?? [];

    Widget buildProductListPane({required bool isTwoPaneMode}) {
      return Column(
        children: [
          // Search & Filter Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search product or SKU...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                ref.read(productSearchQueryProvider.notifier).clear();
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onChanged: (val) {
                      ref.read(productSearchQueryProvider.notifier).setQuery(val);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  selected: activeOnly,
                  label: const Text('Active Only'),
                  onSelected: (val) {
                    ref.read(productActiveOnlyProvider.notifier).set(val);
                  },
                  selectedColor: AppColors.primaryNavy.withAlpha(30),
                  checkmarkColor: AppColors.primaryNavy,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: activeOnly ? FontWeight.w700 : FontWeight.w500,
                    color: activeOnly ? AppColors.primaryNavy : AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),

          // Products List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(productListProvider);
              },
              child: productsAsync.when(
                loading: () => const SkeletonList(count: 5),
                error: (err, _) => Center(child: Text('Error loading products: $err')),
                data: (products) {
                  if (products.isEmpty) {
                    return EmptyStateWidget(
                      icon: Icons.inventory_2_outlined,
                      title: 'No Products Found',
                      message: 'Add wholesale items to your catalog to start recording customer orders.',
                      actionLabel: 'Add Product',
                      onAction: () => _showAddEditProductModal(),
                    );
                  }

                  // Auto select first product if in two-pane mode
                  if (isTwoPaneMode) {
                    if (_selectedProductId == null || !products.any((p) => p.id == _selectedProductId)) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                            _selectedProductId = products.first.id;
                          });
                        }
                      });
                    }
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80, top: 4),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return _buildProductCard(
                        context,
                        product,
                        settings,
                        isSelected: isTwoPaneMode && product.id == _selectedProductId,
                        onTapOverride: isTwoPaneMode
                            ? () {
                                setState(() {
                                  _selectedProductId = product.id;
                                });
                              }
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      );
    }

    final selectedProduct = allProducts.where((p) => p.id == _selectedProductId).firstOrNull;
    final rightPane = selectedProduct != null
        ? _buildProductDetailPane(selectedProduct, settings)
        : _buildEmptyProductSelectionPlaceholder();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Catalog'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(productListProvider),
          ),
        ],
      ),
      body: FoldableTwoPane(
        startPane: buildProductListPane(isTwoPaneMode: true),
        endPane: rightPane,
        singlePane: buildProductListPane(isTwoPaneMode: false),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditProductModal(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Product', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildEmptyProductSelectionPlaceholder() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryNavy.withAlpha(15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.inventory_2_outlined, size: 40, color: AppColors.primaryNavy),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select a Product',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.deepNavy),
              ),
              const SizedBox(height: 6),
              const Text(
                'Select any product from the catalog on the left to inspect wholesale pricing, unit details, and SKU.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductDetailPane(Product product, AppSettings settings) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Edit Product',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _showAddEditProductModal(product),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: product.isActive ? AppColors.primaryNavy.withAlpha(20) : AppColors.draftBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.inventory_2_rounded,
                    color: product.isActive ? AppColors.primaryNavy : AppColors.secondaryText,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.deepNavy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: product.isActive ? AppColors.paidBg : AppColors.draftBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              product.isActive ? 'Active in Catalog' : 'Inactive',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: product.isActive ? AppColors.paidText : AppColors.draftText,
                              ),
                            ),
                          ),
                          if (product.sku.isNotEmpty)
                            Text(
                              'SKU: ${product.sku}',
                              style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
                const Text(
                  'Wholesale Pricing & Units',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepNavy,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryNavy.withAlpha(10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Wholesale Unit Price', style: TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyFormatter.format(product.unitPrice, currency: settings.currency),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primaryNavy),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.emeraldGreen.withAlpha(10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Billing Unit', style: TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                            const SizedBox(height: 4),
                            Text(
                              product.unit,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.emeraldGreen),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => _showAddEditProductModal(product),
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text('Edit Product Details', style: TextStyle(fontWeight: FontWeight.w700)),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: AppColors.primaryNavy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    Product product,
    AppSettings settings, {
    bool isSelected = false,
    VoidCallback? onTapOverride,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primaryNavy.withAlpha(12) : AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? AppColors.primaryNavy : AppColors.border,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTapOverride ?? () => _showAddEditProductModal(product),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: product.isActive ? AppColors.primaryNavy.withAlpha(15) : AppColors.draftBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.inventory_2_rounded,
                  color: product.isActive ? AppColors.primaryNavy : AppColors.secondaryText,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: product.isActive ? AppColors.primaryText : AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (product.sku.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.inputBackground,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              product.sku,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondaryText),
                            ),
                          ),
                        Text(
                          'Unit: ${product.unit}',
                          style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    CurrencyFormatter.format(product.unitPrice, currency: settings.currency),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: product.isActive ? AppColors.deepNavy : AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: product.isActive ? AppColors.paidBg : AppColors.draftBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      product.isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: product.isActive ? AppColors.paidText : AppColors.draftText,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
