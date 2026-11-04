# Autoevaluación del EP3 frente a la rúbrica v3 (32 criterios)

Revisión del 4/11/2026 de la entrega del examen parcial 3 (viernes 6/11/2026): tesis v6
(`01_tesis`), manuscrito enviado v1 (`02_articulo`), resumen independiente, bitácora de envío,
localizadores y evidencias económicas, frente a `ep3_rubrica_v3_s_13.pdf`. Cada condición
completa vale 0,5; la nota es N = 3·P4/10 + 8·P5/20 + 3·P6/8 + 2·P7/6 + 4·PA/20.

Leyenda: **C**, cumple con evidencia localizable; **C\***, cumple con los cambios de esta revisión
(tesis v7 con control de cambios y este repositorio); **R**, en riesgo: el evaluador podría no
darla por cumplida; **F**, falta y solo el autor puede completarla. «Sin observaciones» indica
que esta revisión no encontró un incumplimiento, no que el evaluador vaya a coincidir.

## 1. Lo que se completó en esta revisión

| Condición | Qué faltaba en la tesis v6 | Qué se hizo | Localizador |
|---|---|---|---|
| 15(b) | 5.6.2 declaraba pendiente el caso real; E2E-01 usa datos ficticios | Caso real CR-01: la salida del manifiesto 001-029483 (03/10/2026, Soritor–Tarapoto, V001, C041, 15 pasajeros) recorrida en el prototipo sobre una base vacía, con 15 capturas, el registro del servidor (UTC) y la bitácora (hora de Lima) del mismo caso; PASA | Tesis v7: 5.6.2, Tabla 87 (fila CR-01) y **Anexo K** (Tablas K1 a K3, Figuras K1 a K15); repositorio: [`docs/evidencias/caso_real_001-029483/`](../evidencias/caso_real_001-029483/), [`herramientas/caso_real.sh`](../../herramientas/caso_real.sh), [`cliente/integration_test/caso_real/`](../../cliente/integration_test/caso_real/) |
| 15(d) | Las pruebas del prototipo solo usaban datos sintéticos y ficticios | CR-01 usa datos de la empresa con permiso (Figura B3); la Tabla K1 separa los datos del manifiesto, los supuestos declarados y los seudónimos | Tesis v7: 5.6.11, Tabla 95 (fila nueva), Tabla K1 |
| 15(a) | P-03b, P-04b, P-10b y P-13b fallidos; P-17 y P-18b no ejecutados; E2E-01 sin salida | Los cuatro casos se aprueban desde la versión 1.1.0 (`servidor/test/aceptacion/cola_pares_test.dart`); P-17: media 0.351 s, máximo 0.449 s, cobertura del núcleo Dart 97.9 %; P-18b: restauración en 17.3 s y 25.3 s; E2E-01: artefacto `evidencia-e2e` de la CI. Se conserva el resultado fallido observado en b54c86b | Tesis v7: Tabla 87, nota y párrafo siguiente; [`docs/evidencias/p17/`](../evidencias/p17/), [`docs/evidencias/p18b/`](../evidencias/p18b/) |
| 13(a), 13(c), 13(d) | Tablas 82 y 83 y fichas de CUS con los estados del commit b54c86b | Estados de la versión 1.2.0: los 19 RF implementados; columna del caso demostrado con CR-01 (13 RF); Tabla 83 con el estado de cada diferencia; restricción «Datos» actualizada | Tesis v7: 5.4, Tablas 82 y 83; fichas de CU-02, CU-03, CU-06, CU-07, CU-08, CU-09 y CU-12 |
| 12(d) | 5.3.4 decía «14 tablas» (nombraba 13) y presentaba cola, pares y snapshot como no instalados | 17 tablas y una vista de `basedatos/esquema.sql` | Tesis v7: 5.3.4; Tabla 86 |
| 14(b) | 5.5.2 pedía transcribir las versiones del prototipo | Versiones exactas: Dart 3.13.5, Flutter 3.47.6, MySQL 8.4.11, nginx 1.28.0, shelf 1.4.2, mysql_client_plus 0.1.3, provider 6.1.5+1, entre otras, con el archivo que las fija | Tesis v7: 5.5.2 y Tabla 84 |
| 01(a) | 4.1 remitía al RUC de la sección 1.1.1 sin escribirlo | Se escribe el RUC N.º 20531405481 | Tesis v7: 4.1, primer párrafo |
| Coherencia | Varias secciones repetían el estado de b54c86b | Tabla de RNF de 5.2.2 (RNF-02, RNF-05, RNF-07), 5.2.4, 5.6.9, Tabla 86 (5.5.5), Tabla 97 (5.7), 5.8, 8.3 (viabilidad operativa), Anexo H y las menciones a la «consolidación pendiente» (3.2, 3.4, 5.5.1, 5.6.10 y Anexo E) | Tesis v7 (cambios controlados) |
| Repositorio | `decisiones_y_desviaciones.md` §8 describía la reimplementación retirada | Fila actualizada: `core/` y `poc_cap3/` originales, 14 huellas verificadas | [`docs/decisiones_y_desviaciones.md`](../decisiones_y_desviaciones.md) §8 |

