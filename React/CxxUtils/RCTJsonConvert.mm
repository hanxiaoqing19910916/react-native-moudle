/**
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RCTJsonConvert.h"

#import <objc/runtime.h>

namespace facebook {
namespace react {

id convertCxxJsonToId(const json11::Json &cjn) {
  
  switch (cjn.type()) {
    case json11::Json::NUL:
      return @[];
    case json11::Json::BOOL:
      return cjn.bool_value() ? @YES : @NO;
    case json11::Json::NUMBER:
      if (cjn.int_value()) {
        return @(cjn.int_value());
      } else {
        return @(cjn.number_value());
      }
    case json11::Json::STRING:
      return [NSString stringWithUTF8String:cjn.string_value().c_str()];
    case json11::Json::ARRAY: {
      NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:cjn.array_items().size()];
      for (auto &elem : cjn.array_items()) {
        [array addObject:convertCxxJsonToId(elem)];
      }
      return array;
    }
    case json11::Json::OBJECT: {
      NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithCapacity:cjn.object_items().size()];
      for (auto &elem : cjn.object_items()) {
        dict[convertCxxJsonToId(elem.first)] = convertCxxJsonToId(elem.second);
      }
      return dict;
    }
  }
    return nil;
}

  
json11::Json convertIdToCxxJson(id json) {
  if (json == nil || json == (id)kCFNull) {
    return nullptr;
  } else if ([json isKindOfClass:[NSNumber class]]) {
    const char *objCType = [json objCType];
    switch (objCType[0]) {
        // This is a c++ bool or C99 _Bool.  On some platforms, BOOL is a bool.
      case _C_BOOL:
        return (bool) [json boolValue];
      case _C_CHR:
        // On some platforms, objc BOOL is a signed char, but it
        // might also be a small number.  Use the same hack JSC uses
        // to distinguish them:
        // https://phabricator.intern.facebook.com/diffusion/FBS/browse/master/fbobjc/xplat/third-party/jsc/safari-600-1-4-17/JavaScriptCore/API/JSValue.mm;b8ee03916489f8b12143cd5c0bca546da5014fc9$901
        if ([json isKindOfClass:[@YES class]]) {
          return (bool) [json boolValue];
        } else {
          return [json intValue];
        }
      case _C_UCHR:
      case _C_SHT:
      case _C_USHT:
      case _C_INT:
      case _C_UINT:
      case _C_LNG:
      case _C_ULNG:
      case _C_LNG_LNG:
      case _C_ULNG_LNG:
        return [json intValue];
        
      case _C_FLT:
      case _C_DBL:
        return [json doubleValue];
        
        // default:
        //   fall through
    }
  } else if ([json isKindOfClass:[NSString class]]) {
    NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
    return std::string(reinterpret_cast<const char*>(data.bytes),
                       data.length);
  } else if ([json isKindOfClass:[NSArray class]]) {
    json11::Json::array array = json11::Json::array();
    for (id element in json) {
      array.push_back(convertIdToCxxJson(element));
    }
    return array;
  } else if ([json isKindOfClass:[NSDictionary class]]) {
    __block std::map<std::string, json11::Json> object = {};
    [json enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, __unused BOOL *stop) {
      NSData *data = [key dataUsingEncoding:NSUTF8StringEncoding];
      std::string _key = std::string(reinterpret_cast<const char*>(data.bytes),
                         data.length);
      object[_key] = convertIdToCxxJson(value);
    }];
    return object;
  }
  return nil;
}




} }
