import 'dart:convert';
import 'dart:io';

import 'package:cli/cli.dart';
import 'package:cli/gui.dart';
import 'package:test/test.dart';

// La interfaz gráfica usa las mismas órdenes del CLI (bonus, criterio 25).
void main() {
  late AxiosCli axios;
  late ServidorAxios servidor;
  final cliente = HttpClient();

  setUp(() async {
    axios = AxiosCli.crear(rutaDatos: 'datos', dbCustom: abrirBd(':memory:'));
    axios.cargar('datos/lexico_inicial.csv');
    servidor = ServidorAxios(ApiAxios(axios), File('web/index.html'));
    await servidor.iniciar(puerto: 0); // un puerto libre
  });

  tearDown(() async {
    await servidor.detener();
    axios.cerrar();
  });

  Future<(int, dynamic)> pedir(String metodo, String ruta,
      [Map<String, Object?>? cuerpo]) async {
    final req = await cliente.openUrl(
        metodo, Uri.parse('http://127.0.0.1:${servidor.puerto}$ruta'));
    if (cuerpo != null) {
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(jsonEncode(cuerpo)));
    }
    final res = await req.close();
    final texto = await utf8.decoder.bind(res).join();
    final esJson = res.headers.contentType?.mimeType == 'application/json';
    return (res.statusCode, esJson ? jsonDecode(texto) : texto);
  }

  test('sirve la página', () async {
    final (estado, html) = await pedir('GET', '/');
    expect(estado, 200);
    expect(html, contains('Axios'));
  });

  test('traducir devuelve las dos lenguas y lo registra', () async {
    final (estado, r) =
        await pedir('POST', '/api/traducir', {'pregunta': 'Queremos paz'});
    expect(estado, 200);
    expect(r['kethari']['texto'], 'anir parn thal');
    expect(r['ozh'], isNotNull);
    expect(r['idHistorial'], isNotNull);

    final (_, historial) = await pedir('GET', '/api/historial');
    expect((historial as List).single['original'], 'Queremos paz');
  });

  test('modo traza: devuelve cada fase', () async {
    final (_, r) = await pedir('POST', '/api/traducir',
        {'pregunta': '¿Cuándo vendrán ustedes?', 'traza': true});
    expect(r['tokens'], isNotEmpty);
    expect(r['arbol'], contains('VENIR'));
    expect(r['kethari']['traza'], isNotEmpty);
  });

  test('una pregunta que no se entiende responde con la explicación', () async {
    final (estado, r) = await pedir('POST', '/api/traducir',
        {'pregunta': '¿Quieren visitar la tierra?'});
    expect(estado, 200);
    expect(r['errorSintactico']['mensaje'], contains('dos verbos'));
  });

  test('pregunta vacía: 400 con explicación', () async {
    final (estado, r) = await pedir('POST', '/api/traducir', {'pregunta': ''});
    expect(estado, 400);
    expect(r['error'], isNotEmpty);
  });

  test('cargar desde el navegador aplica la corrección de la semana 2',
      () async {
    final contenido = File('datos/senales_semana2.txt').readAsStringSync();
    final (estado, r) = await pedir('POST', '/api/cargar',
        {'nombre': 'senales_semana2.txt', 'contenido': contenido});
    expect(estado, 200, reason: '$r');

    final (_, tierra) = await pedir('GET', '/api/palabra?termino=tierra');
    expect(tierra['kethari'], isNull);
  });

  test('palabra desconocida: 404 con explicación', () async {
    final (estado, r) = await pedir('GET', '/api/palabra?termino=xyzzy');
    expect(estado, 404);
    expect(r['error'], contains('xyzzy'));
  });
}
