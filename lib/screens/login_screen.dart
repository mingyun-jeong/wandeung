import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // 로고 영역
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.terrain_rounded,
                  size: 40,
                  color: colorScheme.onPrimary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '완등',
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.primary,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '나의 클라이밍 기록',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface.withOpacity(0.45),
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(flex: 3),
              // 로그인 버튼
              authState.isLoading
                  ? const CircularProgressIndicator()
                  : FilledButton.icon(
                      onPressed: () =>
                          ref.read(authProvider.notifier).signInWithGoogle(),
                      icon: const Icon(Icons.login_rounded, size: 20),
                      label: const Text(
                        'Google로 시작하기',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
              if (authState.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    '로그인 실패: ${authState.error}',
                    style: TextStyle(color: colorScheme.error, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
