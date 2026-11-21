import 'package:cli/sintactico.dart';
import 'package:test/test.dart';

void main() {
  // Los datos reales de datos/espanol (dart test corre desde la carpeta cli).
  final morf = AnalizadorMorfologico.desde(FuenteLexicoJson());

  /// Primer análisis de [forma] como texto: "llegar, presente, 3p".
  String primero(String forma) => morf.analizar(forma).first.toString();

  /// Todos los análisis de [forma] como texto.
  List<String> todos(String forma) =>
      morf.analizar(forma).map((a) => a.toString()).toList();

  group('presente regular', () {
    test('verbo en -ar en las cinco personas', () {
      expect(primero('llego'), 'llegar, presente, 1s');
      expect(primero('llegas'), 'llegar, presente, 2s');
      expect(primero('llega'), 'llegar, presente, 3s');
      expect(primero('llegamos'), 'llegar, presente, 1p');
      expect(primero('llegan'), 'llegar, presente, 3p');
    });

    test('otros verbos regulares del manual', () {
      expect(primero('envian'), 'enviar, presente, 3p');
      expect(primero('hablamos'), 'hablar, presente, 1p');
      expect(primero('escuchas'), 'escuchar, presente, 2s');
      expect(primero('visitan'), 'visitar, presente, 3p');
      expect(primero('esperamos'), 'esperar, presente, 1p');
    });
  });

  group('presente irregular (desde verbos.json)', () {
    test('venir, querer, ser, estar, ver', () {
      expect(primero('vienen'), 'venir, presente, 3p');
      expect(primero('vengo'), 'venir, presente, 1s');
      expect(primero('queremos'), 'querer, presente, 1p');
      expect(primero('quieren'), 'querer, presente, 3p');
      expect(primero('somos'), 'ser, presente, 1p');
      expect(primero('estan'), 'estar, presente, 3p');
      expect(primero('veo'), 'ver, presente, 1s');
    });

    test('la regla no genera la forma regular de un tiempo irregular', () {
      // "venir" regular sería "veno"; como el presente es irregular, no existe.
      expect(morf.analizar('veno'), isEmpty);
      expect(morf.analizar('vo'), isEmpty);
    });
  });

  group('pasado y futuro', () {
    test('pasado regular e irregular', () {
      expect(primero('enviaron'), 'enviar, pasado, 3p');
      expect(primero('vieron'), 'ver, pasado, 3p');
      expect(primero('vinieron'), 'venir, pasado, 3p');
      expect(primero('llegue'), 'llegar, pasado, 1s');
    });

    test('futuro regular e irregular, sin tildes', () {
      expect(primero('llegaran'), 'llegar, futuro, 3p');
      expect(primero('esperaremos'), 'esperar, futuro, 1p');
      expect(primero('vendran'), 'venir, futuro, 3p');
      expect(primero('querran'), 'querer, futuro, 3p');
    });
  });

  group('ambigüedades', () {
    test('"llegamos" es presente y pasado; gana la prioridad de los datos', () {
      expect(todos('llegamos'),
          ['llegar, presente, 1p', 'llegar, pasado, 1p']);
    });

    test('"envio" puede ser yo envío o él envió', () {
      expect(todos('envio'), ['enviar, presente, 1s', 'enviar, pasado, 3s']);
    });

    test('"fue" es de ser y de ir', () {
      expect(todos('fue').toSet(), {'ser, pasado, 3s', 'ir, pasado, 3s'});
    });
  });

  group('infinitivo y futuro con "ir a"', () {
    test('reconoce infinitivos', () {
      expect(morf.esInfinitivo('llegar'), isTrue);
      expect(morf.esInfinitivo('llegan'), isFalse);
    });

    test('"van" es auxiliar del futuro y "fueron" no', () {
      expect(morf.comoAuxiliarFuturo('van').toString(), 'ir, presente, 3p');
      expect(morf.esAuxiliarFuturo('vamos'), isTrue);
      expect(morf.esAuxiliarFuturo('fueron'), isFalse);
      expect(morf.esAuxiliarFuturo('llegan'), isFalse);
    });
  });

  test('palabras que no son verbos no tienen análisis', () {
    expect(morf.analizar('nave'), isEmpty);
    expect(morf.esVerbo('presidente'), isFalse);
  });

  test('da al corrector las formas conjugadas', () {
    final formas = morf.formasConocidas.toSet();
    expect(formas, containsAll(['llegan', 'vendran', 'vieron', 'llegar']));
  });
}
