import 'package:cli/generadores.dart';
import 'package:cli/lexico.dart';
import 'package:cli/sintactico.dart';
import 'package:test/test.dart';

void main() {
  // Datos reales de datos/kethari: el generador no conoce palabras propias.
  final generador = GeneradorKethari(FuenteKethariJson());

  String kethari(Oracion o) {
    final r = generador.generar(o);
    expect(r.error, isNull, reason: 'no debía fallar: ${r.error}');
    return r.texto!;
  }

  const nosotros = Pronominal(Persona.primera, Numero.plural, inferido: true);
  const ustedes = Pronominal(Persona.segunda, Numero.plural);

  group('señales Kethari del registro', () {
    test('día 1: anir ombraesh salok (plural y pasado)', () {
      const o = Oracion(
        modo: Modo.afirmacion,
        negada: false,
        tiempo: Tiempo.pasado,
        verbo: 'ENVIAR',
        sujeto: nosotros,
        objeto: Nominal('MENSAJE', numero: Numero.plural),
      );
      expect(kethari(o), 'anir ombraesh salok');
    });

    test('día 2: "Queremos paz" -> anir parn thal (anir, bitácora K-01)', () {
      const o = Oracion(
        modo: Modo.afirmacion,
        negada: false,
        tiempo: Tiempo.presente,
        verbo: 'QUERER',
        sujeto: nosotros,
        objeto: Nominal('PAZ', numero: Numero.singular),
      );
      expect(kethari(o), 'anir parn thal');
    });

    test('día 4: anir ulesh nukorok (objeto pronombre, negación y pasado)',
        () {
      const o = Oracion(
        modo: Modo.afirmacion,
        negada: true,
        tiempo: Tiempo.pasado,
        verbo: 'VER',
        sujeto: nosotros,
        objeto: ustedes,
      );
      expect(kethari(o), 'anir ulesh nukorok');
    });

    test('día 5: kom ulesh vinime ka (interrogativo al principio, futuro)',
        () {
      const o = Oracion(
        modo: Modo.preguntaAbierta,
        interrogativo: 'CUANDO',
        rolInterrogativo: RolInterrogativo.tiempo,
        negada: false,
        tiempo: Tiempo.futuro,
        verbo: 'VENIR',
        sujeto: ustedes,
      );
      expect(kethari(o), 'kom ulesh vinime ka');
    });

    test('día 6: sem ombra salok ka (quién es el sujeto, no se repite)', () {
      const o = Oracion(
        modo: Modo.preguntaAbierta,
        interrogativo: 'QUIEN',
        rolInterrogativo: RolInterrogativo.sujeto,
        negada: false,
        tiempo: Tiempo.pasado,
        verbo: 'ENVIAR',
        sujeto: Incognita('QUIEN'),
        objeto: Nominal('MENSAJE', numero: Numero.singular),
      );
      expect(kethari(o), 'sem ombra salok ka');
    });
  });

  group('reglas del manual', () {
    test('ejemplo del manual: an dahl thal (presente sin sufijo)', () {
      const o = Oracion(
        modo: Modo.afirmacion,
        negada: false,
        tiempo: Tiempo.presente,
        verbo: 'QUERER',
        sujeto: Pronominal(Persona.primera, Numero.singular),
        objeto: Nominal('AGUA', numero: Numero.singular),
      );
      expect(kethari(o), 'an dahl thal');
    });

    test('poseedor delante: "tu planeta" -> ul vael', () {
      const o = Oracion(
        modo: Modo.afirmacion,
        negada: false,
        tiempo: Tiempo.pasado,
        verbo: 'VER',
        sujeto: Pronominal(Persona.primera, Numero.singular),
        objeto: Nominal('PLANETA',
            numero: Numero.singular,
            poseedor: Poseedor(Persona.segunda, Numero.singular)),
      );
      expect(kethari(o), 'an ul vael korok');
    });

    test('pregunta de sí o no: ulesh anir vael nukorok ka', () {
      const o = Oracion(
        modo: Modo.preguntaSiNo,
        negada: true,
        tiempo: Tiempo.pasado,
        verbo: 'VER',
        sujeto: ustedes,
        objeto: Nominal('PLANETA',
            numero: Numero.singular,
            poseedor: Poseedor(Persona.primera, Numero.plural)),
      );
      expect(kethari(o), 'ulesh anir vael nukorok ka');
    });

    test('qué es el objeto: kel ulesh thal ka', () {
      const o = Oracion(
        modo: Modo.preguntaAbierta,
        interrogativo: 'QUE',
        rolInterrogativo: RolInterrogativo.objeto,
        negada: false,
        tiempo: Tiempo.presente,
        verbo: 'QUERER',
        sujeto: ustedes,
        objeto: Incognita('QUE'),
      );
      expect(kethari(o), 'kel ulesh thal ka');
    });

    test('cuántos: kai kumesh vinok ka (bitácora K-03)', () {
      const o = Oracion(
        modo: Modo.preguntaAbierta,
        interrogativo: 'CUANTOS',
        rolInterrogativo: RolInterrogativo.cantidad,
        negada: false,
        tiempo: Tiempo.pasado,
        verbo: 'VENIR',
        sujeto: Nominal('NAVE', numero: Numero.plural, preguntaCantidad: true),
      );
      expect(kethari(o), 'kai kumesh vinok ka');
    });

    test('dónde y verbo ser: dor iresh mi ka', () {
      const o = Oracion(
        modo: Modo.preguntaAbierta,
        interrogativo: 'DONDE',
        rolInterrogativo: RolInterrogativo.lugar,
        negada: false,
        tiempo: Tiempo.presente,
        verbo: 'SER',
        sujeto: Pronominal(Persona.tercera, Numero.plural),
      );
      expect(kethari(o), 'dor iresh mi ka');
    });
  });

  group('no inventa (rúbrica: palabras desconocidas)', () {
    test('verbo sin palabra Kethari: no traduce y lo explica', () {
      const o = Oracion(
        modo: Modo.afirmacion,
        negada: false,
        tiempo: Tiempo.presente,
        verbo: 'BAILAR',
        sujeto: nosotros,
      );
      final r = generador.generar(o);
      expect(r.ok, isFalse);
      expect(r.texto, isNull);
      expect(r.error, contains('BAILAR'));
    });

    test('cantidades todavía no se generan (bitácora K-05)', () {
      const o = Oracion(
        modo: Modo.afirmacion,
        negada: false,
        tiempo: Tiempo.pasado,
        verbo: 'VENIR',
        sujeto: Nominal('NAVE', numero: Numero.plural, cantidad: 15),
      );
      final r = generador.generar(o);
      expect(r.ok, isFalse);
      expect(r.error, contains('base 6'));
    });

    test('la traza cuenta cada decisión', () {
      const o = Oracion(
        modo: Modo.afirmacion,
        negada: false,
        tiempo: Tiempo.presente,
        verbo: 'QUERER',
        sujeto: nosotros,
        objeto: Nominal('PAZ', numero: Numero.singular),
      );
      final r = generador.generar(o);
      expect(r.traza, contains(startsWith('verbo: QUERER -> thal')));
      expect(r.traza.last, 'resultado: anir parn thal');
    });
  });

  // Meta de la semana 1: una frase sencilla viaja de español a Kethari.
  group('de punta a punta: español -> árbol -> Kethari', () {
    final parser = AnalizadorSintactico.desde(FuenteLexicoJson());
    final lexico = FaseLexica(parser.vocabulario);

    String traducir(String pregunta) {
      final r = parser.analizar(lexico.procesar(pregunta).tokens);
      expect(r.error, isNull, reason: 'el parser falló: ${r.error}');
      return kethari(r.arbol!);
    }

    final pares = {
      'Queremos paz': 'anir parn thal',
      '¿Cuándo vendrán ustedes?': 'kom ulesh vinime ka',
      '¿Quién envió el mensaje?': 'sem ombra salok ka',
      '¿Ustedes no vieron nuestro planeta?': 'ulesh anir vael nukorok ka',
      '¿Qué quieren ustedes?': 'kel ulesh thal ka',
    };
    pares.forEach((espanol, esperado) {
      test('"$espanol" -> $esperado', () {
        expect(traducir(espanol), esperado);
      });
    });
  });
}
