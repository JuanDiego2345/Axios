/// Vocabulario y reglas del español que usan la morfología y el parser.
///
/// Nada de esto está escrito en el código: llega por una
/// [FuenteLexicoEspanol]. Hoy la fuente son los JSON de `datos/espanol/`
/// ([FuenteLexicoJson]); cuando esté la base de datos, solo
/// hay que escribir otra clase que implemente [FuenteLexicoEspanol] y leer de
/// SQLite. El parser no cambia.
library;

import 'dart:convert';
import 'dart:io';

import '../lexico/normalizador.dart';
import 'arbol.dart';

/// Clase de palabra (no son verbos: los verbos van en [DatosVerbo]).
enum Categoria {
  pronombre,
  posesivo,
  articulo,
  sustantivo,
  interrogativo,
  negacion,
  preposicion,

  /// Pronombre pegado antes del verbo: "no LOS vimos", "NOS escuchan".
  clitico,

  /// Adverbio de tiempo: antes, después, ya.
  adverbio,

  /// Determinante negativo: ningún, ninguna.
  negativo,
}

/// Persona y número a partir de los códigos de los datos ("2p" -> ustedes).
({Persona persona, Numero numero}) rasgosDesdeCodigo(String codigo) {
  if (codigo.length != 2) {
    throw FormatException('código de persona inválido: "$codigo"');
  }
  final persona = switch (codigo[0]) {
    '1' => Persona.primera,
    '2' => Persona.segunda,
    '3' => Persona.tercera,
    _ => throw FormatException('código de persona inválido: "$codigo"'),
  };
  final numero = switch (codigo[1]) {
    's' => Numero.singular,
    'p' => Numero.plural,
    _ => throw FormatException('código de persona inválido: "$codigo"'),
  };
  return (persona: persona, numero: numero);
}

/// Código de datos a partir de persona y número (inverso de
/// [rasgosDesdeCodigo]).
String codigoDesdeRasgos(Persona persona, Numero numero) =>
    '${persona.index + 1}${numero == Numero.singular ? 's' : 'p'}';

Numero _numeroDesdeTexto(String texto) => switch (texto) {
      'singular' => Numero.singular,
      'plural' => Numero.plural,
      _ => throw FormatException('número inválido: "$texto"'),
    };

/// Una palabra del vocabulario con su información gramatical.
class EntradaLexica {
  /// Forma normalizada (minúsculas, sin tildes), igual que llegan los tokens.
  final String forma;
  final Categoria categoria;

  /// Concepto para sustantivos e interrogativos (`NAVE`, `CUANDO`).
  final String? concepto;

  /// Persona del significado: pronombres, posesivos y clíticos.
  final Persona? persona;

  /// Número: pronombres, posesivos, artículos y sustantivos.
  final Numero? numero;

  /// Persona y número que debe tener el verbo cuando esta palabra es el
  /// sujeto. "ustedes" es 2ª persona pero el verbo va en 3ª plural
  /// ("ustedes llegan"); "quién" pide 3ª singular.
  final String? concordancia;

  /// Papel de un interrogativo.
  final RolInterrogativo? rol;

  /// Adverbios: tiempo que se prefiere cuando el verbo es ambiguo.
  final Tiempo? tiempo;

  /// Adverbios: false si el manual no tiene cómo decirlo ("ya").
  final bool traduce;

  const EntradaLexica({
    required this.forma,
    required this.categoria,
    this.concepto,
    this.persona,
    this.numero,
    this.concordancia,
    this.rol,
    this.tiempo,
    this.traduce = true,
  });

  @override
  String toString() => '$forma:${categoria.name}'
      '${concepto != null ? '($concepto)' : ''}';
}

/// Un verbo tal como viene en los datos.
class DatosVerbo {
  /// Infinitivo, normalizado: `llegar`.
  final String lema;

  /// Concepto que se traduce. null si el manual no lo tiene (`ir`).
  final String? concepto;

  /// Si suele llevar objeto ("queremos paz").
  final bool transitivo;

  /// Si sirve de auxiliar del futuro ("van a llegar").
  final bool auxiliarFuturo;

  /// Formas irregulares por tiempo, en el orden de las personas de las
  /// reglas. Solo los tiempos que no siguen la regla.
  final Map<String, List<String>> irregular;

  const DatosVerbo({
    required this.lema,
    required this.concepto,
    required this.transitivo,
    this.auxiliarFuturo = false,
    this.irregular = const {},
  });
}

/// Cómo se forma un tiempo verbal regular.
class ReglaTiempo {
  /// true: la terminación se pega al infinitivo (futuro: llegar-é).
  /// false: se pega a la raíz (presente: lleg-an).
  final bool desdeInfinitivo;

  /// Terminaciones por conjugación (`ar`, `er`, `ir`), en el orden de las
  /// personas.
  final Map<String, List<String>> terminaciones;

  const ReglaTiempo(
      {required this.desdeInfinitivo, required this.terminaciones});
}

/// Todas las reglas de morfología que vienen en los datos.
class ReglasMorfologicas {
  /// Orden de las personas en las listas de terminaciones ("1s", "2s"...).
  final List<String> personas;

