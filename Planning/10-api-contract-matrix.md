# 10 — API Contract Matrix (Terverifikasi dari Kode, 15 Okt 2026)

Sumber kebenaran: `apps/api-gateway/src/plugins/proxy.ts` + `apps/*/src/routes/*.ts` + `packages/db/src/schema`.
Status: ✅ = terverifikasi ada di kode; 🆕 = harus dibuat (satu-satunya); Aturan: Flutter dilarang pakai endpoint di luar tabel ini tanpa verifikasi ulang.

Base URL mobile = gateway (`http://host:3001`). Semua `/api/*` kecuali `/api/auth/*` wajib Bearer access. Format umum: sukses `{ success:true, data }`, gagal `{ success:false, error, message?, details? }` (Zod → 400 + `details`).

## Auth (`auth-service/src/routes/auth.ts`)

| Fitur mobile | Method + Path (via gateway) | Bukti | Auth | Catatan mobile |
|---|---|---|---|---|
| Login | `POST /api/auth/login` | `auth.ts:93` | publik, rate 10/mnt | body `{email,password}` → `{accessToken,refreshToken}` |
| Register | `POST /api/auth/register` | `auth.ts:200` | publik, force `role:employee` | — |
| Refresh | `POST /api/auth/refresh` | `auth.ts:284` | publik (verify signature+store) | TANPA Zod (temuan M2) — kirim `{refreshToken}` string, siap 400 |
| Forgot | `POST /api/auth/forgot-password` | `auth.ts:380` | publik, rate 3/15m | anti-enumeration |
| Reset | `POST /api/auth/reset-password` | `auth.ts:452` | publik, rate 5/15m | — |
| Me | `GET /api/auth/me` | `auth.ts:523` | Bearer | — |
| Logout | `POST /api/auth/logout` | `auth.ts:563` | Bearer (revoke) | + wipe secure storage |
| Ganti password | `PUT /api/auth/password` | `auth.ts:584` | Bearer | dipakai `/profile/password` |
| Profil employee | `GET /api/employees/me` | `employees.ts:143` | Bearer | milik sendiri |

## Attendance GPS (`attendance-service/src/routes/attendance.ts`, prefix `/api/attendance` via `proxy.ts:15`)

| Fitur | Method + Path | Bukti | Aturan server (sudah ada, jangan duplikasi asumsi) |
|---|---|---|---|
| Lokasi kerja | `GET /api/locations` + `GET /api/locations/:id` | `locations.ts:22,50` | radius per lokasi `radiusMeters \|\| 100` |
| Check-in | `POST /api/attendance/check-in` | `attendance.ts:107` | Zod (`checkInSchema:9-16`: lat/lng wajib, `accuracy` opsional number, `locationId` UUID, `employeeId` opsional); tolak non-milik 403 (`:118-120`); akurasi>100 → 400 (`:138-150`); luar radius → 400 + jarak (`:159-175`); duplikat hari ini → 400 `Already checked in today` (`:186-188`); sukses 201 `{id,checkIn,checkInPhotoUrl,status,location{name,distance}}` (`:286-298`); Zod fail → 400 + `details` |
| Check-out | `POST /api/attendance/check-out` | `attendance.ts:309` | ✅ B3 TERIMPLEMENTASI Langkah 1: cek `accuracy > 100 → 400` ditambah identik check-in (`:359-373`); tanpa check-in → 400 `No check-in found` (`:340`); sudah check-out → 400 `Already checked out` (`:344`) → rekonsiliasi via `GET /today`; sukses 200 `{id,checkIn,checkOut,overtimeHours}`; lembur otomatis >grace 15 mnt |
| Hari ini (rekonsiliasi) | `GET /api/attendance/today` | `attendance.ts:437` | employee dilarang kirim `employeeId` → 403 (`:447-449`); tanpa record employee → `{success:true,data:null}` (`:452`); sukses `{success:true,data:attendance\|null}` |
| Riwayat | `GET /api/attendance/history` | `attendance.ts:503` | employee dilarang `employeeId` → 403 (`:518-520`); paginasi `page/limit`; tanpa employee → `data:[]` |
| Report pribadi | `GET /api/attendance/report` | `attendance.ts:611` | milik sendiri (pola sama: employee tanpa `employeeId`) |
| Statistik mingguan | `GET /api/attendance/weekly-stats` | `attendance.ts:829` | opsional Home |
| Ringkasan today | `GET /api/attendance/today-summary` | `attendance.ts:947` | ✅ TERVERIFIKASI aman untuk employee: hanya data diri (`presentCount 0/1, totalCount 1, isSelfCheckedIn`, `:966-975`). Boleh dipakai kartu Home. |

