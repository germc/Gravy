//
//  GRNetworking.m
//  Gravy
//
//  Created by Nathan Tesler on 29/01/13.
//  Copyright (c) 2013 Nathan Tesler. All rights reserved.
//

#import "GRNetworking.h"

NSString * const GRSerializationContextHTTPRequest = @"GRSerializationContextHTTPRequest";

@interface GRNetworkManager : NSObject 

+(GRNetworkManager *)sharedNetworkManager;

-(void)addRequest:(GRHTTPRequest *)request;
-(void)removeRequest:(GRHTTPRequest *)request;

@property (strong, nonatomic) NSMutableArray *activeRequests;

@end

@interface GRHTTPResponse ()

-(id)initWithResponse:(NSHTTPURLResponse *)response;

@end

@interface GRHTTPRequest ()

@property (strong, nonatomic) NSURL *URL;

@end

@implementation GRHTTPRequest

#pragma mark - Initialization

+(instancetype)request:(NSString *)path, ...
{
    // Override this with a more complex HTTPRequest in your subclass. Make sure to call [super request:path].
    GRHTTPRequest *request = [[self alloc] init];
    request.path = path;
    request.serializationCase = GRSerializationCaseSnakeCase;
    return request;
}

#pragma mark - Execution

-(void)load
{
    // Two conditions must be satisfied for the request to return here:
    // 1. An unreachable block is specified AND
    // 2. The network is unreachable OR the request does not allow cellular access AND WiFi is unreachable
    if (self.unreachableHandler && (![GRReachability isReachable] || (!self.allowsCellularAccess == NO && ![GRReachability isReachableViaWiFi])))
    {
        self.unreachableHandler();
        return;
    }

    // Add the request to the network manager
    [[GRNetworkManager sharedNetworkManager] addRequest:self];

    // Log the request
    #if DEBUG
    NSLog(@"%@", self);
    #endif

    // Add the data to the request
    if (self.payload)
        [self addPayloadAsJSON];

    // Load request
    [NSURLConnection sendAsynchronousRequest:self queue:[NSOperationQueue currentQueue] completionHandler:^(NSURLResponse *URLResponse, NSData *data, NSError *error){

        // Create a GRURLResponse
        GRHTTPResponse *response = [[GRHTTPResponse alloc] initWithResponse:(NSHTTPURLResponse *)URLResponse];

        // Map the data to the required class
        if (data)
            response.data = [GRSerialization objectWithJSON:data class:self.responseClass options:@{ GRSerializationOptionCaseKey: @(GRSerializationCaseLlamaCase) }];

        // Log the response
        #if DEBUG
        NSLog(@"%@", response);
        #endif

        // Execute specified response handlers
        if (self.successHandler && response.success)
            self.successHandler(response);
        if (self.failureHandler && !response.success)
            self.failureHandler(response);
        if (self.completionHandler)
            self.completionHandler(response);

        // Remove the request from the network manager
        [[GRNetworkManager sharedNetworkManager] removeRequest:self];
    }];
}

#pragma mark - URL creation

-(void)setBasePath:(NSString *)basePath
{
    _basePath = basePath;

    [self updateURL];
}

-(void)setPath:(NSString *)path
{
    _path = path;

    [self updateURL];
}

-(void)setParameters:(NSDictionary *)parameters
{
    _parameters = parameters;

    [self updateURL];
}

-(void)updateURL
{
    // Add path and parameters if given
    NSMutableString *path = [NSMutableString string];
    if (self.path)
        [path appendString:self.path];
    if ([self.parameters count])
        [path appendString:[self parametersString]];

    // Use basePath if given
    if (self.basePath)
        self.URL = [NSURL URLWithString:path relativeToURL:[NSURL URLWithString:self.basePath]];
    else
        self.URL = [NSURL URLWithString:path];
}

