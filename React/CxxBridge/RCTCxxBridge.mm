
#include <atomic>
#include <future>

#import "RCTCxxBridge.h"
#import <React/RCTModuleData.h>

#import <React/RCTCxxUtils.h>

#import <React/RCTAssert.h>
#import <React/RCTLog.h>

#import <cxxreact/ModuleRegistry.h>


using namespace facebook::react;

typedef void (^RCTPendingCall)();

@implementation RCTCxxBridge
{
  BOOL _valid;
  BOOL _didInvalidate;
  BOOL _moduleSetupComplete;
  
  RCTBridge *_parentBridge;
  
  NSMutableArray<RCTPendingCall> *_pendingCalls;

  // Native modules
  NSMutableDictionary<NSString *, RCTModuleData *> *_moduleDataByName;
  NSMutableArray<RCTModuleData *> *_moduleDataByID;
  NSMutableArray<Class> *_moduleClassesByID;
}

- (RCTBridge *)parentBridge
{
  return _parentBridge;
}

- (BOOL)isValid
{
    return _valid;
}

- (BOOL)moduleSetupComplete
{
    return _moduleSetupComplete;
}

- (void)setUp {}

- (instancetype)initWithParentBridge:(RCTBridge *)bridge
{
  RCTAssertParam(bridge);
  
  if ((self = [super initWithModuleProvider:bridge.moduleProvider launchOptions:bridge.launchOptions])) {
    _parentBridge = bridge;
    RCTLogInfo(@"Initializing %@ (parent: %@, executor: %@)", self, bridge, [self executorClass]);
    
    /**
     * Set Initial State
     */
    _valid = YES;
    _pendingCalls = [NSMutableArray new];
    
    _moduleDataByName = [NSMutableDictionary new];
    _moduleClassesByID = [NSMutableArray new];
    _moduleDataByID = [NSMutableArray new];
    
    [RCTBridge setCurrentBridge:self];
  }
  return self;
}

- (void)start
{
  // 相比RN源码，去除了js环境（线程，异常捕获等等）相关的初始化
 
  // Initialize all native modules that cannot be loaded lazily
  (void)[self _initializeModules:RCTGetModuleClasses() lazilyDiscovered:NO];

  // Dispatch the instance initialization as soon as the initial module metadata has
  // been collected (see initModules)
   [self _buildModuleRegistry];
}

- (NSArray<Class> *)moduleClasses
{
  if (RCT_DEBUG && _valid && _moduleClassesByID == nil) {
    RCTLogError(@"Bridge modules have not yet been initialized. You may be "
                "trying to access a module too early in the startup procedure.");
  }
  return _moduleClassesByID;
}

- (RCTModuleData *)moduleDataForName:(NSString *)moduleName
{
  return _moduleDataByName[moduleName];
}

- (id)moduleForName:(NSString *)moduleName
{
  return _moduleDataByName[moduleName].instance;
}

- (BOOL)moduleIsInitialized:(Class)moduleClass
{
  return _moduleDataByName[RCTBridgeModuleNameForClass(moduleClass)].hasInstance;
}


- (NSArray<RCTModuleData *> *)_initializeModules:(NSArray<id<RCTBridgeModule>> *)modules
                                lazilyDiscovered:(BOOL)lazilyDiscovered
{
  RCTAssert(!(RCTIsMainQueue() && lazilyDiscovered), @"Lazy discovery can only happen off the Main Queue");

  // Set up moduleData for automatically-exported modules
  NSArray<RCTModuleData *> *moduleDataById = [self registerModulesForClasses:modules];

#ifdef RCT_DEBUG
  if (lazilyDiscovered) {
    // Lazily discovered modules do not require instantiation here,
    // as they are not allowed to have pre-instantiated instance
    // and must not require the main queue.
    for (RCTModuleData *moduleData in moduleDataById) {
      RCTAssert(!(moduleData.requiresMainQueueSetup || moduleData.hasInstance),
                @"Module \'%@\' requires initialization on the Main Queue or has pre-instantiated, which is not supported for the lazily discovered modules.", moduleData.name);
    }
  }
  else
#endif
  {
    // Dispatch module init onto main thread for those modules that require it
    // For non-lazily discovered modules we run through the entire set of modules
    // that we have, otherwise some modules coming from the delegate
    // or module provider block, will not be properly instantiated.
    for (RCTModuleData *moduleData in _moduleDataByID) {
      if (moduleData.requiresMainQueueSetup && RCTIsMainQueue()) {
        // Modules that were pre-initialized should ideally be set up before
        // bridge init has finished, otherwise the caller may try to access the
        // module directly rather than via `[bridge moduleForClass:]`, which won't
        // trigger the lazy initialization process. If the module cannot safely be
        // set up on the current thread, it will instead be async dispatched
        // to the main thread to be set up in _prepareModulesWithDispatchGroup:.
        (void)[moduleData instance];
      }
    }
    
    // From this point on, RCTDidInitializeModuleNotification notifications will
    // be sent the first time a module is accessed.
    _moduleSetupComplete = YES;
  }
  return moduleDataById;
}



