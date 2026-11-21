/// Fase 4: análisis morfológico del verbo.
///
/// De una forma verbal ("vendran", "enviaron", "llegan") obtiene el lema, el
/// tiempo, la persona y el número. Las terminaciones y los irregulares NO
/// están en el código: salen de [ReglasMorfologicas] y [DatosVerbo]
/// (`datos/espanol/morfologia.json` y `verbos.json`).
///
/// Funciona al revés de como se conjuga a mano: al arrancar genera todas las
/// formas de todos los verbos conocidos aplicando las reglas, y guarda un
/// índice forma -> análisis. Ese mismo índice le da al corrector la lista de
/// formas válidas, para que no "corrija" un verbo bien escrito (ver
/// docs/interfaces-lexico.md).
///
/// El futuro con "ir a" ("van a llegar") son tres palabras, así que no lo
/// resuelve esta fase sino el parser, con la ayuda de [esAuxiliarFuturo].
library;

import 'arbol.dart';
import 'lexico_espanol.dart';

/// Un análisis posible de una forma verbal.
class AnalisisVerbal {
  /// El verbo al que pertenece la forma.
  final DatosVerbo verbo;

  /// Tiempo de la forma. null si es el infinitivo.
  final Tiempo? tiempo;

  /// Persona y número de la conjugación, en código de datos ("3p").
  /// null si es el infinitivo.
  final String? personaVerbo;

  const AnalisisVerbal(this.verbo, this.tiempo, this.personaVerbo);

  bool get esInfinitivo => tiempo == null;

  String get lema => verbo.lema;

  @override
  String toString() => esInfinitivo
      ? '$lema (infinitivo)'
      : '$lema, ${tiempo!.name}, $personaVerbo';
}

class AnalizadorMorfologico {
  final ReglasMorfologicas reglas;
  final Map<String, List<AnalisisVerbal>> _porForma = {};

  AnalizadorMorfologico(Iterable<DatosVerbo> verbos, this.reglas) {
    for (final v in verbos) {
      _generar(v);
    }
  }

  /// Construye la morfología leyendo verbos y reglas de [fuente].
  factory AnalizadorMorfologico.desde(FuenteLexicoEspanol fuente) =>
      AnalizadorMorfologico(fuente.verbos(), fuente.reglas());

  /// Genera todas las formas de [v] y las guarda en el índice.
  void _generar(DatosVerbo v) {
    if (v.lema.length < 2) {
      throw FormatException('lema demasiado corto: "${v.lema}"');
    }
    _agregar(v.lema, AnalisisVerbal(v, null, null));

    // Conjugación: las dos últimas letras del infinitivo (ar, er, ir).
    final conjugacion = v.lema.substring(v.lema.length - 2);
    final raiz = v.lema.substring(0, v.lema.length - 2);

    for (final MapEntry(key: tiempo, value: regla) in reglas.tiempos.entries) {
      final List<String> formas;
      final irregulares = v.irregular[tiempo.name];
      if (irregulares != null) {
        formas = irregulares;
      } else {
        final terminaciones = regla.terminaciones[conjugacion];
        if (terminaciones == null) continue;
        final base = regla.desdeInfinitivo ? v.lema : raiz;
        formas = [for (final t in terminaciones) '$base$t'];
      }
      if (formas.length != reglas.personas.length) {
        throw FormatException('"${v.lema}" en ${tiempo.name} tiene '
            '${formas.length} formas y se esperaban ${reglas.personas.length}');
      }
      for (var i = 0; i < formas.length; i++) {
        _agregar(formas[i], AnalisisVerbal(v, tiempo, reglas.personas[i]));
      }
    }
  }

  void _agregar(String forma, AnalisisVerbal analisis) =>
      _porForma.putIfAbsent(forma, () => []).add(analisis);

  /// Todos los análisis de [forma], ordenados por la prioridad de tiempos de
  /// los datos (los infinitivos al final). Vacío si no es un verbo conocido.
  ///
  /// Una forma puede tener varios: "llegamos" es presente y pasado; "fui" es
  /// de ser y de ir. El parser elige el que concuerda con el sujeto.
  List<AnalisisVerbal> analizar(String forma) {
    final todos = _porForma[forma];
    if (todos == null) return const [];
    return [
      for (final t in reglas.prioridadTiempos)
        ...todos.where((a) => a.tiempo == t),
      ...todos.where((a) =>
          a.tiempo != null && !reglas.prioridadTiempos.contains(a.tiempo)),
      ...todos.where((a) => a.esInfinitivo),
    ];
  }

  /// true si [forma] es alguna forma de un verbo conocido.
  bool esVerbo(String forma) => _porForma.containsKey(forma);

  /// true si [forma] es el infinitivo de un verbo conocido.
  bool esInfinitivo(String forma) =>
      analizar(forma).any((a) => a.esInfinitivo);

  /// Análisis de [forma] como auxiliar del futuro ("van" en "van a llegar"):
  /// el verbo marcado como auxiliar, en el tiempo que piden las reglas.
  AnalisisVerbal? comoAuxiliarFuturo(String forma) {
    for (final a in analizar(forma)) {
      if (a.verbo.auxiliarFuturo &&
          a.lema == reglas.auxiliarFuturo &&
          a.tiempo == reglas.tiempoAuxiliarFuturo) {
        return a;
      }
    }
    return null;
  }

  bool esAuxiliarFuturo(String forma) => comoAuxiliarFuturo(forma) != null;

  /// Todas las formas verbales conocidas, para el vocabulario del corrector.
  Iterable<String> get formasConocidas => _porForma.keys;
}
