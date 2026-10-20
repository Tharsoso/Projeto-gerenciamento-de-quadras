import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'admin/painel_page.dart';
import 'auth/autenticacao.dart';
import 'auth/controle_inatividade.dart';
import 'auth/login_page.dart';
import 'publico/inicio_page.dart';

class App extends StatefulWidget {
  const App({
    super.key,
    required this.auth,
    this.limiteInatividade = limiteInatividadePadrao,
  });

  final Autenticacao auth;
  final Duration limiteInatividade;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final GoRouter _router = GoRouter(
    refreshListenable: widget.auth,
    redirect: _redirecionar,
    routes: [
      GoRoute(path: '/', builder: (context, state) => const InicioPage()),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginPage(
          auth: widget.auth,
          sessaoExpirada: state.uri.queryParameters['expirou'] == '1',
        ),
      ),
      // Tudo dentro deste ShellRoute é área administrativa: exige login e conta inatividade.
      ShellRoute(
        builder: (context, state, child) => ControleInatividade(
          limite: widget.limiteInatividade,
          aoExpirar: _expirarSessao,
          child: child,
        ),
        routes: [
          GoRoute(path: '/admin', builder: (context, state) => PainelPage(auth: widget.auth)),
        ],
      ),
    ],
  );

  String? _redirecionar(BuildContext context, GoRouterState state) {
    final local = state.matchedLocation;
    final areaAdmin = local == '/admin' || local.startsWith('/admin/');
    if (areaAdmin && !widget.auth.logado) return '/login';
    if (local == '/login' && widget.auth.logado) return '/admin';
    return null;
  }

  Future<void> _expirarSessao() async {
    await widget.auth.sair();
    _router.go('/login?expirou=1');
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Quadras de Tênis',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.green)),
      routerConfig: _router,
    );
  }
}
