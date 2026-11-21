/// Lectura de cantidades escritas en letras ("dos mil quince" -> 2015).
///
/// Trabaja sobre una lista de palabras ya separadas por el autómata y ya
/// corregidas, así que no usa expresiones regulares (decisión L-08).
/// Las palabras numéricas son reglas del español para leer cantidades, no
/// léxico de traducción (decisión L-06).
library;

/// Una cantidad en letras que se reemplazó por su valor.
class ConversionNumero {
  /// Palabras de la cantidad, ya corregidas: `dos mil quince`.
  final String texto;

  /// Valor numérico: `2015`.
  final int valor;

  /// Posición del primer token de la cantidad en el texto normalizado.
  final int posicion;

  const ConversionNumero(this.texto, this.valor, this.posicion);

  Map<String, Object?> toMap() =>
      {'texto': texto, 'valor': valor, 'posicion': posicion};

  @override
  String toString() => '"$texto" -> $valor';
}

/// Gramática que reconoce (hasta 999.999; el enunciado pide 9.999):
/// ```
/// <numero>    ::= "cero" | [<menor-mil>] "mil" [<menor-mil>] | <menor-mil>
/// <menor-mil> ::= [<centena>] [<decena> ["y" <unidad>] | <especial> | <unidad>]
/// ```
class ConvertidorNumeros {
  const ConvertidorNumeros();

  static const Map<String, int> _unidades = {
    'uno': 1, 'un': 1, 'una': 1, 'dos': 2, 'tres': 3, 'cuatro': 4,
    'cinco': 5, 'seis': 6, 'siete': 7, 'ocho': 8, 'nueve': 9,
  };

  /// Del 10 al 29, que en español se escriben en una sola palabra.
  static const Map<String, int> _especiales = {
    'diez': 10, 'once': 11, 'doce': 12, 'trece': 13, 'catorce': 14,
    'quince': 15, 'dieciseis': 16, 'diecisiete': 17, 'dieciocho': 18,
    'diecinueve': 19, 'veinte': 20, 'veintiuno': 21, 'veintiun': 21,
    'veintiuna': 21, 'veintidos': 22, 'veintitres': 23,
    'veinticuatro': 24, 'veinticinco': 25, 'veintiseis': 26,
    'veintisiete': 27, 'veintiocho': 28, 'veintinueve': 29,
  };

  static const Map<String, int> _decenas = {
    'treinta': 30, 'cuarenta': 40, 'cincuenta': 50, 'sesenta': 60,
    'setenta': 70, 'ochenta': 80, 'noventa': 90,
  };

  static const Map<String, int> _centenas = {
    'cien': 100, 'ciento': 100,
    'doscientos': 200, 'doscientas': 200,
    'trescientos': 300, 'trescientas': 300,
    'cuatrocientos': 400, 'cuatrocientas': 400,
    'quinientos': 500, 'quinientas': 500,
    'seiscientos': 600, 'seiscientas': 600,
    'setecientos': 700, 'setecientas': 700,
    'ochocientos': 800, 'ochocientas': 800,
    'novecientos': 900, 'novecientas': 900,
  };

  static const String _mil = 'mil';
  static const String _cero = 'cero';
  static const String _y = 'y';

  /// Todas las palabras que pueden formar una cantidad. El corrector las
  /// necesita en su vocabulario para arreglar "quinse" -> "quince" en vez de
  /// cambiarlas por otra palabra.
  static Set<String> get palabras => {
        ..._unidades.keys,
        ..._especiales.keys,
        ..._decenas.keys,
        ..._centenas.keys,
        _mil,
        _cero,
        _y,
      };

  /// Intenta leer una cantidad que empieza en `p[i]`. [p] son palabras
  /// seguidas, sin signos entre ellas.
  /// Devuelve el valor y el índice de la primera palabra que no se usó.
  ({int valor, int fin})? leer(List<String> p, int i) {
    if (p[i] == _cero) return (valor: 0, fin: i + 1);

    var total = 0;
    var ultimo = -1; // índice de la última palabra usada
    var usadas = 0;

    final bajo = _leerMenorQueMil(p, i);
    int? cursor = i;
    if (bajo != null) {
      total = bajo.valor;
      ultimo = bajo.ultimo;
      usadas += bajo.usadas;
      cursor = _siguiente(p, ultimo);
    }

    if (cursor != null && p[cursor] == _mil) {
      total = (bajo?.valor ?? 1) * 1000;
      ultimo = cursor;
      usadas++;
      final resto = _siguiente(p, cursor);
      if (resto != null) {
        final bajo2 = _leerMenorQueMil(p, resto);
        if (bajo2 != null) {
          total += bajo2.valor;
          ultimo = bajo2.ultimo;
          usadas += bajo2.usadas;
        }
      }
    }

    if (ultimo < 0) return null;
    // "un" / "una" sueltos son artículos ("una nave"), no la cantidad 1.
    // Ver bitácora, decisión L-02.
    if (usadas == 1 && (p[i] == 'un' || p[i] == 'una')) return null;
    return (valor: total, fin: ultimo + 1);
  }

  int? _siguiente(List<String> p, int k) => k + 1 < p.length ? k + 1 : null;

  /// Lee una cantidad entre 1 y 999 que empieza en `p[k]`.
  ({int valor, int ultimo, int usadas})? _leerMenorQueMil(
      List<String> p, int k) {
    var valor = 0;
    var ultimo = -1;
    var usadas = 0;
    int? c = k;

    final centena = _centenas[p[k]];
    if (centena != null) {
      valor += centena;
      ultimo = k;
      usadas++;
      c = _siguiente(p, k);
    }

    if (c != null) {
      final palabra = p[c];
      final especial = _especiales[palabra];
      final decena = _decenas[palabra];
      final unidad = _unidades[palabra];
      if (especial != null) {
        valor += especial;
        ultimo = c;
        usadas++;
      } else if (decena != null) {
        valor += decena;
        ultimo = c;
        usadas++;
        // "treinta y dos": la "y" solo se usa si le sigue una unidad.
        final y = _siguiente(p, c);
        final u = y == null ? null : _siguiente(p, y);
        if (y != null && p[y] == _y && u != null) {
          final unidad2 = _unidades[p[u]];
          if (unidad2 != null) {
            valor += unidad2;
            ultimo = u;
            usadas += 2;
          }
        }
      } else if (unidad != null) {
        valor += unidad;
        ultimo = c;
        usadas++;
      }
    }

    if (usadas == 0) return null;
    return (valor: valor, ultimo: ultimo, usadas: usadas);
  }
}
