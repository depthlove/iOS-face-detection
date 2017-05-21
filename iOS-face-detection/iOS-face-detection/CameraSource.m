//
//  CameraSource.m
//  iOS-face-detection
//
//  Created by suntongmian on 2017/5/21.
//  Copyright © 2017年 suntongmian@163.com. All rights reserved.
//

#import "CameraSource.h"

#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)

@interface SampleBufferCallback: NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>
{
    CameraSource *_source;
}

- (void)setSource:(CameraSource *)source;

@end

@implementation SampleBufferCallback

- (void)setSource:(CameraSource *)source {
    _source = source;
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (_source) {
        [_source bufferCaptured:sampleBuffer];
    }
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
}

- (void)orientationChanged:(NSNotification*)notification {
    if (_source && ![_source orientationLocked]) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            [_source reorientCamera];
        });
    }
}

@end


@interface CameraSource ()
{
    AVCaptureSession* _captureSession;
    AVCaptureDevice* _captureDevice;
    SampleBufferCallback* _callbackSession;
    AVCaptureVideoPreviewLayer* _previewLayer;
    
    int  _fps;
    bool _torchOn;
    bool _useInterfaceOrientation;
    bool _orientationLocked;
    
    CameraSourceState  _cameraState;
    BOOL _cameraTorch;
}

@end

@implementation CameraSource

- (instancetype)init {
    self = [super init];
    if (self) {
        _captureDevice = nil;
        _callbackSession = nil;
        _previewLayer = nil;
        _orientationLocked = false;
        _torchOn = false;
        _useInterfaceOrientation = false;
        _captureSession = nil;
    }
    return self;
}

- (void)dealloc {
    if(_captureSession) {
        [_captureSession stopRunning];
        
        _captureSession = nil;
    }
    if(_callbackSession) {
        [[NSNotificationCenter defaultCenter] removeObserver:_callbackSession];
        
        _callbackSession = nil;
    }
    if(_previewLayer) {
        _previewLayer = nil;
    }
    NSLog(@"%s", __FUNCTION__);
}

- (CameraSourceState)cameraState {
    return _cameraState;
}

- (void)setCameraState:(CameraSourceState)cameraState {
    if(_cameraState != cameraState) {
        _cameraState = cameraState;
        [self toggleCamera];
    }
}

- (BOOL)cameraTorch {
    return _cameraTorch;
}

- (void)setCameraTorch:(BOOL)cameraTorch {
    _cameraTorch = [self setTorch:cameraTorch];
}

- (void)setupCameraFPS:(int)fps
              useFront:(bool)useFront
