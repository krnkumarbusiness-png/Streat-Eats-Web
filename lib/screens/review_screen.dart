import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/styles.dart';
import '../services/review_service.dart';
import '../constants/app_snackbar.dart';

/// Bottom sheet ke andar dikhta hai — Navigator se nahi khulta.
/// Call: showModalBottomSheet(context, builder: (_) => ReviewBottomSheet(...))
class ReviewBottomSheet extends StatefulWidget {
  final String orderId;
  final String vendorId;
  final String vendorName;
  final bool hasRider; // riderName null nahi hai to true

  const ReviewBottomSheet({
    super.key,
    required this.orderId,
    required this.vendorId,
    required this.vendorName,
    required this.hasRider,
  });

  @override
  State<ReviewBottomSheet> createState() => _ReviewBottomSheetState();
}

class _ReviewBottomSheetState extends State<ReviewBottomSheet> {
  int _foodQuality = 0;
  int _taste = 0;
  int _rider = 0;
  bool _isSubmitting = false;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _foodQuality > 0 && _taste > 0 && (!widget.hasRider || _rider > 0);

  Future<void> _submit() async {
    if (!_canSubmit) {
      AppSnackBar.showError(
        context,
        'Please rate all sections before submitting',
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await ReviewService().submitReview(
        orderId: widget.orderId,
        vendorId: widget.vendorId,
        foodQualityRating: _foodQuality,
        tasteRating: _taste,
        riderRating: widget.hasRider
            ? _rider
            : 5, // rider nahi tha to default 5
        comment: _commentController.text,
      );
      if (mounted) {
        Navigator.pop(context, true); // true = successfully submitted
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppSnackBar.showError(context, 'Failed to submit review. Try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
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
            const SizedBox(height: 20),

            // Title
            Text(
              'Rate Your Order',
              style: AppStyles.screenTitle.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              widget.vendorName,
              style: AppStyles.bodyText.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),

            // Food Quality Rating
            _buildRatingSection(
              icon: Icons.lunch_dining_rounded,
              label: 'Food Quality',
              sublabel: 'Was the food fresh and well-made?',
              value: _foodQuality,
              onChanged: (v) => setState(() => _foodQuality = v),
            ),
            const SizedBox(height: 20),

            // Taste Rating
            _buildRatingSection(
              icon: Icons.favorite_rounded,
              label: 'Taste',
              sublabel: 'How did it taste?',
              value: _taste,
              onChanged: (v) => setState(() => _taste = v),
            ),

            // Rider Rating — sirf tab dikhao jab rider tha
            if (widget.hasRider) ...[
              const SizedBox(height: 20),
              _buildRatingSection(
                icon: Icons.delivery_dining_rounded,
                label: 'Delivery Experience',
                sublabel: 'Was the rider on time and polite?',
                value: _rider,
                onChanged: (v) => setState(() => _rider = v),
              ),
            ],

            const SizedBox(height: 20),

            // Comment field
            TextField(
              controller: _commentController,
              maxLines: 2,
              maxLength: 200,
              style: AppStyles.bodyText.copyWith(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: 'Anything else you\'d like to share? (optional)',
                hintStyle: AppStyles.hintText.copyWith(fontSize: 12),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.all(12),
                counterStyle: AppStyles.bodyText.copyWith(fontSize: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_canSubmit && !_isSubmitting) ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.border,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Submit Review', style: AppStyles.buttonText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingSection({
    required IconData icon,
    required String label,
    required String sublabel,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value > 0
              ? AppColors.primary.withOpacity(0.3)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 16),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppStyles.cardTitle.copyWith(fontSize: 13),
                  ),
                  Text(
                    sublabel,
                    style: AppStyles.bodyText.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final starIndex = i + 1;
              return GestureDetector(
                onTap: () => onChanged(starIndex),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    starIndex <= value
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: starIndex <= value
                        ? const Color(0xFFFFA500)
                        : AppColors.border,
                    size: 36,
                  ),
                ),
              );
            }),
          ),
          if (value > 0) ...[
            const SizedBox(height: 6),
            Center(
              child: Text(
                _ratingLabel(value),
                style: AppStyles.labelText.copyWith(
                  color: AppColors.primary,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _ratingLabel(int v) {
    switch (v) {
      case 1:
        return 'POOR';
      case 2:
        return 'FAIR';
      case 3:
        return 'GOOD';
      case 4:
        return 'GREAT';
      case 5:
        return 'EXCELLENT';
      default:
        return '';
    }
  }
}
