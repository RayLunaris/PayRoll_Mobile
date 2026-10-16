# 01 — PRD Mobile PayrollPro (Flutter)

**Ide produk:** Versi mobile Flutter dari PayrollPro web — khusus `employee` (user) untuk self-service harian. Admin/manager tetap penuh di web. Backend reuse `api-gateway:3001` + services yang ada, tanpa ubah skema gaji.
**Status:** Revisi employee-only. Lihat sitemap di `09-sitemap-mobile-flutter.md`.
**Keputusan terkunci:** target `employee` saja; admin web-only; MVP = absensi GPS, cuti, lembur, slip gaji, shift, notifikasi masuk; min Android 8.0 (API 26); testing Flutter (`flutter test` + Patrol, bukan Playwright); push FCM + offline antre + anti-fake-GPS ikut.

## 1. Problem statement

* **Employee dirugikan:** absensi GPS, pengajuan cuti/lembur, lihat slip gaji & shift hari ini hanya bisa via browser (`apps/web`, Leaflet + Next.js). Di lapangan (HP Android) tidak praktis, tidak ada push hasil approval, tidak bisa offline antre.
* Kenapa: semua flow kritis harian bersifat mobile-native (GPS, kamera lampiran, push), tapi produk saat ini web-only. Approval oleh manager tetap di web (tidak masuk mobile).

## 2. Target user + 2 persona

Target: `employee` saja. `hr_admin`/`manager`/`super_admin` tetap di web.

* **Persona 1 — Sinta, Staff Produksi (employee):** shift pagi, HP Android 9 RAM 3GB, sinyal pabrik tidak stabil. Butuh 1-tap check-in GPS, lihat sisa cuti, download slip.
* **Persona 2 — Dimas, Teknisi Lapangan (employee):** pindah 2-3 lokasi kerja sehari, HP Android 10. Butuh check-in multi-lokasi, ajukan lembur dari HP, terima push hasil approval tanpa telepon HRD.

## 3. Goals dan non-goals

**Goals (MVP done = berjalan selancar web):**
* Login JWT + biometric, session refresh tanpa login ulang.
* Check-in/out GPS valid radius 100m sesuai `work_locations`, tercatat di `attendances` sama seperti web.
* Request cuti/lembur dari HP, status sinkron dengan web; hasil approval diterima via push + inbox.
* Slip gaji pribadi tampil + download PDF, angka sama dengan `payrolls`.
* Jadwal shift pribadi tampil benar dari `shifts`/`employee_shifts`.
* Push untuk hasil approval, slip terbit, dan pengingat check-out.

**Non-goals (tetap web-only di MVP):**
* Seluruh alur admin/manager: `leave/approvals`, `overtime/approvals`, `admin/today`, `payroll/process`, `payroll/bpjs`, `payroll/tax`, `admin/budgets`, `admin/projects`, `settings/*`, `employees/add/edit`, `reports/*` export, `attendance/abuse` investigasi penuh.

## 4. User stories

* Sebagai employee, saya ingin check-in/out 1-tap dengan GPS supaya tercatat tanpa buka laptop.
* Sebagai employee, saya ingin ajukan cuti + lampiran foto supaya tidak perlu ke HRD.
* Sebagai employee, saya ingin ajukan lembur supaya tercatat untuk payroll.
* Sebagai employee, saya ingin lihat slip gaji & download PDF supaya bisa arsip.
* Sebagai employee, saya ingin lihat shift & kuota cuti saya supaya bisa planning.
* Sebagai employee, saya ingin terima push hasil approval supaya tahu cuti/lembur disetujui atau ditolak.
* Sebagai user, saya ingin login biometric supaya cepat dan aman.

## 5. Daftar fitur MVP / v2 / nanti

* **MVP:** Auth+biometric, Dashboard ringkas, Attendance GPS, Leave (request/history/quota/calendar), Overtime (request/history), Payslip view+download, Shift saya, Notifikasi masuk (push FCM + inbox), Profil.
* **V2:** Social lite (feed+announcements read-only), Laporan ringkas pribadi read-only, `cash_advances` request.
* **Nanti:** Budgeting read-only pribadi (bukan admin), forum/DM, geofencing auto-reminder, multibahasa.
* **Tetap web (bukan mobile):** semua approval manager/HR.

## 6. Functional requirement detail (MVP)

