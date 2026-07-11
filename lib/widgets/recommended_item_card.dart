// lib/widgets/recommended_item_card.dart
// v1.2 — 1:1 Image Fix
// ✅ FIX: Image AspectRatio(1:1) + BoxFit.contain — puri image dikhti hai, cut nahi hoti
// ✅ FIX: White background on contain so card looks clean
// ✅ All other design preserved from v1.1

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import '../constants/colors.dart';
import '../models/menu_item_model.dart';

class RecommendedItemCard extends StatelessWidget {
  final MenuItemModel item;
  final VoidCallback? onAddTap;
  final VoidCallback? onCardTap;

  const RecommendedItemCard({
    super.key,
    required this.item,
    this.onAddTap,
    this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onCardTap?.call();
      },
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Item Image — 1:1 aspect ratio ──────────────
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                  // ✅ AspectRatio 1:1 — image cut nahi hogi
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: item.imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: item.imageUrl!,
                            width: double.infinity,
                            // ✅ BoxFit.contain — puri image dikhegi
                            fit: BoxFit.contain,
                            // ✅ White bg so contain doesn't look empty
                            color: null,
                            placeholder: (_, __) => _shimmerBox(),
                            errorWidget: (_, __, ___) => _emojiBox(),
                          )
                        : _emojiBox(),
                  ),
                ),

                // Veg / Non-veg dot
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: item.isVeg ? AppColors.success : AppColors.error,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: item.isVeg
                              ? AppColors.success
                              : AppColors.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),

                // NEW:
                // Tag badge — Bestseller, New, etc.
                if (item.tag != null && item.tag!.isNotEmpty)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        item.tag!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ),

                // ✅ Discount OFF badge — bottom-left of image
                if (item.isDiscounted &&
                    item.originalPrice != null &&
                    item.originalPrice! > item.appPrice)
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(6),
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

            // ── Item Info ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontFamily: 'Poppins',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.description,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                        fontFamily: 'Poppins',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),

                  // Price + ADD button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.isDiscounted && item.originalPrice != null)
                            Text(
                              '₹${item.originalPrice!.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.textMuted,
                                fontFamily: 'SpaceMono',
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          Text(
                            '₹${item.appPrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                              fontFamily: 'SpaceMono',
                            ),
                          ),
                        ],
                      ),

                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onAddTap?.call();
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'ADD',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Poppins',
                              letterSpacing: 0.3,
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

  // ✅ Shimmer — 1:1 aspect ratio
  Widget _shimmerBox() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: Container(width: double.infinity, color: Colors.white),
    );
  }

  // ✅ Emoji fallback — 1:1 aspect ratio (parent AspectRatio se auto)
  Widget _emojiBox() {
    return Container(
      width: double.infinity,
      color: AppColors.border.withOpacity(0.25),
      child: const Center(child: Text('🍽️', style: TextStyle(fontSize: 36))),
    );
  }
}
