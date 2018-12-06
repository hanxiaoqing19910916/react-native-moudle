/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <React/RCTModuleData.h>
#import <cxxreact/NativeModule.h>

namespace facebook {
namespace react {

class RCTNativeModule : public NativeModule {
 public:
  RCTNativeModule(RCTBridge *bridge, RCTModuleData *moduleData);

  std::string getName() override;
  std::vector<MethodDescriptor> getMethods() override;
  json11::Json getConstants() override;
  void invoke(std::string methodName, json11::Json &&params, int callId) override;
  MethodCallResult callSerializableNativeHook(std::string methodName, json11::Json &&params) override;

 private:
  __weak RCTBridge *m_bridge;
  RCTModuleData *m_moduleData;
};

}
}
