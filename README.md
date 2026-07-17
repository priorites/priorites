# Domain SQLite Test

A very small Flutter web app for testing:

- custom domain hosting
- GitHub Actions builds
- Cloudflare Pages deploys
- browser-persistent SQLite storage through `sqlite3.wasm` and IndexedDB

## Run locally

Install Flutter, then run:

```bash
flutter pub get
flutter run -d chrome
```

Type a value and save it. Reload the page. The saved rows should still be there because the database is stored in the browser's IndexedDB.

## Build for Cloudflare Pages

```bash
flutter build web --release
```

Deploy the `build/web` directory.

## GitHub to Cloudflare pipeline

The workflow in `.github/workflows/deploy-cloudflare-pages.yml` builds Flutter web and uploads `build/web` to Cloudflare Pages.

Add these GitHub repository secrets:

- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`

Add this GitHub repository variable:

- `CLOUDFLARE_PROJECT_NAME`

Your site should load as a static Cloudflare Pages site. The SQLite database is local to each visitor's browser, so data persists across reloads on the same browser/device, not across different users or devices.
