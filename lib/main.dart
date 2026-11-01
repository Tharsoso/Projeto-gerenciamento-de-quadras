import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin/quadras_page.dart';
import 'admin/quadras_repositorio.dart';
import 'app_theme.dart';
import 'screens/admin/login_prototipo_screen.dart';
import 'screens/admin/painel_prototipo_screen.dart';
import 'screens/public/consulta_horarios_screen.dart';
import 'screens/public/reserva_prototipo_screen.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(url: _supabaseUrl, publishableKey: _supabaseAnonKey);
  }
  runApp(const GqtApp());
}

class GqtApp extends StatelessWidget {
  const GqtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reserva de quadras',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR')],
      initialRoute: '/',
      routes: {
        '/': (_) => const ConsultaHorariosScreen(),
        '/reserva': (_) => const ReservaPrototipoScreen(),
        '/admin/login': (_) => const LoginPrototipoScreen(),
        '/admin': (_) => const PainelPrototipoScreen(),
        // 5.2. Gravar exige login (RLS): até o login da 5.1 entrar aqui, sem sessão o
        // banco só devolve as quadras ativas e recusa salvar.
        '/admin/quadras': (_) => _supabaseUrl.isEmpty
            ? const Scaffold(body: Center(child: Text('Supabase não configurado (env.json).')))
            : QuadrasPage(repositorio: SupabaseQuadrasRepositorio(Supabase.instance.client)),
      },
    );
  }
}
