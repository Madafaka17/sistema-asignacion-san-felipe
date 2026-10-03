# Sistema de Asignación de Recursos — Transporte y Turismo San Felipe S.A.C.

Aplicación de escritorio que genera la **programación operativa diaria** de
la empresa: decide **qué vehículo y qué conductor cubren cada salida** de
cada ruta, mediante un **algoritmo genético**. Respeta las reglas operativas
(licencias, solapamientos, jornada máxima, descansos) y busca repartir la
carga de trabajo de forma equitativa. Desarrollado como parte de una tesis.

## Qué hace

- **Gestión de datos maestros:** vehículos, conductores, rutas y horarios.
- **Generación automática** de la programación de una fecha con un algoritmo
  genético (PyGAD), configurable desde `config/parametros_ga.yaml`.
- **Validación** de las reglas operativas: vehículo operativo, licencia
  vigente y compatible, sin solapamientos, jornada máxima.
- **Visualización:** diagrama de Gantt por vehículo y por conductor, curva de
  convergencia del algoritmo e indicadores de calidad.
- **Reportes** exportables a CSV.
- **Control de acceso** por roles (administrador y operador).

## Estado del proyecto

| Componente | Estado |
|---|---|
| Modelo de datos (`src/datos/esquema.sql`) y datos de ejemplo | ✅ Implementado y probado en MySQL 8.4.11 |
| Conexión a la base de datos (`src/datos/conexion.py`) | ✅ Implementado y probado |
| Configuración (`.env.example`, `config/parametros_ga.yaml`, `docker-compose.yml`) | ✅ Implementado |
| Pruebas de configuración y de base de datos (`tests/`) | ✅ Implementado |
| Documentación de arquitectura, modelos y algoritmo (`docs/`) | ✅ Completa |
| Algoritmo genético (`src/logica/algoritmo_genetico/`) | ⏳ Pendiente: diseño en [docs/teoria_algoritmo_genetico.md](docs/teoria_algoritmo_genetico.md) |
| Lógica de negocio (`generador_programacion.py`, `reglas_operativas.py`, `validaciones.py`) | ⏳ Pendiente: diseño en [docs/metodos_modelos_algoritmos.md](docs/metodos_modelos_algoritmos.md) |
| Interfaz gráfica (`src/presentacion/`) | ⏳ Pendiente |

## Tecnologías

| Componente | Tecnología | Versión |
|---|---|---|
| Lenguaje | Python | 3.12 |
| Interfaz gráfica | Tkinter (incluido en Python) | — |
| Gráficos | Matplotlib | 3.11.2 |
| Algoritmo genético | PyGAD (sobre NumPy 2.5.3) | 3.7.0 |
| Base de datos | MySQL (versión LTS) | 8.4.11 |
| Conector de base de datos | mysql-connector-python | 26.7.0 |
| Configuración | python-dotenv / PyYAML | 1.2.4 / 6.0.3 |
| Pruebas | pytest | 9.1.1 |
| Contenedores (opcional) | Docker con Docker Compose | — |

## Documentación

| Documento | Contenido |
|---|---|
| [docs/arquitectura.md](docs/arquitectura.md) | Capas, componentes, cómo se comunican, despliegue, seguridad y decisiones de diseño (con diagramas) |
| [docs/metodos_modelos_algoritmos.md](docs/metodos_modelos_algoritmos.md) | Lógica principal, modelo entidad-relación, diccionario de datos, reglas operativas, validaciones y autenticación |
| [docs/teoria_algoritmo_genetico.md](docs/teoria_algoritmo_genetico.md) | Cromosoma, función de aptitud, operadores, criterios de parada, pseudocódigo, ejemplo numérico y reproducibilidad |

## Estructura del repositorio

