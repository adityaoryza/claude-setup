# claude-setup

Pasang semua skill dan plugin Claude Code milik Aditya dengan satu perintah, di perangkat mana pun.

## Satu perintah

Repo publik:

```bash
curl -fsSL https://raw.githubusercontent.com/adityaoryza/claude-setup/main/install.sh | bash
```

Repo private (butuh `gh auth login`):

```bash
gh api repos/adityaoryza/claude-setup/contents/install.sh -H "Accept: application/vnd.github.raw" | bash
```

Opsi dikirim lewat `bash -s --`, misalnya semua termasuk yang opsional:

```bash
curl -fsSL https://raw.githubusercontent.com/adityaoryza/claude-setup/main/install.sh | bash -s -- --all
```

Atau setelah `git clone`: `bash install.sh [--all] [--only a,b] [--skip a,b] [--list]`. `DRY_RUN=1` hanya menampilkan perintah tanpa memasang. Skrip aman dijalankan berulang.

Prasyarat: Claude Code (CLI `claude` di PATH, atau aplikasi desktop yang sudah terpasang: skrip otomatis memakai CLI bawaannya di `~/.claude/remote/ccd-cli/`, atau tentukan sendiri dengan `CLAUDE_BIN=/path/ke/claude`). Tanpa keduanya, pasang CLI dengan `curl -fsSL https://claude.ai/install.sh | bash` lalu jalankan `claude` sekali untuk login ([panduan](https://code.claude.com/docs/en/setup)). Akun Pro, Max, Team, Enterprise, atau Console. Juga Node.js 18+ (npm), Python 3, dan git. RTK butuh Homebrew atau Rust.

## Daftar

### Desain antarmuka

| Skill | Fungsi | Pasang manual | Sumber |
| --- | --- | --- | --- |
| frontend-design | Arah visual tegas, tipografi dan spasi konsisten, bukan tampilan generik. Resmi Anthropic. | `claude plugin marketplace add anthropics/claude-plugins-official` lalu `claude plugin install frontend-design@claude-plugins-official` | [repo](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/frontend-design) |
| designer-skills | Alur desain bertahap: `/grill-me`, `/design-brief`, `/information-architecture`, `/design-tokens`, `/brief-to-tasks`, `/frontend-design`, `/design-review`, dan `/design-flow` yang menjalankan semuanya berurutan. Apache 2.0. | `claude plugin marketplace add julianoczkowski/designer-skills` lalu `claude plugin install designer-skills@designer-skills` | [repo](https://github.com/julianoczkowski/designer-skills) |
| ui-ux-pro-max | Memilih palet, font, dan aturan desain sesuai jenis proyek. Butuh Python 3, skripnya tanpa panggilan jaringan. MIT. | `claude plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill` lalu `claude plugin install ui-ux-pro-max@ui-ux-pro-max-skill` | [repo](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) |
| impeccable | 24 perintah desain (`/impeccable polish`, `audit`, `critique`, dan lain-lain) dan deteksi pola "AI slop". Apache 2.0. | `claude plugin marketplace add pbakaus/impeccable` lalu `claude plugin install impeccable@impeccable` | [repo](https://github.com/pbakaus/impeccable) |
| skillui | CLI yang mengekstrak design system dari situs, repo, atau folder ke file yang dibaca Claude. MIT, tanpa AI dan tanpa API key. | `npm install -g skillui` | [repo](https://github.com/amaancoderx/npxskillui) |
| playwright-cli | Claude membuka browser dan memotret hasil kerjanya sendiri. | `npm install -g @playwright/cli@latest` lalu `playwright-cli install --skills -g` | [dokumentasi](https://playwright.dev/agent-cli/skills) |

### Gaya kerja

| Skill | Fungsi | Pasang manual | Sumber |
| --- | --- | --- | --- |
| ponytail | Persona "senior dev malas": ikuti tangga keputusan (perlu ada? sudah ada di kode? stdlib? satu baris?) sebelum menulis kode, selalu selesaikan semua bagian perubahan, tidak memotong validasi, keamanan, dan aksesibilitas, dan menutup tiap balasan dengan yang dilewati. MIT. | `claude plugin marketplace add DietrichGebert/ponytail` lalu `claude plugin install ponytail@ponytail` | [repo](https://github.com/DietrichGebert/ponytail), [halaman](https://claudecowork.im/resources/ponytail-lazy-senior-dev) |

### Hemat token

| Skill | Fungsi | Pasang manual | Sumber |
| --- | --- | --- | --- |
| caveman | Claude menulis ringkas (tanpa basa-basi), kode dan perintah tetap utuh. Aktif otomatis di tiap sesi. Apache 2.0. | `claude plugin marketplace add JuliusBrussee/caveman` lalu `claude plugin install caveman@caveman` | [repo](https://github.com/JuliusBrussee/caveman) |
| rtk (opsional) | Proxy CLI yang meringkas keluaran perintah shell sebelum masuk konteks. Hook global khusus tool Bash. Apache 2.0 untuk CLI. | `brew install rtk` (atau `cargo install --git https://github.com/rtk-ai/rtk`), cek `rtk gain`, lalu `rtk init -g` | [repo](https://github.com/rtk-ai/rtk) |
| context-mode (opsional) | Menyimpan keluaran tool besar di database lokal dan hanya mengirim ringkasan ke konteks. Memasang 6 hook dan 11 tool MCP. Lisensi ELv2. | `claude plugin marketplace add mksglu/context-mode` lalu `claude plugin install context-mode@context-mode` | [repo](https://github.com/mksglu/context-mode) |

Pemantau pemakaian tidak perlu dipasang, jalankan saat dibutuhkan: `npx ccusage@latest` ([repo](https://github.com/ryoppippi/ccusage), MIT, membaca data lokal, harga model diunduh kecuali `--offline`).

## Yang perlu diketahui sebelum memasang

- **Impeccable memasang hook** yang menjalankan launcher lokal pada edit file UI dan saat sesi berhenti, dan bisa mengunduh mesinnya ke `~/.impeccable`. Telemetri anonim aktif secara bawaan. Skrip ini mematikannya dengan menambah `DO_NOT_TRACK=1` dan `IMPECCABLE_NO_TELEMETRY=1` ke blok `env` di `~/.claude/settings.json` (cadangan disimpan sebagai `settings.json.bak`). Lewati dengan `NO_TELEMETRY_CONFIG=1`.
- **rtk dan context-mode opsional** (`--all`) karena mengubah cara Claude bekerja secara global: rtk menulis ulang perintah Bash lewat hook, context-mode mendaftarkan 6 hook dan server MCP. Keduanya menyasar masalah yang mirip, jadi pasang salah satu dulu. Langkah `rtk init -g` interaktif, jadi dijalankan manual.
- **caveman** mengubah gaya tulisan Claude menjadi sangat ringkas di semua sesi, termasuk subagen. Matikan dengan `claude plugin uninstall caveman@caveman`. Jalur `npx @caveman-ai/cli` mengirim statistik pemakaian secara bawaan; skrip ini memakai jalur plugin.
- **designer-skills dan frontend-design resmi sama-sama punya skill bernama `frontend-design`.** Keduanya terpasang di namespace plugin masing-masing dan bisa tumpang tindih. Kalau hasilnya membingungkan, pakai salah satu (`claude plugin uninstall frontend-design@claude-plugins-official`). Plugin ini mengikuti commit terbaru di `main`, jadi isinya bisa berubah; baca sebelum memperbarui.
- **ponytail dan caveman sama-sama mengubah gaya kerja Claude di semua sesi** (ponytail menahan kode berlebih, caveman memangkas kata). Keduanya bisa dipakai bersamaan; kalau jawaban terasa terlalu irit, matikan salah satu dengan `claude plugin uninstall`.
- Skill dan plugin pihak ketiga adalah instruksi yang memengaruhi perilaku Claude. Baca `SKILL.md`-nya sebelum memasang yang baru.
- Skill terbaca setelah Claude Code dimulai ulang. Cek dengan `claude plugin list`.

## Perbarui dan hapus

Sintaks bisa sedikit berbeda antar versi Claude Code; cek dengan `claude plugin --help`.

```bash
claude plugin marketplace update            # tarik versi terbaru semua marketplace
claude plugin update caveman@caveman        # perbarui satu plugin
claude plugin uninstall caveman@caveman     # hapus satu plugin
npm uninstall -g skillui @playwright/cli    # hapus CLI global
```

## Menambah skill baru

Tambahkan fungsi `s_nama()` di `install.sh` (pola sama dengan `s_caveman`), daftarkan namanya di `STANDARD` atau `OPTIONAL`, panggil lewat `step nama s_nama`, lalu tambahkan barisnya di tabel README ini.

## Lisensi

MIT untuk skrip ini. Setiap skill memakai lisensinya sendiri (lihat tabel).
