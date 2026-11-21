import 'package:cli/cli.dart';
import 'package:test/test.dart';

void main() {
  group('AxiosCli - Cuatro órdenes obligatorias (Criterio 19)', () {
    late AxiosCli axios;

    setUp(() {
      // Usar base de datos en memoria para aislar cada prueba
      axios = AxiosCli.crear(
        rutaDatos: 'datos',
        dbCustom: abrirBd(':memory:'),
      );
    });

    tearDown(() {
      axios.cerrar();
    });

    test('1. traducir registra la pregunta en el historial y devuelve la traducción', () {
      final r = axios.traducir('¿Cuándo vendrán ustedes?', conTraza: true);

      expect(r.exitoso, isTrue);
      expect(r.traduccion, equals('kom ulesh vinime ka'));
      expect(r.idHistorial, isNotNull);

      // Verificar persistencia obligatoria en la base de datos
      final items = axios.historial();
      expect(items.length, equals(1));
      expect(items.first['original'], equals('¿Cuándo vendrán ustedes?'));
      expect(items.first['kethari'], equals('kom ulesh vinime ka'));
      expect(items.first['validacion'], equals('válida'));
    });

    test('1b. traducir con error sintáctico también se registra en el historial', () {
      final r = axios.traducir('palabraDesconocidaXYZ');

      expect(r.exitoso, isFalse);
      expect(r.error, isNotNull);

      // Axios exige que ninguna pregunta se pierda
      final items = axios.historial();
      expect(items.length, equals(1));
      expect(items.first['original'], equals('palabraDesconocidaXYZ'));
      expect(items.first['kethari'], isNull);
      expect(items.first['validacion'], contains('error'));
    });

    test('2. cargar almacena el léxico en la BD', () {
      final res = axios.cargar('datos/lexico_inicial.csv');

      expect(res.filas, greaterThanOrEqualTo(1));
      expect(res.tipo, contains('léxico'));

      // Verificar que se puede consultar la palabra cargada
      final palabra = axios.palabra('agua');
      expect(palabra, isNotNull);
      expect(palabra!.kethari, equals('dahl'));
      expect(palabra.ozh, equals('naʔ'));
    });

    test('2b. cargar almacena señales en la BD', () {
      final res = axios.cargar('datos/senales_inicial.csv');

      expect(res.filas, greaterThanOrEqualTo(1));
      expect(res.tipo, contains('señales'));
    });

    test('3. historial lista y filtra correctamente', () {
      axios.traducir('Queremos paz');
      axios.traducir('¿Cuándo vendrán ustedes?');

      final todos = axios.historial();
      expect(todos.length, equals(2));

      // Filtro por fecha futura no debe retornar nada
      final futuros = axios.historial(desde: '2099-01-01');
      expect(futuros, isEmpty);

      // Filtro por fecha pasada debe retornar todos
      final pasados = axios.historial(desde: '2020-01-01');
      expect(pasados.length, equals(2));
    });

    test('4. palabra busca términos existentes y retorna null si no existen', () {
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
}