-(NSString *)parametersString
{
    NSMutableString *paramsString = [NSMutableString stringWithString:@"?"];

    int i = 0;
    for (NSString *key in self.parameters)
    {
        // Make key & value HTML safe
        NSString *safeKey = [key stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString *safeValue = [[NSString stringWithFormat:@"%@", [self.parameters valueForKey:key]] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

        // Append the pair to the parameter string
        [paramsString appendFormat:@"%@=%@", safeKey, safeValue];

        // Don't add an ampersand at the end
        i++;
        if (i != [self.parameters count])
            [paramsString appendString:@"&"];
    }

    return [paramsString copy];
}

#pragma mark - Data upload

-(void)addPayloadAsJSON
{
    // Add the accept JSON header
    if (![self valueForHTTPHeaderField:GRHTTPHeaderAccept])
        [self setValue:@"application/json" forHTTPHeaderField:GRHTTPHeaderAccept];

    // Convert the object as JSON
    NSDictionary *options = @{ GRSerializationOptionCaseKey: @(self.serializationCase),
                            GRSerializationOptionContextKey: self.serializationContext ?: GRSerializationContextHTTPRequest };
    NSData *json = [GRSerialization JSONWithObject:self.payload options:options];

    // Add object to HTTPBody
    NSMutableData *data = [[self HTTPBody] mutableCopy] ?: [NSMutableData data];
    [self setValue:[NSString stringWithFormat:@"%d", [json length]] forHTTPHeaderField:GRHTTPHeaderContentLength];
    [data appendData:json];
    [self setHTTPBody:data];
}

-(void)addMultipartFormData:(NSData *)data withName:(NSString *)name type:(NSString *)type filename:(NSString *)filename
{
    // String boundary
    NSString *boundaryString = @"<------BOUNDARY------>";

    // Add Content-Type header
    if (![self valueForHTTPHeaderField:GRHTTPHeaderContentType])
        [self addValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundaryString] forHTTPHeaderField:GRHTTPHeaderContentType];

    // Retrieve current post body or create the new data
    NSMutableData *postBody = [[self HTTPBody] mutableCopy] ?: [NSMutableData data];

    // Data
    NSString *boundary = [NSString stringWithFormat:@"\r\n--%@\r\n", boundaryString];
    NSData *metadata   = [[NSString stringWithFormat:@"%@Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n%@Content-Type: %@\r\n\r\n%@", boundary, name, filename, boundary, type, boundary] dataUsingEncoding:NSUTF8StringEncoding];

    // Append data
    [postBody appendData:metadata];
    [postBody appendData:data];

    // Set post body
    [self setHTTPBody:[postBody copy]];
}

#pragma mark - Description

-(NSString *)description
{
    return [NSString stringWithFormat:@"%@: [%@]:%@ <JSON: %@>", NSStringFromClass([self class]) , self.HTTPMethod, self.URL,
            self.HTTPBody ? [NSJSONSerialization JSONObjectWithData:self.HTTPBody options:0 error:nil] : @"No data"];
}

@end

#pragma mark - Response

@implementation GRHTTPResponse

-(id)initWithResponse:(NSHTTPURLResponse *)response
{
    if (self = [super initWithURL:response.URL statusCode:response.statusCode HTTPVersion:nil headerFields:[response allHeaderFields]])
    {
        self.success = (self.statusCode >= 200 && self.statusCode < 300);
    }
    return self;
}

-(NSString *)description
{
    return [NSString stringWithFormat:@"%@: [%i%@] <JSON: %@>", NSStringFromClass([self class]), self.statusCode,
            self.success ? @"" : [NSString stringWithFormat:@": %@", [GRHTTPResponse localizedStringForStatusCode:self.statusCode]],
            self.data ? [NSJSONSerialization JSONObjectWithData:self.data options:0 error:nil] : @"No data"];
}

@end

#pragma mark - Reachability

#import <SystemConfiguration/SystemConfiguration.h>
#import <netinet/in.h>

@interface GRReachability ()

@property (nonatomic) SCNetworkReachabilityRef reachability;
@property (nonatomic, strong) NSMutableArray *reachabilityObservers;
@property (nonatomic) SCNetworkReachabilityFlags statusCache;
@property (nonatomic) BOOL logsReachability;

@end

@implementation GRReachability

#pragma mark - Initialization

+(GRReachability *)sharedReachability
{
    static GRReachability *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Create a singleton for our reachability singleton
        sharedInstance = [[GRReachability alloc] init];
        sharedInstance.reachability = [self reachablityRef];
        sharedInstance.reachabilityObservers = [NSMutableArray array];
        [sharedInstance startNotifier];
    });
    return sharedInstance;
}

+(SCNetworkReachabilityRef)reachablityRef
{
    // Create and return a reachability reference using a zero address
    // We're just interested in the internet connection, not a specific hostname
    struct sockaddr_in zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sin_len    = sizeof(zeroAddress);
    zeroAddress.sin_family = AF_INET;

    return SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr*)&zeroAddress);
}

#pragma mark - Notifiers

-(BOOL)startNotifier
{
    // Set the callback for reachability changes
    SCNetworkReachabilitySetCallback(self.reachability, GRReachabilityCallback, NULL);

    // Create a queue and schedule the callback on it
    dispatch_queue_t reachabilityDispatchQueue = dispatch_queue_create("org.thegravytrain.reachability", NULL);
    SCNetworkReachabilitySetDispatchQueue(self.reachability, reachabilityDispatchQueue);

    return YES;
}

static void GRReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void* info)
{
    // Notify observers whenever we received a reachability callback
    [[GRReachability sharedReachability] reachabilityChanged:flags];
}

