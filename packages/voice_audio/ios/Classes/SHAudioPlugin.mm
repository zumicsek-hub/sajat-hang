#import "SHAudioPlugin.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <UIKit/UIKit.h>
#include "../../native/include/voice/processor.hpp"
#include <vector>
#include <cstring>

// The mono effect runs in the engine render graph. No tap-to-player queue.
@interface SHAudioUnit : AUAudioUnit
- (voice::Processor *)processor;
@end

@implementation SHAudioUnit {
  AUAudioUnitBus *_inBus;
  AUAudioUnitBus *_outBus;
  AUAudioUnitBusArray *_inputs;
  AUAudioUnitBusArray *_outputs;
  voice::Processor _processor;
  std::vector<float> _scratch;
  AudioBufferList _inputList;
}
- (instancetype)initWithComponentDescription:(AudioComponentDescription)description
                                    options:(AudioComponentInstantiationOptions)options
                                      error:(NSError **)error {
  self = [super initWithComponentDescription:description options:options error:error];
  if (self) {
    AVAudioFormat *format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:1];
    _inBus = [[AUAudioUnitBus alloc] initWithFormat:format error:error];
    _outBus = [[AUAudioUnitBus alloc] initWithFormat:format error:error];
    if (!_inBus || !_outBus) return nil;
    _inBus.maximumChannelCount = 1; _outBus.maximumChannelCount = 1;
    _inputs = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self busType:AUAudioUnitBusTypeInput busses:@[_inBus]];
    _outputs = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self busType:AUAudioUnitBusTypeOutput busses:@[_outBus]];
    self.maximumFramesToRender = 4096;
  }
  return self;
}
- (AUAudioUnitBusArray *)inputBusses { return _inputs; }
- (AUAudioUnitBusArray *)outputBusses { return _outputs; }
- (voice::Processor *)processor { return &_processor; }
- (BOOL)allocateRenderResourcesAndReturnError:(NSError **)error {
  if (_inBus.format.channelCount != 1 || _outBus.format.channelCount != 1 ||
      _inBus.format.sampleRate != _outBus.format.sampleRate ||
      _inBus.format.commonFormat != AVAudioPCMFormatFloat32 ||
      _outBus.format.commonFormat != AVAudioPCMFormatFloat32) {
    if (error) *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:kAudioUnitErr_FormatNotSupported userInfo:nil];
    return NO;
  }
  if (![super allocateRenderResourcesAndReturnError:error]) return NO;
  _scratch.assign(self.maximumFramesToRender, 0);
  _processor.prepare(_outBus.format.sampleRate);
  return YES;
}
- (AUInternalRenderBlock)internalRenderBlock {
  voice::Processor *processor = &_processor;
  std::vector<float> *scratch = &_scratch;
  AudioBufferList *input = &_inputList;
  return ^AUAudioUnitStatus(AudioUnitRenderActionFlags *flags,
      const AudioTimeStamp *timestamp, AUAudioFrameCount frames, NSInteger bus,
      AudioBufferList *output, const AURenderEvent *events,
      AURenderPullInputBlock pull) {
    (void)bus; (void)events;
    if (!pull || frames > scratch->size() || output->mNumberBuffers != 1) {
      for (UInt32 b = 0; b < output->mNumberBuffers; ++b)
        if (output->mBuffers[b].mData) std::memset(output->mBuffers[b].mData, 0, output->mBuffers[b].mDataByteSize);
      return kAudioUnitErr_CannotDoInCurrentContext;
    }
    input->mNumberBuffers = 1;
    input->mBuffers[0].mNumberChannels = 1;
    input->mBuffers[0].mDataByteSize = frames * sizeof(float);
    input->mBuffers[0].mData = scratch->data();
    const AUAudioUnitStatus status = pull(flags, timestamp, frames, 0, input);
    if (status != noErr) {
      if (!output->mBuffers[0].mData) output->mBuffers[0].mData = scratch->data();
      std::memset(output->mBuffers[0].mData, 0, frames * sizeof(float));
      return status;
    }
    if (!output->mBuffers[0].mData) output->mBuffers[0].mData = scratch->data();
    output->mBuffers[0].mDataByteSize = frames * sizeof(float);
    processor->process(static_cast<const float *>(input->mBuffers[0].mData),
                       static_cast<float *>(output->mBuffers[0].mData), frames);
    return noErr;
  };
}
@end

