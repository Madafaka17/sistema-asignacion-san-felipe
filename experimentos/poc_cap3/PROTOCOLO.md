# Protocolo de las pruebas de concepto (capítulo 3, sección 3.2)

Este protocolo se fijó **antes** de ejecutar las pruebas. Ningún umbral, peso,
tamaño de instancia ni configuración se ajustó después de observar resultados.

## 1. Propósito

Obtener puntajes empíricos para la matriz de decisión de la sección 3.2.3,
sometiendo a los cuatro candidatos (programación lineal entera, algoritmo voraz,
búsqueda tabú y algoritmo genético) a las mismas instancias, el mismo hardware,
la misma función de evaluación y el mismo límite de tiempo.

## 2. Instancias de prueba

Instancias sintéticas generadas con semilla fija (`generador.py`). No son datos
de la Empresa de Transportes San Felipe; reproducen su estructura (servicios,
vehículos, conductores, alternativas de salida, límites de conducción).

| Parámetro | Valor |
|---|---|
| Servicios por turno, n | 7, 14, 28, 56, 112 |
| Escala de referencia | n = 7 (2 310 servicios en 2025 / 365 días ≈ 6,3; Tabla 3 del capítulo I) |
| Instancias por tamaño | 3 (semillas 101, 102, 103) |
| Vehículos y conductores | V = C = max(2, round(n/3)) |
| Duración del turno | 600 min |
| Duración de cada servicio | entera uniforme en [40, 120] min |
| Holgura mínima entre servicios, t_mín | 10 min |
| Alternativas admisibles por servicio | entera uniforme en {2, 3, 4, 5} |
| Factibilidad | garantizada: existe una programación oculta sin conflictos ni exceso de horas |
| Límite de conducción por conductor | carga en la programación oculta + holgura uniforme en [20, 120] min |
| Programación comprometida (línea base) | 40 % de los servicios, alternativa elegida al azar |
| Pesos de J (prueba de concepto) | retraso 0,25; reprogramación 0,25; tiempo muerto 0,25; desequilibrio 0,25 |
| Referencias de normalización | retraso 60 min; reprogramación = n.º de servicios con línea base; tiempo muerto 60·V min; desequilibrio 60 min |

## 3. Candidatos y configuración (inicial, sin calibrar)

| Candidato | Implementación | Configuración |
|---|---|---|
| PLE | PuLP 2.9.0 + CBC | límite 300 s, 1 hilo; tiempo muerto linealizado; desequilibrio aproximado por la carga máxima |
| Voraz | primer ajuste por hora de inicio | determinista |
| Búsqueda tabú | solución inicial voraz; vecindario = cambiar la alternativa de un servicio | 30 movimientos candidatos por iteración, permanencia tabú 7, aspiración por mejor global, 5 050 evaluaciones |
| AG | núcleo del prototipo (`core.scheduler.run`) | población 50, 100 generaciones, p_c 0,80, p_m 0,10, torneo k = 3, elitismo 10 % (Tabla de parámetros) |

Repeticiones: AG y búsqueda tabú, 10 semillas (1 a 10) por instancia; PLE y voraz,
1 ejecución (deterministas). Presupuesto equivalente de evaluaciones entre AG y
búsqueda tabú (≈ 5 050).

## 4. Evaluación común

Todas las soluciones se evalúan con la misma función del prototipo
(`core.fitness.evaluate`): F = −(M·Φ + E + J). Un validador independiente
(`validador.py`) recalcula, a partir de los intervalos crudos, los conflictos y
los conductores con exceso de horas, y debe coincidir con Φ.

Si un método no entrega solución dentro del límite de tiempo, se registra una
brecha de 100 % y n restricciones duras incumplidas.

## 5. Métricas (definición operacional)

| Criterio | Qué mide | Cómo se mide | Unidad | Condiciones |
|---|---|---|---|---|
| C1 | Calidad | brecha (F_mejor − F)/abs(F_mejor) × 100, acotada a 100 %, promediada en todas las ejecuciones; F_mejor = óptimo certificado por enumeración exhaustiva en n = 7 y mejor solución conocida en n ≥ 14 | % | 15 instancias |
| C2 | Tiempo | tiempo de reloj desde la recepción de la instancia hasta la entrega de la programación, promedio | s | escala de referencia n = 7 |
| C3 | Restricciones duras | número medio de restricciones duras incumplidas por solución (validador independiente) | conteo | todas las ejecuciones |
| C4 | Escalabilidad | media geométrica de t(56)/t(28) y t(112)/t(56) | razón | tiempos medios por tamaño |
| C5 | Capacidad multiobjetivo | número de los seis términos de F(X) (Sc, Cv, Cc, R, Tm, D) evaluados de forma exacta por el mecanismo de búsqueda, sin linealizaciones ni aproximaciones | conteo (0–6) | inspección de la implementación |

