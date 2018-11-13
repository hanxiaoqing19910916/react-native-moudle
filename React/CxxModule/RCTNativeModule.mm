/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RCTNativeModule.h"

#import <React/RCTBridge.h>
#import <React/RCTBridgeMethod.h>
#import <React/RCTBridgeModule.h>

#import <React/RCTCxxUtils.h>
#import <React/RCTFollyConvert.h>
#import <React/RCTLog.h>
#import <React/RCTUtils.h>


namespace facebook {
namespace react {

static MethodCallResult invokeInner(RCTBridge *bridge, RCTModuleData *moduleData, std::string methodName, const folly::dynamic &params);

RCTNativeModule::RCTNativeModule(RCTBridge *bridge, RCTModuleData *moduleData)
    : m_bridge(bridge)
    , m_moduleData(moduleData) {}

std::string RCTNativeModule::getName() {
  return [m_moduleData.name UTF8String];
}

std::vector<MethodDescriptor> RCTNativeModule::getMethods() {
  std::vector<MethodDescriptor> descs;

//  for (id<RCTBridgeMethod> method in m_moduleData.methods) {
//    descs.emplace_back(
//      method.JSMethodName,
//      RCTFunctionDescriptorFromType(method.functionType)
//    );
//  }

  return descs;
}

folly::dynamic RCTNativeModule::getConstants() {
  return nullptr;
}
  


void RCTNativeModule::invoke(std::string methodName, folly::dynamic &&params, int callId) {
   invokeInner(m_bridge, m_moduleData, methodName, std::move(params));
}

MethodCallResult RCTNativeModule::callSerializableNativeHook(std::string methodName, folly::dynamic &&params) {
  return invokeInner(m_bridge, m_moduleData, methodName, params);
}

static MethodCallResult invokeInner(RCTBridge *bridge, RCTModuleData *moduleData, std::string methodName, const folly::dynamic &params) {
  if (!bridge || !bridge.valid || !moduleData) {
    return folly::none;
  }

  NSString *toFindMethodName = [NSString stringWithCString:methodName.c_str() encoding:NSUTF8StringEncoding];
  id<RCTBridgeMethod> method = moduleData.methodsByName[toFindMethodName];
  if (RCT_DEBUG && !method) {
    RCTLogError(@"Unknown methodID: %@ for module: %@",
                toFindMethodName, moduleData.name);
  }

  NSArray *objcParams = convertFollyDynamicToId(params);
  @try {
    id result = [method invokeWithBridge:bridge module:moduleData.instance arguments:objcParams];
    return convertIdToFollyDynamic(result);
  }
  @catch (NSException *exception) {
    // Pass on JS exceptions
    if ([exception.name hasPrefix:RCTFatalExceptionName]) {
      @throw exception;
    }

    NSString *message = [NSString stringWithFormat:
                         @"Exception '%@' was thrown while invoking %s on target %@ with params %@\ncallstack: %@",
                         exception, method.JSMethodName, moduleData.name, objcParams, exception.callStackSymbols];
    RCTFatal(RCTErrorWithMessage(message));
  }

  return folly::none;
}

}
}
