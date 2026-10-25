part of 'owner_members_screen.dart';

class _InviteSheet extends ConsumerStatefulWidget {
  final int nurseryId;
  final String nurseryName;
  final String inviteType;

  const _InviteSheet({
    required this.nurseryId,
    required this.nurseryName,
    required this.inviteType,
  });

  @override
  ConsumerState<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<_InviteSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
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

  String get _roleLabel => switch (widget.inviteType) {
        'MANAGER_INVITE' => 'Manager',
        'DRIVER_INVITE' => 'Driver',
        _ => 'Customer',
      };

  String get _title => widget.inviteType == 'MANAGER_INVITE'
      ? 'Invite Manager / Gumastha'
      : 'Invite $_roleLabel';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final invite =
        await ref.read(membersProvider(widget.nurseryId).notifier).createInvite(
              inviteType: widget.inviteType,
              targetMobile: _phoneCtrl.text.trim(),
              targetName:
                  _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
            );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (invite != null) {
      setState(() => _created = invite);
      // createInvite already reloaded the list (the caller's ref may be gone).
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
      child: _created != null
          ? _SuccessView(
              invite: _created!,
              onCopy: _copyUUID,
              onDone: () => Navigator.pop(context),
            )
          : _FormView(
              formKey: _formKey,
              nameCtrl: _nameCtrl,
              phoneCtrl: _phoneCtrl,
              title: _title,
              roleLabel: _roleLabel,
              isLoading: _isLoading,
              error: _error,
              onSubmit: _submit,
              onCancel: () => Navigator.pop(context),
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
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.errorText,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      error!,
                      style: AppTypography.body
                          .copyWith(color: AppColors.errorText),
                    ),
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
              minimumSize: const Size(double.infinity, AppSpacing.buttonHeight),
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
          child: const Icon(
            Icons.check_rounded,
            color: AppColors.primaryMain,
            size: 36,
          ),
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
                    icon: const Icon(
                      Icons.copy_rounded,
                      color: AppColors.primaryMain,
                      size: 20,
                    ),
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
            minimumSize: const Size(double.infinity, AppSpacing.buttonHeight),
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

class _RemovableMemberTile extends StatelessWidget {
  final IconData icon;
  final String name;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final VoidCallback onRemove;

  const _RemovableMemberTile({
    required this.icon,
    required this.name,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
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
        child: Icon(icon, color: AppColors.primaryMain, size: 20),
      ),
      title: Text(name, style: AppTypography.label),
      subtitle: Text(
        subtitle,
        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: badgeColor,
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(
              Icons.person_remove_outlined,
              color: AppColors.red600,
              size: 20,
            ),
            tooltip: 'Remove',
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
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
            child: const Icon(
              Icons.mail_outline_rounded,
              color: AppColors.amber600,
              size: 20,
            ),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                    Icon(
                      Icons.qr_code_rounded,
                      size: 12,
                      color: AppColors.primaryMain,
                    ),
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
