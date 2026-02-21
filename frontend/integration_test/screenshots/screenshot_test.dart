/// Integration test that captures App Store / Play Store screenshots
/// for the FlowShift Staff app.
///
/// Run with flutter drive (NOT flutter test):
///   flutter drive \
///     --driver=test_driver/screenshot_driver.dart \
///     --target=integration_test/screenshots/screenshot_test.dart \
///     -d "iPhone 17 Pro Max"
///
/// Screenshots are saved by the driver to screenshots/simulator/.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Use the package import since the lib file is in the frontend package
import 'package:frontend/screenshot_app.dart';

/// Global key for the RepaintBoundary that wraps the entire app.
/// Used to capture screenshots from Flutter's rendering tree directly,
/// bypassing the native iOS screenshot mechanism which returns black
/// images with Impeller (Metal) rendering.
final _screenshotBoundaryKey = GlobalKey();

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Captures a screenshot by rendering directly from Flutter's rendering
  /// tree using [RenderRepaintBoundary.toImage]. This bypasses the native
  /// iOS IntegrationTestPlugin which uses drawViewHierarchyInRect — a UIKit
  /// API that cannot capture Metal/Impeller surfaces (returns black).
  Future<void> takeScreenshot(String name) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    try {
      final boundary = _screenshotBoundaryKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        debugPrint('Screenshot "$name": RepaintBoundary not found, falling back to native');
        await binding.takeScreenshot(name);
        return;
      }
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        debugPrint('Screenshot "$name": toByteData returned null');
        return;
      }
      final pngBytes = byteData.buffer.asUint8List().toList();

      // Store in reportData so the driver's onScreenshot receives the bytes
      binding.reportData ??= <String, dynamic>{};
      binding.reportData!['screenshots'] ??= <dynamic>[];
      (binding.reportData!['screenshots']! as List<dynamic>).add(<String, dynamic>{
        'screenshotName': name,
        'bytes': pngBytes,
      });
      debugPrint('Screenshot "$name": captured ${pngBytes.length ~/ 1024}KB via Dart rendering');
    } catch (e) {
      debugPrint('Screenshot "$name" capture error: $e');
    }
  }

  group('Staff App Store Screenshots — English', () {
    testWidgets('Capture all screens (EN)', (WidgetTester tester) async {
      await tester.pumpWidget(
        RepaintBoundary(
          key: _screenshotBoundaryKey,
          child: ScreenshotStaffApp(
            locale: const Locale('en'),
            initialTab: 0,
            tabs: const [
              ScreenshotTab(
                icon: Icons.work_outline_rounded,
                selectedIcon: Icons.work_rounded,
                label: 'Shifts',
              ),
              ScreenshotTab(
                icon: Icons.chat_bubble_outline,
                selectedIcon: Icons.chat_bubble,
                label: 'Chats',
              ),
              ScreenshotTab(
                icon: Icons.account_balance_wallet_outlined,
                selectedIcon: Icons.account_balance_wallet,
                label: 'Earnings',
              ),
              ScreenshotTab(
                icon: Icons.access_time_outlined,
                selectedIcon: Icons.access_time,
                label: 'Clock In',
              ),
            ],
            tabBodies: [
              _DemoShiftsTab(),
              _DemoChatsTab(),
              _DemoEarningsTab(),
              _DemoClockInTab(),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // ── 1. Shifts tab (tab 0) ──
      await takeScreenshot('01_shifts_en');

      // ── 2. Chats (tab 1) ──
      await tester.tap(find.text('Chats'));
      await tester.pumpAndSettle();
      await takeScreenshot('02_chats_en');

      // ── 3. Earnings (tab 2) ──
      await tester.tap(find.text('Earnings'));
      await tester.pumpAndSettle();
      await takeScreenshot('03_earnings_en');

      // ── 4. Clock In (tab 3) ──
      await tester.tap(find.text('Clock In'));
      await tester.pumpAndSettle();
      await takeScreenshot('04_clockin_en');

      // ── 5. Tap first shift card for detail ──
      await tester.tap(find.text('Shifts'));
      await tester.pumpAndSettle();
      final firstCard = find.byType(Card).first;
      if (firstCard.evaluate().isNotEmpty) {
        await tester.tap(firstCard);
        await tester.pumpAndSettle();
        await takeScreenshot('05_event_detail_en');
        final backIcon = find.byIcon(Icons.arrow_back);
        if (backIcon.evaluate().isNotEmpty) {
          await tester.tap(backIcon.first);
          await tester.pumpAndSettle();
        }
      }

      // ── 6. AI Chat ──
      final aiFab = find.byIcon(Icons.smart_toy);
      if (aiFab.evaluate().isNotEmpty) {
        await tester.tap(aiFab.first);
        await tester.pumpAndSettle();
        await takeScreenshot('06_ai_chat_en');
      }
    });
  });

  group('Staff App Store Screenshots — Spanish', () {
    testWidgets('Capture all screens (ES)', (WidgetTester tester) async {
      await tester.pumpWidget(
        RepaintBoundary(
          key: _screenshotBoundaryKey,
          child: ScreenshotStaffApp(
            locale: const Locale('es'),
            initialTab: 0,
            tabs: const [
              ScreenshotTab(
                icon: Icons.work_outline_rounded,
                selectedIcon: Icons.work_rounded,
                label: 'Turnos',
              ),
              ScreenshotTab(
                icon: Icons.chat_bubble_outline,
                selectedIcon: Icons.chat_bubble,
                label: 'Chats',
              ),
              ScreenshotTab(
                icon: Icons.account_balance_wallet_outlined,
                selectedIcon: Icons.account_balance_wallet,
                label: 'Ganancias',
              ),
              ScreenshotTab(
                icon: Icons.access_time_outlined,
                selectedIcon: Icons.access_time,
                label: 'Fichar',
              ),
            ],
            tabBodies: [
              _DemoShiftsTab(),
              _DemoChatsTab(),
              _DemoEarningsTab(),
              _DemoClockInTab(),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // ── 1. Shifts list ──
      await takeScreenshot('01_shifts_es');

      // ── 2. Chats ──
      await tester.tap(find.text('Chats'));
      await tester.pumpAndSettle();
      await takeScreenshot('02_chats_es');

      // ── 3. Earnings ──
      final earningsEs = find.text('Ganancias');
      if (earningsEs.evaluate().isNotEmpty) {
        await tester.tap(earningsEs.first);
      }
      await tester.pumpAndSettle();
      await takeScreenshot('03_earnings_es');

      // ── 4. Clock In ──
      final clockInEs = find.text('Fichar');
      if (clockInEs.evaluate().isNotEmpty) {
        await tester.tap(clockInEs.first);
      }
      await tester.pumpAndSettle();
      await takeScreenshot('04_clockin_es');

      // ── 5. Shift detail ──
      final shiftsEs = find.text('Turnos');
      if (shiftsEs.evaluate().isNotEmpty) {
        await tester.tap(shiftsEs.first);
      }
      await tester.pumpAndSettle();
      final firstCard = find.byType(Card).first;
      if (firstCard.evaluate().isNotEmpty) {
        await tester.tap(firstCard);
        await tester.pumpAndSettle();
        await takeScreenshot('05_event_detail_es');
        final backIcon = find.byIcon(Icons.arrow_back);
        if (backIcon.evaluate().isNotEmpty) {
          await tester.tap(backIcon.first);
          await tester.pumpAndSettle();
        }
      }

      // ── 6. AI Chat ──
      final aiFab = find.byIcon(Icons.smart_toy);
      if (aiFab.evaluate().isNotEmpty) {
        await tester.tap(aiFab.first);
        await tester.pumpAndSettle();
        await takeScreenshot('06_ai_chat_es');
      }
    });
  });
}

// ── Demo Tab Widgets ──────────────────────────────────────────────────
// These are standalone demo screens that render curated data
// without any backend dependencies.

class _DemoShiftsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Shifts'),
        actions: [
          IconButton(icon: const Icon(Icons.filter_list), onPressed: () {}),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _shiftCard(context, 'Annual Gala Dinner', 'The Ritz-Carlton Ballroom', 'Tomorrow, 4:00 PM', 'Bartender', '\$28/hr', true),
          _shiftCard(context, 'Wedding: Johnson & Lee', 'Dumbarton House Gardens', 'In 3 days', 'Server', '\$30/hr', true),
          _shiftCard(context, 'Tech Conference Reception', 'Marriott Grand Salon', 'Next week, 10:00 AM', 'Bartender', '\$25/hr', false),
          _shiftCard(context, 'Corporate Luncheon', 'Four Seasons Terrace', 'In 5 days', 'Server', '\$22/hr', false),
          _shiftCard(context, 'Charity Fundraiser Gala', 'National Building Museum', 'In 10 days', 'Bartender', '\$32/hr', false),
        ],
      ),
    );
  }

  Widget _shiftCard(BuildContext context, String title, String venue, String time, String role, String rate, bool accepted) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                if (accepted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Text('Accepted', style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w500)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(child: Text(venue, style: const TextStyle(color: Colors.grey, fontSize: 13))),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(time, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const Spacer(),
                Text(role, style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w500, fontSize: 13)),
                const SizedBox(width: 8),
                Text(rate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoChatsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conversations')),
      body: ListView(
        children: [
          _chatTile('Annual Gala Team', 'Uniform update: black vest required', '15m ago', 2),
          _chatTile('Wedding Staff Chat', 'Menu finalized — see attached PDF', '1h ago', 0),
          _chatTile('All Staff Announcements', 'Holiday schedule posted for December', '1d ago', 0),
        ],
      ),
    );
  }

  Widget _chatTile(String name, String lastMessage, String time, int unread) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blueGrey.shade100,
        child: Text(name[0], style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(time, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          if (unread > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11)),
            ),
          ],
        ],
      ),
    );
  }
}

class _DemoEarningsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _earningsCard('This Week', '\$434.00', Colors.blue),
          _earningsCard('Last Week', '\$612.00', Colors.blueGrey),
          _earningsCard('This Month', '\$2,847.50', Colors.green),
          const SizedBox(height: 24),
          const Text('Recent Shifts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _earningRow('Wine Tasting Evening', 'Yesterday', '\$104.00'),
          _earningRow('Corporate Mixer', '3 days ago', '\$150.00'),
          _earningRow('Art Gallery Opening', '5 days ago', '\$180.00'),
        ],
      ),
    );
  }

  Widget _earningsCard(String label, String amount, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.account_balance_wallet, color: color),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 4),
                Text(amount, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _earningRow(String event, String date, String amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}

class _DemoClockInTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clock In')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Next Shift', style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 8),
            const Text('Annual Gala Dinner', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Tomorrow at 4:00 PM', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.green, width: 4),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.fingerprint, size: 48, color: Colors.green),
                    SizedBox(height: 8),
                    Text('Clock In', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('You\'ll be able to clock in\nwhen you arrive at the venue',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
