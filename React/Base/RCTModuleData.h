
#import <Foundation/Foundation.h>
#import "RCTModuleMethod.h"
#import "RCTBridge.h"

@protocol RCTBridgeMethod;
@protocol RCTBridgeModule;
@protocol RCTInvalidating;
@class RCTBridge;


typedef id<RCTBridgeModule>(^RCTBridgeModuleProvider)(void);

@interface RCTModuleData : NSObject <RCTInvalidating>
/**
 通过Class初始化，内部把具体的Class实例化赋值给_instance属性
 一般都是常用这个方法，例如RN源码里面RCTCxxBridge.mm---registerModulesForClasses里：
 moduleData = [[RCTModuleData alloc] initWithModuleClass:moduleClass bridge:self];
 
 @param moduleClass 需要export的OC类Class
 @param bridge RCTBridge对象
 @return RCTModuleData
 */
- (instancetype)initWithModuleClass:(Class)moduleClass
                             bridge:(RCTBridge *)bridge;

/**
 通过Class初始化，并且可以通过moduleProvider自定义实例化过程
 @param moduleClass 需要export的OC类Class
 @param moduleProvider 返回id<RCTBridgeModule>类型的对象Block，可在Block内部自定义对象的一些额外初始化数据
 @param bridge RCTBridge对象
 @return RCTModuleData
 */
- (instancetype)initWithModuleClass:(Class)moduleClass
                     moduleProvider:(RCTBridgeModuleProvider)moduleProvider
                             bridge:(RCTBridge *)bridge NS_DESIGNATED_INITIALIZER;

// NS_DESIGNATED_INITIALIZER代表最终一定要调用到的init组合方法

/**
 直接通过id<RCTBridgeModule>类型的实例对象初始化
 @param instance 需要export的OC对象实例
 @param bridge RCTBridge对象
 @return RCTModuleData
 */
- (instancetype)initWithModuleInstance:(id<RCTBridgeModule>)instance
                                bridge:(RCTBridge *)bridge NS_DESIGNATED_INITIALIZER;


@property (nonatomic, strong, readonly) Class moduleClass; // get moduleClass in current RCTModuleData instance
@property (nonatomic, copy, readonly) NSString *name; // get module name

/**
 * Returns the module methods. Note that this will gather the methods the first
 * time it is called and then memoize the results.
 */
@property (nonatomic, copy, readonly) NSArray<id<RCTBridgeMethod>> *methods;


/**
 * Returns YES if module instance has already been initialized; NO otherwise.
 */
@property (nonatomic, assign, readonly) BOOL hasInstance;

/**
 * Returns YES if module instance must be created on the main thread.
 */
@property (nonatomic, assign) BOOL requiresMainQueueSetup;


/**
 * Returns the current module instance. Note that this will init the instance
 * if it has not already been created. To check if the module instance exists
 * without causing it to be created, use `hasInstance` instead.
 */
@property (nonatomic, strong, readonly) id<RCTBridgeModule> instance;


/**
 * Returns the module method dispatch queue. Note that this will init both the
 * queue and the module itself if they have not already been created.
 */
@property (nonatomic, strong, readonly) dispatch_queue_t methodQueue;


@end

