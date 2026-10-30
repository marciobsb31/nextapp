import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../app/entrada.dart';
import '../../app/provedores.dart';
import '../../core/documento/documentos.dart';
import '../../core/rede/falha_api.dart';
import '../../core/sessao/escopo.dart';
import '../../core/sessao/sessao.dart';
import 'cadastro_page.dart';

class LojaEncontrada {
  const LojaEncontrada({
    required this.tenantId,
    required this.lojaId,
    required this.nome,
    required this.endereco,
    this.distanciaKm,
  });

  final String tenantId;
  final int lojaId;
  final String nome;
  final String endereco;
  final double? distanciaKm;

  LojaOferecida get oferecida => LojaOferecida(tenantId: tenantId, lojaId: lojaId, nome: nome);

  factory LojaEncontrada.deJson(Map<String, dynamic> json) {
    final partes = [
      texto(json['logradouro']),
      texto(json['numero']),
      texto(json['bairro']),
      texto(json['cidade']),
    ].where((parte) => parte.isNotEmpty);
    return LojaEncontrada(
      tenantId: texto(json['tenantId']),
      lojaId: json['lojaId'] is num ? (json['lojaId'] as num).toInt() : int.tryParse(texto(json['lojaId'])) ?? 0,
      nome: texto(json['nome']),
      endereco: partes.join(', '),
      distanciaKm: json['distanciaMetros'] is num
          ? (json['distanciaMetros'] as num).toDouble() / 1000
          : json['distanciaKm'] is num
              ? (json['distanciaKm'] as num).toDouble()
              : null,
    );
  }
}

class ResultadoBusca {
  const ResultadoBusca({
    required this.lojas,
    required this.raioKm,
    required this.porCep,
    this.endereco,
  });

  final List<LojaEncontrada> lojas;
  final double? raioKm;
  final bool porCep;
  final EnderecoViaCep? endereco;
}

class DescobertaPage extends ConsumerStatefulWidget {
  const DescobertaPage({super.key});

  @override
  ConsumerState<DescobertaPage> createState() => _DescobertaPageState();
}

class _DescobertaPageState extends ConsumerState<DescobertaPage> {
  final _cep = TextEditingController();
  var _ocupado = false;
  String? _aviso;
  var _avisoErro = true;
  ResultadoBusca? _busca;
  String _ultimoCep = '';

  @override
  void dispose() {
    _cep.dispose();
    super.dispose();
  }