## 2. Autoevaluación por criterio

| Criterio | (a) | (b) | (c) | (d) | Observación |
|---|:-:|:-:|:-:|:-:|---|
| 01 · 4.1 | C\* | C | C | C | 01(a): RUC agregado en 4.1 |
| 02 · 4.2 | C | C | C | C | Sin observaciones |
| 03 · 4.3 | C | C | C | C | Sin observaciones |
| 04 · 4.4 | C | C | C | C | La traza de la corrida se regenera idéntica con `pruebas/corrida/` (verificado el 4/11/2026) |
| 05 · 4.5 | C | C | C | C | Sin observaciones |
| 06 · 5.1 | C | C | C | C | Sin observaciones |
| 07 · 5.1 | C | C | C | C | Sin observaciones |
| 08 · 5.2 | C | C | C | C | La tabla de RNF se actualiza con P-17 y P-18b |
| 09 · 5.2 | C | C | C | C | Las fichas conservan sus flujos; cambia solo la fila «Estado en el prototipo» |
| 10 · 5.3 | C | C | C | C | Sin observaciones |
| 11 · 5.3 | C | C | C | C | 11(d): Tabla 86 actualizada (88, 66 y 17 pruebas; 17 tablas) |
| 12 · 5.3.4 | C | C | C | C\* | 12(d): el texto ya coincide con `esquema.sql` |
| 13 · 5.4 | C\* | C | C\* | C\* | Tablas 82 y 83 con estados verificables y el caso demostrado |
| 14 · 5.5 | C | C\* | C | C | 14(b): versiones exactas en la Tabla 84 |
| 15 · 5.6 | C\* | C\* | C | C\* | 15(c): 109 pruebas aprobadas y 300 de 300 corridas reproducidas el 4/11/2026 (`pruebas/nucleo/verificacion_2026-11-04/`) |
| 16 · 6.1 | C | **R** | C | C | 16(b): la Tabla J2 cita EV-02, EV-10, EV-19 y EV-20, que no están en `05_evidencias_economicas` (las páginas de DigitalOcean, Glassdoor, MEF y SUNAT no se pudieron descargar desde esta sesión) |
| 17 · 6.2 | C | C | C | **R** | 17(d): la renovación de hardware se sustenta en EV-20 (SUNAT), ausente |
| 18 · 6.3 | C | C | C | C | Sin observaciones |
| 19 · 6.4–6.5 | C | C | C | C | Sin observaciones |
| 20 · 7.1 | C | C | C | C | Sin observaciones |
| 21 · 7.2 | C | C | C | C | Sin observaciones |
| 22 · 7.3 | C | C | C | C | 22(a): el COK se sustenta con EV-13 a EV-16, EV-22 y EV-23 (presentes); EV-19 (MEF) es solo referencia |
| 23 · Título y resumen | C | C | C | C | Resumen independiente de 3 páginas |
| 24 · Introducción | C | C | C | C | Sin observaciones |
| 25 · Trabajos relacionados | C | C | C | C | Sin observaciones |
| 26 · Metodología | C | C | C | C | 26(d): Zenodo 10.5281/zenodo.23604918 y autorización de la empresa |
| 27 · Resultados | C | C | C | C | Sin observaciones |
| 28 · Discusión | C | **F** | C | C | 28(b): la Discusión del manuscrito enviado (23/10/2026) no cita ningún trabajo; el envío ya hecho no puede modificarse |
| 29 · Conclusiones | C | C | C | **R** | 29(d): la última oración dice qué se haría (reunir registros y comparar con el despacho manual), pero no con qué indicador ni con qué criterio se comprobaría el efecto |
| 30 · Referencias | C | C | C | C | Sin observaciones |
| 31 · Forma e integridad | C | C | C | C | 31(c): financiamiento, conflicto de intereses, datos, autorización y uso de IA declarados |
| 32 · Bitácora | C | **F** | **F** | C | 32(b): falta la captura de Scimago, WoS, SciELO o CORE (E-VER-03 o E-VER-04); las de Beall son del 3/11, posteriores al envío. 32(c): falta E-EST-01. 32(d): E-ENV-02 muestra el envío con copia oculta a bramirez@ucss.edu.pe; E-ENV-04 la refuerza |

Con estas marcas, si el evaluador acepta las condiciones **C** y **C\*** y rechaza las **R** y
**F**, quedan sin acreditar 16(b), 17(d), 28(b), 29(d), 32(b) y 32(c): P6 = 7, PA = 18 y
N = 3 + 8 + 3·7/8 + 2 + 4·18/20 = 19.2 → 19. Si el autor completa 32(b) y 32(c) y las cuatro
evidencias económicas, solo quedarían 28(b) y, según el criterio del evaluador, 29(d).
La estimación no sustituye la calificación: depende de que el evaluador acepte cada condición
marcada C.

