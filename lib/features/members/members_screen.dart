import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/app_error.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/qr_share_sheet.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class NurseryManager {
  final int id;
  final int userId;
  final String? name;
  final String? mobile;
  final String? email;
  final String role;

  const NurseryManager({
    required this.id,
    required this.userId,
    this.name,
    this.mobile,
    this.email,
    required this.role,
  });

  factory NurseryManager.fromJson(Map<String, dynamic> json) {
    return NurseryManager(
      id:     (json['id'] as num).toInt(),
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      name:   json['name'] as String? ?? json['full_name'] as String?,
      mobile: json['mobile'] as String?,
      email:  json['email'] as String?,
      role:   json['role'] as String? ?? json['role_code'] as String? ?? 'MANAGER',
    );
  }
}

class NurseryInvite {
  final int id;
  final String uuid;
  final String inviteType;
  final String status;
  final String? targetName;
  final String? targetMobile;
  final String? targetEmail;
  final DateTime createdAt;

  const NurseryInvite({
    required this.id,
    required this.uuid,
    required this.inviteType,
    required this.status,
    this.targetName,
    this.targetMobile,
    this.targetEmail,
    required this.createdAt,
  });

  factory NurseryInvite.fromJson(Map<String, dynamic> json) {
    return NurseryInvite(
      id:           (json['id'] as num).toInt(),
      uuid:         json['invite_uuid'] as String? ?? json['uuid'] as String? ?? '',
      inviteType:   json['invite_type'] as String? ?? '',
      status:       json['status'] as String? ?? '',
      targetName:   json['target_name'] as String?,
      targetMobile: json['target_mobile'] as String?,
      targetEmail:  json['target_email'] as String?,
      createdAt:    DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  bool get isPending => status == 'PENDING';
  bool get isAccepted => status == 'ACCEPTED';
}

// ── State ─────────────────────────────────────────────────────────────────────

class MembersState {
  final bool isLoading;
  final List<NurseryManager> managers;
  final List<NurseryInvite> invites;
  final String? error;

  const MembersState({
    this.isLoading = false,
    this.managers = const [],
    this.invites = const [],
    this.error,
  });

  MembersState copyWith({
    bool? isLoading,
    List<NurseryManager>? managers,
    List<NurseryInvite>? invites,
    String? error,
  }) =>
      MembersState(
        isLoading: isLoading ?? this.isLoading,
        managers:  managers  ?? this.managers,
        invites:   invites   ?? this.invites,
        error:     error,
      );
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class MembersNotifier extends StateNotifier<MembersState> {
  final int nurseryId;
  final ApiClient _client;

  MembersNotifier(this.nurseryId, this._client) : super(const MembersState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait([
        _client.get<List<NurseryManager>>(
          ApiConstants.nurseryManagers(nurseryId),
          fromJson: (json) {
            final map  = json as Map<String, dynamic>;
            final list = map['managers'] as List<dynamic>? ??
                map['users'] as List<dynamic>? ?? [];
            return list
                .cast<Map<String, dynamic>>()
                .map(NurseryManager.fromJson)
                .toList();
          },
        ),
        _client.get<List<NurseryInvite>>(
          ApiConstants.nurseryInvites(nurseryId),
          fromJson: (json) {
            final list = (json as Map<String, dynamic>)['invites'] as List<dynamic>? ?? [];
            return list
                .cast<Map<String, dynamic>>()
                .map(NurseryInvite.fromJson)
                .toList();
          },
        ),
      ]);
      state = state.copyWith(
        isLoading: false,
        managers:  results[0] as List<NurseryManager>,
        invites:   results[1] as List<NurseryInvite>,
      );
    } on AppError catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load members');
    }
  }

  Future<NurseryInvite?> createInvite({
    required String inviteType,
    required String targetMobile,
    String? targetName,
  }) async {
    try {
      final invite = await _client.post<NurseryInvite>(
        ApiConstants.invites,
        data: {
          'invite_type':   inviteType,
          'nursery_id':    nurseryId,
          'target_mobile': targetMobile,
          if (targetName != null && targetName.isNotEmpty) 'target_name': targetName,
        },
        fromJson: (json) {
          final map = json as Map<String, dynamic>;
          final invJson = map['invite'] as Map<String, dynamic>? ?? map;
          return NurseryInvite.fromJson(invJson);
        },
      );
      await load();
      return invite;
    } on AppError catch (e) {
      state = state.copyWith(error: e.message);
      return null;
    } catch (e) {
      state = state.copyWith(error: 'Failed to create invite');
      return null;
    }
  }
}

// ── Provider factory ──────────────────────────────────────────────────────────

final membersProvider =
    StateNotifierProvider.family<MembersNotifier, MembersState, int>(
  (ref, nurseryId) => MembersNotifier(nurseryId, ApiClient.instance),
);

// ── Screen ────────────────────────────────────────────────────────────────────

class MembersScreen extends ConsumerStatefulWidget {
  final int nurseryId;
  final String nurseryName;
  final int initialTab; // 0 = Managers, 1 = Customers

