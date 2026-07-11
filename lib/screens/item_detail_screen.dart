// lib/screens/item_detail_screen.dart
// v4.0 — Upsell rework: upsell_item_ids se fetch
// ✅ _triggerUpsellIfNeeded updated — upsellItemIds se directly fetch
// ✅ Baaki sab same — hero, sticky bar, portion sheet preserved

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';
import '../models/menu_item_model.dart';
import '../models/vendor_model.dart';
import '../providers/cart_provider.dart';
import '../services/menu_service.dart';
import 'cart_screen.dart';

class ItemDetailScreen extends StatefulWidget {
  final MenuItemModel item;
  final VendorModel vendor;

  const ItemDetailScreen({super.key, required this.item, required this.vendor});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  final _supabase = Supabase.instance.client;
  final _menuService = MenuService();

  List<MenuItemModel> _otherItems = [];
  bool _isLoadingOthers = true;

  double get _heroH => MediaQuery.of(context).size.height * 0.40;

  @override
  void initState() {
    super.initState();
    _loadOtherItems();
  }

  Future<void> _loadOtherItems() async {
    try {
      final items = await _menuService.getMenuItems(widget.vendor.id);
      if (!mounted) return;
      setState(() {
        _otherItems = items
            .where((i) => i.id != widget.item.id && i.isAvailable)
            .toList();
        _isLoadingOthers = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingOthers = false);
    }
  }

  // ✅ UPDATED — upsell_item_ids se directly fetch
  Future<void> _triggerUpsellIfNeeded(BuildContext context) async {
    final ids = widget.item.upsellItemIds;
    if (ids.isEmpty) return;

    try {
      final data = await _supabase
          .from('menu_items')
          .select()
          .inFilter('id', ids)
          .limit(6);

      if (!context.mounted) return;
      final allItems = (data as List)
          .map((e) => MenuItemModel.fromMap(e as Map<String, dynamic>))
          .toList();
      final upsellItems = allItems
          .where((item) => item.stockStatus != 'sold_out' && item.isAvailable)
          .toList();
      if (upsellItems.isEmpty) return;

      showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.surface,
        isScrollControlled: true,
        isDismissible: true,
        enableDrag: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => _UpsellPopup(
          triggerItem: widget.item,
          upsellItems: upsellItems,
          vendor: widget.vendor,
        ),
      );
    } catch (_) {}
  }

