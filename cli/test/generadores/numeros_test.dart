import 'package:cli/generadores.dart';
import 'package:test/test.dart';

void main() {
  group('cifras en una base', () {
    test('base 6, como Kethari', () {
      expect(cifras(0, 6), [0]);
      expect(cifras(5, 6), [5]);
      expect(cifras(6, 6), [1, 0]);
      expect(cifras(15, 6), [2, 3]);
      expect(cifras(36, 6), [1, 0, 0]);
      expect(cifras(9999, 6), [1, 1, 4, 1, 4, 3]);
    });

    test('base 10, como Ozh', () {
      expect(cifras(15, 10), [1, 5]);
      expect(cifras(2015, 10), [2, 0, 1, 5]);
      expect(cifras(9999, 10), [9, 9, 9, 9]);
    });

    test('no acepta cantidades negativas', () {
      expect(() => cifras(-1, 6), throwsArgumentError);
    });
  });

  group('escribir una cantidad', () {
    // Cifras de prueba: no son de ninguna lengua, para mostrar que el
    // algoritmo no conoce palabras propias.
    const reglas = ReglasNumero(base: 6, separador: '-');
    String? cifra(int c) => const ['a', 'b', 'c', 'd', 'e', 'f'][c];

    test('encadena cifras con el separador', () {
      expect(escribirNumero(15, reglas, cifra).texto, 'c-d');
      expect(escribirNumero(0, reglas, cifra).texto, 'a');
    });

    test('si falta una cifra no inventa: devuelve cuáles faltan', () {
      final r = escribirNumero(15, const ReglasNumero(base: 10, separador: '-'),
          (c) => c < 5 ? 'x$c' : null);
      expect(r.ok, isFalse);
      expect(r.texto, isNull);
      expect(r.cifrasDesconocidas, [5]);
    });
  });

  group('con los datos reales de Kethari', () {
    final fuente = FuenteKethariJson();
    String escribir(int n) =>
        escribirNumero(n, fuente.numeros, fuente.cifra).texto!;

    test('señales del registro', () {
      expect(escribir(15), 'ra-sel'); // día 3
      expect(escribir(6), 'ti-vo'); // día 7
    });

    test('Kethari no tiene palabra para 6, 7, 8 ni 9', () {
      for (final c in [6, 7, 8, 9]) {
        expect(fuente.cifra(c), isNull);
      }
    });
  });
}