useInterfaceOrientation:(bool)useInterfaceOrientation
         sessionPreset:(NSString*)sessionPreset
         callbackBlock:(CallbackBlock)callbackBlock {
    
    _fps = fps;
    _useInterfaceOrientation = useInterfaceOrientation;
    
    __block CameraSource* bThis = self;
    
    void (^permissions)(BOOL) = ^(BOOL granted) {
        @autoreleasepool {
            if(granted) {
                
                int position = useFront ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack;
                
                NSArray* devices = [AVCaptureDevice devices];
                for(AVCaptureDevice* d in devices) {
                    if([d hasMediaType:AVMediaTypeVideo] && [d position] == position)
                    {
                        bThis->_captureDevice = d;
                        NSError* error;
                        [d lockForConfiguration:&error];
                        if(SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
                            [d setActiveVideoMinFrameDuration:CMTimeMake(1, fps)];
                            [d setActiveVideoMaxFrameDuration:CMTimeMake(1, fps)];
                        }
                        [d unlockForConfiguration];
                    }
                }
                
                AVCaptureSession* session = [[AVCaptureSession alloc] init];
                AVCaptureDeviceInput* input;
                AVCaptureVideoDataOutput* output;
                if(sessionPreset) {
                    session.sessionPreset = (NSString*)sessionPreset;
                }
                bThis->_captureSession = session;
                
                input = [AVCaptureDeviceInput deviceInputWithDevice:_captureDevice error:nil];
                
                output = [[AVCaptureVideoDataOutput alloc] init] ;
                
                output.videoSettings = @{(NSString*)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA) };
                
                if(!SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
                    AVCaptureConnection* conn = [output connectionWithMediaType:AVMediaTypeVideo];
                    if([conn isVideoMinFrameDurationSupported]) {
                        [conn setVideoMinFrameDuration:CMTimeMake(1, fps)];
                    }
                    if([conn isVideoMaxFrameDurationSupported]) {
                        [conn setVideoMaxFrameDuration:CMTimeMake(1, fps)];
                    }
                }
                if(!bThis->_callbackSession) {
                    bThis->_callbackSession = [[SampleBufferCallback alloc] init];
                    [bThis->_callbackSession setSource:self];
                }
                dispatch_queue_t camQueue = dispatch_queue_create("com.PL.camera", 0);
                
                [output setSampleBufferDelegate:bThis->_callbackSession queue:camQueue];
                
                camQueue = NULL;
                
                if([session canAddInput:input]) {
                    [session addInput:input];
                }
                if([session canAddOutput:output]) {
                    [session addOutput:output];
                    
                }
                
                [self reorientCamera];
                
                [session startRunning];
                
                if(!bThis->_orientationLocked) {
                    if(bThis->_useInterfaceOrientation) {
                        [[NSNotificationCenter defaultCenter] addObserver:((id)bThis->_callbackSession) selector:@selector(orientationChanged:) name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
                    } else {
                        [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
                        [[NSNotificationCenter defaultCenter] addObserver:((id)bThis->_callbackSession) selector:@selector(orientationChanged:) name:UIDeviceOrientationDidChangeNotification object:nil];
                    }
                }
                output = nil;
            }
            if (callbackBlock) {
                callbackBlock();
            }
        }
    };
    @autoreleasepool {
        if(SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
            AVAuthorizationStatus auth = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
            
            if(auth == AVAuthorizationStatusAuthorized || !SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) {
                permissions(true);
            }
            else if(auth == AVAuthorizationStatusNotDetermined) {
                [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:permissions];
            }
        } else {
            permissions(true);
        }
        
    }
}

- (void)getPreviewLayer:(AVCaptureVideoPreviewLayer**)outAVCaptureVideoPreviewLayer {
    if(!_previewLayer) {
        @autoreleasepool {
            AVCaptureSession *session = _captureSession;
            AVCaptureVideoPreviewLayer *previewLayer;
            previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:session];
            previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
            _previewLayer = previewLayer;
        }
    }
    if(outAVCaptureVideoPreviewLayer) {
        *outAVCaptureVideoPreviewLayer = _previewLayer;
    }
}

- (AVCaptureDevice *)cameraWithPosition:(int)pos {
    AVCaptureDevicePosition position = (AVCaptureDevicePosition)pos;
    
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices)
    {
        if ([device position] == position) return device;
    }
    return nil;
    
}

- (bool)orientationLocked {
    return _orientationLocked;
}

- (void)setOrientationLocked:(bool)orientationLocked {
    _orientationLocked = orientationLocked;
}

- (bool)setTorch:(bool)torchOn {
    bool ret = false;
    if(!_captureSession) return ret;
    
    AVCaptureSession* session = _captureSession;
    
    [session beginConfiguration];
    
    if (session.inputs.count > 0) {
        AVCaptureDeviceInput* currentCameraInput = [session.inputs objectAtIndex:0];
        
        if(currentCameraInput.device.torchAvailable) {
            NSError* err = nil;
            if([currentCameraInput.device lockForConfiguration:&err]) {
                [currentCameraInput.device setTorchMode:( torchOn ? AVCaptureTorchModeOn : AVCaptureTorchModeOff ) ];
                [currentCameraInput.device unlockForConfiguration];
                ret = (currentCameraInput.device.torchMode == AVCaptureTorchModeOn);
            } else {
                NSLog(@"Error while locking device for torch: %@", err);
                ret = false;
            }
        } else {
            NSLog(@"Torch not available in current camera input");
        }
        
    }
    
    [session commitConfiguration];
    _torchOn = ret;
    return ret;
}

