import 'dart:async';
import 'progresso.dart';
import 'paleta.dart';
import 'caca_palavras.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const MeuApp());

class MeuApp extends StatelessWidget {
  const MeuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: Paleta.azul),
      ),
      home: const PaginaPrincipal(),
    );
  }
}

class PaginaPrincipal extends StatefulWidget {
  const PaginaPrincipal({super.key});

  @override
  State<PaginaPrincipal> createState() => _PaginaPrincipalState();
}

class _PaginaPrincipalState extends State<PaginaPrincipal> with WidgetsBindingObserver {
  Timer? _verificarDia;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_receberPao());
    _verificarDia = Timer.periodic(const Duration(minutes: 1), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(_receberPao());
      }
    });
  }

  Future<void> _receberPao() async {
    try { await Progresso.instancia.receberPaoDiario(); }
    catch (_) { /* A aba Conquistas mostra o erro e permite tentar novamente. */ }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_receberPao());
  }

  int aba = 0;
  late final Future<ui.Image> imagem = carregarIcones();
  static const nomes = ['Início', 'Conquistas'];

  Future<ui.Image> carregarIcones() async {
    final dados = await rootBundle.load('assets/icones_abas.png');
    final codec = await ui.instantiateImageCodec(dados.buffer.asUint8List(
      dados.offsetInBytes, dados.lengthInBytes,
    ));
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  }

  @override
  void dispose() {
    _verificarDia?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    imagem.then((valor) => valor.dispose(), onError: (Object _) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: aba,
          sizing: StackFit.expand,
          children: const [Percurso(), ConquistasPage()],
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE1E5E9))),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: List.generate(nomes.length, (i) {
                    final selecionada = aba == i;
                    return Expanded(
                      child: Semantics(
                        button: true,
                        selected: selecionada,
                        label: nomes[i],
                        child: Material(
                          color: Colors.white,
                          child: InkWell(
                            onTap: () => setState(() => aba = i),
                            borderRadius: BorderRadius.circular(14),
                            child: ExcludeSemantics(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FutureBuilder<ui.Image>(
                                    future: imagem,
                                    builder: (context, snapshot) {
                                      if (snapshot.hasError) {
                                        return const SizedBox(
                                          width: 78, height: 78,
                                          child: Icon(Icons.broken_image_outlined),
                                        );
                                      }
                                      return SizedBox(
                                        width: 78, height: 78,
                                        child: snapshot.hasData
                                            ? CustomPaint(painter: _PintorIcone(snapshot.data!, i))
                                            : const SizedBox.shrink(),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 3),
                                  Text(nomes[i], style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: selecionada ? FontWeight.w800 : FontWeight.w500,
                                    color: selecionada ? Paleta.azulEscuro : const Color(0xFF697580),
                                  )),
                                  const SizedBox(height: 5),
                                  Container(
                                    width: 32, height: 4,
                                    decoration: BoxDecoration(
                                      color: selecionada ? Paleta.azul : Colors.transparent,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PintorIcone extends CustomPainter {
  final ui.Image imagem;
  final int indice;
  _PintorIcone(this.imagem, this.indice);

  // Regiões da imagem aprovada: casa, medalha e sacola, sem os textos.
  static const recortes = [
    Rect.fromLTWH(145, 155, 470, 470),
    Rect.fromLTWH(760, 150, 470, 470),
    Rect.fromLTWH(1350, 150, 470, 470),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(imagem, recortes[indice], Offset.zero & size,
        Paint()..filterQuality = FilterQuality.high);
  }

  @override
  bool shouldRepaint(covariant _PintorIcone oldDelegate) =>
      oldDelegate.imagem != imagem || oldDelegate.indice != indice;
}

class Percurso extends StatefulWidget {
  const Percurso({super.key});
  @override
  State<Percurso> createState() => _PercursoState();
}

class _PercursoState extends State<Percurso> {
  late Future<List<Livro>> _livros = carregarLivros();
  static const cores = Paleta.cores;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Livro>>(
      future: _livros,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Não foi possível carregar as etapas.'),
            TextButton(onPressed: () {
              setState(() { _livros = carregarLivros(); });
            },
                child: const Text('Tentar novamente')),
          ]));
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final livros = snapshot.data!;
        // Itens em ordem de leitura: o reverse posiciona o início embaixo.
        final itens = <Widget>[];
        var global = 0;
        for (var livroIndice = 0; livroIndice < livros.length; livroIndice++) {
          final livro = livros[livroIndice];
          itens.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Row(children: [
              const Expanded(child: Divider(color: Color(0xFFDDE2E6))),
              Flexible(flex: 3, child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(livro.nome, textAlign: TextAlign.center, style: const TextStyle(
                  fontFamily: 'Milonga', fontSize: 23, fontWeight: FontWeight.w400, color: Color(0xFF697580),
                )),
              )),
              const Expanded(child: Divider(color: Color(0xFFDDE2E6))),
            ]),
          ));
          for (final etapa in livro.etapas) {
            final indice = global++;
            itens.add(Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Align(
                alignment: Alignment(0.55 * math.sin(indice * math.pi / 4), 0),
                child: Bolinha(
                  indiceIcone: indice % 10,
                  cor: cores[livroIndice % cores.length],
                  descricao: '${livro.nome}, etapa ${etapa.numero}: ${etapa.tema}',
                  aoClicar: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => CacaPalavrasPage(etapa: etapa)),
                  ),
                ),
              ),
            ));
          }
        }
        return Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView.builder(
            key: const PageStorageKey('percurso'), reverse: true,
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
            itemCount: itens.length,
            itemBuilder: (context, index) => itens[index],
          ),
        ));
      },
    );
  }
}

