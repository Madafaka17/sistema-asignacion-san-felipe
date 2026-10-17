# Protocolo del experimento comparativo con datos sintéticos del caso San Felipe

Este protocolo se fijó **antes** de ejecutar cualquier comparación entre los
candidatos. Su huella SHA-256, la del generador y la del ejecutor quedan en
`registro_protocolo.txt`. Ningún parámetro, tamaño, semilla, peso, anclaje ni
configuración se ajusta después de observar resultados; cualquier desviación se
informa como tal.

## 1. Propósito y relación con la tesis

Comparar los cuatro candidatos del capítulo III —programación lineal entera
(PLE), algoritmo voraz, búsqueda tabú y algoritmo genético (AG)— con instancias
sintéticas que representan un turno de operación de la Empresa de Transportes y
Turismo San Felipe S.A.C. desde el terminal de Soritor: salidas hacia Moyobamba
y Tarapoto, unidades que salen según su turno en la cola, conductores habituales
y reemplazos autorizados.

El experimento **complementa** la sección 3.2.3 y **no modifica el capítulo
III**: usa el mismo modelo (ecuaciones 1 a 8), las mismas implementaciones de los
candidatos (`experimentos/poc_cap3/metodos.py`, importadas sin copiarlas), las
mismas configuraciones (Tabla 18 y análisis v2 de la Tabla 20), los mismos
criterios, anclajes y pesos (Tablas 14 a 16) y las mismas ecuaciones 16 a 18.
Solo cambia el generador de instancias: en lugar de duraciones genéricas, las
instancias se construyen con la estructura declarada de la operación de la
empresa.

Las instancias **no son datos de la empresa**. Son datos sintéticos, generados
con semilla fija, cuyos parámetros de referencia provienen de valores declarados
que todavía deben validarse.

## 2. Valores declarados que usa el generador (por validar)

Fuente: hoja «Presentacion» y hoja «Reglas» del libro de captura
`Datos_SanFelipe_Revision_y_Captura.xlsx` y archivos de texto entregados por el
tesista. No se usa ningún dato personal.

| Dato | Valor | Estado en la fuente | Uso en el generador |
|---|---|---|---|
| Rutas desde Soritor | Moyobamba y Tarapoto | Declarado | Dos rutas por servicio |
| Ida Soritor–Moyobamba | 30 min | Referencia declarada (R01) | Duración del viaje redondo |
| Ida Soritor–Tarapoto | 150 min | Referencia declarada (R02) | Duración del viaje redondo |
| Unidades que salen por día | 37 | Declarado; no equivale a 37 salidas | Razón conductores / unidades activas |
| Conductores en lista | 44 | Lista histórica; vigencia por confirmar | Razón conductores / unidades activas = 44/37 |
| Flota | 56 unidades | Por validar | Solo referencia de escala (no entra en el generador) |
| Asientos por unidad | 16 | Leído en 4 manifiestos | Flota homogénea: la capacidad no restringe |
| Orden de salida | Cola por orden de llegada, por destino | Declarado | Unidad que corresponde y siguiente unidad en cola |
| Conductores | Habituales y reemplazos | Declarado | Pares fijos y reemplazos autorizados |

## 3. Supuestos del generador (no provienen de la empresa)

| Supuesto | Valor |
|---|---|
| Servicio | Viaje redondo desde Soritor: la unidad y el conductor quedan ocupados durante la ida, la estancia en destino y el retorno |
| Duración | d = 2 × ida + estancia en destino; estancia entera uniforme en [20, 40] min (Moyobamba: 80 a 100 min; Tarapoto: 320 a 340 min) |
| Destino de cada servicio | Tarapoto con probabilidad 0.5 (no hay dato de la proporción); si el viaje no cabe en el turno, se prueba el otro destino |
| Programación oculta | Cada unidad activa inicia en un minuto entero uniforme en [0, 60] del turno y encadena viajes separados por t_mín más una espera en cola entera uniforme en [0, 30] min, mientras el viaje termine dentro del turno; se generan unidades hasta reunir n servicios (la última cadena se recorta) |
| Unidades activas | Las que resultan de la programación oculta (V); solo ellas forman la cola del día |
| Conductores | C = máx(V, redondeo(V × 44/37)) |
| Conductor fijo | Cada unidad activa tiene conductor fijo con probabilidad 0.7; los viajes de las demás se asignan, en orden de salida, a un conductor sin unidad fija que esté libre (con t_mín) |
| Pares autorizados | Cada unidad: su conductor fijo (o los que la condujeron en la programación oculta) más 1 o 2 reemplazos autorizados elegidos al azar |
| Salidas autorizadas | Salida nominal (la que corresponde en la cola), +10 y +20 min; la unidad no adelanta su turno; la salida debe terminar dentro del turno |
| Siguiente unidad en cola | Una unidad activa distinta, elegida al azar entre las que están en el terminal (sin viaje en curso) a la hora nominal; si no hay ninguna, solo se ofrece la unidad que corresponde |
| Alternativas admisibles A_s | Producto {unidad que corresponde, siguiente en cola} × {conductores autorizados de cada unidad} × {salidas autorizadas}; A_s contiene la alternativa de la programación oculta más k − 1 alternativas distintas de ese producto, con k entero uniforme en [2, 5] |
| Prioridad | Entera uniforme en {1, 2, 3} |
| Hora de presentación | El turno inicia a las 06:00 solo para mostrar horas; no afecta ningún cálculo |

## 4. Condiciones que se conservan de la Tabla 17 del capítulo III

