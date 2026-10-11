# iOS próbafordítás saját Mac nélkül

## Mit készít ez a folyamat?

A `codemagic.yaml` egy kézzel indítható, legfeljebb 30 perces Mac-fordítást ír le. Ellenőrzi a Flutter-kódot, lefuttatja a Flutter- és C++-teszteket, majd megpróbálja lefordítani a natív iPhone-alkalmazást. Flutter 3.44.1-et használ; az Xcode a Codemagic aktuális stabil `latest` változata, pontos verzióját naplózzuk. Az első sikeres futás után érdemes azt a konkrét Xcode-verziót rögzíteni.

**Nincs Apple-aláírás vagy TestFlight-feltöltés. A kapott ZIP nem telepíthető az iPhone-ra.** Ez először azt dönti el, hogy a natív kód lefordul-e. Apple Developer-előfizetés és Apple API-kulcs ehhez nem szükséges. A Codemagic aktuális használati keretét/díját indítás előtt ellenőrizze; a 30 perc időkorlát, nem árgarancia.

## 1. A forrás elhelyezése privát kódtárban

1. Bontsa ki a mellékelt `sajat_hang_prototype.zip` fájlt.
2. GitHubon hozzon létre egy **privát** kódtárat, például `sajat-hang` néven.
3. A kibontott `sajat_hang` mappa **tartalmát** tegye a kódtár gyökerébe. A `pubspec.yaml`, `codemagic.yaml`, `lib`, `ios` és `packages` ugyanazon a szinten legyen. A ZIP-et önmagában feltölteni nem elég.
4. A teljes forrás feltöltéséhez használhat GitHub Desktopot vagy Gitet. A `.gitignore` és `.metadata` rejtett fájlokat is tartsa meg. Ne töltsön fel `build`, `.build`, `.dart_tool`, `local.properties`, hangfelvétel vagy jelszó/API-kulcs fájlokat.

Ha GitHub-fiókja még nincs, a regisztrációt és a szolgáltatási feltételek elfogadását saját maga végezze el. Az alkalmazás forráskódja a GitHubhoz és a fordításhoz Codemagichez kerül, hangadat nem.

## 2. Codemagic csatlakoztatása

1. Lépjen be a https://codemagic.io oldalon, vagy regisztráljon.
2. Válassza az **Add application** lehetőséget, és kapcsolja hozzá a privát kódtárat. Ha választható, csak ehhez az egy kódtárhoz adjon hozzáférést.
3. Válassza ki a kódtárat és a YAML-alapú beállítást. A felület elnevezései változhatnak; a lényeg, hogy a kódtár gyökerében lévő `codemagic.yaml` legyen a konfiguráció.
4. Keresse meg a konfigurációt a megfelelő ágon (**Check for configuration file**, ha megjelenik).
5. Válassza az **ios-unsigned-check** folyamatot, majd indítson egy futást.

Nincs automatikus push-trigger, ezért egy új commit nem indít magától új költséges futást. A konfiguráció nem tartalmaz publikálást vagy titkos változókat.

## 3. Az eredmény értelmezése

- **Siker:** minden lépés zöld; a `Runner-unsigned.zip` és a naplók letölthetők. Ez fordítási siker, nem iPhone-os akusztikai vagy klinikai teszt.
- **Hiba:** a hibás lépés naplójából az első érdemi hibát kell javítani. Az összegyűjtött `build_logs` fájlok segítenek. Ne másoljon ide jelszót, hozzáférési tokent vagy más titkot.
- **Időkorlát:** a futás megszakad; először azt kell megnézni, függőségletöltés, fordítás vagy teszt akadt-e el.

A projekt natív része még nem volt Apple-fordítóval ellenőrizve, ezért az első futás feltárhat javítandó hibákat. A CocoaPods plugin és a Flutter generált Swift Package integráció együttműködését is ez a futás ellenőrzi.

## 4. Csak a sikeres próbafordítás után

Az iPhone-ra telepíthető TestFlight-verzió külön következő lépés: Apple Developer-tagság, App Store Connect alkalmazás, aláírás, majd egy külön terjesztési folyamat szükséges. Ezekhez később, a fiókokban kezeljük a jogosultságokat; jelszót vagy privát kulcsot nem kell chatbe küldeni. A hangfeldolgozás a telepített alkalmazásban továbbra is helyben történik.

## Források

- https://docs.codemagic.io/yaml-quick-start/building-a-flutter-app/
- https://docs.codemagic.io/yaml-basic-configuration/yaml-getting-started/

Állapot: a konfiguráció helyben előkészítve; távoli futás még nem történt.