  const MembersScreen({
    super.key,
    required this.nurseryId,
    required this.nurseryName,
    this.initialTab = 0,
  });

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(membersProvider(widget.nurseryId).notifier).load());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(membersProvider(widget.nurseryId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Members', style: AppTypography.h3),
            Text(
              widget.nurseryName,
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () =>
                ref.read(membersProvider(widget.nurseryId).notifier).load(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryMain,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primaryMain,
          labelStyle: AppTypography.label,
          unselectedLabelStyle: AppTypography.bodySmall,
          tabs: const [
            Tab(text: 'Managers'),
            Tab(text: 'Customers'),
          ],
        ),
      ),
      body: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryMain))
          : state.error != null && state.managers.isEmpty && state.invites.isEmpty
              ? ErrorState(
                  message: state.error!,
                  onRetry: () =>
                      ref.read(membersProvider(widget.nurseryId).notifier).load(),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _ManagersTab(
                      nurseryId:   widget.nurseryId,
                      nurseryName: widget.nurseryName,
                      managers:    state.managers,
                      invites:     state.invites
                          .where((i) => i.inviteType == 'MANAGER_INVITE')
                          .toList(),
                    ),
                    _CustomersTab(
                      nurseryId:   widget.nurseryId,
                      nurseryName: widget.nurseryName,
                      invites:     state.invites
                          .where((i) => i.inviteType == 'CUSTOMER_INVITE')
                          .toList(),
                    ),
                  ],
                ),
    );
  }
}

// ── Managers Tab ──────────────────────────────────────────────────────────────

class _ManagersTab extends ConsumerWidget {
  final int nurseryId;
  final String nurseryName;
  final List<NurseryManager> managers;
  final List<NurseryInvite> invites;

  const _ManagersTab({
    required this.nurseryId,
    required this.nurseryName,
    required this.managers,
    required this.invites,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(membersProvider(nurseryId).notifier).load(),
      color: AppColors.primaryMain,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          // Invite Manager button
          AppButton(
            label: 'Invite Manager / Gumastha',
            leadingIcon: Icons.person_add_rounded,
            onPressed: () => _showInviteSheet(context, ref, 'MANAGER_INVITE'),
          ),
          const SizedBox(height: AppSpacing.x2l),

          // Active managers
          const Text('Active Managers', style: AppTypography.h4),
          const SizedBox(height: AppSpacing.sm),
          if (managers.isEmpty)
            const EmptyState(
              icon: Icons.manage_accounts_outlined,
              title: 'No managers yet',
              subtitle: 'Invite a manager to help run your nursery operations.',
            )
          else
            _MemberList(
              items: managers
                  .map((m) => _MemberItem(
                        name:     m.name ?? 'Unknown',
                        subtitle: m.mobile ?? m.email ?? 'No contact',
                        badge:    m.role,
                        badgeColor: AppColors.primaryMain,
                        icon:     Icons.manage_accounts_rounded,
                      ))
                  .toList(),
            ),

          // Pending invites
          if (invites.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x2l),
            const Text('Pending Invites', style: AppTypography.h4),
            const SizedBox(height: AppSpacing.sm),
            ...invites.map((inv) => _InviteCard(invite: inv)),
          ],
          const SizedBox(height: AppSpacing.x3l),
        ],
      ),
    );
  }

  void _showInviteSheet(
      BuildContext context, WidgetRef ref, String inviteType) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InviteSheet(
        nurseryId:   nurseryId,
        nurseryName: nurseryName,
        inviteType:  inviteType,
        onCreated: (inv) =>
            ref.read(membersProvider(nurseryId).notifier).load(),
      ),
    );
  }
}

// ── Customers Tab ─────────────────────────────────────────────────────────────

class _CustomersTab extends ConsumerWidget {
  final int nurseryId;
  final String nurseryName;
  final List<NurseryInvite> invites;

