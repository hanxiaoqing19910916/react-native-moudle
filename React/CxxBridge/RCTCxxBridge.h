
#import <React/RCTBridge.h>


@interface RCTCxxBridge : RCTBridge

- (instancetype)initWithParentBridge:(RCTBridge *)bridge NS_DESIGNATED_INITIALIZER;

@end
