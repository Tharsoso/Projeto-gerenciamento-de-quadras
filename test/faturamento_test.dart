import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:gqt/admin/faturamento_page.dart';
import 'package:gqt/admin/faturamento_repositorio.dart';
import 'package:gqt/admin/quadras_repositorio.dart';
import 'package:gqt/app.dart';
import 'package:gqt/auth/autenticacao.dart';
import 'package:gqt/formatos.dart';

final hoje = DateTime(2030, 1, 20);

/// Locação confirmada ou cancelada, para o falso somar como o banco.
class Locacao {
  const Locacao(this.data, this.valor, {this.telefone = '31999990000', this.cancelada = false});

  final DateTime data;
  final double valor;
  final String telefone;
  final bool cancelada;
}

class FaturamentoFalso implements FaturamentoRepositorio {
  FaturamentoFalso({this.locacoes = const [], this.falha});

  final List<Locacao> locacoes;
  FalhaQuadra? falha;
  final pedidos = <(DateTime, DateTime, String?)>[];

  Iterable<Locacao> _filtrar(DateTime i, DateTime f, String? tel) => locacoes.where((l) =>
      !l.data.isBefore(i) && !l.data.isAfter(f) && (tel == null || l.telefone == tel));

  @override
  Future<ResumoFaturamento> resumo(DateTime inicio, DateTime fim, {String? telefone}) async {
    pedidos.add((inicio, fim, telefone));
    if (falha != null) throw falha!;
    final l = _filtrar(inicio, fim, telefone);
    final confirmadas = l.where((x) => !x.cancelada);
    return ResumoFaturamento(
      locacoes: confirmadas.length,
      faturamento: confirmadas.fold(0, (s, x) => s + x.valor),
      canceladas: l.where((x) => x.cancelada).length,
    );
  }

  @override
  Future<Map<DateTime, double>> porDia(DateTime inicio, DateTime fim, {String? telefone}) async {
    if (falha != null) throw falha!;
    final soma = <DateTime, double>{};
    for (final l in _filtrar(inicio, fim, telefone).where((x) => !x.cancelada)) {
      soma[l.data] = (soma[l.data] ?? 0) + l.valor;
    }
    return soma;
  }
}

Future<void> abrir(WidgetTester tester, FaturamentoFalso repo,
    {VoidCallback? aoSessaoExpirada, Size tamanho = const Size(1200, 1600)}) async {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    supportedLocales: const [Locale('pt', 'BR')],
    locale: const Locale('pt', 'BR'),
    home: FaturamentoPage(repositorio: repo, hoje: hoje, aoSessaoExpirada: aoSessaoExpirada),
  ));
  await tester.pumpAndSettle();
}

String texto(WidgetTester tester, String chave) =>
    tester.widget<Text>(find.byKey(Key(chave))).data!;

final locacoes = [
  Locacao(DateTime(2030, 1, 3), 80),
  Locacao(DateTime(2030, 1, 3), 100),
  Locacao(DateTime(2030, 1, 10), 1200),
  Locacao(DateTime(2030, 1, 12), 80, cancelada: true),
  Locacao(DateTime(2030, 1, 15), 90, telefone: '21988887777'),
  Locacao(DateTime(2029, 12, 28), 500), // fora do período inicial
];

