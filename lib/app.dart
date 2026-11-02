import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin/bloqueios_page.dart';
import 'admin/bloqueios_repositorio.dart';
import 'admin/horarios_page.dart';
import 'admin/horarios_repositorio.dart';
import 'admin/painel_page.dart';
import 'admin/quadras_page.dart';
import 'admin/quadras_repositorio.dart';
import 'app_theme.dart';
import 'auth/autenticacao.dart';
import 'auth/controle_inatividade.dart';
import 'auth/login_page.dart';
import 'publico/reservas_repositorio.dart';
import 'screens/public/consulta_horarios_screen.dart';
import 'screens/public/reserva_screen.dart';
import 'screens/public/sucesso_screen.dart';

class App extends StatefulWidget {
  const App({
    super.key,
    required this.auth,
    this.limiteInatividade = limiteInatividadePadrao,
    this.quadras,
    this.reservas,
    this.horarios,
    this.bloqueios,
  });

  final Autenticacao auth;
  final Duration limiteInatividade;

  /// Acesso às quadras (5.2). Sem ele, usa o Supabase já inicializado.
  final QuadrasRepositorio? quadras;

  /// Criação de reservas (4.2). Sem ele, usa o Supabase já inicializado.
  final ReservasRepositorio? reservas;

  /// Acesso aos horários de funcionamento (5.3). Sem ele, usa o Supabase.
  final HorariosRepositorio? horarios;

  /// Bloqueios de manutenção (5.6). Sem ele, usa o Supabase.
  final BloqueiosRepositorio? bloqueios;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final GoRouter _router = GoRouter(
    refreshListenable: widget.auth,
    redirect: _redirecionar,
    routes: [
      GoRoute(path: '/', builder: (context, state) => const ConsultaHorariosScreen()),
      // Estas duas só existem vindo do fluxo: ao recarregar a página o `extra` se perde.
      GoRoute(
        path: '/reserva',
        redirect: (context, state) => state.extra is HorarioEscolhido ? null : '/',
        builder: (context, state) => ReservaScreen(
          horario: state.extra! as HorarioEscolhido,
          repositorio:
              widget.reservas ?? SupabaseReservasRepositorio(Supabase.instance.client),
        ),
      ),
      GoRoute(
        path: '/sucesso',
        redirect: (context, state) => state.extra is ReservaConfirmada ? null : '/',
        builder: (context, state) =>
            SucessoScreen(reserva: state.extra! as ReservaConfirmada),
      ),
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
          GoRoute(
            path: '/admin/quadras',
            builder: (context, state) => QuadrasPage(
              repositorio:
                  widget.quadras ?? SupabaseQuadrasRepositorio(Supabase.instance.client),
              aoVoltar: () => context.go('/admin'),
              aoSessaoExpirada: _expirarSessao,
            ),
          ),
          GoRoute(
            path: '/admin/horarios',
            builder: (context, state) => HorariosPage(
              repositorio:
                  widget.horarios ?? SupabaseHorariosRepositorio(Supabase.instance.client),
              aoVoltar: () => context.go('/admin'),
              aoSessaoExpirada: _expirarSessao,
            ),
          ),
          GoRoute(
            path: '/admin/bloqueios',
            builder: (context, state) => BloqueiosPage(
              repositorio:
                  widget.bloqueios ?? SupabaseBloqueiosRepositorio(Supabase.instance.client),
              aoVoltar: () => context.go('/admin'),
              aoSessaoExpirada: _expirarSessao,
            ),
          ),
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
      title: 'Ace Saibro · Reserva de quadras',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR')],
      routerConfig: _router,
    );
  }
}
