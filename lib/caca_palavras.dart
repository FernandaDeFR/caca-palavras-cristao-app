import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'progresso.dart';
import 'paleta.dart';
import 'conclusao.dart';

typedef Celula = (int, int);

class Palavra {
  final String texto;
  final Celula inicio;
  final Celula fim;
  Palavra(Map<String, dynamic> json)
      : texto = json['palavra'] as String,
        inicio = ((json['inicio'] as List)[0] as int, (json['inicio'] as List)[1] as int),
        fim = ((json['fim'] as List)[0] as int, (json['fim'] as List)[1] as int);

  bool corresponde(Celula a, Celula b) =>
      (a == inicio && b == fim) || (a == fim && b == inicio);
}

class Etapa {
  final String id;
  final String livro;
  final int numero;
  final String tema;
  final bool ultimaDoLivro;
  final String dificuldade;
  String get assinatura => jsonEncode([dificuldade, grid,
      palavras.map((p) => [p.texto, p.inicio.$1, p.inicio.$2, p.fim.$1, p.fim.$2]).toList()]);
  final int quantidade;
  final List<List<String>> grid;
  final List<Palavra> palavras;
  Etapa(String livroId, this.livro, Map<String, dynamic> json,
      {this.ultimaDoLivro = false})
      : dificuldade = (json['dificuldade'] as String?) ?? 'nivel_1',
        numero = json['etapa'] as int,
        id = '$livroId/${json['etapa']}',
        tema = (json['tema'] ?? json['salmo'] ?? json['proverbio'] ??
            'Etapa ${json['etapa']}') as String,
        quantidade = json['qtd_palavras'] as int,
        grid = (json['grid'] as List).map((linha) =>
            (linha as String).runes.map(String.fromCharCode).toList()).toList(),
        palavras = (json['solucao'] as List).map((p) =>
            Palavra(Map<String, dynamic>.from(p as Map))).toList() {
    if (quantidade <= 0 || quantidade != palavras.length || grid.isEmpty ||
        grid.first.isEmpty || grid.any((linha) => linha.length != grid.first.length)) {
      throw FormatException('Etapa inválida: $id');
    }
  }
}

class Livro {
  final String nome;
  final String testamento;
  final List<Etapa> etapas;
  Livro(Map<String, dynamic> json)
      : nome = json['nome'] as String,
        testamento = json['testamento'] as String,
        etapas = (json['etapas'] as List).map((e) => Etapa(
          json['id'] as String, json['nome'] as String,
          Map<String, dynamic>.from(e as Map),
          ultimaDoLivro: e['etapa'] == (json['etapas'] as List)
              .map((item) => item['etapa'] as int).reduce(math.max),
        )).toList();
}

Future<List<Livro>> carregarLivros() async {
  final json = jsonDecode(await rootBundle.loadString('caca_palavras.json'))
      as Map<String, dynamic>;
  return (json['livros'] as List)
      .map((l) => Livro(Map<String, dynamic>.from(l as Map))).toList();
}

class CacaPalavrasPage extends StatefulWidget {
  final Etapa etapa;
  const CacaPalavrasPage({super.key, required this.etapa});
  @override
  State<CacaPalavrasPage> createState() => _CacaPalavrasPageState();
}

