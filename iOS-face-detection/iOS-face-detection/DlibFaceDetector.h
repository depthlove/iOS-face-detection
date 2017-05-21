//
//  DlibFaceDetector.h
//  iOS-face-detection
//
//  Created by suntongmian on 2017/5/21.
//  Copyright © 2017年 suntongmian@163.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreMedia/CoreMedia.h>

@interface DlibFaceDetector : NSObject

- (instancetype)init;
- (void)doWorkOnSampleBuffer:(CMSampleBufferRef)sampleBuffer inRects:(NSArray<NSValue *> *)rects;
- (void)prepare;

@end
