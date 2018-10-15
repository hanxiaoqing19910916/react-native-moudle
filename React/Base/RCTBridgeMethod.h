
#import <Foundation/Foundation.h>

@class RCTBridge;

typedef NS_ENUM(NSUInteger, RCTFunctionType) {
  RCTFunctionTypeNormal,
  RCTFunctionTypePromise,
  RCTFunctionTypeSync,
};

static inline const char *RCTFunctionDescriptorFromType(RCTFunctionType type) {
  switch (type) {
    case RCTFunctionTypeNormal:
      return "async";
    case RCTFunctionTypePromise:
      return "promise";
    case RCTFunctionTypeSync:
      return "sync";
  }
};

@protocol RCTBridgeMethod <NSObject>

@property (nonatomic, readonly) const char *JSMethodName;
@property (nonatomic, readonly) RCTFunctionType functionType;

- (id)invokeWithBridge:(RCTBridge *)bridge
                module:(id)module
             arguments:(NSArray *)arguments;

@end


