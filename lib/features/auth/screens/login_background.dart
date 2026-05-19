part of 'login_screen.dart';

extension _LoginBackground on _LoginScreenState {
  Widget _buildAnimatedBackground() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF071E3D), Color(0xFF0D3D6E), Color(0xFF1565A8)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: CustomPaint(
          painter: BubblePainter(_bubbles),
          child: Container(),
        ),
      ),
    );
  }
}