  const _CustomersTab({
    required this.nurseryId,
    required this.nurseryName,
    required this.invites,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingInvites   = invites.where((i) => i.isPending).toList();
    final acceptedInvites  = invites.where((i) => i.isAccepted).toList();

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(membersProvider(nurseryId).notifier).load(),
      color: AppColors.primaryMain,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          // Invite Customer button
          AppButton(
            label: 'Invite Customer',
            leadingIcon: Icons.person_add_rounded,
            onPressed: () => _showInviteSheet(context, ref),
          ),
          const SizedBox(height: AppSpacing.x2l),

          // Linked customers
          const Text('Linked Customers', style: AppTypography.h4),
          const SizedBox(height: AppSpacing.sm),
          if (acceptedInvites.isEmpty)
            const EmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'No customers yet',
              subtitle: 'Invite customers to place orders through your nursery.',
            )
          else
            _MemberList(
              items: acceptedInvites
                  .map((inv) => _MemberItem(
                        name:     inv.targetName ?? 'Customer',
                        subtitle: inv.targetMobile ?? inv.targetEmail ?? '',
                        badge:    'CUSTOMER',
                        badgeColor: AppColors.forest600,
                        icon:     Icons.shopping_bag_rounded,
                      ))
                  .toList(),
            ),

          // Pending invites
          if (pendingInvites.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x2l),
            const Text('Pending Invites', style: AppTypography.h4),
            const SizedBox(height: AppSpacing.sm),
            ...pendingInvites.map((inv) => _InviteCard(invite: inv)),
          ],
          const SizedBox(height: AppSpacing.x3l),
        ],
      ),
    );
  }

  void _showInviteSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InviteSheet(
        nurseryId:   nurseryId,
        nurseryName: nurseryName,
        inviteType:  'CUSTOMER_INVITE',
        onCreated: (inv) =>
            ref.read(membersProvider(nurseryId).notifier).load(),
      ),
    );
  }
}

// ── Invite Creation Sheet ─────────────────────────────────────────────────────

class _InviteSheet extends ConsumerStatefulWidget {
  final int nurseryId;
  final String nurseryName;
  final String inviteType;
  final void Function(NurseryInvite) onCreated;

  const _InviteSheet({
    required this.nurseryId,
    required this.nurseryName,
    required this.inviteType,
    required this.onCreated,
  });

  @override
  ConsumerState<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<_InviteSheet> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _isLoading = false;
  NurseryInvite? _created;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  String get _title => widget.inviteType == 'MANAGER_INVITE'
      ? 'Invite Manager / Gumastha'
      : 'Invite Customer';

  String get _roleLabel => widget.inviteType == 'MANAGER_INVITE'
      ? 'Manager'
      : 'Customer';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error     = null;
    });
    final invite = await ref
        .read(membersProvider(widget.nurseryId).notifier)
        .createInvite(
          inviteType:   widget.inviteType,
          targetMobile: _phoneCtrl.text.trim(),
          targetName:   _nameCtrl.text.trim().isEmpty
              ? null
              : _nameCtrl.text.trim(),
        );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (invite != null) {
      setState(() => _created = invite);
      widget.onCreated(invite);
    } else {
      final state = ref.read(membersProvider(widget.nurseryId));
      setState(() => _error = state.error ?? 'Failed to create invite');
    }
  }

  void _copyUUID() {
    if (_created == null) return;
    Clipboard.setData(ClipboardData(text: _created!.uuid));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite UUID copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.x2l,
        AppSpacing.screenPadding,
        AppSpacing.x2l + bottomPadding,
      ),
      child: _created != null ? _SuccessView(invite: _created!, onCopy: _copyUUID, onDone: () => Navigator.pop(context)) : _FormView(
        formKey:     _formKey,
        nameCtrl:    _nameCtrl,
        phoneCtrl:   _phoneCtrl,
        title:       _title,
        roleLabel:   _roleLabel,
        isLoading:   _isLoading,
        error:       _error,
        onSubmit:    _submit,
        onCancel:    () => Navigator.pop(context),
      ),
    );
  }
}

// ── Sheet sub-views ───────────────────────────────────────────────────────────

