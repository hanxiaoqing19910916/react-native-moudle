
#import "RCTBridge.h"

#import "RCTAssert.h"
#import "RCTUtils.h"

#import "RCTBridgeModule.h"
#import "RCTCxxBridge.h"

NSString *const RCTDidInitializeModuleNotification = @"RCTDidInitializeModuleNotification";
NSString *const RCTBridgeWillReloadNotification = @"RCTBridgeWillReloadNotification";

static NSMutableArray<Class> *RCTModuleClasses;
NSArray<Class> *RCTGetModuleClasses(void)
{
  return RCTModuleClasses;
}

/**
 * Register the given class as a bridge module. All modules must be registered
 * prior to the first bridge initialization.
 */
void RCTRegisterModule(Class);
void RCTRegisterModule(Class moduleClass)
{
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    RCTModuleClasses = [NSMutableArray new];
  });
  
  RCTAssert([moduleClass conformsToProtocol:@protocol(RCTBridgeModule)],
            @"%@ does not conform to the RCTBridgeModule protocol",
            moduleClass);
  
  // Register module
  [RCTModuleClasses addObject:moduleClass];
}

/**
 * This function returns the module name for a given class.
 */
NSString *RCTBridgeModuleNameForClass(Class cls)
{
#if RCT_DEBUG
  RCTAssert([cls conformsToProtocol:@protocol(RCTBridgeModule)],
            @"Bridge module `%@` does not conform to RCTBridgeModule", cls);
#endif
  
  NSString *name = [cls moduleName];
  if (name.length == 0) {
    name = NSStringFromClass(cls);
  }
  
  if ([name hasPrefix:@"RK"]) {
    name = [name substringFromIndex:2];
  } else if ([name hasPrefix:@"RCT"]) {
    name = [name substringFromIndex:3];
  }
  
  return name;
}


@implementation RCTBridge

dispatch_queue_t RCTJSThread;

+ (void)initialize
{
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    // Set up JS thread
    RCTJSThread = (id)kCFNull;
  });
}

static RCTBridge *RCTCurrentBridgeInstance = nil;

/**
 * The last current active bridge instance. This is set automatically whenever
 * the bridge is accessed. It can be useful for static functions or singletons
 * that need to access the bridge for purposes such as logging, but should not
 * be relied upon to return any particular instance, due to race conditions.
 */
+ (instancetype)currentBridge
{
  return RCTCurrentBridgeInstance;
}

+ (void)setCurrentBridge:(RCTBridge *)currentBridge
{
  RCTCurrentBridgeInstance = currentBridge;
}

- (instancetype)initWithModuleProvider:(RCTBridgeModuleListProvider)block
                         launchOptions:(NSDictionary *)launchOptions
{
  if (self = [super init]) {
    _moduleProvider = block;
    _launchOptions = [launchOptions copy];
    
    [self setUp];
  }
  return self;
}

RCT_NOT_IMPLEMENTED(- (instancetype)init)

- (void)setUp
{
  _valid = YES;
  self.batchedBridge = [[RCTCxxBridge alloc] initWithParentBridge:self];
  [self.batchedBridge start];
}



- (NSArray<Class> *)moduleClasses
{
  return self.batchedBridge.moduleClasses;
}

- (id)moduleForName:(NSString *)moduleName
{
  return [self.batchedBridge moduleForName:moduleName];
}

- (id)moduleForClass:(Class)moduleClass
{
  return [self moduleForName:RCTBridgeModuleNameForClass(moduleClass)];
}

- (RCTModuleData *)moduleDataForName:(NSString *)moduleName
{
   return [self.batchedBridge moduleDataForName:moduleName];
}

- (NSArray *)modulesConformingToProtocol:(Protocol *)protocol
{
  NSMutableArray *modules = [NSMutableArray new];
  for (Class moduleClass in self.moduleClasses) {
    if ([moduleClass conformsToProtocol:protocol]) {
      id module = [self moduleForClass:moduleClass];
      if (module) {
        [modules addObject:module];
      }
    }
  }
  return [modules copy];
}


- (BOOL)moduleIsInitialized:(Class)moduleClass
{
  return [self.batchedBridge moduleIsInitialized:moduleClass];
}


- (void)reload
{
  [[NSNotificationCenter defaultCenter] postNotificationName:RCTBridgeWillReloadNotification object:self];
  
  /** Any thread */
  dispatch_async(dispatch_get_main_queue(), ^{
    [self invalidate];
    [self setUp];
  });
}




- (void)invalidate
{
  RCTBridge *batchedBridge = self.batchedBridge;
  self.batchedBridge = nil;
  
  if (batchedBridge) {
    RCTExecuteOnMainQueue(^{
      [batchedBridge invalidate];
    });
  }
}


- (void)dealloc
{
  /**
   * This runs only on the main thread, but crashes the subclass
   * RCTAssertMainQueue();
   */
  [self invalidate];
}

@end
