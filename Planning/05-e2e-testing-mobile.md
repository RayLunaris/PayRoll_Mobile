# 05 — E2E Testing Mobile (Flutter, Employee Only) + Web (Playwright tetap)

Keputusan: **Playwright tetap untuk `apps/web` (termasuk approval admin), TIDAK untuk Flutter.** Mobile employee pakai `flutter test` (unit/widget) + `patrol` / `integration_test` (e2e device). Alasan: Playwright tidak bisa drive APK/IPA, GPS native, kamera, FCM, secure-storage.

## 1. Setup

```yaml
# pubspec (tambah sekali)
dev_dependencies:
  flutter_test:
    sdk: flutter
  patrol: ^3.0.0
  mocktail: ^1.0.0
```

```bash
flutter test                          # unit + widget
flutter test integration_test         # e2e ringan (emulator)
patrol test                           # e2e device (GPS, kamera stub, permission)
```

Web tetap (jangan dihapus, untuk alur admin):
```bash
pnpm --filter @payrollpro/web test:e2e      # playwright.config.ts sudah ada: retry, trace retain-on-failure, projects desktop/mobile/tablet
```

CI: job `mobile-e2e` (emulator Android API 26 + `patrol test`), job `web-e2e` untuk approval/admin saat `apps/web/**` berubah.

## 2. Critical journey (mobile = employee J1-J6; approval = web)

* [x] J1 Auth: login → biometric → refresh-survive-restart → logout-revoke
* [x] J2 Attendance GPS: pilih lokasi → selfie stub → check-in → check-out (happy + outside-radius + low-accuracy + offline-queue + **race: respons hilang setelah server simpan → retry 400 → rekonsiliasi `GET /today` = synced**)
* [x] J3 Cuti: request (validasi end≥start, reason≥10, kuota, overlap pending/approved) → history → detail milik sendiri
* [x] J4 Lembur: request (0.5–8 jam) → history → terima hasil
* [x] J5 Slip: list periode → detail angka = web → download/share PDF
* [x] J6 Shift saya: hari ini + mingguan tampil benar
* [ ] J7 Approval admin — **WEB-ONLY** (Playwright: employee `POST /leaves` → manager `/leave/approvals` → approve + notes). Tidak ada di APK.

Untuk tiap J mobile: tulis happy path + failure realistis (input salah, 401 expired, network mati, data kosong, GPS jelek).

## 3. Selector resilient (pengganti data-testid web yang saat ini NOL)

Web (`apps/web/e2e/helpers.ts`, `auth.spec.ts`, `attendance.spec.ts`) masih pakai `input[type=email]`, `getByText(...)`, `locator(select).first()` — rapuh.
Mobile wajib `Key` semantik sejak awal:

```dart
const kLoginEmail = Key('login-email');
const kLoginSubmit = Key('login-submit');
const kCheckinSubmit = Key('checkin-submit');
```

Tidak ada `Key('approval-approve')` di mobile (tombol itu hanya ada di web).

## 4. Auth fixture (tanpa ulang login tiap test)

```dart
// integration_test/fixtures/auth.dart
Future<void> loginAsEmployee(WidgetTester t) async {
  // POST /api/auth/login (test user role employee) → tulis ke flutter_secure_storage (test double)
}
```

## 5. Seeding + cleanup (isolasi, bisa diulang)

* Ikuti pola web yang sudah benar (`apps/web/e2e/attendance.spec.ts`, `employee-crud.spec.ts`, `helpers.ts:getAdminToken/apiCreateEmployee/apiDeleteEmployee`): buat user+employee suffix unik via API, cleanup `DELETE attendances` + `apiDeleteEmployee/User`.
* Tambah factory yang belum ada: cuti/lembur/payroll-periode (web juga belum punya — buat sekali, pakai berdua).
* Test IDOR mobile: login employee A, `GET` milik B harus 403 (lihat file 03-H4).
* Jangan pakai data `admin@payrollpro.com` prod untuk e2e device.

## 6. Script

```json
{
  "test": "flutter test",
  "test:e2e": "patrol test",
  "test:e2e:web": "pnpm --filter @payrollpro/web test:e2e"
}
```

## 7. Tidak reliable — tandai, jangan dipaksa hijau

1. **GPS real + selfie kamera (HIGH RISK):** mock `POST /attendance/check-in|check-out` untuk UI; GPS real hanya 1 test `@device-only`.
2. **PDF bytes slip:** assert tabel/`GET /payrolls/my` + event share, bukan isi bytes PDF.
3. **Push FCM real:** assert inbox + deep link; pengiriman FCM real hanya manual/Sanity, bukan tiap CI.