  Future<void> _porCep() async {
    final digitos = somenteDigitos(_cep.text);
    final mensagem = mensagemCep(_cep.text);
    if (mensagem != null) {
      setState(() {
        _aviso = mensagem;
        _avisoErro = true;
        _busca = null;
      });
      unawaited(vibrarErro());
      return;
    }
    if (_ocupado || digitos == _ultimoCep) return;
    unawaited(HapticFeedback.lightImpact());
    setState(() {
      _ocupado = true;
      _aviso = null;
    });
    try {
      final corpo = await ref.read(apiProvider).lojasPorCep(digitos);
      if (!mounted) return;
      final busca = _ler(corpo, porCep: true);
      _ultimoCep = digitos;
      setState(() {
        _busca = busca;
        _aviso = _mensagemBusca(busca);
        _avisoErro = busca.lojas.isEmpty;
      });
      unawaited(HapticFeedback.selectionClick());
    } catch (erro) {
      if (!mounted) return;
      _ultimoCep = '';
      unawaited(vibrarErro());
      setState(() {
        _aviso = falhaDe(erro).mensagem;
        _avisoErro = true;
        _busca = null;
      });
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  String _metros(double km) => '${(km * 1000).round()} m';

  String _mensagemBusca(ResultadoBusca busca) {
    final endereco = busca.endereco?.resumo ?? '';
    const raio = '500 metros';
    if (busca.lojas.isEmpty) {
      if (endereco.isEmpty) return 'CEP encontrado, mas nenhuma unidade atende este endereço em $raio.';
      return 'Endereço encontrado: $endereco. Nenhuma unidade atende este CEP em $raio.';
    }
    if (endereco.isEmpty) return 'Escolha a unidade. O cadastro abre com o endereço deste CEP.';
    return 'Endereço confirmado: $endereco. Toque na unidade para abrir o cadastro já preenchido.';
  }

  Future<void> _porLocal() async {
    unawaited(HapticFeedback.lightImpact());
    setState(() {
      _ocupado = true;
      _aviso = null;
    });
    try {
      final servico = await Geolocator.isLocationServiceEnabled();
      if (!servico) {
        throw const FalhaApi('O GPS está desligado. O CEP continua sendo o caminho para criar a conta.');
      }
      var permissao = await Geolocator.checkPermission();
      if (permissao == LocationPermission.denied) {
        permissao = await Geolocator.requestPermission();
      }
      if (permissao == LocationPermission.denied || permissao == LocationPermission.deniedForever) {
        throw const FalhaApi('Sem a localização, digite o CEP. A conta só é criada por um CEP que a unidade atende.');
      }
      final ponto = await Geolocator.getCurrentPosition().timeout(const Duration(seconds: 12));
      final corpo = await ref.read(apiProvider).lojasProximas(ponto.latitude, ponto.longitude);
      if (!mounted) return;
      final busca = _ler(corpo, porCep: false);
      setState(() {
        _busca = busca;
        _aviso = busca.lojas.isEmpty
            ? 'Não há unidade em 500 metros. Tente o CEP da sua casa.'
            : 'Estas unidades estão perto. Para entrar, confirme com o CEP. A localização não cria o vínculo.';
        _avisoErro = busca.lojas.isEmpty;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _aviso = 'A localização demorou demais. Digite o CEP.';
        _avisoErro = true;
      });
    } catch (erro) {
      if (!mounted) return;
      unawaited(vibrarErro());
      setState(() {
        _aviso = falhaDe(erro).mensagem;
        _avisoErro = true;
      });
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  ResultadoBusca _ler(Map<String, dynamic> corpo, {required bool porCep}) {
    final lista = corpo['lojas'];
    final lojas = <LojaEncontrada>[
      if (lista is List)
        for (final item in lista)
          if (item is Map)
            LojaEncontrada.deJson(Map<String, dynamic>.from(item)),
    ].where((loja) => loja.distanciaKm == null || loja.distanciaKm! <= 0.5).toList();
    final raio = corpo['raioKm'];
    final endereco = corpo['endereco'];
    return ResultadoBusca(
      lojas: lojas,
      raioKm: raio is num ? raio.toDouble() : null,
      porCep: porCep,
      endereco: endereco is Map ? EnderecoViaCep.deJson(Map<String, dynamic>.from(endereco)) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final busca = _busca;
    return Scaffold(
      appBar: AppBar(title: const Text('Encontrar unidade')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const EntradaSuave(
            indice: 0,
            child: Text('Digite o CEP da sua casa. O endereço vem do ViaCEP e a conta só nasce na unidade a até 500 metros desse CEP.'),
          ),
          const SizedBox(height: 16),
          EntradaSuave(
            indice: 1,
            child: TextField(
              controller: _cep,
              keyboardType: TextInputType.number,
              inputFormatters: [_Mascara(formatarCep)],
              decoration: InputDecoration(
                labelText: 'CEP',
                hintText: '00000-000',
                suffixIcon: _ocupado
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : const Icon(Icons.location_on_outlined),
              ),
              onChanged: (valor) {
                if (somenteDigitos(valor).length == 8) _porCep();
              },
              onSubmitted: (_) => _porCep(),
            ),
          ),
          const SizedBox(height: 12),
          EntradaSuave(
            indice: 2,
            child: FilledButton(
              onPressed: _ocupado ? null : _porCep,
              child: Text(_ocupado ? 'Consultando o CEP...' : 'Buscar pelo CEP'),
            ),
          ),
          TextButton(onPressed: _ocupado ? null : _porLocal, child: const Text('Ver quem está perto de mim')),
          if (_aviso != null) ...[
            const SizedBox(height: 12),
            AvisoAnimado(texto: _aviso!, erro: _avisoErro),
          ],
          if (busca?.endereco != null && busca!.porCep) ...[
            const SizedBox(height: 16),
            EntradaSuave(indice: 1, child: _CartaoEndereco(endereco: busca.endereco!)),
          ],
          if (busca != null)
            for (var i = 0; i < busca.lojas.length; i++)
              EntradaSuave(
                indice: i + 2,
                child: Card(
                  margin: const EdgeInsets.only(top: 12),
                  child: ListTile(
                    title: Text(busca.lojas[i].nome),
                    subtitle: Text(
                      [
                        if (busca.lojas[i].endereco.isNotEmpty) busca.lojas[i].endereco,
                        if (busca.lojas[i].distanciaKm != null) _metros(busca.lojas[i].distanciaKm!),
                      ].join(' · '),
                    ),
                    trailing: busca.porCep ? const Icon(Icons.arrow_forward) : null,
                    enabled: busca.porCep,
                    onTap: busca.porCep
                        ? () {
                            HapticFeedback.selectionClick();
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => CadastroPage(
                                  cep: somenteDigitos(_cep.text),
                                  loja: busca.lojas[i],
                                  oferecidas: busca.lojas,
                                  endereco: busca.endereco ??
                                      EnderecoViaCep(
                                        cep: somenteDigitos(_cep.text),
                                        logradouro: '',
                                        complemento: '',
                                        bairro: '',
                                        cidade: '',
                                        uf: '',
                                      ),
                                ),
                              ),
                            );
                          }
                        : null,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _CartaoEndereco extends StatelessWidget {
  const _CartaoEndereco({required this.endereco});

  final EnderecoViaCep endereco;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7E4E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Endereço do CEP', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(endereco.resumo.isEmpty ? 'O ViaCEP não trouxe rua para este CEP.' : endereco.resumo),
          if (endereco.cep.isNotEmpty) Text('CEP ${formatarCep(endereco.cep)}'),
        ],
      ),
    );
  }
}

class _Mascara extends TextInputFormatter {
  _Mascara(this.formatar);

  final String Function(String valor) formatar;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue antigo, TextEditingValue novo) {
    final texto = formatar(novo.text);
    return TextEditingValue(text: texto, selection: TextSelection.collapsed(offset: texto.length));
  }
}
