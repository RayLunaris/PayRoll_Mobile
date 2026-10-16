# 11 — Spesifikasi Implementasi Flutter per Endpoint (Audit → Kode)

Turunan langsung `10-api-contract-matrix.md` yang sudah diverifikasi dari kode backend.
Aturan baca: tiap endpoint punya **kontrak (verified) → model Dart → repository → error map → test**. Coding agent kerjakan berurutan E01→E24; dilarang tambah endpoint di luar daftar tanpa verifikasi ulang.

Konvensi global (berlaku semua):
* Base URL = gateway `:3001`; header `Authorization: Bearer <access>` kecuali publik; respons `{success, data?, error?, message?, details?, pagination?}`.
* `Dio` + interceptor: 401 → refresh sekali (`POST /api/auth/refresh`) → retry; gagal → logout + wipe.
* Semua `GET /:id` sensitif: harapkan 403 untuk milik orang (test IDOR wajib).
* Uang sebagai `String`/`Decimal` dari JSON (backend `decimal`) — JANGAN `double` untuk total akhir (pembulatan).

## E01–E08 Auth (`auth-service/src/routes/auth.ts`)

### E01 `POST /api/auth/login` (publik, rate 10/mnt — `auth.ts:93`)
* Model: req `{email, password}`; res `{accessToken, refreshToken, user{id,email,role,employeeId?}}` (lihat `auth.ts:186-187`).
* Repo: `AuthRepository.login()` → simpan refresh ke `flutter_secure_storage`, access di memori.
* Error: 400 validasi (Zod, min 6 max 72) → tampilkan per-field; 401 kredensial salah → error umum (jangan bocorkan user ada/tidak).
* Test: AUTH-01.

### E02 `POST /api/auth/refresh` (`auth.ts:284`, TANPA Zod — temuan M2)
* Kirim `{refreshToken}` string mentah; siap 400/401 → logout paksa + wipe.
* Test: AUTH-02.

### E03 `POST /api/auth/register` (`auth.ts:200`, force `role:employee`)
* Test: happy + email duplikat 400.

### E04 `POST /api/auth/forgot-password` (`auth.ts:380`, rate 3/15m) + E05 `POST /api/auth/reset-password` (`auth.ts:452`, rate 5/15m)
* Forgot selalu respons sama (anti-enumeration) — JANGAN tampilkan "email tidak terdaftar".

### E06 `GET /api/auth/me` (`auth.ts:523`, Bearer) — sumber `role` + profil sesi.
### E07 `POST /api/auth/logout` (`auth.ts:563`, revoke) + wipe lokal (token, antrean, cache slip).
### E08 `PUT /api/auth/password` (`auth.ts:584`) — `/profile/password`; kirim `{current,new}` sesuai Zod backend (cek ulang field saat implementasi).

## E09–E14 Attendance (`attendance-service`, prefix `/api/attendance`)

### E09 `GET /api/locations` (`locations.ts:22`) — dropdown + hitung jarak client (Haversine) vs `radiusMeters||100`.
### E10 `POST /api/attendance/check-in` (`attendance.ts:107`)
* Req: `{latitude, longitude, accuracy*, locationId, photoUrl?}` (*wajib dikirim client walau opsional server).
* Sukses 201 `{id,checkIn,checkInPhotoUrl,status,location{name,distance}}`.
* Error: 400 `Low GPS accuracy` (accuracy>100) → tampilkan ±m + saran; 400 `Outside work area` (+`distance`,`radius`) → tampilkan jarak; 400 `Already checked in today` → rekonsiliasi E12; 403 non-milik; 404 lokasi/employee.
* Offline: simpan `{clientRequestId, body, deviceTime}` → `pending_sync` (JANGAN `success`).
* Race respons-hilang: retry → 400 `Already checked in` → `GET /today` ada record → `synced`. Test wajib (Patrol J2).
### E11 `POST /api/attendance/check-out` (`attendance.ts:309`)
* ⚠️ Server TIDAK cek `accuracy` (gap terdokumentasi) — client tetap kirim + pre-check ≤100 sendiri; radius vs lokasi check-in tetap divalidasi server (`:358-379`).
* Error: 400 `No check-in found` (belum check-in — disable tombol); 400 `Already checked out` → rekonsiliasi E12; sukses 200 `{id,checkIn,checkOut,overtimeHours}` (lembur otomatis >grace 15 mnt).
* Keputusan backend P0 (lihat §Backend): tambah cek akurasi identik check-in ATAU terima risiko tertulis.
### E12 `GET /api/attendance/today` (`attendance.ts:437`) — kartu Home + rekonsiliasi. Employee kirim `employeeId` → 403 (`:447-449`); kosong → `data:null` (bukan error).
### E13 `GET /api/attendance/history` (`attendance.ts:503`) — `employeeId` → 403 (`:518-520`); paginasi; kosong → `data:[]`.
### E14 `GET /api/attendance/today-summary` (`attendance.ts:947`) — ✅ AMAN untuk employee: hanya data diri (`presentCount 0/1, totalCount 1, isSelfCheckedIn`, `:966-975`). Boleh dipakai kartu Home. Manager/admin dapat scope lebih — mobile abaikan field itu.

