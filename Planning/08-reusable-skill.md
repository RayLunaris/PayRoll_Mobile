# 08 — Skill: payrollpro-mobile-planner (Employee Only)

## 1. Nama

`payrollpro-mobile-planner` — buat planning mobile Flutter employee-only dari monorepo PayrollPro.

## 2. Deskripsi

**Pakai ketika** user bilang: "buatkan planning mobile", "jadikan versi mobile", "planning flutter payroll", "mobile hanya user" — dan repo berisi `apps/web` + `apps/api-gateway` + `*-service` + `packages/db`.
**Jangan pakai** untuk: fix bug, audit saja, testing saja, repo non-payroll, atau minta coding langsung.

## 3. Instructions

1. Cek `apps/web/src/app/**/page.tsx` + `apps/api-gateway/src/routes|plugins` + `packages/db/src/schema` + `Flutter/pubspec.yaml|lib/`. Jangan mengarang endpoint.
2. Kunci scope: **mobile = `employee` saja**; admin/manager web-only. Tanya max 5 klarifikasi (MVP vs v2, batasan teknis, definisi done, Patrol vs Playwright). Tunggu jawaban.
3. Tulis `01-prd` (10 bagian; 2 persona employee: Sinta produksi + Dimas lapangan).
4. Tulis `09-sitemap` (tanpa `/admin/*`; deep link hasil + slip + check-out; web-only list eksplisit).
5. Tulis `02-design-brief` (10 bagian, token hex + alasan).
6. Audit `03-security` dari kode (file:line + exploit + fix; urut severity; tulis yang bersih; JANGAN ubah kode).
7. Tulis `04-bug-template`, `05-e2e` (Patrol J1-J6 mobile; J7 approval web-only Playwright), `06-cleanup` (tabel risk, berhenti), `07-commit` (atomic), `08` (file ini).
8. Semua file ke `Flutter/Planning/`. Lapor + minta approve (03, 06, open questions).

## 4. Rules dan constraint

* Wajib: klaim kode ada file:line; tanpa dep baru; tanpa rename public API.
* Dilarang: mengarang endpoint/tabel; token di log/SharedPreferences; tombol approve di APK; port modul admin ke mobile.

## 5. Output format

```
Planning/
  01-prd-mobile-flutter.md
  02-design-brief-mobile.md
  03-security-audit-prelaunch.md
  04-bug-diagnose-template.md
  05-e2e-testing-mobile.md
  06-cleanup-pass.md
  07-commit-convention.md
  08-reusable-skill.md
  09-sitemap-mobile-flutter.md
```

## 6. Contoh

*Input:* "mobile hanya user, perbaiki planning."
*Output:* 9 file scope employee-only; MVP = absensi/cuti/lembur/slip/shift/notif masuk; `device_tokens` satu-satunya migrasi; approval tetap web.

## 7. Failure mode

1. **Mengarang API** → baca gateway+routes dulu.
2. **Port 60 halaman + admin ke APK** → daftar web-only eksplisit.
3. **Playwright untuk APK** → Patrol/integration_test.
4. **Token di log/prefs** → secure-storage-only + FLAG_SECURE.
5. **Hapus yang dipakai** → risk table + <90% dilarang + approve tertulis.