| Elemento | Condición |
|---|---|
| Tamaños | n = 7, 14, 28, 56 y 112 servicios por turno (n = 7: escala de la Tabla 3; con este generador, n = 112 equivale a un turno con unas 38 unidades activas y 45 conductores, del orden de las 37 unidades por día y los 44 conductores declarados) |
| Instancias | 3 por tamaño (semillas 101, 102 y 103): 15 instancias |
| Turno y holgura | 600 min; t_mín = 10 min |
| Alternativas por servicio | Entre 2 y 5 |
| Factibilidad | Garantizada por la programación oculta; límite de conducción de cada conductor = carga en la programación oculta + holgura entera uniforme en [20, 120] min; conducción previa H_c0 = 0 |
| Programación comprometida | 40 % de los servicios, con una alternativa elegida al azar (base de Ret y R) |
| Función de evaluación | F(X) de la ecuación (7) con w_j = 0.25, b_Ret = 60 min, b_R = número de servicios comprometidos, b_Tm = 60·|V| min y b_D = 60 min; validador independiente de Φ |
| Repeticiones | Búsqueda tabú y AG: 10 semillas (1 a 10) por instancia; PLE y voraz: una ejecución (deterministas); 330 ejecuciones por variante |
| Límite de tiempo | 300 s por ejecución; un hilo |
| Referencia de calidad | Óptimo certificado por enumeración exhaustiva en n = 7; mejor solución conocida (máxima F entre todas las ejecuciones) en n ≥ 14 |

## 5. Candidatos y configuraciones

| Candidato | v1 (Tabla 18) | v2 (análisis de sensibilidad de la Tabla 20) |
|---|---|---|
| PLE | PuLP 2.9.0 + CBC; ecuaciones (9) a (11); 300 s; 1 hilo | Igual |
| Voraz | Primer ajuste por hora de inicio; determinista | Igual |
| Búsqueda tabú | Inicio voraz + reparación dirigida; vecindario de un servicio; 30 vecinos; permanencia 7; aspiración; 5 050 evaluaciones | Hasta 20 000 evaluaciones; parada tras 2 000 sin mejora; 300 s |
| AG | Población 50; 100 generaciones; p_c 0.80; p_m 0.10 por descendiente; torneo 3; elitismo 10 %; reparación dirigida | Población 100; hasta 200 generaciones; parada tras 20 sin mejora; 300 s |

Ambas variantes quedan fijadas en este protocolo antes de ejecutar; ninguna es
posterior a los resultados de este experimento.

## 6. Criterios, anclajes, pesos y total

Idénticos a las Tablas 14, 15 y 16 y a las ecuaciones 16 a 18 del capítulo III:

| Criterio | Medida | 5 | 4 | 3 | 2 | 1 | Peso |
|---|---|---|---|---|---|---|---|
| C1 Calidad | Brecha media (ec. 16) | ≤ 1 % | ≤ 5 % | ≤ 10 % | ≤ 20 % | > 20 % | 30 % |
| C2 Tiempo | Tiempo medio en n = 7 | ≤ 3 s | ≤ 30 s | ≤ 150 s | ≤ 300 s | > 300 s | 20 % |
| C3 Restricciones duras | Incumplimientos medios por solución (validador) | 0 | ≤ 0.1 | ≤ 0.5 | ≤ 1 | > 1 | 25 % |
| C4 Escalabilidad | Razón de la ecuación 17 | ≤ 2.2 | ≤ 3.0 | ≤ 4.5 | ≤ 8.5 | > 8.5 o límite alcanzado | 15 % |
| C5 Multiobjetivo | Componentes de F(X) evaluados de forma exacta | 6 | 5 | 4 | 3 | ≤ 2 | 10 % |

C5 se mantiene como en el capítulo (PLE 4, voraz 3, búsqueda tabú 6, AG 6),
porque las implementaciones son las mismas. Total = Σ peso × puntaje. Empate:
menor brecha C1; si persiste, menor C3.

## 7. Indicadores operativos complementarios (no ponderados)

Se informan para relacionar los resultados con la operación de la empresa; no
entran en la matriz de decisión:

- Asignaciones válidas: porcentaje de servicios cuya asignación no participa en
  ningún cruce de unidad o conductor y cuyo conductor no excede su límite.
- Reemplazos: servicios de unidades con conductor fijo atendidos por otro
  conductor autorizado.
- Saltos de cola: servicios atendidos por la siguiente unidad en cola en lugar
  de la unidad que corresponde.
- Salidas demoradas: servicios que salen después de su salida nominal, y minutos
  de demora acumulados.
- Servicios reprogramados (R) y retraso acumulado (Ret) respecto de la
  programación comprometida.
- Tiempo de cálculo.

## 8. Reglas de ejecución

1. Antes de ejecutar se verifica solo el generador: que la programación oculta de
   cada instancia tenga cero incumplimientos según el validador independiente y
   que cada servicio tenga entre 2 y 5 alternativas. Esta verificación no ejecuta
   ningún candidato.
2. Se registran las huellas SHA-256 de este protocolo, del generador y del
   ejecutor en `registro_protocolo.txt`.
3. Se ejecuta v1 y luego v2 con `python3 experimento.py ejecutar v1|v2` y se
   analizan con `python3 experimento.py analizar v1|v2`.
4. Si el ejecutor falla por un error de programación, se corrige, se documenta en
   la sección 9 y se repite la ejecución completa de la variante afectada.
5. Los resultados se informan tal como salgan, cualquiera sea el candidato con
   mayor puntaje total.

## 9. Desviaciones

Las desviaciones se registran en `DESVIACIONES.md` y no en este archivo, para
que su huella SHA-256 no cambie después del registro.