- (void)toggleCamera {
    if(!_captureSession) return;
    
    NSError* error;
    AVCaptureSession* session = _captureSession;
    if(session) {
        [session beginConfiguration];
        [_captureDevice lockForConfiguration: &error];
        
        if (session.inputs.count > 0) {
            AVCaptureInput* currentCameraInput = [session.inputs objectAtIndex:0];
            
            [session removeInput:currentCameraInput];
            [_captureDevice unlockForConfiguration];
            
            AVCaptureDevice *newCamera = nil;
            if(((AVCaptureDeviceInput*)currentCameraInput).device.position == AVCaptureDevicePositionBack)
            {
                newCamera = (AVCaptureDevice*)[self cameraWithPosition:AVCaptureDevicePositionFront];
            }
            else
            {
                newCamera = (AVCaptureDevice*)[self cameraWithPosition:AVCaptureDevicePositionBack];
            }
            
            AVCaptureDeviceInput *newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:newCamera error:nil];
            [newCamera lockForConfiguration:&error];
            [session addInput:newVideoInput];
            
            _captureDevice = newCamera;
            [newCamera unlockForConfiguration];
            [session commitConfiguration];
            
            newVideoInput = nil;
        }
        
        [self reorientCamera];
    }
}

- (void)reorientCamera {
    if(!_captureSession) return;
    
    int orientation = _useInterfaceOrientation ? [[UIApplication sharedApplication] statusBarOrientation] : [[UIDevice currentDevice] orientation];
    
    // use interface orientation as fallback if device orientation is facedown, faceup or unknown
    if(orientation==UIDeviceOrientationFaceDown || orientation==UIDeviceOrientationFaceUp || orientation==UIDeviceOrientationUnknown) {
        orientation =[[UIApplication sharedApplication] statusBarOrientation];
    }
    
    //bool reorient = false;
    
    AVCaptureSession* session = _captureSession;
    // [session beginConfiguration];
    
    for (AVCaptureVideoDataOutput* output in session.outputs) {
        for (AVCaptureConnection * av in output.connections) {
            
            switch (orientation) {
                    // UIInterfaceOrientationPortraitUpsideDown, UIDeviceOrientationPortraitUpsideDown
                case UIInterfaceOrientationPortraitUpsideDown:
                    if(av.videoOrientation != AVCaptureVideoOrientationPortraitUpsideDown) {
                        av.videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
                        //    reorient = true;
                    }
                    break;
                    // UIInterfaceOrientationLandscapeRight, UIDeviceOrientationLandscapeLeft
                case UIInterfaceOrientationLandscapeRight:
                    if(av.videoOrientation != AVCaptureVideoOrientationLandscapeRight) {
                        av.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
                        //    reorient = true;
                    }
                    break;
                    // UIInterfaceOrientationLandscapeLeft, UIDeviceOrientationLandscapeRight
                case UIInterfaceOrientationLandscapeLeft:
                    if(av.videoOrientation != AVCaptureVideoOrientationLandscapeLeft) {
                        av.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
                        //   reorient = true;
                    }
                    break;
                    // UIInterfaceOrientationPortrait, UIDeviceOrientationPortrait
                case UIInterfaceOrientationPortrait:
                    if(av.videoOrientation != AVCaptureVideoOrientationPortrait) {
                        av.videoOrientation = AVCaptureVideoOrientationPortrait;
                        //    reorient = true;
                    }
                    break;
                default:
                    break;
            }
        }
    }
    
    //[session commitConfiguration];
    if(_torchOn) {
        [self setTorch:_torchOn];
    }
}

