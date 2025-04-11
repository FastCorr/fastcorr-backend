class RecipientCache {
  final Map<String, String> _cache = {};

  String? get(String key) => _cache[key];

  void set(String key, String recipientCode) {
    _cache[key] = recipientCode;
  }

  bool contains(String key) => _cache.containsKey(key);
}
