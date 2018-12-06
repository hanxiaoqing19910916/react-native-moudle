/**
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>
#include "json11.hpp"

namespace facebook {
namespace react {
  
json11::Json convertIdToCxxJson(id json);
id convertCxxJsonToId(const json11::Json &cjn);
//folly::dynamic convertIdToFollyDynamic(id json);
//id convertFollyDynamicToId(const folly::dynamic &dyn);
//        
} }
