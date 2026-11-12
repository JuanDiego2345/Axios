/// Fase 1: normalizador.
///
/// Pasa el texto a minúsculas, quita tildes (conserva la ñ), descarta signos
/// que no aportan a la traducción y convierte cantidades en letras a cifras.
/// Es la única fase donde el enunciado permite expresiones regulares.
library;

import 'numeros_texto.dart';

/// Resultado de normalizar una pregunta.
class ResultadoNormalizacion {
  /// Texto tal como llegó.
  final String original;

  /// Texto normalizado, listo para el autómata léxico.
  final String texto;

  /// Cantidades en letras que se convirtieron a cifras.
  final List<ConversionNumero> numerosConvertidos;

  const ResultadoNormalizacion(
      this.original, this.texto, this.numerosConvertidos);
}

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

  /// Normaliza [texto] y devuelve también qué cantidades se convirtieron.
  ResultadoNormalizacion procesar(String texto) {
    var t = normalizarPalabra(texto);
    t = t.replaceAll(_signosDescartados, ' ');

    String antes;
    do {
      antes = t;
      t = t.replaceAllMapped(_separadorMiles, (m) => '${m[1]}${m[2]}');
    } while (t != antes);

    t = t.replaceAll(_espacios, ' ').trim();

    final numeros = const ConvertidorNumeros().convertir(t);
    return ResultadoNormalizacion(texto, numeros.texto, numeros.conversiones);
  }

  /// Atajo que devuelve solo el texto normalizado.
  String normalizar(String texto) => procesar(texto).texto;

  /// Solo minúsculas y sin tildes. Lo usa también el corrector para
  /// normalizar el vocabulario que viene de la base de datos.
  String normalizarPalabra(String texto) {
    final sb = StringBuffer();
    for (final ch in texto.toLowerCase().split('')) {
      sb.write(_sinTilde[ch] ?? ch);
    }
    return sb.toString();
  }
}
