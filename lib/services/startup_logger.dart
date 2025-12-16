import 'dart:io';

class StartupLogger {
  static final StartupLogger _instance = StartupLogger._internal();
  factory StartupLogger() => _instance;
  StartupLogger._internal();

  File? _file;
  String? _filePath;
  bool _initialized = false;

  String? get filePath => _filePath;

  static StartupLogger bootstrapSync({String appName = 'CyreneMusic'}) {
    final logger = StartupLogger();
    if (logger._initialized) return logger;

    logger._initialized = true;

    Directory dir;
    try {
      dir = _resolveLogDir(appName);
      dir.createSync(recursive: true);
    } catch (_) {
      dir = Directory('${Directory.systemTemp.path}${Platform.pathSeparator}$appName');
      dir.createSync(recursive: true);
    }

    final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${dir.path}${Platform.pathSeparator}startup_$ts.log');
    logger._file = file;
    logger._filePath = file.path;

    logger._writeSync('=== Startup log ${DateTime.now().toIso8601String()} ===');
    logger._writeSync('Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    logger._writeSync('Executable: ${Platform.resolvedExecutable}');
    logger._writeSync('CWD: ${Directory.current.path}');

    return logger;
  }

  static Directory _resolveLogDir(String appName) {
    final env = Platform.environment;

    if (Platform.isMacOS) {
      final home = env['HOME'];
      if (home != null && home.isNotEmpty) {
        return Directory('$home/Library/Logs/$appName');
      }
    }

    if (Platform.isWindows) {
      final appData = env['APPDATA'];
      if (appData != null && appData.isNotEmpty) {
        return Directory('$appData${Platform.pathSeparator}$appName${Platform.pathSeparator}logs');
      }
    }

    if (Platform.isLinux) {
      final home = env['HOME'];
      if (home != null && home.isNotEmpty) {
        return Directory('$home/.local/state/$appName/logs');
      }
    }

    final home = env['HOME'];
    if (home != null && home.isNotEmpty) {
      return Directory('$home${Platform.pathSeparator}.$appName${Platform.pathSeparator}logs');
    }

    return Directory('${Directory.systemTemp.path}${Platform.pathSeparator}$appName');
  }

  void log(String message) {
    if (!_initialized) {
      bootstrapSync();
    }

    final ts = DateTime.now().toIso8601String();
    _writeSync('[$ts] $message');
  }

  void _writeSync(String line) {
    final file = _file;
    if (file == null) return;

    try {
      file.writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
    } catch (_) {}
  }
}
