# 02 — Design Brief Mobile PayrollPro (Flutter) — Employee Only

Basis: `01-prd-mobile-flutter.md` + `09-sitemap-mobile-flutter.md`. Scope: **employee saja**, tanpa layar admin.
Stack target: Flutter 3.13+ / Dart, Material 3, `get: ^4.7.3` (sudah di `pubspec.yaml`) + tambahan yang akan dikunci di implementasi.

## 1. Design principles (3 aturan wajib)

1. **Satu tangan, satu tap untuk hal harian.** Check-in/out, ajukan cuti, lihat slip harus selesai ≤3 tap dari tab. Alasan: Sinta/Dimas (lapangan, HP 3GB, sinyal buruk) tidak boleh lewat form web 10 field.
2. **Angka gaji tidak boleh ambigu.** Nominal, periode, status (draft/processed/paid) selalu tampil bersamaan dengan format Rp yang sama dengan web. Alasan: selisih 1 digit = krisis kepercayaan payroll.
3. **State offline selalu jujur.** Setiap layar tulis tampilkan badge sync (Terkirim / Menunggu / Gagal) — jangan pura-pura sukses. Alasan: sinyal pabrik/lapangan tidak stabil, antre offline adalah fitur inti PRD.

## 2. Visual direction

* **Mood:** bank-grade tenang, bukan startup playful. Referensi: BCA mobile (rapat, angka jelas) + Grab driver-app (CTA besar untuk pekerja lapangan).
* **Hindari:** gradient mencolok, dark-mode penuh di MVP, ilustrasi kosong berlebihan, bottom-sheet bertingkat, chart 3D, tabel admin padat. Laporan kompleks tetap di web.
* **Kenapa Material 3:** tim Android-first, komponen bottom-nav/FAB/date-picker sudah aksesibel, konsisten dengan `uses-material-design: true`.

## 3. Design tokens

* **Warna:**
  * `Primary Navy #1B2A4A` — header, appbar, CTA utama. Alasan: otoritas finansial, kontras tinggi di sunlight.
  * `Primary Container #E8EDF5` — background kartu ringkasan.
  * `Success Emerald #0E7C5A` — check-in berhasil, approved, paid.
  * `Warning Amber #B7791F` — pending, di luar radius, kuota menipis.
  * `Danger Red #B3261E` — rejected, mock-location.
  * `Surface #FFFFFF`, `Background #F4F6FA`, `On-surface #1A1C1E`, `Outline #D7DCE3`.
* **Tipografi (Inter — alasan: angka tabular jelas untuk slip, lisensi SIL OFL):**
  * Display 24/32 Bold — nominal gaji di kartu slip.
  * Title 18/26 SemiBold — judul screen.
  * Body 14/20 Regular — isi, alasan cuti.
  * Label 12/16 Medium — badge status, caption GPS.
  * Mono fallback untuk NIP/ID: `RobotoMono 12`.
* **Spacing (basis 4):** 4, 8, 12, 16, 24, 32. Padding screen 16, antar-kartu 12, CTA bottom 16+safe-area.
* **Radius:** kartu 12, CTA 10, sheet 16 top-only, badge 999.
* **Shadow:** hanya 2 level — `card: 0 1 2 rgba(27,42,74,.08)` dan `fab: 0 4 12 rgba(27,42,74,.18)`. Tanpa shadow berlapis (berat di RAM 3GB).

## 4. Screen inventory (employee only, tanpa admin)

| Screen (route) | Tujuan (satu kalimat) |
|---|---|
| Splash `/` | putuskan auth vs login |
| Login/Register/Forgot/Reset | masuk + reset via email, lempar biometric |
| Home `/home` | status hari ini: absen, shift, sisa cuti, slip terakhir, status pengajuan terakhir |
| Notifikasi `/notifications` | inbox hasil approval + slip terbit |
| Absensi `/attendance` | 1-tap check-in/out + jarak meter + akurasi |
| Riwayat absensi + detail | bukti tanggal, jam, lokasi |
| Hub Pengajuan `/request` | pilih Cuti / Lembur |
| Cuti request/history/detail/kuota/kalender | ajukan + lacak + sisa |
| Lembur request/history/detail | ajukan + lacak hasil (tanpa tombol approve) |
| Slip list/detail/PDF | lihat komponen + share PDF |
| Shift `/shift` | jadwal saya hari ini + mingguan |
| Profil + password | data diri sendiri + ganti password |
| Settings app | biometric on/off, logout, versi |

