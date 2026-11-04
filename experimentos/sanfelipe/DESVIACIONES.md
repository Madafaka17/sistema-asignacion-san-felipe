# Desviaciones y análisis posteriores al registro del protocolo

El protocolo (`PROTOCOLO.md`) se registró el 2026-10-06 a las 05:14:13 UTC
(`registro_protocolo.txt`). Este archivo registra todo lo hecho después.

## Ejecución oficial

- v1 y v2 se ejecutaron una sola vez cada una, completas (330 ejecuciones por
  variante), sin fallos del ejecutor y sin cambios de código, parámetros, semillas,
  anclajes ni pesos. El validador independiente coincidió con Φ en las 660
  ejecuciones.

## Decisiones tomadas después de conocer los resultados

1. **Instancia de la figura de un turno.** La figura `figura_turno.png` usa la
   instancia 101 de n = 14, elegida después de conocer los resultados porque n = 14
   es el tamaño en que la brecha de la programación lineal entera fue mayor. La
   semilla del algoritmo genético (1) se fijó por regla (la primera), no por su
   resultado. La figura es ilustrativa y no interviene en la matriz de decisión.

2. **Análisis exploratorio de la definición de D (v1D y v2D).** La figura mostró que la
   ventaja del algoritmo genético en esa instancia proviene de dejar sin servicios
   a un conductor disponible: como D(X) solo considera a los conductores con al
   menos un servicio, esa programación reduce D aunque concentre la carga. Para
   medir cuánto depende el resultado de esa definición se repitieron las
   configuraciones v1 y v2 con D calculada sobre todos los conductores que figuran
   en alguna alternativa admisible (`sensibilidad_D.py`; variantes v1D y v2D, 330
   ejecuciones cada una). Este análisis se definió después de conocer v1 y v2, se
   informa junto a ellas y no las reemplaza; la ejecución oficial sigue siendo v1
   (y v2 como sensibilidad del presupuesto, prevista en el protocolo).

## Incidencias del entorno

- En v1, la primera ejecución de la programación lineal entera (n = 7, instancia
  101) tardó 0.538 s por el arranque inicial del solucionador; la misma instancia
  tardó entre 0.012 s y 0.013 s en las demás variantes. Afecta solo al tiempo medio
  en n = 7 (C2), que queda muy por debajo del corte de 3 s.
- En v2D, una ejecución de la programación lineal entera (n = 14, instancia 103)
  tardó 10.02 s por una demora del entorno; la misma instancia se resolvió en
  0.02 s en las otras tres variantes, con la misma solución. No interviene en C2
  (n = 7) ni en C4 (n = 28, 56 y 112).
- Los tiempos de los candidatos de ejecución muy breve varían entre corridas sin
  ningún cambio de configuración (por ejemplo, la razón C4 del algoritmo voraz fue
  2.30 en v1 y 1.96 en v2); por eso el informe evalúa la robustez del orden frente
  a C2 y C4.

## Correcciones descriptivas (no cambian ningún parámetro)

- `PROTOCOLO.md` (sección 2) y un comentario de `generador_sanfelipe.py` dicen que
  los 16 asientos se leyeron «en 4 manifiestos». En el libro de captura, el valor
  16 figura en los 11 manifiestos transcritos, de los cuales 4 tienen la unidad
  identificada. Como la flota del generador es homogénea y la capacidad no
  restringe ninguna alternativa, la corrección no cambia las instancias. Los
  archivos registrados no se editaron para conservar sus huellas.

## Comprobación de reproducibilidad

- Se volvieron a ejecutar 12 corridas de v1 (los cuatro candidatos en las
  instancias 14-101, 28-103 y 56-102; semilla 3 para búsqueda tabú y algoritmo
  genético) y la aptitud coincidió exactamente con la registrada en las 12.

## Material agregado el 2026-10-17

