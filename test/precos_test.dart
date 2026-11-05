import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:gqt/admin/precos_page.dart';
import 'package:gqt/admin/precos_repositorio.dart';
import 'package:gqt/admin/quadras_repositorio.dart';
import 'package:gqt/models/funcionamento.dart';
import 'package:gqt/models/preco.dart';
import 'package:gqt/models/quadra.dart';

const saibro1 =
    Quadra(id: 1, nome: 'Saibro 1', tipoPiso: TipoPiso.saibro, descricao: null, ativa: true);
const rapida =
    Quadra(id: 3, nome: 'Rápida 1', tipoPiso: TipoPiso.dura, descricao: null, ativa: true);

/// Seg–sex 07h–22h e sáb–dom 08h–18h (igual ao seed).
final Semana semanaSeed = {
  for (var d = 1; d <= 5; d++) d: const Intervalo(7, 22),
  0: const Intervalo(8, 18),
  6: const Intervalo(8, 18),
};

TabelaPrecos tabelaSeed() => {
      TipoDia.util: [const FaixaPreco(7, 18, 60), const FaixaPreco(18, 22, 90)],
      TipoDia.fimDeSemana: [const FaixaPreco(7, 22, 100)],
    };

/// Repositório em memória que repete as regras da `salvar_faixas_preco`.
class PrecosFalsos implements PrecosRepositorio {
  PrecosFalsos({
    Map<int, TabelaPrecos>? tabelas,
    this.reservas = const [],
    this.feriadosIso = const {},
    this.erroAoSalvar,
  }) : salvas = tabelas ?? {1: tabelaSeed()};

  final Map<int, TabelaPrecos> salvas;
  final List<ReservaComValor> reservas;
  final Set<String> feriadosIso;
  final FalhaQuadra? erroAoSalvar;
  final List<(int, TipoDia, List<FaixaPreco>)> chamadas = [];

  @override
  Future<List<Quadra>> quadras() async => [rapida, saibro1];

  @override
  Future<Map<int, Semana>> funcionamento() async => {1: semanaSeed, 3: semanaSeed};

  @override
  Future<Map<int, TabelaPrecos>> tabelas() async => {
        for (final e in salvas.entries)
          e.key: {for (final t in e.value.entries) t.key: [...t.value]},
      };

  @override
  Future<List<ReservaComValor>> reservasFuturas(int quadraId) async => reservas;

  @override
  Future<Set<String>> feriados() async => feriadosIso;

  @override
  Future<void> salvar(int quadraId, TipoDia tipo, List<FaixaPreco> faixas) async {
    if (erroAoSalvar != null) throw erroAoSalvar!;
    final v = validarFaixas(
      [for (final f in faixas) FaixaEditada(f.inicio, f.fim, textoValor(f.valor))],
      horasACobrir(semanaSeed, tipo),
    );
    if (!v.valida) throw FalhaQuadra(v.erros.first, codigo: 'FAIXA_LACUNA');
    chamadas.add((quadraId, tipo, faixas));
    salvas.putIfAbsent(quadraId, () => {TipoDia.util: [], TipoDia.fimDeSemana: []})[tipo] =
        faixas;
  }
}

Future<PrecosFalsos> abrir(WidgetTester tester, PrecosFalsos repo,
    {Size tamanho = const Size(1200, 1800), VoidCallback? aoSessaoExpirada}) async {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
      home: PrecosPage(repositorio: repo, aoSessaoExpirada: aoSessaoExpirada)));
  await tester.pumpAndSettle();
  return repo;
}

Future<void> tocar(WidgetTester tester, String chave) async {
  await tester.ensureVisible(find.byKey(Key(chave)));
  await tester.tap(find.byKey(Key(chave)));
  await tester.pumpAndSettle();
}

Future<void> escolherHora(WidgetTester tester, String chave, String hora) async {
  await tocar(tester, chave);
  await tester.tap(find.text(hora).last);
  await tester.pumpAndSettle();
}

FilledButton botaoSalvar(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(const Key('precos-salvar')));

