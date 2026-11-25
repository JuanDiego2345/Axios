/// Preguntas que en Kethari y Ozh se leen igual (bitácora K-07).
///
/// "¿A quién escuchan ustedes?" (quién es el objeto) y "¿Quién los escucha
/// a ustedes?" (quién es el sujeto) dan el mismo árbol salvo el papel de la
/// incógnita. Las dos lenguas ponen la palabra interrogativa en un extremo
/// (Kethari al principio, Ozh al final) y no marcan quién hace la acción, así
/// que las dos traducciones salen iguales. No es un error del generador: el
/// manual no ofrece cómo distinguirlas. Se traduce según el manual y se
/// avisa.
library;

import '../sintactico/arbol.dart';

/// Aviso si la pregunta se lee igual con la incógnita como sujeto o como
/// objeto. null si no hay ambigüedad.
String? avisoAmbiguedad(Oracion o) {
  if (o.modo != Modo.preguntaAbierta) return null;
  final objeto = o.objeto;
  if (objeto == null) return null;
  final sujetoIncognita = o.sujeto is Incognita;
  final objetoIncognita = objeto is Incognita;
  // Solo cuando exactamente uno de los dos es la incógnita.
  if (sujetoIncognita == objetoIncognita) return null;
  final concepto = sujetoIncognita
      ? (o.sujeto as Incognita).concepto
      : (objeto as Incognita).concepto;
  final papel = sujetoIncognita ? 'sujeto' : 'objeto';
  final otro = sujetoIncognita ? 'objeto' : 'sujeto';
  return 'la traducción se lee igual si $concepto es el $papel o el $otro '
      'de la oración; el manual no permite distinguirlo (bitácora K-07)';
}
