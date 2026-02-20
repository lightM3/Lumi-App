# 📱 LUMI - MASTER PRD & SYSTEM ARCHITECTURE
**Version:** 1.0.0
**Project Vision:** VSCO ve Pinterest hissiyatında, estetik odaklı, yüksek görsel performanslı kişisel kürasyon ve albüm ağı. İsim, ışık ve renkten (Luminescence) ilham almıştır.
**Target Platforms:** iOS & Android (Flutter Impeller Render Engine)

---

## 1. TECH STACK & DEPENDENCIES (KULLANILACAK TEKNOLOJİLER)
Agent'lar kod yazarken SADECE aşağıdaki paketleri ve yaklaşımları kullanacaktır. Alternatif paket önermeyin.
* **Framework:** Flutter (Dart)
* **Backend / BaaS:** Supabase (`supabase_flutter`) - PostgreSQL, Auth, Storage.
* **State Management:** Riverpod (`flutter_riverpod`, `riverpod_annotation`). StateNotifier kullanılmayacak, modern `Notifier` ve `AsyncNotifier` (Riverpod 2.x+) kullanılacak.
* **Routing:** GoRouter (`go_router`) - Type-safe routing tercih edilecek.
* **Image Caching & Layout:** `cached_network_image`, `flutter_staggered_grid_view` (Masonry/Pinterest tarzı akış için).
* **Core Utilities:**
  * Resim Seçimi: `image_picker`
  * Resim Sıkıştırma (Zorunlu): `flutter_image_compress`
  * Renk Çıkarma: `palette_generator` (Lumi'nin kalbi olan dinamik arka planlar için)
  * İkonlar: `lucide_icons` veya `cupertino_icons` (Estetik minimalizm için).

---

## 2. DATABASE SCHEMA (SUPABASE POSTGRESQL)
Projenin ilişkisel veritabanı şeması aşağıdaki gibidir. Tüm veriler bu yapıya göre Modellenecektir (Dart Data Classes / Freezed).

### Table: `users`
* `id` (uuid, primary key, references auth.users)
* `username` (text, unique, not null)
* `avatar_url` (text, nullable)
* `created_at` (timestamp, default now())

### Table: `collections` (Albümler/Kürasyonlar)
* `id` (uuid, primary key, default uuid_generate_v4())
* `user_id` (uuid, foreign key -> users.id)
* `title` (text, not null)
* `description` (text, nullable) - Estetik notlar için.
* `dominant_color` (text, nullable) - Hex code (örn: #FF5733). Dinamik UI rengi için.
* `is_public` (boolean, default true)
* `created_at` (timestamp, default now())

### Table: `photos` (Koleksiyonun İçindeki Resimler)
* `id` (uuid, primary key)
* `collection_id` (uuid, foreign key -> collections.id, on delete cascade)
* `storage_path` (text, not null) - Supabase Storage'daki konumu.
* `image_url` (text, not null) - Public/Signed URL.
* `aspect_ratio` (numeric, not null) - Masonry grid'de UI atlamalarını (layout shift) önlemek için zorunlu!
* `sort_order` (integer, default 0)

### Table: `likes` (Estetik Puanlama)
* `id` (uuid, primary key)
* `collection_id` (uuid, foreign key -> collections.id)
* `user_id` (uuid, foreign key -> users.id)
* `created_at` (timestamp)
*(Unique constraint: user_id + collection_id)*

---

## 3. FOLDER STRUCTURE (MİMARİ)
Klasör yapısı katı bir şekilde Feature-First ve Clean Architecture kurallarına uyacaktır:

lib/
├── core/
│   ├── constants/       # AppColors, AppTextStyles, SupabaseConfig
│   ├── routing/         # app_router.dart (GoRouter)
│   ├── theme/           # app_theme.dart (Özel minimal tema, Glassmorphism helpers)
│   ├── utils/           # image_utils.dart (Compress & Palette extraction)
│   └── error/           # custom_exceptions.dart
├── features/
│   ├── auth/
│   │   ├── domain/      # AuthRepository interface
│   │   ├── data/        # SupabaseAuthRepository impl
│   │   └── presentation/# Ekranlar ve Riverpod controller'ları
│   ├── curation/        # Yeni albüm oluşturma akışı
│   ├── feed/            # Ana sayfa (Masonry Keşfet)
│   └── profile/         # Kullanıcı profili
├── shared/              # Ortak Widgetlar (GlassCard, CustomNetworkImage)
└── main.dart            # Supabase init & ProviderScope

---

## 4. SCREEN-BY-SCREEN SPECIFICATIONS (EKRAN VE İŞ MANTIKLARI)

### 4.1. Auth Flow (Giriş Ekranı)
* **UI/UX:** Arka planda yavaşça hareket eden (breathing) estetik bir resim veya gradient. Üzerinde blur (Glassmorphism) efektli bir form.
* **Logic:** Supabase Apple Login ve Google Login entegrasyonu. Giriş sonrası `users` tablosunda kullanıcı yoksa oluştur.

### 4.2. Curation Flow (Koleksiyon Oluşturma - Core Feature)
* **UI/UX:** Minimalist, dikkat dağıtmayan ekran.
* **Step-by-Step Logic:**
  1. Kullanıcı galeriden fotoğraf(lar) seçer (`image_picker`).
  2. **KRİTİK ADIM:** Seçilen resim UI thread'ini bloklamadan (Isolate kullanılarak veya async) `flutter_image_compress` ile sıkıştırılır.
  3. Resmin `aspect_ratio` (en-boy oranı) hesaplanır.
  4. `palette_generator` ile resimden `dominantColor` çıkartılır. Ekranın arka planı dinamik olarak bu renge yumuşak bir animasyonla geçer.
  5. Kullanıcı başlık ve not girer.
  6. Resim Supabase Storage'a yüklenir.
  7. Dönen URL ve diğer veriler `collections` ve `photos` tablolarına yazılır.

### 4.3. Feed / Discover (Ana Sayfa)
* **UI/UX:** Pinterest veya VSCO benzeri, kenar boşlukları (padding) çok iyi ayarlanmış Masonry Grid (`flutter_staggered_grid_view`).
* **Logic:** `is_public=true` olan koleksiyonlar çekilir.
* **Performans:** * Sayfalama (Pagination) zorunludur.
  * Resimler `cached_network_image` ile gösterilmeli, bellek taşmasını önlemek için `memCacheWidth` / `memCacheHeight` değerleri cihaz çözünürlüğüne göre optimize edilmelidir.

### 4.4. Profile (Profil Ekranı)
* **UI/UX:** Üstte profil fotoğrafı, kullanıcı adı ve istatistikler. Altta kullanıcının kendi koleksiyonlarının Grid görünümü.
* **Logic:** Mevcut kullanıcının ID'sine göre Supabase sorgusu atılır.

---

## 5. AI AGENT CODING GUARDRAILS (YAPAY ZEKA İÇİN KATI KURALLAR)
1. **Never Block UI:** Ağır işlemler sırasında ekranda her zaman estetik bir loading indicator gösterilecek.
2. **Error Handling:** Hiçbir `try-catch` bloğu boş bırakılmayacak. Hatalar kullanıcıya estetik bir Snackbar ile gösterilecek.
3. **No Dummy Code:** "Buraya kendi mantığınızı ekleyin" şeklinde yorum satırları bırakmayın. Sınıfları ve API çağrılarını üretim kalitesinde yazın.
4. **UI Components:** Standart Android Material butonları kullanmayın. Her şey projenin `theme` dosyasına uygun, minimal ve `shared` klasöründeki özel widget'lar ile inşa edilecek.