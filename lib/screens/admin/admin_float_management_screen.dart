// ═══════════════════════════════════════════════════════════
// STREET EATS — Admin Float Management Screen
// v2.0 — Assign Float feature added
//
// Changes from v1:
//  • FAB button → "Assign Float" bottom sheet
//  • Admin kisi bhi approved rider ko float assign kar sakta
//  • Default Rs.500, custom amount bhi enter kar sakte
//  • Already assigned riders pe warning
//  • Assign hone ke baad list auto-refresh
// ═══════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../constants/colors.dart';
import '../../services/float_service.dart';

// ─────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────
class AdminFloatManagementScreen extends StatefulWidget {
  const AdminFloatManagementScreen({super.key});

  @override
  State<AdminFloatManagementScreen> createState() =>
      _AdminFloatManagementScreenState();
}

class _AdminFloatManagementScreenState extends State<AdminFloatManagementScreen>
    with SingleTickerProviderStateMixin {
  final FloatService _floatService = FloatService();
  late TabController _tabController;

  List<RiderFloatSummary> _floatSummaries = [];
  bool _isLoading = true;
  String? _error;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = _isToday(_selectedDate)
          ? await _floatService.getTodayFloatSummary()
          : await _floatService.getFloatSummaryByDate(_selectedDate);
      if (mounted) {
        setState(() {
          _floatSummaries = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  // ── Assign Float Bottom Sheet ─────────────────────────
  void _showAssignFloatSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AssignFloatSheet(
        floatService: _floatService,
        existingSummaries: _floatSummaries,
        onAssigned: () {
          _loadData();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Float assign ho gaya! ✅'),
              backgroundColor: AdminColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  double get _totalSettlement =>
      _floatSummaries.fold(0.0, (sum, r) => sum + r.settlementAmount);

  int get _settledCount => _floatSummaries.where((r) => r.isSettled).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSummaryBanner(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildTodayTab(), _buildHistoryTab()],
            ),
          ),
        ],
      ),
      // ── FAB — Assign Float ──────────────────────────
      floatingActionButton: _isToday(_selectedDate)
          ? FloatingActionButton.extended(
              onPressed: _showAssignFloatSheet,
              backgroundColor: AppColors.primary,
              elevation: 4,
              icon: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 20,
              ),
              label: const Text(
                'Assign Float',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            )
          : null,
    );
  }

  // ─── AppBar ──────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: AdminColors.textPrimary,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Float Management',
            style: TextStyle(
              color: AdminColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          Text(
            _isToday(_selectedDate)
                ? 'Today'
                : DateFormat('d MMM yyyy').format(_selectedDate),
            style: const TextStyle(
              color: AdminColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.calendar_today_rounded,
            color: AppColors.primary,
            size: 20,
          ),
          onPressed: _pickDate,
        ),
        IconButton(
          icon: const Icon(
            Icons.refresh_rounded,
            color: AdminColors.textSecondary,
            size: 22,
          ),
          onPressed: _loadData,
        ),
        const SizedBox(width: 4),
      ],
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    );
  }

  // ─── Summary Banner ──────────────────────────────────────
  Widget _buildSummaryBanner() {
    if (_isLoading || _floatSummaries.isEmpty) return const SizedBox.shrink();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          _summaryChip(
            label: 'Total Riders',
            value: '${_floatSummaries.length}',
            color: AdminColors.infoBlue,
          ),
          const SizedBox(width: 8),
          _summaryChip(
            label: 'Settled',
            value: '$_settledCount/${_floatSummaries.length}',
            color: AdminColors.success,
          ),
          const SizedBox(width: 8),
          _summaryChip(
            label: 'Total Settle',
            value: 'Rs.${_totalSettlement.toStringAsFixed(0)}',
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _summaryChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: AdminColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── TabBar ──────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: AdminColors.textSecondary,
        indicatorColor: AppColors.primary,
        indicatorWeight: 2.5,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(text: 'Float Status'),
          Tab(text: 'History'),
        ],
      ),
    );
  }

  // ─── Today Tab ───────────────────────────────────────────
  Widget _buildTodayTab() {
    if (_isLoading) return _buildShimmer();
    if (_error != null) return _buildError();
    if (_floatSummaries.isEmpty) return _buildEmpty();

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: _floatSummaries.length,
        itemBuilder: (ctx, i) => _RiderFloatCard(
          summary: _floatSummaries[i],
          onSettled: _loadData,
          floatService: _floatService,
        ),
      ),
    );
  }

  // ─── History Tab ─────────────────────────────────────────
  Widget _buildHistoryTab() {
    if (_isLoading) return _buildShimmer();
    if (_floatSummaries.isEmpty) return _buildEmpty();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: _floatSummaries.length,
      itemBuilder: (ctx, i) => _RiderHistoryCard(
        summary: _floatSummaries[i],
        floatService: _floatService,
      ),
    );
  }

  // ─── States ──────────────────────────────────────────────
  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (_, __) => const _ShimmerCard(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AdminColors.error.withOpacity(0.6),
            ),
            const SizedBox(height: 12),
            const Text(
              'Data load nahi hua',
              style: TextStyle(
                color: AdminColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _error ?? 'Unknown error',
              style: const TextStyle(
                color: AdminColors.textSecondary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 56,
            color: AdminColors.textSecondary.withOpacity(0.4),
          ),
          const SizedBox(height: 12),
          const Text(
            'Koi rider active nahi hai',
            style: TextStyle(
              color: AdminColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Aaj ke liye koi float assign nahi hua',
            style: TextStyle(color: AdminColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _showAssignFloatSheet,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Assign Float Karo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ASSIGN FLOAT BOTTOM SHEET — NEW WIDGET
// Admin rider select karo → amount set karo → assign karo
// ═══════════════════════════════════════════════════════════
class _AssignFloatSheet extends StatefulWidget {
  final FloatService floatService;
  final List<RiderFloatSummary> existingSummaries;
  final VoidCallback onAssigned;

  const _AssignFloatSheet({
    required this.floatService,
    required this.existingSummaries,
    required this.onAssigned,
  });

  @override
  State<_AssignFloatSheet> createState() => _AssignFloatSheetState();
}

class _AssignFloatSheetState extends State<_AssignFloatSheet> {
  // Riders list from Supabase
  List<Map<String, dynamic>> _riders = [];
  bool _ridersLoading = true;

  // Selected rider
  Map<String, dynamic>? _selectedRider;

  // Amount controller — default 500
  final TextEditingController _amountCtrl = TextEditingController(text: '500');
  final _formKey = GlobalKey<FormState>();

  bool _isAssigning = false;

  // Quick amount presets
  final List<int> _presets = [300, 500, 750, 1000];

  @override
  void initState() {
    super.initState();
    _loadRiders();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRiders() async {
    try {
      // Directly fetch approved riders from Supabase
      final response = await widget.floatService.getApprovedRiders();

      if (mounted) {
        setState(() {
          _riders = List<Map<String, dynamic>>.from(response);
          _ridersLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _ridersLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Riders load nahi hue: $e'),
            backgroundColor: AdminColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Check if rider already has float today
  bool _hasFloat(String riderId) {
    return widget.existingSummaries.any(
      (s) => s.riderId == riderId && s.floatAmount > 0,
    );
  }

  Future<void> _assign() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRider == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pehle rider select karo'),
          backgroundColor: AdminColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final riderId = _selectedRider!['id'].toString();
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 500;

    // Confirm if already assigned
    if (_hasFloat(riderId)) {
      final ok = await _showOverrideDialog();
      if (!ok) return;
    }

    setState(() => _isAssigning = true);

    try {
      await widget.floatService.assignFloat(
        riderId: riderId,
        floatAmount: amount,
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onAssigned();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAssigning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Float assign nahi hua: $e'),
            backgroundColor: AdminColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<bool> _showOverrideDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Float Already Assigned',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AdminColors.textPrimary,
              ),
            ),
            content: Text(
              '${_selectedRider!['full_name']} ko aaj pehle se float mila hua hai. Override karna chahte ho?',
              style: const TextStyle(color: AdminColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AdminColors.textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.warning,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Override Karo'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomPad),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Handle ──────────────────────────────────
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Title ────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assign Float',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AdminColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Rider ko aaj ka float do',
                      style: TextStyle(
                        fontSize: 12,
                        color: AdminColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Rider Select ─────────────────────────────
            const Text(
              'Rider Select Karo',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AdminColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            if (_ridersLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2,
                  ),
                ),
              )
            else if (_riders.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AdminColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'Koi approved rider nahi hai',
                    style: TextStyle(color: AdminColors.textSecondary),
                  ),
                ),
              )
            else
              // Rider chips list
              SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _riders.length,
                  itemBuilder: (_, i) {
                    final rider = _riders[i];
                    final riderId = rider['id'].toString();
                    final name = rider['full_name']?.toString() ?? 'Rider';
                    final isSelected =
                        _selectedRider?['id'].toString() == riderId;
                    final hasFloat = _hasFloat(riderId);

                    return GestureDetector(
                      onTap: () => setState(() => _selectedRider = rider),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AdminColors.background,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : hasFloat
                                ? AdminColors.success.withOpacity(0.5)
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AdminColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            if (hasFloat) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: isSelected
                                    ? Colors.white70
                                    : AdminColors.success,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            if (_selectedRider != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 13,
                    color: AdminColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _hasFloat(_selectedRider!['id'].toString())
                        ? '⚠️ Is rider ko aaj float mil chuka hai'
                        : '✅ Is rider ko aaj float nahi mila',
                    style: TextStyle(
                      fontSize: 11,
                      color: _hasFloat(_selectedRider!['id'].toString())
                          ? AdminColors.warning
                          : AdminColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),

            // ── Amount ───────────────────────────────────
            const Text(
              'Float Amount (Rs.)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AdminColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            // Quick presets
            Row(
              children: _presets.map((amt) {
                final isSelected = _amountCtrl.text.trim() == amt.toString();
                return GestureDetector(
                  onTap: () =>
                      setState(() => _amountCtrl.text = amt.toString()),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AdminColors.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      'Rs.$amt',
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AdminColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 10),

            // Custom amount field
            TextFormField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                color: AdminColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                prefixText: 'Rs. ',
                prefixStyle: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
                hintText: '500',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true,
                fillColor: AdminColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AdminColors.error),
                ),
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Amount daalo';
                }
                final amt = double.tryParse(v.trim());
                if (amt == null || amt <= 0) {
                  return 'Valid amount daalo';
                }
                if (amt > 5000) {
                  return 'Maximum Rs.5000 assign kar sakte ho';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),

            // ── Assign Button ────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: (_isAssigning || _selectedRider == null)
                    ? null
                    : _assign,
                icon: _isAssigning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 18,
                      ),
                label: Text(
                  _isAssigning
                      ? 'Assign ho raha hai...'
                      : _selectedRider == null
                      ? 'Rider select karo pehle'
                      : 'Rs.${_amountCtrl.text.trim().isEmpty ? "500" : _amountCtrl.text.trim()} Float Assign Karo',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withOpacity(0.4),
                  disabledForegroundColor: Colors.white70,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// RIDER FLOAT CARD — same as v1, no changes
// ═══════════════════════════════════════════════════════════
class _RiderFloatCard extends StatefulWidget {
  final RiderFloatSummary summary;
  final VoidCallback onSettled;
  final FloatService floatService;

  const _RiderFloatCard({
    required this.summary,
    required this.onSettled,
    required this.floatService,
  });

  @override
  State<_RiderFloatCard> createState() => _RiderFloatCardState();
}

class _RiderFloatCardState extends State<_RiderFloatCard> {
  bool _isExpanded = false;
  bool _isSettling = false;

  Future<void> _handleSettle() async {
    final confirmed = await _showSettleDialog();
    if (!confirmed) return;

    setState(() => _isSettling = true);
    try {
      await widget.floatService.markAsSettled(
        riderId: widget.summary.riderId,
        settlementAmount: widget.summary.settlementAmount,
        floatGiven: widget.summary.floatAmount,
        ordersCount: widget.summary.ordersCount,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.summary.riderName} ka settlement done ✅'),
            backgroundColor: AdminColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onSettled();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSettling = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Settlement failed: $e'),
            backgroundColor: AdminColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<bool> _showSettleDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Settlement Confirm?',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AdminColors.textPrimary,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rider: ${widget.summary.riderName}',
                  style: const TextStyle(color: AdminColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Amount: Rs.${widget.summary.settlementAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AdminColors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      _dialogRow(
                        'Float Given',
                        'Rs.${widget.summary.floatAmount.toStringAsFixed(0)}',
                      ),
                      _dialogRow(
                        'Vendor Paid',
                        '- Rs.${widget.summary.totalVendorPaid.toStringAsFixed(0)}',
                      ),
                      _dialogRow(
                        'Cash Collected',
                        '+ Rs.${widget.summary.totalCollected.toStringAsFixed(0)}',
                      ),
                      const Divider(height: 12),
                      _dialogRow(
                        'Rider Dega',
                        'Rs.${widget.summary.settlementAmount.toStringAsFixed(0)}',
                        bold: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AdminColors.textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _dialogRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AdminColors.textSecondary,
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: bold ? AppColors.primary : AdminColors.textPrimary,
              fontSize: 12,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    final isSettled = s.isSettled;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSettled
              ? AdminColors.success.withOpacity(0.3)
              : AppColors.primary.withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSettled
                              ? AdminColors.success.withOpacity(0.12)
                              : AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            s.riderName.isNotEmpty
                                ? s.riderName[0].toUpperCase()
                                : 'R',
                            style: TextStyle(
                              color: isSettled
                                  ? AdminColors.success
                                  : AppColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.riderName,
                              style: const TextStyle(
                                color: AdminColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              s.riderPhone,
                              style: const TextStyle(
                                color: AdminColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isSettled
                              ? AdminColors.success.withOpacity(0.1)
                              : AdminColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isSettled ? '✅ Settled' : '⏳ Pending',
                          style: TextStyle(
                            color: isSettled
                                ? AdminColors.success
                                : AdminColors.warning,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _isExpanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: AdminColors.textSecondary,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _statBox(
                        label: 'Float',
                        value: 'Rs.${s.floatAmount.toStringAsFixed(0)}',
                        color: AdminColors.infoBlue,
                      ),
                      _statBox(
                        label: 'Paid Vendor',
                        value: 'Rs.${s.totalVendorPaid.toStringAsFixed(0)}',
                        color: AdminColors.error,
                      ),
                      _statBox(
                        label: 'Collected',
                        value: 'Rs.${s.totalCollected.toStringAsFixed(0)}',
                        color: AdminColors.success,
                      ),
                      _statBox(
                        label: 'Dega Admin',
                        value: 'Rs.${s.settlementAmount.toStringAsFixed(0)}',
                        color: AppColors.primary,
                        highlight: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _detailRow(
                    icon: Icons.local_shipping_outlined,
                    label: 'Orders delivered',
                    value: '${s.ordersCount} orders',
                  ),
                  _detailRow(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Current balance (pocket mein)',
                    value: 'Rs.${s.currentBalance.toStringAsFixed(0)}',
                  ),
                  _detailRow(
                    icon: Icons.payments_outlined,
                    label: 'Settlement amount',
                    value: 'Rs.${s.settlementAmount.toStringAsFixed(0)}',
                    valueColor: AppColors.primary,
                  ),
                  const SizedBox(height: 14),
                  if (!isSettled)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isSettling ? null : _handleSettle,
                        icon: _isSettling
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.check_circle_outline_rounded,
                                size: 18,
                              ),
                        label: Text(
                          _isSettling ? 'Processing...' : 'Mark as Settled',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  if (isSettled)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AdminColors.success.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          '✅ Settlement ho gaya hai aaj',
                          style: TextStyle(
                            color: AdminColors.success,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statBox({
    required String label,
    required String value,
    required Color color,
    bool highlight = false,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: highlight
              ? AppColors.primary.withOpacity(0.06)
              : AdminColors.background,
          borderRadius: BorderRadius.circular(10),
          border: highlight
              ? Border.all(color: AppColors.primary.withOpacity(0.2))
              : null,
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: AdminColors.textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AdminColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AdminColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AdminColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// RIDER HISTORY CARD
// ═══════════════════════════════════════════════════════════
class _RiderHistoryCard extends StatefulWidget {
  final RiderFloatSummary summary;
  final FloatService floatService;
  const _RiderHistoryCard({required this.summary, required this.floatService});

  @override
  State<_RiderHistoryCard> createState() => _RiderHistoryCardState();
}

class _RiderHistoryCardState extends State<_RiderHistoryCard> {
  bool _isExpanded = false;
  List<SettlementHistory> _history = [];
  bool _historyLoaded = false;
  bool _historyLoading = false;

  Future<void> _loadHistory() async {
    if (_historyLoaded) return;
    setState(() => _historyLoading = true);
    try {
      final data = await widget.floatService.getSettlementHistory(
        widget.summary.riderId,
      );
      if (mounted) {
        setState(() {
          _history = data;
          _historyLoaded = true;
          _historyLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _historyLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('History load failed: $e'),
            backgroundColor: AdminColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() => _isExpanded = !_isExpanded);
              if (!_historyLoaded) _loadHistory();
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        widget.summary.riderName.isNotEmpty
                            ? widget.summary.riderName[0].toUpperCase()
                            : 'R',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.summary.riderName,
                          style: const TextStyle(
                            color: AdminColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          widget.summary.riderPhone,
                          style: const TextStyle(
                            color: AdminColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AdminColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            if (_historyLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2,
                ),
              )
            else if (_history.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 36,
                      color: AdminColors.textSecondary.withOpacity(0.4),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Koi settlement history nahi hai',
                      style: TextStyle(
                        color: AdminColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  children: _history
                      .map((h) => _HistoryRow(history: h))
                      .toList(),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final SettlementHistory history;
  const _HistoryRow({required this.history});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('d MMM, hh:mm a').format(history.settledAt),
                  style: const TextStyle(
                    color: AdminColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${history.ordersCount} orders • Float: Rs.${history.floatGiven.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: AdminColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                if (history.notes != null && history.notes!.isNotEmpty)
                  Text(
                    history.notes!,
                    style: const TextStyle(
                      color: AdminColors.textSecondary,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            'Rs.${history.amount.toStringAsFixed(0)}',
            style: const TextStyle(
              color: AdminColors.success,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// SHIMMER CARD
// ═══════════════════════════════════════════════════════════
class _ShimmerCard extends StatefulWidget {
  const _ShimmerCard();

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _anim = Tween<double>(
      begin: -1.5,
      end: 1.5,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment(_anim.value - 1, 0),
            end: Alignment(_anim.value, 0),
            colors: [
              Colors.grey.shade200,
              Colors.grey.shade100,
              Colors.grey.shade200,
            ],
          ),
        ),
      ),
    );
  }
}
