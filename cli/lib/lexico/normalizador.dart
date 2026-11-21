/// Fase 1: normalizador.
///
/// Trabaja en dos momentos (decisión L-07):
/// 1. [Normalizador.normalizar], sobre el texto y ANTES del autómata:
///    minúsculas, tildes (conserva la ñ), signos y separadores de miles.
///    Es la única parte del proyecto que usa expresiones regulares
///    (decisión L-08).
/// 2. [Normalizador.normalizarNumeros], sobre los tokens y DESPUÉS del
///    corrector: convierte cantidades en letras a cifras. Va después para que
///    "quinse naves" se corrija primero a "quince" y luego se lea como 15.
library;

import 'numeros_texto.dart';
import 'token.dart';

class Normalizador {
  const Normalizador();

  /// Vocales con tilde o diéresis y su forma simple. La ñ NO está aquí:
  /// se conserva porque "año" y "ano" son palabras distintas (decisión L-01).
  static const Map<String, String> _sinTilde = {
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a',
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
  };

  /// Signos que se descartan (se reemplazan por espacio). Se conservan
  /// ¿ ? , . porque el parser los usa. Cualquier otro carácter raro (@, #, ʔ)
  /// se deja pasar para que el autómata lo reporte como desconocido.
  static final RegExp _signosDescartados =
      RegExp(r'''[¡!;:"'«»()\[\]{}…_/\\-]''');

  /// Separador de miles: "1.500" o "1,500" -> "1500".
  static final RegExp _separadorMiles = RegExp(r'(\d{1,3})[.,](\d{3})(?!\d)');

  static final RegExp _espacios = RegExp(r'\s+');

  /// "¿¿" o "¿ ¿" seguidos.
  static final RegExp _abreRepetido = RegExp(r'¿(\s*¿)+');

  /// "??" o "? ?" seguidos.
  static final RegExp _cierraRepetido = RegExp(r'\?(\s*\?)+');

  /// Normaliza el texto antes del autómata. No toca las cantidades en letras:
  /// esas se convierten con [normalizarNumeros] después del corrector.
  /// Si se pasa [ajustes], anota ahí cada arreglo de signos que hizo.
  String normalizar(String texto, {List<String>? ajustes}) {
    var t = normalizarPalabra(texto);
    t = t.replaceAll(_signosDescartados, ' ');

    String antes;
    do {
      antes = t;
      t = t.replaceAllMapped(_separadorMiles, (m) => '${m[1]}${m[2]}');
    } while (t != antes);

    t = t.replaceAll(_espacios, ' ').trim();
    return _ajustarSignos(t, ajustes);
  }

  /// Arregla signos de interrogación mal puestos (decisión L-10). Los signos
  /// que faltan no se inventan: el parser decide si es pregunta.
  String _ajustarSignos(String t, List<String>? ajustes) {
    var r = t;

    // Teclado sin "¿": "?cuando llegan?" -> "¿cuando llegan?".
    if (r.length > 1 && r.startsWith('?')) {
      r = '¿${r.substring(1)}';
      ajustes?.add('"?" al inicio cambiado por "¿"');
    }
    // Signos invertidos al final: "cuando llegan¿" -> "cuando llegan?".
    if (r.length > 1 && r.endsWith('¿')) {
      r = '${r.substring(0, r.length - 1)}?';
      ajustes?.add('"¿" al final cambiado por "?"');
    }

    final sinAbreRepetido = r.replaceAll(_abreRepetido, '¿');
    if (sinAbreRepetido != r) ajustes?.add('"¿" repetidos unidos en uno');
    r = sinAbreRepetido;

    final sinCierraRepetido = r.replaceAll(_cierraRepetido, '?');
    if (sinCierraRepetido != r) ajustes?.add('"?" repetidos unidos en uno');
    return sinCierraRepetido;
  }

  /// Solo minúsculas y sin tildes. Lo usan también el corrector y el parser
  /// para normalizar el vocabulario que viene de los datos.
  String normalizarPalabra(String texto) {
    final sb = StringBuffer();
    for (final ch in texto.toLowerCase().split('')) {
      sb.write(_sinTilde[ch] ?? ch);
    }
    return sb.toString();
  }

  /// Reemplaza cada cantidad en letras por un solo token [TipoToken.numero].
  ///
  /// Solo une palabras seguidas: un signo entre ellas ("dos, tres") corta la
  /// cantidad. El token nuevo toma la posición de la primera palabra y guarda
  /// en `original` cómo se escribió ("dos mil quinse").
  ({List<Token> tokens, List<ConversionNumero> conversiones})
      normalizarNumeros(List<Token> tokens,
          {ConvertidorNumeros convertidor = const ConvertidorNumeros()}) {
    final salida = <Token>[];
    final conversiones = <ConversionNumero>[];

    var i = 0;
    while (i < tokens.length) {
      if (tokens[i].tipo != TipoToken.palabra) {
        salida.add(tokens[i]);
        i++;
        continue;
      }

      // Tramo de palabras seguidas: tokens[i] .. tokens[fin - 1].
      var fin = i;
      while (fin < tokens.length && tokens[fin].tipo == TipoToken.palabra) {
        fin++;
      }
      final tramo = tokens.sublist(i, fin);
      final palabras = tramo.map((t) => t.lexema).toList();

      var k = 0;
      while (k < tramo.length) {
        final numero = convertidor.leer(palabras, k);
        if (numero == null) {
          salida.add(tramo[k]);
          k++;
          continue;
        }
        final usados = tramo.sublist(k, numero.fin);
        salida.add(Token(
          tipo: TipoToken.numero,
          lexema: '${numero.valor}',
          posicion: usados.first.posicion,
          valor: numero.valor,
          original: usados.map((t) => t.original ?? t.lexema).join(' '),
        ));
        conversiones.add(ConversionNumero(
            palabras.sublist(k, numero.fin).join(' '),
            numero.valor,
            usados.first.posicion));
        k = numero.fin;
      }
      i = fin;
    }
    return (tokens: salida, conversiones: conversiones);
  }
}