## 5. User flow (journey utama, employee)

* **Check-in:** Tab Absensi → GPS auto-lock → pilih lokasi (default terdekat) → selfie (wajib, ikut web `SelfieCamera`) → tombol Check-in aktif hanya jika akurasi ≤100m & di radius → sukses (Emerald) + badge Terkirim/Menunggu.
* **Ajukan cuti:** Pengajuan → Cuti → tipe+range+alasan≥10 char → cek kuota pre-submit → lampiran kamera opsional → submit → inbox status pending → push saat manager approve/reject di web.
* **Terima hasil:** Push → deep link detail milik sendiri → lihat status + notes manager → kembali history.
* **Lihat slip:** Slip → pilih periode → detail komponen → share PDF (system share sheet).

## 6. Layout per screen

* **Home:** AppBar (nama) → kartu status absen hari ini (primary action: Check-in/Check-out) → grid 2: Sisa cuti, Shift hari ini → kartu slip terakhir + status pengajuan terakhir → list notifikasi 3 teratas.
* **Absensi:** kartu GPS (jarak meter besar 24 Bold, akurasi, nama lokasi) → dropdown lokasi → preview selfie → CTA full-width (disabled sampai valid) → info shift.
* **Cuti request:** stepper 3 (Tipe&Tanggal → Alasan&Lampiran → Konfirmasi) — hindari form 1 layar panjang.
* **Slip detail:** nominal net 24 Bold → tabel komponen (base, lembur, tunjangan, BPJS, PPh21, potongan) → status+periode chip → CTA Download/Share.
* **Notifikasi:** list inbox (ikon per tipe: approval/slip/shift) → detail + deep link balik.

## 7. Component library

* `PayrollCtaButton` — variant primary/secondary/danger; state enabled/disabled/loading (spinner di dalam, cegah double-tap check-in).
* `StatusChip` — pending/approved/rejected/paid/draft; warna dari token §3.
* `GpsStatusCard` — state locked/searching/denied/outside/low-accuracy; tampilkan jarak + akurasi.
* `SyncBadge` — Terkirim/Menunggu/Gagal + retry.
* `MoneyText` — format `Rp 1.150.000`, selalu dengan periode di bawahnya.
* `EmptyState` — ilustrasi minimal + 1 CTA (misal slip draft → "Belum tersedia").
* `ErrorBanner` — merah, dengan aksi (Buka Pengaturan / Coba lagi).

## 8. State per screen kunci

* **Absensi:** empty (belum check-in) / loading GPS shimmer / error denied-outside-low-accuracy-mock / success Emerald / offline Menunggu.
* **Cuti:** empty (belum pernah) / loading skeleton list / error kuota-habis-overlap / success toast + inbox update.
* **Slip:** empty draft / loading PDF / error download-gagal-retry / success share-sheet.
* Semua error tulis: tampilkan kode + tombol lapor (kirim log tanpa token).

## 9. Responsive behaviour

* **Mobile (360–430dp, prioritas):** bottom-nav 5, 1 kolom, CTA sticky bottom.
* **Tablet (600dp+):** list-detail (riwayat kiri, detail kanan); kalender cuti/shift 7 kolom penuh.
* **Desktop:** tidak didukung native — arahkan ke `apps/web`. Flutter web build dimatikan di MVP.

## 10. Accessibility

* Kontras teks:body ≥4.5:1 (Navy on white 12.6:1, Emerald on white 5.1:1 — lolos; Amber hanya untuk badge besar + ikon, bukan body kecil).
* Focus order: CTA utama → field → nav; semua CTA punya `semanticsLabel` (pengganti `data-testid` web yang saat ini NOL).
* Keyboard/nav: semua flow bisa Tab+Enter; date-picker native.
* Semantics: `Semantics(button, label)` untuk check-in/out; error via `liveRegion`; nominal dibaca "satu juta seratus lima puluh ribu rupiah", bukan digit.
