# Hosted recordings

This folder mirrors the Cloudflare R2 bucket `namo-audio`, served at `https://namo-audio.v-g-a-induwara.workers.dev` by the Worker in `cloudflare/audio-worker/` (deploy it from that folder with `npx wrangler deploy`). A custom domain was not used because `intendable.us` lives on a different Cloudflare account; if a zone ever lands on this account, attach it to the Worker and change `defaultAudioBaseUrl` in `lib/audio/audio_host.dart`.
An object's key is its path under `hosted/` (for example `audio/pirith/08-mahamangala.m4a`). The app fetches each recording once and keeps it.

**Never replace a file under the same name.** Clients cache recordings for a year (`immutable`). A changed recording needs a new file name, and the content must point at it.

Every upload carries `Content-Type: audio/mp4` and `Cache-Control: public, max-age=31536000, immutable`.

Commands (from the project root; the tool reads the size and SHA-256 of each recording from `assets/content/*.json`):

- `python -I -X utf8 tools/sync_hosted_audio.py . --check`: offline; this folder holds exactly the named recordings, byte for byte.
- `python -I -X utf8 tools/sync_hosted_audio.py . --plan`: prints the `npx wrangler r2 object put` command for each recording.
- `python -I -X utf8 tools/sync_hosted_audio.py . --upload`: runs them. Run `npx wrangler login` once first.
- `python -I -X utf8 tools/sync_hosted_audio.py . --verify`: a HEAD request per recording (status, length, type).
- `python -I -X utf8 tools/sync_hosted_audio.py . --verify-full`: downloads each recording and checks its SHA-256.
- Add `--base-url <url>` to `--verify` or `--verify-full` to test an `r2.dev` address while the custom domain is not live.

CORS policy to set on the bucket (the web build needs it); save it as a file and run
`npx wrangler r2 bucket cors set namo-audio --file <file>`:

```json
{"rules": [{"allowed": {"origins": ["*"], "methods": ["GET", "HEAD"], "headers": ["Range"]}, "maxAgeSeconds": 86400}]}
```

Licences: the pirith recordings are CC BY-ND 4.0, from pitaka.lk. The Samantha Pattana recording is from Samata Dharmaya; permission is pending. The bucket stays private until the owner confirms the permissions.
