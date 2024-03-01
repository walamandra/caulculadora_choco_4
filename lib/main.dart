import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

class Receta {
  late DateTime fecha;
  late Map<String, double> ingredientes;
  late double porcentajeCacao;

  Receta(this.fecha, this.ingredientes, this.porcentajeCacao);

  Receta.fromJson(Map<String, dynamic> json)
      : fecha = DateTime.parse(json['fecha']),
        ingredientes = Map<String, double>.from(json['ingredientes']),
        porcentajeCacao = json['porcentajeCacao'];

  Map<String, dynamic> toJson() => {
        'fecha': fecha.toIso8601String(),
        'ingredientes': ingredientes,
        'porcentajeCacao': porcentajeCacao,
      };
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Receta de Ingredientes',
      theme: ThemeData(
        primarySwatch: Colors.brown,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all<Color>(Colors.brown),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all<Color>(Colors.brown),
            foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
          ),
        ),
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<Receta> recetas = [];

  @override
  void initState() {
    super.initState();
    cargarRecetas();
  }

  void cargarRecetas() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? recetasJson = prefs.getStringList('recetas');
    if (recetasJson != null) {
      setState(() {
        recetas = recetasJson
            .map((json) => Receta.fromJson(jsonDecode(json)))
            .toList();
      });
    }
  }

  void guardarRecetas() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> recetasJson =
        recetas.map((receta) => jsonEncode(receta.toJson())).toList();
    await prefs.setStringList('recetas', recetasJson);
  }

  void ingresarDatos() async {
    Map<String, double?> nuevosIngredientes = {};
    nuevosIngredientes['licor_cacao'] = await _inputField(
        context, 'Ingrese la cantidad de licor de cacao en gramos:');
    nuevosIngredientes['mantequilla_cocoa'] = await _inputField(
        context, 'Ingrese la cantidad de mantequilla de cocoa en gramos:');
    nuevosIngredientes['leche_polvo'] = await _inputField(
        context, 'Ingrese la cantidad de leche en polvo en gramos:');
    nuevosIngredientes['azucar'] =
        await _inputField(context, 'Ingrese la cantidad de azúcar en gramos:');

    if (nuevosIngredientes.containsValue(null)) {
      return; // Si se canceló el ingreso de datos, no se agrega la receta
    }

    double totalCacao = (nuevosIngredientes['licor_cacao']! +
        nuevosIngredientes['mantequilla_cocoa']!);
    double totalIngredientes = nuevosIngredientes.values
        .where((value) => value != null)
        .map((value) => value!)
        .reduce((a, b) => a + b);
    double porcentajeCacao = (totalCacao / totalIngredientes) * 100;

    setState(() {
      recetas.insert(
          0,
          Receta(
              DateTime.now(),
              nuevosIngredientes
                  .map((key, value) => MapEntry(key, value ?? 0.0)),
              porcentajeCacao));
    });

    guardarRecetas(); // Guardar las recetas después de agregar una nueva
  }

  Future<double?> _inputField(BuildContext context, String hintText) {
    TextEditingController controller = TextEditingController();
    return showDialog<double>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(hintText),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Ingrese la cantidad',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('CANCELAR'),
              onPressed: () {
                Navigator.of(context).pop(null);
              },
            ),
            TextButton(
              child: Text('ACEPTAR'),
              onPressed: () {
                double? value = double.tryParse(controller.text);
                Navigator.of(context).pop(value);
              },
            ),
          ],
        );
      },
    );
  }

  void mostrarReceta() {
    if (recetas.isNotEmpty) {
      String receta = '';
      recetas.asMap().forEach((index, recetaItem) {
        receta += 'Receta ${index + 1}\n';
        receta += 'Fecha: ${recetaItem.fecha}\n';
        recetaItem.ingredientes.forEach((key, value) {
          receta += '$key: $value g\n';
        });
        receta +=
            'Porcentaje de cacao: ${recetaItem.porcentajeCacao.toStringAsFixed(2)}%\n\n';
      });
      _showAlertDialog('Recetas', receta);
    } else {
      _showAlertDialog('Error', 'No hay recetas guardadas.');
    }
  }

  void eliminarReceta(int index) {
    setState(() {
      recetas.removeAt(index);
    });
    _showAlertDialog('Receta eliminada', 'La receta ha sido eliminada.');
    guardarRecetas(); // Guardar las recetas después de eliminar una
  }

  void eliminarRecetas() {
    if (recetas.isNotEmpty) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Eliminar Receta'),
            content: Text('Seleccione la receta que desea eliminar:'),
            actions: <Widget>[
              ...List.generate(
                recetas.length,
                (index) => TextButton(
                  onPressed: () {
                    eliminarReceta(index);
                    Navigator.of(context).pop();
                  },
                  child: Text('Receta ${index + 1}'),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('Cancelar'),
              ),
            ],
          );
        },
      );
    } else {
      _showAlertDialog('Error', 'No hay recetas guardadas.');
    }
  }

  void anadirIngrediente() async {
    if (recetas.isNotEmpty) {
      String? ingrediente =
          await _inputIngredient(context, 'Ingrese el nombre del ingrediente:');
      if (ingrediente != null && ingrediente.isNotEmpty) {
        double? cantidad = await _inputField(
            context, 'Ingrese la cantidad de $ingrediente en gramos:');
        if (cantidad != null) {
          setState(() {
            recetas.first.ingredientes[ingrediente] = cantidad;
          });
          guardarRecetas(); // Guardar las recetas después de agregar un ingrediente
        }
      }
    } else {
      _showAlertDialog(
          'Error', 'No hay recetas a las que agregar ingredientes.');
    }
  }

  Future<String?> _inputIngredient(BuildContext context, String hintText) {
    TextEditingController controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(hintText),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              hintText: 'Ingrese el nombre',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('CANCELAR'),
              onPressed: () {
                Navigator.of(context).pop(null);
              },
            ),
            TextButton(
              child: Text('ACEPTAR'),
              onPressed: () {
                String? value =
                    controller.text.isNotEmpty ? controller.text : null;
                Navigator.of(context).pop(value);
              },
            ),
          ],
        );
      },
    );
  }

  void _showAlertDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Información'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Desarrollador: Freddy Rafael Risquez Bonillo'),
              Text('Versión: 2.0'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Calculadora de Chocolate'),
        actions: [
          IconButton(
            icon: Icon(Icons.info),
            onPressed: () {
              _showInfoDialog();
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              width: 200,
              child: ElevatedButton(
                onPressed: ingresarDatos,
                child: Text('Ingresar Datos',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
            SizedBox(
              width: 200,
              child: ElevatedButton(
                onPressed: mostrarReceta,
                child: Text('Mostrar Receta',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
            SizedBox(
              width: 200,
              child: ElevatedButton(
                onPressed: eliminarRecetas,
                child: Text('Eliminar Receta',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
            SizedBox(
              width: 200,
              child: ElevatedButton(
                onPressed: anadirIngrediente,
                child: Text('Añadir Ingrediente',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
