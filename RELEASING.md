# Releasing to CurseForge

Releases are built and uploaded by the [BigWigs packager](https://github.com/BigWigsMods/packager) GitHub Action (`.github/workflows/release.yml`) whenever a `v*` tag is pushed.

## One-time setup

1. **Make the repo public and rename it** to `Lorecaster` (GitHub → Settings → General). Blizzard requires addon code to be publicly visible, and the TOC and page links point to `github.com/CasperJoergensen/Lorecaster`.
2. **Create the CurseForge project** at https://authors.curseforge.com:
   - game: World of Warcraft; name: **Lorecaster**; license: **MIT**
   - paste the description from `CURSEFORGE.md`
   - add a logo (400×400)
3. **Add the project ID to the TOC.** Find the numeric ID in the "About Project" panel on the project page, and add this line to `Lorecaster.toc`:
   ```
   ## X-Curse-Project-ID: 123456
   ```
4. **Create an API token** at https://authors.curseforge.com/account/api-tokens. Add it to the GitHub repository as a secret named `CF_API_KEY` (Settings → Secrets and variables → Actions).

## Each release

1. Go through `TESTING.md` in-game.
2. Add a section to the top of `CHANGELOG.md`. Its text becomes the CurseForge changelog.
3. Tag and push:
   ```
   git tag v0.1.0-beta.1
   git push origin v0.1.0-beta.1
   ```
   - A tag containing `beta` or `alpha` is published as a Beta or Alpha file. A plain `v0.1.0` is a Release.
   - The packager replaces `@project-version@` in the TOC with the tag name.
4. Watch the Actions tab. The packager tags the upload for **WoW Forever** (`16001` → game version 1.60.1) and **retail** (`120105` → 12.1.5), reading both from the `## Interface:` line.

## When retail patches

Update the retail number on the `## Interface:` line. In game, `/dump select(4, GetBuildInfo())` prints it. Then release a new version.
