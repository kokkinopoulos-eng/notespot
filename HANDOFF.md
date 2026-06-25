# SpotNote AI — Developer Handoff Prompt

## Ο DEVELOPER
Μπάμπης (BabKok / Κοκκινόπουλος Χαράλαμπος), indie Android dev, Ελλάδα.
Δουλεύω ΜΟΝΟ στα Ελληνικά. Άμεσος, αποτελεσματικός, μισώ την επανάληψη και τις πολλές ερωτήσεις.
Repo: C:\dev\notespot (github.com/kokkinopoulos-eng/notespot)
Test device: Samsung S25 Ultra (SM-S938B, Android 14/15)

## Η ΕΦΑΡΜΟΓΗ — SpotNote AI
Flutter note-taking app για Android. Μία εφαρμογή, freemium μοντέλο.
Package: gr.webdevelopment.notespot | Flavor: free (το ΜΟΝΑΔΙΚΟ ενεργό — το pro flavor ΚΑΤΑΡΓΗΘΗΚΕ)

### Τι κάνει:
- Σημειώσεις κειμένου με notebook UI (γραμμές + κόκκινη γραμμή περιθωρίου)
- Ζωγραφική / S Pen (drawing canvas)
- Split view: κείμενο πάνω + σχέδιο κάτω (ρυθμιζόμενο διαχωριστικό)
- Φωνητικές σημειώσεις (εγγραφή + transcription)
- Φωτογραφίες (camera + gallery) — FREE
- OCR (κείμενο από εικόνες) — FREE
- Math recognition (χειρόγραφες πράξεις → αποτέλεσμα) — FREE
- Eva: on-device AI κατηγοριοποίηση + auto-title — OFFLINE, ΠΑΝΤΑ FREE, ΔΕΝ ΑΓΓΙΖΕΙΣ
- Αρχειοθέτηση, Κάδος ανακύκλωσης 30 ημέρες — FREE
- Backup/Restore (Drive/Dropbox/OneDrive) — FREE
- Αναζήτηση, color tags, αγαπημένα — FREE

### PREMIUM ONLY (IAP €4.99, product: notespot_premium_unlock):
Μόνο ό,τι καλεί CloudAiService (Anthropic/Google/OpenAI API — BYOK):
1. ✨ Ρώτησε τον AI — chat με Claude/Gemini/GPT μέσα σε σημείωση
2. 🪄 AI Εργαλεία — ορθογραφικό, σύνοψη, βελτίωση κειμένου
3. Cloud AI κατηγοριοποίηση — πιο έξυπνη από Eva (χρειάζεται API key)
4. Δομή με AI — αναδιοργάνωση φωνητικής σημείωσης
5. AI σύνοψη στο Smart Voice
6. AI Provider / BYOK settings (Claude/Gemini/OpenAI key)
7. PhotoSpot — AI περιγραφή φωτογραφίας (ΣΕ ΥΛΟΠΟΙΗΣΗ)

### ΚΑΝΟΝΑΣ ΚΛΕΙΔΙ — free vs premium:
- Eva (on-device) = ΠΑΝΤΑ FREE. Auto-title, κατηγορία από Eva = FREE. ΜΗΝ το αγγίξεις.
- CloudAiService = ΠΑΝΤΑ PREMIUM. Αν κάτι καλεί CloudAiService → είναι Premium.
- Το kCloudAiEnabled = PremiumService.instance.isPremium (runtime, όχι compile-time)

## ΚΑΝΟΝΕΣ ΕΡΓΑΣΙΑΣ — ΜΗΝ ΤΟΥΣ ΑΓΝΟΗΣΕΙΣ

### Στυλ επικοινωνίας:
- ΕΝΑ βήμα τη φορά — ποτέ πολλά steps μαζί
- ΜΗΝ ζητάς επαλήθευση αν δεν είναι ΑΠΟΛΥΤΩΣ απαραίτητο
- ΜΗΝ ζητάς ποτέ full file outputs ή tree listings
- Διάβαζε μόνος σου με Select-String μόνο τις γραμμές που χρειάζεσαι
- Ποτέ Get-Content χωρίς Select-Object ή Select-String
- Ψάξε πρώτα στον κώδικα, ρώτα μόνο αν δεν βρεις
- Πριν οποιαδήποτε αλλαγή: τρέξε μόνος σου Select-String στο αρχείο

### PowerShell patches:
- ΠΑΝΤΑ $homeFile (ΟΧΙ $home — reserved variable στο PowerShell!)
- Line-based με [System.Collections.ArrayList]
- [IO.File]::WriteAllText με $utf8NoBom
- Greek strings ως \uXXXX unicode escapes
- Ποτέ pipe OR (|) στο Select-String — χρησιμοποίησε -Pattern με regex

