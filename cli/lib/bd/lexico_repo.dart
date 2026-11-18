
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

class Traduccion {
  final String lema;
  final String categoria;
  final String? kethari;
  final String? ozh;

  Traduccion(this.lema, this.categoria, this.kethari, this.ozh);
}

class LexicoRepo {
  final Database db;

  LexicoRepo(this.db);

  String _hoy() => DateTime.now().toIso8601String().substring(0, 10);

  // Lee un archivo CSV y separa sus columnas.
  List<List<String>> _leerCsv(String ruta) {
    final lineas = File(ruta).readAsLinesSync();

    return lineas
        .skip(1)
        .where((l) => l.trim().isNotEmpty)
        .map((l) => l.split(',').map((c) => c.trim()).toList())
        .toList();
  }

  // Carga el léxico y conserva las versiones anteriores.
  int cargarLexico(String ruta, {String? fecha}) {
    final hoy = fecha ?? _hoy();
    final filas = _leerCsv(ruta);

    db.execute('BEGIN');

    try {
      for (final f in filas) {
        if (f.length < 4) {
          throw FormatException('Fila inválida en el léxico: $f');
        }

        final lema = f[0];
        final cat = f[1];
        final k = f[2];
        final o = f[3];

        db.execute(
          'INSERT OR IGNORE INTO lexico (lema_es, categoria) VALUES (?, ?)',
          [lema, cat],
        );

        final id = db.select(
          'SELECT id FROM lexico WHERE lema_es = ? AND categoria = ?',
          [lema, cat],
        ).first['id'] as int;

        final vigente = db.select(
          'SELECT kethari, ozh FROM lexico_version '
          'WHERE lexico_id = ? AND vigente_hasta IS NULL',
          [id],
        );

        if (vigente.isNotEmpty &&
            vigente.first['kethari'] == k &&
            vigente.first['ozh'] == o) {
          continue;
        }

        db.execute(
          'UPDATE lexico_version SET vigente_hasta = ? '
          'WHERE lexico_id = ? AND vigente_hasta IS NULL',
          [hoy, id],
        );

        db.execute(
          'INSERT INTO lexico_version '
          '(lexico_id, kethari, ozh, vigente_desde, origen) '
          'VALUES (?, ?, ?, ?, ?)',
          [id, k, o, hoy, ruta],
        );
      }

      db.execute(
        'INSERT INTO carga (archivo, fecha, filas) VALUES (?, ?, ?)',
        [ruta, hoy, filas.length],
      );

      db.execute('COMMIT');
    } catch (e) {
      db.execute('ROLLBACK');
      rethrow;
    }

    return filas.length;
  }

  // Carga señales y conserva sus versiones anteriores.
  int cargarSenales(String ruta, {String? fecha}) {
    final hoy = fecha ?? _hoy();
    final filas = _leerCsv(ruta);

    db.execute('BEGIN');

    try {
      for (final f in filas) {
        if (f.length < 2) {
          throw FormatException('Fila inválida en las señales: $f');
        }

        final nombre = f[0];
        final significado = f[1];

        final vigente = db.select(
          'SELECT significado FROM senal '
          'WHERE nombre = ? AND vigente_hasta IS NULL',
          [nombre],
        );

        if (vigente.isNotEmpty &&
            vigente.first['significado'] == significado) {
          continue;
        }

        db.execute(
          'UPDATE senal SET vigente_hasta = ? '
          'WHERE nombre = ? AND vigente_hasta IS NULL',
          [hoy, nombre],
        );

        db.execute(
          'INSERT INTO senal (nombre, significado, vigente_desde) '
          'VALUES (?, ?, ?)',
          [nombre, significado, hoy],
        );
      }

      db.execute(
        'INSERT INTO carga (archivo, fecha, filas) VALUES (?, ?, ?)',
        [ruta, hoy, filas.length],
      );

      db.execute('COMMIT');
    } catch (e) {
      db.execute('ROLLBACK');
      rethrow;
    }

    return filas.length;
  }

  // Busca una palabra y permite consultar su traducción por fecha.
  Traduccion? buscar(String lema, {String? fecha}) {
    final f = fecha ?? _hoy();

    final r = db.select(
      'SELECT l.lema_es, l.categoria, v.kethari, v.ozh '
      'FROM lexico l '
      'JOIN lexico_version v ON v.lexico_id = l.id '
      'WHERE l.lema_es = ? AND v.vigente_desde <= ? '
      'AND (v.vigente_hasta IS NULL OR v.vigente_hasta > ?) '
      'LIMIT 1',
      [lema, f, f],
    );

    if (r.isEmpty) return null;

    final x = r.first;

    return Traduccion(
      x['lema_es'] as String,
      x['categoria'] as String,
      x['kethari'] as String?,
      x['ozh'] as String?,
    );
  }

  // Devuelve las señales que están vigentes.
  List<Map<String, String?>> senalesVigentes() {
    return db
        .select(
          'SELECT nombre, significado FROM senal '
          'WHERE vigente_hasta IS NULL ORDER BY id',
        )
        .map((r) => {
              'nombre': r['nombre'] as String?,
              'significado': r['significado'] as String?,
            })
        .toList();
  }

  // Consulta todas las versiones que ha tenido una palabra.
  List<Map<String, dynamic>> historialPalabra(String lema) {
    final resultados = db.select(
      'SELECT l.lema_es, l.categoria, '
      'v.kethari, v.ozh, v.vigente_desde, '
      'v.vigente_hasta, v.origen '
      'FROM lexico l '
      'JOIN lexico_version v ON v.lexico_id = l.id '
      'WHERE l.lema_es = ? '
      'ORDER BY v.vigente_desde ASC',
      [lema],
    );

    return resultados.map((r) => {
      'lema_es': r['lema_es'],
      'categoria': r['categoria'],
      'kethari': r['kethari'],
      'ozh': r['ozh'],
      'vigente_desde': r['vigente_desde'],
      'vigente_hasta': r['vigente_hasta'],
      'origen': r['origen'],
    }).toList();
  }

  // Consulta el historial de archivos cargados.
  List<Map<String, dynamic>> historialCargas() {
    final resultados = db.select(
      'SELECT archivo, fecha, filas '
      'FROM carga '
      'ORDER BY fecha DESC, id DESC',
    );

    return resultados.map((r) => {
      'archivo': r['archivo'],
      'fecha': r['fecha'],
      'filas': r['filas'],
    }).toList();
  }
}
