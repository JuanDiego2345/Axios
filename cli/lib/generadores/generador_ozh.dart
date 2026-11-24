/// Generador de Ozh (fase 7b): convierte el árbol intermedio en una
/// oración Ozh siguiendo el manual v0.7.
library;

import '../sintactico/arbol.dart';
import 'fuente_ozh.dart';
import 'numeros.dart';

class ResultadoOzh {
  final String? texto;
  final String? error;
  final List<String> traza;

  const ResultadoOzh._(this.texto, this.error, this.traza);

  const ResultadoOzh.fallo(String error, [List<String> traza = const []])
      : this._(null, error, traza);

  bool get ok => texto != null;

  @override
  String toString() => ok ? texto! : 'sin traducción: $error';
}

class GeneradorOzh {
  final FuenteOzh fuente;

  const GeneradorOzh(this.fuente);

  ResultadoOzh generar(Oracion oracion) => _GeneracionOzh(fuente, oracion).ejecutar();
}

class _GeneracionOzh {
  final FuenteOzh fuente;
  final Oracion o;

  final partes = <String>[];
  final traza = <String>[];
  final faltan = <String>[];

  _GeneracionOzh(this.fuente, this.o);

  ResultadoOzh ejecutar() {
    // 1. Negación
    if (o.negada) {
      partes.add(fuente.negacion);
      traza.add('negación: ${fuente.negacion}');
    }

    // 2. Tiempo verbal (partícula previa)
    if (o.tiempo == Tiempo.pasado) {
      partes.add(fuente.tiempoPasado);
      traza.add('tiempo pasado: ${fuente.tiempoPasado}');
    } else if (o.tiempo == Tiempo.futuro) {
      partes.add(fuente.tiempoFuturo);
      traza.add('tiempo futuro: ${fuente.tiempoFuturo}');
    }

    // 3. Verbo (con prefijo ʔa- si es pregunta)
    _generarVerbo();

    // 4. Partícula de enlace / aspecto
    _generarParticula();

    // 5. Sujeto
    _generarParticipante(o.sujeto, 'sujeto');

    // 6. Objeto
    if (o.objeto != null) {
      _generarParticipante(o.objeto!, 'objeto');
    }

    // 7. Palabra interrogativa (al final en Ozh)
    if (o.modo == Modo.preguntaAbierta && o.interrogativo != null) {
      final palabraInterr = fuente.interrogativo(o.interrogativo!);
      if (palabraInterr != null) {
        partes.add(palabraInterr);
        traza.add('interrogativo al final: $palabraInterr');
      } else {
        faltan.add(o.interrogativo!);
      }
    }

    if (faltan.isNotEmpty) {
      final error = 'el manual no tiene palabra Ozh para ${faltan.join(', ')}.';
      return ResultadoOzh.fallo(error, traza);
    }

    final texto = partes.join(' ');
    traza.add('resultado Ozh: $texto');
    return ResultadoOzh._(texto, null, List.unmodifiable(traza));
  }

  void _generarVerbo() {
    final raiz = fuente.verbo(o.verbo);
    if (raiz == null) {
      faltan.add(o.verbo);
      return;
    }

    String formaVerbo = raiz;
    if (o.modo == Modo.preguntaAbierta || o.modo == Modo.preguntaSiNo) {
      formaVerbo = '${fuente.prefijoPregunta.replaceAll('-', '')}$raiz';
      traza.add('verbo en pregunta: $formaVerbo');
    } else {
      traza.add('verbo: $formaVerbo');
    }
    partes.add(formaVerbo);
  }

  void _generarParticula() {
    Persona p = Persona.tercera;
    Numero n = Numero.singular;
    final s = o.sujeto;
    if (s is Pronominal) {
      p = s.persona;
      n = s.numero;
    }
    final particula = fuente.particulaPara(persona: p, numero: n, tiempo: o.tiempo);
    partes.add(particula);
    traza.add('partícula: $particula');
  }

  void _generarParticipante(Participante p, String rol) {
    if (p is Pronominal) {
      final pr = fuente.pronombre(p.persona, p.numero);
      if (pr != null) {
        partes.add(pr);
        traza.add('$rol pronombre: $pr');
      } else {
        faltan.add('${p.persona.name} ${p.numero.name}');
      }
    } else if (p is Nominal) {
      final pedazos = <String>[];
      if (p.cantidad != null) {
        final numEscrito = escribirNumero(p.cantidad!, fuente.reglasNumero, fuente.cifra);
        if (numEscrito.ok) {
          pedazos.add(numEscrito.texto!);
        }
      }
      final sust = fuente.sustantivo(p.concepto);
      if (sust != null) {
        pedazos.add(sust);
      } else {
        faltan.add(p.concepto);
      }
      if (p.poseedor != null) {
        final pos = fuente.pronombre(p.poseedor!.persona, p.poseedor!.numero);
        if (pos != null) {
          pedazos.add(pos);
        }
      }
      if (pedazos.isNotEmpty) {
        final str = pedazos.join(' ');
        partes.add(str);
        traza.add('$rol nominal: $str');
      }
    } else if (p is Incognita) {
      // En preguntas con incógnita como sujeto/objeto, Ozh coloca la palabra interrogativa al final
      traza.add('$rol: incógnita ${p.concepto}');
    }
  }
}

