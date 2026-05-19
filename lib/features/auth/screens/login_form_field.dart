part of 'login_screen.dart';

extension _LoginFormField on _LoginScreenState {
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool focused,
    required Function(bool) onFocus,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Focus(
      onFocusChange: onFocus,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? (focused ? const Color(0xFF32324E) : const Color(0xFF2A2A3E))
              : (focused ? const Color(0xFFE8F1FB) : const Color(0xFFF0F5FB)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: focused ? const Color(0xFF1B5FA8) : const Color(0xFFE0EDF8),
            width: focused ? 2 : 1.5,
          ),
        ),
        child: TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : const Color(0xFF0D3D6E),
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            hintStyle: TextStyle(
              color:
                  (Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.4)
                          : const Color(0xFF6B8CAE).withValues(alpha: 0.5))
                      .withValues(alpha: 0.5),
            ),
            labelStyle: TextStyle(
              color: focused
                  ? const Color(0xFF1B5FA8)
                  : (Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : const Color(0xFF6B8CAE)),
              fontWeight: focused ? FontWeight.w600 : FontWeight.normal,
            ),
            prefixIcon: Icon(
              icon,
              color: focused
                  ? const Color(0xFF1B5FA8)
                  : (Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : const Color(0xFF6B8CAE)),
              size: 20,
            ),
            suffixIcon: suffix != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: suffix,
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ),
    );
  }
}
