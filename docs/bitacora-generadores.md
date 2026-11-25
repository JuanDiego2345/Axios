# Bitácora de decisiones — Generadores (integrante 3)

Formato: problema, opciones, decisión y prueba que la demuestra.
Pruebas en `cli/test/generadores/generador_kethari_test.dart`.

### K-01 · 17/11/2026 · "nosotros": `anul` o `anir`
- **Problema:** el manual da `anul` y `anir` para "nosotros" y la nota 3.5 dice que no son sinónimos. El árbol solo trae `Pronominal(primera, plural)` porque el español no los distingue.
- **Opciones:** (a) `anul` siempre; (b) `anir` siempre; (c) no traducir "nosotros".
- **Evidencia en las señales:** `anir` aparece en el día 1 (enviamos mensajes) y el día 4 (no los vimos *a ustedes*); `anul` en el día 2 (queremos paz) y el día 7 (esperaremos). En el día 4 "nosotros" excluye a los oyentes. La hipótesis más usada en lenguas reales es exclusivo/inclusivo, pero el día 2 no la confirma ni la descarta.
- **Decisión:** (b) `anir`. Quien habla es la Tierra y se dirige a los alienígenas, así que "nosotros" no incluye al oyente, como en el día 4. Está en `datos/kethari/lexico.json` → `pronombres.1p`, no en el código: si lingüística decide otra cosa, se cambia el dato.
- **Prueba:** "día 2: Queremos paz -> anir parn thal" y "día 4: anir ulesh nukorok".

### K-02 · 17/11/2026 · Interrogativo que ocupa el sujeto u objeto
- **Problema:** en "¿Quién envió el mensaje?" el árbol trae `interrogativo: QUIEN` y además `sujeto: Incognita(QUIEN)`. Si se generan los dos, sale `sem sem ombra salok ka`.
- **Opciones:** (a) poner la palabra en su hueco (sujeto/objeto) y no al principio; (b) ponerla al principio y saltar la incógnita.
- **Decisión:** (b). El manual dice que va al principio, y la señal del día 6 (`sem ombra salok ka`) la muestra una sola vez. Para el sujeto (a) y (b) coinciden; para el objeto, (b) da `kel ulesh thal ka`.
- **Prueba:** "día 6: sem ombra salok ka" y "qué es el objeto: kel ulesh thal ka".

### K-03 · 17/11/2026 · "¿Cuántas naves llegaron?"
- **Problema:** el manual no muestra preguntas de cantidad.
- **Opciones:** (a) `kai` al principio y el sustantivo en su lugar; (b) `kai` delante del sustantivo, como un número.
- **Decisión:** (a), porque aplica la regla general de las preguntas ("la palabra interrogativa va al principio") sin inventar otra. El sustantivo va en plural (`kumesh`) porque el árbol lo marca plural. Se revisa si llega una señal con `kai`.
- **Prueba:** "cuántos: kai kumesh vinok ka".

### K-04 · 17/11/2026 · Léxico y afijos fuera del código
- **Problema:** el enunciado prohíbe el léxico y las reglas en el código, y la base de datos todavía no guarda el léxico por concepto (`VENIR`, `NAVE`), que es lo que entrega el árbol.
- **Opciones:** (a) esperar a la BD; (b) escribir las palabras en el generador; (c) archivos de datos detrás de una interfaz, como hizo el parser (S-10).
- **Decisión:** (c). `FuenteKethari` dice qué necesita el generador y `FuenteKethariJson` lo lee de `datos/kethari/` (`lexico.json` y `gramatica.json` con `-ok`, `-ime`, `nu-`, `-esh`, `ka`). Cuando la BD tenga el léxico, se implementa la misma interfaz con SQLite y el generador no cambia. (b) está prohibido.
- **Prueba:** todas las pruebas usan `FuenteKethariJson()` con los datos reales.