Constraint DB (menjawab evaluasi §4): `unique_employee_date ON (employee_id,date)` — `schema/attendances.ts:22`, migrasi `0000:43`. Artinya 1 row/hari; check-in/out = kolom dalam row yang sama. Teknisi multi-lokasi tetap 1 row/hari.
Duplikat check-in → `400 'Already checked in today'` (`attendance.ts:186-188`; race `onConflictDoNothing` + baca ulang `:239-257`), BUKAN 409. Rekonsiliasi mobile: `GET /api/attendance/today` lalu tandai `synced` (aturan §12 PRD).

## Lembur (`attendance.ts:1215-1438` — TERJAWAB, bukan tabel misteri)

| Fitur | Method + Path | Bukti | Aturan |
|---|---|---|---|
| Ajukan | `POST /api/attendance/overtime-requests` | `:1215` | Zod; non-milik 403 (`:1228-1230`); duplikat tanggal non-rejected/cancelled → 400 (`:1241-1255`); 201 + data |
| Riwayat saya | `GET /api/attendance/overtime-requests` | `:1276` | milik sendiri |
| Approval list | `GET /api/attendance/overtime-requests/approvals` | `:1344` | WEB-ONLY (manager) |
| Approve | `PUT /api/attendance/overtime-requests/:id/approve` | `:1377` | WEB-ONLY |
| Hapus | `DELETE /api/attendance/overtime-requests/:id` | `:1438` | ✅ TERVERIFIKASI aman: employee non-pemilik → 403 (`:1451-1455`), manager → 403 (`:1456-1458`), non-pending → 400 (`:1460-1462`). BOLEH dipakai mobile ("Batalkan", pending saja). |

## Cuti (`leave-service/src/routes/leaves.ts`, prefix `/api/leaves` via `proxy.ts:16`)

| Fitur | Method + Path | Bukti | Perilaku terverifikasi |
|---|---|---|---|
| List saya | `GET /api/leaves/` | `leaves.ts:32` | paginasi `page` default 1, `limit` default 50 max 500 (`:37-57`); filter `status/leaveType/startDate/endDate`; employee otomatis milik sendiri (`:61-66`); respons `{success,data,pagination{page,limit,total,totalPages}}` |
| Ajukan | `POST /api/leaves/` | `leaves.ts:135` | non-milik → 403 (`:148-150`); end<start → 400 (`:170-172`); overlap pending/approved → 400 + rentang (`:184-189`); kuota habis → 400 + sisa (`:204-221`, kecuali special/unpaid); sukses 201 + data |
| History | `GET /api/leaves/history` | `leaves.ts:246` | IDOR-protected (komentar kode) — employee hanya milik sendiri |
| Kuota | `GET /api/leaves/quota` | `leaves.ts:305` |
| Kalender | `GET /api/leaves/calendar` | `leaves.ts:395` |
| Detail | `GET /api/leaves/:id` | `leaves.ts:494` (wajib cek milik sendiri, 403 jika bukan) |
| Batalkan | `PUT /api/leaves/:id/cancel` | `leaves.ts:693` |
| Approval | `GET /api/leaves/approvals`, `PUT /api/leaves/:id/approve` | `leaves.ts:448,536` — WEB-ONLY |

## Slip gaji (`payroll-service/src/routes/payrolls.ts`, prefix `/api/payrolls` via `proxy.ts:10`)

