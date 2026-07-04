import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/partners_repository.dart';
import 'partner_parent_account_form.dart';
import 'partner_parent_account_form_ui.dart';

class PartnerParentAccountDialog extends ConsumerStatefulWidget {
  const PartnerParentAccountDialog({super.key, this.existing});

  final PartnerOwnerAccount? existing;

  bool get isEdit => existing != null;

  @override
  ConsumerState<PartnerParentAccountDialog> createState() =>
      _PartnerParentAccountDialogState();
}

class _PartnerParentAccountDialogState
    extends ConsumerState<PartnerParentAccountDialog> {
  final _formUi = PartnerParentAccountFormUi();

  @override
  void dispose() {
    _formUi.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 920,
          maxHeight: size.height * 0.92,
        ),
        child: Column(
          children: [
            _PartnerDialogHeader(
              isEdit: widget.isEdit,
              onClose: _formUi.isSubmitting
                  ? null
                  : () => Navigator.pop(context),
            ),
            Expanded(
              child: Container(
                color: const Color(0xFFF3F4F6),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: PartnerParentAccountForm(
                    existing: widget.existing,
                    formUi: _formUi,
                    onCreated: () => Navigator.pop(context, true),
                  ),
                ),
              ),
            ),
            ListenableBuilder(
              listenable: _formUi,
              builder: (context, _) {
                return Container(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _formUi.isSubmitting
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: (_formUi.isSubmitting || !_formUi.canSubmit)
                            ? null
                            : () => _formUi.submit?.call(),
                        icon: _formUi.isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                widget.isEdit
                                    ? Icons.save_outlined
                                    : Icons.person_add_alt_1_rounded,
                              ),
                        label: Text(
                          _formUi.isSubmitting
                              ? (widget.isEdit ? 'Saving...' : 'Creating...')
                              : (widget.isEdit
                                  ? 'Save Partner'
                                  : 'Create Partner'),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PartnerDialogHeader extends StatelessWidget {
  const _PartnerDialogHeader({
    required this.isEdit,
    this.onClose,
  });

  final bool isEdit;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 8, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isEdit ? Icons.edit_outlined : Icons.person_add_alt_1_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? 'Edit Partner' : 'Create Partner',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isEdit
                      ? 'Update parent login account — re-verify if contacts change'
                      : 'Create the parent login account — add stores separately',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
        ],
      ),
    );
  }
}
