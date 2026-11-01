import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Falha ao entrar, já com a mensagem que vai para a tela.
class FalhaLogin implements Exception {
  const FalhaLogin(this.mensagem);

  final String mensagem;

  @override
  String toString() => mensagem;
}

/// Sessão do proprietário (H7). Notifica os ouvintes sempre que ele entra ou sai,
/// para o roteador reavaliar o acesso a `/admin`.
abstract class Autenticacao implements Listenable {
  bool get logado;

  /// Lança [FalhaLogin] se não conseguir entrar.
  Future<void> entrar({required String email, required String senha});

  Future<void> sair();
}

/// Implementação com o Supabase Auth. O `supabase_flutter` guarda e renova o token
/// sozinho, aqui só repassamos as mudanças de sessão.
class SupabaseAutenticacao extends ChangeNotifier implements Autenticacao {
  SupabaseAutenticacao(this._auth) {
    _inscricao = _auth.onAuthStateChange.listen((_) => notifyListeners());
  }

  final GoTrueClient _auth;
  late final StreamSubscription<AuthState> _inscricao;

  @override
  bool get logado => _auth.currentSession != null;

  @override
  Future<void> entrar({required String email, required String senha}) async {
    try {
      await _auth.signInWithPassword(email: email.trim(), password: senha);
    } on AuthRetryableFetchException {
      throw const FalhaLogin('Não foi possível conectar. Verifique a internet e tente novamente.');
    } on AuthException {
      // Nunca dizer qual dos dois está errado (H7, alternativo 1).
      throw const FalhaLogin('E-mail ou senha inválidos');
    }
  }

  @override
  Future<void> sair() => _auth.signOut();

  @override
  void dispose() {
    _inscricao.cancel();
    super.dispose();
  }
}
