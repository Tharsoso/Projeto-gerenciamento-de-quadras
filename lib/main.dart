import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'auth/autenticacao.dart';

// Passados no build: --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
    throw StateError(
      'Faltam SUPABASE_URL e SUPABASE_ANON_KEY. Rode com '
      '--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=... (veja o README).',
    );
  }
  await Supabase.initialize(url: _supabaseUrl, publishableKey: _supabaseAnonKey);
  runApp(App(auth: SupabaseAutenticacao(Supabase.instance.client.auth)));
}
