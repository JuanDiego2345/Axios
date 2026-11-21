/// De dónde saca el generador de Kethari las palabras y los afijos.
///
/// El generador no conoce ninguna palabra Kethari: todo lo pide a una
/// [FuenteKethari]. Hoy la implementa [FuenteKethariJson] (archivos de
/// `datos/kethari/`); cuando la base de datos guarde el léxico por
/// concepto, bastará con otra clase que implemente esta interfaz leyendo de
/// SQLite. Ver bitácora K-04.
library;

import 'dart:convert';
import 'dart:io';

import '../sintactico/arbol.dart';
import 'numeros.dart';

/// Piezas que se pegan a las palabras (manual, sección 3.3).
class AfijosKethari {
  /// Sufijo del verbo en presente (vacío en el manual).
  final String presente;

  /// Sufijo del verbo en pasado: `-ok`.
  final String pasado;

  /// Sufijo del verbo en futuro: `-ime`.
  final String futuro;

  /// Prefijo de negación del verbo: `nu-`.
  final String negacion;

  /// Sufijo de plural del sustantivo: `-esh`.
  final String plural;

  /// Partícula final de las preguntas: `ka`.
  final String pregunta;

  const AfijosKethari({
    required this.presente,
    required this.pasado,
    required this.futuro,
    required this.negacion,
    required this.plural,
    required this.pregunta,
  });
}

/// Lo que el generador necesita saber de Kethari.
///
/// Todos los métodos devuelven `null` si el concepto no tiene palabra
/// Kethari conocida: el generador no inventa, lo explica.
abstract interface class FuenteKethari {
  /// Pronombre para una persona y un número (`an`, `ulesh`...).
  String? pronombre(Persona persona, Numero numero);

  /// Sustantivo de un concepto (`NAVE` -> `kum`).
  String? sustantivo(String concepto);

  /// Raíz verbal de un concepto (`VENIR` -> `vin`).
  String? verbo(String concepto);

  /// Palabra interrogativa de un concepto (`CUANDO` -> `kom`).
  String? interrogativo(String concepto);

  /// Palabra de una cifra (`2` -> `ra`). `null` si no existe (6 a 9).
  String? cifra(int valor);

  AfijosKethari get afijos;

  /// Base y separador de las cantidades.
  ReglasNumero get numeros;
}

/// Código corto de persona y número: `1s`, `2p`... (mismo formato que
/// `datos/espanol/palabras.json`).
String codigoRasgos(Persona persona, Numero numero) =>
    '${persona.index + 1}${numero == Numero.singular ? 's' : 'p'}';

/// Lee el léxico y los afijos de `datos/kethari/lexico.json` y
/// `datos/kethari/gramatica.json`.
class FuenteKethariJson implements FuenteKethari {
  final Map<String, String> _pronombres;
  final Map<String, String> _sustantivos;
  final Map<String, String> _verbos;
  final Map<String, String> _interrogativos;
  final Map<String, String> _cifras;

  @override
  final AfijosKethari afijos;

  @override
  final ReglasNumero numeros;

  FuenteKethariJson._(this._pronombres, this._sustantivos, this._verbos,
      this._interrogativos, this._cifras, this.afijos, this.numeros);

  factory FuenteKethariJson([String carpeta = 'datos/kethari']) {
    final lexico = _leer(carpeta, 'lexico.json');
    final gramatica = _leer(carpeta, 'gramatica.json');

    final verbo = _seccion(gramatica, 'verbo');
    final sustantivo = _seccion(gramatica, 'sustantivo');
    final pregunta = _seccion(gramatica, 'pregunta');
    final numero = _seccion(gramatica, 'numero');

    return FuenteKethariJson._(
      _textos(lexico, 'pronombres'),
      _textos(lexico, 'sustantivos'),
      _textos(lexico, 'verbos'),
      _textos(lexico, 'interrogativos'),
      _textos(lexico, 'cifras'),
      AfijosKethari(
        presente: verbo['presente'] as String? ?? '',
        pasado: _obligatorio(verbo, 'pasado'),
        futuro: _obligatorio(verbo, 'futuro'),
        negacion: _obligatorio(verbo, 'negacion'),
        plural: _obligatorio(sustantivo, 'plural'),
        pregunta: _obligatorio(pregunta, 'particula'),
      ),
      ReglasNumero(
        base: _entero(numero, 'base'),
        separador: _obligatorio(numero, 'separador'),
      ),
    );
  }

  static Map<String, dynamic> _leer(String carpeta, String archivo) {
    final f = File('$carpeta/$archivo');
    if (!f.existsSync()) {
      throw FileSystemException('no se encontró el archivo de datos', f.path);
    }
    return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  }

  static Map<String, dynamic> _seccion(Map<String, dynamic> json, String llave) =>
      (json[llave] as Map<String, dynamic>?) ?? const {};

  static Map<String, String> _textos(Map<String, dynamic> json, String llave) =>
      _seccion(json, llave).map((k, v) => MapEntry(k, v as String));

  static String _obligatorio(Map<String, dynamic> json, String llave) {
    final v = json[llave];
    if (v is! String || v.isEmpty) {
      throw FormatException('falta "$llave" en datos/kethari/gramatica.json');
    }
    return v;
  }

  static int _entero(Map<String, dynamic> json, String llave) {
    final v = json[llave];
    if (v is! int || v < 2) {
      throw FormatException(
          'falta "$llave" (entero mayor que 1) en datos/kethari/gramatica.json');
    }
    return v;
  }

  @override
  String? pronombre(Persona persona, Numero numero) =>
      _pronombres[codigoRasgos(persona, numero)];

  @override
  String? sustantivo(String concepto) => _sustantivos[concepto];

  @override
  String? verbo(String concepto) => _verbos[concepto];

  @override
  String? interrogativo(String concepto) => _interrogativos[concepto];

  @override
  String? cifra(int valor) => _cifras['$valor'];
}
