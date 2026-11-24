# Informe de la prueba de humo del prototipo

**Sistema de asignación de recursos basado en algoritmo genético — Empresa de Transportes y Turismo San Felipe S.A.C.**
Seminario de Investigación 2 · Sesión 8 (Despliegue y pruebas preliminares) · Actividad 1

| Dato | Valor |
|---|---|
| Ejecución de referencia | `20261007T144734Z_945b`, 7 de octubre de 2026, 14:47:34 UTC |
| Resultado | **PASA**: 12 de 12 pasos |
| Duración | 2,317 s la prueba de humo; 58,1 s la construcción completa desde cero (aprovisionamiento, servidor efímero, pruebas unitarias y prueba de humo) |
| Entorno | Máquina virtual Linux efímera (Ubuntu 24.04.4 LTS, x86_64, 2 vCPU, 7,8 GiB de RAM), Python 3.11.15, MySQL 8.0.46 |
| Datos | **Sintéticos.** No son registros de la empresa ni contienen datos personales |
| Procedimiento | `bash scripts/construir_y_probar.sh` (detalle en `MANUAL_COMPILACION.md`) |

## 1. Objetivo

Confirmar que la arquitectura base del prototipo se construye, se inicializa y opera sin errores sobre un conjunto de datos mínimo y controlado, cargado en una base de datos de pruebas efímera, sin comprometer la integridad de la experimentación futura. La prueba no evalúa la calidad de la programación, la eficiencia algorítmica ni los casos borde: solo la integridad estructural del prototipo. Su resultado es binario: PASA o FALLA.

## 2. Resultados por paso

| Paso | Verificación | Resultado | Duración (s) | Evidencia registrada |
|---|---|---|---|---|
| P01 | Integridad del protocolo y del núcleo registrados | PASA | 0,012 | 14 huellas de `registro_protocolo.txt` coinciden; instantánea de 62 archivos de `core/` y `experimentos/` |
| P02 | Entorno, dependencias y carga de bibliotecas | PASA | 0,333 | Python 3.11.15 en `.venv`; 13 paquetes iguales a `requirements.lock`, sin sobrantes; NumPy 2.4.4, PyGAD 3.7.0, PyMySQL 1.2.3, cryptography 50.0.2 y PuLP 2.9.0 cargados; CBC 2.10.3 resolvió un PLE trivial (Optimal) |
| P03 | Configuración desacoplada | PASA | 0,000 | `.env` completo y en `.gitignore`; contraseña enmascarada en el registro |
| P04 | Puerto, credenciales y permisos | PASA | 0,084 | Puerto 33306 a la escucha; credenciales aceptadas; MySQL 8.0.46-0ubuntu0.24.04.4; permisos: `USAGE` global y `ALL PRIVILEGES` solo sobre `sf\_test\_%` |
| P05 | Base efímera y esquema | PASA | 0,171 | Base `sf_test_humo_20261007t144734z_945b`; 9 sentencias; 9 tablas |
| P06 | Conjunto mínimo controlado | PASA | 0,023 | Huella de `bd/semilla_humo.sql` verificada; 50 filas en 7 tablas |
| P07 | Instancia construida desde la base | PASA | 0,004 | 7 servicios y 27 alternativas; huella idéntica a la de la instancia generada (sin pérdida en la ida y vuelta) |
| P08 | Núcleo AG y validador independiente | PASA | 0,310 | Configuración idéntica a la oficial v1; semilla 9001; 7 genes; 100 generaciones; Φ = 0 y validador = 0 |
| P09 | Persistencia y lectura | PASA | 0,004 | Corrida 1 con 7 filas de programación; lo leído coincide con lo devuelto por el núcleo |
| P10 | Determinismo | PASA | 1,306 | 3 ejecuciones en procesos independientes con la misma huella de salida |
| P11 | Paridad con la referencia | PASA | 0,000 | Huella `d61c2499…5cbf` igual a la registrada en `config/humo.json` |
| P12 | Limpieza e integridad final | PASA | 0,068 | Base efímera eliminada; huellas registradas intactas; `core/` y `experimentos/` sin cambios |

Antes de la prueba de humo, la misma construcción ejecutó las 9 pruebas unitarias del núcleo (`9 passed`).

## 3. Conjunto de datos mínimo

Turno sintético de 7 servicios desde Soritor (6,25 % del turno de referencia de 112 servicios del experimento), con 3 unidades, 4 conductores, 6 autorizaciones (3 habituales y 3 reemplazos), 2 rutas y 27 alternativas admisibles (de 2 a 5 por servicio). Se generó una sola vez con el generador registrado del experimento, sin modificarlo, con la semilla 9001; la prueba carga el archivo SQL estático `bd/semilla_humo.sql` y verifica su huella antes de usarlo. Los identificadores (US01 a US03 y CS01 a CS04) son ficticios. El detalle por tabla está en la sección 7.3 del manual.

