//
//  CameraSource.h
//  iOS-face-detection
//
//  Created by suntongmian on 2017/5/21.
//  Copyright © 2017年 suntongmian@163.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <CoreVideo/CoreVideo.h>
#import <AVFoundation/AVFoundation.h>

typedef void (^CallbackBlock)(void);

@class CameraSource;

typedef NS_ENUM(NSInteger, CameraSourceState)
{
    CameraSourceStateFront, // 前置摄像头
    CameraSourceStateBack   // 后置摄像头
};

@protocol CameraSourceDelegate <NSObject>

- (void)cameraSourceOutput:(CMSampleBufferRef)sampleBuffer;

@end

@interface CameraSource : NSObject

@property (nonatomic, assign) CameraSourceState cameraState; // 前后摄像头切换
@property (nonatomic, assign) BOOL cameraTorch; // YES：闪光灯打开，NO：关闭

@property (nonatomic, assign)id<CameraSourceDelegate> delegate;

/**
 * @brief   获取摄像头视图AVCaptureVideoPreviewLayer
 * @param   outAVCaptureVideoPreviewLayer       摄像头视图的引用
 */
- (void)getPreviewLayer:(AVCaptureVideoPreviewLayer**)outAVCaptureVideoPreviewLayer;

/**
 * @brief   设置摄像头的参数
 * @param   fps                         帧率
 * @param   useFront                    front-facing camera
 * @param   useInterfaceOrientation     video capture旋转
 * @param   sessionPreset               capture session的名称
 * @param   callbackBlock               回调
 */
- (void)setupCameraFPS:(int)fps
              useFront:(bool)useFront
useInterfaceOrientation:(bool)useInterfaceOrientation
         sessionPreset:(NSString*)sessionPreset
         callbackBlock:(CallbackBlock)callbackBlock;

/**
 * @brief   返回旋转锁定的状态
 * @return  如果locked，返回true
 */
- (bool)orientationLocked;

/**
 * @brief   Capture Session
 * @param   sampleBuffer   相机捕获的图像数据
 */
- (void)bufferCaptured:(CMSampleBufferRef)sampleBuffer;

/**
 * @brief   Device/Interface 旋转事件
 */
- (void)reorientCamera;

/**
 * @brief   设置旋转锁定的状态
 * @param   orientationLocked   设置是否锁定旋转
 */
- (void)setOrientationLocked:(bool)orientationLocked;

/**
 * @brief   对焦设置， 左上角(0,0)，右下角(1,1)
 * @param   x   对焦位置的横坐标
 * @param   y   对焦位置的纵坐标
 * @return  设置成功返回true，失败返回false
 */
- (bool)setFocusPointOfInterestWithX:(float)x andY:(float)y;

/**
 * @brief   设置自动对焦点
 * @param   wantsContinuous   true为自动对焦
 * @return  设置成功返回true，失败返回false
 */
- (bool)setContinuousAutofocus:(bool)wantsContinuous;

/**
 * @brief   设置曝光点
 * @param   x   曝光点位置的横坐标
 * @param   y   曝光点位置的纵坐标
 * @return  设置成功返回true，失败返回false
 */
- (bool)setExposurePointOfInterestWithX:(float)x andY:(float)y;

/**
 * @brief   设置自动曝光点
 * @param   wantsContinuous   true为自动曝光
 * @return  设置成功返回true，失败返回false
 */
- (bool)setContinuousExposure:(bool)wantsContinuous;

@end