class Bolinha extends StatelessWidget {
  final int indiceIcone;
  final Color cor;
  final String descricao;
  final VoidCallback aoClicar;
  const Bolinha({super.key, required this.indiceIcone, required this.cor,
    required this.descricao, required this.aoClicar});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: descricao, button: true,
      child: Container(
        width: 78, height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          boxShadow: [BoxShadow(
            color: Color.lerp(cor, Colors.black, 0.22)!, offset: const Offset(0, 7),
          )],
        ),
        child: Material(
          color: cor,
          borderRadius: BorderRadius.circular(40),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: aoClicar,
            child: Center(child: ExcludeSemantics(
              child: IconeEtapa(indice: indiceIcone),
            )),
          ),
        ),
      ),
    );
  }
}

class IconeEtapa extends StatelessWidget {
  final int indice;
  const IconeEtapa({super.key, required this.indice});

  static final Future<_AtlasEtapas> _atlas = _carregar();

  static Future<_AtlasEtapas> _carregar() async {
    final dados = await rootBundle.load('assets/icones_etapas.png');
    final codec = await ui.instantiateImageCodec(
      dados.buffer.asUint8List(dados.offsetInBytes, dados.lengthInBytes),
    );
    try {
      final imagem = (await codec.getNextFrame()).image;
      final pixels = await imagem.toByteData(format: ui.ImageByteFormat.rawRgba);
      final recortes = <Rect>[];
      for (var indice = 0; indice < 10; indice++) {
        final x0 = ((indice % 5) * imagem.width / 5).round();
        final x1 = (((indice % 5) + 1) * imagem.width / 5).round();
        final y0 = ((indice ~/ 5) * imagem.height / 2).round();
        final y1 = (((indice ~/ 5) + 1) * imagem.height / 2).round();
        var esquerda = x1;
        var direita = x0;
        var topo = y1;
        var base = y0;
        if (pixels != null) {
          for (var y = y0; y < y1; y++) {
            for (var x = x0; x < x1; x++) {
              if (pixels.getUint8((y * imagem.width + x) * 4 + 3) >= 128) {
                esquerda = math.min(esquerda, x);
                direita = math.max(direita, x + 1);
                topo = math.min(topo, y);
                base = math.max(base, y + 1);
              }
            }
          }
        }
        recortes.add(esquerda < direita && topo < base
          ? Rect.fromLTRB(esquerda.toDouble(), topo.toDouble(), direita.toDouble(), base.toDouble())
          : Rect.fromLTRB(x0.toDouble(), y0.toDouble(), x1.toDouble(), y1.toDouble()));
      }
      return _AtlasEtapas(imagem, recortes);
    } finally {
      codec.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 60,
      child: FutureBuilder<_AtlasEtapas>(
        future: _atlas,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Icon(Icons.broken_image_outlined,
                color: Colors.white, size: 32);
          }
          if (!snapshot.hasData) return const SizedBox.shrink();
          return CustomPaint(painter: _PintorEtapa(snapshot.data!, indice));
        },
      ),
    );
  }
}

class _AtlasEtapas {
  final ui.Image imagem;
  final List<Rect> recortes;
  _AtlasEtapas(this.imagem, this.recortes);
}

class _PintorEtapa extends CustomPainter {
  final _AtlasEtapas atlas;
  final int indice;
  _PintorEtapa(this.atlas, this.indice);

  @override
  void paint(Canvas canvas, Size size) {
    final origem = atlas.recortes[indice % atlas.recortes.length];
    // Centraliza o desenho visível, e não o espaço transparente da célula.
    final escala = math.min(48.0 / origem.width, 48.0 / origem.height);
    final destino = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: origem.width * escala,
      height: origem.height * escala,
    );
    final pincel = Paint()
      ..filterQuality = FilterQuality.high
      ..colorFilter = const ColorFilter.mode(Colors.white, BlendMode.srcIn);
    canvas.drawImageRect(atlas.imagem, origem, destino, pincel);
  }

  @override
  bool shouldRepaint(covariant _PintorEtapa oldDelegate) =>
      oldDelegate.atlas != atlas || oldDelegate.indice != indice;
}
