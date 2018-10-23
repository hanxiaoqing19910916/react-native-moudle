
#import <Foundation/Foundation.h>

#import <React/RCTBridgeMethod.h>
#import <React/RCTBridgeModule.h>

typedef NS_ENUM(NSUInteger, RCTNullability) {
  RCTNullabilityUnspecified,
  RCTNullable,
  RCTNonnullable,
};


@class RCTBridge;

@interface RCTMethodArgument : NSObject

@property (nonatomic, copy, readonly) NSString *type;
@property (nonatomic, readonly) RCTNullability nullability;
@property (nonatomic, readonly) BOOL unused;

@end

@interface RCTModuleMethod : NSObject <RCTBridgeMethod>

@property (nonatomic, readonly) Class moduleClass;
@property (nonatomic, readonly) SEL selector;

- (instancetype)initWithExportedMethod:(const RCTMethodInfo *)exportMethod
                           moduleClass:(Class)moduleClass NS_DESIGNATED_INITIALIZER;

@end
