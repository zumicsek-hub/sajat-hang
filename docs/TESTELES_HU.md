> 2026-10-13: A 0.2.0 felvételi mód és Windows-változat friss leírása: [FELVETEL_HU.md](FELVETEL_HU.md). Az alábbi eredeti leírás a korábbi élő prototípusra vonatkozik.

# Hogyan tudom tesztelni?

## Most, a Windows gépen

Nyissa meg a futó helyi előnézetet: **http://127.0.0.1:8765/**. Ez csak azon a gépen működik, amelyen az előnézeti kiszolgáló fut. Az iPhone-on a 127.0.0.1 az iPhone saját címe, ezért ott ez a hivatkozás nem fogja megnyitni a számítógépen futó előnézetet.

1. Az **Élő mód** lapon nézze meg a gombok méretét és a szövegek olvashatóságát.
2. Az **EN** gombbal váltson angolra, a **HU** gombbal vissza magyarra.
3. A **Beállítások** lapon próbálja ki az **Alap / Enyhe kiemelés** profilokat, valamint a **Halkabb / Erősebb** gombokat.
4. Térjen vissza az **Élő mód** lapra: a választott profil és erősítés megjelenik. Az előnézetben ezek csak a felület állapotát módosítják.
5. A **Felvétel** lap megmutatja a tervezett következő szakaszt. Hangrögzítés még nincs.

Az Indítás és Hang bekapcsolása gomb szándékosan inaktív. Nincs mikrofonengedély, tényleges erősítés vagy hangmentés a böngészőben. A mérők nem animált demóadatokat mutatnak.

Jegyezze fel, ha valamelyik gomb kicsi, valamelyik szöveg nem érthető, vagy fárasztó a kezelése. Ez most a leghasznosabb felhasználói visszajelzés.

Ha az előnézet már nem fut, a projektmappából indítható:

```powershell
flutter pub get
flutter run -d chrome
```

Alternatív Windows indító:

```powershell
& .\tools\preview_windows.ps1
```

## Később, valódi hanggal az iPhone-on

Ehhez Mac + Xcode szükséges az alkalmazás lefordításához és telepítéséhez. A forráskód elő van készítve, de még nem ment át iOS-fordításon. A README részletesen leírja a Mac-es lépéseket.

Telepítés után először fejlesztői környezetben: alacsony telefonhangerő, **Indítás**, a mikrofonjel ellenőrzése, majd **Hang bekapcsolása**. Sípolás, kellemetlen hang vagy bizonytalan működés esetén **Azonnali leállítás**. A kísérleti védelem nem helyettesíti a felügyelt tesztelést.

A késleltetést és a gerjedés előtti hasznos hangerősítést külön kell megmérni a `DEVICE_TESTING.md` alapján. A hangzásról és érthetőségről csak ezek után érdemes logopédussal és valódi felhasználókkal visszajelzést gyűjteni.