void main() {
  testWidgets('mostra locações, faturamento e canceladas do mês (H12)', (tester) async {
    await abrir(tester, FaturamentoFalso(locacoes: locacoes));

    expect(texto(tester, 'faturamento-locacoes'), '4');
    expect(texto(tester, 'faturamento-total'), 'R\$ 1.470,00');
    expect(texto(tester, 'faturamento-canceladas'), '1');
  });

  testWidgets('período inicial vai do dia 1º do mês até hoje', (tester) async {
    final repo = FaturamentoFalso();
    await abrir(tester, repo);

    expect(repo.pedidos.single.$1, DateTime(2030, 1, 1));
    expect(repo.pedidos.single.$2, hoje);
  });

  testWidgets('gráfico soma por dia e destaca o maior dia', (tester) async {
    await abrir(tester, FaturamentoFalso(locacoes: locacoes));

    // 20 dias no período: uma coluna por dia, com o valor no tooltip.
    expect(find.byKey(const Key('faturamento-dia-3-1')), findsOneWidget);
    expect(find.byTooltip('03/01/2030 · R\$ 180,00'), findsOneWidget);
    expect(find.byTooltip('12/01/2030 · R\$ 0,00'), findsOneWidget); // cancelada não soma
    expect(texto(tester, 'faturamento-maior-dia'), 'R\$ 1.200,00');
  });

  testWidgets('colunas apoiadas na linha do zero e na escala do eixo', (tester) async {
    await abrir(tester, FaturamentoFalso(locacoes: locacoes));

    // Maior dia R$ 1.200 -> eixo vai até R$ 2.000 em 4 linhas (0, 500, ..., 2.000).
    final zero = tester.getTopLeft(find.byKey(const Key('faturamento-grade-0'))).dy;
    final topo = tester.getTopLeft(find.byKey(const Key('faturamento-grade-4'))).dy;
    final barra = find.byKey(const Key('faturamento-barra-10-1'));

    expect(tester.getBottomLeft(barra).dy, moreOrLessEquals(zero, epsilon: 1));
    expect(tester.getSize(barra).height, moreOrLessEquals((zero - topo) * 1200 / 2000, epsilon: 1));
    expect(find.text('R\$ 2.000'), findsOneWidget);
  });

  testWidgets('a tabela mostra os mesmos valores do gráfico', (tester) async {
    await abrir(tester, FaturamentoFalso(locacoes: locacoes));

    await tester.tap(find.byKey(const Key('faturamento-alternar-tabela')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('faturamento-tabela')), findsOneWidget);
    expect(find.text('R\$ 180,00'), findsOneWidget);
    expect(find.text('R\$ 1.200,00'), findsOneWidget);
  });

  testWidgets('filtra por telefone completo', (tester) async {
    final repo = FaturamentoFalso(locacoes: locacoes);
    await abrir(tester, repo);

    await tester.enterText(find.byKey(const Key('faturamento-telefone')), '(21) 98888-7777');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(repo.pedidos.last.$3, '21988887777');
    expect(texto(tester, 'faturamento-total'), 'R\$ 90,00');
  });

  testWidgets('telefone incompleto avisa e não consulta', (tester) async {
    final repo = FaturamentoFalso();
    await abrir(tester, repo);

    await tester.enterText(find.byKey(const Key('faturamento-telefone')), '3199');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(repo.pedidos, hasLength(1));
    expect(find.text('Use o telefone completo: DDD + 9 + 8 dígitos.'), findsOneWidget);
  });

  testWidgets('sem locações mostra o aviso no lugar do gráfico', (tester) async {
    await abrir(tester, FaturamentoFalso());

    expect(texto(tester, 'faturamento-total'), 'R\$ 0,00');
    expect(find.byKey(const Key('faturamento-grafico-vazio')), findsOneWidget);
  });

  testWidgets('período invertido não consulta e avisa', (tester) async {
    final repo = FaturamentoFalso();
    await abrir(tester, repo);

    await tester.tap(find.byKey(const Key('faturamento-de')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '25/01/2030');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(repo.pedidos, hasLength(1));
    expect(
      find.text('Período inválido: a data inicial precisa ser anterior ou igual à final.'),
      findsOneWidget,
    );
  });

  testWidgets('período longo mostra só os últimos 62 dias no gráfico', (tester) async {
    final repo = FaturamentoFalso(locacoes: locacoes);
    await abrir(tester, repo);

    await tester.tap(find.byKey(const Key('faturamento-de')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '01/06/2029');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(texto(tester, 'faturamento-titulo-grafico'),
        'Faturamento por dia · últimos 62 dias do período');
    expect(texto(tester, 'faturamento-total'), 'R\$ 1.970,00'); // o total usa o período todo
  });

  testWidgets('erro de conexão mostra a mensagem e deixa tentar de novo', (tester) async {
    final repo = FaturamentoFalso(
        locacoes: locacoes, falha: const FalhaQuadra('Não foi possível conectar.'));
    await abrir(tester, repo);
    expect(find.text('Não foi possível conectar.'), findsOneWidget);

    repo.falha = null;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(texto(tester, 'faturamento-locacoes'), '4');
  });

  testWidgets('sessão expirada manda para o login', (tester) async {
    var expirou = false;
    await abrir(
      tester,
      FaturamentoFalso(falha: const FalhaQuadra('Sessão expirada.', sessaoExpirada: true)),
      aoSessaoExpirada: () => expirou = true,
    );

    expect(expirou, isTrue);
  });

  testWidgets('cabe na tela de um celular sem estourar', (tester) async {
    await abrir(tester, FaturamentoFalso(locacoes: locacoes), tamanho: const Size(360, 800));

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('faturamento-total')), findsOneWidget);
  });

  testWidgets('card Faturamento do painel abre o relatório', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(App(auth: _Logado(), faturamento: FaturamentoFalso()));
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/admin');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('painel-faturamento')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('faturamento-total')), findsOneWidget);
  });

  test('erros do banco: período inválido e falta de login', () {
    final periodo = traduzirErroFaturamento(const PostgrestException(
      message: 'A data inicial deve ser anterior ou igual à final.',
      code: 'P0001',
      hint: 'PERIODO_INVALIDO',
    ));
    final login = traduzirErroFaturamento(const PostgrestException(
      message: 'Acesso restrito ao proprietário.',
      code: 'P0001',
      hint: 'NAO_AUTORIZADO',
    ));

    expect(periodo.codigo, 'PERIODO_INVALIDO');
    expect(login.sessaoExpirada, isTrue);
  });

  test('valores em reais com separador de milhar', () {
    expect(formatarReal(80), 'R\$ 80,00');
    expect(formatarReal(1470), 'R\$ 1.470,00');
    expect(formatarReal(1234567.5), 'R\$ 1.234.567,50');
  });
}

class _Logado extends ChangeNotifier implements Autenticacao {
  @override
  bool get logado => true;

  @override
  Future<void> entrar({required String email, required String senha}) async {}

  @override
  Future<void> sair() async {}
}