1. **Auth:** `POST /api/auth/login|refresh|logout` reuse. Refresh di `flutter_secure_storage`. Biometric unlock local. Auto-refresh saat 401 sekali, gagal → login.
2. **Attendance GPS:** hitung jarak ke `work_locations` client-side + validasi final server (reuse `attendance-service`). Tolak jika > radius / mock-location (Android). Antre offline (Drift/SQLite) lalu sync. Unik `attendances(employee_id,date)`.
3. **Leave:** tipe annual/sick/maternity/paternity/special/unpaid, start/end, reason, attachment kamera; `history`, `quota` (`leave_quotas`), `calendar`. Validasi kuota client + server.
4. **Overtime:** request (tanggal, jam, alasan), history, status pending/approved/rejected (read-only hasil, tanpa tombol approve di mobile).
5. **Payslip:** list per periode dari `payrolls`, detail komponen (base, overtime, allowances, bpjs, tax, net), download/share via `slip_url`.
6. **Shift:** jadwal hari ini + mingguan dari `employee_shifts` join `shifts`.
7. **Notifikasi masuk:** FCM token ke `device_tokens`, inbox dari `notifications`, tap → deep link milik sendiri (`payrollpro://leave/history/:id`, `payrollpro://payslip/:period`). Tidak ada antre approval di mobile.
8. **Dashboard:** ringkasan hari ini (status absen, shift, sisa cuti, slip terakhir, status pengajuan terakhir). Read-only dari endpoint dashboard gateway.

## 7. Sketsa data model (reuse + 1 baru)

* `users(id,email,role,employee_id)` — auth (mobile hanya role `employee`).
* `employees(id,user_id,nip,full_name,department_id,position_id,location_id)` — profil.
* `work_locations(id,lat,lng,radius_meters)` — validasi GPS.
* `attendances(id,employee_id,date,check_in/out,lat/lng,status)` — unique(employee_id,date).
* `leaves(id,employee_id,type,start/end,reason,attachment_url,status,approved_by)` + `leave_quotas(employee_id,type,year,total,used)`.
* `payrolls(id,employee_id,period_month/year,base,overtime,allowances,bpjs,tax,net,status,slip_url)`.
* `shifts(id,name,start/end)` + `employee_shifts(employee_id,shift_id,date)`.
* `notifications(id,user_id,title,message,type,reference_id,is_read)`.
* **Baru:** `device_tokens(id,user_id,fcm_token,platform,last_seen)` — satu-satunya migrasi wajib MVP (untuk push hasil ke employee).

## 8. Edge case dan failure state

* GPS mati / permission ditolak → blokir check-in + CTA ke settings.
* Di luar radius → tolak + tampilkan jarak + lokasi terdekat.
* Mock location → tolak + catat `abuse_logs`.
* Offline → antre lokal, badge "pending sync", retry eksponensial; konflik → tampilkan resolusi.
* 401 → refresh sekali, gagal → logout + hapus secure storage.
* Kuota habis / overlap → tolak pre-submit + sisa kuota.
* Slip draft/belum terbit → empty state, bukan error.
* FCM denied → fallback inbox polling.
* Double-tap check-in → idempotent key (employee_id,date,tipe).
* Buka deep link milik orang lain → 403 + redirect inbox.

## 9. Success metrics

* 95% check-in/out <10 detik di 3G.
* 0 selisih slip mobile vs web (sampling 50).
* Push hasil approval diterima <5 menit setelah manager approve di web.
* Crash-free ≥99.5%, ANR <0.5%.
* Biometric adoption ≥70% WAU.

## 10. Open questions & Keputusan Terkunci (update 15 Okt 2026)

1. ~~Path exact auth ikut web 100% atau perlu `/api/v1` mobile?~~ TERJAWAB: ikut web 100% via gateway (`proxy.ts:4-26`), tanpa `/api/v1`. Lihat file `10-api-contract-matrix.md`.
2. ~~Tabel request lembur ikut kontrak web yang mana?~~ TERJAWAB: `overtime_requests` via `/api/attendance/overtime-requests*` (`attendance.ts:1215,1276,1344,1377,1438`).
3. ~~Rilis awal: Play Store internal atau APK sideload pilot?~~ TERKUNCI: **Play-internal** (Google Play Internal App Sharing / Closed Testing track) untuk distribusi pilot resmi, menjamin verifikasi Play Integrity token dan pembaruan OTA mulus bagi karyawan (sideload APK diizinkan terbatas untuk internal dev/smoke-test).
4. ~~V2 social/laporan: read-only pribadi atau interaksi terbatas?~~ TERKUNCI: **Read-only pribadi** untuk feed/announcements & slip/laporan.
5. ~~Kebijakan perangkat rooted + Play Integrity: sinyal saja atau blokir check-in?~~ TERKUNCI: **Sinyal saja + audit logging (`abuse_logs`)**, tidak auto-blokir kehadiran demi mencegah false positive pada smartphone lama/murah Android 8–10 (Persona Sinta & Dimas).
6. ~~Retensi antrean offline lokal (misal 30 hari) + hapus saat logout: setuju?~~ TERKUNCI: **Setuju (30 hari retensi antrean lokal + Wipe saat logout = YA)**. Transaksi lokal pending/gagal disimpan maks 30 hari; logout manual/expired menghapus antrean, cache slip, dan tokens di `flutter_secure_storage` (disertai dialog konfirmasi jika masih ada antrean `pending_sync`).
7. ~~Cek akurasi GPS check-out (B3 Backend P0): tambah atau tolak-tertulis?~~ TERKUNCI: **Tambah cek akurasi di backend (`POST /api/attendance/check-out`)** identik dengan check-in (`accuracy > 100 → 400 Low GPS accuracy`) untuk menutup celah server secara konsisten.

