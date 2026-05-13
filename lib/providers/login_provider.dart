import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginState {
  final bool obscurePassword;
  final bool isLoading;
  final bool phoneFocused;
  final bool passFocused;
  final bool isExpanded;

  const LoginState({
    this.obscurePassword = true,
    this.isLoading = false,
    this.phoneFocused = false,
    this.passFocused = false,
    this.isExpanded = false,
  });

  LoginState copyWith({
    bool? obscurePassword,
    bool? isLoading,
    bool? phoneFocused,
    bool? passFocused,
    bool? isExpanded,
  }) {
    return LoginState(
      obscurePassword: obscurePassword ?? this.obscurePassword,
      isLoading: isLoading ?? this.isLoading,
      phoneFocused: phoneFocused ?? this.phoneFocused,
      passFocused: passFocused ?? this.passFocused,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }
}

class LoginStateNotifier extends StateNotifier<LoginState> {
  LoginStateNotifier() : super(const LoginState());

  void setObscurePassword(bool value) {
    state = state.copyWith(obscurePassword: value);
  }

  void toggleObscurePassword() {
    state = state.copyWith(obscurePassword: !state.obscurePassword);
  }

  void setLoading(bool value) {
    state = state.copyWith(isLoading: value);
  }

  void setPhoneFocused(bool value) {
    state = state.copyWith(phoneFocused: value);
  }

  void setPassFocused(bool value) {
    state = state.copyWith(passFocused: value);
  }

  void setExpanded(bool value) {
    state = state.copyWith(isExpanded: value);
  }
}

final loginStateProvider = StateNotifierProvider<LoginStateNotifier, LoginState>(
  (ref) => LoginStateNotifier(),
);
