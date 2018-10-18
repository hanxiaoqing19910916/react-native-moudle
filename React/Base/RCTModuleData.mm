
#import "RCTModuleData.h"

#import <objc/runtime.h>
#include <mutex>

#import "RCTLog.h"

#import "RCTBridge.h"

@implementation RCTModuleData
{
  NSString *_queueName;
  dispatch_queue_t _methodQueue;
  
  id<RCTBridgeModule> _instance;
  __weak RCTBridge *_bridge;
  
  NSArray<id<RCTBridgeMethod>> *_methods;
  
  RCTBridgeModuleProvider _moduleProvider;
  std::mutex _instanceLock;
  BOOL _setupComplete;
}

- (void)setUp
{
  // 判断_moduleClass是否实现了+ (BOOL)requiresMainQueueSetup类方法，得知其初始化是否一定需要在主队列
  const BOOL implementsRequireMainQueueSetup = [_moduleClass respondsToSelector:@selector(requiresMainQueueSetup)];
  if (implementsRequireMainQueueSetup) { //如果实现就调用得到requiresMainQueueSetup返回值，
    _requiresMainQueueSetup = [_moduleClass requiresMainQueueSetup];
  } else { //如果没有实现requiresMainQueueSetup类方法，就从_moduleClass的init方法得知
    static IMP objectInitMethod;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      objectInitMethod = [NSObject instanceMethodForSelector:@selector(init)];
    });
    
    // If a module overrides `init` then we must assume that it expects to be
    // initialized on the main thread, because it may need to access UIKit.
    const BOOL hasCustomInit = !_instance && [_moduleClass instanceMethodForSelector:@selector(init)] != objectInitMethod;
    
    // RN源码中大部分模块在这里的hasCustomInit==N0, 即他们是可以在其他的非主队列进行初始化
    // 其Class初始化方法init来自于NSObject，即
    //（[_moduleClass instanceMethodForSelector:@selector(init)] == objectInitMethod）== true
    _requiresMainQueueSetup = hasCustomInit;
    if (_requiresMainQueueSetup) {
      const char *methodName = "init";
      RCTLogWarn(@"Module %@ requires main queue setup since it overrides `%s` but doesn't implement "
                 "`requiresMainQueueSetup`. In a future release React Native will default to initializing all native modules "
                 "on a background thread unless explicitly opted-out of.", _moduleClass, methodName);
    }
  }
  
}

- (instancetype)initWithModuleClass:(Class)moduleClass
                             bridge:(RCTBridge *)bridge
{
  return [self initWithModuleClass:moduleClass
                    moduleProvider:^id<RCTBridgeModule>{ return [moduleClass new]; }
                            bridge:bridge];
}

- (instancetype)initWithModuleClass:(Class)moduleClass
                     moduleProvider:(RCTBridgeModuleProvider)moduleProvider
                             bridge:(RCTBridge *)bridge
{
  if (self = [super init]) {
    _bridge = bridge;
    _moduleClass = moduleClass;
    _moduleProvider = [moduleProvider copy];
    [self setUp];
  }
  return self;
}

- (instancetype)initWithModuleInstance:(id<RCTBridgeModule>)instance
                                bridge:(RCTBridge *)bridge
{
  if (self = [super init]) {
    _bridge = bridge;
    _instance = instance;
    _moduleClass = [instance class];
    [self setUp];
  }
  return self;
}

RCT_NOT_IMPLEMENTED(- (instancetype)init);


- (void)setUpInstanceAndBridge
{
  {
    std::unique_lock<std::mutex> lock(_instanceLock);
    
    if (!_setupComplete && _bridge.valid) {
      if (!_instance) { //moduleClass未初始化_instance无值
        if (RCT_DEBUG && _requiresMainQueueSetup) { // DEBUG模式下断言是否在主队列
          RCTAssertMainQueue();
        }
      }
      // 调用_moduleProvider block 实现初始化
      _instance = _moduleProvider ? _moduleProvider() : nil;
      if (!_instance) {
        // Module init returned nil, probably because automatic instantatiation
        // of the module is not supported, and it is supposed to be passed in to
        // the bridge constructor. Mark setup complete to avoid doing more work.
        _setupComplete = YES;
        RCTLogWarn(@"The module %@ is returning nil from its constructor. You "
                   "may need to instantiate it yourself and pass it into the "
                   "bridge.", _moduleClass);
      }
      // Bridge must be set before methodQueue is set up, as methodQueue
      // initialization requires it (View Managers get their queue by calling
      // self.bridge.uiManager.methodQueue)
      [self setBridgeForInstance];
    }
    // 初始化 模块方法执行的队列
    [self setUpMethodQueue];
  }
  
  // This is called outside of the lock in order to prevent deadlock issues
  // because the logic in `finishSetupForInstance` can cause
  // `moduleData.instance` to be accessed re-entrantly.
  if (_bridge.moduleSetupComplete) {
    [self finishSetupForInstance];
  } else {
    // If we're here, then the module is completely initialized,
    // except for what finishSetupForInstance does.  When the instance
    // method is called after moduleSetupComplete,
    // finishSetupForInstance will run.  If _requiresMainQueueSetup
    // is true, getting the instance will block waiting for the main
    // thread, which could take a while if the main thread is busy
    // (I've seen 50ms in testing).  So we clear that flag, since
    // nothing in finishSetupForInstance needs to be run on the main
    // thread.
    _requiresMainQueueSetup = NO;
  }
  
}

