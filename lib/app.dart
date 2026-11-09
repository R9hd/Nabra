import 'package:flutter/gestures.dart';

import 'core/app_theme.dart';
import 'screens/auth/auth_gate.dart';
import 'ui.dart';

class NabraApp extends StatelessWidget {
  const NabraApp({super.key, this.home});

  /// Overridable for tests.
  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      scrollBehavior: const AppScrollBehavior(),
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      // Respect the user's font size, within limits the layouts are tested for.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.3)),
          child: child!,
        );
      },
      home: home ?? const AuthGate(),
    );
  }
}

/// Lets every scrollable page be dragged with touch, mouse, trackpad or stylus
/// (Flutter web/desktop ignore mouse drags by default) and shows a scrollbar
/// so it's obvious there is more content below.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    final vertical = details.direction == AxisDirection.down || details.direction == AxisDirection.up;
    return vertical ? Scrollbar(controller: details.controller, child: child) : child;
  }
}
