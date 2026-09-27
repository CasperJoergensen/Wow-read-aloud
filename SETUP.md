# Setup

## 1. Install the addon

Copy the `LoreReader` folder into WoW Forever's AddOns folder. The beta client installs into `_classic_beta_`, so the path is usually:

```
C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns\LoreReader
```

For retail WoW, copy it into `_retail_\Interface\AddOns\LoreReader` as well. Each game keeps its own copy and its own settings.

If retail shows LoreReader as "out of date" after a patch, the retail version number in `LoreReader.toc` needs bumping: run `/dump select(4, GetBuildInfo())` in game and put that number after `16001,` on the `## Interface:` line.

Check that `LoreReader.toc` is directly inside that folder, then enable LoreReader on the character select AddOns screen. LoreReader works immediately with WoW's default (robotic) voice. The steps below add neural voices.

## 2. Install neural voices (Windows 11)

WoW's text-to-speech can only use classic Windows "SAPI5" voices. [NaturalVoiceSAPIAdapter](https://github.com/gexgd0419/NaturalVoiceSAPIAdapter) makes Windows 11's Narrator natural (neural) voices show up as SAPI5 voices.

1. **Install the Narrator natural voice packages — the older versions.** Microsoft changed the Store versions so the adapter can't use them any more. Download the working versions from the adapter wiki: [Narrator natural voice download links](https://github.com/gexgd0419/NaturalVoiceSAPIAdapter/wiki/Narrator-natural-voice-download-links). Good narration voices: **Aria**, **Jenny**, **Guy** (en-US).
2. **Install the adapter.** Download the latest release from the adapter's GitHub page and run the installer. Install **both the 32-bit and 64-bit** versions. In its settings, enable local Narrator voices. Optionally also enable **Edge online voices** as a fallback — they need no packages but require internet and are a bit slower.
3. **Self-sign the adapter DLL.** Since mid-2025 WoW refuses to load unsigned voice DLLs, so the voices won't appear until the DLL is signed. The community steps are in [adapter issue #37](https://github.com/gexgd0419/NaturalVoiceSAPIAdapter/issues/37#issuecomment-3680384897) — follow that thread first, as it is the source of truth. The general shape (PowerShell as Administrator):

   ```powershell
   # Create a code-signing certificate
   $cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject "CN=Local Voice Adapter" -CertStoreLocation Cert:\CurrentUser\My

   # Trust it (Root + TrustedPublisher)
   Export-Certificate -Cert $cert -FilePath "$env:TEMP\voice.cer"
   Import-Certificate -FilePath "$env:TEMP\voice.cer" -CertStoreLocation Cert:\LocalMachine\Root
   Import-Certificate -FilePath "$env:TEMP\voice.cer" -CertStoreLocation Cert:\LocalMachine\TrustedPublisher

   # Sign both adapter DLLs (adjust the paths to where the installer put them)
   Set-AuthenticodeSignature -FilePath "<adapter folder>\x64\NaturalVoiceSAPIAdapter.dll" -Certificate $cert
   Set-AuthenticodeSignature -FilePath "<adapter folder>\x86\NaturalVoiceSAPIAdapter.dll" -Certificate $cert
   ```

   Security note: a trusted root certificate can sign anything your PC will trust. When you're done, delete the certificate's private key (`Remove-Item Cert:\CurrentUser\My\<thumbprint>`), so nobody can use it to sign anything else. The public part stays trusted so the DLL still validates.
4. **Restart WoW** fully (not just `/reload`).

## 3. Check it in game

```
/lore voices          lists every voice WoW can see
/lore voice aria      pick a voice by (part of) its name
/lore test            read a sample
/lore                 open the options panel
```

If only "Microsoft David/Zira" appear, the adapter isn't being loaded: re-check the signing step and that both 32-bit and 64-bit adapters are installed.

## When it breaks

WoW patches and Windows voice updates have broken the adapter before. When that happens LoreReader keeps working with the default voice and prints a one-line warning. Check the adapter's GitHub issues for a fix, then pick your voice again with `/lore voice <name>`.
