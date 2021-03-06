/*
 *  Copyright (c) 2018-present, Facebook, Inc.
 *
 *  This source code is licensed under the MIT license found in the LICENSE
 *  file in the root directory of this source tree.
 *
 */
#if FB_SONARKIT_ENABLED

#import "SKComponentLayoutDescriptor.h"

#import <ComponentKit/CKComponent.h>
#import <ComponentKit/CKComponentInternal.h>
#import <ComponentKit/CKComponentActionInternal.h>
#import <ComponentKit/CKComponentLayout.h>
#import <ComponentKit/CKComponentRootView.h>
#import <ComponentKit/CKComponentViewConfiguration.h>
#import <ComponentKit/CKComponentAccessibility.h>
#import <ComponentKit/CKComponentDebugController.h>
#import <ComponentKit/CKInsetComponent.h>
#import <ComponentKit/CKFlexboxComponent.h>

#import <FlipperKitLayoutPlugin/SKHighlightOverlay.h>
#import <FlipperKitLayoutPlugin/SKObject.h>

#import "SKComponentLayoutWrapper.h"
#import "CKComponent+Sonar.h"
#import "Utils.h"

@implementation SKComponentLayoutDescriptor
{
  NSDictionary<NSNumber *, NSString *> *CKFlexboxAlignSelfEnumMap;
  NSDictionary<NSNumber *, NSString *> *CKFlexboxPositionTypeEnumMap;
}

- (void)setUp {
  [super setUp];

  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    [self initEnumMaps];
  });
}

- (void)initEnumMaps {
  CKFlexboxAlignSelfEnumMap = @{
                                @(CKFlexboxAlignSelfAuto): @"auto",
                                @(CKFlexboxAlignSelfStart): @"start",
                                @(CKFlexboxAlignSelfEnd): @"end",
                                @(CKFlexboxAlignSelfCenter): @"center",
                                @(CKFlexboxAlignSelfBaseline): @"baseline",
                                @(CKFlexboxAlignSelfStretch): @"stretch",
                                };

  CKFlexboxPositionTypeEnumMap = @{
                                   @(CKFlexboxPositionTypeRelative): @"relative",
                                   @(CKFlexboxPositionTypeAbsolute): @"absolute",
                                   };
}

- (NSString *)identifierForNode:(SKComponentLayoutWrapper *)node {
  return node.identifier;
}

- (NSString *)nameForNode:(SKComponentLayoutWrapper *)node {
  return [node.component sonar_getName];
}

- (NSString *)decorationForNode:(SKComponentLayoutWrapper *)node {
  return [node.component sonar_getDecoration];
}

- (NSUInteger)childCountForNode:(SKComponentLayoutWrapper *)node {
  NSUInteger count = node.children.size();
  if (count == 0) {
    count = node.component.viewContext.view ? 1 : 0;
  }
  return count;
}

- (id)childForNode:(SKComponentLayoutWrapper *)node atIndex:(NSUInteger)index {
    if (node.children.size() == 0) {
      return node.component.viewContext.view;
    }
    return node.children[index];
}

- (NSArray<SKNamed<NSDictionary<NSString *, NSObject *> *> *> *)dataForNode:(SKComponentLayoutWrapper *)node {
  NSMutableArray<SKNamed<NSDictionary<NSString *, NSObject *> *> *> *data = [NSMutableArray new];

  if (node.isFlexboxChild) {
    [data addObject: [SKNamed newWithName:@"Layout" withValue:[self propsForFlexboxChild:node.flexboxChild]]];
  }

  [data addObjectsFromArray:[node.component sonar_getData]];

  return data;
}

