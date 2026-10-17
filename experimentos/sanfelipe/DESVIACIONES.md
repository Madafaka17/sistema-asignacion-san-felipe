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
