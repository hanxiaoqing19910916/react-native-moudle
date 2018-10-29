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


namespace facebook {
namespace react {

std::vector<std::unique_ptr<NativeModule>> createNativeModules(NSArray<RCTModuleData *> *modules, RCTBridge *bridge)
{
  std::vector<std::unique_ptr<NativeModule>> nativeModules;
  for (RCTModuleData *moduleData in modules) {

      nativeModules.emplace_back(std::make_unique<RCTNativeModule>(bridge, moduleData));
  }
  return nativeModules;
}



} }
