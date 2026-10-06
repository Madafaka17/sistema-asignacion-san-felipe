import 'package:dominio/dominio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controladores/operacion_controladores.dart';
import '../controladores/registros_controladores.dart';
import '../controladores/sesion_controlador.dart';
import '../modelo/repositorios/operacion_repositorio.dart';
import '../modelo/repositorios/registros_repositorio.dart';
import 'pantallas/pantalla_administracion.dart';
import 'pantallas/pantalla_conductores.dart';
import 'pantallas/pantalla_incidencias.dart';
import 'pantallas/pantalla_programacion.dart';
import 'pantallas/pantalla_reportes.dart';
import 'pantallas/pantalla_rutas.dart';
import 'pantallas/pantalla_servicios.dart';
import 'pantallas/pantalla_vehiculos.dart';

/// Crea la pantalla de cada módulo con su controlador. El controlador vive
/// mientras la pantalla está visible y carga sus datos al crearse.
Widget construirModulo(Modulo modulo) => Builder(builder: (context) {
      final escribe = context.read<SesionControlador>().puedeEscribir(modulo);
      T leer<T>() => context.read<T>();
      return switch (modulo) {
        Modulo.vehiculos => ChangeNotifierProvider(
            create: (_) => VehiculosControlador(leer<RepositorioVehiculos>())..cargar(),
            child: PantallaVehiculos(editable: escribe),
          ),
        Modulo.conductores => ChangeNotifierProvider(
            create: (_) => ConductoresControlador(leer<RepositorioConductores>())..cargar(),
            child: PantallaConductores(editable: escribe),
          ),
        Modulo.rutas => ChangeNotifierProvider(
            create: (_) => RutasControlador(leer<RepositorioRutas>(), leer<RepositorioVehiculos>())..cargar(),
            child: PantallaRutas(editable: escribe),
          ),
        Modulo.servicios => ChangeNotifierProvider(
            create: (_) => ServiciosControlador(leer<RepositorioServicios>(), leer<RepositorioRutas>())..cargar(),
            child: PantallaServicios(editable: escribe),
          ),
        Modulo.incidencias => ChangeNotifierProvider(
            create: (_) => IncidenciasControlador(leer<RepositorioIncidencias>())..cargar(),
            child: PantallaIncidencias(editable: escribe),
          ),
        Modulo.programacion => ChangeNotifierProvider(
            create: (_) => ProgramacionControlador(
              leer<RepositorioProgramaciones>(),
              leer<RepositorioVehiculos>(),
              leer<RepositorioConductores>(),
            )..cargar(),
            child: const PantallaProgramacion(),
          ),
        Modulo.reportes => ChangeNotifierProvider(
            create: (_) => ReportesControlador(leer<RepositorioReportes>()),
            child: const PantallaReportes(),
          ),
        Modulo.usuarios => ChangeNotifierProvider(
            create: (_) => UsuariosControlador(leer<RepositorioUsuarios>())..cargar(),
            child: const PantallaUsuarios(),
          ),
        Modulo.parametros => ChangeNotifierProvider(
            create: (_) => AdministracionControlador(leer<RepositorioAdministracion>())..cargarParametros(),
            child: const PantallaParametros(),
          ),
        Modulo.bitacora => ChangeNotifierProvider(
            create: (_) => AdministracionControlador(leer<RepositorioAdministracion>())..cargarBitacora(),
            child: const PantallaBitacora(),
          ),
      };
    });