## E15–E17 Lembur (`attendance.ts:1215-1438`)

### E15 `POST /api/attendance/overtime-requests` (`:1215`) — req `{date YYYY-MM-DD, hours, reason, employeeId?}`; non-milik 403 (`:1228-1230`); duplikat tanggal non-rejected/cancelled 400 (`:1241-1255`); 201. Validasi client 0.5–8 jam (server: cek Zod saat implementasi).
### E16 `GET /api/attendance/overtime-requests` (`:1276`) — milik sendiri.
### E17 `DELETE /api/attendance/overtime-requests/:id` (`:1438`) — ✅ kepemilikan terverifikasi: employee non-pemilik → 403 (`:1451-1455`), role manager → 403 (`:1456-1458`), non-pending → 400 (`:1460-1462`). BOLEH dipakai mobile sebagai "Batalkan" (hanya status pending). Tutup OPEN matriks.

## E18–E21 Cuti (`leave-service/src/routes/leaves.ts`)

### E18 `POST /api/leaves/` (`:135`) — `leaveType` enum 6 nilai; tanggal `YYYY-MM-DD` (`leaveSchema:6-13`); ⚠️ `reason` OPSIONAL di server — min 10 char hanya aturan client (LEA-01); non-milik 403; end<start 400; overlap pending/approved 400 + rentang; kuota habis 400 + sisa (kecuali special/unpaid, default annual 12/sick 12/maternity 90/paternity 3); 201.
### E19 `GET /api/leaves/` (`:32`) — page 1/limit 50/max 500, filter status/leaveType/tanggal; otomatis milik sendiri (employee).
### E20 `GET /api/leaves/history|/quota|/calendar|/:id` (`:246,305,395,494`) — milik sendiri; `/:id` orang → harapkan 403 (test IDOR).
### E21 `PUT /api/leaves/:id/cancel` (`:693`) — ✅ kepemilikan terverifikasi: non-pending → 400 (`:707-709`); employee non-pemilik → 403 (`:712-716`); manager dept-scoped. BOLEH dipakai mobile ("Batalkan", hanya pending).

## E22–E23 Slip (`payroll-service/src/routes/payrolls.ts`)

### E22 `GET /api/payrolls/my?month&year` (`:111`) — kosong → `data:[]` (bukan error); urut terbaru.
### E23 `GET /api/payrolls/:id` + `GET /api/payrolls/:id/slip` (`:188,:216`) — IDOR 403 non-pemilik (`:201-206,:229-234`); slip = PDF generate server (`:236-241`), simpan via share-sheet; `FLAG_SECURE` di viewer. DILARANG via `/uploads` (H3 blocker).

## E24–E25 Shift + E26 Notifikasi + E27 Upload + E28 FCM

### E24 `GET /api/shifts/current` (`shifts.ts:667`) — tanpa employee → 404; tanpa shift → `data:null`; dukung overnight.
### E25 `GET /api/shifts/calendar` (`shifts.ts:301`) — `all`/`employeeId` → 403 (`:310-312`); month/year wajib (Zod `:306`).
### E26 `GET /api/notifications/` (`notifications.ts:6`) — milik sendiri; page 1/limit 20/max 100; `unreadOnly`; + `GET /unread-count` badge, `PUT /:id/read|/read-all`.
### E27 `POST /api/uploads` (`social/src/index.ts:82`, auth) — multipart 1 file ≤10MB, ekstensi allowlist, nama UUID, 201. Hasil URL JANGAN difetch via `/uploads/*` publik untuk lampiran sensitif (tunggu H3).
### E28 `POST /api/device-tokens` 🆕 — kontrak: req `{fcmToken, platform, appVersion}` → 201; `DELETE` saat logout. Implementasi backend belum ada (satu-satunya pekerjaan backend MVP).

## Backend yang harus diubah — STATUS: selesai Langkah 1 (curl via gateway :3001 OK)

1. **B1 (P0):** ✅ `POST /api/device-tokens` (+GET/DELETE) + FCM dispatch hook — Zod android|ios, upsert 201. Catatan: curl memakai mock DB + FCM dev-fallback → verifikasi ulang vs Postgres real + kirim FCM sungguhan sebelum pilot.
2. **B2 (P0, H3):** ✅ `/uploads/*` anonim → 401; baca milik-sendiri Bearer + signed URL HMAC 5 mnt. Slip tetap `GET /:id/slip`.
3. **B3 (P0):** ✅ cek `accuracy > 100 → 400` di check-out identik check-in.
4. **B4 (P1, M2):** ✅ Zod `POST /refresh` (min 10) + `:id` UUID.

## Keputusan operasional — TERKUNCI Langkah 0 (15 Okt 2026)

* Distribusi pilot: **Play-internal** (sideload hanya smoke-test dev).
* Retensi antrean **30 hari** + wipe saat logout = YA (modal konfirmasi jika pending_sync tersisa).
* Rooted/Play Integrity: **sinyal + audit**, tanpa blokir.