void main() {
  group('regras (RF19)', () {
    test('lerValor aceita vírgula, ponto e milhar', () {
      expect(lerValor('60'), 60);
      expect(lerValor('60,5'), 60.5);
      expect(lerValor('90.00'), 90);
      expect(lerValor('1.234,56'), 1234.56);
      expect(lerValor('1.200'), 1200);
      expect(lerValor('R\$ 75,90'), 75.9);
      expect(lerValor(''), isNull);
      expect(lerValor('60,555'), isNull);
      expect(lerValor('abc'), isNull);
    });

    test('dia útil cobre seg–sex; fim de semana cobre todos os dias (feriado)', () {
      expect(horasACobrir(semanaSeed, TipoDia.util), {for (var h = 7; h < 22; h++) h});
      // Sáb/dom abrem 08h–18h, mas feriado numa segunda abre 07h–22h.
      expect(horasACobrir(semanaSeed, TipoDia.fimDeSemana), {for (var h = 7; h < 22; h++) h});
      expect(horasACobrir({0: const Intervalo(8, 12)}, TipoDia.util), isEmpty);
    });

    test('H4 alt. 1: 08h–18h e 17h–22h se sobrepõem entre 17h e 18h', () {
      final v = validarFaixas(
        const [FaixaEditada(8, 18, '60'), FaixaEditada(17, 22, '90')],
        {for (var h = 8; h < 22; h++) h},
      );
      expect(v.valida, isFalse);
      expect(v.sobrepostas, {17});
      expect(v.erros.single, 'As faixas 08h–18h e 17h–22h se sobrepõem.');
    });

    test('lacunas seguidas viram um aviso só', () {
      final v = validarFaixas(
        const [FaixaEditada(7, 18, '60')],
        {for (var h = 7; h < 22; h++) h},
      );
      expect(v.lacunas, {18, 19, 20, 21});
      expect(v.erros.single, startsWith('Sem preço entre 18h e 22h'));
    });

    test('valor vazio, zero e fim antes do início', () {
      final v = validarFaixas(
        const [FaixaEditada(7, 12, ''), FaixaEditada(12, 12, '0')],
        {for (var h = 7; h < 12; h++) h},
      );
      expect(v.erros, contains('Faixa 1: informe um valor maior que R\$ 0,00.'));
      expect(v.erros, contains('Faixa 2: o fim (12h) precisa ser depois do início (12h).'));
      expect(v.erros, contains('Faixa 2: informe um valor maior que R\$ 0,00.'));
    });

    test('feriado em dia útil usa a tabela de fim de semana', () {
      final segunda = DateTime(2030, 9, 9);
      expect(TipoDia.daData(segunda, {}), TipoDia.util);
      expect(TipoDia.daData(segunda, {'2030-09-09'}), TipoDia.fimDeSemana);
      expect(TipoDia.daData(DateTime(2030, 9, 14), {}), TipoDia.fimDeSemana); // sábado
    });

    test('H4 alt. 2: conta só as reservas do tipo de dia cujo preço mudaria', () {
      final reservas = [
        ReservaComValor(data: DateTime(2030, 1, 7), hora: 19, valor: 90), // seg, noturno
        ReservaComValor(data: DateTime(2030, 1, 8), hora: 20, valor: 90), // ter, noturno
        ReservaComValor(data: DateTime(2030, 1, 8), hora: 9, valor: 60), // ter, manhã
        ReservaComValor(data: DateTime(2030, 1, 12), hora: 19, valor: 100), // sábado
        ReservaComValor(data: DateTime(2030, 1, 9), hora: 19, valor: 100), // feriado
      ];
      final novas = [const FaixaPreco(7, 18, 60), const FaixaPreco(18, 22, 110)];
      expect(reservasComValorAnterior(reservas, TipoDia.util, novas, {'2030-01-09'}), 2);
    });
  });

  testWidgets('abre na primeira quadra com a tabela gravada e nada para salvar', (tester) async {
    await abrir(tester, PrecosFalsos(tabelas: {3: tabelaSeed()}));

    expect(find.text('PREÇOS POR FAIXA'), findsOneWidget);
    expect(find.byKey(const Key('faixa-0-valor')), findsOneWidget);
    expect(find.text('60,00'), findsOneWidget);
    expect(find.text('90,00'), findsOneWidget);
    expect(find.byKey(const Key('precos-ok')), findsOneWidget);
    expect(find.text('NADA PARA SALVAR'), findsOneWidget);
    expect(botaoSalvar(tester).onPressed, isNull);
  });

  testWidgets('quadra sem preço: tudo como lacuna até cadastrar', (tester) async {
    await abrir(tester, PrecosFalsos(tabelas: {}));

    expect(find.textContaining('Sem faixas'), findsOneWidget);
    expect(find.text('Sem preço entre 07h e 22h: as faixas precisam cobrir todo o horário de '
        'funcionamento.'), findsOneWidget);
  });

  testWidgets('cenário principal: cadastra 60 até 18h e 90 das 18h às 22h', (tester) async {
    final repo = await abrir(tester, PrecosFalsos(tabelas: {}));

    await tocar(tester, 'precos-quadra-1');
    await tocar(tester, 'precos-adicionar'); // 07h–22h
    await escolherHora(tester, 'faixa-0-fim', '18:00');
    await tester.enterText(find.byKey(const Key('faixa-0-valor')), '60');
    await tocar(tester, 'precos-adicionar'); // começa onde a anterior terminou
    await tester.enterText(find.byKey(const Key('faixa-1-valor')), '90');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('precos-ok')), findsOneWidget);
    await tocar(tester, 'precos-salvar');

    final (quadra, tipo, faixas) = repo.chamadas.single;
    expect(quadra, 1);
    expect(tipo, TipoDia.util);
    expect(faixas, [const FaixaPreco(7, 18, 60), const FaixaPreco(18, 22, 90)]);
    expect(find.text('Preços de dia útil da Saibro 1 salvos.'), findsOneWidget);
    expect(find.text('NADA PARA SALVAR'), findsOneWidget);
  });

  testWidgets('sobreposição desliga o salvar e aponta as horas (H4 alt. 1)', (tester) async {
    final repo = await abrir(tester, PrecosFalsos());

    await tocar(tester, 'precos-quadra-1');
    await escolherHora(tester, 'faixa-1-inicio', '17:00');

    expect(find.text('As faixas 07h–18h e 17h–22h se sobrepõem.'), findsOneWidget);
    expect(botaoSalvar(tester).onPressed, isNull);
    expect(repo.chamadas, isEmpty);
  });

  testWidgets('remover a faixa noturna mostra a lacuna', (tester) async {
    await abrir(tester, PrecosFalsos());

    await tocar(tester, 'precos-quadra-1');
    await tocar(tester, 'faixa-1-remover');

    expect(find.textContaining('Sem preço entre 18h e 22h'), findsOneWidget);
    expect(botaoSalvar(tester).onPressed, isNull);
  });

  testWidgets('subir o noturno avisa quantas reservas mantêm o valor (H4 alt. 2)',
      (tester) async {
    final reservas = [
      for (var d = 1; d <= 12; d++)
        ReservaComValor(data: DateTime(2030, 1, 7 + (d % 5)), hora: 19, valor: 90),
    ];
    final repo = await abrir(tester, PrecosFalsos(reservas: reservas));

    await tocar(tester, 'precos-quadra-1');
    await tester.enterText(find.byKey(const Key('faixa-1-valor')), '110');
    await tester.pumpAndSettle();
    await tocar(tester, 'precos-salvar');

    expect(repo.chamadas.single.$3.last, const FaixaPreco(18, 22, 110));
    expect(
        find.text('Preços de dia útil da Saibro 1 salvos. '
            '12 reservas futuras mantêm o valor anterior.'),
        findsOneWidget);
  });

  testWidgets('aba de fim de semana é separada e marca alteração pendente', (tester) async {
    final repo = await abrir(tester, PrecosFalsos());

    await tocar(tester, 'precos-quadra-1');
    await tester.enterText(find.byKey(const Key('faixa-0-valor')), '65');
    await tester.pumpAndSettle();
    await tocar(tester, 'precos-aba-fim_de_semana');

    expect(find.text('Dia útil •'), findsOneWidget); // alteração não salva na outra aba
    expect(find.text('100,00'), findsOneWidget);
    expect(find.textContaining('cobre o horário de todos os dias'), findsOneWidget);
    expect(find.text('NADA PARA SALVAR'), findsOneWidget);

    await tocar(tester, 'precos-aba-util');
    expect(find.text('65'), findsOneWidget); // a edição continua lá
    expect(repo.chamadas, isEmpty);
  });

  testWidgets('erro do banco aparece e a tabela continua na tela', (tester) async {
    await abrir(
      tester,
      PrecosFalsos(
          erroAoSalvar:
              const FalhaQuadra('O horário das 21h ficou sem preço.', codigo: 'FAIXA_LACUNA')),
    );

    await tocar(tester, 'precos-quadra-1');
    await tester.enterText(find.byKey(const Key('faixa-0-valor')), '70');
    await tester.pumpAndSettle();
    await tocar(tester, 'precos-salvar');

    expect(find.text('O horário das 21h ficou sem preço.'), findsOneWidget);
    expect(find.text('SALVAR DIA ÚTIL'), findsOneWidget);
  });

  testWidgets('sessão expirada ao salvar chama o callback', (tester) async {
    var expirou = false;
    await abrir(
      tester,
      PrecosFalsos(
          erroAoSalvar:
              const FalhaQuadra('Sua sessão expirou. Entre novamente.', sessaoExpirada: true)),
      aoSessaoExpirada: () => expirou = true,
    );

    await tocar(tester, 'precos-quadra-1');
    await tester.enterText(find.byKey(const Key('faixa-0-valor')), '70');
    await tester.pumpAndSettle();
    await tocar(tester, 'precos-salvar');

    expect(expirou, isTrue);
  });

  testWidgets('cabe em celular (360px)', (tester) async {
    await abrir(tester, PrecosFalsos(), tamanho: const Size(360, 1600));
    await tocar(tester, 'precos-quadra-1');
    expect(tester.takeException(), isNull);
    await tocar(tester, 'precos-aba-fim_de_semana');
    expect(tester.takeException(), isNull);
  });

  group('traduzirErroPreco', () {
    test('hint do banco', () {
      final f = traduzirErroPreco(const PostgrestException(
          message: 'As faixas 08h–18h e 17h–22h se sobrepõem.', hint: 'FAIXA_SOBREPOSTA'));
      expect(f.codigo, 'FAIXA_SOBREPOSTA');
      expect(f.mensagem, 'As faixas 08h–18h e 17h–22h se sobrepõem.');
    });

    test('NAO_AUTORIZADO = sessão expirada', () {
      final f = traduzirErroPreco(const PostgrestException(
          message: 'Acesso restrito ao proprietário.', hint: 'NAO_AUTORIZADO'));
      expect(f.sessaoExpirada, isTrue);
    });

    test('sem permissão = sessão expirada', () {
      final f = traduzirErroPreco(const PostgrestException(message: 'rls', code: '42501'));
      expect(f.sessaoExpirada, isTrue);
    });
  });
}
