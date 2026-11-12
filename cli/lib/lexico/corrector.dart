/// Fase 3: corrector ortográfico con distancia de Levenshtein propia.
///
/// El vocabulario NO está en el código: se recibe desde fuera (base de datos
/// del integrante 4 y formas verbales de la morfología del integrante 2).
library;

import 'normalizador.dart';
import 'token.dart';

/// Distancia de Levenshtein entre [a] y [b]: mínimo número de inserciones,
/// borrados y sustituciones de un carácter para pasar de una a otra.
///
/// Programación dinámica con solo dos filas de la matriz: O(|a|·|b|) en
/// tiempo y O(|b|) en memoria.
int distanciaLevenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  var anterior = List<int>.generate(b.length + 1, (j) => j);
  var actual = List<int>.filled(b.length + 1, 0);

  for (var i = 1; i <= a.length; i++) {
    actual[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final costo = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      final borrar = anterior[j] + 1;
      final insertar = actual[j - 1] + 1;
      final sustituir = anterior[j - 1] + costo;
      var minimo = borrar < insertar ? borrar : insertar;
      if (sustituir < minimo) minimo = sustituir;
      actual[j] = minimo;
    }
    final tmp = anterior;
    anterior = actual;
    actual = tmp;
  }
  return anterior[b.length];
}

/// Un cambio que hizo el corrector.
class Correccion {
  final String original;
  final String corregida;
  final int distancia;

  /// Posición del token en el texto normalizado.
  final int posicion;

  /// Todas las palabras del vocabulario que quedaron a la misma distancia
  /// mínima, ya ordenadas por el desempate. La primera es [corregida].
  final List<String> empatadas;

  const Correccion({
    required this.original,
    required this.corregida,
    required this.distancia,
    required this.posicion,
    required this.empatadas,
  });

  /// Hubo más de un candidato a la misma distancia.
  bool get ambigua => empatadas.length > 1;

  Map<String, Object?> toMap() => {
        'original': original,
        'corregida': corregida,
        'distancia': distancia,
        'posicion': posicion,
        if (ambigua) 'empatadas': empatadas,
      };

  @override
  String toString() => '$original -> $corregida (d=$distancia)'
      '${ambigua ? ' empate: $empatadas' : ''}';
}

/// Resultado de corregir una lista de tokens.
class ResultadoCorreccion {
  /// Tokens con las palabras corregidas (la misma cantidad que la entrada).
  final List<Token> tokens;

  /// Cambios hechos, para guardarlos en el historial.
  final List<Correccion> correcciones;

  /// Palabras que no están en el vocabulario y no se pudieron corregir.
  final List<Token> desconocidas;

  const ResultadoCorreccion(this.tokens, this.correcciones, this.desconocidas);
}

class Corrector {
  final Set<String> _vocabulario;

  /// [vocabulario]: palabras válidas del español. Se normalizan (minúsculas,
  /// sin tildes) para compararlas con el texto normalizado. Las entradas de
  /// varias palabras ("ir a") se parten en palabras sueltas.
  Corrector(Iterable<String> vocabulario,
      {Normalizador normalizador = const Normalizador()})
      : _vocabulario = vocabulario
            .map(normalizador.normalizarPalabra)
            .expand((e) => e.split(' '))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet();

  /// Cantidad de palabras distintas que conoce el corrector.
  int get tamanoVocabulario => _vocabulario.length;

  bool conoce(String palabra) => _vocabulario.contains(palabra);

  /// Distancia máxima permitida según la longitud de la palabra
  /// (decisión L-04). Palabras de 1 o 2 letras no se corrigen.
  static int umbralPara(int longitud) {
    if (longitud <= 2) return 0;
    if (longitud <= 5) return 1;
    return 2;
  }

  /// Busca la palabra del vocabulario más cercana a [palabra].
  /// Devuelve null si ninguna está dentro del umbral.
  ({String palabra, int distancia, List<String> empatadas})? mejorCandidato(
      String palabra) {
    final umbral = umbralPara(palabra.length);
    if (umbral == 0) return null;

    var mejor = umbral + 1;
    final empatadas = <String>[];
    for (final candidata in _vocabulario) {
      // Si las longitudes difieren más que el umbral, la distancia también.
      if ((candidata.length - palabra.length).abs() > umbral) continue;
      final d = distanciaLevenshtein(palabra, candidata);
      if (d < mejor) {
        mejor = d;
        empatadas
          ..clear()
          ..add(candidata);
      } else if (d == mejor) {
        empatadas.add(candidata);
      }
    }
    if (empatadas.isEmpty) return null;

    // Desempate (decisión L-05): misma primera letra, luego longitud más
    // parecida, luego orden alfabético para que el resultado sea estable.
    empatadas.sort((x, y) {
      final px = x[0] == palabra[0] ? 0 : 1;
      final py = y[0] == palabra[0] ? 0 : 1;
      if (px != py) return px - py;
      final lx = (x.length - palabra.length).abs();
      final ly = (y.length - palabra.length).abs();
      if (lx != ly) return lx - ly;
      return x.compareTo(y);
    });
    return (palabra: empatadas.first, distancia: mejor, empatadas: empatadas);
  }

  /// Corrige los tokens de tipo palabra. Las palabras válidas, los números y
  /// los signos no se tocan.
  ResultadoCorreccion corregir(List<Token> tokens) {
    final salida = <Token>[];
    final correcciones = <Correccion>[];
    final desconocidas = <Token>[];

    for (final token in tokens) {
      if (token.tipo != TipoToken.palabra || conoce(token.lexema)) {
        salida.add(token);
        continue;
      }
      final candidato = mejorCandidato(token.lexema);
      if (candidato == null) {
        salida.add(token);
        desconocidas.add(token);
        continue;
      }
      salida.add(token.corregido(candidato.palabra));
      correcciones.add(Correccion(
        original: token.lexema,
        corregida: candidato.palabra,
        distancia: candidato.distancia,
        posicion: token.posicion,
        empatadas: candidato.empatadas,
      ));
    }
    return ResultadoCorreccion(salida, correcciones, desconocidas);
  }
}
