# Cliente Flutter (MVC)

Interfaz web y de escritorio (Windows/Linux) del sistema de asignación de
recursos. La arquitectura y las instrucciones completas están en el
[README principal](../README.md) y en [docs/arquitectura.md](../docs/arquitectura.md).

```text
lib/
├── main.dart, app.dart        raíz de composición (providers)
├── configuracion.dart         URL de la API y versión del cliente
├── modelo/                    M: ApiCliente (HTTP, JWT, versión) y repositorios remotos
├── controladores/             C: ChangeNotifier por caso de uso (sin HTTP ni SQL)
└── vistas/                    V: pantallas por historia de usuario y componentes
```

```sh
flutter pub get
flutter run -d linux --dart-define=API_URL=http://localhost:8080/api   # escritorio
flutter run -d chrome                                                  # web (vía nginx en Docker)
flutter test                                                           # unitarias y de widgets
../herramientas/e2e.sh                                                 # ciclo completo contra el servidor
```
