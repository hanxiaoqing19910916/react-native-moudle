// Copyright (c) 2004-present, Facebook, Inc.

// This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

#pragma once

#include <memory>
#include <unordered_set>
#include <vector>

#include "NativeModule.h"
#include <folly/Optional.h>
#include <folly/dynamic.h>

#ifndef RN_EXPORT
#define RN_EXPORT __attribute__((visibility("default")))
#endif

namespace facebook {
namespace react {

class NativeModule;

struct ModuleConfig {
  std::string name;
  folly::dynamic config;
};

class RN_EXPORT ModuleRegistry {
 public:
  // not implemented:
  // onBatchComplete: see https://our.intern.facebook.com/intern/tasks/?t=5279396
  // getModule: only used by views
  // getAllModules: only used for cleanup; use RAII instead
  // notifyCatalystInstanceInitialized: this is really only used by view-related code
  // notifyCatalystInstanceDestroy: use RAII instead

  using ModuleNotFoundCallback = std::function<bool(const std::string &name)>;
  
  ModuleRegistry(std::unordered_map<std::string, std::unique_ptr<NativeModule>> nameMoudles, ModuleNotFoundCallback callback = nullptr);
  void registerModules(std::vector<std::unique_ptr<NativeModule>> modules);

  std::vector<std::string> moduleNames();

  folly::Optional<ModuleConfig> getConfig(const std::string& name);

  void callNativeMethod(std::string moduleName, std::string methodName, folly::dynamic&& params, int callId);
  MethodCallResult callSerializableNativeHook(std::string moduleName, std::string methodName, folly::dynamic&& args);

 private:
  std::unordered_map<std::string, std::unique_ptr<NativeModule>> nameMoudles_;

  // This is populated with modules that are requested via getConfig but are unknown.
  // An error will be thrown if they are subsequently added to the registry.
  std::unordered_set<std::string> unknownModules_;

  // Function will be called if a module was requested but was not found.
  // If the function returns true, ModuleRegistry will try to find the module again (assuming it's registered)
  // If the functon returns false, ModuleRegistry will not try to find the module and return nullptr instead.
  ModuleNotFoundCallback moduleNotFoundCallback_;
};

}
}
