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

  group('cantidades (base 6, bitácora K-05)', () {
    test('día 3: ra-sel kumesh vinok (15 = 2·6 + 3, plural con número)', () {
      const o = Oracion(
        modo: Modo.afirmacion,
        negada: false,
        tiempo: Tiempo.pasado,
        verbo: 'VENIR',
        sujeto: Nominal('NAVE', numero: Numero.plural, cantidad: 15),
      );
      expect(kethari(o), 'ra-sel kumesh vinok');
    });

    test('día 7: anir ti-vo lunesh tepime (6 = 1·6 + 0)', () {
      const o = Oracion(
        modo: Modo.afirmacion,
        negada: false,
        tiempo: Tiempo.futuro,
        verbo: 'ESPERAR',
        sujeto: nosotros,
        objeto: Nominal('CICLO', numero: Numero.plural, cantidad: 6),
      );
      expect(kethari(o), 'anir ti-vo lunesh tepime');
    });

    test('una sola cifra: ti kum (1, singular)', () {
      const o = Oracion(
        modo: Modo.afirmacion,
        negada: false,
        tiempo: Tiempo.pasado,
        verbo: 'VENIR',
        sujeto: Nominal('NAVE', numero: Numero.singular, cantidad: 1),
      );
      expect(kethari(o), 'ti kum vinok');
    });

    test('9.999, el máximo del enunciado: ti-ti-mok-ti-mok-sel', () {
      const o = Oracion(
        modo: Modo.afirmacion,
        negada: false,
        tiempo: Tiempo.presente,
        verbo: 'VER',
        sujeto: nosotros,
        objeto: Nominal('ESTRELLA', numero: Numero.plural, cantidad: 9999),
      );
      expect(kethari(o), 'anir ti-ti-mok-ti-mok-sel sorinesh kor');
    });

    test('poseedor antes del número: anir ra kumesh (bitácora K-08)', () {
      const o = Oracion(
        modo: Modo.afirmacion,
        negada: false,
        tiempo: Tiempo.pasado,
        verbo: 'VENIR',
        sujeto: Nominal('NAVE',
            numero: Numero.plural,
            cantidad: 2,
            poseedor: Poseedor(Persona.primera, Numero.plural)),
      );
      expect(kethari(o), 'anir ra kumesh vinok');
    });

    test('la traza muestra las cifras en base 6', () {
      const o = Oracion(
        modo: Modo.afirmacion,
        negada: false,
        tiempo: Tiempo.pasado,
        verbo: 'VENIR',
        sujeto: Nominal('NAVE', numero: Numero.plural, cantidad: 15),
      );
      final r = generador.generar(o);
      expect(r.traza, contains('cantidad de sujeto: 15 -> ra-sel (base 6: 2 3)'));
    });
  });

  group('señales de la semana 2', () {
    test('día 8: iresh tekaesh nuthal (teka = territorio reclamado, K-09)', () {
      const o = Oracion(
        modo: Modo.afirmacion,
        negada: true,
        tiempo: Tiempo.presente,
        verbo: 'QUERER',
        sujeto: Pronominal(Persona.tercera, Numero.plural),
        objeto: Nominal('TERRITORIO_RECLAMADO', numero: Numero.plural),
      );
      expect(kethari(o), 'iresh tekaesh nuthal');
    });

    test('día 9: ir yorr mi ka (pregunta de sí o no con ser)', () {
      const o = Oracion(
        modo: Modo.preguntaSiNo,
        negada: false,
        tiempo: Tiempo.presente,
        verbo: 'SER',
        sujeto: Pronominal(Persona.tercera, Numero.singular),
        objeto: Nominal('CRIATURA', numero: Numero.singular),
      );
      expect(kethari(o), 'ir yorr mi ka');
    });

    test('día 10: anir mok-ra sorinesh korok (26 = 4·6 + 2, K-05)', () {
      const o = Oracion(
        modo: Modo.afirmacion,
        negada: false,
        tiempo: Tiempo.pasado,
        verbo: 'VER',
        sujeto: nosotros,
        objeto: Nominal('ESTRELLA', numero: Numero.plural, cantidad: 26),
      );
      expect(kethari(o), 'anir mok-ra sorinesh korok');
    });

    test('"tierra" ya no se traduce como teka: lo explica (K-09)', () {
      const o = Oracion(
        modo: Modo.preguntaSiNo,
        negada: false,
        tiempo: Tiempo.presente,
        verbo: 'QUERER',
        sujeto: ustedes,
        objeto: Nominal('TIERRA',
            numero: Numero.singular,
            poseedor: Poseedor(Persona.primera, Numero.plural)),
      );
      final r = generador.generar(o);
      expect(r.ok, isFalse);
      expect(r.error, contains('TIERRA'));
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
      'Quince naves llegaron': 'ra-sel kumesh vinok',
      'Nosotros esperaremos seis ciclos': 'anir ti-vo lunesh tepime',
      '¿Van a llegar quince naves?': 'ra-sel kumesh vinime ka',
      'Ellos no quieren territorios reclamados.': 'iresh tekaesh nuthal',
      '¿Es él una criatura?': 'ir yorr mi ka',
      'Nosotros vimos veintiséis estrellas.': 'anir mok-ra sorinesh korok',
    };
    pares.forEach((espanol, esperado) {
      test('"$espanol" -> $esperado', () {
        expect(traducir(espanol), esperado);
      });
    });

    test('dos verbos seguidos no llegan al generador (K-10)', () {
      final r = parser.analizar(
          lexico.procesar('¿Quieren visitar la tierra?').tokens);
      expect(r.arbol, isNull);
      expect(r.error!.mensaje, contains('dos verbos'));
    });
  });
}
