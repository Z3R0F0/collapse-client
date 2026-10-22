import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_state.dart';

export 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this.preferences)
    : super(
        SettingsState(
          sidebarWidth: (preferences.getDouble('sidebarWidth') ?? 320).clamp(
            72,
            420,
          ),
          locale: switch (preferences.getString('locale')) {
            'ru' => const Locale('ru'),
            'en' => const Locale('en'),
            _ => null,
          },
          theme: ThemeMode.values.firstWhere(
            (mode) => mode.name == preferences.getString('theme'),
            orElse: () => ThemeMode.system,
          ),
        ),
      );
  final SharedPreferences preferences;
  Timer? _sidebarSave;

  void setSidebarWidth(double width) {
    if (!width.isFinite) return;
    final value = width.clamp(72.0, 420.0);
    if (value == state.sidebarWidth) return;
    emit(
      SettingsState(
        locale: state.locale,
        theme: state.theme,
        sidebarWidth: value,
      ),
    );
    _sidebarSave?.cancel();
    _sidebarSave = Timer(
      const Duration(milliseconds: 250),
      () => preferences.setDouble('sidebarWidth', value),
    );
  }

  Future<void> setLocale(String? code) async {
    if (code == null) {
      await preferences.remove('locale');
    } else {
      await preferences.setString('locale', code);
    }
    emit(
      SettingsState(
        locale: code == null ? null : Locale(code),
        theme: state.theme,
        sidebarWidth: state.sidebarWidth,
      ),
    );
  }

  Future<void> setTheme(ThemeMode mode) async {
    await preferences.setString('theme', mode.name);
    emit(
      SettingsState(
        locale: state.locale,
        theme: mode,
        sidebarWidth: state.sidebarWidth,
      ),
    );
  }

  @override
  Future<void> close() async {
    _sidebarSave?.cancel();
    await preferences.setDouble('sidebarWidth', state.sidebarWidth);
    return super.close();
  }
}