## 6. Anclajes de la escala de 1 a 5

| Puntaje | C1 brecha | C2 tiempo | C3 incumplimientos | C4 razón | C5 términos |
|---|---|---|---|---|---|
| 5 | ≤ 1 % | ≤ 3 s | 0 | ≤ 2,2 | 6 |
| 4 | ≤ 5 % | ≤ 30 s | ≤ 0,1 | ≤ 3,0 | 5 |
| 3 | ≤ 10 % | ≤ 150 s | ≤ 0,5 | ≤ 4,5 | 4 |
| 2 | ≤ 20 % | ≤ 300 s | ≤ 1 | ≤ 8,5 | 3 |
| 1 | > 20 % | > 300 s | > 1 | > 8,5 o límite de tiempo alcanzado | ≤ 2 |

Justificación de los cortes: C2 toma como referencia el límite de 300 s del RNF-02
(3 s = 1 %, 30 s = 10 %, 150 s = 50 %); C4 usa las razones teóricas al duplicar n
de un crecimiento lineal (2), cuadrático (4) y cúbico (8).

## 7. Ponderación, total y desempate

Pesos de la Tabla de criterios: C1 30 %, C2 20 %, C3 25 %, C4 15 %, C5 10 %.
Total = Σ peso × puntaje. Empate: gana la menor brecha C1 medida; si persiste,
el menor C3 medido.

## 8. Correcciones de fidelidad al diseño tras la prueba piloto (antes de la ejecución oficial)

Una prueba piloto (instancia 101 de cada tamaño, semillas 1 y 2) mostró que el
núcleo del prototipo no implementaba tres elementos del diseño del algoritmo
genético especificado en el capítulo 3 (pseudocódigo y mecanismo de reparación),
redactados antes de estas pruebas:

1. La probabilidad de mutación se aplicaba por gen; el pseudocódigo la aplica por
   cromosoma descendiente ("SI número_aleatorio() < probabilidad_mutación ENTONCES
   Mutar(hijo)"). Se añadió `mutation_scope="chromosome"`.
2. La reparación remuestreaba al azar los genes en conflicto; el diseño conserva
   el servicio de mayor prioridad y reasigna el otro a la primera alternativa
   disponible que no genere un nuevo incumplimiento. Se añadió `repair_mode="targeted"`.
3. La población inicial no se reparaba; el pseudocódigo la repara antes de la
   primera generación. Se añadió `repair_initial=True`.

Por coherencia, la búsqueda tabú parte de una solución inicial factible en lo
posible (voraz seguido de la misma reparación dirigida), como indica su
descripción en el capítulo 3. La probabilidad de cruce p_c = 0,80 no se aplicaba
en el núcleo; se corrigió de modo que la configuración por defecto (p_c = 1,0)
reproduce exactamente la ejecución ilustrativa publicada en el artículo.

No se modificaron los tamaños, las semillas, los presupuestos, los pesos, los
anclajes ni las métricas de las secciones 2 a 7. La prueba piloto ya mostraba que
la programación lineal entera alcanzaba el óptimo en todas las instancias
probadas; este protocolo se ejecuta igualmente sin cambios adicionales.

## 9. Análisis de sensibilidad v2 (definido después de conocer los resultados de v1)

La ejecución oficial (v1) dio el mayor total a la programación lineal entera. Al
revisar el diseño se identificó una asimetría de presupuesto: la PLE disponía de
hasta 300 s y se detenía al certificar el óptimo, mientras que el AG y la búsqueda
tabú se detenían en un número fijo y bajo de evaluaciones (≈ 5 050; 0,1 a 4 s),
sin el criterio de parada por convergencia que el propio diseño del AG especifica
(Tabla de parámetros: "generaciones sin mejora = 20").

La variante v2 se definió **después** de conocer v1 y se reporta junto a ella,
no en su reemplazo. Cambios, y solo estos:

| Candidato | v1 | v2 |
|---|---|---|
| AG | población 50, 100 generaciones | población 100, máx. 200 generaciones, parada tras 20 generaciones sin mejora, límite 300 s (valores máximos de la Tabla de parámetros) |
| Búsqueda tabú | 5 050 evaluaciones | máx. 20 000 evaluaciones, parada tras 2 000 evaluaciones sin mejorar la mejor solución, límite 300 s |
| PLE y voraz | sin cambios | sin cambios |

Instancias, semillas, métricas, anclajes, pesos y desempate: idénticos a v1.
