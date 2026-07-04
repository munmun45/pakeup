import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pakeup_store_app/app.dart';
import 'package:pakeup_store_app/core/constants/app_constants.dart';
import 'package:pakeup_store_app/features/auth/data/auth_repository.dart';
import 'package:pakeup_store_app/features/auth/providers/auth_provider.dart';

class _LoggedOutAuthNotifier extends AuthNotifier {
  @override
  Future<PartnerUser?> build() async => null;
}

void main() {
  testWidgets('shows login screen when logged out', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_LoggedOutAuthNotifier.new),
        ],
        child: const PakeUpStoreApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppConstants.appName), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Register your salon'), findsOneWidget);
  });
}