## 11. API Contract & Backend Compatibility

* Seluruh endpoint mobile wajib merujuk `10-api-contract-matrix.md` (terverifikasi dari kode, bukan tebakan).
* Tidak ada endpoint baru di MVP kecuali `POST /api/device-tokens` (FCM) — itu satu-satunya tambahan.
* Aturan umum: base URL = gateway (`http://host:3001`), semua `/api/*` kecuali `/api/auth/*` wajib `Authorization: Bearer <access>`. Gateway teruskan identitas via `x-user-id/x-employee-id/x-user-role` (`proxy.ts:42-48`), timeout downstream 10 detik + retry 2x khusus ECONNREFUSED (`proxy.ts:52-96`), gagal → `502 BadGateway` JSON.
* Response sukses backend: `{ success: true, data }`; gagal: `{ success: false, error, message?, details? }` (Zod fail → `400 Validasi gagal` + `details`). Flutter wajib parse pola ini, bukan pola tebakan.
* Upload lampiran: via `POST /api/uploads` (auth:true, `proxy.ts:21`) multipart passthrough (`proxy.ts:63-69`); unduh file publik `/uploads/*` (auth:false, `proxy.ts:22`).
* ⛔ RELEASE BLOCKER (H3): mobile DILARANG mengambil slip/lampiran sensitif lewat `GET /uploads/*` publik. Jalur resmi: `GET /api/payrolls/:id/slip` (auth, binary passthrough `proxy.ts:77-81`) untuk slip; lampiran cuti via `POST /api/uploads` terotorisasi + baca balik terotorisasi. Jika butuh signed URL expiry pendek, catat sebagai pengecualian eksplisit terhadap "tanpa endpoint baru" — disetujui dulu sebelum coding.
* Tidak ada perubahan perhitungan payroll/skema gaji di scope ini.

## 12. Data Integrity & Offline Synchronization

* Setiap transaksi tulis offline punya UUID lokal (`clientRequestId`, UUID v4). Backend saat ini TIDAK mendukung header `Idempotency-Key` — deduplikasi mengandalkan aturan bisnis server. Karena itu `clientRequestId` dipakai untuk rekonsiliasi sisi client (cocokkan retry dengan hasil `GET` ulang), bukan validasi server.
* Retry check-in: sukses pertama = `201`. Retry setelah sukses = `400 'Already checked in today'` (`attendance.ts:186-188`; race path `:253-254`), BUKAN 409. Aturan rekonsiliasi: jika retry mengembalikan `400 Already checked in today`, Flutter WAJIB `GET /api/attendance/today`; jika record ada dengan `checkIn` terisi → tandai `synced` (bukan `failed`). Hanya tandai `failed` jika `GET` ulang tidak menemukan record.
* Untuk lembur, server sudah cegah duplikat per tanggal non-rejected/cancelled → `400` (`attendance.ts:1241-1255`); rekonsiliasi sama via `GET` ulang.
* Status lokal: `pending_sync → syncing → synced | failed`. Check-in offline TIDAK BOLEH tampil `success` — hanya `pending_sync` sampai server 2xx atau rekonsiliasi `GET` membuktikan record ada.
* Waktu resmi = waktu server (`created_at` balasan). Waktu perangkat dicatat terpisah sebagai `deviceTime` untuk audit; selisih >5 menit → flag risiko, bukan auto-tolak (hindari false positive).
* Check-in + check-out = SATU row per (employee,date) — sesuai `unique_employee_date` (`schema/attendances.ts:22`, migrasi `0000:43`). Multi-lokasi teknisi = pindah `locationId` tetap 1 row/hari; revisi salah input = koreksi via HRD web, bukan insert row baru.
* Sinkronisasi setelah ganti tanggal: tetap kirim dengan `date` asal (tanggal kejadian), bukan tanggal sync. Jika server menolak (misal periode terkunci) → status `failed` + tampilkan alasan + CTA "Ajukan koreksi ke HRD".
* Logout menghapus antrean + token + cache slip (kecuali PDF yang sudah di-share ke luar app — di luar kendali). Retensi default antrean gagal 30 hari **[OPEN]**.

