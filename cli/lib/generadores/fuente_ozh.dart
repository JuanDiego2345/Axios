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
  String get tiempoPasado;
  String get tiempoFuturo;
  String get negacion;
  String get prefijoPregunta;
  String particulaPara({
    required Persona persona,
    required Numero numero,
    required Tiempo tiempo,
  });
}

class FuenteOzhJson implements FuenteOzh {
  final Map<String, String> _pronombres;
  final Map<String, String> _sustantivos;
  final Map<String, String> _verbos;
  final Map<String, String> _interrogativos;
  final Map<String, String> _cifras;
  final Map<String, dynamic> _gramatica;

  FuenteOzhJson._(
    this._pronombres,
    this._sustantivos,
    this._verbos,
    this._interrogativos,
    this._cifras,
    this._gramatica,
  );

  factory FuenteOzhJson([String carpeta = 'datos/ozh']) {
    final lexico = _leer(carpeta, 'lexico.json');
    final gramatica = _leer(carpeta, 'gramatica.json');

    return FuenteOzhJson._(
      _textos(lexico, 'pronombres'),
      _textos(lexico, 'sustantivos'),
      _textos(lexico, 'verbos'),
      _textos(lexico, 'interrogativos'),
      _textos(lexico, 'cifras'),
      gramatica,
    );
  }

  static Map<String, dynamic> _leer(String carpeta, String archivo) {
    var f = File('$carpeta/$archivo');
    if (!f.existsSync()) {
      f = File('cli/$carpeta/$archivo');
    }
    if (!f.existsSync()) {
      throw FileSystemException('no se encontró el archivo de datos Ozh', f.path);
    }
    return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  }

  static Map<String, dynamic> _seccion(Map<String, dynamic> json, String llave) =>
      (json[llave] as Map<String, dynamic>?) ?? const {};

  static Map<String, String> _textos(Map<String, dynamic> json, String llave) =>
      _seccion(json, llave).map((k, v) => MapEntry(k, v.toString()));

  @override
  String? pronombre(Persona persona, Numero numero) {
    final codigo = '${persona.index + 1}${numero == Numero.singular ? 's' : 'p'}';
    return _pronombres[codigo];
  }

  @override
  String? sustantivo(String concepto) => _sustantivos[concepto];

  @override
  String? verbo(String concepto) => _verbos[concepto];

  @override
  String? interrogativo(String concepto) => _interrogativos[concepto];

  @override
  String? cifra(int c) => _cifras[c.toString()];

  @override
  ReglasNumero get reglasNumero {
    final sec = _seccion(_gramatica, 'numero');
    return ReglasNumero(
      base: (sec['base'] as int?) ?? 10,
      separador: (sec['separador'] as String?) ?? '-',
    );
  }

  @override
  String get tiempoPasado =>
      (_seccion(_gramatica, 'tiempo')['pasado'] as String?) ?? 'ʔoka';

  @override
  String get tiempoFuturo =>
      (_seccion(_gramatica, 'tiempo')['futuro'] as String?) ?? 'venu';

  @override
  String get negacion => (_gramatica['negacion'] as String?) ?? 'ne';

  @override
  String get prefijoPregunta =>
      (_seccion(_gramatica, 'pregunta')['prefijoVerbo'] as String?) ?? 'ʔa-';

  @override
  String particulaPara({
    required Persona persona,
    required Numero numero,
    required Tiempo tiempo,
  }) {
    final parts = _seccion(_gramatica, 'particulas');
    if (persona == Persona.segunda || (persona == Persona.primera && numero == Numero.singular)) {
      return (parts['segundaPersona'] as String?) ?? 'mar';
    }
    if (persona == Persona.primera && numero == Numero.plural && tiempo == Tiempo.pasado) {
      return (parts['primeraPasado'] as String?) ?? 'zi';
    }
    return (parts['defecto'] as String?) ?? 'tho';
  }
}

