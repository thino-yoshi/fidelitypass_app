import 'package:flutter/foundation.dart';

class AppLogger {
  static const _r  = '\x1B[0m';
  static const _b  = '\x1B[1m';

  static const _cyan    = '\x1B[96m';
  static const _magenta = '\x1B[95m';
  static const _green   = '\x1B[92m';
  static const _yellow  = '\x1B[93m';
  static const _red     = '\x1B[91m';
  static const _blue    = '\x1B[94m';
  static const _orange  = '\x1B[33m';
  static const _gray    = '\x1B[37m';

  static void auth(String msg)     => debugPrint('$_b$_cyan[AUTH]$_r     $_cyan$msg$_r');
  static void api(String msg)      => debugPrint('$_b$_magenta[API]$_r      $_magenta$msg$_r');
  static void client(String msg)   => debugPrint('$_b$_green[CLIENT]$_r   $_green$msg$_r');
  static void merchant(String msg) => debugPrint('$_b$_yellow[MERCHANT]$_r $_yellow$msg$_r');
  static void error(String msg)    => debugPrint('$_b$_red[ERROR]$_r    $_red$msg$_r');
  static void nav(String msg)      => debugPrint('$_b$_blue[NAV]$_r      $_blue$msg$_r');
  static void fcm(String msg)      => debugPrint('$_b$_orange[FCM]$_r      $_orange$msg$_r');
  static void splash(String msg)   => debugPrint('$_b$_gray[SPLASH]$_r   $_gray$msg$_r');
}
