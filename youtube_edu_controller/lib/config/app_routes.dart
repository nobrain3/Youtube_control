import 'package:go_router/go_router.dart';
import '../views/screens/splash_screen.dart';
import '../views/screens/onboarding_screen.dart';
import '../views/screens/login_screen.dart';
import '../views/screens/register_screen.dart';
import '../views/screens/home_screen.dart';
import '../views/screens/player_screen.dart';
import '../views/screens/question_screen.dart';
import '../views/screens/profile_screen.dart';
import '../views/screens/settings_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String player = '/player';
  static const String question = '/question';
  static const String profile = '/profile';
  static const String settings = '/settings';

  static final GoRouter router = GoRouter(
    initialLocation: splash,
    routes: [
      GoRoute(
        path: splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: register,
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: home,
        name: 'home',
        builder: (context, state) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'profile',
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: 'settings',
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '$player/:videoId',
        name: 'player',
        builder: (context, state) {
          final videoId = state.pathParameters['videoId'] ?? '';
          final videoTitle = state.uri.queryParameters['title'] ?? '';
          return PlayerScreen(
            videoId: videoId,
            videoTitle: videoTitle,
          );
        },
      ),
      GoRoute(
        path: question,
        name: 'question',
        builder: (context, state) {
          final questionData = state.extra as Map<String, dynamic>?;
          return QuestionScreen(
            questionData: questionData ?? {},
          );
        },
      ),
    ],
  );
}