- (void)bufferCaptured:(CMSampleBufferRef)sampleBuffer {
    [self setOutput:sampleBuffer];
}

- (void)setOutput:(CMSampleBufferRef)sampleBuffer {
    [self.delegate cameraSourceOutput:sampleBuffer];
}

- (bool)setContinuousAutofocus:(bool)wantsContinuous {
    AVCaptureDevice* device = _captureDevice;
    AVCaptureFocusMode newMode = wantsContinuous ?  AVCaptureFocusModeContinuousAutoFocus : AVCaptureFocusModeAutoFocus;
    bool ret = [device isFocusModeSupported:newMode];
    
    if(ret) {
        NSError *err = nil;
        if ([device lockForConfiguration:&err]) {
            device.focusMode = newMode;
            [device unlockForConfiguration];
        } else {
            NSLog(@"Error while locking device for autofocus: %@", err);
            ret = false;
        }
    } else {
        NSLog(@"Focus mode not supported: %@", wantsContinuous ? @"AVCaptureFocusModeContinuousAutoFocus" : @"AVCaptureFocusModeAutoFocus");
        if (wantsContinuous) {
            NSLog(@"Focus mode not supported: AVCaptureFocusModeContinuousAutoFocus");
        } else {
            NSLog(@"Focus mode not supported: AVCaptureFocusModeAutoFocus");
        }
    }
    
    return ret;
}

- (bool)setContinuousExposure:(bool)wantsContinuous {
    AVCaptureDevice *device = _captureDevice;
    AVCaptureExposureMode newMode = wantsContinuous ? AVCaptureExposureModeContinuousAutoExposure : AVCaptureExposureModeAutoExpose;
    bool ret = [device isExposureModeSupported:newMode];
    
    if(ret) {
        NSError *err = nil;
        if ([device lockForConfiguration:&err]) {
            device.exposureMode = newMode;
            [device unlockForConfiguration];
        } else {
            NSLog(@"Error while locking device for exposure: %@", err);
            ret = false;
        }
    } else {
        NSLog(@"Exposure mode not supported: %@", wantsContinuous ? @"AVCaptureExposureModeContinuousAutoExposure" : @"AVCaptureExposureModeAutoExpose");
        if (wantsContinuous) {
            NSLog(@"Exposure mode not supported: AVCaptureExposureModeContinuousAutoExposure");
        } else {
            NSLog(@"Exposure mode not supported: AVCaptureExposureModeAutoExpose");
        }
    }
    
    return ret;
}

- (bool)setFocusPointOfInterestWithX:(float)x andY:(float)y {
    AVCaptureDevice* device = _captureDevice;
    bool ret = device.focusPointOfInterestSupported;
    
    if(ret) {
        NSError* err = nil;
        if([device lockForConfiguration:&err]) {
            [device setFocusPointOfInterest:CGPointMake(x, y)];
            if (device.focusMode == AVCaptureFocusModeLocked) {
                [device setFocusMode:AVCaptureFocusModeAutoFocus];
            }
            device.focusMode = device.focusMode;
            [device unlockForConfiguration];
        } else {
            NSLog(@"Error while locking device for focus POI: %@", err);
            ret = false;
        }
    } else {
        NSLog(@"Focus POI not supported");
    }
    
    return ret;
}

- (bool)setExposurePointOfInterestWithX:(float)x andY:(float)y {
    AVCaptureDevice* device = _captureDevice;
    bool ret = device.exposurePointOfInterestSupported;
    
    if(ret) {
        NSError* err = nil;
        if([device lockForConfiguration:&err]) {
            [device setExposurePointOfInterest:CGPointMake(x, y)];
            device.exposureMode = device.exposureMode;
            [device unlockForConfiguration];
        } else {
            NSLog(@"Error while locking device for exposure POI: %@", err);
            ret = false;
        }
    } else {
        NSLog(@"Exposure POI not supported");
    }
    
    return ret;
}

@end


