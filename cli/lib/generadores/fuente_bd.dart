/// Fuentes de Kethari y Ozh que sacan las PALABRAS de la base de datos
/// (bitácora K-11).
///
/// Las reglas (afijos, partículas, base de los números) siguen en
/// `datos/<lengua>/gramatica.json`: la BD no tiene tablas para ellas y son
/// datos, no código. Los generadores no cambian: solo reciben otra fuente.
library;

import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import '../sintactico/arbol.dart';
import '../sintactico/lexico_espanol.dart';
import 'fuente_kethari.dart';
import 'fuente_ozh.dart';
import 'lexico_bd.dart';
import 'numeros.dart';

/// Kethari con el léxico de la BD.
class FuenteKethariBd implements FuenteKethari {
  final LexicoAlienigenaBd lexico;

  /// Afijos y números (de `datos/kethari/gramatica.json`).
  final FuenteKethari reglas;

  /// Cómo resolver una celda con varias palabras ("anul|anir").
  final Map<String, String> _alternativas;

  FuenteKethariBd._(this.lexico, this.reglas, this._alternativas);

  factory FuenteKethariBd(Database db, FuenteLexicoEspanol espanol,
      {String carpeta = 'datos/kethari', String? fecha}) {
    final gramatica = jsonDecode(
            File('$carpeta/gramatica.json').readAsStringSync())
        as Map<String, dynamic>;
    final alt = (gramatica['alternativas'] as Map<String, dynamic>? ?? {})
      ..removeWhere((k, _) => k.startsWith('_'));
    return FuenteKethariBd._(
      LexicoAlienigenaBd(db, espanol, fecha: fecha),
      FuenteKethariJson(carpeta),
      alt.map((k, v) => MapEntry(k, v as String)),
    );
  }

  /// La misma fuente en otra fecha.
  FuenteKethariBd enFecha(String? fecha) =>
      FuenteKethariBd._(lexico.enFecha(fecha), reglas, _alternativas);

  /// "anul|anir" -> la que diga `alternativas` (K-01). Si no lo dice, no
  /// se elige: null.
  String? _una(String? palabra) {
    if (palabra == null || !palabra.contains('|')) return palabra;
    return _alternativas[palabra];
  }

  @override
  String? pronombre(Persona persona, Numero numero) =>
      _una(lexico.pronombre(Lengua.kethari, persona, numero));

  @override
  String? sustantivo(String concepto) =>
      _una(lexico.sustantivo(Lengua.kethari, concepto));

  @override
  String? verbo(String concepto) =>
      _una(lexico.verbo(Lengua.kethari, concepto));

  @override
  String? interrogativo(String concepto) =>
      _una(lexico.interrogativo(Lengua.kethari, concepto));

  @override
  String? cifra(int valor) => _una(lexico.cifra(Lengua.kethari, valor));

  @override
  AfijosKethari get afijos => reglas.afijos;

  @override
  ReglasNumero get numeros => reglas.numeros;
}

/// Ozh con el léxico de la BD.
class FuenteOzhBd implements FuenteOzh {
  final LexicoAlienigenaBd lexico;

  /// Partículas, tiempo, negación y números (de `datos/ozh/gramatica.json`).
  final FuenteOzh reglas;

  FuenteOzhBd._(this.lexico, this.reglas);

  factory FuenteOzhBd(Database db, FuenteLexicoEspanol espanol,
          {String carpeta = 'datos/ozh', String? fecha}) =>
      FuenteOzhBd._(LexicoAlienigenaBd(db, espanol, fecha: fecha),
          FuenteOzhJson(carpeta));

  FuenteOzhBd enFecha(String? fecha) =>
      FuenteOzhBd._(lexico.enFecha(fecha), reglas);

  @override
  String? pronombre(Persona persona, Numero numero) =>
      lexico.pronombre(Lengua.ozh, persona, numero);

  @override
  String? sustantivo(String concepto) =>
      lexico.sustantivo(Lengua.ozh, concepto);

  @override
  String? verbo(String concepto) => lexico.verbo(Lengua.ozh, concepto);

  @override
  String? interrogativo(String concepto) =>
      lexico.interrogativo(Lengua.ozh, concepto);

  @override
  String? cifra(int c) => lexico.cifra(Lengua.ozh, c);

  @override
  ReglasNumero get reglasNumero => reglas.reglasNumero;

  @override
  String get tiempoPasado => reglas.tiempoPasado;

  @override
  String get tiempoFuturo => reglas.tiempoFuturo;

  @override
  String get negacion => reglas.negacion;

  @override
  String get prefijoPregunta => reglas.prefijoPregunta;

  @override
  String particulaPara(
          {required Persona persona,
          required Numero numero,
          required Tiempo tiempo}) =>
      reglas.particulaPara(persona: persona, numero: numero, tiempo: tiempo);
}
