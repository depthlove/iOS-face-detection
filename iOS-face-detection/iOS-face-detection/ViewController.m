//
//  ViewController.m
//  iOS-face-detection
//
//  Created by suntongmian on 2017/5/21.
//  Copyright © 2017年 suntongmian@163.com. All rights reserved.
//

#import "ViewController.h"
#import "CameraSource.h"
#import "DlibFaceDetector.h"

@interface ViewController () <CameraSourceDelegate>

@property (strong, nonatomic) CameraSource *camera;
@property (strong, nonatomic) DlibFaceDetector *faceDetector;
@property (strong, nonatomic) NSMutableArray *currentMetadata;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.currentMetadata = [[NSMutableArray alloc] init];
    
    self.faceDetector = [[DlibFaceDetector alloc] init];
    [self.faceDetector prepare];
    
    self.camera = [[CameraSource alloc] init];
    [self.camera setupCameraFPS:15 useFront:true useInterfaceOrientation:YES sessionPreset:AVCaptureSessionPreset1280x720 callbackBlock:^{
        
    }];
    self.camera.delegate = self;
    
    AVCaptureVideoPreviewLayer *previewLayer = nil;
    [self.camera getPreviewLayer:&previewLayer];
    previewLayer.frame = self.view.bounds;
    previewLayer.masksToBounds = YES;
    [self.view.layer addSublayer:previewLayer];
    
    
    
}

#pragma mark -- CameraSourceDelegate

- (void)cameraSourceOutput:(CMSampleBufferRef)sampleBuffer {
    NSLog(@"%s, %d", __func__, __LINE__);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
