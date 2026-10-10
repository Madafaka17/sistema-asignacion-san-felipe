import 'package:dominio/dominio.dart';
import 'package:flutter/foundation.dart';

import '../modelo/api/api_cliente.dart';

/// Base de los controladores (C del MVC).
///
/// Un controlador guarda el estado de una pantalla, recibe las acciones de
/// la vista y las resuelve con los repositorios del modelo. No accede a la
/// red ni a la base de datos: solo conoce las interfaces de los
/// repositorios. La vista se reconstruye cuando el controlador notifica.
abstract class ControladorBase extends ChangeNotifier {
  bool _ocupado = false;
  String? _error;
  Map<String, String> _erroresCampo = const {};
  bool _desechado = false;

  /// Hay una operación en curso: la vista desactiva los botones que la
  /// repetirían.
  bool get ocupado => _ocupado;

  /// Mensaje del último error, para mostrarlo en la pantalla.
  String? get error => _error;

  /// Errores por campo devueltos por el servidor (400/409/422), para
  /// resaltarlos en el formulario.
  Map<String, String> get erroresCampo => _erroresCampo;

  void limpiarError() {
    _error = null;
    _erroresCampo = const {};
    notificar();
  }

  /// Ejecuta [accion] marcando la pantalla como ocupada; devuelve su
  /// resultado o `null` si falló (el error queda en [error]).
  @protected
  Future<T?> ejecutar<T>(Future<T> Function() accion) async {
    if (_ocupado) return null; // evita envíos duplicados
    _ocupado = true;
    _error = null;
    _erroresCampo = const {};
    notificar();
    try {
      return await accion();
    } on ExcepcionApi catch (e) {
      _error = e.mensaje;
      _erroresCampo = e.campos;
      return null;
    } on ErrorConexion catch (e) {
      _error = e.mensaje;
      return null;
    } finally {
      _ocupado = false;
      notificar();
    }
  }

  @protected
  void notificar() {
    if (!_desechado) notifyListeners();
  }

  @override
  void dispose() {
    _desechado = true;
    super.dispose();
  }
}
