import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import '../../lib/bd/conexion.dart';

void main() {
  test('rechaza una version de lexico con ID inexistente', () {
    final db = abrirBd(':memory:');

    expect(
      () => db.execute('''
        INSERT INTO lexico_version
        (lexico_id, vigente_desde)
        VALUES (999, '2026-11-21')
      '''),
      throwsA(isA<SqliteException>()),
    );

    db.close();
  });

  test('rechaza una señal con carga inexistente', () {
    final db = abrirBd(':memory:');

    expect(
      () => db.execute('''
        INSERT INTO senal
        (dia, voz, transcripcion, salida, carga_id)
        VALUES (1, 'voz', 'hola', 'salida', 999)
      '''),
      throwsA(isA<SqliteException>()),
    );

    db.close();
  });
}