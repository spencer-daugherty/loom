# Loom Source Control

This workspace intentionally has two separate Git histories:

- `.git/` is the GitHub-connected public website repository. It must never contain
  Xcode project files, native source code, app configuration, or credentials.
- `.xcode-local-git/` is the offline, local-only Xcode repository. It has no
  remote and blocks every push through its pre-push hook.

In a Codex Cloud checkout, only the public website repository exists. Treat any
missing local Xcode paths or tools as intentionally unavailable. Do not recreate,
approximate, upload, or request native application files in the public repository.

## Public Website

- GitHub Pages publishes `main:/docs` to `https://loomlife.us`.
- Treat `docs/` as the production website. Edit root-level mirrors only when the
  task explicitly requires them.
- Keep `assets/analytics.js` and `docs/assets/analytics.js` identical whenever
  the analytics loader changes.
- Preserve Loom's established design, navigation, analytics controls, canonical
  URLs, structured data, and accessibility behavior.
- New public pages must use a descriptive title and meta description, canonical
  URL, useful internal links, and an entry in `docs/sitemap.xml` when indexable.
- Never add private analytics exports, customer data, account credentials, API
  keys, `.env` files, or unpublished business records.
- Do not merge or deploy a Cloud task unless the user explicitly requests it.

Before presenting website work as complete, run:

```sh
./.githooks/verify-public-repo --tracked
./.githooks/verify-public-site --worktree
```

For visual changes, serve `docs/` locally and inspect relevant desktop and mobile
pages. The website has no package-install step.

## Xcode Commits

When the user asks to "commit Xcode", "commit the app", or otherwise explicitly
requests a native iOS checkpoint:

1. Use `./.xcode-local-tools/xcode-history commit "<message>"`.
2. Never force-add app files to the public website repository.
3. Run `./.xcode-local-tools/xcode-history verify` after the commit.
4. Report the local Xcode commit hash and confirm that the local repository has
   no remote.

When the user asks to commit website work, use the normal public repository only
after its existing public-repository hooks pass.

An unqualified "commit" should be resolved from the files changed in the current
task. Native app changes use the local Xcode history; public website-only changes
use the public repository.

## Safety

- Do not add a remote to `.xcode-local-git/`.
- Do not bypass `.xcode-local-tools/hooks/pre-push`.
- Do not commit `GoogleService-Info.plist`, `.env` files, signing keys,
  provisioning profiles, Xcode user data, temporary files, or build output.
- Local Git history protects development checkpoints but is not an off-device
  backup. Use an encrypted local backup such as Time Machine as well.
