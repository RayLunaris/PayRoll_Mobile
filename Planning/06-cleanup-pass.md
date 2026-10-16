# 06 — Cleanup Pass (Dua Fase, Berhenti di Tengah) — Scope Employee

Aturan: behaviour identik, tanpa dep baru, tanpa rename public API.

## FASE 1 — AUDIT — status: Disetujui 15 Okt 2026 (A1–A7 disetujui eksekusi, A8 ekstraksi setelah verifikasi tanpa hapus)

| # | Item + bukti | Aksi usul | Risk |
|---|---|---|---|
| A1 | `JWT_EXPIRATION` tidak dipakai (hardcode `15m` di `auth-service/src/routes/auth.ts:150-160,333-343`) | pakai env | Low |
| A2 | Duplikasi `attendanceActivityRoutes` dua prefix (`attendance-service/src/index.ts:50-51`) | satu prefix | Low |
| A3 | Hardcoded dev path + `loadEnvFile` (`auth-service/src/lib/mailer.ts:10,14`) | hapus path absolut | Low |
| A4 | `console.log resetLink` (`mailer.ts:45-48`) | hapus/gate dev-only | **Hati-hati (butuh audit pengganti)** |
| A5 | `refreshToken` ganda di zustand memory (`web/src/stores/auth.ts:155-163`) | cookie-only di web; secure-storage-only di mobile | Medium |
| A6 | `apps/web`: NOL `data-testid` — debt test | tambah Key bertahap (file 05) | Low |
| A7 | Flutter `my_app`: masih template (`lib/main.dart` counter, `get` belum dipakai, nama `my_app`) | rename + hapus counter saat scaffold | Low |
| A8 | Dugaan duplikasi hitung jarak GPS (web vs service) — **confidence <90%, JANGAN hapus** | extract setelah verifikasi | Medium |

Scope employee-only tidak mengubah tabel ini; approval admin tetap di web jadi tidak disentuh cleanup mobile.
Yang confidence <90% (A8) DILARANG hapus.

**Status: Disetujui 15 Okt 2026 (Approve A1–A7 untuk eksekusi, A8 ekstraksi setelah verifikasi). Siap lanjut ke Fase 2.**

## FASE 2 — EKSEKUSI (hanya setelah approve tertulis)

Hapus hanya yang di-approve; extract duplikasi ke `packages/utils` / `lib/core`; pecah file >500 baris. Ringkasan per perubahan untuk review diff.