  void _showPortionSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _PortionBottomSheet(
        item: widget.item,
        vendor: widget.vendor,
        onDone: () => _triggerUpsellIfNeeded(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final item = widget.item;
    final isSoldOut = item.stockStatus == 'sold_out';
    final qty = item.hasHalfFull
        ? cart.getTotalQuantity(item.id)
        : cart.getQuantity(item.id);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _HeroSection(
                  item: item,
                  vendor: widget.vendor,
                  isSoldOut: isSoldOut,
                  heroH: _heroH,
                  onBack: () => Navigator.pop(context),
                ),
              ),
              SliverToBoxAdapter(child: _buildItemInfo(item)),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              if (!_isLoadingOthers && _otherItems.isNotEmpty)
                SliverToBoxAdapter(child: _buildMoreFromVendor(widget.vendor)),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildStickyBar(cart, item, qty, isSoldOut),
          ),
        ],
      ),
    );
  }

  Widget _buildItemInfo(MenuItemModel item) {
    final hasDiscount =
        item.isDiscounted &&
        item.originalPrice != null &&
        item.discountPercent > 0;
    final hasLongDesc =
        item.longDescription != null && item.longDescription!.isNotEmpty;

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.storefront_rounded,
                    size: 12,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    widget.vendor.name,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_back_rounded,
                    size: 10,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _VegDotLarge(isVeg: item.isVeg),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Poppins',
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (item.tag != null && item.tag!.isNotEmpty) ...[
            _TagChip(tag: item.tag!),
            const SizedBox(height: 10),
          ],
          if (item.hasHalfFull &&
              item.halfPrice != null &&
              item.fullPrice != null)
            _buildHalfFullPriceBox(item)
          else
            _buildPriceBox(item, hasDiscount),
          const SizedBox(height: 16),
          if (item.description.isNotEmpty) ...[
            Text(
              item.description,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                height: 1.6,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (hasLongDesc) ...[
            Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                  childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  title: const Text(
                    'Product description',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  iconColor: AppColors.primary,
                  collapsedIconColor: AppColors.textMuted,
                  children: [
                    Text(
                      item.longDescription!,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                        height: 1.65,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _infoTag(
                label: item.isVeg ? 'Pure Veg' : 'Non-Veg',
                color: item.isVeg ? AppColors.success : AppColors.nonVegPrimary,
                emoji: item.isVeg ? '🥦' : '🍗',
              ),
              _infoTag(
                label: item.category,
                color: AppColors.primary,
                emoji: _emoji(item.category),
              ),
              _infoTag(
                label: widget.vendor.area,
                color: AppColors.textMuted,
                emoji: '📍',
              ),
              if (widget.vendor.deliveryMinutes != null)
                _infoTag(
                  label: '${widget.vendor.deliveryMinutes} min delivery',
                  color: AppColors.warning,
                  emoji: '⚡',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHalfFullPriceBox(MenuItemModel item) {
    final cart = context.watch<CartProvider>();
    final halfQty = cart.getQuantity(item.id, portionType: 'half');
    final fullQty = cart.getQuantity(item.id, portionType: 'full');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF7C3AED).withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.restaurant_rounded,
                color: Color(0xFF7C3AED),
                size: 14,
              ),
              SizedBox(width: 6),
              Text(
                'CHOOSE YOUR PORTION',
                style: TextStyle(
                  color: Color(0xFF7C3AED),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PortionRow(
            label: 'Half',
            emoji: '🥘',
            subtitle: 'Smaller portion — great for one',
            price: item.halfPrice ?? item.appPrice,
            qty: halfQty,
            onAdd: () {
              HapticFeedback.selectionClick();
              context.read<CartProvider>().addItem(
                item,
                widget.vendor,
                portionType: 'half',
                effectivePrice: item.halfPrice,
              );
            },
            onRemove: () {
              HapticFeedback.selectionClick();
              context.read<CartProvider>().removeItem(
                item.id,
                portionType: 'half',
              );
            },
          ),
          const SizedBox(height: 10),
          _PortionRow(
            label: 'Full',
            emoji: '🍲',
            subtitle: 'Larger portion — for a hearty meal',
            price: item.fullPrice ?? item.appPrice,
            qty: fullQty,
            onAdd: () {
              HapticFeedback.selectionClick();
              context.read<CartProvider>().addItem(
                item,
                widget.vendor,
                portionType: 'full',
                effectivePrice: item.fullPrice,
              );
            },
            onRemove: () {
              HapticFeedback.selectionClick();
              context.read<CartProvider>().removeItem(
                item.id,
                portionType: 'full',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPriceBox(MenuItemModel item, bool hasDiscount) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasDiscount
            ? AppColors.error.withOpacity(0.04)
            : AppColors.primary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasDiscount
              ? AppColors.error.withOpacity(0.15)
              : AppColors.primary.withOpacity(0.12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasDiscount) ...[
                  Text(
                    '₹${item.originalPrice!.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                      fontFamily: 'Poppins',
                      decoration: TextDecoration.lineThrough,
                      decorationColor: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  '₹${item.appPrice.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: hasDiscount ? AppColors.error : AppColors.primary,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Poppins',
                  ),
                ),
                if (hasDiscount) ...[
                  const SizedBox(height: 4),
                  Text(
                    'You save ₹${(item.originalPrice! - item.appPrice).toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: AppColors.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (hasDiscount)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    '${item.discountPercent}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const Text(
                    'OFF',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoTag({
    required String label,
    required Color color,
    required String emoji,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreFromVendor(VendorModel vendor) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'More from ${vendor.name} 👇',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              physics: const BouncingScrollPhysics(),
              itemCount: _otherItems.length,
              itemBuilder: (_, i) =>
                  _OtherItemCard(item: _otherItems[i], vendor: vendor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyBar(
    CartProvider cart,
    MenuItemModel item,
    int qty,
    bool isSoldOut,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: isSoldOut
            ? Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text(
                    'Sold Out — Item Unavailable',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              )
            : Row(
                children: [
                  if (!cart.isEmpty) ...[
                    Expanded(
                      flex: 4,
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CartScreen()),
                        ),
                        child: Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.25),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${cart.totalItems} item${cart.totalItems > 1 ? 's' : ''}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              Text(
                                '₹${cart.total.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  // NEW:
                  Expanded(
                    flex: cart.isEmpty ? 1 : 6,
                    child: (qty == 0 && item.hasHalfFull)
                        ? Container(
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.border.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Center(
                              child: Text(
                                'Select portion above ↑',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                          )
                        : GestureDetector(
                            onTap: () async {
                              HapticFeedback.mediumImpact();
                              if (qty == 0) {
                                context.read<CartProvider>().addItem(
                                  item,
                                  widget.vendor,
                                );
                                await Future.delayed(
                                  const Duration(milliseconds: 300),
                                );
                                if (context.mounted) {
                                  await _triggerUpsellIfNeeded(context);
                                }
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const CartScreen(),
                                  ),
                                );
                              }
                            },
                            child: Container(
                              height: 52,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.35),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  qty == 0
                                      ? 'Add to Cart — ₹${item.appPrice.toStringAsFixed(0)}'
                                      : 'Proceed to Pay →',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  String _emoji(String category) {
    const map = {
      'momos': '🥟',
      'burger': '🍔',
      'chowmein': '🍜',
      'pizza': '🍕',
      'chaat': '🍛',
      'maggi': '🍝',
      'sandwich': '🥪',
      'shake': '🥤',
      'beverage': '🥤',
      'sweet': '🍬',
    };
    return map[category.toLowerCase()] ?? '🍴';
  }
}

// ═══════════════════════════════════════════════════════════════
// HERO SECTION
// ═══════════════════════════════════════════════════════════════
class _HeroSection extends StatelessWidget {
  final MenuItemModel item;
  final VendorModel vendor;
  final bool isSoldOut;
  final double heroH;
  final VoidCallback onBack;

  const _HeroSection({
    required this.item,
    required this.vendor,
    required this.isSoldOut,
    required this.heroH,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final hasDiscount = item.isDiscounted && item.discountPercent > 0;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        SizedBox(
          width: double.infinity,
          height: heroH,
          child: item.imageUrl != null && item.imageUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: item.imageUrl!,
                  fit: BoxFit.cover,
                  color: isSoldOut ? Colors.black.withOpacity(0.45) : null,
                  colorBlendMode: isSoldOut ? BlendMode.darken : null,
                  placeholder: (_, __) => _placeholder(),
                  errorWidget: (_, __, ___) => _placeholder(),
                )
              : _placeholder(),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: heroH * 0.35,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  AppColors.surface.withOpacity(0.85),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 12,
          child: GestureDetector(
            onTap: onBack,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.textPrimary,
                size: 16,
              ),
            ),
          ),
        ),
        if (hasDiscount)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.error.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                '${item.discountPercent}% OFF',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ),
        if (isSoldOut)
          Positioned(
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Sold Out',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _placeholder() {
    const map = {
      'momos': '🥟',
      'burger': '🍔',
      'chowmein': '🍜',
      'pizza': '🍕',
      'chaat': '🍛',
      'maggi': '🍝',
      'sandwich': '🥪',
      'shake': '🥤',
    };
    return Container(
      width: double.infinity,
      height: heroH,
      color: AppColors.surfaceWarm,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            map[item.category.toLowerCase()] ?? '🍴',
            style: const TextStyle(fontSize: 72),
          ),
          const SizedBox(height: 8),
          Text(
            item.category,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// VEG DOT LARGE
// ═══════════════════════════════════════════════════════════════
class _VegDotLarge extends StatelessWidget {
  final bool isVeg;
  const _VegDotLarge({required this.isVeg});

  @override
  Widget build(BuildContext context) {
    final color = isVeg ? AppColors.success : AppColors.nonVegPrimary;
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAG CHIP
// ═══════════════════════════════════════════════════════════════
class _TagChip extends StatelessWidget {
  final String tag;
  const _TagChip({required this.tag});

  Color get _color {
    switch (tag.toLowerCase()) {
      case 'bestseller':
        return AppColors.success;
      case 'new':
        return AppColors.primary;
      case 'spicy':
        return AppColors.error;
      case 'must try':
        return const Color(0xFF7C3AED);
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Text(
        tag,
        style: TextStyle(
          color: _color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          fontFamily: 'Poppins',
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PORTION BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════
class _PortionBottomSheet extends StatelessWidget {
  final MenuItemModel item;
  final VendorModel vendor;
  final VoidCallback? onDone;

  const _PortionBottomSheet({
    required this.item,
    required this.vendor,
    this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final halfQty = cart.getQuantity(item.id, portionType: 'half');
    final fullQty = cart.getQuantity(item.id, portionType: 'full');

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (item.imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: item.imageUrl!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _placeholder(),
                  ),
                )
              else
                _placeholder(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Choose your portion size',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 20),
          _PortionRow(
            label: 'Half',
            emoji: '🥘',
            subtitle: 'Smaller portion — great for one',
            price: item.halfPrice ?? item.appPrice,
            qty: halfQty,
            onAdd: () {
              HapticFeedback.selectionClick();
              context.read<CartProvider>().addItem(
                item,
                vendor,
                portionType: 'half',
                effectivePrice: item.halfPrice,
              );
            },
            onRemove: () {
              HapticFeedback.selectionClick();
              context.read<CartProvider>().removeItem(
                item.id,
                portionType: 'half',
              );
            },
          ),
          const SizedBox(height: 12),
          _PortionRow(
            label: 'Full',
            emoji: '🍲',
            subtitle: 'Larger portion — for a hearty meal',
            price: item.fullPrice ?? item.appPrice,
            qty: fullQty,
            onAdd: () {
              HapticFeedback.selectionClick();
              context.read<CartProvider>().addItem(
                item,
                vendor,
                portionType: 'full',
                effectivePrice: item.fullPrice,
              );
            },
            onRemove: () {
              HapticFeedback.selectionClick();
              context.read<CartProvider>().removeItem(
                item.id,
                portionType: 'full',
              );
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if ((halfQty + fullQty) > 0 && onDone != null) {
                  Future.delayed(const Duration(milliseconds: 300), onDone!);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                (halfQty + fullQty) > 0
                    ? 'Done — ${halfQty + fullQty} item${(halfQty + fullQty) > 1 ? 's' : ''} added'
                    : 'Done',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.border),
    ),
    child: const Center(
      child: Icon(Icons.fastfood_rounded, color: AppColors.primary, size: 22),
    ),
  );
}

// ── Portion Row ───────────────────────────────────────────
class _PortionRow extends StatelessWidget {
  final String label, emoji, subtitle;
  final double price;
  final int qty;
  final VoidCallback onAdd, onRemove;

  const _PortionRow({
    required this.label,
    required this.emoji,
    required this.subtitle,
    required this.price,
    required this.qty,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: qty > 0
            ? AppColors.primary.withOpacity(0.06)
            : AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: qty > 0
              ? AppColors.primary.withOpacity(0.35)
              : AppColors.border,
          width: qty > 0 ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
          Text(
            '₹${price.toStringAsFixed(0)}',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(width: 12),
          qty == 0
              ? GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'ADD',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        SizedBox(width: 3),
                        Icon(
                          Icons.add_rounded,
                          color: AppColors.primary,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                )
              : Container(
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: onRemove,
                        child: const SizedBox(
                          width: 32,
                          height: 32,
                          child: Center(
                            child: Icon(
                              Icons.remove_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '$qty',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: onAdd,
                        child: const SizedBox(
                          width: 32,
                          height: 32,
                          child: Center(
                            child: Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// OTHER ITEM CARD
// ═══════════════════════════════════════════════════════════════
class _OtherItemCard extends StatelessWidget {
  final MenuItemModel item;
  final VendorModel vendor;
  const _OtherItemCard({required this.item, required this.vendor});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final qty = cart.getTotalQuantity(item.id);
    final isSoldOut = item.stockStatus == 'sold_out';

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ItemDetailScreen(item: item, vendor: vendor),
          ),
        );
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: qty > 0
                ? AppColors.primary.withOpacity(0.4)
                : AppColors.border,
            width: qty > 0 ? 1.5 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              child: item.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: item.imageUrl!,
                      height: 95,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      color: isSoldOut ? Colors.black.withOpacity(0.4) : null,
                      colorBlendMode: isSoldOut ? BlendMode.darken : null,
                      placeholder: (_, __) => _placeholder(),
                      errorWidget: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₹${item.minPrice.toStringAsFixed(0)}${item.hasHalfFull ? '+' : ''}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      if (!isSoldOut)
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            context.read<CartProvider>().addItem(item, vendor);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: qty > 0
                                  ? AppColors.primary
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.primary),
                            ),
                            child: Text(
                              qty > 0 ? '$qty' : '+',
                              style: TextStyle(
                                color: qty > 0
                                    ? Colors.white
                                    : AppColors.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ),
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

  Widget _placeholder() {
    const map = {
      'momos': '🥟',
      'burger': '🍔',
      'chowmein': '🍜',
      'pizza': '🍕',
    };
    return Container(
      height: 95,
      color: AppColors.surfaceWarm,
      child: Center(
        child: Text(
          map[item.category.toLowerCase()] ?? '🍴',
          style: const TextStyle(fontSize: 32),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// UPSELL POPUP
// ═══════════════════════════════════════════════════════════════
class _UpsellPopup extends StatelessWidget {
  final MenuItemModel triggerItem;
  final List<MenuItemModel> upsellItems;
  final VendorModel vendor;

  const _UpsellPopup({
    required this.triggerItem,
    required this.upsellItems,
    required this.vendor,
  });

  @override
  Widget build(BuildContext context) {
    final title =
        (triggerItem.upsellPopupTitle != null &&
            triggerItem.upsellPopupTitle!.isNotEmpty)
        ? triggerItem.upsellPopupTitle!
        : 'Something else? 🥤';
    final message =
        (triggerItem.upsellPopupMessage != null &&
            triggerItem.upsellPopupMessage!.isNotEmpty)
        ? triggerItem.upsellPopupMessage!
        : 'Complete your order!';

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            message,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textMuted,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(height: 1, color: AppColors.border),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.78,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: upsellItems.length,
              itemBuilder: (_, i) =>
                  _UpsellPopupCard(item: upsellItems[i], vendor: vendor),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: SafeArea(
              top: false,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Center(
                    child: Text(
                      'No thanks 🙏',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Upsell Popup Card ─────────────────────────────────────
class _UpsellPopupCard extends StatelessWidget {
  final MenuItemModel item;
  final VendorModel vendor;

  const _UpsellPopupCard({required this.item, required this.vendor});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final qty = cart.getQuantity(item.id);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: qty > 0
              ? AppColors.primary.withOpacity(0.5)
              : AppColors.border,
          width: qty > 0 ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            child: item.imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: item.imageUrl!,
                    height: 100,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _placeholder(),
                  )
                : _placeholder(),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₹${item.appPrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    qty == 0
                        ? GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              context.read<CartProvider>().addItem(
                                item,
                                vendor,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'ADD',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                          )
                        : Container(
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    context.read<CartProvider>().removeItem(
                                      item.id,
                                    );
                                  },
                                  child: const SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: Center(
                                      child: Icon(
                                        Icons.remove_rounded,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  child: Text(
                                    '$qty',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    context.read<CartProvider>().addItem(
                                      item,
                                      vendor,
                                    );
                                  },
                                  child: const SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: Center(
                                      child: Icon(
                                        Icons.add_rounded,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
    height: 100,
    color: AppColors.background,
    child: const Center(
      child: Icon(Icons.fastfood_rounded, color: AppColors.primary, size: 28),
    ),
  );
}
