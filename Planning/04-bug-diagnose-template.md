# 04 — Bug Diagnose Template (Jangan Langsung Fix) — Scope Employee

Aturan: restate → hipotesis → 1 cek per hipotesis → STOP tunggu hasil → fix minimal. Dilarang shotgun, refactor tak terkait, atau benerin yang tidak diminta.

## Cara pakai

```
Error / perilaku tak diharapkan:
Yang saya harapkan:
Yang sebenarnya terjadi:
Kode relevan (file:line atau tempel):
Yang sudah saya coba:
Env: [staging|prod|emulator Android API __|HP fisik __]  App versi: __  Role: employee  Backend: [gateway :3001|service langsung]
```

## Diagnosa

1. **Restate** (1-2 kalimat).
2. **Hipotesis (3-5, urut probabilitas + alasan).**
3. **Satu cek tercepat per hipotesis** (satu log / satu pengecekan / satu test).
4. **STOP — tulis:** "Tunggu hasil cek dari kamu sebelum fix."

## Fix (hanya setelah terkonfirmasi)

Satu perubahan minimal + diff + kenapa berhasil + tes verifikasi persis.

## Contoh (GPS check-in ditolak padahal di kantor)

* H1 akurasi >100m → cek `position.accuracy` di `GpsStatusCard`.
* H2 lat/lng `work_locations` geser → cek `GET /api/work-locations` vs maps.
* H3 mock-location aktif → cek flag Android.
* H4 radius default bukan per-lokasi → cek log `radius_meters` client vs server.
