import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/profile_completion_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../auth/data/models/capabilities_model.dart';
import '../auth/data/models/user_models.dart';
import '../auth/domain/rbac/roles.dart';
import '../auth/presentation/providers/session_provider.dart';
import '../nurseries/nurseries.dart' show Nursery, nurseryDetailProvider;

class CompleteProfileScreen extends ConsumerWidget {
  const CompleteProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final user = session.user;
    final caps = session.capabilities;
    final nursery = caps.primaryNurseryId == null
        ? null
        : ref.watch(nurseryDetailProvider(caps.primaryNurseryId!)).valueOrNull;
    final completionItems = buildCompletionItems(
      role: _roleFor(caps),
      user: user,
      caps: caps,
      nursery: nursery,
      onEditProfile: () => context.push('/edit-profile'),
      onEditAddress: caps.primaryNurseryId != null
          ? () => context.push(
                '/nursery/addresses',
                extra: caps.primaryNurseryId,
              )
          : null,
      onEditNurseryProfile: caps.primaryNurseryId != null
          ? () => context.push(
                '/nursery/profile',
                extra: caps.primaryNurseryId,
              )
          : null,
      onRegisterDriver: () => context.push('/register/driver'),
    );
    final pct = completionPercent(completionItems);
    final tasks = _tasksFor(context, user, caps, nursery);
    final next = tasks.where((t) => !t.done && t.onTap != null).firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Complete Your Profile', style: AppTypography.h3),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          _ProgressCard(
            percent: pct,
            done: completionItems.where((i) => i.done).length,
            total: completionItems.length,
          ),
          const SizedBox(height: AppSpacing.x2l),
          _ChecklistSection(
            title: 'Personal Information',
            tasks:
                tasks.where((t) => t.section == _TaskSection.personal).toList(),
          ),
          if (caps.isNurseryOwner) ...[
            const SizedBox(height: AppSpacing.x2l),
            _ChecklistSection(
              title: 'Nursery Profile',
              tasks: tasks
                  .where((t) => t.section == _TaskSection.nursery)
                  .toList(),
            ),
          ],
          if (caps.isNurseryOwner) ...[
            const SizedBox(height: AppSpacing.x2l),
            _ChecklistSection(
              title: 'Business (Optional)',
              tasks: tasks
                  .where((t) => t.section == _TaskSection.business)
                  .toList(),
            ),
          ],
          const SizedBox(height: AppSpacing.x3l),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: ElevatedButton(
            onPressed: next?.onTap ?? () => context.pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryMain,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, AppSpacing.buttonHeight),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(next == null ? 'Done' : 'Continue'),
          ),
        ),
      ),
    );
  }

  static AppRole _roleFor(UserCapabilities caps) {
    if (caps.canSell) {
      return caps.isNurseryOwner ? AppRole.nurseryOwner : AppRole.manager;
    }
    if (caps.hasDriverProfile) return AppRole.driver;
    return AppRole.buyer;
  }

  static List<_ProfileTask> _tasksFor(
    BuildContext context,
    UserProfile? user,
    UserCapabilities caps,
    Nursery? nursery,
  ) {
    void editPersonal() => context.push('/edit-profile');
    void editAddress() {
      context.push('/nursery/addresses', extra: caps.primaryNurseryId);
    }

    VoidCallback? editNursery;
    if (caps.primaryNurseryId != null) {
      editNursery = () {
        context.push('/nursery/profile', extra: caps.primaryNurseryId);
      };
    }

    return [
      _ProfileTask(
        section: _TaskSection.personal,
        label: 'Add first name',
        done: user?.hasRealFirstName ?? false,
        onTap: editPersonal,
      ),
      _ProfileTask(
        section: _TaskSection.personal,
        label: 'Add last name',
        done: user?.lastName?.isNotEmpty ?? false,
        onTap: editPersonal,
      ),
      _ProfileTask(
        section: _TaskSection.personal,
        label: 'Add email address',
        done: user?.email?.isNotEmpty == true,
        onTap: editPersonal,
      ),
      _ProfileTask(
        section: _TaskSection.personal,
        label: 'Upload profile photo',
        done: user?.profileImageUrl?.isNotEmpty == true,
        onTap: editPersonal,
      ),
      _ProfileTask(
        section: _TaskSection.personal,
        label: 'Set gender',
        done: user?.gender?.isNotEmpty == true,
        onTap: editPersonal,
      ),
      if (caps.isNurseryOwner) ...[
        _ProfileTask(
          section: _TaskSection.nursery,
          label: 'Nursery approved',
          done: caps.isNurseryOwner,
        ),
        _ProfileTask(
          section: _TaskSection.nursery,
          label: 'Add nursery address',
          done: nursery?.addresses.isNotEmpty == true,
          onTap: caps.primaryNurseryId == null ? null : editAddress,
        ),
        _ProfileTask(
          section: _TaskSection.nursery,
          label: 'Add nursery description',
          done: nursery?.description?.isNotEmpty == true,
          onTap: editNursery,
        ),
      ],
      if (caps.isNurseryOwner) ...[
        _ProfileTask(
          section: _TaskSection.business,
          label: 'Add website',
          done: nursery?.website?.isNotEmpty == true,
          optional: true,
          onTap: editNursery,
        ),
      ],
    ];
  }
}

class _ProgressCard extends StatelessWidget {
  final double percent;
  final int done;
  final int total;

  const _ProgressCard({
    required this.percent,
    required this.done,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final pctLabel = '${(percent * 100).round()}%';
    final color = percent >= 0.9
        ? AppColors.primaryMain
        : percent >= 0.5
            ? AppColors.amber600
            : AppColors.red500;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 88,
                  height: 88,
                  child: CircularProgressIndicator(
                    value: percent.clamp(0, 1),
                    strokeWidth: 7,
                    backgroundColor: AppColors.border,
                    color: color,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Text(
                  pctLabel,
                  style: AppTypography.h3.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            percent >= 1 ? 'Profile complete' : 'You are doing great!',
            style: AppTypography.h4.copyWith(color: AppColors.primaryMain),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            percent >= 1
                ? 'Tap any section below to update your profile'
                : 'Complete the remaining steps to get the most out of GreenRoot.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ChecklistSection extends StatelessWidget {
  final String title;
  final List<_ProfileTask> tasks;

  const _ChecklistSection({required this.title, required this.tasks});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.h4),
        const SizedBox(height: AppSpacing.sm),
        Material(
          color: AppColors.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Column(
            children: [
              for (int i = 0; i < tasks.length; i++) ...[
                _ChecklistTile(task: tasks[i]),
                if (i < tasks.length - 1)
                  const Divider(height: 1, color: AppColors.border),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  final _ProfileTask task;

  const _ChecklistTile({required this.task});

  @override
  Widget build(BuildContext context) {
    final tappable = task.onTap != null;
    return ListTile(
      onTap: task.onTap,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
      leading: Icon(
        task.done
            ? Icons.check_circle_rounded
            : Icons.radio_button_unchecked_rounded,
        color: task.done ? AppColors.primaryMain : AppColors.textMuted,
      ),
      title: Text(task.label, style: AppTypography.body),
      trailing: task.optional
          ? Text(
              'Optional',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          : tappable
              ? const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                )
              : null,
    );
  }
}

enum _TaskSection { personal, nursery, business }

class _ProfileTask {
  final _TaskSection section;
  final String label;
  final bool done;
  final bool optional;
  final VoidCallback? onTap;

  const _ProfileTask({
    required this.section,
    required this.label,
    required this.done,
    this.optional = false,
    this.onTap,
  });
}
