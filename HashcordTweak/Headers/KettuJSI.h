#pragma once

#import <Foundation/Foundation.h>
#import <jsi/jsi.h>

@interface HashcordJSI : NSObject
+ (void)evaluate:(NSData *)data
             tag:(NSString *)tag
         runtime:(facebook::jsi::Runtime &)runtime;
@end
