"""Prueba de humo del prototipo desplegado (sesión 8, actividad 1).

Recorre la ruta crítica del sistema con un conjunto de datos mínimo, sintético y
controlado, cargado en una base de datos de pruebas efímera, y termina con un
resultado binario: PASA (código de salida 0) o FALLA (código 1). Se detiene en el
primer fallo (bloqueo estricto): solo la limpieza y la verificación final de
integridad se ejecutan siempre.

No compromete la experimentación futura:
  * verifica antes y después las huellas SHA-256 registradas del protocolo, del
    generador y del núcleo, y una instantánea de core/ y experimentos/;
  * crea una base efímera sf_test_humo_<id> en el servidor de pruebas y la elimina
    al terminar; el usuario de pruebas no tiene privilegios fuera de sf_test_%;
  * usa semillas disjuntas de las del experimento registrado y datos sintéticos;
  * solo escribe en pruebas/humo/salidas/<id>/ y en la base efímera.

No evalúa la calidad de la programación, la eficiencia ni los casos borde.

Uso (siempre a través de scripts/construir_y_probar.sh, que fija el entorno):
    python -s -m pruebas.humo.prueba_humo
"""
from __future__ import annotations

import argparse
import json
import logging
import os
import platform
import re
import secrets
import subprocess
import sys
import time
import traceback
from datetime import datetime, timezone
from importlib import metadata
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
for _p in (RAIZ, RAIZ / "experimentos" / "poc_cap3"):
    if str(_p) not in sys.path:
        sys.path.insert(0, str(_p))

from persistencia.canonico import a_json, huella_instancia, instancia_a_dict, salida_a_dict, sha256  # noqa: E402
from persistencia.config import cargar_config, env_no_versionado  # noqa: E402
from pruebas.humo import integridad  # noqa: E402

CONFIG = RAIZ / "config" / "humo.json"
ENV = RAIZ / ".env"
ESQUEMA = RAIZ / "bd" / "esquema.sql"
SALIDAS = RAIZ / "pruebas" / "humo" / "salidas"
LOCK = RAIZ / "requirements.lock"

logging.addLevelName(logging.CRITICAL, "FATAL")


class FalloPrueba(Exception):
    """Condición de rechazo de un paso de la prueba."""


class _FormatoUTC(logging.Formatter):
    def formatTime(self, record, datefmt=None):  # noqa: N802 (API de logging)
        t = datetime.fromtimestamp(record.created, timezone.utc)
        return t.isoformat(timespec="milliseconds").replace("+00:00", "Z")


def _configurar_registro(archivo: Path, consola: bool) -> logging.Logger:
    log = logging.getLogger(f"humo.{archivo.stem}")
    log.setLevel(logging.DEBUG)
    log.propagate = False
    fmt = _FormatoUTC("%(asctime)s %(levelname)-7s %(message)s")
    fh = logging.FileHandler(archivo, encoding="utf8")
    fh.setLevel(logging.DEBUG)
    fh.setFormatter(fmt)
    log.addHandler(fh)
    if consola:
        ch = logging.StreamHandler(sys.stderr)
        ch.setLevel(logging.INFO)
        ch.setFormatter(fmt)
        log.addHandler(ch)
    return log


def _exigir(condicion: bool, mensaje: str) -> None:
    if not condicion:
        raise FalloPrueba(mensaje)


def _normalizar(nombre: str) -> str:
    return re.sub(r"[-_.]+", "-", nombre).lower()


def _leer_lock() -> dict[str, str]:
    fijadas = {}
    for linea in LOCK.read_text(encoding="utf8").splitlines():
        m = re.match(r"^([A-Za-z0-9_.\-]+)==([^\s\\;]+)", linea)
        if m:
            fijadas[_normalizar(m.group(1))] = m.group(2)
    return fijadas


def _cpu_y_memoria() -> dict:
    datos = {"nucleos_logicos": os.cpu_count()}
    try:
        for linea in Path("/proc/cpuinfo").read_text().splitlines():
            if linea.startswith("model name"):
                datos["procesador"] = linea.split(":", 1)[1].strip()
                break
        for linea in Path("/proc/meminfo").read_text().splitlines():
            if linea.startswith("MemTotal"):
                datos["memoria_total_kib"] = int(linea.split()[1])
                break
        for linea in Path("/etc/os-release").read_text().splitlines():
            if linea.startswith("PRETTY_NAME="):
                datos["sistema_operativo"] = linea.split("=", 1)[1].strip('"')
    except OSError:
        pass
    return datos


