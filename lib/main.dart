import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'audio_controller.dart';

void main() => runApp(const SajatHangApp());

const ink = Color(0xFF183B36);
const green = Color(0xFF116B5D);
const canvas = Color(0xFFF4F6F2);

class SajatHangApp extends StatefulWidget {
  const SajatHangApp({super.key, this.controller});
  final AudioController? controller;
  @override
  State<SajatHangApp> createState() => _SajatHangAppState();
}

class _SajatHangAppState extends State<SajatHangApp>
    with WidgetsBindingObserver {
  late final AudioController audio = widget.controller ?? AudioController();
  bool english = false;
  int page = 0;
  String t(String hu, String en) => english ? en : hu;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Native iOS also stops independently. Inactive can be the permission alert;
    // stop that state only if a live session is already running.
    if (state != AppLifecycleState.resumed && audio.running) {
      unawaited(audio.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.controller == null) audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Saját Hang',
    locale: Locale(english ? 'en' : 'hu'),
    supportedLocales: const [Locale('hu'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: canvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: green,
        surface: Colors.white,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 36,
          height: 1.12,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        titleLarge: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        bodyLarge: TextStyle(fontSize: 18, height: 1.5, color: ink),
        bodyMedium: TextStyle(fontSize: 16, height: 1.45, color: ink),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 60),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 60),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    ),
    home: AnimatedBuilder(
      animation: audio,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          backgroundColor: canvas,
          toolbarHeight: 80,
          title: const Row(
            children: [
              Icon(Icons.graphic_eq_rounded, color: green, size: 32),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Saját Hang',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, color: ink),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => setState(() => english = !english),
              style: TextButton.styleFrom(minimumSize: const Size(64, 56)),
              child: Text(
                english ? 'HU' : 'EN',
                semanticsLabel: english ? 'Magyar nyelv' : 'Switch to English',
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!audio.supported) ...[
                      _notice(
                        Icons.desktop_windows_outlined,
                        t(
                          'Felületi előnézet · nincs hangfeldolgozás',
                          'Interface preview · no audio processing',
                        ),
                        t(
                          'Az élő hang az iPhone-ra telepített alkalmazásban tesztelhető. Az Android hangmotor még nincs bekötve.',
                          'Live audio requires the app installed on an iPhone. The Android audio engine is not connected yet.',
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (audio.errorCode != null) ...[
                      _notice(
                        Icons.error_outline,
                        t(
                          'A hangkapcsolat ellenőrzést igényel',
                          'Audio needs attention',
                        ),
                        audio.errorCode == 'permission'
                            ? t(
                                'Engedélyezze a mikrofont az iPhone Beállításaiban, majd indítsa újra.',
                                'Allow microphone access in iPhone Settings, then start again.',
                              )
                            : t(
                                'Állítsa le, majd indítsa újra. Ha ismét jelentkezik, kérjen segítséget. Hibakód: ${audio.errorCode}',
                                'Stop, then start again. If the problem returns, ask for help. Code: ${audio.errorCode}',
                              ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (page == 0)
                      _live(context)
                    else if (page == 1)
                      _recording(context)
                    else
                      _settings(context),
                    const SizedBox(height: 24),
                    Text(
                      t(
                        'Fejlesztői prototípus · nem helyettesíti a logopédiai ellátást.',
                        'Development prototype · does not replace speech-language therapy.',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF53665F),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: page,
          onDestinationSelected: (value) => setState(() => page = value),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.graphic_eq),
              label: t('Élő mód', 'Live'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.mic_none_rounded),
              label: t('Felvétel', 'Recording'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.tune_rounded),
              label: t('Beállítások', 'Settings'),
            ),
          ],
        ),
        // The emergency action remains reachable on every page, outside scrolling.
        bottomSheet: audio.running || audio.busy
            ? SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => unawaited(audio.stop()),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF9C302C),
                      ),
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: Text(t('Azonnali leállítás', 'Stop immediately')),
                    ),
                  ),
                ),
              )
            : null,
      ),
    ),
  );

  Widget _notice(IconData icon, String title, String body) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF2D8),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF755119)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(body),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _card(Widget child, {Color color = Colors.white}) => Material(
    color: color,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: const BorderSide(color: Color(0xFFE0E7E1)),
    ),
    child: Padding(padding: const EdgeInsets.all(24), child: child),
  );

  Widget _live(BuildContext context) {
    final status = audio.fault != 0
        ? t('Védelem aktív', 'Protection active')
        : audio.running
        ? (audio.muted
              ? t('Hang némítva', 'Sound muted')
              : t('Élő erősítés', 'Live amplification'))
        : t('Készen a beszélgetésre', 'Ready to talk');
    final controls = _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _badge(
                Icons.phonelink_lock,
                t('Csak a telefonon', 'On-device only'),
              ),
              _badge(
                Icons.speaker_phone,
                t('Telefonhangszóró', 'Phone speaker'),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Semantics(
            liveRegion: true,
            child: Text(
              status,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            t(
              'Az Ön hangja, egy kicsit érthetőbben.',
              'Your voice, a little clearer.',
            ),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          if (audio.fault != 0) ...[
            _notice(
              Icons.volume_off_outlined,
              t('A kimenet elnémult', 'Output has been muted'),
              audio.fault == 1
                  ? t(
                      'Sípolás gyanúja. Csökkentse a hangerőt és változtasson a telefon helyzetén. Ezután állítsa le és indítsa újra.',
                      'Possible feedback. Lower the volume and reposition the phone. Then stop and restart.',
                    )
                  : t(
                      'A vezérlés vagy a hangfolyam megszakadt. Állítsa le, majd indítsa újra.',
                      'The controller or audio stream was interrupted. Stop, then restart.',
                    ),
            ),
            const SizedBox(height: 18),
          ],
          FilledButton.icon(
            key: const Key('start-stop'),
            onPressed: !audio.supported || audio.busy
                ? null
                : () => audio.running ? audio.stop() : audio.start(),
            icon: Icon(
              audio.running ? Icons.stop_rounded : Icons.play_arrow_rounded,
            ),
            label: Text(
              audio.busy
                  ? t('Kapcsolódás…', 'Connecting…')
                  : audio.running
                  ? t('Leállítás', 'Stop')
                  : t('Indítás', 'Start'),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('mute'),
            onPressed:
                !audio.running ||
                    (audio.muted && (audio.busy || audio.fault != 0))
                ? null
                : () => audio.muted ? audio.unmute() : audio.mute(),
            icon: Icon(
              audio.muted
                  ? Icons.volume_up_outlined
                  : Icons.volume_off_outlined,
            ),
            label: Text(
              audio.muted
                  ? t('Hang bekapcsolása', 'Enable sound')
                  : t('Némítás', 'Mute'),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            t(
              'Indításkor a hang némítva marad. Kezdjen alacsony telefonhangerővel, és tartsa szabadon a mikrofont.',
              'Audio starts muted. Begin with low phone volume and keep the microphone uncovered.',
            ),
            style: const TextStyle(fontSize: 14),
          ),
          if (!audio.running &&
              !['idle', 'stopped'].contains(audio.reason)) ...[
            const SizedBox(height: 12),
            Text(
              t(
                'A munkamenet megállt. Az újraindítás mindig kézi.',
                'The session stopped. Restart is always manual.',
              ),
            ),
          ],
        ],
      ),
    );
    final levels = _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t('Hangszintek', 'Sound levels'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            t(
              'A mikrofon és az erősített kimenet külön látható.',
              'Microphone and amplified output are shown separately.',
            ),
          ),
          const SizedBox(height: 28),
          _meter(t('Mikrofon', 'Microphone'), audio.input),
          const SizedBox(height: 24),
          _meter(t('Kimenet', 'Output'), audio.output),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            t('Aktív profil', 'Active profile'),
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            audio.clarity
                ? t('Enyhe kiemelés', 'Gentle clarity')
                : t('Alap', 'Basic'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            t(
              'Erősítés: +${audio.gainDb.toStringAsFixed(0)} dB',
              'Gain: +${audio.gainDb.toStringAsFixed(0)} dB',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            t(
              'Nincs hangrögzítés. Nincs feltöltés.',
              'No recording. No uploads.',
            ),
            style: const TextStyle(fontWeight: FontWeight.w600, color: green),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            t('ÉLŐ MÓD / 01', 'LIVE MODE / 01'),
            style: const TextStyle(
              fontSize: 12,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
              color: green,
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth >= 800
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: controls),
                    const SizedBox(width: 20),
                    Expanded(flex: 4, child: levels),
                  ],
                )
              : Column(
                  children: [controls, const SizedBox(height: 20), levels],
                ),
        ),
        if (audio.running || audio.busy) const SizedBox(height: 96),
      ],
    );
  }

  Widget _badge(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFEDF4EE),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: green),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  Widget _meter(String label, double level) {
    final db = level > 0 ? 20 * math.log(level) / math.ln10 : -60.0;
    final value = ((db + 60) / 60).clamp(0.0, 1.0);
    final reading = audio.running
        ? '${db.clamp(-60, 0).toStringAsFixed(0)} dBFS'
        : '—';
    return Semantics(
      label: '$label: $reading',
      child: ExcludeSemantics(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(reading, style: const TextStyle(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: audio.running ? value : 0,
                minHeight: 14,
                color: green,
                backgroundColor: const Color(0xFFE5ECE6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recording(BuildContext context) => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.mic_none_rounded, size: 40, color: green),
        const SizedBox(height: 20),
        Text(
          t('Felvétel', 'Recording'),
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 16),
        _badge(
          Icons.construction_outlined,
          t('Következő fejlesztési szakasz', 'Next development phase'),
        ),
        const SizedBox(height: 20),
        Text(
          t(
            'Ez a prototípus még nem rögzít hangot.',
            'This prototype does not record audio yet.',
          ),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Text(
          t(
            'A tervezett folyamat: felvétel → helyi hangjavítás → eredeti és javított változat összehasonlítása → mentés vagy megosztás.',
            'Planned flow: record → on-device enhancement → compare original and enhanced → save or share.',
          ),
        ),
        const SizedBox(height: 20),
        Text(
          t(
            'Az eredeti felvétel megmarad. Felhőalapú feldolgozás nem lesz.',
            'The original will be retained. There will be no cloud processing.',
          ),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        if (audio.running || audio.busy) const SizedBox(height: 96),
      ],
    ),
  );

  Widget _settings(BuildContext context) => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t('Egyszerű beállítások', 'Simple settings'),
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 12),
        Text(
          t(
            'Szükség esetén kérje gondozója vagy logopédusa segítségét.',
            'Ask a caregiver or speech-language therapist for help if needed.',
          ),
        ),
        const SizedBox(height: 24),
        Text(
          t('Profil', 'Profile'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _profile(t('Alap', 'Basic'), false),
            _profile(t('Enyhe kiemelés', 'Gentle clarity'), true),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          t(
            'Erősítés: +${audio.gainDb.toStringAsFixed(0)} dB',
            'Gain: +${audio.gainDb.toStringAsFixed(0)} dB',
          ),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: audio.busy || audio.gainDb <= 0
                  ? null
                  : () => audio.configure(audio.gainDb - 1, audio.clarity),
              icon: const Icon(Icons.remove),
              label: Text(t('Halkabb', 'Lower')),
            ),
            OutlinedButton.icon(
              onPressed: audio.busy || audio.gainDb >= 6
                  ? null
                  : () => audio.configure(audio.gainDb + 1, audio.clarity),
              icon: const Icon(Icons.add),
              label: Text(t('Erősebb', 'Higher')),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          t(
            'A kiemelés és az erősítés együtt legfeljebb 6 dB. Ez nem a hangszóró fizikai hangerejének mérése.',
            'Gain and EQ are capped at 6 dB together. This is not a measurement of the speaker’s acoustic loudness.',
          ),
        ),
        const SizedBox(height: 16),
        Text(
          audio.supported
              ? t(
                  'A beállítások automatikusan, helyben mentődnek.',
                  'Settings are saved automatically on this device.',
                )
              : t(
                  'Előnézet: a beállítások csak erre a munkamenetre érvényesek.',
                  'Preview: settings apply to this session only.',
                ),
        ),
        const SizedBox(height: 24),
        const Divider(),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(t('Műszaki adatok', 'Technical details')),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${t('Mintavétel', 'Sample rate')}: ${audio.sampleRate == 0 ? '—' : '${audio.sampleRate.toStringAsFixed(0)} Hz'}\n'
                  '${t('I/O puffer', 'I/O buffer')}: ${audio.bufferMs == 0 ? '—' : '${audio.bufferMs.toStringAsFixed(2)} ms'}\n'
                  '${t('Rendszer által jelzett I/O késés', 'OS-reported I/O latency')}: ${audio.reportedIoMs == 0 ? '—' : '${audio.reportedIoMs.toStringAsFixed(1)} ms'}\n\n'
                  '${t('A teljes akusztikus késés még nincs megmérve. Cél: 50 ms alatt.', 'Total acoustic latency has not been measured. Target: under 50 ms.')}',
                ),
              ),
            ),
          ],
        ),
        if (audio.running || audio.busy) const SizedBox(height: 96),
      ],
    ),
  );

  Widget _profile(String label, bool clarity) => OutlinedButton.icon(
    onPressed: audio.busy ? null : () => audio.configure(audio.gainDb, clarity),
    icon: Icon(
      audio.clarity == clarity
          ? Icons.radio_button_checked
          : Icons.radio_button_unchecked,
    ),
    label: Text(label),
  );
}