### K-05 · 17/11/2026 → resuelta el 19/11/2026 · Cantidades en Kethari
- **Problema:** Kethari no tiene palabras de 6 a 9 (nota 3.5), pero el enunciado pide cantidades hasta 9.999 y la señal del día 7 habla de seis ciclos.
- **Evidencia:** día 3 `ra-sel kumesh` = quince naves; día 7 `ti-vo lunesh` = seis ciclos. Con base 10 serían 23 y 10; con base 6 dan 2·6 + 3 = 15 y 1·6 + 0 = 6, justo lo que dice el decodificador.
- **Opciones:** (a) base 10 y no traducir las cifras 6 a 9; (b) base 6, encadenando cifras con guiones (manual 3.2).
- **Decisión (17/11):** en la semana 1 no traducir cantidades y explicarlo. **(19/11):** (b). Las dos señales coinciden con base 6, y con (a) no se podría decir ni "seis". La base (6), el separador (`-`) y las cifras (`vo`…`pai`) están en `datos/kethari/`; el algoritmo (`numeros.dart`) es el mismo que usará Ozh con base 10. El sustantivo lleva `-esh` también con número (manual 3.3). 9.999 = `ti-ti-mok-ti-mok-sel`.
- **Prueba:** grupo "cantidades (base 6, bitácora K-05)" y `numeros_test.dart` → "señales del registro".

### K-06 · 17/11/2026 · Palabra sin traducción
- **Problema:** el árbol puede traer un concepto sin palabra Kethari conocida.
- **Decisión:** no se genera nada y el error dice qué concepto falta ("No se inventan palabras"). Se listan todos los que falten, no solo el primero.
- **Prueba:** "verbo sin palabra Kethari: no traduce y lo explica".

### K-08 · 19/11/2026 · Poseedor y número en el mismo sustantivo
- **Problema:** "nuestras dos naves": el manual dice que el poseedor va delante de lo poseído y que el número va delante del sustantivo, pero no dice cuál va primero.
- **Opciones:** (a) `anir ra kumesh` (poseedor, número, sustantivo); (b) `ra anir kumesh`.
- **Decisión:** (a). El poseedor va delante de todo lo poseído ("dos naves"), y el número queda pegado al sustantivo, como en las señales de los días 3 y 7. Ninguna señal tiene los dos juntos; se revisa si llega una.
- **Prueba:** "poseedor antes del número: anir ra kumesh (bitácora K-08)".

### K-09 · 25/11/2026 · Corrección del manual v0.8: `teka`
- **Problema:** el archivo de la semana 2 corrige `teka`: ya no significa "tierra" sino "territorio reclamado". El léxico del generador seguía con `TIERRA = teka`, así que "¿Quieren nuestra tierra?" se habría transmitido como "¿quieren nuestro territorio reclamado?", la clase de palabra equivocada que puede sonar a amenaza.
- **Opciones:** (a) dejar `TIERRA = teka`; (b) pasar `teka` a `TERRITORIO_RECLAMADO` (concepto que agregó el parser) y dejar `TIERRA` sin palabra Kethari.
- **Decisión:** (b). Con (a) el sistema transmitiría un significado que Axios ya corrigió. Sin palabra para "tierra", el generador no traduce y explica que falta (K-06). En Ozh `mak` sigue siendo tierra: la corrección solo toca Kethari. El cambio está en `datos/kethari/lexico.json`, sin recompilar.
- **Prueba:** "día 8: iresh tekaesh nuthal" y "tierra ya no se traduce como teka: lo explica".

### K-10 · 25/11/2026 · Dos verbos seguidos ("¿Quieren visitar la tierra?")
- **Problema:** el manual no dice cómo se combinan dos verbos en Kethari ni en Ozh, ninguna señal lo muestra y el árbol tiene un solo verbo (pregunta de S-11).
- **Opciones:** (a) inventar una forma (`dun thal`, verbo + verbo); (b) traducir solo un verbo; (c) no traducir y explicarlo.
- **Decisión:** (c). (a) no tiene respaldo en el manual ni en las señales ("No se inventa nada") y (b) cambia el sentido de la pregunta. El parser sigue rechazando la oración con su explicación (S-11), así que el árbol no cambia. Se revisa si llega una señal con dos verbos.
- **Prueba:** "dos verbos seguidos no llegan al generador (K-10)".

