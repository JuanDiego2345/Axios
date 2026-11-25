/// Servidor de la interfaz gráfica (bonus de la rúbrica, criterio 25).
///
/// Usa solo `dart:io` (biblioteca estándar). Escucha únicamente en la
/// dirección local 127.0.0.1: no es un servicio en red y funciona sin
/// conexión. Sirve `web/index.html` y una API JSON con las cuatro órdenes.
library;

import 'dart:convert';
import 'dart:io';

import 'api_axios.dart';

class ServidorAxios {
  final ApiAxios api;

  /// Página de la interfaz.
  final File pagina;

  HttpServer? _servidor;

  ServidorAxios(this.api, this.pagina);

  int get puerto => _servidor!.port;

  /// Arranca en [puerto] (0 = uno libre cualquiera, útil en pruebas).
  Future<void> iniciar({int puerto = 8080}) async {
    _servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, puerto);
    _servidor!.listen(_atender);
  }

  Future<void> detener() async => _servidor?.close(force: true);

  Future<void> _atender(HttpRequest req) async {
    final res = req.response;
    try {
      final ruta = req.uri.path;
      final q = req.uri.queryParameters;

      if (req.method == 'GET' && (ruta == '/' || ruta == '/index.html')) {
        res.headers.contentType = ContentType.html;
        res.write(pagina.readAsStringSync());
      } else if (req.method == 'POST' && ruta == '/api/traducir') {
        final cuerpo = await _leerJson(req);
        final pregunta = (cuerpo['pregunta'] as String? ?? '').trim();
        if (pregunta.isEmpty) {
          _json(res, {'error': 'Escribe una pregunta.'}, 400);
          return;
        }
        _json(res, api.traducir(pregunta, traza: cuerpo['traza'] == true));
      } else if (req.method == 'POST' && ruta == '/api/cargar') {
        final cuerpo = await _leerJson(req);
        _json(
            res,
            api.cargar(cuerpo['nombre'] as String? ?? '',
                cuerpo['contenido'] as String? ?? ''));
      } else if (req.method == 'GET' && ruta == '/api/historial') {
        final desde = q['desde'];
        _json(res, api.historial(
            desde: desde == null || desde.isEmpty ? null : desde));
      } else if (req.method == 'GET' && ruta == '/api/palabra') {
        final termino = (q['termino'] ?? '').trim();
        final fecha = q['fecha'];
        if (termino.isEmpty) {
          _json(res, {'error': 'Escribe una palabra.'}, 400);
          return;
        }
        final p = api.palabra(termino,
            fecha: fecha == null || fecha.isEmpty ? null : fecha);
        if (p == null) {
          _json(res, {'error': 'El sistema no conoce "$termino".'}, 404);
          return;
        }
        _json(res, p);
      } else {
        _json(res, {'error': 'No existe ${req.method} $ruta'}, 404);
      }
    } catch (e) {
      // Ninguna pregunta se pierde y el sistema siempre responde.
      _json(res, {'error': '$e'}, 500);
    } finally {
      await res.close();
    }
  }

  Future<Map<String, dynamic>> _leerJson(HttpRequest req) async {
    final texto = await utf8.decoder.bind(req).join();
    if (texto.trim().isEmpty) return const {};
    return jsonDecode(texto) as Map<String, dynamic>;
  }

  void _json(HttpResponse res, Object? datos, [int estado = 200]) {
    res.statusCode = estado;
    res.headers.contentType = ContentType.json;
    res.write(jsonEncode(datos));
  }
}
