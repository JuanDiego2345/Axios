/// De dónde saca el generador de Ozh las palabras y las reglas.
///
/// Como en Kethari (bitácora K-04), el generador no conoce ninguna palabra
/// ni partícula: todo sale de los datos. [FuenteOzhJson] lee
/// `datos/ozh/`; [FuenteOzhBd] (fuente_bd.dart) saca las palabras de la BD
/// y las reglas de aquí.
library;

import 'dart:convert';
import 'dart:io';

import '../sintactico/arbol.dart';
import 'numeros.dart';

abstract interface class FuenteOzh {
  String? pronombre(Persona persona, Numero numero);
  String? sustantivo(String concepto);
  String? verbo(String concepto);
  String? interrogativo(String concepto);
  String? cifra(int c);
  ReglasNumero get reglasNumero;

  /// Marcador de pasado al principio de la oración: `ʔoka`.
  String get tiempoPasado;

  /// Marcador de futuro al principio de la oración: `venu`.
  String get tiempoFuturo;

  /// Palabra de negación delante del verbo: `ne`.
  String get negacion;

  /// Prefijo del verbo en las preguntas, sin guion: `ʔa`.
  String get prefijoPregunta;

  /// Partícula obligatoria después del verbo (`zi`, `mar`, `tho`), según las
  /// reglas de los datos (bitácora O-01). null si ninguna regla aplica.
  String? particulaPara({
    required Persona persona,
    required Numero numero,
    required Tiempo tiempo,
  });
}

/// Una regla de partícula: condiciones y la partícula que da.
class ReglaParticula {
  final Map<String, String> condiciones;
  final String particula;

  const ReglaParticula(this.condiciones, this.particula);

  bool aplica(Persona persona, Numero numero, Tiempo tiempo) {
    final valores = {
      'persona': persona.name,
      'numero': numero.name,
      'tiempo': tiempo.name,
    };
    return condiciones.entries.every((c) => valores[c.key] == c.value);
  }
}

class FuenteOzhJson implements FuenteOzh {
  final Map<String, String> _pronombres;
  final Map<String, String> _sustantivos;
  final Map<String, String> _verbos;
  final Map<String, String> _interrogativos;
  final Map<String, String> _cifras;

  @override
  final ReglasNumero reglasNumero;
  @override
  final String tiempoPasado;
  @override
  final String tiempoFuturo;
  @override
  final String negacion;
  @override
  final String prefijoPregunta;

  final List<ReglaParticula> reglasParticula;

  FuenteOzhJson._(
    this._pronombres,
    this._sustantivos,
    this._verbos,
    this._interrogativos,
    this._cifras,
    this.reglasNumero,
    this.tiempoPasado,
    this.tiempoFuturo,
    this.negacion,
    this.prefijoPregunta,
    this.reglasParticula,
  );

  factory FuenteOzhJson([String carpeta = 'datos/ozh']) {
    final lexico = _leer(carpeta, 'lexico.json');
    final gramatica = _leer(carpeta, 'gramatica.json');

    final tiempo = _seccion(gramatica, 'tiempo');
    final numero = _seccion(gramatica, 'numero');
    final prefijo = _obligatorio(_seccion(gramatica, 'pregunta'), 'prefijoVerbo');

    final base = numero['base'];
    if (base is! int || base < 2) {
      throw const FormatException(
          'falta "numero.base" (entero mayor que 1) en datos/ozh/gramatica.json');
    }

    final reglas = <ReglaParticula>[];
    for (final r in (_seccion(gramatica, 'particulas')['reglas'] as List? ??
        const [])) {
      final m = (r as Map<String, dynamic>);
      final particula = _obligatorio(m, 'particula');
      final condiciones = <String, String>{
        for (final llave in ['persona', 'numero', 'tiempo'])
          if (m[llave] is String) llave: m[llave] as String,
      };
      reglas.add(ReglaParticula(condiciones, particula));
    }
    if (reglas.isEmpty) {
      throw const FormatException(
          'faltan "particulas.reglas" en datos/ozh/gramatica.json');
    }

    return FuenteOzhJson._(
      _textos(lexico, 'pronombres'),
      _textos(lexico, 'sustantivos'),
      _textos(lexico, 'verbos'),
      _textos(lexico, 'interrogativos'),
      _textos(lexico, 'cifras'),
      ReglasNumero(base: base, separador: _obligatorio(numero, 'separador')),
      _obligatorio(tiempo, 'pasado'),
      _obligatorio(tiempo, 'futuro'),
      _obligatorio(gramatica, 'negacion'),
      prefijo.endsWith('-') ? prefijo.substring(0, prefijo.length - 1) : prefijo,
      reglas,
    );
  }

  static Map<String, dynamic> _leer(String carpeta, String archivo) {
    var f = File('$carpeta/$archivo');
    if (!f.existsSync()) f = File('cli/$carpeta/$archivo');
    if (!f.existsSync()) {
      throw FileSystemException('no se encontró el archivo de datos Ozh', f.path);
    }
    return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  }

  static Map<String, dynamic> _seccion(Map<String, dynamic> json, String llave) =>
      (json[llave] as Map<String, dynamic>?) ?? const {};

  static Map<String, String> _textos(Map<String, dynamic> json, String llave) =>
      Map.fromEntries(_seccion(json, llave)
          .entries
          .where((e) => !e.key.startsWith('_'))
          .map((e) => MapEntry(e.key, e.value.toString())));

  static String _obligatorio(Map<String, dynamic> json, String llave) {
    final v = json[llave];
    if (v is! String || v.isEmpty) {
      throw FormatException('falta "$llave" en datos/ozh/gramatica.json');
    }
    return v;
  }

  @override
  String? pronombre(Persona persona, Numero numero) =>
      _pronombres['${persona.index + 1}${numero == Numero.singular ? 's' : 'p'}'];

  @override
  String? sustantivo(String concepto) => _sustantivos[concepto];

  @override
  String? verbo(String concepto) => _verbos[concepto];

  @override
  String? interrogativo(String concepto) => _interrogativos[concepto];

  @override
  String? cifra(int c) => _cifras['$c'];

  @override
  String? particulaPara({
    required Persona persona,
    required Numero numero,
    required Tiempo tiempo,
  }) {
    for (final r in reglasParticula) {
      if (r.aplica(persona, numero, tiempo)) return r.particula;
    }
    return null;
  }
}
