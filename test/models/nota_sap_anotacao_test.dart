import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/nota_sap_analise.dart';
import 'package:task2026/models/nota_sap_anotacao.dart';

void main() {
  group('Fase 3: Model de Anotações Técnicas e Serialização JSON', () {
    test('1. JSON round-trip de elemento individual preserva todos os campos', () {
      const elemento = NotaSapAnotacaoElemento(
        id: 'el_123',
        type: NotaSapElementoTipo.arrow,
        x1: 0.25,
        y1: 0.35,
        x2: 0.65,
        y2: 0.75,
        strokeWidth: 4.0,
        color: '#E53935',
        label: 'Trinca na cruzeta',
        text: 'Avaria grave',
        fontSize: 16.0,
        zIndex: 2,
      );

      final map = elemento.toMap();
      final reloaded = NotaSapAnotacaoElemento.fromMap(map);

      expect(reloaded.id, 'el_123');
      expect(reloaded.type, NotaSapElementoTipo.arrow);
      expect(reloaded.x1, 0.25);
      expect(reloaded.y1, 0.35);
      expect(reloaded.x2, 0.65);
      expect(reloaded.y2, 0.75);
      expect(reloaded.strokeWidth, 4.0);
      expect(reloaded.color, '#E53935');
      expect(reloaded.label, 'Trinca na cruzeta');
      expect(reloaded.text, 'Avaria grave');
      expect(reloaded.fontSize, 16.0);
      expect(reloaded.zIndex, 2);
    });

    test('2. JSON round-trip do documento de anotações (NotaSapAnotacaoDocumento)', () {
      final doc = NotaSapAnotacaoDocumento(
        version: 1,
        canvasWidth: 3840,
        canvasHeight: 2160,
        rotationAngle: 90,
        crop: {'x': 0.1, 'y': 0.1, 'w': 0.8, 'h': 0.8},
        elements: const [
          NotaSapAnotacaoElemento(
            id: 'el_rect',
            type: NotaSapElementoTipo.rect,
            x1: 0.1,
            y1: 0.2,
            x2: 0.4,
            y2: 0.5,
            strokeWidth: 3.0,
            color: '#1E88E5',
          ),
          NotaSapAnotacaoElemento(
            id: 'el_circle',
            type: NotaSapElementoTipo.circle,
            x1: 0.5,
            y1: 0.5,
            x2: 0.7,
            y2: 0.7,
            color: '#FBC02D',
          ),
          NotaSapAnotacaoElemento(
            id: 'el_text',
            type: NotaSapElementoTipo.text,
            x1: 0.8,
            y1: 0.8,
            text: 'Isolador quebrado',
          ),
        ],
      );

      final jsonStr = doc.toJson();
      final docRestaurado = NotaSapAnotacaoDocumento.fromJson(jsonStr);

      expect(docRestaurado.version, 1);
      expect(docRestaurado.canvasWidth, 3840);
      expect(docRestaurado.canvasHeight, 2160);
      expect(docRestaurado.rotationAngle, 90);
      expect(docRestaurado.crop?['w'], 0.8);
      expect(docRestaurado.elements.length, 3);
      expect(docRestaurado.elements[0].type, NotaSapElementoTipo.rect);
      expect(docRestaurado.elements[1].type, NotaSapElementoTipo.circle);
      expect(docRestaurado.elements[2].type, NotaSapElementoTipo.text);
      expect(docRestaurado.elements[2].text, 'Isolador quebrado');
    });

    test('3. NotaSapAnotacao persistência de versão append-only (sem updated_at)', () {
      final doc = const NotaSapAnotacaoDocumento(
        canvasWidth: 1920,
        canvasHeight: 1080,
      );

      final anotacao = NotaSapAnotacao(
        id: 'anot_v1',
        anexoId: 'anexo_orig_1',
        versao: 1,
        dadosJson: doc,
        imagemLargura: 1920,
        imagemAltura: 1080,
        criadoPor: 'user_456',
        criadoPorNome: 'Analista Técnico',
        createdAt: DateTime(2026, 10, 30, 8, 0),
      );

      final map = anotacao.toMap();
      // Não deve ter updated_at nem nota_sap_id na anotação
      expect(map.containsKey('updated_at'), isFalse);
      expect(map.containsKey('nota_sap_id'), isFalse);
      expect(map['versao'], 1);
      expect(map['anexo_id'], 'anexo_orig_1');

      final v2 = anotacao.copyWith(versao: 2);
      expect(v2.versao, 2);
      expect(v2.anexoId, 'anexo_orig_1');
    });

    test('4. Imutabilidade do anexo original e integridade de hash SHA-256', () {
      final bytesOriginais = utf8.encode('CONTEUDO_BINARIO_IMAGEM_ORIGINAL_TESTE');
      final sha256Antes = sha256.convert(bytesOriginais).toString();

      final anexoOriginal = NotaSapAnexo(
        id: 'orig_1',
        notaSapId: 'nota_123',
        nomeArquivo: 'foto_poste.jpg',
        tipoArquivo: NotaAnexoTipo.imagem,
        caminhoArquivo: 'nota_123/foto_poste.jpg',
        tamanhoBytes: bytesOriginais.length,
        sha256: sha256Antes,
        versaoAnotacao: 0,
      );

      // Anotação é criada e associada
      final anexoAnotado = anexoOriginal.copyWith(versaoAnotacao: 1);

      // Verificação estrita de não destrutividade:
      // O hash, caminho, nome e tamanho do original permanecem 100% inalterados
      expect(anexoAnotado.sha256, sha256Antes);
      expect(anexoAnotado.caminhoArquivo, anexoOriginal.caminhoArquivo);
      expect(anexoAnotado.tamanhoBytes, anexoOriginal.tamanhoBytes);
      expect(anexoAnotado.possuiAnotacao, isTrue);
      expect(anexoAnotado.isOriginal, isTrue);
      expect(anexoAnotado.isDerivado, isFalse);

      // Derivada opcional aponta para o original
      final anexoDerivado = NotaSapAnexo(
        id: 'deriv_1',
        notaSapId: 'nota_123',
        nomeArquivo: 'foto_poste_anotada_v1.png',
        tipoArquivo: NotaAnexoTipo.imagem,
        caminhoArquivo: 'nota_123/derived/orig_1/v1.png',
        tamanhoBytes: 54321,
        origem: 'TASKFLOW',
        anexoDerivadoDeId: anexoOriginal.id,
      );

      expect(anexoDerivado.isDerivado, isTrue);
      expect(anexoDerivado.isOriginal, isFalse);
      expect(anexoDerivado.anexoDerivadoDeId, 'orig_1');
    });
  });
}
