import 'package:flutter/material.dart';

import 'app.dart';
import 'configuracion.dart';
import 'modelo/api/api_cliente.dart';

void main() {
  runApp(AplicacionSanFelipe(api: ApiCliente(base: urlApiPorDefecto())));
}
