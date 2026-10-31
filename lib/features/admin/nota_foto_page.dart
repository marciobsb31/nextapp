import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/provedores.dart';
import '../../app/tema.dart';
import '../../core/rede/falha_api.dart';
import '../../core/sessao/sessao.dart';
import '../inicio/produto_resumo.dart';
import 'gestao_comum.dart';

/// Entrada de estoque pela foto da nota fiscal: a IA lê os itens, você confere e confirma.
/// Itens que já existem somam estoque (e o preço, se marcar); os novos viram produtos.
class NotaFotoPage extends ConsumerStatefulWidget {
  const NotaFotoPage({super.key, this.unidadeId});

  final int? unidadeId;

  @override
  ConsumerState<NotaFotoPage> createState() => _NotaFotoPageState();
}

class _NotaFotoPageState extends ConsumerState<NotaFotoPage> {
  var _lendo = false;
  var _gravando = false;
  String? _erro;
  Map<String, dynamic>? _nota;
  List<Map<String, dynamic>> _itens = [];

  Future<void> _tirarFoto(ImageSource origem) async {
    final sessao = ref.read(sessaoProvider).asData?.value;
    if (sessao == null) return;
    final foto = await ImagePicker().pickImage(source: origem, imageQuality: 85, maxWidth: 2200);
    if (foto == null) return;
    setState(() {
      _lendo = true;
      _erro = null;
      _nota = null;
    });
    try {
      final nome = foto.name.isEmpty ? 'nota.jpg' : foto.name;
      final nota = await ref.read(apiProvider).lerNotaPorFoto(sessao, bytes: await foto.readAsBytes(), nomeArquivo: nome);
      if (!mounted) return;
      setState(() {
        _nota = nota;
        _itens = [
          for (final item in mapas(nota['itens']))
            {
              ...item,
              'incluir': true,
              'atualizarPreco': false,
            },
        ];
      });
    } catch (erro) {
      if (mounted) setState(() => _erro = falhaDe(erro).mensagem);
    } finally {
      if (mounted) setState(() => _lendo = false);
    }
  }

  Future<void> _confirmar() async {
    final sessao = ref.read(sessaoProvider).asData?.value;
    if (sessao == null || _nota == null) return;
    final escolhidos = _itens.where((i) => i['incluir'] == true).toList();
    if (escolhidos.isEmpty) return avisar(context, 'Marque ao menos um item.', erro: true);
    setState(() => _gravando = true);
    try {
      final r = await ref.read(apiProvider).gestaoEnviar(sessao, 'POST', '/api/compras/nota-foto/confirmar', corpo: {
        'fornecedor': _nota!['fornecedor'],
        'numero': _nota!['numero'],
        'lojaId': widget.unidadeId,
        'itens': escolhidos,
      });
      if (!mounted) return;
      final m = r is Map ? r : const {};
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Estoque atualizado'),
          content: Text('${m['itens'] ?? 0} item(ns) com entrada no estoque.\n'
              '${m['produtosCriados'] ?? 0} produto(s) novo(s) cadastrado(s).\n'
              '${m['precosAtualizados'] ?? 0} preço(s) atualizado(s).'),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Pronto'))],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (erro) {
      if (mounted) avisar(context, falhaDe(erro).mensagem, erro: true);
    } finally {
      if (mounted) setState(() => _gravando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nota = _nota;
    return TelaGestao(
      titulo: 'Nota por foto',
      corpo: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          if (nota == null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: cartaoApp(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.document_scanner_outlined, color: Cores.laranja, size: 40),
                  SizedBox(height: 8),
                  Text('Fotografe a nota da compra', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  SizedBox(height: 6),
                  Text('A IA lê cada item com quantidade e custo. Você confere antes de gravar: '
                      'o que já existe soma estoque e o que é novo vira produto.', style: TextStyle(color: Cores.tinta)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _lendo ? null : () => _tirarFoto(ImageSource.camera),
              icon: const Icon(Icons.photo_camera),
              label: const Text('Tirar foto da nota'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _lendo ? null : () => _tirarFoto(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Escolher da galeria'),
            ),
          ],
          if (_lendo) ...[
            const SizedBox(height: 20),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text('Lendo a nota... isso leva alguns segundos.', textAlign: TextAlign.center, style: TextStyle(color: Cores.tinta)),
          ],
          if (_erro != null) ...[const SizedBox(height: 12), EstadoLista(carregando: false, erro: _erro, vazia: false, textoVazio: '')],
          if (nota != null) ...[
            Text(texto(nota['fornecedor']).isEmpty ? 'Fornecedor não identificado' : texto(nota['fornecedor']),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            Text([if (texto(nota['numero']).isNotEmpty) 'Nota ${nota['numero']}', if (texto(nota['cnpj']).isNotEmpty) 'CNPJ ${nota['cnpj']}'].join(' · '),
                style: const TextStyle(color: Cores.tinta)),
            const SizedBox(height: 12),
            for (final item in _itens) _item(item),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _gravando ? null : _confirmar,
              icon: _gravando ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.inventory),
              label: Text('Dar entrada em ${_itens.where((i) => i['incluir'] == true).length} item(ns)'),
            ),
            TextButton(onPressed: () => setState(() => _nota = null), child: const Text('Ler outra nota')),
          ],
        ],
      ),
    );
  }

  Widget _item(Map<String, dynamic> item) {
    final novo = item['novo'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(8, 8, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Cores.raio),
        boxShadow: Cores.sombra,
        border: Border.all(color: novo ? Cores.laranja.withValues(alpha: 0.35) : Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(value: item['incluir'] == true, onChanged: (v) => setState(() => item['incluir'] = v ?? false)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(texto(item['nome']), style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(novo ? 'Produto novo: será cadastrado' : 'Já cadastrado · preço atual ${reais(item['precoAtual'])}',
                        style: TextStyle(color: novo ? Cores.laranjaEscuro : Cores.tinta, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(
              children: [
                _campo('Qtd.', item, 'quantidade', inteiro: true),
                const SizedBox(width: 8),
                _campo('Custo un.', item, 'custoUnitario'),
                const SizedBox(width: 8),
                _campo('Venda', item, 'precoVenda'),
              ],
            ),
          ),
          if (!novo)
            CheckboxListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 0),
              controlAffinity: ListTileControlAffinity.leading,
              value: item['atualizarPreco'] == true,
              onChanged: (v) => setState(() => item['atualizarPreco'] = v ?? false),
              title: const Text('Atualizar o preço de venda'),
            ),
        ],
      ),
    );
  }

  Widget _campo(String rotulo, Map<String, dynamic> item, String chave, {bool inteiro = false}) {
    return Expanded(
      child: TextFormField(
        initialValue: texto(item[chave]),
        keyboardType: inteiro ? TextInputType.number : const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: rotulo, isDense: true),
        onChanged: (v) => item[chave] = inteiro ? int.tryParse(v.trim()) ?? 0 : v.trim(),
      ),
    );
  }
}
