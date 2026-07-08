import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression: inventory lived inside SelectionArea + outer scroll view,
/// which caused "Cannot hit test a render box that has never been laid out"
/// when tapping checkboxes or + buttons.
void main() {
  testWidgets('SelectionContainer.disabled allows nested grid taps', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var toggled = false;
    var priceTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectionArea(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Expanded(
                    child: SelectionContainer.disabled(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 260,
                            child: ListView(
                              primary: false,
                              children: const [
                                ListTile(title: Text('Bliss Beauty Spa')),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 48),
                                Expanded(
                                  child: ListView(
                                    primary: false,
                                    physics: const ClampingScrollPhysics(),
                                    children: [
                                      Row(
                                        children: [
                                          const SizedBox(
                                            width: 220,
                                            child: Text('Swedish Massage'),
                                          ),
                                          Expanded(
                                            child: _TestDayCell(
                                              onToggle: () => toggled = true,
                                              onPrice: () => priceTapped = true,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    await tester.tap(find.byIcon(Icons.check_box_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(tester.takeException(), isNull);
    expect(toggled, isTrue);
    expect(priceTapped, isTrue);
  });
}

class _TestDayCell extends StatelessWidget {
  const _TestDayCell({
    required this.onToggle,
    required this.onPrice,
  });

  final VoidCallback onToggle;
  final VoidCallback onPrice;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: const Icon(Icons.check_box_rounded, color: Color(0xFF4CAF50)),
          ),
          const Text('₹2499'),
          InkWell(
            onTap: onPrice,
            child: const Icon(Icons.add_circle_outline, color: Color(0xFF1E6FD9)),
          ),
        ],
      ),
    );
  }
}
