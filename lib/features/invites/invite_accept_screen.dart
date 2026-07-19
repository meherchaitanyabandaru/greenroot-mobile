import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/errors/app_error.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/universal_qr_screen.dart';
import '../auth/presentation/providers/session_provider.dart';

// ── Invite model ──────────────────────────────────────────────────────────────

class InviteDetail {
  final String uuid;
  final String inviteType;
  final String? nurseryName;
  final String? inviterName;
  final String status;

  const InviteDetail({
    required this.uuid,
    required this.inviteType,
    this.nurseryName,
    this.inviterName,
    required this.status,
  });

  factory InviteDetail.fromJson(Map<String, dynamic> json) {
    final inv = json['invite'] as Map<String, dynamic>? ?? json;
    return InviteDetail(
      uuid: inv['invite_uuid'] as String? ?? '',
      inviteType: inv['invite_type'] as String? ?? '',
      nurseryName: inv['nursery_name'] as String?,
      inviterName: inv['inviter_name'] as String?,
      status: inv['status'] as String? ?? '',
    );
  }

  String get typeLabel => switch (inviteType) {
        'MANAGER_INVITE' => 'Manager Invite',
        'DRIVER_INVITE' => 'Driver Invite',
        'CUSTOMER_INVITE' => 'Customer Invite',
        _ => inviteType.replaceAll('_', ' '),
      };

  IconData get typeIcon => switch (inviteType) {
        'MANAGER_INVITE' => Icons.manage_accounts_rounded,
        'DRIVER_INVITE' => Icons.local_shipping_rounded,
        'CUSTOMER_INVITE' => Icons.shopping_bag_rounded,
        _ => Icons.mail_rounded,
      };

  bool get isPending => status == 'PENDING';
}

// ── Provider ──────────────────────────────────────────────────────────────────

class InviteState {
  final bool isLoading;
  final bool isAccepting;
  final bool accepted;
  final InviteDetail? invite;
  final String? error;

  const InviteState({
    this.isLoading = false,
    this.isAccepting = false,
    this.accepted = false,
    this.invite,
    this.error,
  });

  InviteState copyWith({
    bool? isLoading,
    bool? isAccepting,
    bool? accepted,
    InviteDetail? invite,
    String? error,
  }) =>
      InviteState(
        isLoading: isLoading ?? this.isLoading,
        isAccepting: isAccepting ?? this.isAccepting,
        accepted: accepted ?? this.accepted,
        invite: invite ?? this.invite,
        error: error,
      );
}

class InviteNotifier extends StateNotifier<InviteState> {
  final ApiClient _client;

  InviteNotifier(this._client) : super(const InviteState());

  Future<void> fetchByUUID(String uuid) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final detail = await _client.get(
        '/api/v1/invites/$uuid',
        fromJson: (json) => InviteDetail.fromJson(json as Map<String, dynamic>),
      );
      state = state.copyWith(isLoading: false, invite: detail);
    } on AppError catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (_) {
      state = state.copyWith(
          isLoading: false, error: 'Could not load invite. Check your code.');
    }
  }

  Future<void> accept(String uuid) async {
    state = state.copyWith(isAccepting: true, error: null);
    try {
      await _client.post('/api/v1/invites/$uuid/accept');
      state = state.copyWith(isAccepting: false, accepted: true);
    } on AppError catch (e) {
      state = state.copyWith(isAccepting: false, error: e.message);
    } catch (_) {
      state = state.copyWith(
          isAccepting: false, error: 'Failed to accept invite. Try again.');
    }
  }

  void reset() => state = const InviteState();
}

final inviteProvider =
    StateNotifierProvider.autoDispose<InviteNotifier, InviteState>(
  (ref) => InviteNotifier(ApiClient.instance),
);

// ── Screen ────────────────────────────────────────────────────────────────────

class InviteAcceptScreen extends ConsumerStatefulWidget {
  final String? preloadedUUID;

  const InviteAcceptScreen({super.key, this.preloadedUUID});

  @override
  ConsumerState<InviteAcceptScreen> createState() => _InviteAcceptScreenState();
}

class _InviteAcceptScreenState extends ConsumerState<InviteAcceptScreen> {
  final _uuidCtrl = TextEditingController();
  bool _looked = false;

