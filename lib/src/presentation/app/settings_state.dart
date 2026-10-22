import 'package:flutter/material.dart';

class SettingsState {
  const SettingsState({
    this.locale,
    this.theme = ThemeMode.system,
    this.sidebarWidth = 320,
  });
  final Locale? locale;
  final ThemeMode theme;
  final double sidebarWidth;
}