| Fitur | Method + Path | Bukti + perilaku terverifikasi |
|---|---|---|
| List saya | `GET /api/payrolls/my?month&year` | `payrolls.ts:111` — tanpa employee → `data:[]` (`:121-124`); filter bulan/tahun opsional; urut terbaru |
| Semua (admin) | `GET /api/payrolls/` | `payrolls.ts:142` — JANGAN dipakai mobile (HR-only 403, `:147-149`) |
| Detail | `GET /api/payrolls/:id` | `payrolls.ts:188` — IDOR: non-pemilik non-HR → 403 (`:201-206`); tidak ada → 404 |
| PDF slip | `GET /api/payrolls/:id/slip` | `payrolls.ts:216` — IDOR sama (`:229-234`); PDF digenerate server (`generatePayslip`), binary + `Content-Disposition: attachment` (`:238-241`) — INI jalur resmi mobile, bukan `/uploads` (pendukung H3 blocker) |
| Proses payroll | `POST /api/payrolls/process` | `payrolls.ts:14` — WEB-ONLY |

## Shift (`shift-service/src/routes/shifts.ts`, prefix `/api/shifts` via `proxy.ts:23`)

| Fitur | Method + Path | Bukti + perilaku terverifikasi |
|---|---|---|
| Jadwal saya | `GET /api/shifts/current` | `shifts.ts:667` — tanpa employee → 404 (`:677-679`); tanpa shift → `data:null` (`:732`); dukung overnight (`:722-730`) |
| Kalender saya | `GET /api/shifts/calendar` | `shifts.ts:301` — employee dilarang `all`/`employeeId` → 403 (`:310-312`); `month/year` wajib via Zod (`:306`); tanpa employee → `data:[]` |
| List master | `GET /api/shifts/` | `shifts.ts:105` — hanya referensi |
| Assign/swap approve | `POST /api/shifts/assign`, `PUT /api/shifts/swap/:id/approve` | `shifts.ts:225,537` — WEB-ONLY |

## Notifikasi + upload (`social-service`, via `proxy.ts:17-22`)

| Fitur | Method + Path | Bukti + perilaku terverifikasi |
|---|---|---|
| Inbox | `GET /api/notifications/` | `notifications.ts:6` — otomatis milik sendiri (`userId`, `:21`); page default 1, limit default 20 max 100 (`:17-19`); filter `unreadOnly`; `{success,data,pagination}` |
| Unread | `GET /api/notifications/unread-count` | `notifications.ts:59` — badge |
| Baca | `PUT /api/notifications/:id/read`, `PUT /api/notifications/read-all` | `notifications.ts:88,119` |
| Upload lampiran | `POST /api/uploads` | `social-service/src/index.ts:82` — auth; multipart max 10MB + 1 file (`:40-45`); tanpa file → 400 (`:87-89`); ekstensi allowlist (`:91-94`); >10MB → 400 (`:100-102`); nama UUID (`:96`); sukses 201 |
| File statik | `GET /uploads/*` | ⛔ TERBLOKIR Langkah 1 (H3 closed): anonim → 401 + pesan H3; baca milik-sendiri via `GET /api/uploads/:filename` (Bearer, 200); signed URL HMAC 5 mnt via `POST /api/uploads/signed-url` → `GET /api/uploads/signed/:filename` (tanpa Bearer, token salah → 403). Slip tetap via `GET /api/payrolls/:id/slip`. |
| FCM register | `POST /api/device-tokens` (+ `GET`, `DELETE`) | ✅ TERIMPLEMENTASI Langkah 1: `device-tokens.ts` routes (POST 201 upsert, GET list, DELETE wipe) + proxy gateway; Zod platform android|ios; curl 201/400/200 terverifikasi (mock DB — verifikasi ulang vs Postgres real sebelum pilot) |

## Yang TIDAK boleh dipakai mobile

`POST /api/payrolls/process|/process/employee`, `PUT /:id/paid`, `GET /api/payrolls/` (admin), `GET /api/leaves/approvals`, `PUT /leaves/:id/approve`, `GET|PUT overtime-requests/approvals|approve`, `POST /api/shifts/assign`, `PUT /swap/:id/approve`, `GET /api/attendance/today-summary` (kecuali terbukti milik-pribadi), `GET /api/budgets|/projects`, `POST|PUT|DELETE /api/users|departments|positions|locations|bpjs-config|tax-config|overtime-rates`, `GET /api/users`.
