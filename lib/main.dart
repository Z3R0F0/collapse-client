import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'app.dart';
import 'core/config.dart';
import 'core/font_licenses.dart';
import 'dependency_injection.dart';
import 'src/data/auth/auth_repository.dart';

export 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  registerFontLicenses();
  await initInjections(AppConfig.environment());
  runApp(const CollapseApp());
  unawaited(locator<AuthRepository>().restore());
}
