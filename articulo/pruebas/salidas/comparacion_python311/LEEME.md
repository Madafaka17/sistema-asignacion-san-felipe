# Comparación con Python 3.11 (anomalía B-07)

Reproducción de las mismas 684 corridas publicadas con Python 3.11.17 (entorno en `entorno.json`), el 24/10/2026,
antes de la ejecución registrada con Python 3.13.16. Resultado: 683 de 684 corridas iguales al registro publicado
con la tolerancia de la suite (10^-9 relativa); 87 valores de J difieren solo en el último bit; la corrida
Tabu_v1 de Łódź PHUOLA, instancia 102, semilla 4, siguió otra trayectoria (J = 1.7300 frente a 1.7498 publicado).
Con Python 3.13.16 las 684 corridas coinciden bit a bit (ver `../resumen_reproduccion.json`).

Causa: desde Python 3.12, `sum()` de números reales usa suma compensada; las sumas de la función objetivo cambian
en el último bit y, en una búsqueda tabú con empates casi exactos, eso basta para elegir otro movimiento.
