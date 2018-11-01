/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#include <memory>
#import "RCTNativeModule.h"
#import <cxxreact/ModuleRegistry.h>

@class RCTBridge;
@class RCTModuleData;

namespace facebook {
namespace react {

std::vector<std::unique_ptr<NativeModule>> createNativeModules(NSArray<RCTModuleData *> *modules, RCTBridge *bridge);
  
std::shared_ptr<ModuleRegistry> buildModuleRegistry();

} }
