class StorageInfo {
  final String category;
  final double sizeInMB;
  final String path;
  final int fileCount;
  bool isSelected;

  StorageInfo({
    required this.category,
    required this.sizeInMB,
    required this.path,
    required this.fileCount,
    this.isSelected = false,
  });

  String get sizeText {
    if (sizeInMB < 1) {
      return '${(sizeInMB * 1024).toStringAsFixed(1)} KB';
    } else if (sizeInMB > 1024) {
      return '${(sizeInMB / 1024).toStringAsFixed(2)} GB';
    }
    return '${sizeInMB.toStringAsFixed(1)} MB';
  }
}