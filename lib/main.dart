import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

enum SettingsKey { sound, visualEffect, hitzoneBefore, hitzoneAfter, durationBase, durationRandomness, penaltyTime }

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
      case SettingsKey.penaltyTime:
        return 'penaltyTime';
    }
  }
}

class DefaultSettings {
  static const Map<SettingsKey, dynamic> values = {
    SettingsKey.sound: true,
    SettingsKey.visualEffect: true,
    SettingsKey.hitzoneBefore: 150, // ms
    SettingsKey.hitzoneAfter: 200, // ms
    SettingsKey.durationBase: 1000, // ms
    SettingsKey.durationRandomness: 500, // ms
    SettingsKey.penaltyTime: 1000, // ms
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
  bool _isPenaltyActive = false;
  double _progress = 0.0; // Initial state: 0% full
  final Random _random = Random();
  AnimationController? _animationController;
  final barBgColorDefault = Colors.grey[300];
  final barFgColorDefault = Colors.blue;
  Color? barBgColor;
  Color? barFgColor;

  @override
  void initState() {
    super.initState();
    barBgColor = barBgColorDefault;
    barFgColor = barFgColorDefault;
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

        // Start a timer for "hitzoneAfter" after de-loading completes
        () async {
          final prefs = await SharedPreferences.getInstance();
          final int hitzoneAfter =
              prefs.getInt(SettingsKey.hitzoneAfter.asString) ?? DefaultSettings.get<int>(SettingsKey.hitzoneAfter);
          Future.delayed(Duration(milliseconds: hitzoneAfter), () {
            if (_isDeLoading) {
              return; // If user has started a new de-loading, skip effects
            }

            // Missed hitzone - apply penalty
            _applyPenalty();
          });
        }();
      }
    });
  }

  @override
  void dispose() {
    _animationController?.dispose(); // Dispose the controller
    super.dispose();
  }

  void _buttonPressed() {
    // Don't allow button press during penalty
    if (_isPenaltyActive) return;

    // Placeholder for button press action
    if (_isDeLoading) {
      () async {
        final prefs = await SharedPreferences.getInstance();
        final int hitzoneBefore =
            prefs.getInt(SettingsKey.hitzoneBefore.asString) ?? DefaultSettings.get<int>(SettingsKey.hitzoneBefore);
        if (_animationController != null) {
          final int remainingMs = ((1.0 - _animationController!.value) * _animationController!.duration!.inMilliseconds)
              .round();
          if (remainingMs > hitzoneBefore) {
            // Missed hitzone - apply penalty
            _applyPenalty();
            return;
          }
        }
      }();
      _animationController?.stop();
      setState(() {
        _isDeLoading = false;
        _progress = 0.0; // Reset progress to empty
      });
    }

    _startDeLoading();
  }

  void _playSound() async {
    // play short cue to notify user of failed hit
    final player = AudioPlayer();
    await player.play(AssetSource('sound/failed_SFX.wav'));
  }

  void _triggerVisualEffect() {
    // colorize the background briefly
    setState(() {
      barBgColor = Colors.red;
      barFgColor = Colors.yellow;
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      setState(() {
        barBgColor = barBgColorDefault;
        barFgColor = barFgColorDefault;
      });
    });
  }

  void _startDeLoading() async {
    // Stop any ongoing animation before starting a new one
    _animationController?.stop();

    setState(() {
      _isDeLoading = true;
      _progress = 1.0; // Ensure progress starts at 100% visually
    });

    // Generate a random duration based on user settings
    // Read durationBase and durationRandomness from SettingsKey
    final prefs = await SharedPreferences.getInstance();
    final int durationBase =
        prefs.getInt(SettingsKey.durationBase.asString) ?? DefaultSettings.get<int>(SettingsKey.durationBase);
    final int durationRandomness =
        prefs.getInt(SettingsKey.durationRandomness.asString) ??
        DefaultSettings.get<int>(SettingsKey.durationRandomness);
    final int randomDurationMs = (_random.nextInt(durationRandomness + 1) - (durationRandomness ~/ 2)) + durationBase;
    _animationController!.duration = Duration(milliseconds: randomDurationMs);

    // Reset the animation controller's value to 0.0 before starting
    _animationController!.reset();
    // Start the animation, which will move from 0.0 to 1.0 over its duration
    _animationController!.forward();
  }

  void _applyPenalty() async {
    final prefs = await SharedPreferences.getInstance();
    final int penaltyTime =
        prefs.getInt(SettingsKey.penaltyTime.asString) ?? DefaultSettings.get<int>(SettingsKey.penaltyTime);

    // Play sound and visual effect for penalty
    if (prefs.getBool(SettingsKey.sound.asString) ?? DefaultSettings.get<bool>(SettingsKey.sound)) {
      _playSound();
    }
    if (prefs.getBool(SettingsKey.visualEffect.asString) ?? DefaultSettings.get<bool>(SettingsKey.visualEffect)) {
      _triggerVisualEffect();
    }

    if (penaltyTime <= 0) return; // No penalty time set

    setState(() {
      _isPenaltyActive = true;
      _isDeLoading = false;
      _progress = 0.0;
    });

    _animationController?.stop();

    // End penalty after specified time
    Future.delayed(Duration(milliseconds: penaltyTime), () {
      if (mounted) {
        setState(() {
          _isPenaltyActive = false;
        });
      }
    });
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
                backgroundColor: barBgColor,
                valueColor: AlwaysStoppedAnimation<Color>(barFgColor!),
                minHeight: 10.0,
                borderRadius: BorderRadius.circular(4.0),
              ),
            ),
            const SizedBox(height: 15),
            Text(
              '${(_progress * 100).toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: _isPenaltyActive ? Colors.grey : null),
            ),
            const SizedBox(height: 30),
            Text(
              _isPenaltyActive
                  ? 'Status: Penalty Active (UI Frozen)'
                  : (_isDeLoading)
                  ? 'Status: De-Loading...'
                  : 'Status: Ready',
              style: TextStyle(fontStyle: FontStyle.italic, color: _isPenaltyActive ? Colors.red : Colors.grey),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 100,
              height: 70,
              child: ElevatedButton(
                onPressed: _isPenaltyActive ? null : _buttonPressed,
                autofocus: true,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(0)),
                child: const Icon(Icons.play_arrow, size: 48),
              ),
            ),
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
                  // Create controllers for text fields
                  final hitzoneBeforeController = TextEditingController(
                    text: dialogSettings[SettingsKey.hitzoneBefore].toString(),
                  );
                  final hitzoneAfterController = TextEditingController(
                    text: dialogSettings[SettingsKey.hitzoneAfter].toString(),
                  );
                  final durationBaseController = TextEditingController(
                    text: dialogSettings[SettingsKey.durationBase].toString(),
                  );
                  final durationRandomnessController = TextEditingController(
                    text: dialogSettings[SettingsKey.durationRandomness].toString(),
                  );
                  final penaltyTimeController = TextEditingController(
                    text: dialogSettings[SettingsKey.penaltyTime].toString(),
                  );

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
                                controller: hitzoneBeforeController,
                                keyboardType: TextInputType.number,
                                onChanged: (val) => dialogSettings[SettingsKey.hitzoneBefore] =
                                    int.tryParse(val) ?? dialogSettings[SettingsKey.hitzoneBefore],
                              ),
                            ),
                          ),
                          ListTile(
                            title: const Text('Hitzone After (ms)'),
                            trailing: SizedBox(
                              width: 80,
                              child: TextFormField(
                                controller: hitzoneAfterController,
                                keyboardType: TextInputType.number,
                                onChanged: (val) => dialogSettings[SettingsKey.hitzoneAfter] =
                                    int.tryParse(val) ?? dialogSettings[SettingsKey.hitzoneAfter],
                              ),
                            ),
                          ),
                          ListTile(
                            title: const Text('Duration Base (ms)'),
                            trailing: SizedBox(
                              width: 80,
                              child: TextFormField(
                                controller: durationBaseController,
                                keyboardType: TextInputType.number,
                                onChanged: (val) => dialogSettings[SettingsKey.durationBase] =
                                    int.tryParse(val) ?? dialogSettings[SettingsKey.durationBase],
                              ),
                            ),
                          ),
                          ListTile(
                            title: const Text('Duration Randomness (ms)'),
                            trailing: SizedBox(
                              width: 80,
                              child: TextFormField(
                                controller: durationRandomnessController,
                                keyboardType: TextInputType.number,
                                onChanged: (val) => dialogSettings[SettingsKey.durationRandomness] =
                                    int.tryParse(val) ?? dialogSettings[SettingsKey.durationRandomness],
                              ),
                            ),
                          ),
                          ListTile(
                            title: const Text('Penalty Time (ms)'),
                            trailing: SizedBox(
                              width: 80,
                              child: TextFormField(
                                controller: penaltyTimeController,
                                keyboardType: TextInputType.number,
                                onChanged: (val) => dialogSettings[SettingsKey.penaltyTime] =
                                    int.tryParse(val) ?? dialogSettings[SettingsKey.penaltyTime],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => setState(() {
                          // Reset all settings to default values
                          for (var key in SettingsKey.values) {
                            dialogSettings[key] = DefaultSettings.values[key];
                          }
                          // Update text field controllers
                          hitzoneBeforeController.text = DefaultSettings.values[SettingsKey.hitzoneBefore].toString();
                          hitzoneAfterController.text = DefaultSettings.values[SettingsKey.hitzoneAfter].toString();
                          durationBaseController.text = DefaultSettings.values[SettingsKey.durationBase].toString();
                          durationRandomnessController.text = DefaultSettings.values[SettingsKey.durationRandomness]
                              .toString();
                          penaltyTimeController.text = DefaultSettings.values[SettingsKey.penaltyTime].toString();
                        }),
                        child: const Text('Reset to Defaults'),
                      ),
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
