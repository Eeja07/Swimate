# SwiMate — Aplikasi Pembantu Latihan Renang

SwiMate membantu perenang memantau performa latihan secara real-time menggunakan GPS, sensor gerak (accelerometer + gyroscope), dan model machine learning untuk mendeteksi gaya renang. README ini diperbarui untuk memberikan penjelasan mendetail mengenai arsitektur frontend (Flutter), backend (Supabase / PostgreSQL) dan pipeline machine learning (training → TFLite → inference), lengkap dengan contoh, checklist dan langkah debugging yang umum dijumpai saat ujian.

## Demo

Video demo: https://drive.google.com/file/d/1MjcQMe2_oCaYc2Xd8yo435FslvocRyuB/view?usp=sharing

## Ringkasan Fitur

- Menghitung pace (real-time) menggunakan GPS dan stopwatch
- Deteksi stroke otomatis dari sensor gerak
- Estimasi kalori berbasis jarak, durasi, dan stroke
- Analisis efisiensi renang (Stroke Rate, Stroke Length, SWOLF)
- Deteksi gaya renang (Freestyle, Backstroke, Breaststroke, Butterfly) menggunakan model ML
- Penyimpanan sesi & breakdown gaya per sesi ke Supabase (PostgreSQL)

## Arsitektur tingkat tinggi

Frontend (Flutter) ⇄ Supabase SDK (supabase_flutter) ⇄ Supabase API (HTTP) ⇄ PostgreSQL (tabel: users, activity_table, activity_segments)

- Autentikasi: Supabase Auth (JWT) — client menerima session (access + refresh token) melalui SDK.
- Database: PostgreSQL yang dikelola Supabase. Gunakan Row Level Security (RLS) untuk membatasi akses berdasarkan `auth.uid()`.
- ML: Model dilatih di folder `machine_learning/` (Keras). Hasil training diekspor ke `.h5` dan dikonversi ke `.tflite` untuk digunakan di aplikasi.

## Struktur penting di repo

- `applications/` — kode aplikasi Flutter (source utama: `applications/lib/`).
	- `applications/lib/main.dart` — entry point app (pastikan Supabase di-initialize di sini).
	- `applications/lib/pages/` — screens (signin, signup, record, history, age/height/weight, dll).
	- `applications/lib/services/` — services seperti `activity_service.dart` (query Supabase) dan `swimming_style_detector.dart` (tflite inference wrapper).
	- `applications/assets/models/` — model tflite dan (opsional) `labels.json`/`labels.npy` yang dipaket ke app.

- `machine_learning/` — skrip training, dataset, dan model hasil pelatihan (`model.h5`, `labels.npy`, `runs/`).
	- `swimate_train.py`, `swimate_train_with_unknown.py`, `swimate_train_default.py` — skrip pelatihan dengan variasi augmentasi/setting.
	- `dataset/` — CSV sumber per gaya renang.
	- `runs/` & `runs_no_aug/` — artifacts pelatihan (model.h5, tflite, labels.npy).

## Frontend (Flutter) — penjelasan lengkap

1) Inisialisasi Supabase

Sebelum kode lain yang mengakses `Supabase.instance.client`, inisialisasi Supabase harus dipanggil di `main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
	WidgetsFlutterBinding.ensureInitialized();

	await Supabase.initialize(
		url: 'https://<PROJECT_REF>.supabase.co',
		anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
	);

	runApp(const SwimScienceApp());
}
```

- Gunakan environment variables atau CI secrets (mis. `flutter build --dart-define=SUPABASE_ANON_KEY=xxx`) untuk menghindari menyimpan kunci di repo.

2) Auth flow (ringkas)

- Login email/password: `supabase.auth.signInWithPassword(email:..., password:...)`.
- OAuth (Google): dapat menggunakan `signInWithIdToken` setelah mendapatkan idToken dari Google SDK.
- SDK menyimpan session; SDK otomatis menyertakan Authorization header pada request ke API Supabase.

3) Contoh CRUD (Dart)

- Ambil semua aktivitas user (history):

```dart
final userId = Supabase.instance.client.auth.currentUser?.id;
final res = await Supabase.instance.client
	.from('activity_table')
	.select('*')
	.eq('user_id', userId)
	.order('started_at', ascending: false);

// response biasanya List<Map<String,dynamic>>
```

- Simpan activity dan segments (non-atomic example):

```dart
final insertRes = await Supabase.instance.client
	.from('activity_table')
	.insert({
		'user_id': userId,
		'started_at': DateTime.now().toIso8601String(),
		'distance_m': 0,
	})
	.select()
	.single();

final activityId = insertRes['id'];

await Supabase.instance.client.from('activity_segments').insert({
	'activity_id': activityId,
	'start_offset_seconds': 0,
	'end_offset_seconds': 30,
	'stroke_type': 'freestyle',
	'confidence': 0.92,
});
```

- Catatan: operasi multi-table di client tidak bersifat atomik — untuk atomicity buat RPC (Postgres function) di Supabase.

4) Best-practices frontend

- Debounce/throttle penulisan ke DB (mis. saat user scroll untuk mengubah `age`) — hindari terlalu banyak request.
- Tangani tipe data dengan hati-hati: API bisa mengembalikan jenis yang berbeda tergantung versi SDK (`Map` atau `PostgrestResponse`). Gunakan safe-casts.
- Pastikan nama kolom di query sesuai dengan skema DB (`user_id` vs `id_user`).

## Backend (Supabase / PostgreSQL) — penjelasan lengkap

1) Skema tabel (contoh)

- `users` / `profiles` (terdiri dari data user tambahan):
	- `id` uuid PRIMARY KEY (supabase auth UID)
	- `email` text
	- `username` text
	- `height` numeric
	- `weight` numeric
	- `created_at` timestamptz