-(void)stopNotifier
{
    // Stop the callback
    SCNetworkReachabilitySetCallback(self.reachability, NULL, NULL);

    // Unregister the queue
    SCNetworkReachabilitySetDispatchQueue(self.reachability, NULL);
}

#pragma mark - Convenience methods

+(BOOL)isReachable
{
    return ([self reachabilityFlags] & kSCNetworkReachabilityFlagsReachable);
}

+(BOOL)isReachableViaWiFi
{
    return (([self reachabilityFlags] & kSCNetworkReachabilityFlagsReachable) &&
           !([self reachabilityFlags] & kSCNetworkReachabilityFlagsIsWWAN));
}

+(BOOL)isReachableViaCellular
{
    return (([self reachabilityFlags] & kSCNetworkReachabilityFlagsReachable) &&
            ([self reachabilityFlags] & kSCNetworkReachabilityFlagsIsWWAN));
}

+(SCNetworkReachabilityFlags)reachabilityFlags
{
    SCNetworkReachabilityFlags flags;
    SCNetworkReachabilityGetFlags([GRReachability sharedReachability].reachability, &flags);

    return flags;
}

#pragma mark - Reachability handlers

static const NSString *GRReachabilityObserverKey = @"GRReachabilityObserver";
static const NSString *GRReachabilityHandlerKey  = @"GRReachabilityHandler";

+(void)addReachabilityObserver:(id)observer withChangeHandler:(GRReachabilityChangeHandler)changeHandler
{
    // Use NSValue to create a weak reference to the object. This is an observer, so it must not be retained.
    NSValue *weakObserver = [NSValue valueWithNonretainedObject:observer];

    // Create information about the observer
    NSDictionary *observerInfo = @{ GRReachabilityObserverKey: weakObserver, GRReachabilityHandlerKey: changeHandler };

    // Store in the observers array
    [[GRReachability sharedReachability].reachabilityObservers addObject:observerInfo];
}

+(void)removeReachabilityObserver:(id)observer
{
    // Find the observer and remove it from the observer's array
    for (NSDictionary *observerDictionary in [GRReachability sharedReachability].reachabilityObservers)
    {
        if ([observerDictionary[GRReachabilityObserverKey] nonretainedObjectValue] == observer)
            [[GRReachability sharedReachability].reachabilityObservers removeObject:observerDictionary];
    }
}

-(void)reachabilityChanged:(SCNetworkReachabilityFlags)flags
{
    // If the reachability status is the same as the cache, do nothing
    if (self.statusCache == flags)
        return;

    // Set the cache
    self.statusCache = flags;

    // Log if necessary
    #if DEBUG
    if (self.logsReachability)
        [[self class] logReachability];
    #endif

    // Notify each observer
    for (NSDictionary *observer in self.reachabilityObservers)
    {
        // Execute handler on main thread
        GRReachabilityChangeHandler handler = observer[GRReachabilityHandlerKey];
        dispatch_async(dispatch_get_main_queue(), ^{
            handler();
        });
    }
}

#pragma mark - Logging

+(void)setLogsReachability:(BOOL)logsReachability
{
    [GRReachability sharedReachability].logsReachability = logsReachability;

    if (logsReachability)
        [self logReachability];
}

+(void)logReachability
{
    NSString *status = @"None";
    if ([GRReachability isReachableViaCellular])
        status = @"Cell";
    else if ([GRReachability isReachableViaWiFi])
        status = @"Wifi";

    NSLog(@"Reachability: %@", status);
}

@end

#pragma mark - Manager

@implementation GRNetworkManager

+(GRNetworkManager *)sharedNetworkManager
{
    static GRNetworkManager *sharedNetworkManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Create a singleton for our reachability singleton
        sharedNetworkManager = [[GRNetworkManager alloc] init];
        sharedNetworkManager.activeRequests = [NSMutableArray array];
    });
    return sharedNetworkManager;
}

#pragma mark - Network indicator management

-(void)addRequest:(GRHTTPRequest *)request
{
    [self.activeRequests addObject:request];

    [self updateNetworkIndicator];
}

-(void)removeRequest:(GRHTTPRequest *)request
{
    [self.activeRequests removeObject:request];

    [self updateNetworkIndicator];
}

-(void)updateNetworkIndicator
{
    // Get array of non-silent requests
    NSPredicate *silentPredicate = [NSPredicate predicateWithFormat:@"silent != YES"];
    NSArray *nonsilentRequests   = [self.activeRequests filteredArrayUsingPredicate:silentPredicate];

    // When a request is added or removed, the network indicator should update
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:[nonsilentRequests count]];
}

@end

