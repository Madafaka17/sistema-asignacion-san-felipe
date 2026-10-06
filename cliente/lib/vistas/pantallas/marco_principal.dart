import 'package:dominio/dominio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controladores/sesion_controlador.dart';
import '../modulos.dart';

/// Marco de la aplicación autenticada: muestra solo los módulos del rol
/// (HU-01) en un riel lateral (pantallas anchas) o en un menú (angostas).
class MarcoPrincipal extends StatefulWidget {
  const MarcoPrincipal({super.key});

  @override
  State<MarcoPrincipal> createState() => _MarcoPrincipalState();
}

class _MarcoPrincipalState extends State<MarcoPrincipal> {
  int _indice = 0;

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<SesionControlador>();
    final modulos = sesion.modulos;
    final usuario = sesion.usuario!;
    final indice = _indice.clamp(0, modulos.length - 1);
    final modulo = modulos[indice];
    final ancho = MediaQuery.sizeOf(context).width;
    final conRiel = ancho >= 760;

    void ir(int i) => setState(() => _indice = i);

    final contenido = KeyedSubtree(key: ValueKey(modulo), child: construirModulo(modulo));
    return Scaffold(
      appBar: AppBar(
        title: Text(modulo.etiqueta),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text('${usuario.nombreUsuario} · ${usuario.rol.etiqueta}', key: const Key('usuario_actual'), overflow: TextOverflow.ellipsis),
            ),
          ),
          IconButton(
            key: const Key('boton_salir'),
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: sesion.salir,
          ),
        ],
      ),
      drawer: conRiel
          ? null
          : NavigationDrawer(
              selectedIndex: indice,
              onDestinationSelected: (i) {
                ir(i);
                Navigator.of(context).pop();
              },
              children: [
                const SizedBox(height: 16),
                for (final m in modulos)
                  NavigationDrawerDestination(icon: Icon(iconoModulo(m)), label: Text(m.etiqueta)),
              ],
            ),
      body: conRiel
          ? Row(children: [
              NavigationRail(
                key: const Key('navegacion'),
                selectedIndex: indice,
                onDestinationSelected: ir,
                extended: ancho >= 1180,
                labelType: ancho >= 1180 ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                destinations: [
                  for (final m in modulos)
                    NavigationRailDestination(
                      icon: Icon(iconoModulo(m), key: Key('modulo_${m.name}')),
                      label: Text(m.etiqueta),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: contenido),
            ])
          : contenido,
    );
  }
}

IconData iconoModulo(Modulo m) => switch (m) {
      Modulo.vehiculos => Icons.directions_bus,
      Modulo.conductores => Icons.badge,
      Modulo.rutas => Icons.alt_route,
      Modulo.servicios => Icons.event_note,
      Modulo.incidencias => Icons.report_problem,
      Modulo.programacion => Icons.auto_awesome,
      Modulo.reportes => Icons.insights,
      Modulo.usuarios => Icons.manage_accounts,
      Modulo.parametros => Icons.tune,
      Modulo.bitacora => Icons.history,
    };
