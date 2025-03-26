# Rehber Yedekleme Uygulaması

Bu uygulama, telefonunuzdaki rehberinizi çeşitli formatlarda yedeklemenizi ve geri yüklemenizi sağlar. Hem iOS hem de Android platformlarında çalışır.

## Özellikler

- Rehberi çeşitli formatlarda dışa aktarma:
  - vCard (.vcf)
  - CSV (.csv)
  - Excel (.xlsx)
  - PDF (.pdf)
  - JSON (.json)
  
- Dışa aktarma seçenekleri:
  - Telefona kaydetme
  - Paylaşma
  - E-posta ile gönderme
  - Google Drive'a yükleme
  - Dropbox'a yükleme
  
- vCard formatındaki yedekleri doğrudan rehbere aktarma
- Telefon, SIM kart ve hesaplardaki tüm kişileri tek bir yedek dosyasında toplama
- Modern ve kullanıcı dostu arayüz

## Gereksinimler

- Flutter SDK 3.3.0 veya üzeri
- Android Studio / Xcode 
- Android SDK API 21+
- iOS 12+

## Kurulum

1. Projeyi klonlayın:
```
git clone https://github.com/kullaniciadi/rehber_yedek_f25.git
```

2. Bağımlılıkları yükleyin:
```
flutter pub get
```

3. Uygulamayı çalıştırın:
```
flutter run
```

## Kullanım

1. Uygulamayı açın ve gerekli izinleri verin.
2. "Rehberi Yedekle" seçeneğine tıklayın.
3. İstediğiniz yedekleme formatını seçin.
4. Yedekleme yöntemini seçin (kaydetme, paylaşma, vb.).
5. İşlem tamamlandığında bildirim alacaksınız.

## Katkıda Bulunma

1. Bu repository'yi fork edin
2. Özellik dalı oluşturun (`git checkout -b yeni-ozellik`)
3. Değişikliklerinizi commit edin (`git commit -m 'Yeni özellik eklendi'`)
4. Dalınıza push edin (`git push origin yeni-ozellik`)
5. Pull Request oluşturun

## Lisans

Bu proje MIT Lisansı altında lisanslanmıştır. Detaylar için [LICENSE](LICENSE) dosyasına bakınız.