def _metricas_proceso() -> dict:
    """Consumo del proceso (informativo; la caracterización con 10 o más ejecuciones es
    la actividad 2 y no forma parte de esta prueba)."""
    out = {}
    try:
        import resource
        propio = resource.getrusage(resource.RUSAGE_SELF)
        hijos = resource.getrusage(resource.RUSAGE_CHILDREN)
        out["rss_maximo_kib"] = propio.ru_maxrss
        out["cpu_usuario_s"] = round(propio.ru_utime, 3)
        out["cpu_sistema_s"] = round(propio.ru_stime, 3)
        out["repeticiones_rss_maximo_kib"] = hijos.ru_maxrss
        out["repeticiones_cpu_s"] = round(hijos.ru_utime + hijos.ru_stime, 3)
    except ImportError:
        pass
    try:
        io = dict(l.split(": ") for l in Path("/proc/self/io").read_text().splitlines())
        out["io_bytes_leidos"] = int(io["rchar"])
        out["io_bytes_escritos"] = int(io["wchar"])
        out["io_bytes_leidos_disco"] = int(io["read_bytes"])
        out["io_bytes_escritos_disco"] = int(io["write_bytes"])
    except (OSError, KeyError, ValueError):
        pass
    return out


# ---------------------------------------------------------------------------------------------
# Cadena BD -> instancia -> núcleo AG -> validador -> BD, compartida por la ejecución principal
# (pasos P07, P08 y P09) y por las repeticiones independientes (paso P10)
# ---------------------------------------------------------------------------------------------
def cargar(con, cfg: dict):
    from persistencia.repositorio import cargar_instancia
    return cargar_instancia(con, cfg["conjunto_minimo"]["id_turno"], cfg["pesos"])


def optimizar(inst, t_min: float, cfg: dict, destino: Path) -> dict:
    from core.scheduler import GAConfig, run
    from validador import contar_incumplimientos
    params = {k: v for k, v in cfg["algoritmo_genetico"].items() if k != "fuente"}
    semilla = cfg["semillas"]["algoritmo_genetico"]
    res = run(inst, GAConfig(**params, min_transition=t_min, random_seed=semilla))
    validador = contar_incumplimientos(res.chromosome, inst.services_with_options(), inst, t_min)
    salida = salida_a_dict(cfg["conjunto_minimo"]["id_turno"], semilla, res, validador)
    datos = a_json(salida)
    destino.write_bytes(datos)
    return {"resultado": res, "validador": validador, "salida": salida, "huella": sha256(datos),
            "params": params, "semilla": semilla}


def persistir(con, cfg: dict, r: dict) -> dict:
    from persistencia.repositorio import guardar_programacion, leer_programacion
    id_corrida = guardar_programacion(con, cfg["conjunto_minimo"]["id_turno"], r["semilla"], r["resultado"],
                                      r["validador"], r["huella"])
    return {"id_corrida": id_corrida, "leida": leer_programacion(con, id_corrida)}


