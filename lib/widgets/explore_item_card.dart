import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/menu_item_model.dart';
import '../models/vendor_model.dart';
import '../providers/cart_provider.dart';
import '../utils/cart_utils.dart';
import '../constants/colors.dart';

/// Shared 2-column / horizontal scroll card used in Explore Menu,
/// Today's Deals, Trending Now, Recommended Items, and Category Items screens.
class ExploreItemCard extends StatefulWidget {
  final MenuItemModel item;
  final VoidCallback onTap;
  final int? rank;
  final String? badgeText;
  final double imageHeight;

  const ExploreItemCard({
    super.key,
    required this.item,
    required this.onTap,
    this.rank,
    this.badgeText,
    this.imageHeight = 125,
  });

  @override
  State<ExploreItemCard> createState() => _ExploreItemCardState();
}

class _ExploreItemCardState extends State<ExploreItemCard> {
  static const _surface = Color(0xFFFFFFFF);
  static const _textPrimary = Color(0xFF1A1814);
  static const _textMuted = Color(0xFF9E9893);
  static const _green = Color(0xFF16A34A);
  static const _greenLight = Color(0xFFDCFCE7);
  static const _bgPlaceholder = Color(0xFFFFF8F0);

  static final Map<String, VendorModel> _vendorCache = {};
  bool _isAdding = false;

  Future<VendorModel?> _getVendor() async {
    if (_vendorCache.containsKey(widget.item.vendorId)) {
      return _vendorCache[widget.item.vendorId];
    }
    try {
      final res = await Supabase.instance.client
          .from('vendors')
          .select()
          .eq('id', widget.item.vendorId)
          .maybeSingle();
      if (res != null) {
        final vendor = VendorModel.fromMap(res);
        _vendorCache[widget.item.vendorId] = vendor;
        return vendor;
      }
    } catch (_) {}
    return null;
  }

