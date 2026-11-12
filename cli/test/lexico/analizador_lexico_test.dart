import 'package:cli/lexico.dart';
import 'package:test/test.dart';

void main() {
  const afd = AnalizadorLexico();

  List<TipoToken> tipos(List<Token> ts) => ts.map((t) => t.tipo).toList();

  test('pregunta simple con posiciones', () {
    final ts = afd.analizar('¿cuando llegan?');
    expect(tipos(ts), [
      TipoToken.abreInterrogacion,
      TipoToken.palabra,
      TipoToken.palabra,
      TipoToken.cierraInterrogacion,
      TipoToken.fin,
    ]);
    expect(ts[1].lexema, 'cuando');
    expect(ts[1].posicion, 1);
    expect(ts[1].columna, 2);
    expect(ts[2].lexema, 'llegan');
    expect(ts[2].posicion, 8);
    expect(ts[3].posicion, 14);
    expect(ts[4].posicion, 15);
  });

  test('números con valor', () {
    final ts = afd.analizar('15 naves');
    expect(ts[0].tipo, TipoToken.numero);
    expect(ts[0].valor, 15);
    expect(ts[1].lexema, 'naves');
    expect(ts[1].posicion, 3);
  });

  test('número pegado a palabra da dos tokens (lexema más largo)', () {
    final ts = afd.analizar('15naves');
    expect(tipos(ts),
        [TipoToken.numero, TipoToken.palabra, TipoToken.fin]);
    expect(ts[1].posicion, 2);
  });

  test('coma y punto', () {
    final ts = afd.analizar('si, ya.');
    expect(tipos(ts), [
      TipoToken.palabra,
      TipoToken.coma,
      TipoToken.palabra,
      TipoToken.punto,
      TipoToken.fin,
    ]);
  });

  test('carácter desconocido no detiene el análisis', () {
    final ts = afd.analizar('hola @ mundo');
    expect(tipos(ts), [
      TipoToken.palabra,
      TipoToken.desconocido,
      TipoToken.palabra,
      TipoToken.fin,
    ]);
    expect(ts[1].lexema, '@');
    expect(ts[1].posicion, 5);
  });

  test('la ñ es letra', () {
    final ts = afd.analizar('año');
    expect(ts.first.tipo, TipoToken.palabra);
    expect(ts.first.lexema, 'año');
  });

  test('entrada vacía solo produce fin', () {
    expect(tipos(afd.analizar('')), [TipoToken.fin]);
    expect(tipos(afd.analizar('   ')), [TipoToken.fin]);
  });

  test('la traza registra las transiciones', () {
    final traza = <String>[];
    afd.analizar('yo', traza: traza);
    expect(traza, [
      'inicio --"y" (letra)--> palabra',
      'palabra --"o" (letra)--> palabra',
      '  acepta palabra("yo") en columna 1',
    ]);
  });

  test('la tabla es determinista: cada clase lleva a un único estado', () {
    for (final estado in Estado.values) {
      expect(AnalizadorLexico.tabla.containsKey(estado), isTrue,
          reason: 'falta el estado ${estado.name} en la tabla');
    }
    // Desde inicio, toda clase que no sea espacio tiene transición.
    for (final clase in ClaseCaracter.values) {
      if (clase == ClaseCaracter.espacio) continue;
      expect(AnalizadorLexico.tabla[Estado.inicio]![clase], isNotNull,
          reason: 'inicio sin transición para ${clase.name}');
    }
  });
}
