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
//  if (modules_.empty() && unknownModules_.empty()) {
//    modules_ = std::move(modules);
//  } else {
//    size_t modulesSize = modules_.size();
//    size_t addModulesSize = modules.size();
//    bool addToNames = !modulesByName_.empty();
//    modules_.reserve(modulesSize + addModulesSize);
//    std::move(modules.begin(), modules.end(), std::back_inserter(modules_));
//    if (!unknownModules_.empty()) {
//      for (size_t index = modulesSize; index < modulesSize + addModulesSize; index++) {
//        std::string name = normalizeName(modules_[index]->getName());
//        auto it = unknownModules_.find(name);
//        if (it != unknownModules_.end()) {
//          throw std::runtime_error(
//            folly::to<std::string>("module ", name, " was required without being registered and is now being registered."));
//        } else if (addToNames) {
//          modulesByName_[name] = index;
//        }
//      }
//    } else if (addToNames) {
//      updateModuleNamesFromIndex(modulesSize);
//    }
//  }
}

std::vector<std::string> ModuleRegistry::moduleNames() {
  std::vector<std::string> names;
//  for (size_t i = 0; i < modules_.size(); i++) {
//    std::string name = normalizeName(modules_[i]->getName());
//    modulesByName_[name] = i;
//    names.push_back(std::move(name));
//  }
  return names;
}

folly::Optional<ModuleConfig> ModuleRegistry::getConfig(const std::string& name) {
  
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
  folly::dynamic config = folly::dynamic::array(name);
  config.push_back(module->getConstants());
  
  
  std::vector<MethodDescriptor> methods = module->getMethods();
  
  folly::dynamic methodNames = folly::dynamic::array;
  folly::dynamic promiseMethodIds = folly::dynamic::array;
  folly::dynamic syncMethodIds = folly::dynamic::array;
  
  for (auto& descriptor : methods) {
    // TODO: #10487027 compare tags instead of doing string comparison?
    methodNames.push_back(std::move(descriptor.name));
    if (descriptor.type == "promise") {
      promiseMethodIds.push_back(methodNames.size() - 1);
    } else if (descriptor.type == "sync") {
      syncMethodIds.push_back(methodNames.size() - 1);
    }
  }
  
  if (!methodNames.empty()) {
    config.push_back(std::move(methodNames));
    if (!promiseMethodIds.empty() || !syncMethodIds.empty()) {
      config.push_back(std::move(promiseMethodIds));
      if (!syncMethodIds.empty()) {
        config.push_back(std::move(syncMethodIds));
      }
    }
  }
  
  
  if (config.size() == 2 && config[1].empty()) {
    // no constants or methods
    return nullptr;
  } else {
    return ModuleConfig{name, config};
  }
}
  
void ModuleRegistry::callNativeMethod(std::string moduleName, std::string methodName, folly::dynamic&& params, int callId) {
  auto it = nameMoudles_.find(moduleName);
  if (it == nameMoudles_.end()) {
    throw std::runtime_error(
      folly::to<std::string>("moduleName", moduleName, " not existed"));
  }
  NativeModule *module = it->second.get();
  module->invoke(methodName, std::move(params), callId);
}

MethodCallResult ModuleRegistry::callSerializableNativeHook(std::string moduleName, std::string methodName, folly::dynamic&& params) {
  auto it = nameMoudles_.find(moduleName);
  if (it == nameMoudles_.end()) {
    throw std::runtime_error(
                             folly::to<std::string>("moduleName", moduleName, " not existed"));
  }
  NativeModule *module = it->second.get();
  return module->callSerializableNativeHook(methodName, std::move(params));
}

}}
