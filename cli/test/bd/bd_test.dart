import 'package:test/test.dart';
import '../../lib/bd/conexion.dart';

void main() {
  test('el esquema crea las cinco tablas', () {
    final db = abrirBd(':memory:');

    final tablas = db
        .select("SELECT name FROM sqlite_master WHERE type = 'table'")
        .map((fila) => fila['name'])
        .toSet();

    expect(
      tablas,
      containsAll([
        'lexico',
        'lexico_version',
        'carga',
        'senal',
        'pregunta',
      ]),
    );

    db.close();
  });
}