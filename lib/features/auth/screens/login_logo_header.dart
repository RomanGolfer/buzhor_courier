part of 'login_screen.dart';

extension _LoginLogoHeader on _LoginScreenState {
  Widget _buildLogoHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: MediaQuery.of(context).size.height * 0.45,
      child: SafeArea(
        bottom: false,
        child: FadeTransition(
          opacity: _logoFade,
          child: ScaleTransition(
            scale: _logoScale,
            child: Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Column(
                children: [
                  Image.asset(
                    'assets/buzhor_logo_transparent.png',
                    width: 240,
                    height: 130,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 30,
                        height: 1,
                        color: const Color(0xFF5BB8F5).withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'КУРЬЕРСКОЕ ПРИЛОЖЕНИЕ',
                        style: TextStyle(
                          color: Color(0xFF5BB8F5),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.5,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 30,
                        height: 1,
                        color: const Color(0xFF5BB8F5).withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
