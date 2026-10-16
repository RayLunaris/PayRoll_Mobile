# 03 — Security Audit Pre-Launch (PayrollPro + Flutter Employee-Only)

**Status:** Disetujui 15 Okt 2026 (Item `03-C1`, `03-H1–H4`, `03-M1–M4` disetujui penuh untuk perbaikan).
Scope mobile: **hanya `employee`.** Audit backend di bawah tidak berubah (tetap wajib karena APK bicara ke API yang sama). Yang berubah: tidak ada tombol approve di mobile, jadi pengujian otorisasi mobile fokus ke "milik sendiri vs milik orang", bukan "approve sebagai admin".
Audit read-only 15 Okt 2026 terhadap `C:\Users\Advan\Documents\Projects\PayRoll`. Urut severity. File:line terverifikasi. Yang bersih ditulis eksplisit.

## CRITICAL — perbaiki sebelum rilis mobile

### C1. Reset-password token di-log ke console (bocor ke log prod)
* **File:** `apps/auth-service/src/lib/mailer.ts:45-48`
* **Eksploitasi:** pembaca log dapat `resetLink` berisi raw token 32-byte → reset password korban tanpa email.
* **Fix:**
```ts
// hapus dua console.log resetLink; ganti dengan:
if (process.env.NODE_ENV !== 'production') console.log('[AUTH-SERVICE] reset link (dev only)');
```

## HIGH

### H1. `JWT_EXPIRATION` diabaikan — expiry access hardcode 15m
* **File:** `apps/auth-service/src/routes/auth.ts:150-160,333-343` vs `.env.example:12`
* **Eksploitasi:** risiko operasional (refresh storm di shift 8 jam) + window tak terkontrol.
* **Fix:** `expiresIn: process.env.JWT_EXPIRATION || '15m'`.

### H2. Satu `JWT_SECRET` dipakai semua service (blast radius)
* **File:** `apps/employee-service/src/index.ts:12-15`, `payroll-service/src/index.ts:15-18`, `attendance-service/src/index.ts:12-15`, `social-service/src/index.ts:22-25`, `api-gateway/src/index.ts:13-16`
* **Eksploitasi:** bocor 1 env → forge token ke semua service. Jangan embed secret di APK.
* **Fix:** pisahkan verify gateway vs audience per-service; rotasi env versioned.

### H3. `GET /uploads/:file` publik tanpa auth (slip/lampiran bisa ditebak)
* **File:** `apps/api-gateway/src/plugins/proxy.ts:22` (`auth:false` untuk `/uploads`) vs `apps/social-service/src/index.ts:82-84`
* **Eksploitasi:** IDOR enumerasi nama file → unduh slip/lampiran milik orang lain.
* **Fix:** `app.authenticate` + cek kepemilikan, atau signed URL expiry 5 menit untuk mobile.

### H4. Banyak route hanya `authenticate` tanpa `requireRole` + tanpa cek objek
* **File contoh:** `apps/employee-service/src/routes/employees.ts:90,144,205,475`; `departments.ts:15,43`, `positions.ts:45,67`, `leaves.ts:33`, `attendance.ts:107`
* **Eksploitasi (skenario mobile employee):** employee A tebak UUID → `GET /api/employees/:id-B`, `/api/payrolls/:id`, `/api/leaves/:id`.
* **Fix:**
```ts
preHandler: [app.authenticate, requireRole('super_admin','hr_admin')]
// atau untuk data sendiri:
if (request.user.role === 'employee' && paramId !== request.user.employeeId) return reply.status(403).send({ error: 'Forbidden' });
```

## MEDIUM

### M1. Helmet + rate-limit hanya di gateway/auth
* **File:** helmet hanya `apps/api-gateway/src/plugins/security.ts:5-17`; rate-limit `api-gateway/src/plugins/rate-limit.ts:5-18` + `auth-service/src/index.ts:34-37` (`routes/auth.ts:95-97,382-384,454-456`)
* **Fix:** tambah `@fastify/helmet` + `@fastify/rate-limit` di `payroll/attendance/leave/social/shift/employee/src/index.ts`; tutup port service dari publik.

### M2. Validasi hilang: `POST /refresh` tanpa Zod, `:id` tanpa UUID, `?force` tanpa coerce
* **File:** `apps/auth-service/src/routes/auth.ts:286,686,720,722`
* **Fix:**
```ts
const RefreshBody = z.object({ refreshToken: z.string().min(10).max(4096) });
const IdParam = z.object({ id: z.string().uuid() });
```

### M3. Cookie `Secure=false` di HTTP + refresh juga di zustand memory
* **File:** `apps/web/src/app/api/auth/session/route.ts:7-15,43-47`; `apps/web/src/stores/auth.ts:155-163`
* **Fix mobile (wajib, employee):** refresh HANYA di `flutter_secure_storage`, tidak di memory; `Secure` true di prod; pinning cert; `allowBackup=false` + `FLAG_SECURE` di slip.

### M4. CORS service longgar
* **File:** `auth-service/src/index.ts:25-28` dkk. Gateway sudah benar (`api-gateway/src/index.ts:33-45`).
* **Fix:** samakan allowlist gateway; prod https-only tanpa wildcard.

## LOW

### L1. Email PII di log + hardcoded dev path (`mailer.ts:88,10,14`) — redact + hapus path absolut.
### L2. Duplikasi `attendanceActivityRoutes` dua prefix (`attendance-service/src/index.ts:50-51`) — satu prefix saja.

## KATEGORI BERSIH (eksplisit)

* **Password hashing: BERSIH.** `bcrypt.compare` (`auth.ts:127`), `hash(...,12)` (`:212,483,601,653`).
* **Refresh anti-replay: BERSIH** (`auth.ts:295-309`).
* **Register force role employee: BERSIH** (`auth.ts:200`).
* **Forgot anti-enumeration: BERSIH.**
* **Hardcoded JWT di `apps/web/src`: BERSIH.** Hanya fallback URL + `localStorage` non-sensitif.
* **SQL injection: BERSIH** (Drizzle parameterized). **NoSQL/command: BERSIH.**

## Dependency — BELUM DIAUDIT

```
pnpm audit --prod
flutter pub outdated && flutter pub audit
```
Blokir rilis jika Critical di `fastify/jwt/bcrypt` atau `flutter_secure_storage`.

## Aturan Flutter employee-only

1. Refresh hanya di `flutter_secure_storage`; dilarang log JWT/FCM/slip bytes.
2. Semua `GET /:id` harus milik sendiri; harapkan 403 untuk milik orang (test di file 05).
3. Non-employee login → tolak pakai mobile ("Gunakan web").
4. JANGAN ubah kode backend sebelum approve tiap item.
