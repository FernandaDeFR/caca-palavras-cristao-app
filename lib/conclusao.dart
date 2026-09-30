import 'dart:math';
import 'package:flutter/material.dart';
import 'progresso.dart';
import 'paleta.dart';

class ConclusaoPage extends StatefulWidget {
  final String livro;
  final bool ultimaDoLivro;
  final int talentos;
  final int tempoMs;

  const ConclusaoPage({
    super.key,
    required this.livro,
    required this.ultimaDoLivro,
    required this.talentos,
    required this.tempoMs,
  });

  @override
  State<ConclusaoPage> createState() => _ConclusaoPageState();
}

class _ConclusaoPageState extends State<ConclusaoPage> {
  static const _frases = [
    'Cada descoberta é mais um passo!',
    'Mais uma conquista na sua caminhada!',
    'Sua dedicação deu frutos!',
    'Palavra por palavra, você chegou lá!',
    'Mais uma etapa, novas descobertas!',
    'Valeu a pena perseverar!',
  ];
  static int? _ultimaFrase;
  late final String _frase;

  @override
  void initState() {
    super.initState();
    if (widget.ultimaDoLivro) {
      _frase = 'Uau, você chegou à última etapa de ${widget.livro}!';
    } else {
      final opcoes = List<int>.generate(_frases.length, (i) => i)
          .where((i) => i != _ultimaFrase).toList();
      final indice = opcoes[Random().nextInt(opcoes.length)];
      _ultimaFrase = indice;
      _frase = _frases[indice];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: max(0.0, constraints.maxHeight - 48),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _OvelhaAnimada(
                        altura: min(280.0, constraints.maxHeight * .35),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _frase,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Paleta.azulEscuro,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _Resultado(
                            titulo: 'Total de Talentos',
                            valor: '${widget.talentos}',
                            cor: Paleta.dourado,
                            fundo: const Color(0xFFFFF5DB),
                            icone: Image.asset(
                              'assets/talento.png',
                              width: 48, height: 48,
                              fit: BoxFit.contain,
                            ),
                          )),
                          const SizedBox(width: 16),
                          Expanded(child: _Resultado(
                            titulo: 'Total de tempo',
                            valor: formatarTempo(widget.tempoMs),
                            cor: Paleta.azulEscuro,
                            fundo: const Color(0xFFEAF7FD),
                            icone: const Icon(
                              Icons.timer_outlined,
                              size: 48, color: Paleta.azulEscuro,
                            ),
                          )),
                        ],
                      ),
                      const SizedBox(height: 36),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 56),
                            backgroundColor: Paleta.azulEscuro,
                          ),
                          child: const Text('Continuar',
                              style: TextStyle(fontSize: 18)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _Resultado extends StatelessWidget {
  final String titulo;
  final String valor;
  final Color cor;
  final Color fundo;
  final Widget icone;

  const _Resultado({
    required this.titulo,
    required this.valor,
    required this.cor,
    required this.fundo,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
      decoration: BoxDecoration(
        color: fundo,
        border: Border.all(color: cor, width: 2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: [
        Text(titulo, textAlign: TextAlign.center,
            style: TextStyle(color: cor, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        icone,
        const SizedBox(height: 8),
        Text(valor, textAlign: TextAlign.center,
            style: TextStyle(color: cor, fontSize: 28,
                fontWeight: FontWeight.bold)),
      ]),
    );
  }
}


/// Dois pulinhos, sem alterar o tamanho e sem repetição.
class _OvelhaAnimada extends StatefulWidget {
  final double altura;
  const _OvelhaAnimada({required this.altura});

  @override
  State<_OvelhaAnimada> createState() => _OvelhaAnimadaState();
}

class _OvelhaAnimadaState extends State<_OvelhaAnimada>
    with SingleTickerProviderStateMixin {
  late final AnimationController _movimento;
  bool _iniciou = false;

  @override
  void initState() {
    super.initState();
    _movimento = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _iniciou = true;
      _movimento.value = 1;
    }
  }

  void _iniciarQuandoVisivel() {
    if (_iniciou) return;
    _iniciou = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !MediaQuery.disableAnimationsOf(context)) {
        _movimento.forward();
      }
    });
  }

  @override
  void dispose() {
    _movimento.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _movimento,
      child: Image.asset(
        'assets/ovelha.png',
        height: widget.altura,
        fit: BoxFit.contain,
        semanticLabel: 'Ovelha, mascote do jogo',
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (frame != null || wasSynchronouslyLoaded) {
            _iniciarQuandoVisivel();
          }
          return child;
        },
      ),
      builder: (context, child) {
        final t = _movimento.value;
        // A curva começa e termina com velocidade zero em cada pulinho.
        final primeiro = t < .5;
        final fase = primeiro ? t * 2 : (t - .5) * 2;
        final seno = sin(pi * fase);
        final salto = (t == 0 || t == 1) ? 0.0 : seno * seno;
        final altura = min(18.0, widget.altura * .075);
        return Transform.translate(
          offset: Offset(0, -altura * (primeiro ? 1.0 : .7) * salto),
          child: Transform.rotate(
            angle: (primeiro ? -.065 : .065) * salto,
            alignment: Alignment.bottomCenter,
            child: child,
          ),
        );
      },
    );
  }
}
