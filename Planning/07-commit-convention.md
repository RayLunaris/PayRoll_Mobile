# 07 — Commit Convention (Atomic, Conventional Commits) — Employee Only

Tipe: `feat, fix, refactor, perf, docs, test, chore, style, build, ci`. Dilarang: `update, fix stuff, changes, wip`.
Format: `type(scope): ringkasan imperatif <60 char` + body KENAPA + tradeoff + `BREAKING CHANGE:` bila ada.

## Urutan commit (repo hijau tiap langkah; tanpa commit approval-admin di mobile)

```
1. chore(mobile): scaffold flutter planning docs employee-only
2. feat(mobile-auth): login JWT + secure storage + biometric gate
3. feat(mobile-attendance): GPS check-in/out + offline queue
4. feat(mobile-leave): request/history/quota + attachment
5. feat(mobile-overtime): request/history hasil read-only
6. feat(mobile-payslip): list/detail/share PDF
7. feat(mobile-shift): jadwal saya + kalender
8. feat(mobile-notif): FCM register + inbox hasil + deep link milik sendiri
9. fix(auth): pakai JWT_EXPIRATION env (lihat 03-H1)
10. fix(auth): hapus log resetLink prod (lihat 03-C1)
11. test(mobile): patrol J1-J6 employee + fixture + seeding
```

Approval manager/HR tetap commit web (`fix(web-approval): ...`), bukan mobile.

## Perintah git persis (contoh, ulangi per scope)

```bash
git status --short
git add "C:/Users/Advan/Documents/Projects/Flutter/Planning/01-prd-mobile-flutter.md" "C:/Users/Advan/Documents/Projects/Flutter/Planning/02-design-brief-mobile.md"
git commit -m "docs(mobile): revisi PRD dan design ke employee-only

Kenapa: mobile hanya user, admin tetap web agar scope tidak melebar.
Tradeoff: approval/push-admin tidak ada di APK."
git log --oneline -5
```