- (void)setBridgeForInstance
{
  // 模块类实现了bridge方法并且不等于新赋值的_bridge
  if ([_instance respondsToSelector:@selector(bridge)] && _instance.bridge != _bridge) {
    @try {
      [(id)_instance setValue:_bridge forKey:@"bridge"];
    }
    @catch (NSException *exception) {
      RCTLogError(@"%@ has no setter or ivar for its bridge, which is not "
                  "permitted. You must either @synthesize the bridge property, "
                  "or provide your own setter method.", self.name);
    }
  }
}

- (void)finishSetupForInstance
{
  if (!_setupComplete && _instance) {
    _setupComplete = YES;
    [_bridge registerModuleForFrameUpdates:_instance withModuleData:self];
    [[NSNotificationCenter defaultCenter] postNotificationName:RCTDidInitializeModuleNotification
                                                        object:_bridge
                                                      userInfo:@{@"module": _instance, @"bridge": RCTNullIfNil(_bridge.parentBridge)}];
  }
}

// 为模块类的实例 指定一个methodQueue
- (void)setUpMethodQueue
{
  if (_instance && !_methodQueue && _bridge.valid) { //实例对象已经初始化，_bridge.valid有效，_methodQueue未初始化有值
    BOOL implementsMethodQueue = [_instance respondsToSelector:@selector(methodQueue)];
    if (implementsMethodQueue && _bridge.valid) { // 如果实现了模块实例对象已经自身赋值了methodQueue，就使用它
      _methodQueue = _instance.methodQueue;
    }
    if (!_methodQueue && _bridge.valid) { // _methodQueue还为空的话，就新创建一个
      // Create new queue (store queueName, as it isn't retained by dispatch_queue)
      _queueName = [NSString stringWithFormat:@"com.facebook.react.%@Queue", self.name];
      _methodQueue = dispatch_queue_create(_queueName.UTF8String, DISPATCH_QUEUE_SERIAL);
      
      // assign it to the module
      if (implementsMethodQueue) {
        @try {
          [(id)_instance setValue:_methodQueue forKey:@"methodQueue"];
        }
        @catch (NSException *exception) {
          RCTLogError(@"%@ is returning nil for its methodQueue, which is not "
                      "permitted. You must either return a pre-initialized "
                      "queue, or @synthesize the methodQueue to let the bridge "
                      "create a queue for you.", self.name);
        }
      }
    }
  }
}

- (dispatch_queue_t)methodQueue
{
  //(void)[self instance];
  RCTAssert(_methodQueue != nullptr, @"Module %@ has no methodQueue (instance: %@, bridge.valid: %d)",
            self, _instance, _bridge.valid);
  return _methodQueue;
}

- (void)invalidate
{
  _methodQueue = nil;
}


- (BOOL)hasInstance
{
  std::unique_lock<std::mutex> lock(_instanceLock);
  return _instance != nil;
}

- (id<RCTBridgeModule>)instance
{
  if (!_setupComplete) { // 第一次获取instance 肯定_setupComplete=NO
    if (_requiresMainQueueSetup) { // 如果模块class的init需要在主队列，就ExecuteOnMainQueue
      // The chances of deadlock here are low, because module init very rarely
      // calls out to other threads, however we can't control when a module might
      // get accessed by client code during bridge setup, and a very low risk of
      // deadlock is better than a fairly high risk of an assertion being thrown.
      if (!RCTIsMainQueue()) {
        RCTLogWarn(@"RCTBridge required dispatch_sync to load %@. This may lead to deadlocks", _moduleClass);
      }
      RCTUnsafeExecuteOnMainQueueSync(^{
        [self setUpInstanceAndBridge];
      });
    } else {
      [self setUpInstanceAndBridge];
    }
  }
  return _instance;
}

- (NSString *)name
{
  return RCTBridgeModuleNameForClass(_moduleClass);
}

- (NSArray<id<RCTBridgeMethod>> *)methods
{
  if (!_methods) {
    NSMutableArray<id<RCTBridgeMethod>> *moduleMethods = [NSMutableArray new];
    
    if ([_moduleClass instancesRespondToSelector:@selector(methodsToExport)]) {
      [moduleMethods addObjectsFromArray:[self.instance methodsToExport]];
    }
    
    unsigned int methodCount;
    Class cls = _moduleClass;
    while (cls && cls != [NSObject class] && cls != [NSProxy class]) {
      Method *methods = class_copyMethodList(object_getClass(cls), &methodCount);
      
      for (unsigned int i = 0; i < methodCount; i++) {
        Method method = methods[i];
        SEL selector = method_getName(method);
        NSLog(@"收集到模块class： %@的%@方法", cls, NSStringFromSelector(selector));
        if ([NSStringFromSelector(selector) hasPrefix:@"__rct_export__"]) {
//        IMP imp = method_getImplementation(method);
//        auto exportedMethod = ((const RCTMethodInfo *(*)(id, SEL))imp)(_moduleClass, selector);
          
//        [moduleMethods addObject:moduleMethod];
        }
      }
      
      free(methods);
      cls = class_getSuperclass(cls);
    }
    
    _methods = [moduleMethods copy];
  }
  return _methods;
}
- (NSString *)description
{
  return [NSString stringWithFormat:@"<%@: %p; name=\"%@\">", [self class], self, self.name];
}

@end
