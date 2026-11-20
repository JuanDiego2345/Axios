import 'package:cli/lexico.dart';
import 'package:test/test.dart';

void main() {
  final fase = FaseLexica([
    'cuándo', 'llegan', 'las', 'naves', 'cuántas', 'llegaron', 'esperaremos',
    'ciclos', 'queremos', 'paz',
  ]);

  List<String> lexemas(ResultadoLexico r) => r.tokens
      .where((t) => t.tipo != TipoToken.fin)
      .map((t) => t.lexema)
      .toList();

  test('pregunta con errores, sin tildes y en mayúsculas', () {
    final r = fase.procesar('¿Kuando LLEGAN las nabes?');
    expect(r.normalizado, '¿kuando llegan las nabes?');
    expect(lexemas(r), ['¿', 'cuando', 'llegan', 'las', 'naves', '?']);
    expect(r.correcciones.map((c) => c.toString()),
        ['kuando -> cuando (d=1)', 'nabes -> naves (d=1)']);
    expect(r.limpio, isTrue);
  });

  test('pregunta sin signos de interrogación', () {
    final r = fase.procesar('cuantas naves llegaron');
    expect(lexemas(r), ['cuantas', 'naves', 'llegaron']);
    expect(r.correcciones, isEmpty);
  });

  test('cantidad en letras llega como token número', () {
    final r = fase.procesar('Esperaremos seis ciclos');
    expect(r.tokens[1].tipo, TipoToken.numero);
    expect(r.tokens[1].valor, 6);
    expect(r.numerosConvertidos.single.valor, 6);
  });

  test('corrige una cantidad mal escrita y luego la convierte (L-07)', () {
    final r = fase.procesar('Llegaron quinse naves');
    expect(lexemas(r), ['llegaron', '15', 'naves']);
    expect(r.tokens[1].tipo, TipoToken.numero);
    expect(r.tokens[1].valor, 15);
    expect(r.tokens[1].original, 'quinse');
    expect(r.correcciones.single.toString(), 'quinse -> quince (d=1)');
    expect(r.numerosConvertidos.single.valor, 15);
  });

  test('error dentro de una cantidad de varias palabras (L-07)', () {
    final r = fase.procesar('dos mil quinse naves');
    expect(lexemas(r), ['2015', 'naves']);
    expect(r.tokens.first.original, 'dos mil quinse');
  });

  test('las palabras numéricas bien escritas no se corrigen', () {
    final r = fase.procesar('esperaremos seis ciclos');
    expect(r.correcciones, isEmpty);
    expect(r.palabrasDesconocidas, isEmpty);
  });

  test('reporta caracteres desconocidos y palabras fuera del vocabulario', () {
    final r = fase.procesar('queremos paz # zzzz');
    expect(r.erroresLexicos.single.lexema, '#');
    expect(r.palabrasDesconocidas.single.lexema, 'zzzz');
    expect(r.limpio, isFalse);
  });

  test('el último token siempre es fin', () {
    expect(fase.procesar('').tokens.single.tipo, TipoToken.fin);
    expect(fase.procesar('queremos paz').tokens.last.tipo, TipoToken.fin);
  });

  test('modo traza', () {
    final r = fase.procesar('paz', conTraza: true);
    expect(r.traza, isNotEmpty);
    final t = fase.procesar('quinse', conTraza: true).traza;
    expect(t, contains('corrige quinse -> quince (d=1)'));
    expect(t, contains('número "quince" -> 15'));
    expect(fase.procesar('paz').traza, isEmpty);
  });
}
