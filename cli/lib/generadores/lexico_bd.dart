/// Léxico de Kethari y Ozh leído de la base de datos (bitácora K-11).
///
/// El árbol habla en CONCEPTOS (`VENIR`, `TIERRA`) y la base de datos guarda
/// el léxico por palabra española ("venir", "llegar", "tierra"). El puente es
/// el vocabulario del parser, que ya sabe qué palabras españolas expresan
/// cada concepto. Así no hay que cambiar las tablas.
///
/// Cada búsqueda consulta la BD en ese momento, con la versión vigente en
/// [fecha] (hoy si es null). Lo que entra con `cargar` (señales nuevas,
/// correcciones del manual) se usa en la siguiente traducción, sin
/// recompilar ni tocar archivos.
library;

import 'package:sqlite3/sqlite3.dart';

import '../lexico/normalizador.dart';
import '../sintactico/arbol.dart';
import '../sintactico/lexico_espanol.dart';
import 'fuente_kethari.dart';

/// Lengua alienígena: nombre de su columna en `lexico_version`.
enum Lengua { kethari, ozh }

class LexicoAlienigenaBd {
  final Database db;

  /// Fecha de consulta (`AAAA-MM-DD`). null = hoy.
  final String? fecha;

  /// Concepto -> formas españolas normalizadas, por categoría de la BD.
  final Map<String, Set<String>> _sustantivos;
  final Map<String, Set<String>> _verbos;
  final Map<String, Set<String>> _interrogativos;

  /// Código de rasgos (`1p`) -> formas españolas de ese pronombre.
  final Map<String, Set<String>> _pronombres;

  static const _normalizador = Normalizador();

  LexicoAlienigenaBd._(this.db, this.fecha, this._sustantivos, this._verbos,
      this._interrogativos, this._pronombres);

  /// [espanol] es la misma fuente de vocabulario que usa el parser.
  factory LexicoAlienigenaBd(Database db, FuenteLexicoEspanol espanol,
      {String? fecha}) {
    final sustantivos = <String, Set<String>>{};
    final interrogativos = <String, Set<String>>{};
    final pronombres = <String, Set<String>>{};
    final verbos = <String, Set<String>>{};

    void agregar(Map<String, Set<String>> m, String llave, String forma) =>
        m.putIfAbsent(llave, () => <String>{}).add(_n(forma));

    for (final e in espanol.palabras()) {
      final concepto = e.concepto;
      switch (e.categoria) {
        case Categoria.sustantivo when concepto != null:
          agregar(sustantivos, concepto, e.forma);
        case Categoria.interrogativo when concepto != null:
          agregar(interrogativos, concepto, e.forma);
        case Categoria.pronombre when e.persona != null && e.numero != null:
          agregar(pronombres, codigoRasgos(e.persona!, e.numero!), e.forma);
        default:
          break;
      }
    }
    for (final v in espanol.verbos()) {
      final concepto = v.concepto;
      if (concepto != null) agregar(verbos, concepto, v.lema);
    }
    return LexicoAlienigenaBd._(
        db, fecha, sustantivos, verbos, interrogativos, pronombres);
  }

  /// La misma fuente consultando otra fecha: "qué se habría transmitido".
  LexicoAlienigenaBd enFecha(String? otra) => LexicoAlienigenaBd._(
      db, otra, _sustantivos, _verbos, _interrogativos, _pronombres);

  static String _n(String s) => _normalizador.normalizarPalabra(s.trim());

  String _hoy() => DateTime.now().toIso8601String().substring(0, 10);

  String? sustantivo(Lengua l, String concepto) =>
      _buscar(l, 'sustantivo', _sustantivos[concepto]);

  String? verbo(Lengua l, String concepto) =>
      _buscar(l, 'verbo', _verbos[concepto]);

  String? interrogativo(Lengua l, String concepto) =>
      _buscar(l, 'interrogativo', _interrogativos[concepto]);

  String? pronombre(Lengua l, Persona persona, Numero numero) =>
      _buscar(l, 'pronombre', _pronombres[codigoRasgos(persona, numero)]);

  String? cifra(Lengua l, int valor) => _buscar(l, 'numero', {'$valor'});

  /// Palabra de la lengua [l] para cualquiera de las [formas] españolas.
  ///
  /// Si los sinónimos ("venir", "llegar") dan palabras distintas, por
  /// ejemplo porque una corrección cambió solo uno, no se elige al azar:
  /// devuelve null y el generador explica que no hay traducción (K-11).
  String? _buscar(Lengua l, String categoria, Set<String>? formas) {
    if (formas == null || formas.isEmpty) return null;
    final f = fecha ?? _hoy();
    final filas = db.select(
      'SELECT l.lema_es, v.${l.name} AS palabra '
      'FROM lexico l JOIN lexico_version v ON v.lexico_id = l.id '
      'WHERE l.categoria = ? AND v.vigente_desde <= ? '
      'AND (v.vigente_hasta IS NULL OR v.vigente_hasta > ?)',
      [categoria, f, f],
    );
    final encontradas = <String>{};
    for (final r in filas) {
      if (!formas.contains(_n(r['lema_es'] as String))) continue;
      final p = (r['palabra'] as String?)?.trim() ?? '';
      if (p.isNotEmpty) encontradas.add(p);
    }
    return encontradas.length == 1 ? encontradas.first : null;
  }
}
