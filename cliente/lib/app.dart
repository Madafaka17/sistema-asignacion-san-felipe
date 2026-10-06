import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'controladores/sesion_controlador.dart';
import 'modelo/api/api_cliente.dart';
import 'modelo/repositorios/operacion_repositorio.dart';
import 'modelo/repositorios/registros_repositorio.dart';
import 'vistas/pantallas/marco_principal.dart';
import 'vistas/pantallas/pantalla_ingreso.dart';

/// Raíz de composición del cliente (MVC):
///
/// ```text
/// Vista (widgets) ─acciones→ Controlador (ChangeNotifier) ─→ Repositorio (interfaz)
///      ↑ notifica                                              └→ ApiCliente ─HTTP→ servidor
/// ```
///
/// Las vistas solo leen el estado del controlador y le envían acciones; los
/// controladores dependen de las interfaces de los repositorios; solo
/// `ApiCliente` conoce HTTP.
class AplicacionSanFelipe extends StatelessWidget {
  const AplicacionSanFelipe({super.key, required this.api});

  final ApiCliente api;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: api),
        Provider<RepositorioVehiculos>(create: (_) => RepositorioVehiculosApi(api)),
        Provider<RepositorioConductores>(create: (_) => RepositorioConductoresApi(api)),
        Provider<RepositorioRutas>(create: (_) => RepositorioRutasApi(api)),
        Provider<RepositorioServicios>(create: (_) => RepositorioServiciosApi(api)),
        Provider<RepositorioUsuarios>(create: (_) => RepositorioUsuariosApi(api)),
        Provider<RepositorioProgramaciones>(create: (_) => RepositorioProgramacionesApi(api)),
        Provider<RepositorioIncidencias>(create: (_) => RepositorioIncidenciasApi(api)),
        Provider<RepositorioReportes>(create: (_) => RepositorioReportesApi(api)),
        Provider<RepositorioAdministracion>(create: (_) => RepositorioAdministracionApi(api)),
        ChangeNotifierProvider(create: (_) => SesionControlador(api)..iniciar()),
      ],
      child: MaterialApp(
        title: 'Transportes San Felipe · Asignación de recursos',
        debugShowCheckedModeBanner: false,
        theme: _tema(Brightness.light),
        darkTheme: _tema(Brightness.dark),
        locale: const Locale('es'),
        supportedLocales: const [Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const _Inicio(),
      ),
    );
  }

  static ThemeData _tema(Brightness brillo) => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F5C8A), brightness: brillo),
        visualDensity: VisualDensity.standard,
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      );
}

class _Inicio extends StatelessWidget {
  const _Inicio();

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<SesionControlador>();
    return switch (sesion.estado) {
      EstadoSesion.iniciando => const Scaffold(body: Center(child: CircularProgressIndicator())),
      EstadoSesion.incompatible => Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(sesion.error ?? 'Versión incompatible', key: const Key('version_incompatible'), textAlign: TextAlign.center),
            ),
          ),
        ),
      EstadoSesion.sinSesion => const PantallaIngreso(),
      EstadoSesion.autenticado => const MarcoPrincipal(),
    };
  }
}
