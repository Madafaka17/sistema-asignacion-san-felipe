# Variables que fijan el comportamiento del intérprete, de pip y de las bibliotecas numéricas.
# Uso: source scripts/entorno_determinista.sh   (lo hacen los demás scripts)
RAIZ="${RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

export PYTHONHASHSEED=0                                  # orden de hash de cadenas fijo
export PYTHONNOUSERSITE=1                                # sin paquetes del directorio del usuario
export PYTHONPYCACHEPREFIX="$RAIZ/.build/pycache"        # bytecode fuera del árbol de fuentes
unset PYTHONPATH PYTHONSTARTUP PYTHONHOME                # sin configuración residual del intérprete
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 NUMEXPR_NUM_THREADS=1   # un hilo
export TZ=UTC LC_ALL=C.UTF-8 LANG=C.UTF-8                # zona horaria y configuración regional fijas
export PIP_CONFIG_FILE=/dev/null                         # pip ignora archivos pip.conf residuales
export PIP_DISABLE_PIP_VERSION_CHECK=1 PIP_NO_INPUT=1
export PIP_CACHE_DIR="$RAIZ/.build/pip-cache"            # caché propia del proyecto (los hashes se verifican igual)
