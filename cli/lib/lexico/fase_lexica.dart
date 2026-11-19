/// Punto de entrada del módulo léxico:
/// normalizar texto -> AFD -> corregir -> normalizar números.
///
/// Es lo único que el parser (integrante 2) y el CLI (integrante 5) necesitan
/// llamar. Ver docs/interfaces-lexico.md.
library;

import 'analizador_lexico.dart';
import 'corrector.dart';
import 'normalizador.dart';
import 'numeros_texto.dart';
import 'token.dart';

/// Todo lo que produce el módulo léxico para una pregunta.
class ResultadoLexico {
  /// Pregunta tal como llegó.
  final String original;

  /// Texto después del normalizador, antes del autómata. Las cantidades en
  /// letras siguen en letras aquí; las posiciones de los tokens se cuentan
  /// sobre este texto.
  final String normalizado;

  /// Tokens corregidos y con las cantidades ya en cifras, terminando en
  /// [TipoToken.fin]. Esto es lo que consume el parser.
  final List<Token> tokens;

  /// Cantidades en letras que se pasaron a cifras.
  final List<ConversionNumero> numerosConvertidos;

  /// Palabras que el corrector cambió (se guardan en el historial).
  final List<Correccion> correcciones;

  /// Palabras fuera del vocabulario que no se pudieron corregir.
  final List<Token> palabrasDesconocidas;

  /// Caracteres que el autómata no reconoce.
  final List<Token> erroresLexicos;

  /// Transiciones del AFD y conversiones (vacía si no se pidió traza).
  final List<String> traza;

  const ResultadoLexico({
    required this.original,
    required this.normalizado,
    required this.tokens,
    required this.numerosConvertidos,
    required this.correcciones,
    required this.palabrasDesconocidas,
    required this.erroresLexicos,
    required this.traza,
  });

  /// No hay caracteres inválidos ni palabras desconocidas.
  bool get limpio => erroresLexicos.isEmpty && palabrasDesconocidas.isEmpty;
}

class FaseLexica {
  final Normalizador normalizador;
  final AnalizadorLexico analizador;
  final Corrector corrector;

  /// [vocabulario]: palabras válidas del español, cargadas desde los datos.
  /// Se le agregan las palabras numéricas ("quince", "mil") para que el
  /// corrector pueda arreglarlas antes de convertirlas.
  FaseLexica(Iterable<String> vocabulario,
      {this.normalizador = const Normalizador(),
      this.analizador = const AnalizadorLexico()})
      : corrector = Corrector(
            [...vocabulario, ...ConvertidorNumeros.palabras],
            normalizador: normalizador);

  ResultadoLexico procesar(String pregunta, {bool conTraza = false}) {
    final normalizado = normalizador.normalizar(pregunta);
    final traza = <String>[];
    final tokens =
        analizador.analizar(normalizado, traza: conTraza ? traza : null);
    final correccion = corrector.corregir(tokens);
    final numeros = normalizador.normalizarNumeros(correccion.tokens);

    if (conTraza) {
      for (final c in correccion.correcciones) {
        traza.add('corrige $c');
      }
      for (final n in numeros.conversiones) {
        traza.add('número $n');
      }
    }

    return ResultadoLexico(
      original: pregunta,
      normalizado: normalizado,
      tokens: numeros.tokens,
      numerosConvertidos: numeros.conversiones,
      correcciones: correccion.correcciones,
      palabrasDesconocidas: correccion.desconocidas,
      erroresLexicos: numeros.tokens
          .where((t) => t.tipo == TipoToken.desconocido)
          .toList(),
      traza: traza,
    );
  }
}
