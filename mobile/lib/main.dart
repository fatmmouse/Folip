// Entry point — delegates to lib/app/main.dart for the actual app setup.
export 'app/main.dart';

// Re-export main() so flutter run picks it up from this file.
// The actual implementation is in lib/app/main.dart.
import 'app/main.dart' as app;

void main() => app.main();