### Build/Install:
- flutter analyze ΠΑΝΤΑ πριν build
- Stale APK trap: αν build FAILS → adb install βάζει ΠΑΛΙΟ APK. ΠΑΝΤΑ επιβεβαίωσε "✓ Built" πριν install
- Gradle cache corruption: αν fails με zipflinger/Archive → taskkill /F /IM java.exe + Remove-Item "$env:USERPROFILE\.gradle\caches" -Recurse -Force + ξανabuild
- adb uninstall: ΠΑΝΤΑ adb shell pm uninstall --user 0 pkg (όχι adb uninstall)
- Προτίμησε flutter run αντί APK install — αποφεύγει stale/multi-user προβλήματα
- Code CLI (claude) για πολύπλοκες multi-file αλλαγές

## ΤΕΧΝΙΚΟ ΠΕΡΙΒΑΛΛΟΝ
- Flutter flavor: free (gr.webdevelopment.notespot) — ΜΟΝΑΔΙΚΟ ενεργό
- Python: C:\Users\hkokin.MELISSA\AppData\Local\Python\bin\python.exe
- Signing key: υπάρχει στο key.properties
- Run debug: flutter run --flavor free
- Run release: flutter run --flavor free --release
- Build AAB: flutter build appbundle --flavor free --release
- Build APK: flutter build apk --flavor free --release

## ΑΡΧΙΤΕΚΤΟΝΙΚΗ
- lib/core/feature_flags.dart: bool get kCloudAiEnabled => PremiumService.instance.isPremium;
- lib/services/premium_service.dart: IAP singleton, product notespot_premium_unlock, debug bypass (if(kDebugMode) _isPremium=true), testTogglePremium() (TEST ONLY)
- lib/services/cloud_ai_service.dart: CloudAiService — όλες οι AI κλήσεις (Claude/Gemini/OpenAI)
- lib/services/eva_service.dart: Eva — on-device, FREE, ΜΗΝ ΑΓΓΙΖΕΙΣ
- lib/widgets/locked_feature.dart: LockedWrapper — PRO chip πορτοκαλί, 50% opacity
- χlib/widgets/paywall_sheet.dart: showPaywall() bottom sheet
- lib/screens/capture/note_editor_screen.dart: κύριος editor (κείμενο + σχέδιο + AI chat)
- lib/screens/home/home_screen.dart: λίστα σημειώσεων + create menu (+)
- lib/screens/home/settings_tab.dart: ρυθμίσεις (AI section, backup, κλπ)

## ΚΑΤΑΣΤΑΣΗ (committed στο main, HEAD=00ca9ef)
- ✅ Freemium λειτουργεί (locks, paywall, reactive rebuild)
- ✅ AI chat πλήρεις απαντήσεις (_parseTurns fix)
- ✅ Unified ✨AI menu (PopupMenuButton — Ρώτησε τον AI + AI Εργαλεία)
- ✅ Icons (πράσινο launcher, μπλε in-app)
- ✅ Native splash καθαρό
- ✅ Test toggle στις Ρυθμίσεις (DEBUG ONLY)
- Backup: branch backup-before-freemium, tag v1.0.0-stable

## TODO — ΑΦΑΙΡΕΣΗ ΠΡΙΝ PRODUCTION
1. testTogglePremium() στο premium_service.dart
2. TEST toggle tile στο settings_tab.dart (// TEST ONLY - REMOVE BEFORE PRODUCTION)
3. Debug bypass if(kDebugMode) στο premium_service.dart init
4. Debug badge "Free P=false D=false" στο home_screen.dart

## ΕΠΟΜΕΝΟ FEATURE — PhotoSpot
AI ανάλυση φωτογραφίας, PREMIUM ONLY:
- Entry #1: + menu στο home → "📷 Από φωτογραφία (AI)" → gallery/camera → AI περιγραφή → νέα σημείωση
- Entry #2: μέσα σε σημείωση με φωτο → ✨AI menu → "📷 Περίγραψε την εικόνα" → AI περιγραφή append
- Αποτέλεσμα: φωτο ΜΕΝΕΙ στη σημείωση + AI περιγραφή ως κείμενο + αυτόματη κατηγοριοποίηση
- CloudAiService.analyzeImage() υπάρχει ήδη
- Η απλή φωτογραφία (χωρίς AI) είναι FREE και υπάρχει ήδη — ΜΗΝ την αγγίξεις
- Entry #1: LockedWrapper στο νέο menu item μόνο (το υπάρχον photo item μένει FREE)
- Entry #2: LockedWrapper στο νέο AI menu item

## PLAY CONSOLE (εκκρεμεί — φορολογικά)
- IAP product: notespot_premium_unlock €4.99 (δεν έχει δημιουργηθεί ακόμα)
- Data safety update απαιτείται: IAP + data sharing με AI providers
- Internal testing upload + license tester για δοκιμή πραγματικής αγοράς
- ΜΗΝ ανεβάσεις production μέχρι να αφαιρεθούν τα TEST items