## 4. Integridad de la experimentación futura

| Riesgo | Control | Evidencia en la ejecución |
|---|---|---|
| Alterar el código o el protocolo registrados | Verificación de las 14 huellas antes (P01) y después (P12) e instantánea de `core/` y `experimentos/` | P01 y P12: PASA; `SHA256SUMS` íntegro después de la ejecución; ningún `__pycache__` en el árbol de fuentes |
| Escribir en una base equivocada | Servidor propio en 127.0.0.1:33306 con directorio de datos nuevo; base `sf_test_humo_<id>` eliminada al final; guardas de nombre y de host en `persistencia/config.py` | P04: el usuario solo tiene privilegios sobre `sf_test\_%`; P12: base eliminada |
| Mezclar datos reales con datos de prueba | `CHECK (origen_datos = 'sintetico')` y `CHECK (tipo = 'humo')` en el esquema | Esquema aplicado en P05 |
| Reutilizar semillas del experimento | Semillas 9001, distintas de las del experimento (instancias 101 a 103, métodos 1 a 10), comprobadas en P08 | P08: PASA |
| Ajustar parámetros a partir de la prueba | Configuración v1 comprobada contra `resolver_ag`; los resultados de la prueba no se comparan con los del experimento ni intervienen en ninguna decisión | P08: `configuracion_igual_a_v1 = true` |

## 5. Reproducibilidad

| Ejecución | Evidencia | *Bytecode* (17 módulos) | Salida canónica (3 ejecuciones) |
|---|---|---|---|
| Referencia `20261007T144734Z_945b`, sobre el sistema sin MySQL | `evidencias/ejecucion_referencia/` | `e19c0774d956f9a11ad5f51b9cabac8f009f87320a175110faf5c62d9bf591e0` | `d61c24991f23f49eebf567847826694d75e642d62e1052e6cf8617a6bf955cbf` (×3) |
| Reproducción `20261007T144829Z_329f`, construida en otra carpeta | `evidencias/reproduccion/` | `e19c0774d956f9a11ad5f51b9cabac8f009f87320a175110faf5c62d9bf591e0` | `d61c24991f23f49eebf567847826694d75e642d62e1052e6cf8617a6bf955cbf` (×3) |

Las dos construcciones, completas e independientes, produjeron el mismo *bytecode* y la misma salida; las seis ejecuciones de la cadena BD → núcleo → BD dieron la misma programación. Una verificación independiente que siguió el manual al pie de la letra (`20261007T145730Z_857f`), con una versión del paquete que solo difería de la entregada en la documentación y en un mensaje de error, reprodujo las siete huellas de la sección 8 del manual.

**Limitación.** En esta instancia el AG alcanza su mejor aptitud en la generación 0 y la trayectoria es constante, de modo que P10 comprueba el determinismo de la cadena completa y no el de una búsqueda que evoluciona. Como comprobación complementaria, fuera de la prueba de humo, `examples/run_demo.py` (instancia ilustrativa sintética de 20 servicios, configuración por omisión del núcleo, semilla 42) se ejecutó dos veces en procesos independientes del entorno de referencia: la mejor aptitud pasa de −1,1108 a −0,8385 en la generación 11 y las dos salidas fueron idénticas, salvo la línea del tiempo de reloj.

## 6. Verificación del criterio de rechazo

Para comprobar que la prueba bloquea la ejecución cuando debe, se ejecutaron tres fallos controlados sobre copias desechables del paquete:

| Caso | Alteración simulada | Paso que falla y mensaje | Código de salida | Limpieza |
|---|---|---|---|---|
| N1 | Una línea en blanco añadida a `core/repair.py` y `SHA256SUMS` regenerado para que A1 no la detecte | P01: «el código o el protocolo no coinciden con el registro: core/repair.py: huella distinta de la registrada»; registro `FATAL` de bloqueo estricto | 1 | P02 a P11 no se ejecutan; P12 vuelve a señalar el archivo alterado |
| N2 | Contraseña de `.env` distinta de la del servidor | P04: «el servidor rechazó la conexión (credenciales o permisos): (1045, Access denied…)» | 1 | P05 a P11 no se ejecutan; P12 cierra sin base que borrar |
| N3 | `pluggy` 1.5.0 instalado a mano en lugar de 1.6.0 | P02: «dependencias distintas del manifiesto: pluggy: fijada 1.6.0, instalada 1.5.0» | 1 | P03 a P11 no se ejecutan; servidor detenido y borrado |

