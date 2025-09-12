import 'package:flutter/material.dart';
import 'level_selection_screen.dart';

class MenuScreen extends StatefulWidget {
  @override
  _MenuScreenState createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
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
              Color(0xFF1a1a2e),
              Color(0xFF16213e),
              Color(0xFF0f3460),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Title Section
              Expanded(
                flex: 3,
                child: Center(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Game Icon/Logo
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Color(0xFFe94560),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFFe94560).withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.directions_car,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 20),
                          // Game Title
                          Text(
                            'CAR RACING',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 3,
                              shadows: [
                                Shadow(
                                  color: Color(0xFFe94560).withOpacity(0.5),
                                  blurRadius: 10,
                                  offset: Offset(0, 5),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'GAME',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w300,
                              color: Colors.white70,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // Menu Buttons Section
              Expanded(
                flex: 2,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildMenuButton(
                        'PLAY',
                        Icons.play_arrow,
                        Color(0xFF4CAF50),
                        () => _startGame(context),
                      ),
                      SizedBox(height: 15),
                      _buildMenuButton(
                        'OPTIONS',
                        Icons.settings,
                        Color(0xFF2196F3),
                        () => _showOptions(context),
                      ),
                      SizedBox(height: 15),
                      _buildMenuButton(
                        'QUIT',
                        Icons.exit_to_app,
                        Color(0xFFe94560),
                        () => _quitGame(context),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Footer
              Expanded(
                flex: 1,
                child: Center(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      'Use WASD or Arrow Keys to play',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(String text, IconData icon, Color color, VoidCallback onPressed) {
    return Container(
      width: 250,
      height: 55,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 24),
        label: Text(
          text,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 8,
          shadowColor: color.withOpacity(0.4),
        ),
      ),
    );
  }

  void _startGame(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LevelSelectionScreen(),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color(0xFF1a1a2e),
          title: Text(
            'Options',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.volume_up, color: Color(0xFFe94560)),
                title: Text('Sound', style: TextStyle(color: Colors.white)),
                trailing: Switch(
                  value: true,
                  activeColor: Color(0xFFe94560),
                  onChanged: (bool value) {
                    // Handle sound toggle
                  },
                ),
              ),
              ListTile(
                leading: Icon(Icons.vibration, color: Color(0xFFe94560)),
                title: Text('Vibration', style: TextStyle(color: Colors.white)),
                trailing: Switch(
                  value: true,
                  activeColor: Color(0xFFe94560),
                  onChanged: (bool value) {
                    // Handle vibration toggle
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'CLOSE',
                style: TextStyle(color: Color(0xFFe94560)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _quitGame(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color(0xFF1a1a2e),
          title: Text(
            'Quit Game',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to quit?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'CANCEL',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () {
                // Close the app
                Navigator.of(context).pop();
                // You might want to use SystemNavigator.pop() here
                // but it requires import 'package:flutter/services.dart';
              },
              child: Text(
                'QUIT',
                style: TextStyle(color: Color(0xFFe94560)),
              ),
            ),
          ],
        );
      },
    );
  }
}