# ---------------------------------------------------------------------------------------------
# Ejecución principal
# ---------------------------------------------------------------------------------------------
class PruebaHumo:
    def __init__(self) -> None:
        self.inicio = datetime.now(timezone.utc)
        self.id = self.inicio.strftime("%Y%m%dT%H%M%SZ") + "_" + secrets.token_hex(2)
        self.dir = SALIDAS / self.id
        self.dir.mkdir(parents=True, exist_ok=False)
        self.log = _configurar_registro(self.dir / "prueba_humo.log", consola=True)
        self.pasos: list[dict] = []
        self.advertencias: list[str] = []
        self.cfg: dict = {}
        self.cfg_bd = None
        self.con = None
        self.bd: str | None = None
        self.bd_creada = False
        self.inst_antes: dict = {}
        self.estado: dict = {}
        self.informe: dict = {"id_ejecucion": self.id, "inicio_utc": self.inicio.isoformat(timespec="seconds"),
                              "datos": "sintéticos (no son datos de la empresa)"}

    # -- infraestructura de pasos -------------------------------------------------------------
    def paso(self, codigo: str, nombre: str, funcion) -> str:
        self.log.info("[%s] %s: inicio", codigo, nombre)
        t0, c0 = time.perf_counter(), time.process_time()
        try:
            detalle = funcion() or {}
            estado = detalle.pop("_estado", "PASA")
        except FalloPrueba as exc:
            estado, detalle = "FALLA", {"motivo": str(exc)}
            self.log.error("[%s] condición de rechazo: %s", codigo, exc)
        except Exception as exc:  # noqa: BLE001 - toda excepción no prevista es un fallo estructural
            estado, detalle = "FALLA", {"motivo": f"{type(exc).__name__}: {exc}"}
            self.log.critical("[%s] excepción no controlada: %s: %s", codigo, type(exc).__name__, exc)
            self.log.debug("[%s] traza de la pila:\n%s", codigo, traceback.format_exc())
        duracion = time.perf_counter() - t0
        self.pasos.append({"codigo": codigo, "nombre": nombre, "estado": estado,
                           "duracion_s": round(duracion, 4), "cpu_s": round(time.process_time() - c0, 4),
                           "detalle": detalle})
        nivel = logging.INFO if estado in ("PASA", "OMITIDA") else logging.ERROR
        self.log.log(nivel, "[%s] %s: %s (%.3f s)", codigo, nombre, estado, duracion)
        return estado

    # -- P01 -------------------------------------------------------------------------------------
    def p01_integridad(self) -> dict:
        diferencias = integridad.verificar_registradas(RAIZ)
        _exigir(not diferencias, "el código o el protocolo no coinciden con el registro: " + "; ".join(diferencias))
        self.inst_antes = integridad.instantanea(RAIZ)
        n = len(integridad.huellas_registradas(RAIZ))
        self.log.debug("instantánea inicial: %d archivos de core/ y experimentos/", len(self.inst_antes))
        return {"archivos_registrados_verificados": n, "archivos_en_instantanea": len(self.inst_antes)}

    # -- P02 -------------------------------------------------------------------------------------
    def p02_entorno(self) -> dict:
        self.cfg = json.loads(CONFIG.read_text(encoding="utf8"))
        esperado = self.cfg["entorno_esperado"]
        _exigir(platform.python_version() == esperado["python"],
                f"Python {platform.python_version()} distinto del esperado {esperado['python']}")
        venv = (RAIZ / ".venv").resolve()
        _exigir(sys.prefix != sys.base_prefix and Path(sys.prefix).resolve() == venv,
                "el intérprete no es el del entorno virtual del proyecto (.venv)")
        mal = {k: os.environ.get(k) for k, v in esperado["variables"].items() if os.environ.get(k) != v}
        _exigir(not mal, f"variables de entorno de determinismo ausentes o distintas: {mal}")

        fijadas = _leer_lock()
        distintas, instaladas = [], {}
        for nombre, version in fijadas.items():
            try:
                v = metadata.version(nombre)
            except metadata.PackageNotFoundError:
                v = None
            instaladas[nombre] = v
            if v != version:
                distintas.append(f"{nombre}: fijada {version}, instalada {v}")
        _exigir(not distintas, "dependencias distintas del manifiesto: " + "; ".join(distintas))
        permitidos = {_normalizar(p) for p in esperado["paquetes_adicionales_permitidos"]}
        sobrantes = sorted({_normalizar(d.metadata["Name"]) for d in metadata.distributions() if d.metadata["Name"]}
                           - set(fijadas) - permitidos)
        _exigir(not sobrantes, f"paquetes instalados que no están en el manifiesto: {sobrantes}")

        import numpy  # noqa: F401  (carga de bibliotecas: un error aquí es un fallo estructural)
        import pygad  # noqa: F401
        import pymysql  # noqa: F401
        import cryptography  # noqa: F401
        import pulp
        import core.domain, core.conflicts, core.fitness, core.repair, core.scheduler  # noqa: E401,F401
        import validador  # noqa: F401
        # Versiones según los metadatos de instalación (pymysql.__version__ imita a mysqlclient).
        versiones = {n: metadata.version(n) for n in ("numpy", "pygad", "pymysql", "cryptography", "pulp")}

        prob = pulp.LpProblem("humo", pulp.LpMaximize)
        x = pulp.LpVariable("x", 0, 1, cat="Binary")
        prob += x
        prob += x <= 1
        solver = pulp.PULP_CBC_CMD(msg=False, threads=1)
        prob.solve(solver)
        _exigir(pulp.LpStatus[prob.status] == "Optimal", "el solucionador CBC no resolvió el problema trivial")
        cbc = ""
        try:
            sal = subprocess.run([solver.path, "-quit"], capture_output=True, text=True, timeout=20).stdout
            m = re.search(r"Version:\s*(\S+)", sal)
            cbc = m.group(1) if m else ""
        except (OSError, subprocess.SubprocessError):
            pass
        versiones["cbc"] = cbc
        self.informe["entorno"] = {"python": platform.python_version(), "implementacion": platform.python_implementation(),
                                   "plataforma": platform.platform(), "nucleo_linux": platform.release(),
                                   "arquitectura": platform.machine(), **_cpu_y_memoria(),
                                   "pip": instaladas.get("pip") or metadata.version("pip"),
                                   "paquetes": dict(sorted(instaladas.items())), "modulos": versiones,
                                   "variables": {k: os.environ.get(k) for k in sorted(esperado["variables"])},
                                   "sha256_requirements_lock": integridad.sha256_archivo(LOCK)}
        self.log.debug("versiones: %s", versiones)
        return {"python": platform.python_version(), "paquetes_fijados": len(fijadas), "modulos": versiones,
                "solucionador_cbc": "Optimal"}

    # -- P03 -------------------------------------------------------------------------------------
    def p03_configuracion(self) -> dict:
        self.cfg_bd = cargar_config(ENV)
        _exigir(env_no_versionado(RAIZ), ".env no figura en .gitignore (las credenciales no deben versionarse)")
        self.log.debug("configuración de conexión: %s", self.cfg_bd.resumen_seguro())
        return {"conexion": self.cfg_bd.resumen_seguro(), "env_en_gitignore": True}

    # -- P04 -------------------------------------------------------------------------------------
    def p04_conexion(self) -> dict:
        from persistencia.conexion import conectar, puerto_escuchando, version_servidor
        _exigir(puerto_escuchando(self.cfg_bd), f"nada escucha en {self.cfg_bd.host}:{self.cfg_bd.puerto}")
        import pymysql
        try:
            self.con = conectar(self.cfg_bd)
        except pymysql.err.OperationalError as exc:
            raise FalloPrueba(f"el servidor rechazó la conexión (credenciales o permisos): {exc.args}") from exc
        version = version_servidor(self.con)
        esperada = self.cfg["entorno_esperado"]["mysql"]
        _exigir(version.split("-")[0] == esperada, f"MySQL {version} distinto del esperado {esperada}")
        with self.con.cursor() as cur:
            cur.execute("SHOW GRANTS FOR CURRENT_USER()")
            permisos = [r[0] for r in cur.fetchall()]
        globales = [g for g in permisos if " ON *.* " in g and not g.startswith("GRANT USAGE ON *.*")]
        _exigir(not globales, "el usuario de pruebas tiene privilegios globales; solo debe operar sobre sf_test_%")
        _exigir(any("`sf\\_test\\_%`" in g for g in permisos), "el usuario de pruebas no tiene permisos sobre sf_test_%")
        self.informe["base_datos"] = {"servidor": version, "puerto": self.cfg_bd.puerto, "host": self.cfg_bd.host}
        return {"puerto_escuchando": True, "credenciales_aceptadas": True, "servidor": version,
                "permisos": [re.sub(r" TO .*$", "", g) for g in permisos]}

    # -- P05 -------------------------------------------------------------------------------------
    def p05_esquema(self) -> dict:
        from persistencia.repositorio import TABLAS_ESPERADAS, aplicar_sql, crear_bd, tablas
        self.bd = f"{self.cfg_bd.prefijo}humo_{self.id.lower()}"
        crear_bd(self.con, self.bd, self.cfg_bd)
        self.bd_creada = True
        n = aplicar_sql(self.con, ESQUEMA)
        t = tablas(self.con)
        _exigir(t == TABLAS_ESPERADAS, f"tablas creadas {t} distintas de las esperadas")
        self.informe.setdefault("base_datos", {})["base_efimera"] = self.bd
        return {"base_efimera": self.bd, "sentencias": n, "tablas": list(t),
                "sha256_esquema": integridad.sha256_archivo(ESQUEMA)}

    # -- P06 -------------------------------------------------------------------------------------
    def p06_datos(self) -> dict:
        from persistencia.repositorio import aplicar_sql, conteos
        cm = self.cfg["conjunto_minimo"]
        ruta = RAIZ / cm["archivo"]
        h = integridad.sha256_archivo(ruta)
        _exigir(h == cm["sha256"], "la semilla de datos no coincide con su huella registrada en config/humo.json")
        aplicar_sql(self.con, ruta)
        c = conteos(self.con)
        _exigir(c == cm["conteos"], f"conteos cargados {c} distintos de los esperados {cm['conteos']}")
        pct = round(100.0 * cm["servicios"] / cm["turno_referencia_servicios"], 2)
        self.informe["conjunto_minimo"] = {"archivo": cm["archivo"], "sha256": h, "conteos": c,
                                           "porcentaje_del_turno_de_referencia": pct}
        return {"sha256": h, "conteos": c, "porcentaje_del_turno_de_referencia": pct}

    # -- P07 -------------------------------------------------------------------------------------
    def p07_instancia(self) -> dict:
        inst, t_min = cargar(self.con, self.cfg)
        self.estado.update(instancia=inst, t_min=t_min)
        cm = self.cfg["conjunto_minimo"]
        h = huella_instancia(inst)
        (self.dir / "instancia.json").write_bytes(a_json(instancia_a_dict(inst)))
        self.log.debug("instancia: %d servicios, t_min=%s, huella=%s", len(inst.services), t_min, h)
        _exigir(h == cm["huella_instancia"],
                "la instancia leída de la BD difiere de la generada (pérdida en la ida y vuelta)")
        _exigir(len(inst.services) == cm["servicios"], "número de servicios distinto del esperado")
        _exigir(not inst.uncovered_services(), "hay servicios sin alternativas admisibles")
        _exigir(all(2 <= len(s.admissible) <= 5 for s in inst.services),
                "servicios con un número de alternativas fuera de [2, 5]")
        return {"huella_instancia": h, "servicios": len(inst.services),
                "alternativas": sum(len(s.admissible) for s in inst.services), "t_min": t_min}

    # -- P08 -------------------------------------------------------------------------------------
    def p08_nucleo(self) -> dict:
        v1 = integridad.configuracion_ag_v1(RAIZ)
        params = {k: v for k, v in self.cfg["algoritmo_genetico"].items() if k != "fuente"}
        distintos = {k: (params.get(k), v) for k, v in v1.items()
                     if k not in ("min_transition", "random_seed") and params.get(k) != v}
        _exigir(not distintos, f"la configuración del AG difiere de la oficial v1: {distintos}")
        reservadas = integridad.semillas_reservadas(RAIZ)
        _exigir(self.cfg["semillas"]["algoritmo_genetico"] not in reservadas["SEMILLAS_METODO"]
                and self.cfg["semillas"]["instancia"] not in reservadas["SEMILLAS_INSTANCIA"],
                "las semillas de la prueba coinciden con las del experimento registrado")
        inst = self.estado["instancia"]
        self.estado.update(optimizar(inst, self.estado["t_min"], self.cfg, self.dir / "salida_1.json"))
        res = self.estado["resultado"]
        n = len(inst.services_with_options())
        self.log.debug("cromosoma=%s aptitud=%r", list(res.chromosome), res.breakdown.fitness)
        _exigir(len(res.chromosome) == n, "longitud del cromosoma distinta del número de servicios")
        _exigir(all(0 <= g < len(s.admissible) for s, g in zip(res.services, res.chromosome)),
                "gen fuera del rango de alternativas")
        _exigir(len(res.best_fitness_by_generation) == params["num_generations"],
                "el ciclo generacional no completó las generaciones configuradas")
        phi = res.breakdown.feasibility_violations
        _exigir(self.estado["validador"] == phi,
                f"el validador independiente ({self.estado['validador']}) y el núcleo (Φ={phi}) no coinciden")
        if phi:
            self.advertencias.append(f"la programación de la prueba tiene Φ = {phi} (informativo)")
            self.log.warning("Φ = %d en la programación de la prueba (no es criterio de la prueba de humo)", phi)
        return {"configuracion_igual_a_v1": True, "semilla_ag": self.estado["semilla"],
                "semillas_reservadas_del_experimento": reservadas, "genes": n,
                "generaciones": len(res.best_fitness_by_generation), "phi": phi,
                "validador": self.estado["validador"], "aptitud": res.breakdown.fitness,
                "huella_salida": self.estado["huella"]}

    # -- P09 -------------------------------------------------------------------------------------
    def p09_persistencia(self) -> dict:
        self.estado.update(persistir(self.con, self.cfg, self.estado))
        esperado = self.estado["salida"]["asignaciones"]
        _exigir(self.estado["leida"] == esperado, "la programación leída de la BD difiere de la devuelta por el núcleo")
        return {"id_corrida": self.estado["id_corrida"], "filas_programacion": len(self.estado["leida"])}

    # -- P10 -------------------------------------------------------------------------------------
    def p10_determinismo(self) -> dict:
        huellas = [self.estado["huella"]]
        detalles = []
        for k in range(2, self.cfg["repeticiones_determinismo"] + 1):
            cmd = [sys.executable, "-s", "-m", "pruebas.humo.prueba_humo", "--repeticion", str(k),
                   "--bd", self.bd, "--dir", str(self.dir)]
            t0 = time.perf_counter()
            proc = subprocess.run(cmd, cwd=RAIZ, capture_output=True, text=True, timeout=600)
            dur = time.perf_counter() - t0
            _exigir(proc.returncode == 0, f"la repetición {k} terminó con código {proc.returncode}: "
                                          f"{proc.stderr.strip().splitlines()[-1:] if proc.stderr else ''}")
            r = json.loads(proc.stdout.strip().splitlines()[-1])
            huellas.append(r["huella"])
            detalles.append({"repeticion": k, "pid": r["pid"], "id_corrida": r["id_corrida"], "huella": r["huella"],
                             "duracion_s": round(dur, 3)})
            self.log.debug("repetición %d: %s", k, r)
        iguales = len(set(huellas)) == 1
        _exigir(iguales, f"las ejecuciones independientes produjeron salidas distintas: {huellas}")
        self.informe["huellas"] = {"salida": huellas[0], "ejecuciones_independientes": huellas}
        return {"ejecuciones": len(huellas), "huellas_identicas": True, "huella_salida": huellas[0],
                "repeticiones": detalles}

    # -- P11 -------------------------------------------------------------------------------------
    def p11_paridad(self) -> dict:
        ref = self.cfg["referencia"]
        if not ref.get("huella_salida"):
            self.advertencias.append("sin huella de referencia registrada: la paridad entre entornos no se verificó")
            self.log.warning("config/humo.json no tiene huella de referencia; paso omitido")
            return {"_estado": "OMITIDA", "motivo": "no hay huella de referencia"}
        _exigir(self.estado["huella"] == ref["huella_salida"],
                "la salida es determinista en este equipo pero difiere de la del entorno de referencia "
                f"({ref.get('entorno')}): el entorno no tiene paridad")
        return {"huella_referencia": ref["huella_salida"], "entorno_referencia": ref.get("entorno"),
                "coincide": True}

    # -- P12 (siempre) ---------------------------------------------------------------------------
    def p12_limpieza(self) -> dict:
        detalle = {}
        if self.con is not None:
            if self.bd_creada:
                from persistencia.repositorio import eliminar_bd, existe_bd
                eliminar_bd(self.con, self.bd, self.cfg_bd)
                _exigir(not existe_bd(self.con, self.bd), "la base efímera no se eliminó")
                detalle["base_efimera_eliminada"] = self.bd
            self.con.close()
            self.con = None
        diferencias = integridad.verificar_registradas(RAIZ)
        _exigir(not diferencias, "al terminar, hay archivos registrados distintos del registro: " + "; ".join(diferencias))
        if self.inst_antes:
            cambios = integridad.comparar_instantaneas(self.inst_antes, integridad.instantanea(RAIZ))
            _exigir(not cambios, "core/ o experimentos/ cambiaron durante la prueba: " + "; ".join(cambios))
            detalle["core_y_experimentos_sin_cambios"] = True
        detalle["huellas_registradas_intactas"] = True
        return detalle

    # -- orquestación ----------------------------------------------------------------------------
    def ejecutar(self) -> int:
        self.log.info("Prueba de humo %s. Datos sintéticos; base de pruebas efímera.", self.id)
        principales = [
            ("P01", "Integridad del protocolo y del núcleo registrados", self.p01_integridad),
            ("P02", "Entorno, dependencias fijadas y carga de bibliotecas", self.p02_entorno),
            ("P03", "Configuración desacoplada (.env no versionado)", self.p03_configuracion),
            ("P04", "Puerto, credenciales y permisos de la BD de pruebas", self.p04_conexion),
            ("P05", "Creación de la base efímera y del esquema", self.p05_esquema),
            ("P06", "Carga del conjunto mínimo controlado", self.p06_datos),
            ("P07", "Construcción de la instancia desde la BD", self.p07_instancia),
            ("P08", "Ejecución del núcleo AG y validador independiente", self.p08_nucleo),
            ("P09", "Persistencia y lectura de la programación", self.p09_persistencia),
            ("P10", "Determinismo en ejecuciones independientes", self.p10_determinismo),
            ("P11", "Paridad con el entorno de referencia", self.p11_paridad),
        ]
        for i, (codigo, nombre, funcion) in enumerate(principales):
            if self.paso(codigo, nombre, funcion) == "FALLA":
                self.log.critical("BLOQUEO ESTRICTO en %s: se detiene la prueba; no debe continuar la "
                                  "experimentación hasta corregir la causa.", codigo)
                for c, n, _ in principales[i + 1:]:
                    self.pasos.append({"codigo": c, "nombre": n, "estado": "NO EJECUTADA"})
                break
        self.paso("P12", "Limpieza de la base efímera e integridad final", self.p12_limpieza)

        resultado = "PASA" if all(p["estado"] in ("PASA", "OMITIDA") for p in self.pasos) else "FALLA"
        fin = datetime.now(timezone.utc)
        self.informe.update({"fin_utc": fin.isoformat(timespec="seconds"), "resultado": resultado,
                             "duracion_total_s": round((fin - self.inicio).total_seconds(), 3),
                             "pasos": self.pasos, "advertencias": self.advertencias,
                             "metricas_informativas": _metricas_proceso()})
        (self.dir / "informe.json").write_bytes(a_json(self.informe))
        self.log.info("Resumen: %s", ", ".join(f"{p['codigo']} {p['estado']}" for p in self.pasos))
        self.log.info("RESULTADO DE LA PRUEBA DE HUMO: %s (evidencia en %s)", resultado,
                      self.dir.relative_to(RAIZ).as_posix())
        return 0 if resultado == "PASA" else 1


