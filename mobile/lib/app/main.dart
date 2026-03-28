import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: FolipApp(),
    ),
  );
}

/// Root application widget.
///
/// Uses ProviderScope for Riverpod dependency injection, buildAppTheme() for
/// Anthropic brand styling, and routerProvider for declarative navigation.
class FolipApp extends ConsumerWidget {
  const FolipApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Folip',
      theme: buildAppTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