- `activity_table`:
	- `id` uuid PRIMARY KEY
	- `user_id` uuid REFERENCES profiles(id)
	- `started_at` timestamptz
	- `ended_at` timestamptz
	- `distance_m` numeric
	- `calories` numeric
	- `strokes_count` int
	- `timestamp` timestamptz -- (opsional) record created timestamp

- `activity_segments`:
	- `id` uuid PRIMARY KEY
	- `activity_id` uuid REFERENCES activity_table(id)
	- `start_offset_seconds` numeric
	- `end_offset_seconds` numeric
	- `stroke_type` text
	- `confidence` numeric
	- `created_at` timestamptz

2) Row Level Security (RLS) dan policy

- Supabase memberikan kemampuan RLS — sangat penting untuk aplikasi yang memanggil DB langsung dari client.
- Contoh kebijakan minimal (ganti `user_id` sesuai kolom Anda):

```sql
ALTER TABLE public.activity_table ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can select own activities"
	ON public.activity_table
	FOR SELECT
	USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own activities"
	ON public.activity_table
	FOR INSERT
	WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own activities"
	ON public.activity_table
	FOR UPDATE
	USING (auth.uid() = user_id)
	WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own activities"
	ON public.activity_table
	FOR DELETE
	USING (auth.uid() = user_id);
```

- Aktifkan kebijakan serupa untuk `activity_segments` dan `profiles` (jika perlu).

3) Atomic insert (activity + segments)

- Buat fungsi PL/pgSQL (RPC) yang melakukan insert activity dan segments dalam satu transaksi, lalu panggil via `supabase.rpc('create_activity_with_segments', params)` dari client.

Contoh ringkas:

```sql
CREATE FUNCTION public.create_activity_with_segments(p_activity json, p_segments json)
RETURNS json AS $$
DECLARE new_activity_id uuid;
BEGIN
	INSERT INTO activity_table (user_id, started_at, distance_m)
	VALUES ((p_activity->>'user_id')::uuid, (p_activity->>'started_at')::timestamptz, (p_activity->>'distance_m')::numeric)
	RETURNING id INTO new_activity_id;

	INSERT INTO activity_segments (activity_id, start_offset_seconds, end_offset_seconds, stroke_type, confidence)
	SELECT new_activity_id, (s->>'start_offset_seconds')::numeric, (s->>'end_offset_seconds')::numeric, s->>'stroke_type', (s->>'confidence')::numeric
	FROM json_array_elements(p_segments) AS s;

	RETURN json_build_object('activity_id', new_activity_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

4) Security notes

- Jangan simpan `service_role` key di client. Gunakan hanya `anonKey` untuk client.
- Validasi input di DB (constraints) untuk pertahanan lapis kedua.

## Machine Learning — penjelasan lengkap

1) Data & preprocessing

- Dataset CSV ada di `machine_learning/dataset/` (file per gaya). Setiap CSV berisi kolom sensor seperti `accel_x, accel_y, accel_z, gyro_x, gyro_y, gyro_z` dan label.
- Preprocessing utama di skrip training:
	- Windowing (mis. SAMPLING_HZ=10, WINDOW_SEC=4 → window_size=40 sampel)
	- Stride (overlap)
	- Normalisasi/standardisasi (pakai mean/std dari training set — simpan stat jika perlu)
	- Augmentasi (opsional): gaussian noise, magnitude scaling, axis scaling, random dropout

2) Training

- Skrip: `swimate_train.py`, `swimate_train_with_unknown.py`, `swimate_train_default.py`.
- Model: Transformer-like architecture (MultiHeadAttention, LayerNorm, FeedForward, GlobalAvgPool). Output: softmax K-class.
- Training menyimpan `labels.npy` (urutan kelas) dan model `.h5` di folder `runs/`.

3) Evaluasi

- Confusion matrix disimpan/ditampilkan: baris = ground truth, kolom = prediksi.
- Perhatikan metrik per kelas (accuracy, precision, recall, F1) dan latency inference untuk deployment.

4) Export ke TFLite

- Konversi `.h5` → `.tflite` (contoh):

```python
import tensorflow as tf
model = tf.keras.models.load_model('swimate_model.h5')
converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()
open('swimate_model.tflite', 'wb').write(tflite_model)
```

- Pertimbangkan quantization (post-training) untuk mengurangi ukuran dan latency.

5) Integrasi ke Flutter

- Salin `swimate_model.tflite` dan `labels.npy`/`labels.json` ke `applications/assets/models/`.
- Tambahkan assets di `applications/pubspec.yaml` (pastikan path benar).
- Di runtime, `swimming_style_detector.dart` memuat model via `tflite_flutter`, menyiapkan input tensor sesuai shape, menjalankan interpreter, lalu memetakan indeks ke label.

6) Hal-hal penting untuk inference

- Sampling rate dan window size harus sama dengan setting saat training.
- Preprocessing (order channel, normalization) harus identik.
- Labels ordering harus sinkron (simpan `labels.npy` yang sama dengan model) — jika tidak, hasil label akan keliru.

## Cara cepat menjalankan & contoh perintah (fish shell)

Frontend (Flutter):

```fish
cd applications
flutter pub get
# Jalankan di device/emulator
flutter run

# Analisis kode statis
flutter analyze

# Build release (Android)
flutter build apk --release
```

Machine learning (Python):

```fish
cd machine_learning
python3 -m venv .venv
source .venv/bin/activate.fish
pip install -r requirements.txt  # jika tersedia
python swimate_train_default.py
```

Jika hasil training menghasilkan `runs/<timestamp>/swimate_model.h5` dan `.tflite`, salin `.tflite` ke `applications/assets/models/` dan tambahkan path di `applications/pubspec.yaml`.
