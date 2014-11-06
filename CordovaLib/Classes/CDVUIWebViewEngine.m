/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

#import "CDVUIWebViewEngine.h"
#import "CDVUIWebViewDelegate.h"
#import "NSDictionary+CordovaPreferences.h"

#import <objc/message.h>

@interface CDVUIWebViewEngine ()

@property (nonatomic, strong, readwrite) UIView* engineWebView;

@end

// see forwardingTargetForSelector: selector comment for the reason for this pragma
#pragma clang diagnostic ignored "-Wprotocol"

@implementation CDVUIWebViewEngine

@synthesize engineWebView = _engineWebView;

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super init];
    if (self) {
        self.engineWebView = [[UIWebView alloc] initWithFrame:frame];
        NSLog(@"Using UIWebView");
    }

    return self;
}

- (void)evaluateJavaScript:(NSString*)javaScriptString completionHandler:(void (^)(id, NSError*))completionHandler
{
    NSString* ret = [(UIWebView*)_engineWebView stringByEvaluatingJavaScriptFromString : javaScriptString];

    if (completionHandler) {
        completionHandler(ret, nil);
    }
}

- (void)loadFileURL:(NSURL*)url allowingReadAccessToURL:(NSURL*)readAccessURL
{
    __weak CDVUIWebViewEngine* weakSelf = self;

    // UIKit operations have to be on the main thread. This method does not need to be synchronous
    dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf loadRequest:[NSURLRequest requestWithURL:url]];
        });
}

- (void)updateSettings:(NSDictionary*)settings
{
    UIWebView* uiWebView = (UIWebView*)_engineWebView;

    uiWebView.scalesPageToFit = [settings cordovaBoolSettingForKey:@"EnableViewportScale" defaultValue:NO];
    uiWebView.allowsInlineMediaPlayback = [settings cordovaBoolSettingForKey:@"AllowInlineMediaPlayback" defaultValue:NO];
    uiWebView.mediaPlaybackRequiresUserAction = [settings cordovaBoolSettingForKey:@"MediaPlaybackRequiresUserAction" defaultValue:YES];
    uiWebView.mediaPlaybackAllowsAirPlay = [settings cordovaBoolSettingForKey:@"MediaPlaybackAllowsAirPlay" defaultValue:YES];
    uiWebView.keyboardDisplayRequiresUserAction = [settings cordovaBoolSettingForKey:@"KeyboardDisplayRequiresUserAction" defaultValue:YES];
    uiWebView.suppressesIncrementalRendering = [settings cordovaBoolSettingForKey:@"SuppressesIncrementalRendering" defaultValue:NO];
    uiWebView.gapBetweenPages = [settings cordovaFloatSettingForKey:@"GapBetweenPages" defaultValue:0.0];
    uiWebView.pageLength = [settings cordovaFloatSettingForKey:@"PageLength" defaultValue:0.0];

    id prefObj = nil;

    // By default, DisallowOverscroll is false (thus bounce is allowed)
    BOOL bounceAllowed = !([settings cordovaBoolSettingForKey:@"DisallowOverscroll" defaultValue:NO]);

    // prevent webView from bouncing
    if (!bounceAllowed) {
        if ([self.webView respondsToSelector:@selector(scrollView)]) {
            ((UIScrollView*)[uiWebView scrollView]).bounces = NO;
        } else {
            for (id subview in self.webView.subviews) {
                if ([[subview class] isSubclassOfClass:[UIScrollView class]]) {
                    ((UIScrollView*)subview).bounces = NO;
                }
            }
        }
    }

    NSString* decelerationSetting = [settings cordovaSettingForKey:@"UIWebViewDecelerationSpeed"];
    if (![@"fast" isEqualToString : decelerationSetting]) {
        [uiWebView.scrollView setDecelerationRate:UIScrollViewDecelerationRateNormal];
    }

    NSInteger paginationBreakingMode = 0; // default - UIWebPaginationBreakingModePage
    prefObj = [settings cordovaSettingForKey:@"PaginationBreakingMode"];
    if (prefObj != nil) {
        NSArray* validValues = @[@"page", @"column"];
        NSString* prefValue = [validValues objectAtIndex:0];

        if ([prefObj isKindOfClass:[NSString class]]) {
            prefValue = prefObj;
        }

        paginationBreakingMode = [validValues indexOfObject:[prefValue lowercaseString]];
        if (paginationBreakingMode == NSNotFound) {
            paginationBreakingMode = 0;
        }
    }
    uiWebView.paginationBreakingMode = paginationBreakingMode;

    NSInteger paginationMode = 0; // default - UIWebPaginationModeUnpaginated
    prefObj = [settings cordovaSettingForKey:@"PaginationMode"];
    if (prefObj != nil) {
        NSArray* validValues = @[@"unpaginated", @"lefttoright", @"toptobottom", @"bottomtotop", @"righttoleft"];
        NSString* prefValue = [validValues objectAtIndex:0];

        if ([prefObj isKindOfClass:[NSString class]]) {
            prefValue = prefObj;
        }

        paginationMode = [validValues indexOfObject:[prefValue lowercaseString]];
        if (paginationMode == NSNotFound) {
            paginationMode = 0;
        }
    }
    uiWebView.paginationMode = paginationMode;
}

- (void)updateWithInfo:(NSDictionary*)info
{
    id <UIWebViewDelegate> uiWebViewDelegate = [info objectForKey:kCDVWebViewEngineUIWebViewDelegate];
    NSDictionary* settings = [info objectForKey:kCDVWebViewEngineWebViewPreferences];

    if (uiWebViewDelegate &&
        [uiWebViewDelegate conformsToProtocol:@protocol(UIWebViewDelegate)]) {
        ((UIWebView*)_engineWebView).delegate = uiWebViewDelegate;
    }

    if (settings && [settings isKindOfClass:[NSDictionary class]]) {
        [self updateSettings:settings];
    }
}

// This forwards the methods that are in the header that are not implemented here.
// Both WKWebView and UIWebView implement the below:
//     loadHTMLString:baseURL:
//     loadRequest:
- (id)forwardingTargetForSelector:(SEL)aSelector
{
    return _engineWebView;
}

@end
