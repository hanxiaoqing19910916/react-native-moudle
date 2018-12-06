// Copyright (c) Facebook, Inc. and its affiliates.

// This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

#pragma once

#ifndef NativeModule_H
#define NativeModule_H

#include <string>
#include <vector>

#include "json11.hpp"

namespace facebook {
namespace react {

struct MethodDescriptor {
  std::string name;
  // type is one of js MessageQueue.MethodTypes
  std::string type;

  MethodDescriptor(std::string n, std::string t)
      : name(std::move(n))
      , type(std::move(t)) {}
};

using MethodCallResult = std::unique_ptr<json11::Json>;

class NativeModule {
 public:
  virtual ~NativeModule() {}
  virtual std::string getName() = 0;
  virtual std::vector<MethodDescriptor> getMethods() = 0;
  virtual json11::Json getConstants() = 0;
  virtual void invoke(std::string methodName, json11::Json&& params, int callId) = 0;
  virtual MethodCallResult callSerializableNativeHook(std::string methodName, json11::Json&& args) = 0;
};
  

}
}

#endif
