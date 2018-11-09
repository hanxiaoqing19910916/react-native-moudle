
#import <React/RCTBridge.h>


@interface RCTCxxBridge : RCTBridge

- (instancetype)initWithParentBridge:(RCTBridge *)bridge NS_DESIGNATED_INITIALIZER;

@property (nonatomic, strong) NSMutableDictionary<NSString *, RCTModuleData *> *moduleDataByName;

@end