  @override
  void initState() {
    super.initState();
    if (widget.preloadedUUID != null) {
      _uuidCtrl.text = widget.preloadedUUID!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Only auto-lookup if authenticated; unauthenticated users see a login prompt.
        final session = ref.read(sessionProvider);
        if (session.isAuthenticated) _lookup();
      });
    }
  }

  void _lookup() {
    final uuid = _uuidCtrl.text.trim();
    if (uuid.isEmpty) return;
    setState(() => _looked = true);
    ref.read(inviteProvider.notifier).fetchByUUID(uuid);
  }

  void _scanQr() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const UniversalQrScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  void _accept() {
    final uuid = _uuidCtrl.text.trim();
    if (uuid.isEmpty) return;
    ref.read(inviteProvider.notifier).accept(uuid);
  }

  @override
  void dispose() {
    _uuidCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inviteProvider);

    // After successful accept, redirect
    ref.listen(inviteProvider, (_, next) {
      if (next.accepted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invite accepted! Your access has been updated.'),
            backgroundColor: AppColors.primaryMain,
          ),
        );
        ref.read(sessionProvider.notifier).bootstrap().then((_) {
          if (context.mounted) context.go('/');
        });
      }
    });

    final isAuthenticated = ref.watch(sessionProvider).isAuthenticated;

    // Unauthenticated deep link: show login prompt instead of invite form.
    if (!isAuthenticated && widget.preloadedUUID != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Accept Invite'),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppColors.forest100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mail_outline_rounded,
                    size: 40, color: AppColors.primaryMain),
              ),
              const SizedBox(height: AppSpacing.x2l),
              const Text('You\'ve Been Invited!',
                  style: AppTypography.h3, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Login or create an account to accept this invite and get started.',
                style:
                    AppTypography.body.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.x3l),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.go('/login'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryMain,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Login to Accept',
                      style:
                          AppTypography.button.copyWith(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Accept Invite'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          const SizedBox(height: AppSpacing.lg),

          // Icon
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppColors.forest100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mail_outline_rounded,
                size: 40,
                color: AppColors.primaryMain,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x2l),
          const Text('Enter Your Invite Code',
              style: AppTypography.h3, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Ask your nursery owner or manager for the invite link/UUID.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.x2l),

          // Scan QR button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _scanQr,
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
              label: const Text('Scan QR Code'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryMain,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: AppTypography.button,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x2l),

          // Divider
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text('or enter code manually',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textMuted)),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: AppSpacing.x2l),

          // UUID input
          AppTextField(
            controller: _uuidCtrl,
            label: 'Invite UUID',
            hint: 'e.g. 550e8400-e29b-41d4-a716-446655440000',
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Look Up Invite',
            isLoading: state.isLoading,
            onPressed: _lookup,
          ),

          // Error
          if (state.error != null && _looked) ...[
            const SizedBox(height: AppSpacing.md),
            _ErrorBanner(message: state.error!),
          ],

          // Invite details
          if (state.invite != null) ...[
            const SizedBox(height: AppSpacing.x2l),
            _InviteCard(invite: state.invite!),
            const SizedBox(height: AppSpacing.lg),
            if (state.invite!.isPending)
              AppButton(
                label: 'Accept Invite',
                isLoading: state.isAccepting,
                onPressed: _accept,
              )
            else
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.amber100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppColors.amber600, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'This invite is ${state.invite!.status.toLowerCase()} and cannot be accepted.',
                        style: AppTypography.body
                            .copyWith(color: AppColors.amber700),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.x3l),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            0,
            AppSpacing.screenPadding,
            AppSpacing.md,
          ),
          child: TextButton(
            onPressed: () => context.go('/home'),
            child: const Text('Continue as Customer for now'),
          ),
        ),
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  final InviteDetail invite;
  const _InviteCard({required this.invite});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryMain.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.forest100,
                  shape: BoxShape.circle,
                ),
                child: Icon(invite.typeIcon,
                    color: AppColors.primaryMain, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(invite.typeLabel, style: AppTypography.h4),
                    if (invite.nurseryName != null)
                      Text(
                        invite.nurseryName!,
                        style: AppTypography.body
                            .copyWith(color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: invite.isPending
                      ? AppColors.forest100
                      : AppColors.amber100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  invite.status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: invite.isPending
                        ? AppColors.primaryMain
                        : AppColors.amber600,
                  ),
                ),
              ),
            ],
          ),
          if (invite.inviterName != null) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const Icon(Icons.person_outline_rounded,
                    size: 16, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  'Invited by ${invite.inviterName}',
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.red100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.red600.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.red600, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(message,
                style: AppTypography.body.copyWith(color: AppColors.red600)),
          ),
        ],
      ),
    );
  }
}
