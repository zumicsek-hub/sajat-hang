# Saját Hang — fejlesztői prototípus

Magyar és angol kezelőfelület, iPhone-hangszóróra tervezett helyi beszéderősítéssel. Flutter + AVAudioEngine + C++17. Célkészülék: iPhone 16e, a megadott rendszerverzió iOS 26.5.2.

**Ez az első műszaki prototípus, nem kész segédeszköz.** A Flutter-felület és a C++ mag Windows alatt ellenőrizhető. Az iOS natív kód még nincs Xcode-dal lefordítva vagy iPhone-on kipróbálva. A tényleges késleltetés, a gerjedés előtti hasznos erősítés és a klinikai hatás még nincs igazolva.

## Mi készült el?

- Magyar alapnyelv, EN/HU váltás, nagy gombok, külön bemeneti/kimeneti szintjelző.
- Élő mód: Indítás, Hang bekapcsolása, Némítás, Leállítás. Minden indítás némítva történik.
- Natív iOS forrás: mikrofonengedély, beépített mikrofon/hangszóró, AVAudioEngine és saját AUAudioUnit.
- Közös C++ DSP: magasáteresztő, enyhe EQ, kompresszor, korlátozott kézi erősítés, csúcskorlát.
- Kísérleti sípolásérzékelő, vezérlési watchdog, kézi újraindítást igénylő védelem.
- Helyben mentett iOS profilbeállítások. A böngészős előnézetben csak munkamenet-beállítások vannak.
- Nincs hangmentés, nincs felhő, nincs hangfeltöltés vagy szintetikus beszéd.

**Még nincs:** hangrögzítés, ML, lejátszás/megosztás, zajszűrés, dereverberáció, automatikus hangerőszabályzás, Android Oboe-hangmotor. A Felvétel lap ezt egyértelműen jelzi. Ezek a következő fejlesztési szakaszok, nem működőnek feltüntetett demók.

## Megnézés Windows alatt

Flutter 3.44.1 / Dart 3.12.1 verzióval készült. A projekt gyökérmappájában:

```powershell
flutter pub get
flutter run -d chrome
```

A böngészőben **csak kezelőfelületi előnézet** fut. A Start gomb le van tiltva, a szintjelzők nem mutatnak kitalált mikrofonadatokat. Bejárható a három lap, váltható a nyelv és kipróbálhatók a profilvezérlők. A webes változat nem helyettesíti a natív iPhone-tesztet.

Ha a helyi Flutter `.bat` indítója elakad, használható a mellékelt `tools/preview_windows.ps1`, amely a telepített SDK Dart-futtatójával indítja a Flutter eszközt, és elkülöníti az eszközállapotot.

## Tesztek

```powershell
flutter analyze
flutter test
& .\tools\check_dsp.ps1
```

Az utolsó parancshoz Visual Studio C++ Build Tools szükséges. Más rendszeren CMake használható:

```sh
cmake -S native -B .build/native
cmake --build .build/native --config Release
ctest --test-dir .build/native -C Release --output-on-failure
```

A Dart-tesztek a vezérlési állapotokat, a megszakított indítást, a nyelvváltást és a nagy betűs mobilnézetet vizsgálják. A C++ tesztek a némítást, hibás mintákat, kimeneti korlátot, watchdogot, tónusvédelmet és halk hang megőrzését. Ezek nem bizonyítanak klinikai hatást vagy akusztikus stabilitást.

## Saját Mac nélkül: távoli próbafordítás

A mellékelt `codemagic.yaml` előkészíti a kézi, aláírás nélküli iOS-fordítást. Részletes lépések: [Codemagic útmutató](docs/CODEMAGIC_HU.md). A távoli futás még nem történt meg. A próbafordítás eredménye nem telepíthető az iPhone-ra; ehhez később Apple-aláírás és például TestFlight kell.

## Amikor elérhető lesz egy Mac

1. Másolja át a forrásprojektet vagy bontsa ki a forrás-ZIP-et. A Windows alatt keletkezett `.dart_tool`, `build`, `ios/Flutter/Generated.xcconfig` és egyéb generált fájlokat ne vigye át; a ZIP nem tartalmazza ezeket.
2. Telepítsen Fluttert, az iPhone rendszerével kompatibilis Xcode-ot és CocoaPodst. Ellenőrzés: `flutter doctor -v`.
3. A projektben futtassa: `flutter pub get`, majd `flutter build ios --debug --no-codesign`. Ez az első tényleges natív fordítási kapu; Windows alatt nem volt elvégezhető.
4. Nyissa meg az `ios/Runner.xcworkspace` fájlt Xcode-ban. Állítsa be a saját fejlesztői csapatot és szükség esetén egyedi bundle ID-t.
5. Csatlakoztassa USB-n az iPhone-t, engedélyezze a szükséges fejlesztői módot/bizalmat, és indítsa a Runner célt.
6. Kezdjen alacsony telefonhangerővel. Indítás után csak a mikrofon mérője aktív; a hanghoz külön érintse meg a Hang bekapcsolása gombot.
7. Kövesse a `docs/DEVICE_TESTING.md` ellenőrzőlistát. Automatikus újraindítás nincs.

## Fájlok

| Hely | Tartalom |
|---|---|
| `lib/main.dart` | Magyar/angol, akadálymentesíthető Flutter UI |
| `lib/audio_controller.dart` | Vezérlési állapot, heartbeat, prioritásos leállítás |
| `packages/voice_audio/ios/Classes/` | Natív iOS plugin és AU renderelés |
| `packages/voice_audio/native/include/voice/processor.hpp` | Hordozható C++ DSP |
| `native/tests/` | DSP-tesztek |
| `test/` | Flutter vezérlési és felületi tesztek |
| `docs/ARCHITECTURE.md` | Pontos megvalósítás, korlátok, következő szakasz |
| `docs/DEVICE_TESTING.md` | iPhone-os mérési és használhatósági protokoll |
| `docs/VALIDATION.md` | A ténylegesen elvégzett ellenőrzések |

Nem gyógymód és nem helyettesíti a logopédiai ellátást. A jogi besorolást a tervezett rendeltetés alapján kell tisztázni; a „nem orvostechnikai eszköz” felirat önmagában nem dönt erről. A prototípus nem alkalmas felügyelet nélküli segédeszköz-használatra.
