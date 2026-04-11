int asInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

int? asIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

bool asBool(dynamic value, {bool defaultValue = false}) {
  if (value == null) return defaultValue;
  if (value is bool) return value;
  if (value is String) return value == 'true' || value == '1';
  if (value is num) return value != 0;
  return defaultValue;
}

bool? asBoolOrNull(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is String) {
    if (value == 'true' || value == '1') return true;
    if (value == 'false' || value == '0') return false;
    return null;
  }
  if (value is num) return value != 0;
  return null;
}

double asDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

double? asDoubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

Map<String, dynamic> asMap(dynamic value) {
  if (value == null) return const <String, dynamic>{};
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    try {
      return value.cast<String, dynamic>();
    } catch (e) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
  }
  return const <String, dynamic>{};
}

Map<String, dynamic>? asMapOrNull(dynamic value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    try {
      return value.cast<String, dynamic>();
    } catch (e) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
  }
  return null;
}

extension SafeConvert on dynamic {
  int get asInt {
    if (this == null) return 0;
    if (this is int) return this as int;
    if (this is num) return (this as num).toInt();
    if (this is String) return int.tryParse(this as String) ?? 0;
    return 0;
  }

  int? get asIntOrNull {
    if (this == null) return null;
    if (this is int) return this as int;
    if (this is num) return (this as num).toInt();
    if (this is String) return int.tryParse(this as String);
    return null;
  }

  double get asDouble {
    if (this == null) return 0.0;
    if (this is double) return this as double;
    if (this is num) return (this as num).toDouble();
    if (this is String) return double.tryParse(this as String) ?? 0.0;
    return 0.0;
  }

  double? get asDoubleOrNull {
    if (this == null) return null;
    if (this is double) return this as double;
    if (this is num) return (this as num).toDouble();
    if (this is String) return double.tryParse(this as String);
    return null;
  }

  Map<String, dynamic> get asMap {
    if (this == null) return const {};
    if (this is Map<String, dynamic>) return this as Map<String, dynamic>;
    if (this is Map) {
      return (this as Map).map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }

  Map<String, dynamic>? get asMapOrNull {
    if (this == null) return null;
    if (this is Map<String, dynamic>) return this as Map<String, dynamic>;
    if (this is Map) {
      return (this as Map).map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }
}
