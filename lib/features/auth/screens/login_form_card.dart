part of 'login_screen.dart';

extension _LoginFormCard on _LoginScreenState {
  Widget _buildLoginCard(LoginState state) {
    // Fixed white card in bottom 55%
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E1E2E)
              : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Color(0x30000000),
              blurRadius: 8,
              offset: Offset(0, -5),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).padding.bottom +
              24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Добро пожаловать',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : AppColors.darkBlue,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Войдите в аккаунт курьера',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white60
                          : AppColors.grayBlue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildField(
              controller: _emailController,
              label: 'Email',
              hint: 'courier@buzhor.ru',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              focused: state.phoneFocused,
              onFocus: (v) =>
                  ref.read(loginStateProvider.notifier).setPhoneFocused(v),
            ),
            const SizedBox(height: 16),
            _buildField(
              controller: _passwordController,
              label: 'Пароль',
              hint: '••••••••',
              icon: Icons.lock_outline_rounded,
              obscure: state.obscurePassword,
              focused: state.passFocused,
              onFocus: (v) =>
                  ref.read(loginStateProvider.notifier).setPassFocused(v),
              suffix: GestureDetector(
                onTap: ref
                    .read(loginStateProvider.notifier)
                    .toggleObscurePassword,
                child: Icon(
                  state.obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: const Color(0xFF6B8CAE),
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: state.isLoading
                  ? null
                  : () async {
                      final loginNotifier = ref.read(
                        loginStateProvider.notifier,
                      );
                      loginNotifier.setLoading(true);
                      final nav = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      final result = await ref
                          .read(authRepositoryProvider)
                          .signIn(
                            email: _emailController.text,
                            password: _passwordController.text,
                          );
                      if (!mounted) return;
                      loginNotifier.setLoading(false);
                      if (!result.isSuccess) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(result.errorMessage!)),
                        );
                        return;
                      }
                      await ref
                          .read(authCredentialsStorageProvider)
                          .saveEmail(_emailController.text.trim());
                      ref.invalidate(backendAppConfigProvider);
                      nav.pushReplacement(
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                      );
                    },
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE8720C), Color(0xFFFF9A3C)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE8720C).withValues(alpha: 0.45),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: state.isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Войти',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Бужор · Анапа',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.38)
                    : const Color(0xFF6B8CAE).withValues(alpha: 0.6),
                fontSize: 11,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