#if !defined(FLIPPER_OSS)
- (NSDictionary<NSString *, NSString *> *) getNTMetaDataForChild:(CKFlexboxComponentChild)child
                           qualifier:(NSString *) qualifier
{
  NSString *str = @"{\"stackTrace\":{\"Content\":\":nt:flexbox :nt:text :nt:flexbox\"},\"unminifiedData\":{\"Content\":\"text\"}, \"graphQLCalls\":{\"Content\":\"text\"}}";
  NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];
  id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  if ([qualifier isEqualToString:@"Stack Trace"]) {
    NSDictionary *trace = [json objectForKey:@"stackTrace"];
    NSString *traceString = [[trace objectForKey:@"Content"] stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSArray *listItems = [traceString componentsSeparatedByString:@":nt:"];
    NSMutableArray *xhpComponents = [NSMutableArray array];;
    for (NSString *s in listItems) {
      if (![s isEqualToString:@""]) {
        NSString *xhpString = [NSString stringWithFormat:@"%@%@%@", @"<nt:", s, @">"];
        [xhpComponents addObject:xhpString];
      }
    }
    return @{@"Content": [xhpComponents componentsJoinedByString:@" "]};
  } else if ([qualifier isEqualToString:@"Unminified Payload"]) {
    return [json objectForKey:@"unminifiedData"];
  } else if ([qualifier isEqualToString:@"GraphQL Calls"]) {
    return [json objectForKey:@"graphQLCalls"];
  }
  return @{};
}
#endif
       
- (NSDictionary<NSString *, NSObject *> *)propsForFlexboxChild:(CKFlexboxComponentChild)child {
  return @{
           @"spacingBefore": SKObject(@(child.spacingBefore)),
#if !defined(FLIPPER_OSS)
           @"Native Templates": @{
               @"Stack Trace": [self getNTMetaDataForChild:child qualifier:@"Stack Trace"],
               @"Unminified Payload":[self getNTMetaDataForChild:child qualifier:@"Unminified Payload"],
               @"GraphQL Calls":[self getNTMetaDataForChild:child qualifier:@"GraphQL Calls"],
               },
#endif
           @"spacingAfter": SKObject(@(child.spacingAfter)),
           @"flexGrow": SKObject(@(child.flexGrow)),
           @"flexShrink": SKObject(@(child.flexShrink)),
           @"zIndex": SKObject(@(child.zIndex)),
           @"useTextRounding": SKObject(@(child.useTextRounding)),
           @"margin": flexboxRect(child.margin),
           @"flexBasis": relativeDimension(child.flexBasis),
           @"padding": flexboxRect(child.padding),
           @"alignSelf": CKFlexboxAlignSelfEnumMap[@(child.alignSelf)],
           @"position": @{
               @"type": CKFlexboxPositionTypeEnumMap[@(child.position.type)],
               @"start": relativeDimension(child.position.start),
               @"top": relativeDimension(child.position.top),
               @"end": relativeDimension(child.position.end),
               @"bottom": relativeDimension(child.position.bottom),
               @"left": relativeDimension(child.position.left),
               @"right": relativeDimension(child.position.right),
               },
           @"aspectRatio": @(child.aspectRatio.aspectRatio()),
           };
}

- (NSDictionary<NSString *, SKNodeUpdateData> *)dataMutationsForNode:(SKComponentLayoutWrapper *)node {
  return [node.component sonar_getDataMutations];
}

- (NSArray<SKNamed<NSString *> *> *)attributesForNode:(SKComponentLayoutWrapper *)node {
  return @[
           [SKNamed newWithName: @"responder"
                      withValue: SKObject(NSStringFromClass([node.component.nextResponder class]))]
           ];
}

- (void)setHighlighted:(BOOL)highlighted forNode:(SKComponentLayoutWrapper *)node {
  SKHighlightOverlay *overlay = [SKHighlightOverlay sharedInstance];
  if (highlighted) {
    CKComponentViewContext viewContext = node.component.viewContext;
    [overlay mountInView: viewContext.view
               withFrame: viewContext.frame];
  } else {
    [overlay unmount];
  }
}

- (void)hitTest:(SKTouch *)touch forNode:(SKComponentLayoutWrapper *)node {
  if (node.children.size() == 0) {
    UIView *componentView = node.component.viewContext.view;
    if (componentView != nil) {
      if ([touch containedIn: componentView.bounds]) {
        [touch continueWithChildIndex: 0 withOffset: componentView.bounds.origin];
        return;
      }
    }
  }

  NSInteger index = 0;
  for (index = node.children.size() - 1; index >= 0; index--) {
    const auto child = node.children[index];

    CGRect frame = {
      .origin = child.position,
      .size = child.size
    };

    if ([touch containedIn: frame]) {
      [touch continueWithChildIndex: index withOffset: child.position];
      return;
    }
  }

  [touch finish];
}

@end

#endif
