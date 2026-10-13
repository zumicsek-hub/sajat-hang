# Saját Hang 0.2 — Windows és iPhone felvételi mód

## Windows: első próba

1. A SajatHang-Windows mappában indítsa el a sajat_hang.exe fájlt. A DLL-ek és a data mappa maradjanak mellette. ZIP esetén előbb az egész csomagot bontsa ki.
2. A program a Felvétel lapon indul. Kattintson az Új felvétel gombra, és beszéljen 10–20 másodpercig. A mikrofon szintjelzőjének mozognia kell.
3. Kattintson a Leállítás és hangjavítás gombra. Feldolgozás után az Eredeti és a Javított gombokkal hallgassa vissza a két változatot.
4. Az Exportálása gombbal válasszon mentési helyet a WAV fájlnak. A Törlés mindkét alkalmazáson belüli változatot törli; az exportált másolatot nem.

Ha nem mozog a szintjelző: Windows Beállítások → Rendszer → Hang → Bemenet: válassza ki és tesztelje a mikrofont. Az Adatvédelem és biztonság → Mikrofon alatt engedélyezze az asztali alkalmazások hozzáférését. Ha visszajátszáskor nincs hang, ellenőrizze a Windows kimeneti eszközét és hangerőkeverőjét.

A telepített alkalmazás működik hanggal; a régi localhost böngészőlap továbbra is csak előnézet.

## iPhone frissítése

A felvetel-frissites.zip kibontott tartalmát töltse fel a GitHub-kódtár gyökerébe, a lib, ios, packages, test és docs mappaszerkezet megtartásával. A pubspec.yaml és pubspec.lock is cserélendő. Indítsa el Codemagicben a Sajat Hang - TestFlight folyamatot. A 0.2.0 build sikeres feldolgozása után frissítsen az iPhone TestFlight alkalmazásában.

Felvétel előtt az élő módot állítsa le. A felvétel és a visszajátszás nem használhatja egyszerre a mikrofont. A megosztólapon a Mentés a Fájlokba lehetőség is használható. A megosztás célját a felhasználó választja; ha felhős szolgáltatást választ, az exportált másolat oda kerülhet.

## Mi történik a hanggal?

- Natív mikrofonrögzítés: Windows Media Foundation, iPhone AVFoundation a record csomagon keresztül. PCM16 WAV, mono, kért 48 kHz. A WAV tényleges mintavételezését olvassuk feldolgozáskor.
- Legfeljebb 3 perc egy felvétel. Háttérbe kerüléskor vagy telefonos hangmegszakításkor lezárjuk a felvételt; nincs automatikus újraindítás.
- Feldolgozás külön Dart isolate-ban: 75 Hz magasáteresztő, +2 dB enyhe 3 kHz kiemelés, 20 ms keretek energiája alapján legfeljebb 18 dB erősítés, 2:1 kompresszió és -2 dBFS csúcshatár. Ez nem LUFS-mérés és nem fizikai hangerőkorlát.
- Az eredeti WAV változatlan marad. A javított fájl új fájl, azonos időtartammal. A csendet nem erősítjük fel; a háttérzajt azonban a módszer a beszéddel együtt erősítheti.
- Ez DSP-hangjavítás, nem ML, nem beszédfelismerés, nem kiejtés-helyreállítás. Nem változtat szavakat, ritmust vagy hangmagasságot. Enyhe hangszínváltozás lehetséges.

A felvétel utáni DSP nem valós idejű, ezért Dart isolate megfelelő hozzá. Az iPhone élő hangútja továbbra is natív C++, a hangminták ott nem jutnak Dartba. A Windows élő hangútja még nincs megvalósítva.

## Adatkezelés

Nincs bejelentkezés, analitika vagy automatikus hangfeltöltés. A felvételek az alkalmazás saját Application Support/recordings mappájában maradnak újraindítás után is. iOS-en ez a mappa kizárt a rendszer biztonsági mentéséből. Windows saját mentőprogramjai ettől függetlenül készíthetnek másolatot. A helyi felvételek külön alkalmazásjelszóval nincsenek titkosítva; az operációs rendszer fiók- és lemezelérési védelme érvényes. Az exportált másolatok kezeléséért a választott mentési hely felel.

## Tesztelési korlátok

A Windows-fordítás és az automatizált DSP/vezérlési tesztek nem igazolják a beszédérthetőség javulását. A felhasználó mikrofonjával és hangszórójával még szükséges egy kézi felvétel-visszajátszás próba. A 0.2.0 iOS natív fordítása Codemagicben és a fizikai iPhone-próba külön ellenőrzés. A korábbi élő iPhone-kimenet némaságának oka még nincs igazolva.
