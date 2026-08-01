import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../models/combo_model.dart';
import '../services/combo_service.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../models/menu_item_model.dart';
import '../services/vendor_service.dart';
import '../utils/cart_utils.dart';
import '../constants/app_snackbar.dart';
import 'combo_detail_screen.dart';

class CombosListScreen extends StatefulWidget {
  const CombosListScreen({super.key});

  @override
  State<CombosListScreen> createState() => _CombosListScreenState();
}

class _CombosListScreenState extends State<CombosListScreen> {
  final _comboService = ComboService();
  List<ComboModel> _combos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final combos = await _comboService.getAllCombos();
    if (mounted) {
      setState(() {
        _combos = combos;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF1A1A1A),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Text(
              'Combo Deals',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('🎁', style: const TextStyle(fontSize: 14)),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE5E7EB)),
        ),
      ),
      body: _isLoading
          ? _buildShimmer()
          : _combos.isEmpty
          ? _buildEmpty()
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.72,
                ),
                itemCount: _combos.length,
                itemBuilder: (_, i) => _ComboListCard(
                  combo: _combos[i],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ComboDetailScreen(combo: _combos[i]),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildShimmer() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.72,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
      ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🎁', style: TextStyle(fontSize: 42)),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Combos Yet',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'More combo deals coming soon!\nStay tuned 😊',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ComboListCard extends StatelessWidget {
  final ComboModel combo;
  final VoidCallback onTap;
  const _ComboListCard({required this.combo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasImage = combo.imageUrl != null && combo.imageUrl!.isNotEmpty;
    final hasDiscount =
        combo.isDiscounted &&
        combo.originalPrice != null &&
        combo.discountPercent > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEEEEEE), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Image ──────────────────────────────────────
            SizedBox(
              height: 160,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    hasImage
                        ? CachedNetworkImage(
                            imageUrl: combo.imageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 160,
                            errorWidget: (_, __, ___) => _imgPh(),
                          )
                        : _imgPh(),

                    // OFF badge — bottom left
                    if (hasDiscount)
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '₹${(combo.originalPrice! - combo.appPrice).toStringAsFixed(0)} OFF',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),

                    // Add button — bottom right
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: _ComboListAddButton(combo: combo),
                    ),
                  ],
                ),
              ),
            ),

            // ── Info ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Item name
                  Text(
                    combo.name,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A),
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 6),

                  // Price row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Price box
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          '₹${combo.appPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      // Strikethrough original price
                      if (hasDiscount) ...[
                        const SizedBox(width: 5),
                        Text(
                          '₹${combo.originalPrice!.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                            decoration: TextDecoration.lineThrough,
                            decorationColor: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imgPh() => Container(
    color: AppColors.primary.withOpacity(0.06),
    child: const Center(child: Text('🎁', style: TextStyle(fontSize: 40))),
  );
}

class _ComboListAddButton extends StatefulWidget {
  final ComboModel combo;
  const _ComboListAddButton({Key? key, required this.combo}) : super(key: key);

  @override
  State<_ComboListAddButton> createState() => _ComboListAddButtonState();
}

class _ComboListAddButtonState extends State<_ComboListAddButton> {
  bool _isAdding = false;

  void _addToCart() async {
    setState(() => _isAdding = true);
    try {
      final vendor = await VendorService().getVendorById(widget.combo.vendorId);
      if (!mounted) return;

      if (vendor == null) {
        setState(() => _isAdding = false);
        AppSnackBar.showError(context, 'Vendor not found');
        return;
      }

      final comboAsItem = MenuItemModel(
        id: widget.combo.id,
        vendorId: widget.combo.vendorId,
        vendorName: vendor.name,
        name: '🎁 ${widget.combo.name}',
        description: widget.combo.description,
        vendorPrice: widget.combo.vendorPrice,
        appPrice: widget.combo.appPrice,
        originalPrice: widget.combo.originalPrice,
        isDiscounted: widget.combo.isDiscounted,
        category: 'Combo',
        isAvailable: true,
        imageUrl: widget.combo.imageUrl,
      );

      CartUtils.handleCartAddItem(
        context,
        comboAsItem,
        vendor,
        onSuccess: () {
          if (mounted) setState(() => _isAdding = false);
        },
        onLimitReached: () {
          if (mounted) setState(() => _isAdding = false);
          AppSnackBar.showError(context, 'Cart limit reached!');
        },
      );
    } catch (e) {
      if (mounted) setState(() => _isAdding = false);
      AppSnackBar.showError(context, 'Failed to add item');
    }
  }

  @override
  Widget build(BuildContext context) {
    final qty = context.watch<CartProvider>().getQuantity(widget.combo.id);

    if (qty > 0) {
      return Container(
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF16A34A),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                context.read<CartProvider>().removeItem(widget.combo.id);
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                ),
                child: const Icon(
                  Icons.remove_rounded,
                  color: Color(0xFF16A34A),
                  size: 16,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                '$qty',
                style: const TextStyle(
                  color: Color(0xFF16A34A),
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                if (!_isAdding) _addToCart();
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: _isAdding
                    ? const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(
                          color: Color(0xFF16A34A),
                          strokeWidth: 2.0,
                        ),
                      )
                    : const Icon(
                        Icons.add_rounded,
                        color: Color(0xFF16A34A),
                        size: 16,
                      ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        if (!_isAdding) _addToCart();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF16A34A),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: _isAdding
            ? const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Text(
                'Add +',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}

