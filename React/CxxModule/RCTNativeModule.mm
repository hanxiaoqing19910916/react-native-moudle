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
#import <React/RCTJsonConvert.h>
#import <React/RCTLog.h>
#import <React/RCTUtils.h>


namespace facebook {
namespace react {

static MethodCallResult invokeInner(RCTBridge *bridge, RCTModuleData *moduleData, std::string methodName, const json11::Json &params);

RCTNativeModule::RCTNativeModule(RCTBridge *bridge, RCTModuleData *moduleData)
    : m_bridge(bridge)
    , m_moduleData(moduleData) {}

std::string RCTNativeModule::getName() {
  return [m_moduleData.name UTF8String];
}

std::vector<MethodDescriptor> RCTNativeModule::getMethods() {
  std::vector<MethodDescriptor> descs;

  for (id<RCTBridgeMethod> method in m_moduleData.methodsByName.allValues) {
    descs.emplace_back(
      method.JSMethodName,
      RCTFunctionDescriptorFromType(method.functionType)
    );
  }

  return descs;
}

json11::Json RCTNativeModule::getConstants() {
  return nullptr;
}
  


void RCTNativeModule::invoke(std::string methodName, json11::Json &&params, int callId) {
   invokeInner(m_bridge, m_moduleData, methodName, std::move(params));
}

MethodCallResult RCTNativeModule::callSerializableNativeHook(std::string methodName, json11::Json &&params) {
  return invokeInner(m_bridge, m_moduleData, methodName, params);
}

static MethodCallResult invokeInner(RCTBridge *bridge, RCTModuleData *moduleData, std::string methodName, const json11::Json &params) {
  if (!bridge || !bridge.valid || !moduleData) {
    return nullptr;
  }

  NSString *toFindMethodName = [NSString stringWithCString:methodName.c_str() encoding:NSUTF8StringEncoding];
  id<RCTBridgeMethod> method = moduleData.methodsByName[toFindMethodName];
  if (RCT_DEBUG && !method) {
    RCTLogError(@"Unknown methodID: %@ for module: %@",
                toFindMethodName, moduleData.name);
  }
 
  NSArray *objcParams = convertCxxJsonToId(params);
  @try {
    id result = [method invokeWithBridge:bridge module:moduleData.instance arguments:objcParams];
    return std::make_unique<json11::Json>(convertIdToCxxJson(result));
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

  return nullptr;
}

}
}
