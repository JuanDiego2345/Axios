import 'package:cli/generadores.dart';
import 'package:cli/lexico.dart';
import 'package:cli/sintactico.dart';
import 'package:test/test.dart';

void main() {
  // Datos reales de datos/ozh: el generador no conoce palabras propias.
  final generador = GeneradorOzh(FuenteOzhJson());

  String ozh(Oracion o) {
    final r = generador.generar(o);
    expect(r.error, isNull, reason: 'no debía fallar: ${r.error}');
    return r.texto!;
  }

  const nosotros = Pronominal(Persona.primera, Numero.plural);
  const ustedes = Pronominal(Persona.segunda, Numero.plural);
  const ellos = Pronominal(Persona.tercera, Numero.plural);

  group('señales Ozh del registro (bitácora O-01)', () {
    test('día 1: ʔoka dra zi ʔenka vesh (pasado -> zi)', () {
      const o = Oracion(
        modo: Modo.afirmacion,
        negada: false,
        tiempo: Tiempo.pasado,
        verbo: 'ENVIAR',
        sujeto: nosotros,
        objeto: Nominal('MENSAJE', numero: Numero.singular),
      );
      expect(ozh(o), 'ʔoka dra zi ʔenka vesh');
    });

    test('día 2: lom tho oruvi ilu (tercera persona -> tho)', () {
      const o = Oracion(
        modo: Modo.afirmacion,
        negada: false,
        tiempo: Tiempo.presente,
        verbo: 'QUERER',
        sujeto: ellos,
        objeto: Nominal('PAZ', numero: Numero.singular),
      );
      expect(ozh(o), 'lom tho oruvi ilu');
    });

    test('día 3: venu sur tho ois-ulo gor (futuro, número, sin plural)', () {
      const o = Oracion(
        modo: Modo.afirmacion,
        negada: false,
        tiempo: Tiempo.futuro,
        verbo: 'VENIR',
        sujeto: Nominal('NAVE', numero: Numero.plural, cantidad: 15),
      );
      expect(ozh(o), 'venu sur tho ois-ulo gor');
    });

    test('día 5: ʔasur mar shavi wem (pregunta: ʔa- e interrogativo al final)',
        () {
      const o = Oracion(
        modo: Modo.preguntaAbierta,
        interrogativo: 'CUANDO',
        rolInterrogativo: RolInterrogativo.tiempo,
        negada: false,
        tiempo: Tiempo.presente,
        verbo: 'VENIR',
        sujeto: ustedes,
      );
      expect(ozh(o), 'ʔasur mar shavi wem');
    });

    test('día 6: ne tal mar shavi (segunda persona -> mar)', () {
      const o = Oracion(
        modo: Modo.afirmacion,
        negada: true,
        tiempo: Tiempo.presente,
        verbo: 'HABLAR',
        sujeto: ustedes,
      );
      expect(ozh(o), 'ne tal mar shavi');
    });

    test('día 7: bo mar ʔen sab drüm (Ozh sí tiene seis: base 10)', () {
      const o = Oracion(
        modo: Modo.afirmacion,
        negada: false,
        tiempo: Tiempo.presente,
        verbo: 'ESPERAR',
        sujeto: Pronominal(Persona.primera, Numero.singular),
        objeto: Nominal('CICLO', numero: Numero.plural, cantidad: 6),
      );
      expect(ozh(o), 'bo mar ʔen sab drüm');
    });

    test('día 8: ʔoka kesh zi oruvi thüm ʔenka (poseedor detrás)', () {
      const o = Oracion(
        modo: Modo.afirmacion,
        negada: false,
        tiempo: Tiempo.pasado,
        verbo: 'VISITAR',
        sujeto: ellos,
        objeto: Nominal('PLANETA',
            numero: Numero.singular,
            poseedor: Poseedor(Persona.primera, Numero.plural)),
      );
      expect(ozh(o), 'ʔoka kesh zi oruvi thüm ʔenka');
    });

    test('día 10: ne lom tho oruvi ilu', () {
      const o = Oracion(
        modo: Modo.afirmacion,
        negada: true,
        tiempo: Tiempo.presente,
        verbo: 'QUERER',
        sujeto: ellos,
        objeto: Nominal('PAZ', numero: Numero.singular),
      );
      expect(ozh(o), 'ne lom tho oruvi ilu');
    });

    test('día 4: con pasado sale ʔoka; la señal no lo trae (O-05)', () {
      const o = Oracion(
        modo: Modo.afirmacion,
        negada: true,
        tiempo: Tiempo.pasado,
        verbo: 'VER',
        sujeto: nosotros,
        objeto: Nominal('NAVE', numero: Numero.singular),
      );
      // Señal: "ne ʔim zi ʔenka gor". Mismo orden, partícula y palabras.
      expect(ozh(o), 'ʔoka ne ʔim zi ʔenka gor');
    });

    test('día 9: el orden coincide; la partícula es la excepción (O-01)', () {
      const o = Oracion(
        modo: Modo.preguntaAbierta,
        interrogativo: 'QUIEN',
        rolInterrogativo: RolInterrogativo.objeto,
        negada: false,
        tiempo: Tiempo.presente,
        verbo: 'ESCUCHAR',
        sujeto: ustedes,
        objeto: Incognita('QUIEN'),
      );
      // Señal: "ʔanem tho shavi wis".
      expect(ozh(o), 'ʔanem mar shavi wis');
    });
  });

  group('reglas del manual', () {
    test('tiempo antes de la negación: ʔoka ne ... (O-02)', () {
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
      expect(ozh(o), 'ʔoka ne ʔaʔim zi shavi thüm ʔenka');
    });

    test('quién como sujeto: va al final y no se repite (O-03)', () {
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
      expect(ozh(o), 'ʔoka ʔadra zi vesh wis');
    });

    test('cuántos: ʔoka ʔasur zi gor wak', () {
      const o = Oracion(
        modo: Modo.preguntaAbierta,
        interrogativo: 'CUANTOS',
        rolInterrogativo: RolInterrogativo.cantidad,
        negada: false,
        tiempo: Tiempo.pasado,
        verbo: 'VENIR',
        sujeto: Nominal('NAVE', numero: Numero.plural, preguntaCantidad: true),
      );
      expect(ozh(o), 'ʔoka ʔasur zi gor wak');
    });

    test('9.999 en base 10: hev-hev-hev-hev', () {
      const o = Oracion(
        modo: Modo.afirmacion,
        negada: false,
        tiempo: Tiempo.presente,
        verbo: 'VER',
        sujeto: nosotros,
        objeto: Nominal('ESTRELLA', numero: Numero.plural, cantidad: 9999),
      );
      expect(ozh(o), 'ʔim mar ʔenka hev-hev-hev-hev ral');
    });
  });

  group('no inventa ni omite (O-04)', () {
    test('palabra sin traducción: no traduce y lo explica', () {
      const o = Oracion(
        modo: Modo.afirmacion,
        negada: false,
        tiempo: Tiempo.presente,
        verbo: 'QUERER',
        sujeto: ustedes,
        objeto: Nominal('TERRITORIO_RECLAMADO', numero: Numero.singular),
      );
      final r = generador.generar(o);
      expect(r.ok, isFalse);
      expect(r.error, contains('TERRITORIO_RECLAMADO'));
    });

    test('poseedor desconocido: no lo quita en silencio', () {
      final o = Oracion(
        modo: Modo.afirmacion,
        negada: false,
        tiempo: Tiempo.presente,
        verbo: 'VER',
        sujeto: nosotros,
        objeto: const Nominal('PLANETA',
            numero: Numero.singular,
            poseedor: Poseedor(Persona.segunda, Numero.plural)),
      );
      final sinPronombres = GeneradorOzh(_SinPronombre2p(FuenteOzhJson()));
      final r = sinPronombres.generar(o);
      expect(r.ok, isFalse);
      expect(r.error, contains('2p'));
    });
  });

  group('preguntas que se leen igual (bitácora K-07)', () {
    test('quién como objeto o como sujeto: avisa', () {
      const comoObjeto = Oracion(
        modo: Modo.preguntaAbierta,
        interrogativo: 'QUIEN',
        rolInterrogativo: RolInterrogativo.objeto,
        negada: false,
        tiempo: Tiempo.presente,
        verbo: 'ESCUCHAR',
        sujeto: ustedes,
        objeto: Incognita('QUIEN'),
      );
      final r = generador.generar(comoObjeto);
      expect(r.advertencias.single, contains('K-07'));
      final k = GeneradorKethari(FuenteKethariJson()).generar(comoObjeto);
      expect(k.texto, 'sem ulesh rhu ka');
      expect(k.advertencias.single, contains('K-07'));
    });

    test('sin incógnita en sujeto u objeto: no avisa', () {
      const o = Oracion(
        modo: Modo.preguntaAbierta,
        interrogativo: 'CUANDO',
        rolInterrogativo: RolInterrogativo.tiempo,
        negada: false,
        tiempo: Tiempo.futuro,
        verbo: 'VENIR',
        sujeto: ustedes,
      );
      expect(generador.generar(o).advertencias, isEmpty);
    });
  });

  group('de punta a punta: español -> árbol -> Ozh', () {
    final parser = AnalizadorSintactico.desde(FuenteLexicoJson());
    final lexico = FaseLexica(parser.vocabulario);

    final pares = {
      'Ellos quieren paz': 'lom tho oruvi ilu',
      'Ellos no quieren paz.': 'ne lom tho oruvi ilu',
      'Ustedes no hablan': 'ne tal mar shavi',
      '¿Cuándo vienen ustedes?': 'ʔasur mar shavi wem',
      'Yo espero seis ciclos': 'bo mar ʔen sab drüm',
      'Antes ellos visitaron nuestro mundo.': 'ʔoka kesh zi oruvi thüm ʔenka',
      '¿Quién envió el mensaje?': 'ʔoka ʔadra zi vesh wis',
    };
    pares.forEach((espanol, esperado) {
      test('"$espanol" -> $esperado', () {
        final r = parser.analizar(lexico.procesar(espanol).tokens);
        expect(r.error, isNull, reason: 'el parser falló: ${r.error}');
        expect(ozh(r.arbol!), esperado);
      });
    });
  });
}

/// Fuente de prueba sin el pronombre 2p, para comprobar que no se omite.
class _SinPronombre2p implements FuenteOzh {
  final FuenteOzh base;
  _SinPronombre2p(this.base);

  @override
  String? pronombre(Persona persona, Numero numero) =>
      persona == Persona.segunda && numero == Numero.plural
          ? null
          : base.pronombre(persona, numero);
  @override
  String? sustantivo(String concepto) => base.sustantivo(concepto);
  @override
  String? verbo(String concepto) => base.verbo(concepto);
  @override
  String? interrogativo(String concepto) => base.interrogativo(concepto);
  @override
  String? cifra(int c) => base.cifra(c);
  @override
  ReglasNumero get reglasNumero => base.reglasNumero;
  @override
  String get tiempoPasado => base.tiempoPasado;
  @override
  String get tiempoFuturo => base.tiempoFuturo;
  @override
  String get negacion => base.negacion;
  @override
  String get prefijoPregunta => base.prefijoPregunta;
  @override
  String? particulaPara(
          {required Persona persona,
          required Numero numero,
          required Tiempo tiempo}) =>
      base.particulaPara(persona: persona, numero: numero, tiempo: tiempo);
}
