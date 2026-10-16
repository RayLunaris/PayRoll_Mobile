# Sitemap Mobile PayrollPro (Flutter) — Employee Only

Sumber: `apps/web/src/app` (~60 `page.tsx`) dipadatkan untuk mobile.
Prinsip: **mobile hanya `employee`.** Seluruh alur admin/manager (`approvals`, `admin/*`, `payroll/process`, `settings/*`, `reports/*` export) tetap web-only.

## 1. Struktur Navigasi

```
Splash (/)
└── Auth Stack (unauthenticated)
│   ├── /login            ← (auth)/login
│   ├── /register         ← (auth)/register
│   ├── /forgot-password  ← (auth)/forgot-password
│   ├── /reset-password   ← (auth)/reset-password
│   └── biometric-gate    (local, tanpa padanan web)
└── Main Tabs (authenticated, bottom nav 5, employee only)
    ├── [Tab 1] /home
    │   ├── /home                              ← (dashboard)/dashboard (versi ringkas pribadi)
    │   ├── /notifications                     ← (dashboard)/notifications (inbox hasil)
    │   └── /notifications/:id (detail milik sendiri)
    ├── [Tab 2] /attendance
    │   ├── /attendance (check-in/out 1-tap)   ← attendance/check-in + attendance/page
    │   ├── /attendance/history                ← attendance/history
    │   └── /attendance/history/:date (detail) ← attendance/report
    ├── [Tab 3] /request (Pengajuan)
    │   ├── /request (hub: Cuti / Lembur)
    │   ├── /leave/request                     ← leave/request
    │   ├── /leave/history                     ← leave/history
    │   ├── /leave/history/:id (detail milik sendiri)
    │   ├── /leave/quota                       ← leave/quota
    │   ├── /leave/calendar                    ← leave/calendar
    │   ├── /overtime/request                  ← overtime/request
    │   ├── /overtime/history                  ← overtime/history
    │   └── /overtime/history/:id (detail milik sendiri)
    ├── [Tab 4] /payslip
    │   ├── /payslip (list periode)            ← payroll/slips
    │   ├── /payslip/:period (detail komponen) ← payroll/page (detail personal)
    │   └── /payslip/:period/pdf (viewer/share)
    └── [Tab 5] /more (Lainnya)
        ├── /shift (jadwal saya + kalender)    ← shift/page + shift/calendar
        ├── /profile                           ← employees/[id] (milik sendiri)
        ├── /profile/password                  ← settings/password
        └── /settings (app-level: bahasa, biometric on/off, logout, versi)
```

Tidak ada grup `/admin/*` di mobile.

## 2. Tabel Route → Sumber Web → API

| Mobile route | Sumber web | API gateway (reuse) | Role |
|---|---|---|---|
| `/login`, `/register`, `/forgot-password` | `(auth)/*` | `POST /api/auth/*` | publik |
| `/home` | `(dashboard)/dashboard` (ringkas pribadi) | `GET /api/dashboard/*` | employee |
| `/notifications` | `(dashboard)/notifications` | `GET /api/notifications?mine` | employee |
| `/attendance` | `attendance/check-in`, `attendance/page` | `POST /api/attendances/check-in\|checkout`, `GET /api/work-locations` | employee |
| `/attendance/history` | `attendance/history`, `attendance/report` | `GET /api/attendances?mine` | employee |
| `/leave/*` | `leave/request|history|quota|calendar` | `GET|POST /api/leaves`, `GET /api/leave-quotas` | employee |
| `/overtime/*` | `overtime/request|history` | `GET|POST /api/overtimes` **[OPEN: kunci path ikut web]** | employee |
| `/payslip*` | `payroll/slips`, `payroll/page` | `GET /api/payrolls?mine`, file `slip_url` | employee |
| `/shift` | `shift/page`, `shift/calendar` | `GET /api/shifts/mine`, `GET /api/employee-shifts` | employee |

## 3. Deep Link (push → halaman, hasil untuk employee)

| Push event | Deep link | Fallback jika denied |
|---|---|---|
| Hasil approval cuti/lembur (dari manager via web) | `payrollpro://leave/history/:id` | inbox `/notifications` |
| Slip terbit | `payrollpro://payslip/:period` | tab Slip |
| Pengingat check-out | `payrollpro://attendance` | tab Absensi |

`POST /api/device-tokens` (tabel baru `device_tokens`) wajib ada sebelum push jalan.

## 4. Web-only (sengaja tidak masuk mobile)

`leave/approvals`, `overtime/approvals`, `payroll/process|bpjs|tax|cash-advances`, `employees/add|[id]/edit`, `settings/*` (users, positions, departments, locations, bpjs, tax, overtime), `admin/budgets`, `admin/projects`, `admin/today`, `reports/*` (export), `attendance/abuse`, `shift/assign|swap`, `social/messages|forum` (penuh, V2 nanti).

## 5. Aturan Tampil per Role

* Mobile: hanya `employee`. Non-employee yang login di mobile → tampilkan pesan "Gunakan versi web" + tombol logout.
* `hr_admin`/`manager`/`super_admin`: penuh di web, tidak ada layar admin di mobile.
