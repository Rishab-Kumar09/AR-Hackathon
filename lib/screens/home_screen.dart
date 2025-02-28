import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'game_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Ensure wakelock is enabled when home screen is shown
    WakelockPlus.enable();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-enable wakelock when app is resumed
      WakelockPlus.enable();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // Disable wakelock when app is inactive or paused
      WakelockPlus.disable();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade900,
              Colors.purple.shade900,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Game title
                Text(
                  'AR Bubble Pop',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.blue.shade500,
                        blurRadius: 10,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 800.ms).slideY(
                      begin: -0.2,
                      end: 0,
                      duration: 800.ms,
                      curve: Curves.easeOutQuad,
                    ),

                const SizedBox(height: 20),

                // Game description
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    kIsWeb
                        ? 'Use your mouse to pop bubbles and score points!'
                        : 'Use your hand to pop bubbles and score points!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ).animate().fadeIn(delay: 300.ms, duration: 800.ms),

                const SizedBox(height: 20),

                // Optimal distance information
                if (!kIsWeb)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade800.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.blue.shade400, width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.info_outline, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                'Optimal Playing Distance',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'For best hand tracking results, position yourself 1.5-2 feet (45-60 cm) from your camera in a well-lit area.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 450.ms, duration: 800.ms),

                const SizedBox(height: 20),

                // Animated bubbles
                _buildAnimatedBubbles(),

                const SizedBox(height: 60),

                // Start game button
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const GameScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 5,
                    shadowColor: Colors.blue.shade800,
                  ),
                  child: const Text(
                    'Start Game',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ).animate().fadeIn(delay: 600.ms, duration: 800.ms).scaleXY(
                      begin: 0.8,
                      end: 1,
                      delay: 600.ms,
                      duration: 800.ms,
                      curve: Curves.elasticOut,
                    ),

                const SizedBox(height: 40),

                // Platform-specific instructions
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    kIsWeb
                        ? 'Running in web mode: Use your mouse to pop bubbles'
                        : 'Running in camera mode: Use your hand to pop bubbles',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ).animate().fadeIn(delay: 900.ms, duration: 800.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedBubbles() {
    return SizedBox(
      height: 100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildBubble(Colors.blue, 60, 0),
          _buildBubble(Colors.purple, 40, 200),
          _buildBubble(Colors.pink, 70, 400),
          _buildBubble(Colors.green, 50, 600),
          _buildBubble(Colors.orange, 45, 800),
        ],
      ),
    );
  }

  Widget _buildBubble(Color color, double size, int delayMs) {
    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.7),
        gradient: RadialGradient(
          colors: [
            Colors.white.withOpacity(0.7),
            color.withOpacity(0.5),
          ],
          stops: const [0.2, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Text(
          '+${(size / 10).round() * 5}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    )
        .animate(
          onPlay: (controller) => controller.repeat(),
        )
        .fadeIn(delay: Duration(milliseconds: delayMs), duration: 600.ms)
        .then()
        .moveY(
          begin: 0,
          end: -20,
          duration: 1200.ms,
          curve: Curves.easeInOut,
        )
        .then()
        .moveY(
          begin: -20,
          end: 0,
          duration: 1200.ms,
          curve: Curves.easeInOut,
        );
  }
}
