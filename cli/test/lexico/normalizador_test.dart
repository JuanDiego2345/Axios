import 'package:cli/lexico.dart';
import 'package:test/test.dart';

void main() {
  const n = Normalizador();

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
  });

  group('Normalizador: números', () {
    test('quita separadores de miles', () {
      expect(n.normalizar('1.500 naves'), '1500 naves');
      expect(n.normalizar('2,015 naves'), '2015 naves');
    });

    test('números en letras simples', () {
      expect(n.normalizar('esperaremos seis ciclos'), 'esperaremos 6 ciclos');
      expect(n.normalizar('quince naves'), '15 naves');
      expect(n.normalizar('cero'), '0');
    });

    test('decenas con y', () {
      expect(n.normalizar('treinta y dos naves'), '32 naves');
    });

    test('centenas', () {
      expect(n.normalizar('cien'), '100');
      expect(n.normalizar('ciento uno'), '101');
      expect(n.normalizar('novecientos noventa y nueve'), '999');
    });

    test('miles', () {
      expect(n.normalizar('mil'), '1000');
      expect(n.normalizar('dos mil quince'), '2015');
      expect(n.normalizar('nueve mil novecientos noventa y nueve'), '9999');
      expect(n.normalizar('mil doscientas naves'), '1200 naves');
    });

    test('veintiuna y veintiún', () {
      expect(n.normalizar('veintiuna naves'), '21 naves');
      expect(n.normalizar('veintiún planetas'), '21 planetas');
    });

    test('un / una sueltos son artículos (decisión L-02)', () {
      expect(n.normalizar('una nave'), 'una nave');
      expect(n.normalizar('un mensaje'), 'un mensaje');
      expect(n.normalizar('uno'), '1');
    });

    test('la y entre unidades no se une', () {
      expect(n.normalizar('cinco y dos'), '5 y 2');
    });

    test('un signo corta la cantidad', () {
      expect(n.normalizar('dos, tres'), '2, 3');
      expect(n.normalizar('¿quince?'), '¿15?');
    });

    test('registra las conversiones', () {
      final r = n.procesar('Llegaron dos mil quince naves');
      expect(r.texto, 'llegaron 2015 naves');
      expect(r.numerosConvertidos, hasLength(1));
      expect(r.numerosConvertidos.first.texto, 'dos mil quince');
      expect(r.numerosConvertidos.first.valor, 2015);
    });
  });
}
