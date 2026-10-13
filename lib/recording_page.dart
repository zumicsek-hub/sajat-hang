import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:share_plus/share_plus.dart';
import 'recording_controller.dart';

class RecordingPage extends StatelessWidget {
  const RecordingPage({
    super.key,
    required this.controller,
    required this.english,
    required this.start,
    required this.liveActive,
  });
  final RecordingController controller;
  final bool english, liveActive;
  final Future<void> Function() start;
  String t(String hu, String en) => english ? en : hu;

  Future<void> export(BuildContext context, Clip clip, bool enhanced) async {
    final path = enhanced ? clip.enhanced : clip.original;
    try {
      if (!await File(path).exists()) throw const FileSystemException();
      if (Platform.isWindows) {
        final destination = await getSaveLocation(
          suggestedName:
              'SajatHang-${clip.id}-${enhanced ? 'javitott' : 'eredeti'}.wav',
          acceptedTypeGroups: [
            const XTypeGroup(label: 'WAV', extensions: ['wav']),
          ],
        );
        if (destination != null) await XFile(path).saveTo(destination.path);
      } else {
        if (!context.mounted) return;
        final box = context.findRenderObject() as RenderBox;
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(path, mimeType: 'audio/wav')],
            sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t('A fájl exportálása nem sikerült.', 'File export failed.'),
            ),
          ),
        );
      }
    }
  }

  String errorText(String code) => switch (code) {
    'permission' => t(
      'Engedélyezze a mikrofont a rendszer adatvédelmi beállításaiban.',
      'Allow microphone access in system privacy settings.',
    ),
    'record' => t(
      'Nem indult a felvétel. Ellenőrizze a mikrofont és a Windows alapértelmezett bemeneti eszközét.',
      'Recording failed. Check your microphone and default input device.',
    ),
    'format' => t(
      'A felvétel túl rövid, túl hosszú vagy sérült. Az eredeti fájl megmaradt.',
      'The recording is empty, too long or damaged. The original was retained.',
    ),
    'missing' => t(
      'A javított fájl még nem készült el. Válassza a Hangjavítás újra gombot.',
      'The enhanced file is not available. Choose Enhance again.',
    ),
    'play' => t(
      'Nem indult a lejátszás. Ellenőrizze a kimeneti eszközt és a hangerőt.',
      'Playback failed. Check your output device and volume.',
    ),
    _ => t(
      'A művelet nem sikerült. Az eredeti felvételt nem írjuk felül.',
      'Operation failed. Original recordings are not overwritten.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final locked = c.busy || c.recording || liveActive;
    return Padding(
      padding: EdgeInsets.only(bottom: c.recording ? 100 : 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t('Felvétel és visszahallgatás', 'Record and listen'),
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 12),
              Text(
                t(
                  'Vegyen fel legfeljebb 3 perc beszédet. Leállítás után a hangjavítás helyben készül el. Felvétel közben nincs visszhangosítás.',
                  'Record up to 3 minutes. Enhancement runs on this device after stopping. There is no microphone monitoring while recording.',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                t(
                  'Az eredeti és a javított hang automatikusan ezen az eszközön marad, amíg Ön nem törli. Megosztás csak külön gombnyomásra történik.',
                  'Original and enhanced audio are saved on this device until you delete them. Sharing only happens when you choose it.',
                ),
              ),
              const SizedBox(height: 20),
              if (!c.supported)
                Text(
                  t(
                    'A felvétel a telepített Windows- és iPhone-alkalmazásban használható.',
                    'Recording requires the installed Windows or iPhone app.',
                  ),
                ),
              if (liveActive)
                Text(
                  t(
                    'A felvételhez előbb állítsa le az élő módot.',
                    'Stop live mode before recording.',
                  ),
                ),
              if (c.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    errorText(c.error!),
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (c.message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    c.message == 'quiet'
                        ? t(
                            'Nagyon halk vagy néma felvétel. Ellenőrizze a mikrofont, és hallgassa meg az eredetit.',
                            'Very quiet or silent input. Check the microphone and listen to the original.',
                          )
                        : t(
                            'Az eredeti és a javított felvétel mentve.',
                            'Original and enhanced recording saved.',
                          ),
                  ),
                ),
              if (c.busy) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
                Text(t('Feldolgozás…', 'Working…')),
              ],
              if (c.recording) ...[
                Text(
                  '${c.seconds ~/ 60}:${(c.seconds % 60).toString().padLeft(2, '0')} / 3:00',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Semantics(
                  label: t('Mikrofon hangszint', 'Microphone level'),
                  child: LinearProgressIndicator(
                    value: ((c.db + 60) / 60).clamp(0, 1),
                    minHeight: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text('${c.db.toStringAsFixed(0)} dBFS'),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('record-toggle'),
                onPressed: !c.supported || c.busy || liveActive
                    ? null
                    : () => c.recording ? c.stop() : start(),
                icon: Icon(c.recording ? Icons.stop : Icons.mic),
                label: Text(
                  c.recording
                      ? t('Leállítás és hangjavítás', 'Stop and enhance')
                      : t('Új felvétel', 'New recording'),
                ),
              ),
              if (c.playing) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: c.stopPlayback,
                  icon: const Icon(Icons.stop),
                  label: Text(t('Lejátszás leállítása', 'Stop playback')),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                t('Mentett felvételek', 'Saved recordings'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (c.clips.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    t(
                      'Még nincs felvétel. Az Új felvétel gombbal kezdhet.',
                      'No recordings yet. Choose New recording to begin.',
                    ),
                  ),
                ),
              for (final clip in c.clips)
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Divider(),
                      Text(
                        clip.label,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          OutlinedButton.icon(
                            onPressed: locked
                                ? null
                                : () => c.play(clip.original),
                            icon: const Icon(Icons.play_arrow),
                            label: Text(t('Eredeti', 'Original')),
                          ),
                          FilledButton.icon(
                            onPressed: locked
                                ? null
                                : () => c.play(clip.enhanced),
                            icon: const Icon(Icons.play_arrow),
                            label: Text(t('Javított', 'Enhanced')),
                          ),
                          OutlinedButton(
                            onPressed: locked ? null : () => c.enhance(clip),
                            child: Text(t('Hangjavítás újra', 'Enhance again')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          OutlinedButton(
                            onPressed: locked
                                ? null
                                : () => export(context, clip, false),
                            child: Text(
                              t('Eredeti exportálása', 'Export original'),
                            ),
                          ),
                          OutlinedButton(
                            onPressed: locked
                                ? null
                                : () => export(context, clip, true),
                            child: Text(
                              t('Javított exportálása', 'Export enhanced'),
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.delete_outline),
                            label: Text(t('Törlés', 'Delete')),
                            onPressed: locked
                                ? null
                                : () async {
                                    final yes = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text(
                                          t(
                                            'Törli mindkét változatot?',
                                            'Delete both versions?',
                                          ),
                                        ),
                                        content: Text(
                                          t(
                                            'Az eredeti és a javított felvétel törlődik az alkalmazásból.',
                                            'The original and enhanced recording will be deleted from the app.',
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: Text(t('Mégse', 'Cancel')),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: Text(t('Törlés', 'Delete')),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (yes == true) await c.delete(clip);
                                  },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                t(
                  'A hangjavítás hangerő-kiegyenlítés és enyhe szűrés. Nem javítja ki a szavakat, és nem használ mesterséges hangot vagy felhőt.',
                  'Enhancement levels volume and gently filters audio. It does not correct words or use synthetic voices or cloud processing.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