### Evidencia nueva para decisiones anteriores (señales de la semana 2)
- **K-05:** día 10 `mok-ra sorinesh` = veintiséis estrellas (4·6 + 2 = 26). Tercera señal que confirma la base 6.
- **K-01:** día 10 `anir … korok` ("nosotros vimos") vuelve a usar `anir`.
- **Prueba:** "día 10: anir mok-ra sorinesh korok" y "día 9: ir yorr mi ka".

### K-11 · 25/11/2026 · Los generadores leen el léxico de la base de datos
- **Problema:** `cargar` guardaba señales y correcciones en la BD, pero los generadores leían los JSON de `datos/`. Una corrección cargada aparecía en `palabra` y no en `traducir` (criterio 17: incorporar cambios sin recompilar). Además la BD guarda el léxico por palabra española ("llegar", "tú") y el árbol entrega conceptos (`VENIR`) y rasgos (`2s`).
- **Opciones:** (a) seguir editando los JSON a mano; (b) pedir a la BD una columna `concepto`; (c) usar el vocabulario del parser como puente concepto → palabras españolas y buscarlas en la BD tal como está.
- **Decisión:** (c). No cambia las tablas ni el parser, y el parser ya sabe que `VENIR` es "venir" y "llegar". `LexicoAlienigenaBd` consulta la BD en cada búsqueda con la versión vigente en una fecha, así que lo cargado se usa en la traducción siguiente y se puede preguntar "qué se habría transmitido" en una fecha pasada. `FuenteKethariBd` y `FuenteOzhBd` implementan las mismas interfaces que las de JSON: los generadores no cambian. Las reglas (afijos, partículas, base) siguen en `gramatica.json`, porque la BD no tiene tablas para ellas; son datos, no código.
- **Detalles:**
  - Comparación sin tildes ("tú" en la BD = "tu" del parser), igual que el normalizador.
  - Si dos sinónimos dan palabras distintas (por ejemplo, una corrección cambia "llegar" y no "venir"), no se elige al azar: no se traduce y se explica.
  - `anul|anir` en una celda: se usa la que diga `gramatica.json` → `alternativas` (K-01). Una celda con varias palabras que no esté ahí no se traduce.
- **Prueba:** `fuente_bd_test.dart` → "después de cargar la semana 2, tierra ya no tiene palabra", "en una fecha anterior a la corrección se usa lo que se creía", "un archivo nuevo cambia la traducción sin recompilar".

### K-07 · 25/11/2026 · Preguntas que se leen igual
- **Problema (lo señaló Jacobo):** "¿A quién escuchan ustedes?" y "¿Quién los escucha a ustedes?" tienen árboles distintos (quién es objeto o sujeto), pero salen iguales: Kethari `sem ulesh rhu ka`, Ozh `ʔanem … shavi wis`. Las dos lenguas ponen la palabra interrogativa en un extremo y no marcan quién hace la acción.
- **Opciones:** (a) dejar la palabra interrogativa en su hueco cuando es objeto (`ulesh sem rhu ka`), contra el manual; (b) no traducir cuando hay ambigüedad; (c) traducir según el manual y avisar.
- **Decisión:** (c). (a) contradice el manual ("la palabra interrogativa va al principio" / "al final") y la señal Ozh del día 9 la pone al final siendo objeto; (b) bloquearía preguntas básicas como "¿Qué quieren ustedes?". Los resultados de los dos generadores traen el aviso en `advertencias` y en la traza.
- **Prueba:** `generador_ozh_test.dart` → "quién como objeto o como sujeto: avisa".

## Generador de Ozh

