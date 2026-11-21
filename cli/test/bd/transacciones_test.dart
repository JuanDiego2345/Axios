import 'dart:io';
import 'package:test/test.dart';
import '../../lib/bd/conexion.dart';
import '../../lib/bd/lexico_repo.dart';

void main() {
  test('una carga invalida revierte todos los cambios', () {
    final db = abrirBd(':memory:');
    final repo = LexicoRepo(db);

    final archivo = File('test_lexico_temporal.csv');

    archivo.writeAsStringSync('''
lema_es,categoria,kethari,ozh
agua,sustantivo,dahl,naʔ
fila_invalida,sustantivo
''');

    try {
      expect(
        () => repo.cargarLexico(archivo.path),
        throwsA(isA<FormatException>()),
      );

      final registros = db.select('SELECT * FROM lexico');

      expect(registros, isEmpty);
    } finally {
      if (archivo.existsSync()) {
        archivo.deleteSync();
      }
      db.close();
    }
  });
}