En los tres casos no quedó ningún proceso `mysqld` ni directorio temporal residual.

## 7. Errores encontrados y corregidos durante la preparación

Se corrigió solo el código propio del despliegue; no se modificó ninguna biblioteca de terceros ni ningún archivo registrado.

| Id. | Tipo | Síntoma registrado | Causa raíz | Corrección |
|---|---|---|---|---|
| E1 | Error fatal (configuración) | `mysqld` abortó: «Failed to access directory for --secure-file-priv … /var/lib/mysql-files» | Con `--no-defaults` el servidor usa el directorio compilado, que solo crea el paquete completo `mysql-server-8.0` | `--secure-file-priv=NULL` en `scripts/bd_efimera.sh` |
| E2 | Error fatal (entorno) | «The socket file path is too long (> 107)» al construir desde una carpeta muy anidada | Límite de longitud de la ruta de un socket Unix | Socket en un directorio temporal de ruta corta (`/tmp/sfhumo.*`) |
| E3 | Error de ejecución | `rm` no pudo borrar `#innodb_redo` tras un arranque fallido | El proceso del servidor seguía activo mientras se borraba su directorio | `detener` espera a todo `mysqld` del directorio de datos y reintenta el borrado |
| E4 | Error lógico | El informe mostraba PyMySQL 2.2.8 | `pymysql.__version__` imita la versión de mysqlclient | Versiones leídas de los metadatos de instalación |
| E5 | Error lógico (determinismo) | `libevent-2.1-7t64` quedó en la versión fijada sin verificar su `.deb` | apt la actualizó como dependencia, desde el índice, al instalar otro paquete | Se fijaron los 8 paquetes con su huella y se instalan juntos desde los `.deb` verificados |

## 8. Consumo de recursos (línea base preliminar)

Valores de una sola ejecución, registrados como referencia inicial; la caracterización con diez o más ejecuciones y el análisis de fugas de memoria corresponden a la actividad 2, que no forma parte de esta entrega.

| Métrica (proceso principal de la prueba) | Valor |
|---|---|
| Memoria residente máxima | 58 040 KiB (56,7 MiB) |
| Tiempo de CPU | 0,721 s de usuario y 0,087 s de sistema |
| Lectura (`rchar`, incluye caché) | 25 726 949 bytes; 0 bytes leídos del disco |
| Escritura (`wchar`) | 1 029 544 bytes; 1 638 400 bytes enviados al disco |
| Tiempo de CPU de las dos repeticiones | 1,263 s |

El campo `repeticiones_rss_maximo_kib` del informe no mide la memoria propia de las repeticiones, porque en Linux incluye la memoria del proceso padre al momento de crearlas; por eso no se interpreta.

## 9. Decisión

**Estado de aceptación (PASA).** El entorno de pruebas se considera temporalmente estable: la arquitectura base se construye desde cero solo con los scripts, carga sus bibliotecas, se conecta a la base de pruebas sin rechazo de credenciales, procesa el conjunto mínimo de punta a punta y devuelve el mismo resultado en ejecuciones independientes. Corresponde continuar con:

1. la caracterización del consumo de RAM, CPU y E/S con diez o más ejecuciones (actividad 2);
2. la validación de RD-01 y la aplicación de E-01 y O-01, antes de cargar datos reales; la recolección de la muestra real sigue suspendida hasta entonces;
3. la incorporación de estos archivos al repositorio por el tesista (el repositorio sigue en consolidación) y la verificación en el equipo de destino (Windows 10 mediante WSL2), que no se hizo en esta sesión.

## 10. Evidencias

Las evidencias se entregan junto con este informe, en la carpeta `evidencias/` del paquete de entrega. No se versionan en el repositorio, porque `pruebas/humo/salidas/` y `.build/` figuran en `.gitignore`. Ninguna contiene la contraseña de la base de pruebas.

| Archivo | Contenido |
|---|---|
| `evidencias/ejecucion_referencia/` | `prueba_humo.log`, `informe.json`, `instancia.json`, `salida_1.json` a `salida_3.json`, registros de las repeticiones y `construccion.json` |
| `evidencias/reproduccion/` | Los mismos archivos de la segunda construcción independiente |
| `evidencias/consola_referencia.txt`, `evidencias/consola_reproduccion.txt` | Salida completa de `scripts/construir_y_probar.sh` |
| `evidencias/pruebas_negativas.txt` | Resultado de los casos N1 a N3 |
| `evidencias/verificacion_independiente/` | Consola, informe y salidas de la verificación que siguió el manual al pie de la letra |
| `evidencias/run_demo_1.txt`, `evidencias/run_demo_2.txt` | Las dos ejecuciones independientes de `examples/run_demo.py` (sección 5) |
