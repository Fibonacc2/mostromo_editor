class PageLayout {
  final bool isPageMode;
  final double a4Width;
  final double a4Height;
  final double pageGap;
  final double marginTop;
  final double marginBottom;
  final double marginLeft;
  final double marginRight;
  final int totalPages;
  final double physicalHeight;

  PageLayout({
    required this.isPageMode,
    required this.a4Width,
    required this.a4Height,
    required this.pageGap,
    required this.marginTop,
    required this.marginBottom,
    required this.marginLeft,
    required this.marginRight,
    required this.totalPages,
    required this.physicalHeight,
  });
}