  /// Reglas por tiempo. Las llaves son los nombres de [Tiempo].
  final Map<Tiempo, ReglaTiempo> tiempos;

  /// Tiempo preferido cuando una forma es ambigua.
  final List<Tiempo> prioridadTiempos;

  /// Futuro con "ir a": lema del auxiliar, tiempo que debe tener y palabra
  /// de enlace.
  final String auxiliarFuturo;
  final Tiempo tiempoAuxiliarFuturo;
  final String enlaceFuturo;

  /// Sujeto que se deduce cuando no está escrito: código de la persona del
  /// verbo -> código del sujeto. Uno para preguntas y otro para
  /// afirmaciones.
  final Map<String, String> sujetoOmitidoPregunta;
  final Map<String, String> sujetoOmitidoAfirmacion;

  const ReglasMorfologicas({
    required this.personas,
    required this.tiempos,
    required this.prioridadTiempos,
    required this.auxiliarFuturo,
    required this.tiempoAuxiliarFuturo,
    required this.enlaceFuturo,
    required this.sujetoOmitidoPregunta,
    required this.sujetoOmitidoAfirmacion,
  });
}

/// De dónde salen el vocabulario y las reglas del español.
abstract interface class FuenteLexicoEspanol {
  List<EntradaLexica> palabras();
  List<DatosVerbo> verbos();
  ReglasMorfologicas reglas();
}

/// Lee el vocabulario y las reglas de los JSON de una carpeta
/// (`datos/espanol` por defecto).
class FuenteLexicoJson implements FuenteLexicoEspanol {
  final String carpeta;
  final Normalizador _normalizador;

  FuenteLexicoJson([this.carpeta = 'datos/espanol'])
      : _normalizador = const Normalizador();

  Map<String, dynamic> _leer(String archivo) {
    final f = File('$carpeta/$archivo');
    if (!f.existsSync()) {
      throw FileSystemException('no se encontró el archivo de datos', f.path);
    }
    return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  }

  String _n(String palabra) => _normalizador.normalizarPalabra(palabra);

  List<Map<String, dynamic>> _lista(Map<String, dynamic> json, String llave) =>
      (json[llave] as List? ?? const []).cast<Map<String, dynamic>>();

  @override
  List<EntradaLexica> palabras() {
    final json = _leer('palabras.json');
    final salida = <EntradaLexica>[];

    for (final p in _lista(json, 'pronombres')) {
      final r = rasgosDesdeCodigo(p['rasgos'] as String);
      salida.add(EntradaLexica(
        forma: _n(p['forma'] as String),
        categoria: Categoria.pronombre,
        persona: r.persona,
        numero: r.numero,
        concordancia: p['concuerda'] as String,
      ));
    }
    for (final p in _lista(json, 'posesivos')) {
      final r = rasgosDesdeCodigo(p['rasgos'] as String);
      salida.add(EntradaLexica(
        forma: _n(p['forma'] as String),
        categoria: Categoria.posesivo,
        persona: r.persona,
        numero: r.numero,
      ));
    }
    for (final a in _lista(json, 'articulos')) {
      salida.add(EntradaLexica(
        forma: _n(a['forma'] as String),
        categoria: Categoria.articulo,
        numero: _numeroDesdeTexto(a['numero'] as String),
      ));
    }
    for (final s in _lista(json, 'sustantivos')) {
      final concepto = s['concepto'] as String;
      for (final (llave, numero) in [
        ('singular', Numero.singular),
        ('plural', Numero.plural),
      ]) {
        final forma = s[llave] as String?;
        if (forma == null) continue;
        salida.add(EntradaLexica(
          forma: _n(forma),
          categoria: Categoria.sustantivo,
          concepto: concepto,
          numero: numero,
        ));
      }
    }
    for (final i in _lista(json, 'interrogativos')) {
      salida.add(EntradaLexica(
        forma: _n(i['forma'] as String),
        categoria: Categoria.interrogativo,
        concepto: i['concepto'] as String,
        rol: RolInterrogativo.values.byName(i['rol'] as String),
        concordancia: i['concuerda'] as String?,
      ));
    }
    for (final n in (json['negaciones'] as List? ?? const []).cast<String>()) {
      salida.add(EntradaLexica(forma: _n(n), categoria: Categoria.negacion));
    }
    for (final p
        in (json['preposiciones'] as List? ?? const []).cast<String>()) {
      salida.add(EntradaLexica(forma: _n(p), categoria: Categoria.preposicion));
    }
    for (final c in _lista(json, 'cliticos')) {
      final r = rasgosDesdeCodigo(c['rasgos'] as String);
      salida.add(EntradaLexica(
        forma: _n(c['forma'] as String),
        categoria: Categoria.clitico,
        persona: r.persona,
        numero: r.numero,
      ));
    }
    for (final a in _lista(json, 'adverbios')) {
      final prefiere = a['prefiere'] as String?;
      salida.add(EntradaLexica(
        forma: _n(a['forma'] as String),
        categoria: Categoria.adverbio,
        tiempo: prefiere == null ? null : Tiempo.values.byName(prefiere),
        traduce: a['traduce'] as bool? ?? true,
      ));
    }
    for (final d in _lista(json, 'negativos')) {
      salida.add(EntradaLexica(
        forma: _n(d['forma'] as String),
        categoria: Categoria.negativo,
        numero: _numeroDesdeTexto(d['numero'] as String),
      ));
    }
    return salida;
  }

