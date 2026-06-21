import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';

// ═══════════════════════════════════════════════════════════════
//  AdminNotificationsScreen — Enhanced v2.0
//  Features:
//   ✅ {name} auto-inject → replaces with each user's real name
//   ✅ Segment targeting — All / New users / Inactive / City
//   ✅ Notification type selector (Promo, Order, Alert, Custom)
//   ✅ Per-type enable/disable settings (Settings tab)
//   ✅ Quick actions — Opening Soon + Live Now
//   ✅ Quick templates (horizontal scroll)
//   ✅ Notification history log (History tab)
//   ✅ All existing send logic preserved
// ═══════════════════════════════════════════════════════════════

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  // ── State ────────────────────────────────────────────────────
  bool _isSending = false;
  bool _isScheduling = false;
  String _selectedTarget = 'all'; // all | specific | segment
  String _selectedSegment =
      'all_users'; // all_users | new_users | inactive | city
  String _selectedCity = 'Haldwani';
  String _selectedNotifType = 'promo'; // promo | order | alert | custom
  List<Map<String, dynamic>> _users = [];
  String? _selectedUserId;
  String? _selectedUserName;
  bool _isLoadingUsers = false;

  // Tab controller
  late TabController _tabController;
  int _activeTab = 0; // 0=Compose, 1=Settings, 2=History

  // ── Notification Type Settings (enable/disable) ───────────────
  final Map<String, bool> _notifTypeEnabled = {
    'order_update': true,
    'promo': true,
    'opening_soon': true,
    'app_live': true,
    'new_vendor': true,
    'offer': true,
    'system': true,
  };

  // ── History ───────────────────────────────────────────────────
  List<Map<String, dynamic>> _history = [];
  bool _isLoadingHistory = false;

  // ── Cities ────────────────────────────────────────────────────
  final List<String> _cities = ['Haldwani', 'Rudrapur', 'Ramnagar', 'Nainital'];

  // ── Templates ────────────────────────────────────────────────
  final List<Map<String, String>> _templates = [
    {
      'title': '🔥 Street Eats is LIVE!',
      'body':
          'Hey {name}! We are open now! Order your favourite street food. 5 PM - 9 PM only 🛵',
      'type': 'alert',
    },
    {
      'title': '🎉 Special Offer Today!',
      'body': 'Hey {name}, aaj special offer hai! Order karo aur maze karo 😍',
      'type': 'promo',
    },
    {
      'title': '⏰ Opening in 30 minutes!',
      'body': '{name}, Street Eats 5 PM pe open hone wali hai! Ready ho jao 🔥',
      'type': 'alert',
    },
    {
      'title': '🆕 New Vendor Added!',
      'body':
          '{name}, naya vendor aa gaya! Fresh menu, great taste — check karo abhi 👀',
      'type': 'promo',
    },
    {
      'title': '💸 Free Delivery Today!',
      'body':
          '{name}, aaj sab orders pe free delivery! 5 PM se 9 PM tak order karo 🛵',
      'type': 'promo',
    },
    {
      'title': '⭐ Rate Your Last Order!',
      'body': '{name}, tumhara order kaisa laga? App mein jaake review do!',
      'type': 'custom',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() => _activeTab = _tabController.index);
      if (_tabController.index == 2) _loadHistory();
    });
    _loadUsers();
    _loadNotifSettings();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ── Snackbar ─────────────────────────────────────────────────
  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Load Users ────────────────────────────────────────────────
  Future<void> _loadUsers() async {
    setState(() => _isLoadingUsers = true);
    try {
      final data = await _supabase
          .from('users')
          .select('id, full_name, phone, city, created_at')
          .order('full_name');
      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(data);
          _isLoadingUsers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

  // ── Load Notification Settings from Supabase ──────────────────
  Future<void> _loadNotifSettings() async {
    try {
      final data = await _supabase
          .from('notification_settings')
          .select()
          .limit(1)
          .maybeSingle();
      if (data != null && mounted) {
        setState(() {
          for (final key in _notifTypeEnabled.keys) {
            if (data.containsKey('${key}_enabled')) {
              _notifTypeEnabled[key] = data['${key}_enabled'] as bool? ?? true;
            }
          }
        });
      }
    } catch (_) {
      // Table not found — defaults use karo
    }
  }

  // ── Save Notification Settings ────────────────────────────────
  Future<void> _saveNotifSettings() async {
    try {
      final payload = <String, dynamic>{'id': 1};
      for (final entry in _notifTypeEnabled.entries) {
        payload['${entry.key}_enabled'] = entry.value;
      }
      await _supabase
          .from('notification_settings')
          .upsert(payload, onConflict: 'id');
      _snack('Settings save ho gayi! ✅');
    } catch (e) {
      _snack('Save failed: $e', isError: true);
    }
  }

  // ── Load History ──────────────────────────────────────────────
  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      // notification_logs table se fetch karo
      final data = await _supabase
          .from('notification_logs')
          .select()
          .order('created_at', ascending: false)
          .limit(30);
      if (mounted) {
        setState(() {
          _history = List<Map<String, dynamic>>.from(data);
          _isLoadingHistory = false;
        });
      }
    } catch (_) {
      // Table nahi hai abhi — empty list
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  // ── Auth Headers ──────────────────────────────────────────────
  Map<String, String> _authHeaders() {
    final session = _supabase.auth.currentSession;
    return session != null
        ? {'Authorization': 'Bearer ${session.accessToken}'}
        : {};
  }

  // ── Get Filtered User IDs for Segments ───────────────────────
  Future<List<Map<String, dynamic>>> _getSegmentUsers() async {
    final now = DateTime.now();

    switch (_selectedSegment) {
      case 'new_users':
        // Last 7 days join kiye users
        final cutoff = now.subtract(const Duration(days: 7)).toIso8601String();
        final data = await _supabase
            .from('users')
            .select('id, full_name')
            .gte('created_at', cutoff);
        return List<Map<String, dynamic>>.from(data);

      case 'inactive':
        // Users jinke last 7 din mein koi order nahi
        final cutoff = now.subtract(const Duration(days: 7)).toIso8601String();
        // Get all users who ordered recently
        final recentOrders = await _supabase
            .from('orders')
            .select('user_id')
            .gte('created_at', cutoff);
        final activeIds = (recentOrders as List)
            .map((o) => o['user_id'] as String)
            .toSet();
        // All users filter karke inactive nikalo
        final allUsers = await _supabase.from('users').select('id, full_name');
        return (allUsers as List)
            .where((u) => !activeIds.contains(u['id']))
            .cast<Map<String, dynamic>>()
            .toList();

      case 'city':
        final data = await _supabase
            .from('users')
            .select('id, full_name')
            .eq('city', _selectedCity);
        return List<Map<String, dynamic>>.from(data);

      case 'all_users':
      default:
        return List<Map<String, dynamic>>.from(_users);
    }
  }

  // ── MAIN: Send Notification ───────────────────────────────────
  // {name} auto-replace logic yahan hai
  Future<void> _sendNotification() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      _snack('Title aur message dono fill karo', isError: true);
      return;
    }
    if (_selectedTarget == 'specific' && _selectedUserId == null) {
      _snack('Koi user select karo', isError: true);
      return;
    }

    setState(() => _isSending = true);

    try {
      if (_selectedTarget == 'specific') {
        // Single user — {name} replace karo with selected user name
        final personalTitle = title.replaceAll(
          '{name}',
          _selectedUserName ?? 'Dost',
        );
        final personalBody = body.replaceAll(
          '{name}',
          _selectedUserName ?? 'Dost',
        );

        await _supabase.functions.invoke(
          'send-notification',
          body: {
            'user_id': _selectedUserId,
            'title': personalTitle,
            'body': personalBody,
            'data': {'type': _selectedNotifType},
          },
          headers: _authHeaders(),
        );
        _snack('${_selectedUserName ?? 'User'} ko notification bhej di! ✅');
        await _logNotification(
          title: personalTitle,
          body: personalBody,
          target: 'specific',
          targetDetail: _selectedUserName ?? '',
          type: _selectedNotifType,
          recipientCount: 1,
        );
      } else if (_selectedTarget == 'segment') {
        // Segment — har user ke liye {name} replace karo
        final segmentUsers = await _getSegmentUsers();
        if (segmentUsers.isEmpty) {
          _snack('Is segment mein koi user nahi', isError: true);
          setState(() => _isSending = false);
          return;
        }

        final bool hasNameTag =
            title.contains('{name}') || body.contains('{name}');

        if (hasNameTag) {
          // Personal — each user ko individually bhejo
          int sent = 0;
          for (final user in segmentUsers) {
            final name = (user['full_name'] as String?) ?? 'Dost';
            final personalTitle = title.replaceAll('{name}', name);
            final personalBody = body.replaceAll('{name}', name);
            try {
              await _supabase.functions.invoke(
                'send-notification',
                body: {
                  'user_id': user['id'],
                  'title': personalTitle,
                  'body': personalBody,
                  'data': {'type': _selectedNotifType},
                },
                headers: _authHeaders(),
              );
              sent++;
            } catch (_) {}
          }
          _snack('$sent users ko personalized notification bhej di! ✅');
          await _logNotification(
            title: title,
            body: body,
            target: 'segment',
            targetDetail: _segmentLabel(_selectedSegment),
            type: _selectedNotifType,
            recipientCount: sent,
          );
        } else {
          // No {name} tag — send_to_all style (faster)
          final payload = <String, dynamic>{
            'title': title,
            'body': body,
            'data': {'type': _selectedNotifType},
          };
          if (_selectedSegment == 'all_users') {
            payload['send_to_all'] = true;
          } else {
            // Segment IDs pass karo
            payload['user_ids'] = segmentUsers.map((u) => u['id']).toList();
          }
          await _supabase.functions.invoke(
            'send-notification',
            body: payload,
            headers: _authHeaders(),
          );
          _snack('${segmentUsers.length} users ko notification bhej di! ✅');
          await _logNotification(
            title: title,
            body: body,
            target: 'segment',
            targetDetail: _segmentLabel(_selectedSegment),
            type: _selectedNotifType,
            recipientCount: segmentUsers.length,
          );
        }
      } else {
        // All users — {name} check
        final hasNameTag = title.contains('{name}') || body.contains('{name}');

        if (hasNameTag) {
          // Personalized to all
          int sent = 0;
          await _supabase.functions.invoke(
            'send-notification',
            body: {
              'send_to_all': true,
              'title': title,
              'body': body,
              'personalize': true,
              'data': {'type': _selectedNotifType},
            },
            headers: _authHeaders(),
          );
          _snack('Sab users ko notification bhej di! ✅');
          await _logNotification(
            title: title,
            body: body,
            target: 'all',
            targetDetail: 'All Users (personalized)',
            type: _selectedNotifType,
            recipientCount: sent,
          );
        } else {
          await _supabase.functions.invoke(
            'send-notification',
            body: {
              'send_to_all': true,
              'title': title,
              'body': body,
              'data': {'type': _selectedNotifType},
            },
            headers: _authHeaders(),
          );
          _snack('Sab users ko notification bhej di! ✅');
          await _logNotification(
            title: title,
            body: body,
            target: 'all',
            targetDetail: 'All Users',
            type: _selectedNotifType,
            recipientCount: _users.length,
          );
        }
      }

      _titleController.clear();
      _bodyController.clear();
    } catch (e) {
      _snack('Failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ── Log Notification to Supabase ──────────────────────────────
  Future<void> _logNotification({
    required String title,
    required String body,
    required String target,
    required String targetDetail,
    required String type,
    required int recipientCount,
  }) async {
    try {
      await _supabase.from('notification_logs').insert({
        'title': title,
        'body': body,
        'target': target,
        'target_detail': targetDetail,
        'type': type,
        'recipient_count': recipientCount,
        'sent_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Table nahi hai toh skip karo silently
    }
  }

  // ── Quick Action: Opening Soon ────────────────────────────────
  Future<void> _sendOpeningSoonNotification() async {
    setState(() => _isScheduling = true);
    try {
      await _supabase.functions.invoke(
        'send-notification',
        body: {
          'send_to_all': true,
          'title': '⏰ Street Eats opens in 30 minutes!',
          'body':
              'Get ready to order! We open at 5 PM daily. Momos, burgers, chowmein & more 🔥',
          'personalize': true,
          'data': {'type': 'opening_soon'},
        },
        headers: _authHeaders(),
      );
      _snack('Opening soon notification sab users ko bhej di! ✅');
      await _logNotification(
        title: '⏰ Street Eats opens in 30 minutes!',
        body: 'Personalized opening soon',
        target: 'all',
        targetDetail: 'All Users (personalized)',
        type: 'opening_soon',
        recipientCount: _users.length,
      );
    } catch (e) {
      _snack('Failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isScheduling = false);
    }
  }

  // ── Quick Action: Live Now ────────────────────────────────────
  Future<void> _sendLiveNowNotification() async {
    setState(() => _isScheduling = true);
    try {
      await _supabase.functions.invoke(
        'send-notification',
        body: {
          'send_to_all': true,
          'title': '🔥 Street Eats is LIVE now!',
          'body':
              'App ab open hai! Apna order karo — momos, burgers, chowmein sab available 🛵',
          'personalize': true,
          'data': {'type': 'app_live'},
        },
        headers: _authHeaders(),
      );
      _snack('Live notification sab users ko bhej di! ✅');
      await _logNotification(
        title: '🔥 Street Eats is LIVE now!',
        body: 'Personalized live now',
        target: 'all',
        targetDetail: 'All Users (personalized)',
        type: 'app_live',
        recipientCount: _users.length,
      );
    } catch (e) {
      _snack('Failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isScheduling = false);
    }
  }

  void _applyTemplate(Map<String, String> template) {
    setState(() {
      _titleController.text = template['title']!;
      _bodyController.text = template['body']!;
      _selectedNotifType = template['type'] ?? 'promo';
    });
    // {name} hai toh hint snackbar
    if (template['body']!.contains('{name}')) {
      Future.delayed(const Duration(milliseconds: 300), () {
        _snack(
          '💡 {name} automatically har user ka naam se replace ho jaayega!',
        );
      });
    }
  }

  String _segmentLabel(String segment) {
    switch (segment) {
      case 'new_users':
        return 'New Users (Last 7 days)';
      case 'inactive':
        return 'Inactive (7+ days no order)';
      case 'city':
        return 'City: $_selectedCity';
      default:
        return 'All Users';
    }
  }

  // ════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Notifications', style: AppStyles.screenTitle),
        automaticallyImplyLeading: false,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            children: [
              Container(height: 1, color: AppColors.border),
              _buildTabBar(),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildComposeTab(), _buildSettingsTab(), _buildHistoryTab()],
      ),
    );
  }

  // ── Tab Bar ───────────────────────────────────────────────────
  Widget _buildTabBar() {
    final tabs = [
      ('Compose', Icons.edit_rounded),
      ('Settings', Icons.tune_rounded),
      ('History', Icons.history_rounded),
    ];
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isActive = _activeTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => _tabController.animateTo(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(right: i < tabs.length - 1 ? 6 : 0),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primary
                      : AppColors.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tabs[i].$2,
                      size: 14,
                      color: isActive ? Colors.white : AppColors.textMuted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      tabs[i].$1,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isActive ? Colors.white : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 1 — COMPOSE
  // ════════════════════════════════════════════════════════════
  Widget _buildComposeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Quick Actions ──
          _sectionLabel('QUICK ACTIONS'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _quickActionCard(
                  icon: Icons.timer_rounded,
                  label: 'Opening Soon',
                  sublabel: '30 min pehle',
                  color: AppColors.warning,
                  isLoading: _isScheduling,
                  onTap: _sendOpeningSoonNotification,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _quickActionCard(
                  icon: Icons.campaign_rounded,
                  label: 'Live Now!',
                  sublabel: 'App open hai',
                  color: AppColors.success,
                  isLoading: false,
                  onTap: _sendLiveNowNotification,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Templates ──
          _sectionLabel('QUICK TEMPLATES'),
          const SizedBox(height: 10),
          SizedBox(
            height: 86,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _templates.length,
              itemBuilder: (_, i) {
                final t = _templates[i];
                return GestureDetector(
                  onTap: () => _applyTemplate(t),
                  child: Container(
                    width: 175,
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t['title']!,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t['body']!,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // ── {name} hint banner ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                  size: 16,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                      children: [
                        const TextSpan(text: 'Message mein '),
                        TextSpan(
                          text: '{name}',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                          ),
                        ),
                        const TextSpan(
                          text:
                              ' likho — automatically har user ka real naam replace ho jaayega!',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Custom Message ──
          _sectionLabel('CUSTOM MESSAGE'),
          const SizedBox(height: 10),

          // Target selector — 3 options now
          _buildTargetSelector(),

          // Segment selector (if segment selected)
          if (_selectedTarget == 'segment') ...[
            const SizedBox(height: 10),
            _buildSegmentSelector(),
          ],

          // User selector (if specific selected)
          if (_selectedTarget == 'specific') ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _showUserPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedUserId != null
                        ? AppColors.primary.withOpacity(0.4)
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.person_search_rounded,
                      color: _selectedUserId != null
                          ? AppColors.primary
                          : AppColors.textMuted,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _selectedUserId != null
                            ? (_selectedUserName ?? 'User selected')
                            : 'User select karo...',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: _selectedUserId != null
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Notification Type selector
          _buildNotifTypeSelector(),

          const SizedBox(height: 12),

          // Title field
          _buildTextField(
            controller: _titleController,
            hint: 'Notification title...',
            icon: Icons.title_rounded,
          ),
          const SizedBox(height: 10),

          // Body field with {name} insert button
          Stack(
            children: [
              _buildTextField(
                controller: _bodyController,
                hint:
                    'Message likhao yahan... ({name} use karo personalize ke liye)',
                icon: Icons.message_rounded,
                maxLines: 3,
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: GestureDetector(
                  onTap: () {
                    final text = _bodyController.text;
                    final sel = _bodyController.selection;
                    final newText = text.replaceRange(
                      sel.start < 0 ? text.length : sel.start,
                      sel.end < 0 ? text.length : sel.end,
                      '{name}',
                    );
                    _bodyController.text = newText;
                    _snack('💡 {name} add ho gaya!');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                      ),
                    ),
                    child: const Text(
                      '+{name}',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Send button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isSending ? null : _sendNotification,
              icon: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _isSending
                    ? 'Bhej raha hai...'
                    : _selectedTarget == 'specific'
                    ? 'Is User Ko Bhejo'
                    : _selectedTarget == 'segment'
                    ? 'Segment Ko Bhejo'
                    : 'Sab Users Ko Bhejo',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Target Selector (3 options) ───────────────────────────────
  Widget _buildTargetSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(child: _targetBtn('all', 'Sab', Icons.group_rounded)),
          Expanded(
            child: _targetBtn('segment', 'Segment', Icons.filter_alt_rounded),
          ),
          Expanded(
            child: _targetBtn('specific', 'Specific', Icons.person_rounded),
          ),
        ],
      ),
    );
  }

  // ── Segment Selector ──────────────────────────────────────────
  Widget _buildSegmentSelector() {
    final segments = [
      ('all_users', 'Sab Users', Icons.group_rounded),
      ('new_users', 'Naye (7d)', Icons.fiber_new_rounded),
      ('inactive', 'Inactive', Icons.bedtime_rounded),
      ('city', 'City', Icons.location_city_rounded),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Segment chips
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: segments.map((s) {
              final isSelected = _selectedSegment == s.$1;
              return GestureDetector(
                onTap: () => setState(() => _selectedSegment = s.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        s.$3,
                        size: 13,
                        color: isSelected ? Colors.white : AppColors.textMuted,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        s.$2,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // City dropdown (only if city segment selected)
        if (_selectedSegment == 'city') ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCity,
                isExpanded: true,
                dropdownColor: AppColors.surface,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textMuted,
                ),
                onChanged: (v) => setState(() => _selectedCity = v!),
                items: _cities
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
              ),
            ),
          ),
        ],

        // Segment info chip
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 13,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                _getSegmentDescription(),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getSegmentDescription() {
    switch (_selectedSegment) {
      case 'new_users':
        return 'Last 7 days mein join kiye users ko jaayegi';
      case 'inactive':
        return '7+ din se order nahi kiya — wapas bulao!';
      case 'city':
        return '$_selectedCity ke users ko jaayegi';
      default:
        return 'Sab registered users ko jaayegi';
    }
  }

  // ── Notification Type Selector ────────────────────────────────
  Widget _buildNotifTypeSelector() {
    final types = [
      ('promo', '🎉 Promo', AppColors.warning),
      ('alert', '🔔 Alert', AppColors.primary),
      ('order', '📦 Order', AppColors.success),
      ('custom', '✏️ Custom', AppColors.textMuted),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('NOTIFICATION TYPE'),
        const SizedBox(height: 8),
        Row(
          children: types.map((t) {
            final isSelected = _selectedNotifType == t.$1;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedNotifType = t.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: EdgeInsets.only(right: t.$1 != 'custom' ? 6 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (t.$3).withOpacity(0.12)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? (t.$3).withOpacity(0.5)
                          : AppColors.border,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        t.$2.split(' ')[0],
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t.$2.split(' ')[1],
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected ? t.$3 : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 2 — SETTINGS
  // ════════════════════════════════════════════════════════════
  Widget _buildSettingsTab() {
    final settingItems = [
      (
        'order_update',
        'Order Updates',
        'Order placed, preparing, delivered etc.',
        Icons.receipt_long_rounded,
        AppColors.success,
      ),
      (
        'promo',
        'Promotional',
        'Offers, discounts, special deals',
        Icons.local_offer_rounded,
        AppColors.warning,
      ),
      (
        'opening_soon',
        'Opening Soon',
        '30 min pehle notification',
        Icons.timer_rounded,
        AppColors.primary,
      ),
      (
        'app_live',
        'App Live Alert',
        'Jab app 5 PM pe open ho',
        Icons.campaign_rounded,
        AppColors.success,
      ),
      (
        'new_vendor',
        'New Vendor',
        'Naya vendor add hone pe',
        Icons.storefront_rounded,
        Colors.purpleAccent,
      ),
      (
        'offer',
        'Offers & Discounts',
        'Flash sales, coupon alerts',
        Icons.flash_on_rounded,
        AppColors.warning,
      ),
      (
        'system',
        'System Alerts',
        'App updates, maintenance etc.',
        Icons.settings_rounded,
        AppColors.textMuted,
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('NOTIFICATION TYPE CONTROLS'),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.primary,
                  size: 15,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ye settings disable karne se us type ki notification kisi ko nahi jaayegi — even if manually send karo.',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: AppColors.primary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: List.generate(settingItems.length, (i) {
                final item = settingItems[i];
                final isLast = i == settingItems.length - 1;
                final isEnabled = _notifTypeEnabled[item.$1] ?? true;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: item.$5.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(item.$4, color: item.$5, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.$2,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  item.$3,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: isEnabled,
                            onChanged: (v) {
                              setState(() => _notifTypeEnabled[item.$1] = v);
                            },
                            activeThumbColor: AppColors.primary,
                            activeTrackColor: AppColors.primary.withOpacity(
                              0.3,
                            ),
                            inactiveThumbColor: AppColors.textMuted,
                            inactiveTrackColor: AppColors.textMuted.withOpacity(
                              0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Divider(
                        height: 1,
                        indent: 66,
                        endIndent: 0,
                        color: AppColors.border.withOpacity(0.5),
                      ),
                  ],
                );
              }),
            ),
          ),

          const SizedBox(height: 24),

          // ── General Settings ──
          _sectionLabel('GENERAL SETTINGS'),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                // Daily Opening Soon - info only (actual scheduling via server)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.schedule_rounded,
                          color: AppColors.warning,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Auto Opening Alert',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Daily 4:30 PM pe "Opening Soon" auto-send\n(Set via Supabase Edge Function cron)',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: AppColors.textMuted,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'CRON',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Divider(
                  height: 1,
                  indent: 66,
                  color: AppColors.border.withOpacity(0.5),
                ),

                // Notification sound info
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.volume_up_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notification Sound',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'High importance channel — sound + vibration\n(street_eats_high channel)',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: AppColors.textMuted,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'ON',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Save button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _saveNotifSettings,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text(
                'Settings Save Karo',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 3 — HISTORY
  // ════════════════════════════════════════════════════════════
  Widget _buildHistoryTab() {
    if (_isLoadingHistory) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.history_rounded,
              size: 64,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            const Text(
              'Abhi koi history nahi',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Pehli notification bhejo\ntoh yahan dikhai degi!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: _loadHistory,
              icon: const Icon(
                Icons.refresh_rounded,
                color: AppColors.primary,
                size: 16,
              ),
              label: const Text(
                'Refresh karo',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _history.length,
        itemBuilder: (_, i) => _buildHistoryCard(_history[i]),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> log) {
    final sentAt = log['sent_at'] != null
        ? DateTime.tryParse(log['sent_at'] as String)
        : null;
    final type = log['type'] as String? ?? 'custom';
    final target = log['target_detail'] as String? ?? 'Unknown';
    final count = log['recipient_count'] as int? ?? 0;

    Color typeColor;
    switch (type) {
      case 'promo':
        typeColor = AppColors.warning;
        break;
      case 'opening_soon':
      case 'app_live':
      case 'alert':
        typeColor = AppColors.primary;
        break;
      case 'order_update':
        typeColor = AppColors.success;
        break;
      default:
        typeColor = AppColors.textMuted;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  type.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: typeColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              if (sentAt != null)
                Text(
                  _formatDate(sentAt),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            log['title'] as String? ?? '',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            log['body'] as String? ?? '',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.people_rounded,
                size: 13,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                target,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.send_rounded,
                size: 13,
                color: AppColors.success,
              ),
              const SizedBox(width: 4),
              Text(
                '$count bheja',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m pehle';
    if (diff.inHours < 24) return '${diff.inHours}h pehle';
    return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ════════════════════════════════════════════════════════════
  //  SHARED WIDGETS
  // ════════════════════════════════════════════════════════════

  Widget _quickActionCard({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: color,
                    ),
                  ),
                  Text(
                    sublabel,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: color.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: color,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(Icons.send_rounded, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _targetBtn(String value, String label, IconData icon) {
    final isSelected = _selectedTarget == value;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedTarget = value;
        _selectedUserId = null;
        _selectedUserName = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : AppColors.textMuted,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserPicker() {
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> filtered = List.from(_users);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          maxChildSize: 0.92,
          builder: (_, scrollController) => Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text('User Select Karo', style: AppStyles.sectionHeader),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: searchCtrl,
                  onChanged: (q) {
                    final lower = q.toLowerCase();
                    setSheet(() {
                      filtered = q.isEmpty
                          ? List.from(_users)
                          : _users
                                .where(
                                  (u) =>
                                      (u['full_name'] ?? '')
                                          .toString()
                                          .toLowerCase()
                                          .contains(lower) ||
                                      (u['phone'] ?? '').toString().contains(q),
                                )
                                .toList();
                    });
                  },
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontFamily: 'Poppins',
                  ),
                  decoration: InputDecoration(
                    hintText: 'Naam ya phone se dhundo...',
                    hintStyle: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontFamily: 'Poppins',
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textMuted,
                      size: 18,
                    ),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _isLoadingUsers
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'Koi user nahi mila',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final user = filtered[i];
                          final name = user['full_name'] as String? ?? 'User';
                          final phone = user['phone'] as String? ?? '';
                          final isSelected = _selectedUserId == user['id'];
                          return ListTile(
                            onTap: () {
                              setState(() {
                                _selectedUserId = user['id'] as String;
                                _selectedUserName = name;
                              });
                              Navigator.pop(context);
                            },
                            leading: CircleAvatar(
                              backgroundColor: isSelected
                                  ? AppColors.primary
                                  : AppColors.primary.withOpacity(0.1),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              phone,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.primary,
                                  )
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontFamily: 'Poppins',
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppColors.textMuted,
      letterSpacing: 0.8,
    ),
  );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
        fontFamily: 'Poppins',
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 13,
          fontFamily: 'Poppins',
        ),
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
        filled: true,
        fillColor: AppColors.surface,
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
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(14),
      ),
    );
  }
}
