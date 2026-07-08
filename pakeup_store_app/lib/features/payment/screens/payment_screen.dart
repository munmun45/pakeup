import 'package:flutter/material.dart';

import '../../shared/widgets/store_required_gate.dart';
import '../../bank/screens/bank_account_view_screen.dart';

/// Payment tab — bank account & settlements.
class PaymentScreen extends StatelessWidget {
  const PaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const StoreRequiredGate(
      title: 'Payment',
      child: BankAccountViewScreen(),
    );
  }
}
