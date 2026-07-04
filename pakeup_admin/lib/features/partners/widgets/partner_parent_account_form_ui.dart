import 'package:flutter/foundation.dart';

/// Shared UI state between [PartnerParentAccountForm] and dialog footer.
class PartnerParentAccountFormUi extends ChangeNotifier {
  bool canSubmit = false;
  bool isSubmitting = false;
  Future<void> Function()? submit;

  void update({bool? canSubmit, bool? isSubmitting}) {
    var changed = false;
    if (canSubmit != null && this.canSubmit != canSubmit) {
      this.canSubmit = canSubmit;
      changed = true;
    }
    if (isSubmitting != null && this.isSubmitting != isSubmitting) {
      this.isSubmitting = isSubmitting;
      changed = true;
    }
    if (changed) notifyListeners();
  }
}
