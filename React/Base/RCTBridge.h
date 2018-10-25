#import <UIKit/UIKit.h>

#import <React/RCTDefines.h>
#import <React/RCTBridgeModule.h>

@class RCTModuleData;

/**
 * This function returns the module name for a given class.
 */
RCT_EXTERN NSString *RCTBridgeModuleNameForClass(Class bridgeModuleClass);

RCT_EXTERN NSArray<Class> *RCTGetModuleClasses(void);

/**
 * This notification fires each time a native module is instantiated. The
 * `module` key will contain a reference to the newly-created module instance.
 * Note that this notification may be fired before the module is available via
 * the `[bridge moduleForClass:]` method.
 */
RCT_EXTERN NSString *const RCTDidInitializeModuleNotification;
/**
 * This notification fires just before the bridge starts processing a request to
 * reload.
 */
RCT_EXTERN NSString *const RCTBridgeWillReloadNotification;

/**
 * This block can be used to instantiate modules that require additional
 * init parameters, or additional configuration prior to being used.
 * The bridge will call this block to instatiate the modules, and will
 * be responsible for invalidating/releasing them when the bridge is destroyed.
 * For this reason, the block should always return new module instances, and
 * module instances should not be shared between bridges.
 */
typedef NSArray<id<RCTBridgeModule>> *(^RCTBridgeModuleListProvider)(void);


@protocol RCTInvalidating <NSObject>

- (void)invalidate;

@end

@interface RCTBridge : NSObject 
/**
 * The designated initializer. This creates a new bridge on top of the specified
 * executor. The bridge should then be used for all subsequent communication
 * with the JavaScript code running in the executor. Modules will be automatically
 * instantiated using the default contructor, but you can optionally pass in an
 * array of pre-initialized module instances if they require additional init
 * parameters or configuration.
 */
- (instancetype)initWithModuleProvider:(RCTBridgeModuleListProvider)block
                    launchOptions:(NSDictionary *)launchOptions;

/**
 * Retrieve a bridge module instance by name or class. Note that modules are
 * lazily instantiated, so calling these methods for the first time with a given
 * module name/class may cause the class to be sychronously instantiated,
 * potentially blocking both the calling thread and main thread for a short time.
 */
- (id)moduleForName:(NSString *)moduleName;
- (id)moduleForClass:(Class)moduleClass;
- (RCTModuleData *)moduleDataForName:(NSString *)moduleName;


/**
 * Convenience method for retrieving all modules conforming to a given protocol.
 * Modules will be sychronously instantiated if they haven't already been,
 * potentially blocking both the calling thread and main thread for a short time.
 */
- (NSArray *)modulesConformingToProtocol:(Protocol *)protocol;

/**
 * Test if a module has been initialized. Use this prior to calling
 * `moduleForClass:` or `moduleForName:` if you do not want to cause the module
 * to be instantiated if it hasn't been already.
 */
- (BOOL)moduleIsInitialized:(Class)moduleClass;

/**
 * All registered bridge module classes.
 */
@property (nonatomic, copy, readonly) NSArray<Class> *moduleClasses;

/**
 * The class of the executor currently being used. Changes to this value will
 * take effect after the bridge is reloaded.
 */
@property (nonatomic, strong) Class executorClass;


/**
 * The launch options that were used to initialize the bridge.
 */
@property (nonatomic, copy, readonly) NSDictionary *launchOptions;
/**
 * Use this to check if the bridge has been invalidated.
 */
@property (nonatomic, readonly, getter=isValid) BOOL valid;

/**
 * Reload the bundle and reset executor & modules. Safe to call from any thread.
 */
- (void)reload;


@end



@interface RCTBridge ()

+ (instancetype)currentBridge;
+ (void)setCurrentBridge:(RCTBridge *)bridge;

/**
 * Bridge setup code - creates an instance of RCTBachedBridge. Exposed for
 * test only
 */
- (void)setUp;

/**
 * This method is used to invoke a callback that was registered in the
 * JavaScript application context. Safe to call from any thread.
 */
- (void)enqueueCallback:(NSNumber *)cbID args:(NSArray *)args;

/**
 * This property is mostly used on the main thread, but may be touched from
 * a background thread if the RCTBridge happens to deallocate on a background
 * thread. Therefore, we want all writes to it to be seen atomically.
 */
@property (atomic, strong) RCTBridge *batchedBridge;

/**
 * The block that creates the modules' instances to be added to the bridge.
 * Exposed for RCTCxxBridge
 */
@property (nonatomic, copy, readonly) RCTBridgeModuleListProvider moduleProvider;

@end


@interface RCTBridge (RCTCxxBridge)
/**
 * Used by RCTModuleData
 */
@property (nonatomic, weak, readonly) RCTBridge *parentBridge;

/**
 * Used by RCTModuleData
 */
@property (nonatomic, assign, readonly) BOOL moduleSetupComplete;
/**
 * Called on the child bridge to run the executor and start loading.
 */
- (void)start;

@end
