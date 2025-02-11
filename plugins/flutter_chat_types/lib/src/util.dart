String shortFileName(name) {
  if (name.length > 30) {
    final start = name.substring(0, 15);
    final end = name.substring(name.length - 15, name.length);
    return "$start...$end";
  }
  return name;
}
