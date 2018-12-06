// Copyright (c) 2004-present, Facebook, Inc.

// This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

#include "ModuleRegistry.h"

#include <glog/logging.h>


namespace facebook {
namespace react {

namespace {

std::string normalizeName(std::string name) {
  // TODO mhorowitz #10487027: This is super ugly.  We should just
  // change iOS to emit normalized names, drop the "RK..." from
  // names hardcoded in Android, and then delete this and the
  // similar hacks in js.
  if (name.compare(0, 3, "RCT") == 0) {
    return name.substr(3);
  } else if (name.compare(0, 2, "RK") == 0) {
    return name.substr(2);
  }
  return name;
}

}

  
ModuleRegistry::ModuleRegistry(std::unordered_map<std::string, std::unique_ptr<NativeModule>> nameMoudles, ModuleNotFoundCallback callback)
  : nameMoudles_{std::move(nameMoudles)}, moduleNotFoundCallback_{callback} {}

  

void ModuleRegistry::registerModules(std::vector<std::unique_ptr<NativeModule>> modules) {
  
}

std::vector<std::string> ModuleRegistry::moduleNames() {
  std::vector<std::string> names;
  for (auto& m : nameMoudles_) {
     std::string name = normalizeName(m.second->getName());
     names.push_back(std::move(name));
  }
  return names;
}

std::unique_ptr<ModuleConfig> ModuleRegistry::getConfig(const std::string& name) {
  
  if (nameMoudles_.empty()) {
    return nullptr;
  }

  auto it = nameMoudles_.find(name);
  
  if (it == nameMoudles_.end()) {
    if (unknownModules_.find(name) != unknownModules_.end()) {
      return nullptr;
    }
    if (!moduleNotFoundCallback_ ||
        !moduleNotFoundCallback_(name) ||
        (it = nameMoudles_.find(name)) == nameMoudles_.end()) {
      unknownModules_.insert(name);
      return nullptr;
    }
  }

  NativeModule *module = it->second.get();
  
  // string name, object constants, array methodNames (methodId is index), [array promiseMethodIds], [array syncMethodIds]
  json11::Json::array config = json11::Json::array();
  
  config.push_back(json11::Json(name));
  config.push_back(module->getConstants());
 
  std::vector<MethodDescriptor> methods = module->getMethods();
 
  json11::Json::array methodNames = json11::Json::array();
  json11::Json::array promiseMethodIds = json11::Json::array();
  json11::Json::array syncMethodIds = json11::Json::array();
  
//
//  for (auto& descriptor : methods) {
//    // TODO: #10487027 compare tags instead of doing string comparison?
//    methodNames.push_back(std::move(descriptor.name));
//    if (descriptor.type == "promise") {
//      promiseMethodIds.push_back(methodNames.size() - 1);
//    } else if (descriptor.type == "sync") {
//      syncMethodIds.push_back(methodNames.size() - 1);
//    }
//  }
//
//  if (!methodNames.empty()) {
//    config.push_back(std::move(methodNames));
//    if (!promiseMethodIds.empty() || !syncMethodIds.empty()) {
//      config.push_back(std::move(promiseMethodIds));
//      if (!syncMethodIds.empty()) {
//        config.push_back(std::move(syncMethodIds));
//      }
//    }
//  }
//
//
//  if (config.size() == 2 && config[1].empty()) {
//    // no constants or methods
//    return nullptr;
//  } else {
//    return ModuleConfig{name, config};
//  }
  return nullptr;
}
  
void ModuleRegistry::callNativeMethod(std::string moduleName, std::string methodName, json11::Json&& params, int callId) {
  auto it = nameMoudles_.find(moduleName);
  if (it == nameMoudles_.end()) {
//    throw std::runtime_error(
//                             folly::to<std::string>("moduleName: ", moduleName, " not existed"));
  }
  NativeModule *module = it->second.get();
  module->invoke(methodName, std::move(params), callId);
}

MethodCallResult ModuleRegistry::callSerializableNativeHook(std::string moduleName, std::string methodName, json11::Json&& params) {
  auto it = nameMoudles_.find(moduleName);
  if (it == nameMoudles_.end()) {
//    throw std::runtime_error(
//                             folly::to<std::string>("moduleName", moduleName, " not existed"));
  }
  NativeModule *module = it->second.get();
  return module->callSerializableNativeHook(methodName, std::move(params));
}

}}
