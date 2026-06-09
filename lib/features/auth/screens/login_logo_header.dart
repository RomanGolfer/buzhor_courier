part of 'login_screen.dart';

extension _LoginLogoHeader on _LoginScreenState {
  Widget _buildLogoHeader() {
    final mediaQuery = MediaQuery.of(context);
    final keyboardVisible = mediaQuery.viewInsets.bottom > 0;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      top: keyboardVisible ? -44 : 0,
      left: 0,
      right: 0,
      height: mediaQuery.size.height * (keyboardVisible ? 0.38 : 0.5),
      child: SafeArea(
        bottom: false,
        child: FadeTransition(
          opacity: _logoFade,
          child: ScaleTransition(
            scale: _logoScale,
            child: ClipRect(
              child: Padding(
                padding: EdgeInsets.only(top: keyboardVisible ? 28 : 96),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/buzhor_logo_transparent.png',
                      width: keyboardVisible ? 220 : 240,
                      height: keyboardVisible ? 118 : 130,
                      fit: BoxFit.contain,
                    ),
                    SizedBox(height: keyboardVisible ? 10 : 20),
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
      ),
    );
  }
}
