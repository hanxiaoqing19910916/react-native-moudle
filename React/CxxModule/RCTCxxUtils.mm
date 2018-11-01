/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RCTCxxUtils.h"

#import <React/RCTFollyConvert.h>
#import <React/RCTModuleData.h>
#import <React/RCTUtils.h>
#import "RCTCxxBridge.h"


//- (std::shared_ptr<ModuleRegistry>)_buildModuleRegistry
//{
//  if (!self.valid) {
//    return {};
//  }
//
//  __weak __typeof(self) weakSelf = self;
//  ModuleRegistry::ModuleNotFoundCallback moduleNotFoundCallback = ^bool(const std::string &name) {
//    return true;
//  };
//
//  auto registry = std::make_shared<ModuleRegistry>(
//                                                   createNativeModules(_moduleDataByID, self),
//                                                   moduleNotFoundCallback);
//  return registry;
//}

namespace facebook {
namespace react {

  
  
std::shared_ptr<ModuleRegistry> buildModuleRegistry()
{
  return std::make_shared<ModuleRegistry>(createNativeModules(nullptr, nullptr),
                                                     nullptr);
}

std::vector<std::unique_ptr<NativeModule>> createNativeModules(NSArray<RCTModuleData *> *modules, RCTBridge *bridge)
{
  std::vector<std::unique_ptr<NativeModule>> nativeModules;
  for (RCTModuleData *moduleData in modules) {
    nativeModules.emplace_back(std::make_unique<RCTNativeModule>(bridge, moduleData));
  }
  return nativeModules;
}
  
} }
