# The LockedIn shipping playbook

How this app was built, packaged, and launched — written down so the next app
(and anyone else's indie macOS app) can follow the same track. Steps are in the
order that worked, with the mistakes we paid for marked ⚠️.

## 1. Repo shape (day one)

- **One monorepo**: Swift app at the root, `landing/` for the Next.js site,
  `scripts/` for every build/release action, `docs/` for process, `.github/`
  for CI + templates + README assets.
  *(Amended 2026-07: the site now lives in its own repo, `<app>-site` — app
  users cloning the repo don't need the website. Both LockedIn and SplitScreen
  follow the split layout; ship docs point at `../<app>-site`.)*
- **SwiftPM only, no Xcode project.** `swift build` is the compile check;
  `scripts/bundle.sh` assembles the .app (Info.plist, icon, version); everything
  is scriptable and CI-able on a plain runner.
- **`VERSION` file** is the single source of truth; build number = `git rev-list --count HEAD`.
- **`CLAUDE.md` at the root** with: how to run, the architecture in ten lines,
  and the *hard rules* (design system, product invariants). Every agent session
  starts aligned instead of rediscovering decisions.
- ⚠️ **Set git identity before the first commit**: repo-local `user.name` +
  GitHub noreply email. We had to `filter-branch` 74 commits later to fix
  attribution and strip trailers. Two lines at `git init` avoids that.

## 2. App architecture

- **Menu-bar app = LSUIElement** (no Dock icon). When a real window opens, flip
  `NSApp.setActivationPolicy(.regular)`; back to `.accessory` when the last one
  closes. Count *transitions*, not calls.
- **Small single-purpose monitors** (one class per data source) feeding a 5-second
  tick loop; persistence is one JSON file per day in Application Support. No
  database, trivially debuggable, trivially private.
- **Privacy as architecture**: zero permissions, read only metadata (timestamps,
  paths, counts — never content). This constraint became the strongest marketing
  line, not a limitation.
- **A `--render <dir>` CLI flag** that dumps a PNG of every UI surface. It powers
  README screenshots, design review, and QA without clicking through the app.
- **Debug breadcrumbs in UserDefaults** (`notif.debug.*` style) for anything that
  can fail silently in the field (notifications, auth, updates).
- ⚠️ **Guard automated self-remediation with positive proof.** Our "rescue the
  menu-bar item from the notch" logic fired on false positives (full-screen apps
  hide the whole menu bar) and *caused* the disappearance it was fixing. Before
  any automatic recovery action, prove the bad state, not just the absence of a
  good signal — and trust user reports over flaky system APIs.
- ⚠️ **Profile the tick loop early.** Re-reading growing log files every 5s cost
  50–99% CPU. Incremental byte-offset reads took it to ~0%. Measure CPU + RSS
  before anyone else does.
- **Dev hygiene**: /Applications is the canonical install; kill and replace it on
  every rebuild so two instances never run (we double-counted time for a day).

## 3. One design system, app === website

- **All tokens in one `Theme.swift`**; the site's `globals.css` mirrors it
  value-for-value. Change both together — the app screenshot and the landing page
  must look like the same product.
- **Write the hard rules down** (ours: SF Symbols only — never emoji; one accent
  color; forced dark; every new view styled through tokens).
- **Pick one signature visual element** (our split bar) and repeat it everywhere:
  popover, widget, dashboard, share card, website hero.
- **Generate the app icon from a script** (`scripts/make_icon.py`) so re-theming
  regenerates it instead of orphaning it.

## 4. Landing site

- Next.js on Vercel; free `.vercel.app` URL until launch week, then a real domain.
- **Waitlist → Vercel Blob** (private store, one JSON per signup) — durable email
  capture with zero backend.
- **Vercel Analytics** with a custom `download_dmg` event = the entire funnel
  metric stack for v0.
- The site also serves the **update feed (`appcast.json`)**, the **DMG**, and the
  **install script** — one deploy ships marketing + distribution.

## 5. Distribution without paying Apple (yet)

The big lesson of this project. Unsigned apps are fine for a dev-audience beta
*if* the funnel is honest and tested:

- **`curl -fsSL <site>/install | sh` is the headline install.** curl downloads
  carry no quarantine flag, so the script (download DMG from GitHub Releases →
  ditto to /Applications → `xattr -dr` belt-and-braces → open) hits **zero
  Gatekeeper prompts**. Serve it from the site with a `/install` rewrite.
- **Homebrew tap** (`<user>/homebrew-tap` repo, one cask file): a second real
  install path in ~20 minutes. Document `--no-quarantine`. Future apps just add
  another cask to the same tap.
- **DMG as the fallback**, with copy that matches current macOS: ⚠️ macOS 15
  removed right-click → Open for unsigned apps — the real path is *open once →
  System Settings → Privacy & Security → Open Anyway*. Wrong instructions here
  are a support disaster.
- **Own the unsigned state in writing** ("unsigned until the project justifies
  $99/yr") — dev audiences respect honesty and punish pretending.
- ⚠️ **Never advertise an install command that doesn't exist.** We shipped three
  fake ones (brew formula, unowned domain, npm CLI) as design placeholder copy.
  Test every command on the live site, end to end, on a clean path.
- **`scripts/release.sh` ready for Developer ID day**: sign (hardened runtime +
  timestamp) → DMG → `notarytool submit --wait` → staple → `spctl` verify; it
  *refuses* to ship ad-hoc builds. When the $99 happens, release day is one
  command.

## 6. Updates

- **Static `appcast.json` on the site** + a tiny in-app poller (6h): version,
  URL, notes[]. One notification per version, banner in the popover.
- Ship = bump `VERSION` → build DMG → copy to `landing/public/download/` → bump
  appcast + changelog page → deploy site → `gh release create vX.Y` with the DMG
  attached (asset also named plain `LockedIn.dmg` so
  `releases/latest/download/...` is a stable URL for the install script).

## 7. GitHub public-readiness

Checklist that took us from private to public:

- README: badges, install one-liner *first*, `--render`-generated screenshots +
  a desktop tour GIF, why/how-it-works, source layout table, build-from-source.
- LICENSE (MIT), CONTRIBUTING, SECURITY.md with an honest **known limitations**
  section, issue templates (.yml) — and **link the templates from inside the
  app** (Report a bug / Suggest a feature in the dashboard).
- CI from day one: `swift build` on macos + site build on ubuntu. Green badge
  before flipping public.
- Before the flip: secret sweep of working tree *and* full history; authors and
  trailers the way you want them forever (rewrite while private — it's free then).
- After the flip: enable private vulnerability reporting, add topics + homepage,
  pin the repo.

## 8. Launch order

1. Funnel first: real domain, tested install commands, accurate Gatekeeper copy.
2. Directories + awesome-list PRs (slow-drip SEO, one hour total).
3. Reddit niche subs → Show HN (privacy story ready, stay in comments) → X
   build-in-public with the share card → Product Hunt once there's social proof.
4. A data blog post from your own usage 2–4 weeks in — second front-page shot.

## The meta-rule

Every claim the product makes — an install command, a screenshot, a privacy
promise, a "right-click → Open" — gets **verified on the live artifact** before
it ships. Placeholder copy rots into lies; funnels only count if you've walked
them yourself from a clean machine's point of view.
