import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

// TODOs:
// - add "hitzone" before and after 0%
// - add sound and visual effect when failing to hit within the "hitzone"

enum SettingsKey { sound, visualEffect, hitzoneBefore, hitzoneAfter, durationBase, durationRandomness }

extension SettingsKeyExtension on SettingsKey {
  String get asString {
    switch (this) {
      case SettingsKey.sound:
        return 'sound';
      case SettingsKey.visualEffect:
        return 'visualEffect';
      case SettingsKey.hitzoneBefore:
        return 'hitzoneBefore';
      case SettingsKey.hitzoneAfter:
        return 'hitzoneAfter';
      case SettingsKey.durationBase:
        return 'durationBase';
      case SettingsKey.durationRandomness:
        return 'durationRandomness';
    }
  }
}

class DefaultSettings {
  static const Map<SettingsKey, dynamic> values = {
    SettingsKey.sound: true,
    SettingsKey.visualEffect: true,
    SettingsKey.hitzoneBefore: 100, // ms
    SettingsKey.hitzoneAfter: 100, // ms
    SettingsKey.durationBase: 500, // ms
    SettingsKey.durationRandomness: 1000, // ms
  };

  static T get<T>(SettingsKey key) {
    return values[key] as T;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set default window size for desktop platforms only
  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(600, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tapper App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.blue),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  bool _isDeLoading = false;
  double _progress = 0.0; // Initial state: 0% full
  final Random _random = Random();
  AnimationController? _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this, // The TickerProvider
      duration: const Duration(seconds: 1), // Default duration, will be overridden
    );

    // Listener to update _progress when animation value changes
    _animationController!.addListener(() {
      setState(() {
        // Invert the animation value for a de-loading effect (1.0 to 0.0)
        _progress = 1.0 - _animationController!.value;
      });
    });

