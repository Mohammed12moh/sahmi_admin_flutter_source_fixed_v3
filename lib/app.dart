import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens.dart';

const bg = Color(0xFF0A0E27);
const surface = Color(0xFF151A35);
const adminRed = Color(0xFFE63946);
const gold = Color(0xFFFFD700);
const success = Color(0xFF00D09C);

final supabase = Supabase.instance.client;
final routerProvider = Provider<GoRouter>((ref) => GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/', builder: (_, __) => const AdminShell()),
  ],
  redirect: (context, state) {
    final loggedIn = supabase.auth.currentSession != null;
    if (!loggedIn && state.matchedLocation != '/login') return '/login';
    if (loggedIn && state.matchedLocation == '/login') return '/';
    return null;
  },
));

class SahmiAdminApp extends ConsumerWidget {
  const SahmiAdminApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    debugShowCheckedModeBanner: false,
    routerConfig: ref.watch(routerProvider),
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        primary: adminRed, secondary: gold, surface: surface,
        error: Color(0xFFFF6B6B),
      ),
      textTheme: GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(backgroundColor: surface, elevation: 0),
      cardTheme: CardThemeData(color: surface, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
      ),
    ),
  );
}