## 3. Acciones que solo puede hacer el autor (antes del 6/11/2026)

1. **Tesis v7.** Abrir `RIOS_SEPULVEDA_LUIS_tesis_v7_cambios.docx`, revisar cada cambio
   controlado (autor «Claude»), aceptarlos o modificarlos, actualizar el índice general (Word lo
   pide al abrir; en LibreOffice, Herramientas › Actualizar › Actualizar todo) para que incluya
   el Anexo K y el nuevo título del Anexo H, y exportar el PDF. El Anexo K y la fila CR-01 son
   nuevos; los números de las demás tablas y figuras no cambian, y las tablas y figuras del
   Anexo K, como las de los demás anexos, no entran en los índices de tablas y de figuras.
2. **Criterio 32** (bitácora, marcas «[completar]»): capturas fechadas de Scimago (E-VER-03), de
   CORE o SciELO (E-VER-04) y del portal ISSN (E-VER-05); correo de seguimiento a la revista en
   el mismo hilo (E-ENV-03); captura fechada de la bandeja que acredite el estado (E-EST-01);
   correo al docente con esa captura (E-ENV-04); fechas al 6/11/2026. Si conserva capturas de
   la verificación anterior al 23/10/2026, agregarlas como E-VER-00. Desde esta sesión esos
   sitios no fueron accesibles.
3. **Evidencias económicas** (16(b) y 17(d)): guardar como PDF fechado EV-02 (DigitalOcean),
   EV-10 (Glassdoor), EV-19 (MEF, tasa social de descuento) y EV-20 (SUNAT, depreciación) en
   `05_evidencias_economicas` y añadirlas a `INDICE_EVIDENCIAS.txt`.
4. **Artículo** (28(b) y 29(d)): el manuscrito enviado no puede cambiarse. Si la revista pide
   correcciones, conviene contrastar en la Discusión los resultados con al menos dos trabajos ya
   citados y precisar en las Conclusiones el indicador y el criterio con que se comprobará la
   comparación con el despacho manual.
5. **Localizadores.** Usar `RIOS_SEPULVEDA_LUIS_localizadores_EP3_v2.docx` (cambios
   controlados). Sus páginas se calcularon sobre la tesis v7 con todos los cambios aceptados y
   exportada con LibreOffice 24.2, el mismo programa del PDF original (390 páginas; sin cambios
   hasta la p. 228, +1 desde la Tabla 83, +3 desde 5.6.2, +4 desde 5.6.3 y +5 desde la
   Tabla 96). Si se edita algo más antes de exportar, deben revisarse.
6. **Repositorio.** Fusionar el pull request 3 en `main` (o indicar la rama en el Anexo H, como
   ya hace la tesis v7) y publicar las etiquetas v1.0.0 a v1.2.0 desde una cuenta con permiso
   (desde esta sesión el envío de etiquetas devuelve HTTP 403).

## 4. Localizadores nuevos o modificados

| Condición | Localizador |
|---|---|
| 01a | Tesis, 4.1, primer párrafo (RUC N.º 20531405481) |
| 12d | Tesis, 5.3.4 (17 tablas y una vista); Tabla 86; `basedatos/esquema.sql` |
| 13a | Tesis, Tabla 82 (estado en la versión 1.2.0); fichas de CUS, fila «Estado en el prototipo» |
| 13c | Tesis, 5.4, párrafo de restricciones («Datos») |
| 13d | Tesis, Tablas 82 (columna «En el caso demostrado»: E2E-01 y CR-01) y 83 (tercera columna) |
| 14b | Tesis, 5.5.2 y Tabla 84; `servidor/pubspec.lock`, `cliente/pubspec.lock`, `paquetes/dominio/pubspec.lock`, Dockerfile y `docker-compose.yml`; `docs/MANUAL_COMPILACION.md` |
| 15a | Tesis, Tabla 87 (25 casos, CR-01 incluido) y párrafo siguiente; `servidor/test/aceptacion/cola_pares_test.dart`; `docs/evidencias/p17/`, `docs/evidencias/p18b/`; artefacto `evidencia-e2e` de GitHub Actions |
| 15b | Tesis, 5.6.2 (caso real CR-01) y Anexo K (Tablas K1 a K3, Figuras K1 a K15); `docs/evidencias/caso_real_001-029483/` (capturas, `servidor.log`, `registro_bd.txt`, `ejecucion.txt`) |
| 15c | Tesis, 5.6.3 a 5.6.7, Tablas 88 a 91 y Anexo I; `pruebas/nucleo/verificacion_2026-11-04/` |
| 15d | Tesis, 5.6.11 y Tabla 95 (fila del manifiesto 001-029483); Tabla K1; Figura B3 |

Enlace del repositorio: https://github.com/Madafaka17/sistema-asignacion-san-felipe (rama
`claude/lucid-feynman-ybqrwy`; pull request 3 hacia `main`).
