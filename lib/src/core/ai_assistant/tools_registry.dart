import 'package:logger/logger.dart';
import 'package:tuple/tuple.dart';

class ToolsRegistry {
  // Private constructor
  ToolsRegistry._();

  // Singleton instance
  static ToolsRegistry? _instance;

  // Factory constructor that returns the singleton instance
  factory ToolsRegistry.getInstance() {
    _instance ??= ToolsRegistry();

    return _instance!;
  }

  ToolsRegistry();

  // Private map to store functions: (description, confirm, function)
  final Map<String, Tuple3<String, bool, Function>> _functions = {};

  // Registers a function with a given name
  void registerFunction(String name, String description, Function function,
      {bool confirm = false}) {
    _functions[name] = Tuple3(description, confirm, function);
    Logger().i(
        'Function "${name}" registered with description: ${description}, confirm: ${confirm}');
  }

  List<String> getFunctionInfos() {
    var functions = _functions.entries.map((entry) {
      return '''{
"name":"${entry.key}",
"description": "${entry.value.item1}",
"confirm": ${entry.value.item2}
}''';
    }).toList();

    return functions;
  }

  bool functionExists(String name) {
    return _functions.containsKey(name);
  }

  bool requiresConfirmation(String name) {
    return _functions[name]?.item2 ?? false;
  }

  String? getDescription(String name) {
    return _functions[name]?.item1;
  }

  // Retrieves the description of a function by its name
  // Calls a function by its name with optional parameters
  Future<String> callFunction(String name, List<dynamic> params) async {
    if (_functions.containsKey(name)) {
      return await Function.apply(_functions[name]!.item3, params);
    } else {
      throw Exception('Function "${name}" is not registered.');
    }
  }
}
