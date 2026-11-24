"""Adaptador de persistencia del prototipo (capa de lógica de negocio de la Figura 4).

Lee la configuración de conexión desde un archivo .env no versionado, se conecta a
MySQL, carga una instancia del turno en las estructuras del núcleo (core.domain) y
guarda la programación devuelta por el núcleo. El núcleo (core/) no se modifica ni
accede a la base de datos: este paquete es el único que lo hace.
"""
