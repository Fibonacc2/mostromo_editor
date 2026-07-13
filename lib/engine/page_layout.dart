// lib/engine/page_layout.dart

class PageLayout {
  final bool isPageMode;
  final double a4Width;
  final double a4Height;
  final double pageGap;
  final double marginTop;
  final double marginBottom;
  final double marginLeft;
  final double marginRight;
  final List<double> pageBreaks;
  final double logicalHeight;

  PageLayout({
    required this.isPageMode,
    required this.a4Width,
    required this.a4Height,
    required this.pageGap,
    required this.marginTop,
    required this.marginBottom,
    required this.marginLeft,
    required this.marginRight,
    required this.pageBreaks,
    required this.logicalHeight,
  });

  int get totalPages => isPageMode ? pageBreaks.length : 1;

  double get physicalHeight {
    if (!isPageMode) return logicalHeight;
    return (totalPages * a4Height) + ((totalPages - 1) * pageGap);
  }

  double physicalToLogicalY(double physicalY) {
    if (!isPageMode) return physicalY - 32.0;

    int pageIndex = (physicalY / (a4Height + pageGap)).floor();
    if (pageIndex < 0) pageIndex = 0;
    if (pageIndex >= pageBreaks.length) pageIndex = pageBreaks.length - 1;

    double localY = physicalY - (pageIndex * (a4Height + pageGap));
    double offsetInPrintable = localY - marginTop;

    double maxContentOnPage =
        ((pageIndex + 1 < pageBreaks.length)
            ? pageBreaks[pageIndex + 1]
            : logicalHeight) -
        pageBreaks[pageIndex];

    // Üst kenar boşluğuna tıklanırsa, sayfanın en başına sabitle
    if (offsetInPrintable < 0) offsetInPrintable = 0;

    // Alt kenar boşluğuna tıklanırsa, o sayfadaki en son satıra sabitle
    if (offsetInPrintable > maxContentOnPage) {
      offsetInPrintable = maxContentOnPage;
    }

    return pageBreaks[pageIndex] + offsetInPrintable;
  }
}