Agregado once días después de la ejecución, con todos los resultados conocidos.
Ninguno de los archivos registrados de esta carpeta se modificó: sus huellas siguen
siendo las de `registro_protocolo.txt` (la integración continua las comprueba).

- **Reimplementación de `core/` y `experimentos/poc_cap3/` (retirada el 2026-11-04).**
  Mientras faltaban los archivos con los que se ejecutó el experimento, el repositorio
  publicó una versión escrita de nuevo a partir del capítulo III, con otras huellas.
  Se retiró al recuperarse los originales (sección siguiente).
- **`reevaluar_cromosomas.py`.** Reevalúa cada cromosoma de
  `soluciones_*.jsonl`. Las 1 320 soluciones (v1, v2, v1D y v2D) coinciden con
  `resultados_crudos_*.csv` en los 16 campos —F, J, Φ, validador, E, Ret, R, Tm, D
  y los siete indicadores operativos— y los 12 óptimos de n = 7 coinciden en F y en
  el número de hojas factibles. Esto acredita que las soluciones registradas son
  coherentes con sus resultados. (Se comprobó primero con la reimplementación y, el
  2026-11-04, con los archivos originales.)
- **`incertidumbre_bootstrap.py` e `incertidumbre_brecha.csv`.** Intervalos
  bootstrap (B = 10 000, remuestreo estratificado de instancias y semillas, con la
  referencia de la brecha fija) de la brecha media C1 y de la diferencia AG − PLE,
  calculados solo con los resultados registrados. En v1: AG 4.00 % (IC 95 %:
  0.95 a 7.79), PLE 9.22 % (2.06 a 19.56); diferencia AG − PLE −5.22 puntos
  (−15.40 a 3.16), con brecha del AG mayor en el 15 % de las réplicas; el puntaje C1
  observado se conserva en el 70 % de las réplicas en el AG (4) y en el 39 % en la
  PLE (3). La ventaja del AG en C1 proviene de n = 14 (una instancia con 89 % de
  brecha de la PLE) y de n = 28; en n = 56 y n = 112 la brecha de la PLE es menor
  (AG − PLE: +3.43 y +12.97 puntos). En v2, AG 0.40 % (0.15 a 0.69) y diferencia
  −9.00 puntos (−19.39 a −1.83). Con tres instancias por tamaño, los intervalos
  describen la variabilidad de este experimento, no la de la operación real.
- **`repetir_reimplementacion.py` y `reimplementacion/` (retirados el 2026-11-04).**
  Repetición completa de v1, v2, v1D y v2D con la reimplementación; con ella, la
  búsqueda tabú y el AG no repetían las ejecuciones registradas. Al recuperarse los
  originales dejó de tener objeto; queda en el historial de git (commit 98f19b9).

## Recuperación del código original (2026-11-04)

El autor entregó el paquete del repositorio del núcleo de la sesión 8
(`paquete_repositorio.zip`, 7/10/2026, con su `SHA256SUMS` íntegro). Sus 14 archivos
registrados —los cinco de esta carpeta, `metodos.py`, `exhaustivo.py` y
`validador.py` de `experimentos/poc_cap3/` y los seis de `core/`— tienen las huellas
de `registro_protocolo.txt`. Se incorporaron sin cambios y sustituyeron a la
reimplementación; también se incorporaron los registros de la prueba técnica inicial
de `experimentos/poc_cap3/` (`PROTOCOLO.md`, `resumen.json`, resultados y figura).

Con ellos, en el contenedor de verificación (Python 3.11.18, dependencias de
`requirements.lock`): `pruebas/nucleo` aprobó 109 pruebas (100 casos del Anexo I y 9
de `tests/test_core.py`), entre ellas M12-02, que repite las 12 corridas de la
sección anterior, y M12-03 y M11-04, que repiten la PLE y el voraz en las 15
instancias; `reevaluar_cromosomas.py` volvió a coincidir en las 1 320 soluciones.
Las 300 ejecuciones estocásticas v1 se informan en `pruebas/nucleo/README.md`.

