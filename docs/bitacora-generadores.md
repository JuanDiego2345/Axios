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