@implementation SHAudioPlugin {
  AVAudioEngine *_engine;
  AVAudioUnit *_effect;
  SHAudioUnit *_unit;
  BOOL _running;
  BOOL _starting;
  NSUInteger _generation;
  float _gain;
  BOOL _clarity;
  NSString *_reason;
}
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  FlutterMethodChannel *channel = [FlutterMethodChannel methodChannelWithName:@"hu.sajathang/audio" binaryMessenger:registrar.messenger];
  SHAudioPlugin *plugin = [[SHAudioPlugin alloc] init];
  [registrar addMethodCallDelegate:plugin channel:channel];
}
- (instancetype)init {
  self = [super init];
  if (self) {
    _reason = @"idle";
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserver:self selector:@selector(interrupted:) name:AVAudioSessionInterruptionNotification object:nil];
    [center addObserver:self selector:@selector(routeChanged:) name:AVAudioSessionRouteChangeNotification object:nil];
    [center addObserver:self selector:@selector(backgrounded:) name:UIApplicationWillResignActiveNotification object:nil];
    [center addObserver:self selector:@selector(mediaReset:) name:AVAudioSessionMediaServicesWereResetNotification object:nil];
    [center addObserver:self selector:@selector(configurationChanged:) name:AVAudioEngineConfigurationChangeNotification object:nil];
    [AUAudioUnit registerSubclass:SHAudioUnit.class asComponentDescription:[self component] name:@"SajatHang: Offline Voice" version:1];
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    _gain = std::clamp([defaults floatForKey:@"sh.gain"], 0.0f, 6.0f);
    _clarity = [defaults boolForKey:@"sh.clarity"];
  }
  return self;
}
- (AudioComponentDescription)component {
  AudioComponentDescription desc = {};
  desc.componentType = kAudioUnitType_Effect;
  desc.componentSubType = 'shvc'; desc.componentManufacturer = 'Shng';
  return desc;
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; [_engine stop]; }
- (BOOL)isBuiltInRoute {
  AVAudioSessionRouteDescription *route = AVAudioSession.sharedInstance.currentRoute;
  return route.inputs.count == 1 && route.outputs.count == 1 &&
    [route.inputs.firstObject.portType isEqualToString:AVAudioSessionPortBuiltInMic] &&
    [route.outputs.firstObject.portType isEqualToString:AVAudioSessionPortBuiltInSpeaker];
}
- (void)interrupted:(NSNotification *)note {
  if ([note.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue] == AVAudioSessionInterruptionTypeBegan)
    dispatch_async(dispatch_get_main_queue(), ^{ [self stop:@"interrupted"]; });
}
- (void)backgrounded:(NSNotification *)note {
  (void)note;
  if (_running) [self stop:@"background"];
}
- (void)mediaReset:(NSNotification *)note {
  (void)note;
  dispatch_async(dispatch_get_main_queue(), ^{ [self stop:@"mediaReset"]; });
}
- (void)configurationChanged:(NSNotification *)note {
  AVAudioEngine *changed = note.object;
  dispatch_async(dispatch_get_main_queue(), ^{
    if (self->_running && changed == self->_engine) [self stop:@"configurationChanged"];
  });
}
- (void)routeChanged:(NSNotification *)note {
  const NSUInteger reason = [note.userInfo[AVAudioSessionRouteChangeReasonKey] unsignedIntegerValue];
  dispatch_async(dispatch_get_main_queue(), ^{
    if (self->_running && (![self isBuiltInRoute] ||
        reason == AVAudioSessionRouteChangeReasonNewDeviceAvailable ||
        reason == AVAudioSessionRouteChangeReasonOldDeviceUnavailable)) [self stop:@"routeChanged"];
  });
}
- (NSDictionary *)status {
  AVAudioSession *session = AVAudioSession.sharedInstance;
  voice::Processor *p = _unit ? [_unit processor] : nullptr;
  return @{@"running": @(_running), @"starting": @(_starting),
    @"muted": @(p ? p->muted() : YES), @"fault": @(p ? p->fault() : 0),
    @"input": @(p && _running ? p->inputLevel() : 0),
    @"output": @(p && _running ? p->outputLevel() : 0),
    @"gainDb": @(_gain), @"clarity": @(_clarity),
    @"sampleRate": @(_running ? session.sampleRate : 0),
    @"bufferMs": @(_running ? session.IOBufferDuration * 1000 : 0),
    @"reportedIoMs": @(_running ? (session.inputLatency + session.outputLatency) * 1000 : 0),
    @"reason": _reason ?: @"idle", @"route": _running ? @"builtInSpeaker" : @"none"};
}
- (void)stop:(NSString *)reason {
  ++_generation; _starting = NO;
  if (_unit) [_unit processor]->setMuted(true);
  [_engine stop]; _running = NO;
  _engine = nil; _unit = nil; _effect = nil; _reason = reason;
  [AVAudioSession.sharedInstance setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
}
- (void)fail:(NSError *)error result:(FlutterResult)result {
  [self stop:@"error"];
  result([FlutterError errorWithCode:@"audio_start" message:error.localizedDescription ?: @"Audio setup failed" details:nil]);
}
- (void)start:(FlutterResult)result {
  if (_starting || _running) { result([FlutterError errorWithCode:@"busy" message:@"Session is already active" details:nil]); return; }
  _starting = YES;
  const NSUInteger generation = ++_generation;
  [AVAudioSession.sharedInstance requestRecordPermission:^(BOOL granted) {
    dispatch_async(dispatch_get_main_queue(), ^{
      if (generation != self->_generation) { result([FlutterError errorWithCode:@"cancelled" message:@"Start cancelled" details:nil]); return; }
      if (!granted) { [self stop:@"permissionDenied"]; result([FlutterError errorWithCode:@"permission" message:@"Microphone permission is required in Settings." details:nil]); return; }
      if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) {
        [self stop:@"background"]; result([FlutterError errorWithCode:@"inactive" message:@"Return to the app and start again." details:nil]); return;
      }
      AVAudioSession *session = AVAudioSession.sharedInstance;
      NSError *error = nil;
      if (![session setCategory:AVAudioSessionCategoryPlayAndRecord mode:AVAudioSessionModeMeasurement options:AVAudioSessionCategoryOptionDefaultToSpeaker error:&error] ||
          ![session setPreferredSampleRate:48000 error:&error] ||
          ![session setPreferredIOBufferDuration:0.005333333 error:&error] ||
          ![session setActive:YES error:&error]) { [self fail:error result:result]; return; }
      AVAudioSessionPortDescription *microphone = nil;
      for (AVAudioSessionPortDescription *port in session.availableInputs)
        if ([port.portType isEqualToString:AVAudioSessionPortBuiltInMic]) microphone = port;
      if (!microphone || ![session setPreferredInput:microphone error:&error] ||
          ![session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error] || ![self isBuiltInRoute]) {
        [self stop:@"unsupportedRoute"];
        result([FlutterError errorWithCode:@"route" message:@"Disconnect external audio devices. This prototype requires the phone microphone and speaker." details:nil]); return;
      }
      [AVAudioUnit instantiateWithComponentDescription:[self component] options:0 completionHandler:^(AVAudioUnit *effect, NSError *creationError) {
        dispatch_async(dispatch_get_main_queue(), ^{
          if (generation != self->_generation) { result([FlutterError errorWithCode:@"cancelled" message:@"Start cancelled" details:nil]); return; }
          if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive || ![self isBuiltInRoute]) {
            [self stop:@"routeChanged"];
            result([FlutterError errorWithCode:@"inactive" message:@"Return to the app with the built-in speaker, then start again." details:nil]); return;
          }
          if (!effect || creationError) { [self fail:creationError result:result]; return; }
          @try {
            self->_engine = [[AVAudioEngine alloc] init]; self->_effect = effect;
            self->_unit = (SHAudioUnit *)effect.AUAudioUnit;
            [self->_engine attachNode:effect];
            AVAudioInputNode *input = self->_engine.inputNode;
            const double rate = [input outputFormatForBus:0].sampleRate;
            AVAudioFormat *mono = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:rate channels:1];
            [self->_engine connect:input to:effect format:mono];
            [self->_engine connect:effect to:self->_engine.mainMixerNode format:mono];
            [self->_engine prepare];
            [self->_unit processor]->setGainDb(self->_gain);
            [self->_unit processor]->setClarity(self->_clarity);
            [self->_unit processor]->heartbeat();
            NSError *startError = nil;
            if (![self->_engine startAndReturnError:&startError]) { [self fail:startError result:result]; return; }
            self->_running = YES; self->_starting = NO; self->_reason = @"startedMuted";
            result([self status]);
          } @catch (NSException *exception) {
            [self stop:@"error"];
            result([FlutterError errorWithCode:@"audio_graph" message:exception.reason details:nil]);
          }
        });
      }];
    });
  }];
}
- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  if ([call.method isEqualToString:@"start"]) { [self start:result]; return; }
  if ([call.method isEqualToString:@"stop"]) { [self stop:@"stopped"]; result([self status]); return; }
  if ([call.method isEqualToString:@"status"]) { result([self status]); return; }
  if ([call.method isEqualToString:@"heartbeat"]) {
    if (_unit) [_unit processor]->heartbeat();
    result([self status]); return;
  }
  if ([call.method isEqualToString:@"mute"]) {
    id muted = [call.arguments isKindOfClass:NSDictionary.class] ? call.arguments[@"muted"] : nil;
    BOOL shouldMute = ![muted isKindOfClass:NSNumber.class] || [muted boolValue];
    if (_unit) [_unit processor]->setMuted(shouldMute);
    result([self status]); return;
  }
  if ([call.method isEqualToString:@"configure"]) {
    NSDictionary *args = [call.arguments isKindOfClass:NSDictionary.class] ? call.arguments : @{};
    id gain = args[@"gainDb"]; id clarity = args[@"clarity"];
    if (![gain isKindOfClass:NSNumber.class] || !std::isfinite([gain floatValue]) || ![clarity isKindOfClass:NSNumber.class]) {
      result([FlutterError errorWithCode:@"arguments" message:@"Invalid profile" details:nil]); return;
    }
    _gain = std::clamp([gain floatValue], 0.0f, 6.0f); _clarity = [clarity boolValue];
    if (_unit) { [_unit processor]->setGainDb(_gain); [_unit processor]->setClarity(_clarity); }
    [NSUserDefaults.standardUserDefaults setFloat:_gain forKey:@"sh.gain"];
    [NSUserDefaults.standardUserDefaults setBool:_clarity forKey:@"sh.clarity"];
    result([self status]); return;
  }
  result(FlutterMethodNotImplemented);
}
@end
