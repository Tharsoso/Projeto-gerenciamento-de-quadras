import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'app_theme.dart';
import 'auth/autenticacao.dart';
import 'screens/intro_screen.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
    runApp(const _SemSupabase());
    return;
  }
  await Supabase.initialize(url: _supabaseUrl, publishableKey: _supabaseAnonKey);
  runApp(_Entrada(auth: SupabaseAutenticacao(Supabase.instance.client.auth)));
}

/// O [App] já abre por baixo; a intro (vídeo do saque do protótipo) cobre a tela e sobe
/// no fim, revelando a home.
class _Entrada extends StatefulWidget {
  const _Entrada({required this.auth});

  final Autenticacao auth;

  @override
  State<_Entrada> createState() => _EntradaState();
}

class _EntradaState extends State<_Entrada> {
  late final App _app = App(auth: widget.auth);
  bool _introFeita = false;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _app,
          if (!_introFeita) IntroScreen(onDone: () => setState(() => _introFeita = true)),
        ],
      ),
    );
  }
}

class _SemSupabase extends StatelessWidget {
  const _SemSupabase();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const Scaffold(
        body: Center(child: Text('Supabase não configurado (env.json).')),
      ),
    );
  }
}