// HTTPMethods
NSString * const GRHTTPMethodGET    = @"GET";
NSString * const GRHTTPMethodPOST   = @"POST";
NSString * const GRHTTPMethodPUT    = @"PUT";
NSString * const GRHTTPMethodDELETE = @"DELETE";
NSString * const GRHTTPMethodHEAD   = @"HEAD";
NSString * const GRHTTPMethodPATCH  = @"PATCH";

// HTTPRequestHeaders
NSString * const GRHTTPHeaderAccept                     = @"Accept";
NSString * const GRHTTPHeaderAcceptCharset              = @"Accept-Charset";
NSString * const GRHTTPHeaderAcceptEncoding             = @"Accept-Encoding";
NSString * const GRHTTPHeaderAcceptLanguage             = @"Accept-Language";
NSString * const GRHTTPHeaderAcceptDatetime             = @"Accept-Datetime";
NSString * const GRHTTPHeaderAuthorization              = @"Authorization";
NSString * const GRHTTPHeaderCacheControl               = @"Cache-Control";
NSString * const GRHTTPHeaderConnection                 = @"Connection";
NSString * const GRHTTPHeaderCookie                     = @"Cookie";
NSString * const GRHTTPHeaderContentLength              = @"Content-Length";
NSString * const GRHTTPHeaderContentMD5                 = @"Content-MD5";
NSString * const GRHTTPHeaderContentType                = @"Content-Type";
NSString * const GRHTTPHeaderDate                       = @"Date";
NSString * const GRHTTPHeaderExpect                     = @"Except";
NSString * const GRHTTPHeaderFrom                       = @"From";
NSString * const GRHTTPHeaderHost                       = @"Host";
NSString * const GRHTTPHeaderIfMatch                    = @"If-Match";
NSString * const GRHTTPHeaderIfModifiedSince            = @"If-Modified-Since";
NSString * const GRHTTPHeaderIfNoneMatch                = @"If-None-Match";
NSString * const GRHTTPHeaderIfRange                    = @"If-Range";
NSString * const GRHTTPHeaderIfUnmodifiedSince          = @"If-Unmodified-Since";
NSString * const GRHTTPHeaderMaxForwards                = @"Max-Forwards";
NSString * const GRHTTPHeaderPragma                     = @"Pragma";
NSString * const GRHTTPHeaderProxyAuthorization         = @"Proxy-Authorization";
NSString * const GRHTTPHeaderRange                      = @"Range";
NSString * const GRHTTPHeaderReferer                    = @"Referer";
NSString * const GRHTTPHeaderTE                         = @"TE";
NSString * const GRHTTPHeaderUpgrade                    = @"Upgrade";
NSString * const GRHTTPHeaderUserAgent                  = @"User-Agent";
NSString * const GRHTTPHeaderVia                        = @"Via";
NSString * const GRHTTPHeaderWarning                    = @"Warning";

// HTTPResponseHeaders
NSString * const GRHTTPHeaderAccessControlAllowOrigin   = @"Access-Control-Allow-Origin";
NSString * const GRHTTPHeaderAcceptRanges               = @"Accept-Ranges";
NSString * const GRHTTPHeaderAge                        = @"Age";
NSString * const GRHTTPHeaderAllow                      = @"Allow";
NSString * const GRHTTPHeaderContentEncoding            = @"Content-Encoding";
NSString * const GRHTTPHeaderContentLanguage            = @"Content-Language";
NSString * const GRHTTPHeaderContentLocation            = @"Content-Location";
NSString * const GRHTTPHeaderContentDisposition         = @"Content-Disposition";
NSString * const GRHTTPHeaderContentRange               = @"Content-Range";
NSString * const GRHTTPHeaderETag                       = @"ETag";
NSString * const GRHTTPHeaderExpires                    = @"Expires";
NSString * const GRHTTPHeaderLastModified               = @"Last-Modified";
NSString * const GRHTTPHeaderLink                       = @"Link";
NSString * const GRHTTPHeaderProxyAuthenticate          = @"Proxy-Authentication";
NSString * const GRHTTPHeaderRefresh                    = @"Refresh";
NSString * const GRHTTPHeaderRetryAfter                 = @"Retry-After";
NSString * const GRHTTPHeaderServer                     = @"Server";
NSString * const GRHTTPHeaderSetCookie                  = @"Set-Cookie";
NSString * const GRHTTPHeaderStrictTransportSecurity    = @"Strict-Transport-Security";
NSString * const GRHTTPHeaderTrailer                    = @"Trailer";
NSString * const GRHTTPHeaderTransferEncoding           = @"Transfer-Encoding";
NSString * const GRHTTPHeaderVary                       = @"Vary";
NSString * const GRHTTPHeaderWWWAuthenticate            = @"WWW-Authenticate";
