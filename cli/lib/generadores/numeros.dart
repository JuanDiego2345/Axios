/// Escritura de cantidades en las lenguas alienígenas (manual, sección 3.2).
///
/// "En las dos lenguas, las cantidades de más de una cifra se forman
/// encadenando cifras con guiones." La diferencia es la base: Ozh tiene
/// cifras del 0 al 9 (base 10) y Kethari solo del 0 al 5, y las señales
/// muestran que cuenta en base 6 (`ra-sel` = 15, `ti-vo` = 6). Ver bitácora
/// K-05.
///
/// Aquí solo está el algoritmo. La base, el separador y la palabra de cada
/// cifra salen de los datos de cada lengua.
library;

/// Cómo se escriben las cantidades en una lengua.
class ReglasNumero {
  /// Cuántas cifras distintas tiene la lengua (6 en Kethari, 10 en Ozh).
  final int base;

  /// Lo que une las cifras: `-`.
  final String separador;

  const ReglasNumero({required this.base, required this.separador});
}

/// Cifras de [n] en [base], de la más significativa a la menos:
/// `cifras(15, 6)` -> `[2, 3]`.
List<int> cifras(int n, int base) {
  if (n < 0) throw ArgumentError.value(n, 'n', 'no hay cantidades negativas');
  if (base < 2) throw ArgumentError.value(base, 'base', 'debe ser al menos 2');
  if (n == 0) return const [0];
  final salida = <int>[];
  var resto = n;
  while (resto > 0) {
    salida.add(resto % base);
    resto ~/= base;
  }
  return salida.reversed.toList();
}

/// Resultado de escribir una cantidad.
class NumeroEscrito {
  /// La cantidad escrita (`ra-sel`). `null` si falta alguna cifra.
  final String? texto;

  /// Cifras de la base que no tienen palabra conocida.
  final List<int> cifrasDesconocidas;

  /// Las cifras usadas, para la traza: `[2, 3]`.
  final List<int> cifrasUsadas;

  const NumeroEscrito(this.texto, this.cifrasDesconocidas, this.cifrasUsadas);

  bool get ok => texto != null;
}

/// Escribe [n] con las [reglas] de una lengua, buscando cada cifra con
/// [palabraCifra]. Si una cifra no tiene palabra, no se inventa.
NumeroEscrito escribirNumero(
  int n,
  ReglasNumero reglas,
  String? Function(int cifra) palabraCifra,
) {
  final usadas = cifras(n, reglas.base);
  final palabras = <String>[];
  final desconocidas = <int>[];
  for (final c in usadas) {
    final p = palabraCifra(c);
    if (p == null || p.isEmpty) {
      if (!desconocidas.contains(c)) desconocidas.add(c);
    } else {
      palabras.add(p);
    }
  }
  if (desconocidas.isNotEmpty) {
    return NumeroEscrito(null, desconocidas, usadas);
  }
  return NumeroEscrito(palabras.join(reglas.separador), const [], usadas);
}
