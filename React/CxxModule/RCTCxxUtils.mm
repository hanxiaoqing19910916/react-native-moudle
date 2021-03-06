/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RCTCxxUtils.h"

#import <React/RCTJsonConvert.h>
#import <React/RCTModuleData.h>
#import <React/RCTUtils.h>
#import "RCTCxxBridge.h"


namespace facebook {
namespace react {

  
std::shared_ptr<ModuleRegistry> buildModuleRegistry()
{
  //  init a Bridge
  RCTBridge *rctBridge = [[RCTBridge alloc] initWithModuleProvider:nil launchOptions:nil];
  NSMutableDictionary<NSString *, RCTModuleData *> *moduleDataByName = [(RCTCxxBridge *)rctBridge.batchedBridge moduleDataByName];
  return std::make_shared<ModuleRegistry>(createNativeModules(moduleDataByName, rctBridge),
                                                     nullptr);
}

  
std::unordered_map<std::string, std::unique_ptr<NativeModule>> createNativeModules(NSDictionary<NSString *, RCTModuleData *> *moduleDataByName, RCTBridge *bridge)
{
  std::unordered_map<std::string, std::unique_ptr<NativeModule>> nameMoudles;
  for (NSString *moduleName in moduleDataByName) {
    std::string name = moduleName.UTF8String;
    nameMoudles[name] = std::make_unique<RCTNativeModule>(bridge, moduleDataByName[moduleName]);
  }
  return nameMoudles;
}
  
} }
