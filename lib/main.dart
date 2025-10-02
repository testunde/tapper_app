import 'dart:math';
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Loading Bar App',
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
  bool _isLoading = false;
  double _progress = 1.0; // Initial state: 100% full
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
          _isLoading = false;
          // Reset progress to full (1.0) when de-loading is complete
          _progress = 1.0;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController?.dispose(); // Dispose the controller
    super.dispose();
  }

  void _startLoading() {
    // Stop any ongoing animation before starting a new one
    _animationController?.stop();

    setState(() {
      _isLoading = true;
      _progress = 1.0; // Ensure progress starts at 100% visually
    });

    // Generate a random duration between 500 ms (0.5 seconds) and 1500 ms (1.5 seconds)
    final int randomDurationMs = _random.nextInt(1001) + 500;
    _animationController!.duration = Duration(milliseconds: randomDurationMs);

    // Reset the animation controller's value to 0.0 before starting
    _animationController!.reset();
    // Start the animation, which will move from 0.0 to 1.0 over its duration
    _animationController!.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Loading Progress')),
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
              width: 350, // Fixed width for the progress bar
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
              (_isLoading) ? 'Status: De-Loading...' : 'Status: Ready',
              style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              // Disable the button while loading to prevent multiple starts
              // onPressed: _isLoading ? null : _startLoading,
              onPressed: _startLoading,
              autofocus: true,
              //tooltip: 'Start Countdown',
              child: const Icon(Icons.play_arrow),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        // Disable the button while loading to prevent multiple starts
        onPressed: _isLoading ? null : _startLoading,
        tooltip: 'Start Countdown',
        child: const Icon(Icons.play_arrow),
      ),
    );
  }
}