# ---------------------------------------------------------------------------------------------
# Repetición independiente (proceso nuevo, invocado por P10)
# ---------------------------------------------------------------------------------------------
def repeticion(k: int, bd: str, directorio: Path) -> int:
    from persistencia.conexion import conectar
    log = _configurar_registro(directorio / f"repeticion_{k}.log", consola=False)
    con = None
    try:
        cfg = json.loads(CONFIG.read_text(encoding="utf8"))
        con = conectar(cargar_config(ENV), bd)
        log.info("repetición %d en proceso %d sobre %s", k, os.getpid(), bd)
        inst, t_min = cargar(con, cfg)
        if huella_instancia(inst) != cfg["conjunto_minimo"]["huella_instancia"]:
            log.error("la instancia leída difiere de la esperada")
            return 1
        r = optimizar(inst, t_min, cfg, directorio / f"salida_{k}.json")
        r.update(persistir(con, cfg, r))
        if r["leida"] != r["salida"]["asignaciones"]:
            log.error("la programación leída difiere de la devuelta por el núcleo")
            return 1
        log.info("huella de la salida: %s", r["huella"])
        print(json.dumps({"repeticion": k, "pid": os.getpid(), "huella": r["huella"], "id_corrida": r["id_corrida"]}))
        return 0
    except Exception as exc:  # noqa: BLE001
        log.critical("excepción no controlada: %s: %s", type(exc).__name__, exc)
        log.debug("traza de la pila:\n%s", traceback.format_exc())
        print(f"{type(exc).__name__}: {exc}", file=sys.stderr)
        return 1
    finally:
        if con is not None:
            con.close()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--repeticion", type=int)
    ap.add_argument("--bd")
    ap.add_argument("--dir")
    a = ap.parse_args()
    if a.repeticion:
        return repeticion(a.repeticion, a.bd, Path(a.dir))
    return PruebaHumo().ejecutar()


if __name__ == "__main__":
    sys.exit(main())