El primer generador de Ozh entró con el PR del CLI (#20). Se revisó contra el manual y las señales y se reescribió con las decisiones siguientes. Pruebas en `cli/test/generadores/generador_ozh_test.dart`.

### O-01 · 25/11/2026 · Qué partícula va después del verbo
- **Problema:** Ozh exige `zi` (lo vimos), `mar` (nos lo dijeron) o `tho` (lo deducimos) después del verbo, y el manual no dice cuál usar; la nota 3.5 dice que en las preguntas "no parece referirse a quien pregunta". El árbol no dice cómo sabe algo quien habla.
- **Evidencia (10 señales Ozh):**

| Día | Tiempo | Sujeto | Partícula |
|---|---|---|---|
| 1 | pasado | 1p | zi |
| 4 | pasado (decodificado) | 1p | zi |
| 8 | pasado | 3p | zi |
| 2 | presente | 3p | tho |
| 3 | futuro | nave (3ª) | tho |
| 10 | presente | 3p | tho |
| 5 | presente, pregunta | 2p | mar |
| 6 | presente | 2p | mar |
| 7 | presente | 1s | mar |
| 9 | presente, pregunta | 2p | **tho** |

- **Opciones:** (a) una sola partícula siempre; (b) la regla del primer generador (2ª o 1ª singular → `mar`, 1ª plural en pasado → `zi`, resto → `tho`), que falla en los días 8 y 9; (c) tres reglas en orden: pasado → `zi`; tercera persona → `tho`; lo demás → `mar`.
- **Decisión:** (c). Reproduce 9 de 10 señales y tiene sentido con lo que significan: lo pasado se cuenta como visto, lo que hacen otros se deduce, y lo que hacemos o hacen ustedes se sabe porque se dijo. La única excepción es el día 9; ningún dato del árbol lo distingue del día 5 (las dos son preguntas a "ustedes" en presente). Las reglas están en `datos/ozh/gramatica.json` → `particulas.reglas`, no en el código: si llega otra señal, se cambia el dato.
- **Prueba:** grupo "señales Ozh del registro (bitácora O-01)".

### O-02 · 25/11/2026 · Orden del tiempo y la negación
- **Problema:** el primer generador ponía `ne ʔoka verbo`.
- **Decisión:** `ʔoka`/`venu` van "al principio de la oración" y `ne` "delante del verbo" (manual 3.4), así que el orden es `ʔoka ne verbo`.
- **Prueba:** "tiempo antes de la negación: ʔoka ne ... (O-02)".

### O-03 · 25/11/2026 · Palabra interrogativa que ocupa el sujeto u objeto
- **Problema:** como en Kethari (K-02), "quién" o "qué" ocupan un hueco y además van al final.
- **Decisión:** van solo al final, sin repetirse, como en la señal del día 9 (`ʔanem tho shavi wis`, el objeto "quién" al final). Con "¿Quién envió el mensaje?" el sujeto queda representado por `wis` al final: `ʔoka ʔadra zi vesh wis`.
- **Prueba:** "quién como sujeto: va al final y no se repite (O-03)".

### O-04 · 25/11/2026 · No omitir en silencio
- **Problema:** el primer generador quitaba la cantidad o el poseedor si no los podía escribir y traducía igual: transmitía algo distinto de lo preguntado.
- **Decisión:** igual que en Kethari (K-06): si falta cualquier palabra, no se traduce y se explica qué falta. Además se quitaron las palabras escritas en el código como valores de respaldo (`'ʔoka'`, `'ne'`, `'mar'`…): si falta un dato en `gramatica.json`, el programa lo dice al arrancar (criterio 15).
- **Prueba:** grupo "no inventa ni omite (O-04)".

### O-05 · 25/11/2026 · Señal del día 4 sin `ʔoka`
- **Problema:** el decodificador traduce `ne ʔim zi ʔenka gor` como "No vimos ninguna nave" (pasado), pero la señal no trae `ʔoka`.
- **Opciones:** (a) quitar `ʔoka` del pasado; (b) seguir el manual y poner `ʔoka`.
- **Decisión:** (b). El manual dice que el pasado lleva `ʔoka`, y las señales de los días 1 y 8 lo traen. Lo más probable es que el día 4 sea presente ("no vemos") y el decodificador lo haya pasado al pasado. Fuera del marcador, la traducción coincide (orden, partícula y palabras).
- **Prueba:** "día 4: con pasado sale ʔoka; la señal no lo trae (O-05)".