  @override
  List<DatosVerbo> verbos() {
    final json = _leer('verbos.json');
    return [
      for (final v in _lista(json, 'verbos'))
        DatosVerbo(
          lema: _n(v['lema'] as String),
          concepto: v['concepto'] as String?,
          transitivo: v['transitivo'] as bool? ?? false,
          auxiliarFuturo: v['auxiliarFuturo'] as bool? ?? false,
          irregular: {
            for (final e
                in ((v['irregular'] as Map?) ?? const {}).entries)
              e.key as String: [
                for (final f in (e.value as List).cast<String>()) _n(f)
              ],
          },
        ),
    ];
  }

  @override
  ReglasMorfologicas reglas() {
    final json = _leer('morfologia.json');
    final tiempos = <Tiempo, ReglaTiempo>{};
    final t = json['tiempos'] as Map<String, dynamic>;
    for (final e in t.entries) {
      final regla = e.value as Map<String, dynamic>;
      tiempos[Tiempo.values.byName(e.key)] = ReglaTiempo(
        desdeInfinitivo: regla['base'] == 'infinitivo',
        terminaciones: {
          for (final c in ['ar', 'er', 'ir'])
            if (regla[c] != null)
              c: [for (final f in (regla[c] as List).cast<String>()) _n(f)],
        },
      );
    }
    final perifrasis = json['perifrasisFuturo'] as Map<String, dynamic>;
    final omitido = json['sujetoOmitido'] as Map<String, dynamic>;
    return ReglasMorfologicas(
      personas: (json['personas'] as List).cast<String>(),
      tiempos: tiempos,
      prioridadTiempos: [
        for (final p in (json['prioridadTiempos'] as List).cast<String>())
          Tiempo.values.byName(p),
      ],
      auxiliarFuturo: _n(perifrasis['auxiliar'] as String),
      tiempoAuxiliarFuturo:
          Tiempo.values.byName(perifrasis['tiempoAuxiliar'] as String),
      enlaceFuturo: _n(perifrasis['enlace'] as String),
      sujetoOmitidoPregunta:
          (omitido['pregunta'] as Map).cast<String, String>(),
      sujetoOmitidoAfirmacion:
          (omitido['afirmacion'] as Map).cast<String, String>(),
    );
  }
}

/// Vocabulario listo para consultar: forma -> todas sus entradas.
///
/// Una forma puede tener varias: "el" es artículo y pronombre (él), "tu" es
/// posesivo y pronombre (tú). El parser decide cuál por el contexto.
///
/// Las formas de varias palabras ("territorio reclamado", "ser vivo") se
/// guardan aparte, por su primera palabra, y se buscan con [compuesto].
class LexicoEspanol {
  final Map<String, List<EntradaLexica>> _porForma = {};
  final Map<String, List<EntradaLexica>> _compuestos = {};
  final Set<String> _partes = {};

  LexicoEspanol(Iterable<EntradaLexica> entradas) {
    for (final e in entradas) {
      final palabras = e.forma.split(' ');
      if (palabras.length > 1) {
        _compuestos.putIfAbsent(palabras.first, () => []).add(e);
        _partes.addAll(palabras);
      } else {
        _porForma.putIfAbsent(e.forma, () => []).add(e);
      }
    }
  }

  /// La forma de varias palabras más larga con la que empiezan [palabras]
  /// ("territorios reclamados llegaron" -> "territorios reclamados", 2), o
  /// null si no empiezan con ninguna.
  ({EntradaLexica entrada, int largo})? compuesto(List<String> palabras) {
    if (palabras.isEmpty) return null;
    ({EntradaLexica entrada, int largo})? mejor;
    for (final e in _compuestos[palabras.first] ?? const <EntradaLexica>[]) {
      final partes = e.forma.split(' ');
      if (partes.length > palabras.length) continue;
      var coincide = true;
      for (var k = 0; k < partes.length; k++) {
        if (partes[k] != palabras[k]) {
          coincide = false;
          break;
        }
      }
      if (coincide && (mejor == null || partes.length > mejor.largo)) {
        mejor = (entrada: e, largo: partes.length);
      }
    }
    return mejor;
  }

  /// Todas las entradas de [forma] (vacío si no se conoce).
  List<EntradaLexica> buscar(String forma) => _porForma[forma] ?? const [];

  /// La entrada de [forma] con esa [categoria], o null.
  EntradaLexica? como(String forma, Categoria categoria) {
    for (final e in buscar(forma)) {
      if (e.categoria == categoria) return e;
    }
    return null;
  }

  bool es(String forma, Categoria categoria) => como(forma, categoria) != null;

  /// Todas las palabras conocidas (para el vocabulario del corrector),
  /// incluidas las que forman parte de una forma de varias palabras.
  Iterable<String> get formas => {..._porForma.keys, ..._partes};
}