class _CacaPalavrasPageState extends State<CacaPalavrasPage> with WidgetsBindingObserver {
  final _progresso = Progresso.instancia;
  final _relogio = Stopwatch();
  Timer? _ticker;
  int _acumulado = 0;
  int _ticks = 0;
  bool _tempoValido = true;
  bool _suspenso = false;
  bool _saindo = false;
  bool _conclusaoPendente = false;
  bool _resultadoAberto = false;
  int _talentosGanhos = 0;
  int get _tempoMs => _acumulado + _relogio.elapsedMilliseconds;
  Set<int> _encontradas = {};
  Set<String> _letrasReveladas = {};
  Celula? _inicio;
  Celula? _fim;
  bool _carregando = true;
  bool _salvando = false;
  String? _erro;
  String? _erroSalvar;
  bool get _concluida => _encontradas.length == widget.etapa.quantidade;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _carregar();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_relogio.isRunning) return;
      setState(() {});
      if (++_ticks % 5 == 0) unawaited(_checkpoint());
    });
  }

  void _retomar() {
    final estado = WidgetsBinding.instance.lifecycleState;
    if (!_carregando && _erro == null && !_concluida && !_suspenso && !_saindo &&
        (estado == null || estado == AppLifecycleState.resumed)) {
      _relogio.start();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _retomar();
    } else {
      _relogio.stop();
      unawaited(_checkpoint());
    }
  }

  Future<int> _gravar() => _progresso.salvarEtapa(
    id: widget.etapa.id, assinatura: widget.etapa.assinatura, livro: widget.etapa.livro,
    numero: widget.etapa.numero, tema: widget.etapa.tema,
    quantidade: widget.etapa.quantidade, palavras: Set.of(_encontradas),
    tempoMs: _tempoMs, tempoValido: _tempoValido,
    letrasReveladas: Set.of(_letrasReveladas),
  );

  Future<void> _checkpoint() async {
    if (_carregando || _erro != null || _salvando || _suspenso || _concluida) return;
    try { await _gravar(); }
    catch (_) {
      if (mounted) setState(() => _erroSalvar = 'Não foi possível salvar. Tente novamente.');
    }
  }

  Future<void> _sair() async {
    if (_saindo || _salvando || _suspenso) return;
    _saindo = true;
    _relogio.stop();
    if (!_carregando && _erro == null) {
      await _salvar();
      if (!mounted) return;
      if (_erroSalvar != null) { _saindo = false; _retomar(); return; }
    }
    if (!mounted) return;
    // Libera o PopScope antes de remover a rota.
    setState(() => _podeSair = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  bool _podeSair = false;

  @override
  void dispose() {
    _relogio.stop();
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final dados = await _progresso.lerEtapa(widget.etapa.id, assinatura: widget.etapa.assinatura);
      final indices = (dados['palavras'] as List).cast<int>()
          .where((i) => i >= 0 && i < widget.etapa.quantidade).toSet();
      if (!mounted) return;
      setState(() {
        _encontradas = indices;
        _letrasReveladas = ((dados['letrasReveladas'] as List?) ?? []).cast<String>().toSet();
        _acumulado = (dados['tempoMs'] as int?) ?? 0;
        _tempoValido = dados['tempoValido'] != false;
        _carregando = false; _erro = null;
      });
      if (_concluida) { await _salvar(); }
      else { _retomar(); }
    } catch (_) {
      if (mounted) setState(() { _carregando = false; _erro = 'Não foi possível carregar seu progresso.'; });
    }
  }

  Future<void> _salvar() async {
    setState(() { _salvando = true; _erroSalvar = null; });
    try {
      final credito = await _gravar();
      _talentosGanhos += credito;
    } catch (_) {
      if (mounted) setState(() => _erroSalvar = 'Não foi possível salvar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
    _abrirConclusao();
  }

  void _abrirConclusao() {
    if (!mounted || !_conclusaoPendente || !_concluida ||
        _erroSalvar != null || _resultadoAberto || _saindo) {
      return;
    }
    _resultadoAberto = true;
    _relogio.stop();
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(builder: (_) => ConclusaoPage(
        livro: widget.etapa.livro,
        ultimaDoLivro: widget.etapa.ultimaDoLivro,
        talentos: _talentosGanhos,
        tempoMs: _tempoMs,
      )),
    );
  }

  Celula? _celula(Offset p, double tamanho) {
    final colunas = widget.etapa.grid.first.length;
    final linhas = widget.etapa.grid.length;
    final c = (p.dx / tamanho).floor();
    final l = (p.dy / tamanho).floor();
    if (l < 0 || c < 0 || l >= linhas || c >= colunas) return null;
    return (l, c);
  }

  bool _reta(Celula a, Celula b) {
    final dl = (a.$1 - b.$1).abs();
    final dc = (a.$2 - b.$2).abs();
    return dl == 0 || dc == 0 || dl == dc;
  }

  Future<void> _confirmar() async {
    final a = _inicio;
    final b = _fim;
    setState(() { _inicio = null; _fim = null; });
    if (a == null || b == null || !_reta(a, b)) return;
    final indice = widget.etapa.palavras.indexWhere((p) => p.corresponde(a, b));
    if (indice < 0 || _encontradas.contains(indice)) return;
    setState(() => _encontradas.add(indice));
    if (_concluida) {
      _relogio.stop();
      _conclusaoPendente = true;
    }
    await _salvar();
    if (!mounted || !_concluida || _erroSalvar != null) return;

  }

  String _posicao(Celula c) => '${c.$1},${c.$2}';

  bool _estaEncontrada(Celula c) {
    for (final i in _encontradas) {
      final p = widget.etapa.palavras[i];
      final dl = p.fim.$1 - p.inicio.$1;
      final dc = p.fim.$2 - p.inicio.$2;
      final passos = math.max(dl.abs(), dc.abs());
      for (var k = 0; k <= passos; k++) {
        if ((p.inicio.$1 + dl.sign * k, p.inicio.$2 + dc.sign * k) == c) return true;
      }
    }
    return false;
  }

  Future<void> _abrirDicas() async {
    if (_carregando || _salvando || _suspenso || _saindo || _concluida) {
      return;
    }
    _relogio.stop();
    setState(() { _suspenso = true; _inicio = null; _fim = null; });
    final temLetra = widget.etapa.palavras.asMap().entries.any((item) =>
      !_encontradas.contains(item.key) &&
      !_letrasReveladas.contains(_posicao(item.value.inicio)) &&
      !_estaEncontrada(item.value.inicio));
    final podeLetra = temLetra && _progresso.talentos >= 3;
    final podePalavra = _progresso.paes >= 7;
    bool? escolha;
    try {
      escolha = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Dica!'),
          content: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Revelar uma letra?', style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Destaca a primeira letra de uma palavra ainda não encontrada.'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: podeLetra ? () => Navigator.pop(context, false) : null,
                child: const Text('Custa 3 talentos'),
              ),
              if (!temLetra)
                const Text('As primeiras letras restantes já estão destacadas.')
              else if (!podeLetra)
                const Text('Talentos insuficientes.'),
              const SizedBox(height: 20),
              const Text('Revelar uma palavra inteira?', style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Encontra e destaca uma palavra completa.'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: podePalavra ? () => Navigator.pop(context, true) : null,
                child: const Text('Custa 7 pães diários'),
              ),
              if (!podePalavra) const Text('Pães diários insuficientes.'),
            ],
          )),
          actions: [TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          )],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _suspenso = false);
      }
    }
    if (!mounted) {
      return;
    }
    if (escolha != null) {
      await _usarDica(escolha);
    }
    if (mounted) {
      _retomar();
    }
  }

  Future<void> _usarDica(bool palavraInteira) async {
    if (_carregando || _salvando || _suspenso || _saindo || _concluida) return;
    final candidatas = <int>[];
    for (var i = 0; i < widget.etapa.palavras.length; i++) {
      final inicio = widget.etapa.palavras[i].inicio;
      if (!_encontradas.contains(i) && (palavraInteira ||
          (!_letrasReveladas.contains(_posicao(inicio)) && !_estaEncontrada(inicio)))) {
        candidatas.add(i);
      }
    }
    if (candidatas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('As primeiras letras restantes já estão destacadas.'),
      ));
      return;
    }
    final saldo = palavraInteira ? _progresso.paes : _progresso.talentos;
    final preco = palavraInteira ? 7 : 3;
    if (saldo < preco) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        palavraInteira ? 'Você precisa de 7 pães para esta dica.' : 'Você precisa de 3 talentos para esta dica.',
      )));
      return;
    }
    _suspenso = true;
    _relogio.stop();
    setState(() { _inicio = null; _fim = null; });
    final indice = candidatas[math.Random().nextInt(candidatas.length)];
    final novasPalavras = Set<int>.of(_encontradas);
    final novasLetras = Set<String>.of(_letrasReveladas);
    if (palavraInteira) { novasPalavras.add(indice); }
    else { novasLetras.add(_posicao(widget.etapa.palavras[indice].inicio)); }
    setState(() { _salvando = true; });
    try {
      // Saldo e efeito da dica são gravados juntos; falha não entrega a dica.
      final credito = await _progresso.salvarEtapa(
        id: widget.etapa.id, assinatura: widget.etapa.assinatura, livro: widget.etapa.livro,
        numero: widget.etapa.numero, tema: widget.etapa.tema,
        quantidade: widget.etapa.quantidade, palavras: novasPalavras,
        tempoMs: _tempoMs, tempoValido: _tempoValido,
        letrasReveladas: novasLetras,
        custoTalentos: palavraInteira ? 0 : 3, custoPaes: palavraInteira ? 7 : 0,
      );
      if (!mounted) return;
      setState(() {
        _encontradas = novasPalavras; _letrasReveladas = novasLetras;
        _erroSalvar = null;
        _talentosGanhos += credito;
        if (_concluida) _conclusaoPendente = true;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Não foi possível usar a dica. Confira seu saldo e tente novamente.'),
        ));
      }
    } finally {
      if (mounted) setState(() { _salvando = false; _suspenso = false; });
    }
    if (!mounted) return;
    _abrirConclusao();
    _retomar();
  }

  @override
  Widget build(BuildContext context) {
    final etapa = widget.etapa;
    return PopScope(
      canPop: _podeSair,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_sair());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _salvando ? null : _sair),
          titleSpacing: 8,
          title: BarraProgressoEtapa(
            encontradas: _encontradas.length,
            total: etapa.quantidade,
          ),
          actions: [Padding(
            padding: const EdgeInsets.only(left: 12, right: 16),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.timer_outlined, size: 20),
              const SizedBox(width: 6),
              Text(formatarTempo(_tempoMs), style: const TextStyle(
                fontWeight: FontWeight.w600,
              )),
            ]),
          )],
        ),
        body: SafeArea(child: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_erro!), TextButton(onPressed: _carregar, child: const Text('Tentar novamente')),
              ]))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(etapa.tema,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge),
                    if (etapa.dificuldade == 'nivel_4') ...[
                      const SizedBox(height: 12),
                      Text('Encontre as ${etapa.quantidade} palavras escondidas sobre ${etapa.tema}!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18)),
                    ],
                    const SizedBox(height: 16),
                    LayoutBuilder(builder: (context, constraints) {
                      final tamanho = constraints.maxWidth / etapa.grid.first.length;
                      final altura = tamanho * etapa.grid.length;
                      return GestureDetector(
                        dragStartBehavior: DragStartBehavior.down,
                        behavior: HitTestBehavior.opaque,
                        onPanStart: _concluida || _salvando || _suspenso ? null : (d) {
                          final c = _celula(d.localPosition, tamanho);
                          setState(() { _inicio = c; _fim = c; });
                        },
                        onPanUpdate: _concluida || _salvando || _suspenso ? null : (d) {
                          setState(() => _fim = _celula(d.localPosition, tamanho));
                        },
                        onPanEnd: _concluida || _salvando || _suspenso ? null : (_) => _confirmar(),
                        onPanCancel: () => setState(() { _inicio = null; _fim = null; }),
                        child: SizedBox(width: constraints.maxWidth, height: altura,
                          child: CustomPaint(painter: _GradePainter(
                            etapa: etapa, encontradas: Set.of(_encontradas),
                            letrasReveladas: Set.of(_letrasReveladas),
                            inicio: _inicio, fim: _fim,
                          )),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    if (etapa.dificuldade != 'nivel_4')
                    Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
                      children: List.generate(etapa.palavras.length, (i) {
                        final achou = _encontradas.contains(i);
                        return Chip(
                          avatar: achou ? const Icon(Icons.check, size: 18) : null,
                          backgroundColor: Paleta.azulClaro,
                          label: Text(etapa.palavras[i].texto, style: TextStyle(
                            decoration: achou ? TextDecoration.lineThrough : null,
                          )),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    Center(child: OutlinedButton(
                      onPressed: _concluida || _salvando || _suspenso
                          ? null : _abrirDicas,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Paleta.azulEscuro,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Paleta.azulEscuro.withAlpha(100),
                        disabledForegroundColor: Colors.white70,
                        side: const BorderSide(color: Color(0xFF05548E), width: 3),
                        minimumSize: const Size(180, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Dica!', style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                    )),
                    if (_erroSalvar != null) ...[
                      Text(_erroSalvar!, textAlign: TextAlign.center),
                      TextButton(onPressed: _salvando ? null : _salvar, child: const Text('Salvar novamente')),
                    ],
                  ]),
                )),
              ),
        ),
      ),
    );
  }
}

class _GradePainter extends CustomPainter {
  final Etapa etapa;
  final Set<int> encontradas;
  final Set<String> letrasReveladas;
  final Celula? inicio;
  final Celula? fim;
  _GradePainter({required this.etapa, required this.encontradas, required this.letrasReveladas, this.inicio, this.fim});

  @override
  void paint(Canvas canvas, Size size) {
    final t = size.width / etapa.grid.first.length;
    Offset centro(Celula c) => Offset((c.$2 + .5) * t, (c.$1 + .5) * t);
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF7F9FB));
    void destacar(Celula a, Celula b, Color cor) {
      final pincel = Paint()..color = cor..strokeWidth = t * .76..strokeCap = StrokeCap.round;
      if (a == b) { canvas.drawCircle(centro(a), t * .38, pincel); }
      else { canvas.drawLine(centro(a), centro(b), pincel); }
    }
    const cores = Paleta.cores;
    for (final i in encontradas) {
      final p = etapa.palavras[i];
      destacar(p.inicio, p.fim, cores[i % cores.length].withAlpha(170));
    }
    for (final posicao in letrasReveladas) {
      final partes = posicao.split(',');
      if (partes.length != 2) continue;
      final l = int.tryParse(partes[0]);
      final c = int.tryParse(partes[1]);
      if (l == null || c == null || l < 0 || c < 0 ||
          l >= etapa.grid.length || c >= etapa.grid.first.length) {
        continue;
      }
      canvas.drawCircle(centro((l, c)), t * .37, Paint()..color = Paleta.vermelhoClaro);
      canvas.drawCircle(centro((l, c)), t * .37, Paint()
        ..color = Paleta.vermelhoEscuro..style = PaintingStyle.stroke..strokeWidth = 2);
    }
    if (inicio != null && fim != null) {
      final dl = (inicio!.$1 - fim!.$1).abs();
      final dc = (inicio!.$2 - fim!.$2).abs();
      if (dl == 0 || dc == 0 || dl == dc) destacar(inicio!, fim!, Paleta.azulClaro.withAlpha(150));
    }
    for (var l = 0; l < etapa.grid.length; l++) {
      for (var c = 0; c < etapa.grid[l].length; c++) {
        final texto = TextPainter(
          text: TextSpan(text: etapa.grid[l][c], style: TextStyle(
            color: const Color(0xFF253342), fontSize: math.min(24.0, t * .56), fontWeight: FontWeight.w600,
          )), textDirection: TextDirection.ltr,
        )..layout();
        final p = centro((l, c));
        texto.paint(canvas, p - Offset(texto.width / 2, texto.height / 2));
        texto.dispose();
      }
    }
  }
  @override
  bool shouldRepaint(covariant _GradePainter oldDelegate) => true;
}


/// Progresso real da etapa, com preenchimento animado e degradê horizontal.
class BarraProgressoEtapa extends StatelessWidget {
  final int encontradas;
  final int total;
  const BarraProgressoEtapa({super.key, required this.encontradas, required this.total});

  @override
  Widget build(BuildContext context) {
    final proporcao = total > 0 ? (encontradas / total).clamp(0.0, 1.0).toDouble() : 0.0;
    return Semantics(
      label: 'Progresso da etapa',
      value: '$encontradas de $total palavras, ${(proporcao * 100).round()} por cento',
      child: SizedBox(
        height: 22,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: DecoratedBox(
            decoration: const BoxDecoration(color: Color(0xFFE2E8ED)),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: proporcao),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              builder: (context, valor, _) => Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: valor,
                  heightFactor: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [Paleta.azulClaro, Paleta.azul, Paleta.azulEscuro],
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          height: 5,
                          margin: const EdgeInsets.fromLTRB(5, 3, 5, 0),
                          decoration: BoxDecoration(
                            color: const Color(0x40FFFFFF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
