import 'package:cli/cli.dart';
import 'package:test/test.dart';

void main() {
  group('AxiosCli - Órdenes obligatorias del CLI', () {
    late AxiosCli axios;

    setUp(() {
      axios = AxiosCli.crear(
        rutaDatos: 'datos',
        dbCustom: abrirBd(':memory:'),
      );
    });

    tearDown(() {
      axios.cerrar();
    });

    test('traducir con error sintáctico se registra en el historial con validación adecuada', () {
      final r = axios.traducir('palabraDesconocidaXYZ');

      expect(r.exitoso, isFalse);
      expect(r.error, isNotNull);

      final items = axios.historial();
      expect(items.length, equals(1));
      expect(items.first['original'], equals('palabraDesconocidaXYZ'));
      expect(items.first['kethari'], isNull);
      expect(items.first['ozh'], isNull);
      expect(items.first['validacion'], equals('error sintáctico'));
    });

    test('cargar almacena el léxico en la BD', () {
      final res = axios.cargar('datos/lexico_inicial.csv');

      expect(res.filas, greaterThanOrEqualTo(1));
      expect(res.tipo, contains('léxico'));

      final palabra = axios.palabra('agua');
      expect(palabra, isNotNull);
      expect(palabra!.kethari, equals('dahl'));
      expect(palabra.ozh, equals('naʔ'));
    });

    test('cargar almacena señales en la BD', () {
      final res = axios.cargar('datos/senales_inicial.csv');

      expect(res.filas, greaterThanOrEqualTo(1));
      expect(res.tipo, contains('señales'));
    });

    test('historial lista y filtra correctamente', () {
      axios.traducir('Queremos paz');
      axios.traducir('¿Cuándo vendrán ustedes?');

      final todos = axios.historial();
      expect(todos.length, equals(2));

      final futuros = axios.historial(desde: '2099-01-01');
      expect(futuros, isEmpty);

      final pasados = axios.historial(desde: '2020-01-01');
      expect(pasados.length, equals(2));
    });

    test('palabra busca términos existentes y retorna null si no existen', () {
      axios.cargar('datos/lexico_inicial.csv');

      final nave = axios.palabra('nave');
      expect(nave, isNotNull);
      expect(nave!.lema, equals('nave'));
      expect(nave.categoria, equals('sustantivo'));
      expect(nave.kethari, equals('kum'));

      final inexistente = axios.palabra('terminoInexistente123');
      expect(inexistente, isNull);
    });
  });

  group('AxiosCli - Batería de 30 pares de traducción (Español -> Kethari y Ozh)', () {
    late AxiosCli axios;

    setUp(() {
      axios = AxiosCli.crear(
        rutaDatos: 'datos',
        dbCustom: abrirBd(':memory:'),
      );
      // Los generadores leen el léxico de la BD (bitácora K-11): sin el
      // manual cargado no hay palabras que traducir.
      axios.cargar('datos/lexico_inicial.csv');
    });

    tearDown(() {
      axios.cerrar();
    });

    // 30 pares de oraciones en español y su traducción Kethari esperada
    const pares = <String, String>{
      'Queremos paz': 'anir parn thal',
      '¿Cuándo vendrán ustedes?': 'kom ulesh vinime ka',
      '¿Quién envió el mensaje?': 'sem ombra salok ka',
      '¿Ustedes no vieron nuestro planeta?': 'ulesh anir vael nukorok ka',
      '¿Qué quieren ustedes?': 'kel ulesh thal ka',
      'Quince naves llegaron': 'ra-sel kumesh vinok',
      'Nosotros esperaremos seis ciclos': 'anir ti-vo lunesh tepime',
      '¿Van a llegar quince naves?': 'ra-sel kumesh vinime ka',
      'Nosotros enviamos mensajes': 'anir ombraesh sal',
      'Ellos quieren paz': 'iresh parn thal',
      'Ustedes no vieron el planeta': 'ulesh vael nukorok',
      '¿Dónde está su hogar?': 'dor ulesh hosk mi ka',
      '¿Cuántas naves llegaron?': 'kai kumesh vinok ka',
      'Ellos no quieren paz': 'iresh parn nuthal',
      '¿Cuándo llegan ustedes?': 'kom ulesh vin ka',
      'Nosotros vimos estrellas': 'anir sorinesh korok',
      '¿Ustedes escuchan el mensaje?': 'ulesh ombra rhu ka',
      'Yo espero un ciclo': 'an lun tep',
      'Una criatura llegó': 'yorr vinok',
      'Nosotros visitaremos su planeta': 'anir ulesh vael dunime',
      'Ellos no hablan': 'iresh nular',
      'Ustedes no hablan': 'ulesh nular',
      '¿Quién quiere paz?': 'sem parn thal ka',
      'El mensaje llegó': 'ombra vinok',
      'Nosotros queremos agua': 'anir dahl thal',
      'Dos naves llegaron': 'ra kumesh vinok',
      'Ellos enviarán mensajes': 'iresh ombraesh salime',
      '¿Qué vieron ustedes?': 'kel ulesh korok ka',
      'Esperaremos paz': 'anir parn tepime',
      '¿Quién escucha?': 'sem rhu ka',
    };

    var indice = 1;
    pares.forEach((espanol, esperadoKethari) {
      final numeroPar = indice++;
      test('Par $numeroPar: "$espanol"', () {
        final r = axios.traducir(espanol);

        // 1. Debe traducir con éxito
        expect(r.exitoso, isTrue, reason: 'Falló la traducción de "$espanol": ${r.error}');

        // 2. Debe traducir a Kethari
        expect(r.traduccionKethari, equals(esperadoKethari),
            reason: 'Kethari no coincide para "$espanol"');

        // 3. Debe traducir también a Ozh (el enunciado exige siempre ambas lenguas)
        expect(r.traduccionOzh, isNotNull,
            reason: 'Debe generar traducción a Ozh para "$espanol"');
        expect(r.traduccionOzh, isNotEmpty);

        // 4. Debe guardarse en la BD con validación "sin validar"
        final historial = axios.historial();
        expect(historial, isNotEmpty);
        final ultimo = historial.last;
        expect(ultimo['original'], equals(espanol));
        expect(ultimo['kethari'], equals(esperadoKethari));
        expect(ultimo['ozh'], equals(r.traduccionOzh));
        expect(ultimo['validacion'], equals('sin validar'),
            reason: 'Sin componente validador debe registrarse como "sin validar"');
      });
    });
  });
}
