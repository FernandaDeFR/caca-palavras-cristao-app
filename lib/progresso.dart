import 'dart:convert';
import 'paleta.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

String formatarTempo(int ms) {
  final segundos = ms ~/ 1000;
  final minutos = segundos ~/ 60;
  return '${minutos.toString().padLeft(2, '0')}:${(segundos % 60).toString().padLeft(2, '0')}';
}

// Um único registro inclui saldos, etapas premiadas e progresso.
// Escritas em fila evitam que duas recompensas se sobrescrevam.
class Progresso extends ChangeNotifier {
  Progresso._();
  static final instancia = Progresso._();
  final _prefs = SharedPreferencesAsync();
  static const _chave = 'progresso_biblico_v2';
  Map<String, dynamic> _dados = {};
  bool _carregado = false;
  Future<void> _fila = Future<void>.value();
  String? erro;
  bool get carregado => _carregado;
  int get talentos => (_dados['talentos'] as int?) ?? 0;
  int get paes => (_dados['paes'] as int?) ?? 0;
  int get sequencia => (_dados['sequencia'] as int?) ?? 0;
  Map<String, dynamic>? get recorde => _dados['recorde'] == null ? null
      : Map<String, dynamic>.from(_dados['recorde'] as Map);

  Future<T> _serial<T>(Future<T> Function() tarefa) {
    final resultado = _fila.then((_) => tarefa());
    _fila = resultado.then<void>((_) {}, onError: (Object e, StackTrace st) {
      erro = 'Não foi possível salvar ou carregar o progresso.';
      notifyListeners();
    });
    return resultado;
  }

  Future<void> _ler() async {
    if (_carregado) return;
    final texto = await _prefs.getString(_chave);
    if (texto != null) _dados = Map<String, dynamic>.from(jsonDecode(texto) as Map);
    _carregado = true;
  }

  Future<void> _gravar(Map<String, dynamic> novo) async {
    await _prefs.setString(_chave, jsonEncode(novo));
    _dados = novo;
    erro = null;
    notifyListeners();
  }

  Map<String, dynamic> _copia() =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(_dados)) as Map);

  Future<int> receberPaoDiario({DateTime? agora}) => _serial(() async {
    await _ler();
    final local = agora ?? DateTime.now();
    // UTC apenas para calcular a diferença entre datas sem interferência do horário de verão.
    final hoje = DateTime.utc(local.year, local.month, local.day);
    final ultima = DateTime.tryParse((_dados['ultimoDia'] as String?) ?? '');
    if (ultima != null && !hoje.isAfter(ultima)) {
      erro = null;
      notifyListeners();
      return 0;
    }
    final dias = ultima != null && hoje.difference(ultima).inDays == 1 ? sequencia + 1 : 1;
    final premio = math.min(dias, 7);
    final novo = _copia();
    novo['ultimoDia'] = hoje.toIso8601String();
    novo['sequencia'] = dias;
    novo['paes'] = paes + premio;
    await _gravar(novo);
    return premio;
  });

  Future<Map<String, dynamic>> lerEtapa(String id, {String? assinatura}) => _serial(() async {
    await _ler();
    final etapas = (_dados['etapas'] as Map?) ?? {};
    if (etapas[id] != null) {
      final dados = Map<String, dynamic>.from(etapas[id] as Map);
      if (assinatura == null || dados['assinatura'] == assinatura) return dados;
      // O grid mudou: preserva o prêmio anterior, mas reinicia a partida.
      return <String, dynamic>{
        'palavras': <int>[], 'letrasReveladas': <String>[],
        'tempoMs': 0, 'tempoValido': true,
      };
    }
    if (assinatura != null) {
      return <String, dynamic>{'palavras': <int>[], 'tempoMs': 0, 'tempoValido': true};
    }
    // Migra as palavras salvas pela versão anterior sem inventar um tempo.
    final antigo = await _prefs.getStringList('palavras_encontradas_v1/$id') ?? [];
    return <String, dynamic>{
      'palavras': antigo.map(int.tryParse).whereType<int>().toList(),
      'tempoMs': 0,
      'tempoValido': antigo.isEmpty,
    };
  });

  Future<int> salvarEtapa({required String id, String? assinatura, required String livro,
    required int numero, required String tema, required int quantidade,
    required Set<int> palavras, required int tempoMs, required bool tempoValido,
    Set<String> letrasReveladas = const {}, int custoTalentos = 0, int custoPaes = 0}) {
    final indices = palavras.toList()..sort();
    final letras = letrasReveladas.toList()..sort();
    return _serial(() async {
      await _ler();
      if (custoTalentos < 0 || custoPaes < 0) throw ArgumentError('Custo inválido');
      if (talentos < custoTalentos || paes < custoPaes) {
        throw StateError('Saldo insuficiente');
      }
      final novo = _copia();
      novo['talentos'] = talentos - custoTalentos;
      novo['paes'] = paes - custoPaes;
      final etapas = Map<String, dynamic>.from((novo['etapas'] as Map?) ?? {});
      final anterior = Map<String, dynamic>.from((etapas[id] as Map?) ?? {});
      var premiada = anterior['premiada'] == true;
      var credito = 0;
      final concluida = indices.length == quantidade;
      if (concluida && !premiada) {
        credito = quantidade;
        novo['talentos'] = talentos - custoTalentos + credito;
        premiada = true;
      }
      etapas[id] = {
        'assinatura': assinatura,
        'palavras': indices, 'tempoMs': tempoMs,
        'tempoValido': tempoValido, 'premiada': premiada,
        'letrasReveladas': letras,
      };
      novo['etapas'] = etapas;
      final atual = novo['recorde'] as Map?;
      if (concluida && tempoValido && tempoMs > 0 &&
          (atual == null || tempoMs < (atual['tempoMs'] as int))) {
        novo['recorde'] = {'tempoMs': tempoMs, 'id': id,
          'livro': livro, 'numero': numero, 'tema': tema};
      }
      await _gravar(novo);
      return credito;
    });
  }
}

