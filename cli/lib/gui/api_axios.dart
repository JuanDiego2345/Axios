/// API de la interfaz gráfica: traduce las cuatro órdenes del CLI a JSON.
///
/// No tiene lógica propia de traducción: llama a [AxiosCli], igual que la
/// consola. Así la interfaz y el CLI siempre dan el mismo resultado.
library;

import 'dart:io';

import '../cli.dart';

class ApiAxios {
  final AxiosCli axios;

  ApiAxios(this.axios);

  /// `traducir "<pregunta>"`: el resultado de cada fase, para la traza.
  Map<String, Object?> traducir(String pregunta, {bool traza = false}) {
    final r = axios.traducir(pregunta, conTraza: traza);
    final lex = r.resultadoLexico;
    final sint = r.resultadoSintactico;

    Map<String, Object?>? generador(String? texto, String? error,
            List<String>? pasos, bool hay) =>
        hay ? {'texto': texto, 'error': error, 'traza': pasos ?? const []} : null;

    return {
      'entrada': r.entrada,
      'normalizado': lex.normalizado,
      'ajustesSignos': lex.ajustesSignos,
      'correcciones': [
        for (final c in lex.correcciones)
          {
            'original': c.original,
            'corregida': c.corregida,
            'distancia': c.distancia,
          }
      ],
      'numeros': [
        for (final n in lex.numerosConvertidos)
          {'texto': n.texto, 'valor': n.valor}
      ],
      'tokens': [
        for (final t in lex.tokens)
          {
            'tipo': t.tipo.name,
            'lexema': t.lexema,
            'posicion': t.posicion,
            if (t.valor != null) 'valor': t.valor,
          }
      ],
      'errorSintactico': sint.error == null
          ? null
          : {'mensaje': sint.error!.mensaje, 'columna': sint.error!.columna},
      'advertencias': sint.advertencias,
      'trazaSintactica': sint.traza,
      'arbol': sint.arbol?.dibujar(),
      'kethari': generador(r.resultadoKethari?.texto, r.resultadoKethari?.error,
          r.resultadoKethari?.traza, r.resultadoKethari != null),
      'ozh': generador(r.resultadoOzh?.texto, r.resultadoOzh?.error,
          r.resultadoOzh?.traza, r.resultadoOzh != null),
      'idHistorial': r.idHistorial,
    };
  }

  /// `cargar <archivo>` con un archivo que llega desde el navegador.
  ///
  /// Se guarda con su nombre en una carpeta temporal y se carga igual que
  /// desde la consola.
  Map<String, Object?> cargar(String nombre, String contenido) {
    final limpio = nombre.split('/').last.split('\\').last.trim();
    if (limpio.isEmpty) {
      throw const FormatException('El archivo no tiene nombre.');
    }
    final dir = Directory.systemTemp.createTempSync('axios_carga_');
    final archivo = File('${dir.path}/$limpio')..writeAsStringSync(contenido);
    final r = axios.cargar(archivo.path);
    return {'archivo': limpio, 'tipo': r.tipo, 'filas': r.filas};
  }

  /// `historial [desde <fecha>]`.
  List<Map<String, Object?>> historial({String? desde}) => [
        for (final h in axios.historial(desde: desde))
          {for (final e in h.entries) e.key: e.value}
      ];

  /// `palabra <término>`, opcionalmente en una fecha pasada.
  Map<String, Object?>? palabra(String termino, {String? fecha}) {
    final t = axios.palabra(termino, fecha: fecha);
    if (t == null) return null;
    return {
      'lema': t.lema,
      'categoria': t.categoria,
      'kethari': t.kethari,
      'ozh': t.ozh,
    };
  }
}