class _FormView extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final String title;
  final String roleLabel;
  final bool isLoading;
  final String? error;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  const _FormView({
    required this.formKey,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.title,
    required this.roleLabel,
    required this.isLoading,
    this.error,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: AppTypography.h3),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Enter the details of the person you want to invite as $roleLabel.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.x2l),

          AppTextField(
            controller: nameCtrl,
            label: 'Full Name (optional)',
            hint: 'e.g. Ramesh Kumar',
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: phoneCtrl,
            label: 'Mobile Number',
            hint: '9876543210',
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            prefixIcon: const Text(
              '+91',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Mobile number is required';
              }
              if (val.trim().length != 10) {
                return 'Enter a valid 10-digit mobile number';
              }
              return null;
            },
            onSubmitted: (_) => onSubmit(),
          ),

          if (error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.errorBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.errorText, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(error!,
                        style: AppTypography.body
                            .copyWith(color: AppColors.errorText)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.x2l),
          AppButton(
            label: 'Send Invite',
            isLoading: isLoading,
            onPressed: onSubmit,
            trailingIcon: Icons.send_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              minimumSize:
                  const Size(double.infinity, AppSpacing.buttonHeight),
              side: const BorderSide(color: AppColors.border),
              foregroundColor: AppColors.textPrimary,
            ),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final NurseryInvite invite;
  final VoidCallback onCopy;
  final VoidCallback onDone;

  const _SuccessView({
    required this.invite,
    required this.onCopy,
    required this.onDone,
  });

  String get _inviteLabel => switch (invite.inviteType) {
        'MANAGER_INVITE' => 'Manager Invite',
        'DRIVER_INVITE' => 'Driver Invite',
        'CUSTOMER_INVITE' => 'Customer Invite',
        _ => 'Invite',
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.x2l),
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: AppColors.successBg,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded,
              color: AppColors.primaryMain, size: 36),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Text('Invite Created!', style: AppTypography.h3),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Share the invite UUID with ${invite.targetName ?? invite.targetMobile ?? 'the recipient'}.',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.x2l),

        // UUID display
        Container(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invite UUID',
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      invite.uuid,
                      style: AppTypography.body.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded,
                        color: AppColors.primaryMain, size: 20),
                    onPressed: onCopy,
                    tooltip: 'Copy UUID',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.x2l),

        AppButton(
          label: 'Show QR & Share',
          onPressed: () => QrShareSheet.show(
            context,
            code: invite.uuid,
            qrType: invite.inviteType == 'MANAGER_INVITE'
                ? QrCodeType.managerInvite
                : QrCodeType.customerInvite,
            shareMessage:
                'You\'ve been invited to join GreenRoot.\n\nInvitation code: ${invite.uuid}\n\nOpen GreenRoot app → Accept Invite → paste or scan.',
          ),
          leadingIcon: Icons.qr_code_rounded,
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: onCopy,
          style: OutlinedButton.styleFrom(
            minimumSize:
                const Size(double.infinity, AppSpacing.buttonHeight),
            side: const BorderSide(color: AppColors.border),
            foregroundColor: AppColors.textPrimary,
          ),
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy UUID'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: onDone,
          child: const Text('Done'),
        ),
      ],
    );
  }
}

// ── Shared components ─────────────────────────────────────────────────────────

class _MemberList extends StatelessWidget {
  final List<_MemberItem> items;

  const _MemberList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _buildTile(items[i]),
            if (i < items.length - 1)
              const Divider(height: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }

  Widget _buildTile(_MemberItem item) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.forest100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(item.icon, color: AppColors.primaryMain, size: 20),
      ),
      title: Text(item.name, style: AppTypography.label),
      subtitle: Text(item.subtitle,
          style: AppTypography.caption
              .copyWith(color: AppColors.textSecondary)),
      trailing: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: item.badgeColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          item.badge,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: item.badgeColor,
          ),
        ),
      ),
    );
  }
}

class _MemberItem {
  final String name;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final IconData icon;

  const _MemberItem({
    required this.name,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.icon,
  });
}

class _InviteCard extends StatelessWidget {
  final NurseryInvite invite;

  const _InviteCard({required this.invite});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.warningBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.mail_outline_rounded,
                color: AppColors.amber600, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invite.targetName ?? invite.targetMobile ?? 'Pending',
                  style: AppTypography.label,
                ),
                if (invite.targetMobile != null)
                  Text(
                    invite.targetMobile!,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  invite.status,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.amber600,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: () => QrShareSheet.show(
                  context,
                  code: invite.uuid,
                  qrType: invite.inviteType == 'MANAGER_INVITE'
                      ? QrCodeType.managerInvite
                      : QrCodeType.customerInvite,
                  shareMessage:
                      'You\'re invited to join GreenRoot.\n\nInvitation code:\n${invite.uuid}\n\nOpen GreenRoot app → Accept Invite → paste or scan.',
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_rounded,
                        size: 12, color: AppColors.primaryMain),
                    SizedBox(width: 3),
                    Text(
                      'QR / Share',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primaryMain,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
