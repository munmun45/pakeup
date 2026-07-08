/// Sort helpers so admin lists show the most recently added items first.
extension SortNewestFirst<T> on List<T> {
  List<T> sortedByNewest(DateTime? Function(T item) dateOf) {
    final copy = [...this];
    copy.sort((a, b) {
      final da = dateOf(a);
      final db = dateOf(b);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
    return copy;
  }
}
