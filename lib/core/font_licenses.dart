import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'IBM Plex Mono',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
}