  void _showPortionSheet(BuildContext context, VendorModel vendor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _PortionBottomSheet(
        item: widget.item,
        vendor: vendor,
      ),
    );
  }

  Future<void> _handleAddToCart() async {
    HapticFeedback.lightImpact();
    setState(() => _isAdding = true);

    try {
      final vendor = await _getVendor();
      if (!mounted) return;

      if (vendor == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not fetch vendor details')),
        );
        return;
      }

      // If item has portions (Half/Full), open portion selector modal
      if (widget.item.hasHalfFull) {
        _showPortionSheet(context, vendor);
      } else {
        // Direct add for items without portions
        CartUtils.handleCartAddItem(context, widget.item, vendor, onSuccess: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.item.name} added to cart ✓'),
              backgroundColor: _green,
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add item to cart')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  LinearGradient _getRankGradient(int rank) {
    if (rank == 1) {
      return const LinearGradient(
        colors: [Color(0xFFFF5722), Color(0xFFFF9800)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (rank == 2) {
      return const LinearGradient(
        colors: [Color(0xFFE53935), Color(0xFFFF7043)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (rank == 3) {
      return const LinearGradient(
        colors: [Color(0xFFD97706), Color(0xFFFBBF24)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return const LinearGradient(
      colors: [Color(0xFF374151), Color(0xFF1F2937)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  Widget _buildVegDot() {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 4,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.item.isVeg
                ? const Color(0xFF16A34A)
                : const Color(0xFFDC2626),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final cart = context.watch<CartProvider>();
    final totalQty = cart.getTotalQuantity(item.id);
    final hasImage = item.imageUrl != null && item.imageUrl!.isNotEmpty;
    final hasDiscount =
        item.isDiscounted &&
        item.originalPrice != null &&
        item.discountPercent > 0;
    final rank = widget.rank;
    final badge = widget.badgeText;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEEEEEE), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Image Section ──────────────────────────────
            SizedBox(
              height: widget.imageHeight,
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
                            imageUrl: item.imageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: widget.imageHeight,
                            errorWidget: (_, __, ___) => _imgPh(),
                          )
                        : _imgPh(),

                    // ── Top Left: Rank Badge OR Veg/Non-veg Dot ──
                    Positioned(
                      top: 7,
                      left: 7,
                      child: rank != null
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                gradient: _getRankGradient(rank),
                                borderRadius: BorderRadius.circular(5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.25),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Text(
                                '#$rank',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            )
                          : _buildVegDot(),
                    ),

                    // ── Top Right: Custom Badge (Orders / Deal Tag) ──
                    if (badge != null && badge.isNotEmpty)
                      Positioned(
                        top: 7,
                        right: 7,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: badge.contains('🔥') || badge.contains('left')
                                ? Colors.black.withOpacity(0.78)
                                : _green,
                            borderRadius: BorderRadius.circular(5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.18),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),

                    // ── Bottom Left: Veg Dot (if rank on top) OR Discount OFF badge ──
                    if (rank != null)
                      Positioned(
                        bottom: 7,
                        left: 7,
                        child: _buildVegDot(),
                      )
                    else if (hasDiscount)
                      Positioned(
                        bottom: 7,
                        left: 7,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _green,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            '₹${(item.originalPrice! - item.appPrice).toStringAsFixed(0)} OFF',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),

                    // ── Bottom Right: Add+ button / Quantity Control ──
                    Positioned(
                      bottom: 7,
                      right: 7,
                      child: totalQty > 0
                          ? (item.hasHalfFull
                              ? GestureDetector(
                                  onTap: () async {
                                    final vendor = await _getVendor();
                                    if (context.mounted && vendor != null) {
                                      _showPortionSheet(context, vendor);
                                    }
                                  },
                                  child: Container(
                                    height: 28,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _green,
                                      borderRadius: BorderRadius.circular(7),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.15),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
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
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            fontFamily: 'Poppins',
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        const Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: Colors.white,
                                          size: 15,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : Container(
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(7),
                                    border: Border.all(
                                      color: _green,
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          context
                                              .read<CartProvider>()
                                              .removeItem(item.id);
                                        },
                                        child: Container(
                                          width: 26,
                                          height: 28,
                                          decoration: const BoxDecoration(
                                            borderRadius: BorderRadius.only(
                                              topLeft: Radius.circular(7),
                                              bottomLeft: Radius.circular(7),
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.remove_rounded,
                                            color: _green,
                                            size: 15,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        child: Text(
                                          '$totalQty',
                                          style: const TextStyle(
                                            color: _green,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11,
                                            fontFamily: 'Poppins',
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () async {
                                          final vendor = await _getVendor();
                                          if (context.mounted && vendor != null) {
                                            CartUtils.handleCartAddItem(
                                              context,
                                              item,
                                              vendor,
                                            );
                                          }
                                        },
                                        child: Container(
                                          width: 26,
                                          height: 28,
                                          decoration: const BoxDecoration(
                                            borderRadius: BorderRadius.only(
                                              topRight: Radius.circular(7),
                                              bottomRight: Radius.circular(7),
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.add_rounded,
                                            color: _green,
                                            size: 15,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ))
                          : GestureDetector(
                              onTap: () {
                                if (!_isAdding) _handleAddToCart();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _green,
                                  borderRadius: BorderRadius.circular(7),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: _isAdding
                                    ? const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Add',
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(width: 2),
                                          Icon(
                                            Icons.add_rounded,
                                            color: Colors.white,
                                            size: 13,
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Info Section ───────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 7, 9, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Item name
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: _textPrimary,
                      height: 1.15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 2),

                  // Sub-text: Portion indicator OR Vendor name OR Category
                  if (item.hasHalfFull)
                    const Text(
                      'Half & Full available',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFF6B2B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else if (item.vendorName.isNotEmpty)
                    Text(
                      item.vendorName,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 9.5,
                        color: _textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else if (item.category.isNotEmpty)
                    Text(
                      item.category,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 9.5,
                        color: _textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                  const SizedBox(height: 5),

                  // Price row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Discount OFF pill
                      if (hasDiscount) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: _greenLight,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: _green, width: 0.8),
                          ),
                          child: Text(
                            '₹${(item.originalPrice! - item.appPrice).toStringAsFixed(0)} OFF',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              color: _green,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],

                      // Price box
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: _green,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          '₹${(item.hasHalfFull && item.halfPrice != null ? item.halfPrice! : item.appPrice).toStringAsFixed(0)}${item.hasHalfFull ? '+' : ''}',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      // Strikethrough original price
                      if (hasDiscount) ...[
                        const SizedBox(width: 4),
                        Text(
                          '₹${item.originalPrice!.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            color: _textMuted,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: _textMuted,
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
    color: _bgPlaceholder,
    child: const Center(child: Text('🍽️', style: TextStyle(fontSize: 34))),
  );
}

// ─── Portion Bottom Sheet for Explore Cards ───────────────
class _PortionBottomSheet extends StatelessWidget {
  final MenuItemModel item;
  final VendorModel vendor;

  const _PortionBottomSheet({
    required this.item,
    required this.vendor,
  });

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final halfQty = cart.getQuantity(item.id, portionType: 'half');
    final fullQty = cart.getQuantity(item.id, portionType: 'full');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAE8E4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
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
                          color: Color(0xFF1A1814),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Choose portion size',
                        style: TextStyle(
                          color: Color(0xFF9E9893),
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
            const Divider(height: 1, color: Color(0xFFEAE8E4)),
            const SizedBox(height: 20),
            _ExplorePortionRow(
              label: 'Half',
              emoji: '🥘',
              subtitle: 'Small portion — perfect for 1',
              price: item.halfPrice ?? item.appPrice,
              qty: halfQty,
              onAdd: () {
                HapticFeedback.selectionClick();
                CartUtils.handleCartAddItem(
                  context,
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
            _ExplorePortionRow(
              label: 'Full',
              emoji: '🍲',
              subtitle: 'Large portion — full meal',
              price: item.fullPrice ?? item.appPrice,
              qty: fullQty,
              onAdd: () {
                HapticFeedback.selectionClick();
                CartUtils.handleCartAddItem(
                  context,
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
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B2B),
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
      ),
    );
  }

  Widget _placeholder() => Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      color: const Color(0xFFF7F5F2),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFEAE8E4)),
    ),
    child: const Center(
      child: Icon(Icons.fastfood_rounded, color: Color(0xFFFF6B2B), size: 22),
    ),
  );
}

// ─── Portion Row ──────────────────────────────────────────
class _ExplorePortionRow extends StatelessWidget {
  final String label, emoji, subtitle;
  final double price;
  final int qty;
  final VoidCallback onAdd, onRemove;

  const _ExplorePortionRow({
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
            ? const Color(0xFFFF6B2B).withOpacity(0.06)
            : const Color(0xFFF7F5F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: qty > 0
              ? const Color(0xFFFF6B2B).withOpacity(0.35)
              : const Color(0xFFEAE8E4),
          width: qty > 0 ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF1A1814),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF9E9893),
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
              color: Color(0xFFFF6B2B),
              fontSize: 14.5,
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
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'Add +',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ),
                )
              : Container(
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: onRemove,
                        child: Container(
                          width: 30,
                          height: 32,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.remove_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          '$qty',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: onAdd,
                        child: Container(
                          width: 30,
                          height: 32,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 16,
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