## 13. Security & Privacy

* Token hanya di `flutter_secure_storage`; access di memori; biometric = gate lokal, bukan auth server.
* Server menegakkan (terverifikasi): nilai `accuracy` > 100 DITOLAK `400 Low GPS accuracy` (`attendance.ts:138-150`). Arti: `accuracy` = estimasi radius ketidakpastian posisi dalam METER (makin KECIL makin presisi; `±Xm` di pesan error `:147`); ambang = 100 m. `accuracy` bersifat opsional di schema (`checkInSchema:12`, `checkOutSchema:21`) — jika tidak dikirim, cek ini lolos (celah terdokumentasi; client WAJIB selalu kirim). Di luar radius → `400 Outside work area` + jarak (`:159-175`). Check-in untuk orang lain → 403 (`:118-120`); lembur orang lain → 403 (`:1228-1230`).
* Mock-location/root/Play Integrity = sinyal risiko + tulis `abuse_logs`, BUKAN vonis tunggal. False positive (GPS indoor jelek) harus dapat jalur koreksi manual.
* Employee hanya akses milik sendiri; `GET /:id` milik orang harus 403 (test IDOR di file 05). Lampiran/slip wajib akses terotorisasi (lihat H3).
* Dilarang log JWT, FCM token, koordinat presisi penuh, atau bytes PDF.

## 14. Acceptance Criteria (penguji: `flutter test` + Patrol)

| ID | Kriteria |
|----|----------|
| AUTH-01 | Login valid → token tersimpan secure, masuk `/home`; invalid → error tanpa bocor info user. |
| AUTH-02 | Access expired (401) → refresh sekali dan retry sukses; refresh mati → logout + wipe. |
| ATT-01 | Lokasi valid + online → 201 + konfirmasi server tampil (bukan optimis). |
| ATT-02 | Di luar radius → 400 server + tampilkan jarak; validasi client tidak cukup. |
| ATT-03 | Offline → status `pending_sync`, bukan `success`; terkirim setelah online. |
| ATT-04 | Retry setelah sukses → `400 Already checked in today`, lalu `GET /today` membuktikan record ada → tandai `synced` (rekonsiliasi, bukan `failed`/duplikat). |
| ATT-05 | Ditolak saat sync → tampilkan alasan + CTA koreksi HRD. |
| ATT-06 | `accuracy` > 100 (meter) → `400 Low GPS accuracy`; tanpa `accuracy` → lolos cek (celah diketahui, client wajib kirim). |
| LEA-01 | End<start / reason<10 char ditolak pre-submit; kuota habis ditolak dengan sisa tampil. |
| LEA-02 | Submit valid → pending di history + kalender; hasil approve via push+inbox (SLA online <5 mnt, offline via sync inbox — lihat §15). |
| OT-01 | Hours di luar 0.5–8 ditolak; duplikat tanggal non-rejected ditolak 400 dengan pesan tanggal. |
| PAY-01 | Seluruh komponen + total + pembulatan sama dengan web untuk periode sama (sampling). |
| PAY-02 | Slip draft → empty state, bukan error/crash; download gagal → retry. |
| SHF-01 | Jadwal hari ini + mingguan sama dengan `GET /api/shifts/calendar|current` milik sendiri. |
| NOT-01 | Tap push hasil → deep link detail milik sendiri; FCM mati → inbox polling tetap benar. |
| NOT-02 | Deep link milik orang → 403 + redirect inbox, tanpa bocor data. |

## 15. Definisi Pengukuran Metrik (agar tidak ambigu)

* Check-in <10 detik: minimal 95% dari 50 sampel tap-CTA-sampai-2xx selesai <10 detik, di Android RAM 3GB + 3G (selaras §9; bukan median).
* 0 selisih slip: bandingkan per komponen + total + periode + pembulatan vs `GET /api/payrolls/my` + web, 50 periode.
* Push hasil: SLA ONLINE (foreground/background/killed tapi konek) <5 menit dari `PUT approve` sampai tampil; OFFLINE tidak masuk SLA push — diukur terpisah sebagai sinkronisasi inbox setelah online kembali (<2 menit dari konek sampai inbox benar). FCM bukan jaminan — inbox adalah sumber kebenaran.
* Crash-free ≥99.5%: berbasis sesi (Crashlytics), ANR <0.5%.
