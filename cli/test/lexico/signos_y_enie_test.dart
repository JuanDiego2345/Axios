// Pruebas de punta a punta: módulo léxico + parser con los datos reales de
// datos/espanol. Demuestran que los arreglos de signos (L-10) y de ñ (L-09)
// sirven para que el parser entienda la pregunta.
import 'package:cli/lexico.dart';
import 'package:cli/sintactico.dart';
import 'package:test/test.dart';

void main() {
  final parser = AnalizadorSintactico.desde(FuenteLexicoJson());
  final lexico = FaseLexica(parser.vocabulario);

  Oracion arbol(String pregunta) {
    final r = parser.analizar(lexico.procesar(pregunta).tokens);
    expect(r.error, isNull, reason: 'no debía fallar: ${r.error}');
    return r.arbol!;
  }

  group('signos de interrogación mal puestos', () {
    test('teclado sin ¿: "?Cuando vendran ustedes?"', () {
      final o = arbol('?Cuando vendran ustedes?');
      expect(o.modo, Modo.preguntaAbierta);
      expect(o.interrogativo, 'CUANDO');
    });

    test('signos repetidos: "¿¿Ustedes quieren paz??"', () {
      expect(arbol('¿¿Ustedes quieren paz??').modo, Modo.preguntaSiNo);
    });

    test('signo invertido al final: "ustedes vienen¿"', () {
      expect(arbol('ustedes vienen¿').modo, Modo.preguntaSiNo);
    });

    test('sin ningún signo, con palabra interrogativa', () {
      expect(arbol('cuando llegan').modo, Modo.preguntaAbierta);
    });

    test('los arreglos quedan registrados para el historial', () {
      final r = lexico.procesar('?Cuando llegan??');
      expect(r.ajustesSignos, [
        '"?" al inicio cambiado por "¿"',
        '"?" repetidos unidos en uno',
      ]);
    });
  });

  group('ñ ausente con el vocabulario real', () {
    test('"anos" se corrige a "años"', () {
      final r = lexico.procesar('esperaremos seis anos');
      expect(r.tokens[2].lexema, 'años');
      expect(r.correcciones.single.original, 'anos');
    });
  });
}