```text
sistema-asignacion-san-felipe/
├── config/
│   └── parametros_ga.yaml       # Parámetros del algoritmo genético y reglas operativas
├── docs/                        # Arquitectura, modelos y algoritmos
├── src/
│   ├── presentacion/            # Capa de presentación (interfaz Tkinter)
│   ├── logica/                  # Capa de lógica de negocio
│   │   └── algoritmo_genetico/  # Cromosoma, aptitud, operadores, orquestador
│   └── datos/                   # Capa de datos
│       ├── conexion.py          # Conexión a MySQL leyendo .env
│       ├── esquema.sql          # Tablas, restricciones y vistas
│       └── datos_ejemplo.sql    # Datos ficticios para pruebas
├── tests/                       # Pruebas automatizadas (pytest)
├── .env.example                 # Plantilla de variables de entorno
├── .python-version              # Versión de Python del proyecto
├── docker-compose.yml           # MySQL 8.4.11 para desarrollo
├── pytest.ini                   # Configuración de pytest
└── requirements.txt             # Dependencias con versiones fijas
```

## Requisitos previos

- [Git](https://git-scm.com/)
- [Python 3.12](https://www.python.org/downloads/) con Tkinter.
  - **Windows:** el instalador oficial incluye Tkinter (opción *tcl/tk and IDLE*).
  - **Ubuntu/Debian:** `sudo apt install python3.12-venv python3-tk`
- Una de estas dos opciones para la base de datos:
  - **Opción A (recomendada):** [Docker Desktop](https://www.docker.com/products/docker-desktop/), que incluye Docker Compose.
  - **Opción B:** [MySQL Server 8.4](https://dev.mysql.com/downloads/mysql/8.4.html) instalado en el equipo.

## Instalación

### 1. Clonar el repositorio

```bash
git clone https://github.com/Madafaka17/sistema-asignacion-san-felipe.git
cd sistema-asignacion-san-felipe
```

### 2. Crear el entorno virtual e instalar las dependencias

**Windows (PowerShell):**

```powershell
py -3.12 -m venv venv
.\venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
```

> Si PowerShell no permite ejecutar `Activate.ps1`, ejecute una vez
> `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` y vuelva a intentarlo.

**Linux / macOS:**

```bash
python3.12 -m venv venv
source venv/bin/activate
python -m pip install --upgrade pip
pip install -r requirements.txt
```

### 3. Configurar las variables de entorno

Copie la plantilla y cambie las contraseñas de ejemplo:

```bash
cp .env.example .env              # Linux / macOS
Copy-Item .env.example .env       # Windows PowerShell
```

| Variable | Descripción | Valor de ejemplo |
|---|---|---|
| `DB_HOST` | Servidor MySQL | `127.0.0.1` |
| `DB_PORT` | Puerto de MySQL | `3306` |
| `DB_NAME` | Base de datos | `san_felipe` |
| `DB_USER` | Usuario de la aplicación (no use `root`) | `san_felipe_app` |
| `DB_PASSWORD` | Contraseña de `DB_USER` | — |
| `MYSQL_ROOT_PASSWORD` | Contraseña de `root` del contenedor (solo Opción A) | — |

El archivo `.env` está en `.gitignore`: **nunca lo suba al repositorio**.

### 4. Crear la base de datos

**Opción A: con Docker (recomendada)**

```bash
docker compose up -d
docker compose ps        # esperar a que el estado sea "healthy"
```

Esto descarga MySQL 8.4.11, crea la base `DB_NAME` y el usuario `DB_USER`
con los valores de `.env` y carga `esquema.sql` y `datos_ejemplo.sql`.
Los datos se conservan entre reinicios. Para empezar desde cero (borra todos
los datos): `docker compose down -v` y luego `docker compose up -d`.

**Opción B: con MySQL instalado en el equipo**

Conéctese como `root` (`mysql -h 127.0.0.1 -u root -p`) y ejecute, usando en
`IDENTIFIED BY` la misma contraseña que puso en `DB_PASSWORD`:

```sql
CREATE DATABASE san_felipe CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE USER 'san_felipe_app'@'127.0.0.1' IDENTIFIED BY 'su_contrasena';
GRANT ALL PRIVILEGES ON san_felipe.* TO 'san_felipe_app'@'127.0.0.1';
```

Después, desde la carpeta del proyecto, cargue el esquema y los datos de ejemplo:

```bash
mysql -h 127.0.0.1 -u san_felipe_app -p san_felipe -e "source src/datos/esquema.sql; source src/datos/datos_ejemplo.sql;"
```

> El usuario se crea para `127.0.0.1` (y no para `localhost`) porque la
> aplicación se conecta por TCP. MySQL 8.4 rechaza esas conexiones si la
> cuenta se creó como `'san_felipe_app'@'localhost'`.
> En Windows, si `mysql` no se reconoce, use la ruta completa, por ejemplo
> `"C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe"`.

### 5. Verificar la instalación

Con el entorno virtual activado:

```bash
python -m src.datos.conexion
```

Resultado esperado (con la Opción B la versión de MySQL puede variar):

```text
Conexión exitosa: MySQL 8.4.11, base de datos 'san_felipe', 10 tablas/vistas.
```

Ejecute las pruebas automatizadas:

```bash
pytest                                        # pruebas unitarias (no necesitan MySQL)
PRUEBAS_BD=1 pytest -m integracion            # Linux / macOS: prueba la base de datos
$env:PRUEBAS_BD=1; pytest -m integracion      # Windows PowerShell
```

Todas las pruebas deben pasar. Sin `PRUEBAS_BD=1`, las de integración se
muestran como *skipped*.

## Ejecución

Por ahora se pueden ejecutar la verificación de la conexión y las pruebas
(paso 5). La interfaz gráfica está en desarrollo; su punto de entrada será la
pantalla de inicio de sesión: `python -m src.presentacion.login`.

Ejecute siempre los comandos desde la carpeta raíz del proyecto y con el
entorno virtual activado.

## Configuración del algoritmo genético

`config/parametros_ga.yaml` contiene los parámetros del algoritmo (tamaño de
población, probabilidades de cruce y mutación, elitismo, criterios de parada,
pesos de la función de aptitud) y de las reglas operativas (jornada máxima,
descansos, alistamiento). Cada parámetro está comentado y su fundamento se
explica en [docs/teoria_algoritmo_genetico.md](docs/teoria_algoritmo_genetico.md).
La prueba `tests/test_configuracion.py` comprueba que los valores sean
coherentes.

## Reproducibilidad

Lo que garantiza que otra persona obtenga el mismo comportamiento:

| Elemento | Cómo se fija |
|---|---|
| Versión de Python | `.python-version` (3.12) |
| Dependencias | `requirements.txt` con versiones exactas, incluidas las transitivas |
| Motor de base de datos | Imagen `mysql:8.4.11` en `docker-compose.yml` |
| Estructura y datos de prueba | `esquema.sql` y `datos_ejemplo.sql` versionados; las fechas de vencimiento de licencias son relativas a la fecha de carga |
| Resultados del algoritmo | `semilla_aleatoria` fija en `parametros_ga.yaml`; cada programación guarda la semilla y una copia de los parámetros usados |
| Secretos | Fuera del repositorio (`.env`), con plantilla `.env.example` |

Para actualizar una dependencia: cambie su versión en `requirements.txt`,
reinstale en un entorno virtual nuevo, ejecute `pytest` y registre el cambio
en el commit.

## Solución de problemas

| Problema | Solución |
|---|---|
| `Faltan variables de entorno: ...` | No existe `.env`. Copie `.env.example` como `.env` (paso 3) |
| `Access denied for user 'san_felipe_app'@'...'` | **Docker:** si cambió `.env` después del primer `docker compose up`, el usuario conserva la contraseña anterior; ejecute `docker compose down -v` y `docker compose up -d` (borra los datos). **MySQL local:** cree el usuario para `127.0.0.1` (paso 4, Opción B) y verifique la contraseña |
| `Can't connect to MySQL server on '127.0.0.1:3306'` | MySQL no está en ejecución: revise `docker compose ps` o el servicio de MySQL |
| `port is already allocated` al levantar Docker | Ya hay otro MySQL usando el puerto 3306. Cambie `DB_PORT=3307` en `.env` |
| `ModuleNotFoundError: No module named 'src'` | Ejecute los comandos desde la raíz del proyecto, con `python -m ...` |
| `ModuleNotFoundError: No module named 'mysql'` (u otro paquete) | El entorno virtual no está activado (paso 2) |
| `No module named '_tkinter'` | Instale Tkinter: `sudo apt install python3-tk` (Linux) o reinstale Python marcando *tcl/tk* (Windows) |
