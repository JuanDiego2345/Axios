/// Conversión de cantidades escritas en letras a cifras (0 a 9.999 y más).
///
/// Forma parte del normalizador, por eso puede usar expresiones regulares.
/// Las palabras numéricas son reglas del español para leer cantidades, no
/// léxico de traducción: el léxico Kethari/Ozh vive en la base de datos.
library;

/// Una cantidad en letras que se reemplazó por su valor.
class ConversionNumero {
  /// Texto original de la cantidad, por ejemplo `dos mil quince`.
  final String texto;

  /// Valor numérico, por ejemplo `2015`.
  final int valor;

  const ConversionNumero(this.texto, this.valor);

  @override
  String toString() => '"$texto" -> $valor';
}

/// Convierte cantidades en letras dentro de un texto ya en minúsculas y sin
/// tildes.
///
/// Gramática que reconoce (hasta 999.999, el enunciado pide 9.999):
/// ```
/// <numero>      ::= "cero" | [<menor-mil>] "mil" [<menor-mil>] | <menor-mil>
/// <menor-mil>   ::= [<centena>] [<decena> ["y" <unidad>] | <especial> | <unidad>]
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

  /// Parte el texto en trozos alternos de letras y de no-letras.
  static final RegExp _trozos = RegExp(r'[a-zñ]+|[^a-zñ]+');
  static final RegExp _soloLetras = RegExp(r'^[a-zñ]+$');
  static final RegExp _soloEspacios = RegExp(r'^ +$');

  /// Devuelve el texto con las cantidades en cifras y la lista de cambios.
  ({String texto, List<ConversionNumero> conversiones}) convertir(
      String texto) {
    final t = _trozos.allMatches(texto).map((m) => m.group(0)!).toList();
    final salida = StringBuffer();
    final conversiones = <ConversionNumero>[];
    var i = 0;
    while (i < t.length) {
      final numero = _leerNumero(t, i);
      if (numero == null) {
        salida.write(t[i]);
        i++;
      } else {
        salida.write(numero.valor);
        conversiones.add(
            ConversionNumero(t.sublist(i, numero.fin).join(), numero.valor));
        i = numero.fin;
      }
    }
    return (texto: salida.toString(), conversiones: conversiones);
  }

  bool _esPalabra(String trozo) => _soloLetras.hasMatch(trozo);

  /// Índice de la palabra que sigue a la palabra en [k], si entre ambas solo
  /// hay espacios. Si hay un signo de por medio ("dos, tres") devuelve null.
  int? _siguiente(List<String> t, int k) {
    if (k + 2 < t.length &&
        _soloEspacios.hasMatch(t[k + 1]) &&
        _esPalabra(t[k + 2])) {
      return k + 2;
    }
    return null;
  }

  /// Intenta leer una cantidad que empieza en el trozo [i].
  /// Devuelve su valor y el índice del primer trozo que no se consumió.
  ({int valor, int fin})? _leerNumero(List<String> t, int i) {
    if (!_esPalabra(t[i])) return null;
    if (t[i] == _cero) return (valor: 0, fin: i + 1);

    var total = 0;
    var ultimo = -1; // índice de la última palabra consumida
    var palabras = 0;

    final bajo = _leerMenorQueMil(t, i);
    int? cursor = i;
    if (bajo != null) {
      total = bajo.valor;
      ultimo = bajo.ultimo;
      palabras += bajo.palabras;
      cursor = _siguiente(t, ultimo);
    }

    if (cursor != null && t[cursor] == _mil) {
      total = (bajo?.valor ?? 1) * 1000;
      ultimo = cursor;
      palabras++;
      final resto = _siguiente(t, cursor);
      if (resto != null) {
        final bajo2 = _leerMenorQueMil(t, resto);
        if (bajo2 != null) {
          total += bajo2.valor;
          ultimo = bajo2.ultimo;
          palabras += bajo2.palabras;
        }
      }
    }

    if (ultimo < 0) return null;
    // "un" / "una" sueltos son artículos ("una nave"), no la cantidad 1.
    // Ver bitácora del léxico, decisión L-02.
    if (palabras == 1 && (t[i] == 'un' || t[i] == 'una')) return null;
    return (valor: total, fin: ultimo + 1);
  }

  /// Lee una cantidad entre 1 y 999 que empieza en la palabra [k].
  ({int valor, int ultimo, int palabras})? _leerMenorQueMil(
      List<String> t, int k) {
    var valor = 0;
    var ultimo = -1;
    var palabras = 0;
    int? c = k;

    final centena = _centenas[t[k]];
    if (centena != null) {
      valor += centena;
      ultimo = k;
      palabras++;
      c = _siguiente(t, k);
    }

    if (c != null) {
      final palabra = t[c];
      final especial = _especiales[palabra];
      final decena = _decenas[palabra];
      final unidad = _unidades[palabra];
      if (especial != null) {
        valor += especial;
        ultimo = c;
        palabras++;
      } else if (decena != null) {
        valor += decena;
        ultimo = c;
        palabras++;
        // "treinta y dos": la "y" solo se consume si le sigue una unidad.
        final y = _siguiente(t, c);
        final u = y == null ? null : _siguiente(t, y);
        if (y != null && t[y] == _y && u != null) {
          final unidad2 = _unidades[t[u]];
          if (unidad2 != null) {
            valor += unidad2;
            ultimo = u;
            palabras += 2;
          }
        }
      } else if (unidad != null) {
        valor += unidad;
        ultimo = c;
        palabras++;
      }
    }

    if (palabras == 0) return null;
    return (valor: valor, ultimo: ultimo, palabras: palabras);
  }
}