    // Listener for animation status changes
    _animationController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isDeLoading = false;
          // Reset progress to empty (0.0) when de-loading is complete
          _progress = 0.0;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController?.dispose(); // Dispose the controller
    super.dispose();
  }

  void _buttonPressed() {
    // Placeholder for button press action
    if (!_isDeLoading) {
      _startDeLoading();
    }
  }

  void _startDeLoading() async {
    // Stop any ongoing animation before starting a new one
    _animationController?.stop();

    setState(() {
      _isDeLoading = true;
      _progress = 1.0; // Ensure progress starts at 100% visually
    });

    // Generate a random duration between 500 ms (0.5 seconds) and 1500 ms (1.5 seconds)
    // Read durationBase and durationRandomness from SettingsKey
    final prefs = await SharedPreferences.getInstance();
    final int durationBase =
        prefs.getInt(SettingsKey.durationBase.toString()) ?? DefaultSettings.get<int>(SettingsKey.durationBase);
    final int durationRandomness =
        prefs.getInt(SettingsKey.durationRandomness.toString()) ??
        DefaultSettings.get<int>(SettingsKey.durationRandomness);
    final int randomDurationMs = _random.nextInt(durationRandomness + 1) + durationBase;
    _animationController!.duration = Duration(milliseconds: randomDurationMs);

    // Reset the animation controller's value to 0.0 before starting
    _animationController!.reset();
    // Start the animation, which will move from 0.0 to 1.0 over its duration
    _animationController!.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tapper App: De-Loading Progress')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Text(
                'Press the button to start a de-loading sequence:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.6, // 60% of column width
              child: LinearProgressIndicator(
                value: _progress, // The progress bar value is now driven by _progress
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                minHeight: 10.0,
                borderRadius: BorderRadius.circular(4.0),
              ),
            ),
            const SizedBox(height: 15),
            Text('${(_progress * 100).toStringAsFixed(0)}%', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 30),
            Text(
              (_isDeLoading) ? 'Status: De-Loading...' : 'Status: Ready',
              style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _buttonPressed, autofocus: true, child: const Icon(Icons.play_arrow)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final prefs = await SharedPreferences.getInstance();
          // Load current settings or defaults
          Map<SettingsKey, dynamic> currentSettings = {};
          for (var key in SettingsKey.values) {
            switch (key) {
              case SettingsKey.sound:
              case SettingsKey.visualEffect:
                currentSettings[key] = prefs.getBool(key.asString) ?? DefaultSettings.get<bool>(key);
                break;
              default:
                currentSettings[key] = prefs.getInt(key.asString) ?? DefaultSettings.get<int>(key);
            }
          }

          if (!mounted) return;
          showDialog(
            context: context,
            builder: (context) {
              // Local state for dialog
              Map<SettingsKey, dynamic> dialogSettings = Map.of(currentSettings);

              return StatefulBuilder(
                builder: (context, setState) {
                  return AlertDialog(
                    title: const Text('Settings'),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SwitchListTile(
                            title: const Text('Sound'),
                            value: dialogSettings[SettingsKey.sound],
                            onChanged: (val) => setState(() => dialogSettings[SettingsKey.sound] = val),
                          ),
                          SwitchListTile(
                            title: const Text('Visual Effect'),
                            value: dialogSettings[SettingsKey.visualEffect],
                            onChanged: (val) => setState(() => dialogSettings[SettingsKey.visualEffect] = val),
                          ),
                          ListTile(
                            title: const Text('Hitzone Before (ms)'),
                            trailing: SizedBox(
                              width: 80,
                              child: TextFormField(
                                initialValue: dialogSettings[SettingsKey.hitzoneBefore].toString(),
                                keyboardType: TextInputType.number,
                                onChanged: (val) => setState(() {
                                  dialogSettings[SettingsKey.hitzoneBefore] =
                                      int.tryParse(val) ?? dialogSettings[SettingsKey.hitzoneBefore];
                                }),
                              ),
                            ),
                          ),
                          ListTile(
                            title: const Text('Hitzone After (ms)'),
                            trailing: SizedBox(
                              width: 80,
                              child: TextFormField(
                                initialValue: dialogSettings[SettingsKey.hitzoneAfter].toString(),
                                keyboardType: TextInputType.number,
                                onChanged: (val) => setState(() {
                                  dialogSettings[SettingsKey.hitzoneAfter] =
                                      int.tryParse(val) ?? dialogSettings[SettingsKey.hitzoneAfter];
                                }),
                              ),
                            ),
                          ),
                          ListTile(
                            title: const Text('Duration Base (ms)'),
                            trailing: SizedBox(
                              width: 80,
                              child: TextFormField(
                                initialValue: dialogSettings[SettingsKey.durationBase].toString(),
                                keyboardType: TextInputType.number,
                                onChanged: (val) => setState(() {
                                  dialogSettings[SettingsKey.durationBase] =
                                      int.tryParse(val) ?? dialogSettings[SettingsKey.durationBase];
                                }),
                              ),
                            ),
                          ),
                          ListTile(
                            title: const Text('Duration Randomness (ms)'),
                            trailing: SizedBox(
                              width: 80,
                              child: TextFormField(
                                initialValue: dialogSettings[SettingsKey.durationRandomness].toString(),
                                keyboardType: TextInputType.number,
                                onChanged: (val) => setState(() {
                                  dialogSettings[SettingsKey.durationRandomness] =
                                      int.tryParse(val) ?? dialogSettings[SettingsKey.durationRandomness];
                                }),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                      ElevatedButton(
                        onPressed: () async {
                          // Save settings
                          for (var key in SettingsKey.values) {
                            var value = dialogSettings[key];
                            if (value is bool) {
                              await prefs.setBool(key.asString, value);
                            } else if (value is int) {
                              await prefs.setInt(key.asString, value);
                            }
                          }
                          Navigator.of(context).pop();
                          setState(() {}); // Refresh main page if needed
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
        tooltip: 'Preferences',
        child: const Icon(Icons.settings),
      ),
    );
  }
}
