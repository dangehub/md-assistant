class Action {
  final int id;
  final String name;
  final List<String> parameters;

  Action({
    required this.id,
    required this.name,
    required this.parameters,
  });

  factory Action.fromJson(Map<String, dynamic> json) {
    if (!json.containsKey('id') ||
        !json.containsKey('name') ||
        !json.containsKey('parameters')) {
      throw Exception("Action does not match the required schema.");
    }

    List<String> parameters = [];
    if (json['parameters'] is List<dynamic>) {
      parameters = (json['parameters'] as List<dynamic>)
          .map((param) => param as String)
          .toList();
    }

    return Action(
      id: json['id'] as int,
      name: json['name'] as String,
      parameters: parameters,
    );
  }
}
