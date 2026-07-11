// lib/widgets/menu_item_card.dart
// v4.0 — Upsell rework: upsell_item_ids se fetch
// ✅ _triggerUpsellIfNeeded updated — upsellItemIds se directly fetch
// ✅ Baaki sab same — UI, portion sheet, animations preserved

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';
import '../constants/styles.dart';
import '../models/menu_item_model.dart';
import '../models/vendor_model.dart';
import '../providers/cart_provider.dart';
import '../screens/item_detail_screen.dart';

class MenuItemCard extends StatelessWidget {
  final MenuItemModel item;
  final VendorModel vendor;

  const MenuItemCard({super.key, required this.item, required this.vendor});

  void _showPortionSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _PortionBottomSheet(
        item: item,
        vendor: vendor,
        onDone: () => _triggerUpsellIfNeeded(ctx),
      ),
    );
  }

  // ✅ UPDATED — upsell_item_ids se directly fetch
  Future<void> _triggerUpsellIfNeeded(BuildContext context) async {
    final ids = item.upsellItemIds;
    if (ids.isEmpty) return;

    try {
      final data = await Supabase.instance.client
          .from('menu_items')
          .select()
          .inFilter('id', ids)
          .eq('is_available', true)
          .limit(6);

      if (!context.mounted) return;
      final upsellItems = (data as List)
          .map((e) => MenuItemModel.fromMap(e))
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
          triggerItem: item,
          upsellItems: upsellItems,
          vendor: vendor,
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isSoldOut = item.stockStatus == 'sold_out';
    final isLowStock = item.stockStatus == 'low_stock';
    final hasDiscount =
        item.isDiscounted &&
        item.originalPrice != null &&
        item.discountPercent > 0;

    final cart = context.watch<CartProvider>();
    final totalQty = cart.getTotalQuantity(item.id);

    return GestureDetector(
      onTap: () {
        if (isSoldOut) return;
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ItemDetailScreen(item: item, vendor: vendor),
          ),
        );
      },
      child: Container(
        decoration: const BoxDecoration(color: AppColors.surface),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _VegDot(isVeg: item.isVeg),
                        const SizedBox(height: 6),
                        Text(
                          item.name,
                          style: AppStyles.cardTitle.copyWith(
                            fontSize: 15,
                            color: isSoldOut
                                ? AppColors.textMuted
                                : AppColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.tag != null && item.tag!.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          _TagChip(tag: item.tag!),
                        ],
                        const SizedBox(height: 6),
                        if (item.hasHalfFull &&
                            item.halfPrice != null &&
                            item.fullPrice != null)
                          _HalfFullPriceRow(item: item, isSoldOut: isSoldOut)
                        else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹${item.appPrice.toStringAsFixed(0)}',
                                style: AppStyles.priceText.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isSoldOut
                                      ? AppColors.textMuted
                                      : hasDiscount
                                      ? AppColors.error
                                      : AppColors.primary,
                                ),
                              ),
                              if (hasDiscount) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '₹${item.originalPrice!.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                    fontFamily: 'Poppins',
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        if (item.description.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          GestureDetector(
                            onTap: () {
                              if (isSoldOut) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ItemDetailScreen(
                                    item: item,
                                    vendor: vendor,
                                  ),
                                ),
                              );
                            },
                            child: RichText(
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                text: item.description,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                  fontFamily: 'Poppins',
                                  height: 1.4,
                                ),
                                children: const [
                                  TextSpan(
                                    text: ' ...more',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (isLowStock && !isSoldOut) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: AppColors.warning.withOpacity(0.35),
                              ),
                            ),
                            child: const Text(
                              'Low Stock',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.warning,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 104,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: ColorFiltered(
                                colorFilter: isSoldOut
                                    ? const ColorFilter.matrix([
                                        0.2126,
                                        0.7152,
                                        0.0722,
                                        0,
                                        0,
                                        0.2126,
                                        0.7152,
                                        0.0722,
                                        0,
                                        0,
                                        0.2126,
                                        0.7152,
                                        0.0722,
                                        0,
                                        0,
                                        0,
                                        0,
                                        0,
                                        1,
                                        0,
                                      ])
                                    : const ColorFilter.mode(
                                        Colors.transparent,
                                        BlendMode.multiply,
                                      ),
                                child: item.imageUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: item.imageUrl!,
                                        width: 104,
                                        height: 104,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) =>
                                            _imagePlaceholder(),
                                        errorWidget: (_, __, ___) =>
                                            _imagePlaceholder(),
                                      )
                                    : _imagePlaceholder(),
                              ),
                            ),
                            if (isSoldOut)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.38),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'Sold\nOut',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        fontFamily: 'Poppins',
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (hasDiscount)
                              Positioned(
                                top: 0,
                                left: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: AppColors.success,
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(12),
                                      bottomRight: Radius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    '₹${(item.originalPrice! - item.appPrice).toStringAsFixed(0)} OFF',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (!isSoldOut) ...[
                          const SizedBox(height: 8),
                          totalQty == 0
                              ? _AddButton(
                                  onTap: () async {
                                    if (item.hasHalfFull) {
                                      _showPortionSheet(context);
                                    } else {
                                      HapticFeedback.mediumImpact();
                                      context.read<CartProvider>().addItem(
                                        item,
                                        vendor,
                                      );
                                      await Future.delayed(
                                        const Duration(milliseconds: 300),
                                      );
                                      if (context.mounted) {
                                        await _triggerUpsellIfNeeded(context);
                                      }
                                    }
                                  },
                                )
                              : item.hasHalfFull
                              ? _HalfFullQtyBadge(
                                  totalQty: totalQty,
                                  onTap: () => _showPortionSheet(context),
                                )
                              : _QuantityControl(
                                  quantity: totalQty,
                                  onAdd: () {
                                    HapticFeedback.selectionClick();
                                    context.read<CartProvider>().addItem(
                                      item,
                                      vendor,
                                    );
                                  },
                                  onRemove: () {
                                    HapticFeedback.selectionClick();
                                    context.read<CartProvider>().removeItem(
                                      item.id,
                                    );
                                  },
                                ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Divider(
              height: 1,
              color: AppColors.border,
              indent: 16,
              endIndent: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(
        child: Icon(Icons.fastfood_rounded, color: AppColors.primary, size: 32),
      ),
    );
  }
}

// ─── Half/Full Price Row ──────────────────────────────────
class _HalfFullPriceRow extends StatelessWidget {
  final MenuItemModel item;
  final bool isSoldOut;
  const _HalfFullPriceRow({required this.item, required this.isSoldOut});

  @override
  Widget build(BuildContext context) {
    final color = isSoldOut ? AppColors.textMuted : AppColors.primary;
    final halfColor =
        (!isSoldOut && item.halfIsDiscounted && item.halfOriginalPrice != null)
        ? AppColors.error
        : color;
    final fullColor =
        (!isSoldOut && item.fullIsDiscounted && item.fullOriginalPrice != null)
        ? AppColors.error
        : color;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: halfColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: halfColor.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isSoldOut &&
                  item.halfIsDiscounted &&
                  item.halfOriginalPrice != null)
                Text(
                  '₹${item.halfOriginalPrice!.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 9,
                    fontFamily: 'Poppins',
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              Text(
                'Half ₹${item.halfPrice!.toStringAsFixed(0)}',
                style: TextStyle(
                  color: halfColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: fullColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: fullColor.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isSoldOut &&
                  item.fullIsDiscounted &&
                  item.fullOriginalPrice != null)
                Text(
                  '₹${item.fullOriginalPrice!.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 9,
                    fontFamily: 'Poppins',
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              Text(
                'Full ₹${item.fullPrice!.toStringAsFixed(0)}',
                style: TextStyle(
                  color: fullColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Half/Full Qty Badge ──────────────────────────────────
class _HalfFullQtyBadge extends StatelessWidget {
  final int totalQty;
  final VoidCallback onTap;
  const _HalfFullQtyBadge({required this.totalQty, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.35),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$totalQty',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.expand_more_rounded,
              color: Colors.white,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Portion Bottom Sheet ─────────────────────────────────
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
                      'Choose portion size',
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
            subtitle: 'Small portion — perfect for 1',
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
            subtitle: 'Large portion — a little more',
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

// ─── Portion Row ──────────────────────────────────────────
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

// ─── Veg Dot ─────────────────────────────────────────────
class _VegDot extends StatelessWidget {
  final bool isVeg;
  const _VegDot({required this.isVeg});

  @override
  Widget build(BuildContext context) {
    final color = isVeg ? AppColors.success : AppColors.nonVegPrimary;
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

// ─── Tag Chip ─────────────────────────────────────────────
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Text(
        tag,
        style: TextStyle(
          color: _color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          fontFamily: 'Poppins',
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ─── Add Button ───────────────────────────────────────────
class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 8,
              offset: const Offset(0, 3),
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
                fontSize: 13,
                fontFamily: 'Poppins',
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.add_rounded, color: AppColors.primary, size: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Quantity Control ─────────────────────────────────────
class _QuantityControl extends StatelessWidget {
  final int quantity;
  final VoidCallback onAdd, onRemove;
  const _QuantityControl({
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onRemove,
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
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '$quantity',
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
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
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

// ─── Upsell Popup Card ────────────────────────────────────
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
