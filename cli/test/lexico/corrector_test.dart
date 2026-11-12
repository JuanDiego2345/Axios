import 'package:cli/lexico.dart';
import 'package:test/test.dart';

void main() {
  group('distanciaLevenshtein', () {
    test('casos conocidos', () {
      expect(distanciaLevenshtein('kitten', 'sitting'), 3);
      expect(distanciaLevenshtein('', 'abc'), 3);
      expect(distanciaLevenshtein('abc', ''), 3);
      expect(distanciaLevenshtein('naves', 'naves'), 0);
      expect(distanciaLevenshtein('nabes', 'naves'), 1);
      expect(distanciaLevenshtein('planta', 'planeta'), 1);
    });

    test('es simétrica', () {
      expect(distanciaLevenshtein('llegaron', 'lelgaron'),
          distanciaLevenshtein('lelgaron', 'llegaron'));
    });
  });

  group('Corrector', () {
    // En el sistema real este vocabulario viene de la base de datos.
    final corrector = Corrector([
      'Cuándo', 'llegan', 'naves', 'nave', 'planeta', 'quieren', 'paz',
      'las', 'mensaje',
    ]);

    Token palabra(String lexema, [int posicion = 0]) =>
        Token(tipo: TipoToken.palabra, lexema: lexema, posicion: posicion);

    test('no altera palabras válidas', () {
      final r = corrector.corregir([palabra('naves'), palabra('paz')]);
      expect(r.correcciones, isEmpty);
      expect(r.tokens.map((t) => t.lexema), ['naves', 'paz']);
      expect(r.tokens.every((t) => !t.fueCorregido), isTrue);
    });

    test('corrige con distancia 1', () {
      final r = corrector.corregir([palabra('nabes', 4)]);
      expect(r.tokens.single.lexema, 'naves');
      expect(r.tokens.single.original, 'nabes');
      expect(r.tokens.single.posicion, 4);
      expect(r.correcciones.single.distancia, 1);
    });

    test('el vocabulario con tildes se normaliza', () {
      final r = corrector.corregir([palabra('kuando')]);
      expect(r.tokens.single.lexema, 'cuando');
    });

    test('corrige con distancia 2 en palabras largas', () {
      final r = corrector.corregir([palabra('mesnaje')]);
      expect(r.tokens.single.lexema, 'mensaje');
    });

    test('palabra sin candidato queda como desconocida', () {
      final r = corrector.corregir([palabra('xyzw')]);
      expect(r.tokens.single.lexema, 'xyzw');
      expect(r.desconocidas.single.lexema, 'xyzw');
      expect(r.correcciones, isEmpty);
    });

    test('palabras de 1 o 2 letras no se corrigen (decisión L-04)', () {
      final r = corrector.corregir([palabra('pz')]);
      expect(r.tokens.single.lexema, 'pz');
      expect(r.desconocidas, hasLength(1));
    });

    test('números y signos no se tocan', () {
      final r = corrector.corregir([
        const Token(tipo: TipoToken.numero, lexema: '15', posicion: 0, valor: 15),
        const Token(tipo: TipoToken.cierraInterrogacion, lexema: '?', posicion: 2),
      ]);
      expect(r.correcciones, isEmpty);
      expect(r.desconocidas, isEmpty);
    });

    test('desempate: prefiere la misma primera letra (decisión L-05)', () {
      final c = Corrector(['casa', 'masa']);
      final r = c.mejorCandidato('cosa');
      expect(r!.palabra, 'casa');
      expect(r.empatadas, ['casa']);
      final r2 = c.mejorCandidato('xasa');
      expect(r2!.empatadas, ['casa', 'masa']); // empate real, orden alfabético
    });

    test('umbral según longitud', () {
      expect(Corrector.umbralPara(2), 0);
      expect(Corrector.umbralPara(3), 1);
      expect(Corrector.umbralPara(5), 1);
      expect(Corrector.umbralPara(6), 2);
    });
  });
}
