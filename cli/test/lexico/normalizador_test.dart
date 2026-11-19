import 'package:cli/lexico.dart';
import 'package:test/test.dart';

void main() {
  const n = Normalizador();
  const afd = AnalizadorLexico();

  /// Normaliza el texto, lo pasa por el AFD y convierte las cantidades.
  /// Devuelve los lexemas separados por espacio.
  String numeros(String texto) {
    final tokens = afd.analizar(n.normalizar(texto));
    return n
        .normalizarNumeros(tokens)
        .tokens
        .where((t) => t.tipo != TipoToken.fin)
        .map((t) => t.lexema)
        .join(' ');
  }

  group('Normalizador: minúsculas, tildes y signos', () {
    test('pasa a minúsculas y quita tildes', () {
      expect(n.normalizar('¿Cuándo LLEGARÁN?'), '¿cuando llegaran?');
    });

    test('conserva la ñ (decisión L-01)', () {
      expect(n.normalizar('¡Feliz Año!'), 'feliz año');
    });

    test('la diéresis se quita', () {
      expect(n.normalizar('Pingüino'), 'pinguino');
    });

    test('conserva ¿ ? , . y descarta ¡ ! ; : comillas y paréntesis', () {
      expect(n.normalizar('Hola; "mundo" (paz): ¿si, no.?'),
          'hola mundo paz ¿si, no.?');
    });

    test('colapsa espacios', () {
      expect(n.normalizar('   quiero     agua  '), 'quiero agua');
    });

    test('deja pasar caracteres raros para que el AFD los reporte', () {
      expect(n.normalizar('hola @ mundo'), 'hola @ mundo');
    });

    test('quita separadores de miles', () {
      expect(n.normalizar('1.500 naves'), '1500 naves');
      expect(n.normalizar('2,015 naves'), '2015 naves');
    });

    test('no convierte cantidades en letras: eso va después (L-07)', () {
      expect(n.normalizar('Quince naves'), 'quince naves');
    });
  });

  group('Normalizador: números en letras', () {
    test('números simples', () {
      expect(numeros('esperaremos seis ciclos'), 'esperaremos 6 ciclos');
      expect(numeros('quince naves'), '15 naves');
      expect(numeros('cero'), '0');
    });

    test('veintiséis (señal del día 10)', () {
      expect(numeros('vimos veintiséis estrellas'), 'vimos 26 estrellas');
    });

    test('decenas con y', () {
      expect(numeros('treinta y dos naves'), '32 naves');
    });

    test('centenas', () {
      expect(numeros('cien'), '100');
      expect(numeros('ciento uno'), '101');
      expect(numeros('novecientos noventa y nueve'), '999');
    });

    test('miles', () {
      expect(numeros('mil'), '1000');
      expect(numeros('dos mil quince'), '2015');
      expect(numeros('nueve mil novecientos noventa y nueve'), '9999');
      expect(numeros('mil doscientas naves'), '1200 naves');
    });

    test('veintiuna y veintiún', () {
      expect(numeros('veintiuna naves'), '21 naves');
      expect(numeros('veintiún planetas'), '21 planetas');
    });

    test('un / una sueltos son artículos (decisión L-02)', () {
      expect(numeros('una nave'), 'una nave');
      expect(numeros('un mensaje'), 'un mensaje');
      expect(numeros('uno'), '1');
    });

    test('la y entre unidades no se une', () {
      expect(numeros('cinco y dos'), '5 y 2');
    });

    test('un signo corta la cantidad', () {
      expect(numeros('dos, tres'), '2 , 3');
      expect(numeros('¿quince?'), '¿ 15 ?');
    });

    test('las cifras escritas con dígitos no cambian', () {
      expect(numeros('15 naves'), '15 naves');
    });

    test('el token nuevo guarda posición, valor y texto original', () {
      final tokens = afd.analizar(n.normalizar('Llegaron dos mil quince naves'));
      final r = n.normalizarNumeros(tokens);
      final numero = r.tokens[1];
      expect(numero.tipo, TipoToken.numero);
      expect(numero.lexema, '2015');
      expect(numero.valor, 2015);
      expect(numero.posicion, 9);
      expect(numero.original, 'dos mil quince');
      expect(r.conversiones.single.texto, 'dos mil quince');
      expect(r.conversiones.single.valor, 2015);
      expect(r.tokens[2].lexema, 'naves');
    });
  });
}
