import 'package:flutter_test/flutter_test.dart';

// Kendi projenizin adıyla eşleştiğinden emin olun
import 'package:mostromo_editor/main.dart';

void main() {
  testWidgets('Mostromo Başlangıç Testi', (WidgetTester tester) async {
    // 🌟 ÇÖZÜM: Zorunlu olan 'initialRoute' parametresini ekledik
    await tester.pumpWidget(const MostromoEditorApp(initialRoute: '/'));

    // Uygulamanın başarıyla derlenip derlenmediğini test etmek için
    // ilk karenin (frame) çizilmesini bekliyoruz.
    await tester.pumpAndSettle();

    // Not: Eski "Sayaç" uygulamasının test kodları (0 bul, + bas)
    // uygulamamız artık bambaşka bir boyuta geçtiği için silindi.
    // İleride kendi testlerinizi buraya yazabilirsiniz.
  });
}