class ConquistasPage extends StatelessWidget {
  const ConquistasPage({super.key});

  @override
  Widget build(BuildContext context) {
    final progresso = Progresso.instancia;
    return AnimatedBuilder(animation: progresso, builder: (context, _) {
      if (!progresso.carregado && progresso.erro == null) {
        return const Center(child: CircularProgressIndicator());
      }
      final recorde = progresso.recorde;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Image.asset('assets/ovelha.png', height: 210, fit: BoxFit.contain,
                semanticLabel: 'Ovelha, mascote do jogo'),
            const SizedBox(height: 16),
            const Text('Conquistas', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold,
                    color: Paleta.azulEscuro)),
            const SizedBox(height: 24),
            _recompensa(
              nome: 'Talentos', saldo: progresso.talentos,
              explicacao: 'Ganhe talentos ao completar os caça-palavras',
              cor: Paleta.dourado, figura: Image.asset('assets/talento.png', width: 92, height: 92, fit: BoxFit.contain, semanticLabel: 'Talento'),
            ),
            const SizedBox(height: 16),
            _recompensa(
              nome: 'Pão Diário', saldo: progresso.paes,
              explicacao: 'Ganhe pães diários ao retornar todos os dias',
              cor: Paleta.coral, figura: Image.asset('assets/pao_diario.png', width: 92, height: 92, fit: BoxFit.contain, semanticLabel: 'Pão diário'),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                border: Border.all(color: Paleta.azul, width: 2.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(children: [
                const Ampulheta(),
                const SizedBox(width: 18),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Melhor tempo', style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (recorde == null)
                      const Text('Conclua uma etapa para registrar seu tempo.')
                    else
                      Text.rich(TextSpan(children: [
                        TextSpan(text: formatarTempo(recorde['tempoMs'] as int),
                          style: const TextStyle(fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Paleta.azulEscuro)),
                        TextSpan(text: '  ${recorde['livro']} - ${recorde['tema']}',
                          style: const TextStyle(fontSize: 17)),
                      ])),
                  ],
                )),
              ]),
            ),
            if (progresso.erro != null) ...[
              const SizedBox(height: 20), Text(progresso.erro!),
              TextButton(onPressed: () async {
                try { await progresso.receberPaoDiario(); }
                catch (_) { /* Erro exibido acima. */ }
              }, child: const Text('Tentar novamente')),
            ],
          ]),
        )),
      );
    });
  }

  Widget _recompensa({required String nome, required int saldo,
      required String explicacao, required Color cor, required Widget figura}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        border: Border.all(color: cor, width: 2.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: [
        Text(explicacao, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 10),
        figura,
        const SizedBox(height: 8),
        Text('$nome: $saldo', textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

