# wiwiwi — first Internal testing upload (checklist)

Prepared 1 Nov 2026. You (owner) do these steps in Play Console; Claude never uploads.
Play Console screens change over time — if a button name differs, follow the closest match.

## What's ready

| File | Where | Notes |
|---|---|---|
| Release bundle | `builds/wiwiwi-release.aab` | version **0.1.0**, version code **1**, signed with the **upload key** (SHA-1 `3A:5B:4F:6F:9C:87:32:A5:99:D1:B2:3A:B7:A0:06:88:2B:F6:E4:49`). 64-bit + 32-bit; each phone downloads about **43 MB**. |
| App icon 512×512 | `store_assets/icon_512.png` | for the store listing |
| Feature graphic 1024×500 | `store_assets/feature_graphic_1024x500.png` | for the store listing |
| Phone screenshots (6) | `store_assets/screenshots/` | home, map, slimes, mushroom, river, hug |

## Step 1 — Upload to Internal testing

1. Play Console → **wiwiwi** → **Test and release → Testing → Internal testing**.
2. **Create new release**.
3. If asked about **app signing**: choose **Let Google manage and protect your app signing key** (Play App Signing). This is the normal choice; your upload key stays the one in `C:\Godot\Keys\`.
4. **Upload** `builds/wiwiwi-release.aab`.
5. Release name: `0.1.0 (1)`. Release notes (English): `First test build: World 1 with 10 levels, Cat Shop and new home page.`
6. **Save → Review release.** Fix anything it flags as an error (warnings are OK for internal testing).
7. **Start rollout to Internal testing.**

## Step 2 — Testers

1. Internal testing → **Testers** tab → **Create email list** (e.g. "DigiCraft team") → add your Gmail and your co-founder's Gmail → **Save**.
2. Copy the **opt-in link** shown there and open it on each phone (signed in with that Gmail) → **Accept** → install wiwiwi from the Play Store.
3. ⚠ **Before installing from the Play Store, uninstall the current test build** on your phone. It is signed with a different (debug) key, so Android won't replace it. Uninstalling also clears its local progress (stars) — expected.

## Step 3 — The forms Play Console asks for

Play Console shows a "set up your app" list. Answers that match the game as built:

- **App access:** all functionality is available without special access (no login).
- **Ads:** No, the app has no ads.
- **Content rating** (questionnaire): category **Game**. Answer honestly — cartoon kitten, slimes that squash and fade (no blood), no in-game purchases, no chat, no user-made content, no gambling, no location sharing.
- **Target audience:** ✅ **decided: 13 and over** (choose the 13+ age groups only). Picking any age group **under 13** puts the app under Google's **Families policy** (stricter rules for every SDK in the app, including Play Games). Claude's recommendation for the first test: **13 and over** now, and decide about children before the public launch (we'd check the Families rules for Play Games first).
- **Data safety:** wiwiwi itself collects and shares **no** data (progress and settings stay on the phone; no server). The **Google Play Games Services** library is in the app, so read Google's Data safety guidance for Play Games Services and declare what it says it collects.
- **Privacy policy:** already set — `https://wiwiwi.digicraft.one/privacy`.
- Government / financial / health / news features: **No**.

## Step 4 — Send Claude the app-signing fingerprint

After the first upload Google creates the **app signing key**.

1. Play Console → **Test and release → App integrity → App signing**.
2. Copy the **SHA-1 certificate fingerprint** of the **App signing key** (not the upload key).
3. Send it to Claude. With it we set up **Play Games sign-in** (credentials for the app-signing key, plus the debug key `76:EA:46:81:AC:A0:5C:A5:6A:D6:A1:7E:D3:DA:E8:64:8F:E3:12:08` for test builds) and add you both as **Play Games testers**.

## Not needed yet

Full store listing texts, closed testing (12 testers / 14 days if the account requires it), production access — later steps (plan.md §10).