- (NSArray<RCTModuleData *> *)registerModulesForClasses:(NSArray<Class> *)moduleClasses
{
  NSMutableArray<RCTModuleData *> *moduleDataByID = [NSMutableArray arrayWithCapacity:moduleClasses.count];
  for (Class moduleClass in moduleClasses) {
    NSString *moduleName = RCTBridgeModuleNameForClass(moduleClass);
    
    // Check for module name collisions
    RCTModuleData *moduleData = _moduleDataByName[moduleName];
    if (moduleData) {
      if (moduleData.hasInstance) {
        // Existing module was preregistered, so it takes precedence
        continue;
      } else if ([moduleClass new] == nil) {
        // The new module returned nil from init, so use the old module
        continue;
      } else if ([moduleData.moduleClass new] != nil) {
        // Both modules were non-nil, so it's unclear which should take precedence
        RCTLogError(@"Attempted to register RCTBridgeModule class %@ for the "
                    "name '%@', but name was already registered by class %@",
                    moduleClass, moduleName, moduleData.moduleClass);
      }
    }
    
    // Instantiate moduleData
    // TODO #13258411: can we defer this until config generation?
    moduleData = [[RCTModuleData alloc] initWithModuleClass:moduleClass bridge:self];
    
    _moduleDataByName[moduleName] = moduleData;
    [_moduleClassesByID addObject:moduleClass];
    [moduleDataByID addObject:moduleData];
  }
  [_moduleDataByID addObjectsFromArray:moduleDataByID];
  return moduleDataByID;
}



- (std::shared_ptr<ModuleRegistry>)_buildModuleRegistry
{
  if (!self.valid) {
    return {};
  }
  
  __weak __typeof(self) weakSelf = self;
  ModuleRegistry::ModuleNotFoundCallback moduleNotFoundCallback = ^bool(const std::string &name) {
    return true;
  };
  
  auto registry = std::make_shared<ModuleRegistry>(
                                                   createNativeModules(_moduleDataByID, self),
                                                   moduleNotFoundCallback);
  return registry;
}

- (void)dispatchBlock:(dispatch_block_t)block
                queue:(dispatch_queue_t)queue
{
  if (queue) {
    dispatch_async(queue, block);
  }
}

- (void)invalidate
{
  if (_didInvalidate) {
    return;
  }
  
  RCTAssertMainQueue();
    RCTLogInfo(@"Invalidating %@ (parent: %@, executor: %@)", self, self.parentBridge, [self executorClass]);
  
  _valid = NO;
  _didInvalidate = YES;
  
  if ([RCTBridge currentBridge] == self) {
    [RCTBridge setCurrentBridge:nil];
  }
  
  // Stop JS instance and message thread
  
  // Invalidate modules
  // We're on the JS thread (which we'll be suspending soon), so no new calls will be made to native modules after
  // this completes. We must ensure all previous calls were dispatched before deallocating the instance (and module
  // wrappers) or we may have invalid pointers still in flight.
  dispatch_group_t moduleInvalidation = dispatch_group_create();
  for (RCTModuleData *moduleData in self->_moduleDataByID) {
    // Be careful when grabbing an instance here, we don't want to instantiate
    // any modules just to invalidate them.
    if (![moduleData hasInstance]) {
      continue;
    }
    
    if ([moduleData.instance respondsToSelector:@selector(invalidate)]) {
      dispatch_group_enter(moduleInvalidation);
      [self dispatchBlock:^{
        [(id<RCTInvalidating>)moduleData.instance invalidate];
        dispatch_group_leave(moduleInvalidation);
      } queue:moduleData.methodQueue];
    }
    [moduleData invalidate];
  }
  
  if (dispatch_group_wait(moduleInvalidation, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC))) {
    RCTLogError(@"Timed out waiting for modules to be invalidated");
  }
  
  self->_moduleDataByName = nil;
  self->_moduleDataByID = nil;
  self->_moduleClassesByID = nil;
}


@end
