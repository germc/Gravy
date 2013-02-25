//
//  GRNetworking.h
//  Gravy
//
//  Created by Nathan Tesler on 29/01/13.
//  Copyright (c) 2013 Nathan Tesler. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GRSerialization.h"

/* Gravy's networking system is dead simple. You create GRHTTPRequests, customize them and send them a `load` message. You then receive GRHTTPResponse objects which contain the data you requested.

 # Usage

 To fetch an array of users from an api endpoint, you could use the following code:

    +(void)fetchFollowers
    {
        // Create the request
        GRHTTPRequest *request = [GRHTTPRequest request:@"http://api.myserver.com/users/%i/followers.json", self.user.identifier];
        request.responseClass  = [MYUser class];

        // Handle response scenarios
        request.successHandler = ^(GRHTTPResponse *response){
            self.users = response.data;
        };
        request.unreachableHandler = ^{
            NSLog(@"Check your internet connection!");
        }
 
        // Load the request
        [request load];
    }
 
 This code fetches the JSON data from the URL, then creates an array of MYUser objects from the returned data.
 
 You can subclass GRHTTPRequest and override the `+request:` method to create a "standard request". For example, you can create MYAPIRequest, and in your `+request` method add the following code:

     +(instancetype)request:(NSString *)path, ...
     {
         // Create the request
         MYAPIRequest *request = [super request:path];
         request.basePath = @"https://api.myserver.com/";

         // Customize the header fields
         [request setValue:MY_AUTH_CODE forHTTPHeaderField:GRHTTPHeaderAuthorization];

         return request;
     }
 
 And use the following code:
 
    +(void)saveUser
    {
        // Create the request
        MYAPIRequest *request = [MYAPIRequest request:@"users/%i"];
        request.HTTPMethod = GRHTTPMethodPOST;

        // Add the user as a JSON object
        [request addObject:self.user];
    
        // Handle response
        request.successHandler = ^(GRHTTPResponse *response){
            NSLog(@"Saved!");
        };

        // Load the request
        [request load];
    }

 Note: Gravy only supports JSON. If you are not using JSON, I feel bad for you son. 99 problems but XML ain't one.
 */

@class GRHTTPResponse;
@interface GRHTTPRequest : NSMutableURLRequest

///
/// Creation
///

/* Creates and returns a request with the given format string as its path. You can override this method in your subclass to create a boilerplate or standard request, but make sure to call [super request:path] in your implementation.
 @discussion If no basePath is supplied, the path should contain all information necessary to build a URL (protocol, hostname, path).
 @param path A format string containing the path
 */
+(instancetype)request:(NSString *)path,...;

///
/// Customization & Loading
///

/* This is a redefinition of the URL property to make it readonly. The URL is generated automatically by the basePath, path and parameter properties, and this property is only useful for inspecting the final result. */
@property (strong, nonatomic, readonly) NSURL *URL;

/* The base path of the request. If supplied, the given path property will be appended to the basePath. */
@property (strong, nonatomic) NSString *basePath;

/* The path of the request. For example, with a basePath of "http://example.com/", a path of "hello" will produce "http://example.com/hello". If there is no basePath, the path must be a full URL with protocol, hostname and path. */
@property (strong, nonatomic) NSString *path;

/* An NSDictionary representing the parameters of the request. They are appended to the end of the url. */
@property (strong, nonatomic) NSDictionary *parameters;

/* If set to YES, the network activity indicator will not show when the request is loading. Default: NO. */
@property (nonatomic) BOOL silent;

/* Loads the request asynchronously. If response handlers are supplied, they will be executed as needed. */
-(void)load;

///
/// Data & serialization
///

/* This property will be added to the request as JSON data when the request is sent a `-load` message. It must be serializable. See GRSerialization for more info. */
@property (strong, nonatomic) id payload;

/* The class to which to serialize the returned data. For example, if you set this property to `[MYUser class]` and the request returns a payload of an array with 5 dictionaries, each dictionary will become a MYUser object. Set this property to `[GRObject class]` to prompt Gravy to infer the class of the response on its own. See the GRNetworking and GRSerialization docs for more info. */
@property (strong, nonatomic) Class responseClass;

/* An arbitrary string to pass to the serializer when serializing the object property of the request. You can check this string in your object's GRSerializable methods to cater serialization to your needs. */
@property (strong, nonatomic) NSString *serializationContext;

/* The case to which to serialize the parameter keys and given JSON data. For example, if you supply GRSerializationCaseSnakeCase and add a user object with a single property called "userName", when creating a JSON payload, Gravy will convert the property name to "user_name". Default value is GRSerializationCaseSnakeCase. */
@property (nonatomic) GRSerializationCase serializationCase;

/* Adds multipart form data to the request's HTTPBody and adds the other paramaters to the form. */
-(void)addMultipartFormData:(NSData *)data withName:(NSString *)name type:(NSString *)type filename:(NSString *)filename;

///
/// Response handling
///

// A typedef for the GRHTTPResponseHandler
typedef void(^GRHTTPResponseHandler)(GRHTTPResponse *response);

/* A block executed if the request succeeds. Any 2xx response code will trigger this block. Optional. */
@property (strong, nonatomic) GRHTTPResponseHandler successHandler;

/* A block executed if the request fails. Any non-2xx response code will trigger this block. Optional. */
@property (strong, nonatomic) GRHTTPResponseHandler failureHandler;

/* A block executed when the request returns a response, regardless of whether it succeeds. Check the statusCode property or the success property of the GRHTTPResponse to determine the nature of the response. Optional. */
@property (strong, nonatomic) GRHTTPResponseHandler completionHandler;

/* A block executed if the network is unreachable. Supplying a block here will cancel the request operation if unreachable. Optional.
 @discussion If allowsCellularAccess is set to NO, the block will execute if WiFi in unreachable.
 */
@property (strong, nonatomic) void(^unreachableHandler)();

@end

/* GRHTTPResponse is a simple subclass of NSHTTPURLRequest, which encapulates the data in a request and greatly simplifies the response process when loading requests. You can access all properties of NSHTTPURLResponse, most importantly the `statusCode` property, which you can check against the typedef GRHTTPStatusCode. */

@interface GRHTTPResponse : NSHTTPURLResponse

/* A BOOL indicating whether or not the request was successful. This is YES only if the returned status code is 2xx. */
@property (nonatomic) BOOL success;

/* If a responseClass is provided in the request, this data will be serialized to the class. Otherwise, the JSON is serialized as NSDictionary and NSArray objects.  */
@property (strong, nonatomic) id data;

@end

/* GRReachability is the simplest reachability implementation you'll ever see.
 */

@interface GRReachability : NSObject

/* Returns a BOOL indicating whether the network is reachable. */
+(BOOL)isReachable;

/* Returns a BOOL indicating whether the network is reachable via WiFi. */
+(BOOL)isReachableViaWiFi;

/* Returns a BOOL indicating whether the network is reachable via cellular. */
+(BOOL)isReachableViaCellular;

/* Logs the current reachability status, once. */
+(void)logReachability;

/* If set to YES, logs the current reachability status and begins logging on each change. Setting NO will stop the log messages. A message is only logged if in DEBUG mode. */
+(void)setLogsReachability:(BOOL)logsReachability;

/* Typedef for the reachability change handler. */
typedef void(^GRReachabilityChangeHandler)();

/* Registers a block to execute when the reachability status changes. The observer property is used to identify the block. */
+(void)addReachabilityObserver:(id)observer withChangeHandler:(GRReachabilityChangeHandler)changeHandler;

/* Removes the observer and stops executing the block on reachability changes. You should call removeReachabilityObserver in your observer's dealloc, otherwise you'll be causing a memory leak. */
+(void)removeReachabilityObserver:(id)observer;

@end

// GRHTTPRequest's serialization context. To learn more about serialization contexts, see GRSerialization.
extern NSString * const GRSerializationContextGenericHTTPRequest;

// Here are some typedefs and consts for common HTTP methods, status codes, and headers. No more magic strings!
extern NSString * const GRHTTPMethodGET;
extern NSString * const GRHTTPMethodPOST;
extern NSString * const GRHTTPMethodPUT;
extern NSString * const GRHTTPMethodDELETE;
extern NSString * const GRHTTPMethodHEAD;
extern NSString * const GRHTTPMethodPATCH;

// Common status codes
enum GRHTTPStatusCode {
    
    // Unreachable
    GRHTTPStatusUnreachable                 = 0,

    // Informational
    GRHTTPStatusContinue                    = 100,
    GRHTTPStatusSwitchingProtocols          = 101,
    GRHTTPStatusProccessing                 = 102,

    // Success
    GRHTTPStatusOK                          = 200,
    GRHTTPStatusCreated                     = 201,
    GRHTTPStatusAccepted                    = 202,
    GRHTTPStatusNonAuthoritativeInformation = 203,
    GRHTTPStatusNoContent                   = 204,
    GRHTTPStatusResetContent                = 205,
    GRHTTPStatusPartialContent              = 206,
    GRHTTPStatusMultiStatus                 = 207,
    GRHTTPStatusIMUsed                      = 226,

    // Redirection
    GRHTTPStatusMultipleChoices             = 300,
    GRHTTPStatusMovedPermanently            = 301,
    GRHTTPStatusFound                       = 302,
    GRHTTPStatusSeeOther                    = 303,
    GRHTTPStatusNotModified                 = 304,
    GRHTTPStatusUseProxy                    = 305,
    GRHTTPStatusTemporaryRedirect           = 307,

    // Client Error
    GRHTTPStatusBadRequest                  = 400,
    GRHTTPStatusUnauthorized                = 401,
    GRHTTPStatusPaymentRequired             = 402,
    GRHTTPStatusForbidden                   = 403,
    GRHTTPStatusNotFound                    = 404,
    GRHTTPStatusMethodNotAllowed            = 405,
    GRHTTPStatusNotAcceptable               = 406,
    GRHTTPStatusProxyAuthenticationRequired = 407,
    GRHTTPStatusRequestTimeout              = 408,
    GRHTTPStatusConflict                    = 409,
    GRHTTPStatusGone                        = 410,
    GRHTTPStatusLengthRequired              = 411,
    GRHTTPStatusPreconditionFailed          = 412,
    GRHTTPStatusRequestEntityTooLarge       = 413,
    GRHTTPStatusRequestURITooLong           = 414,
    GRHTTPStatusUnsupportedMediaType        = 415,
    GRHTTPStatusRequestedRangeNotSatisfied  = 416,
    GRHTTPStatusExpectationFailed           = 417,
    GRHTTPStatusUnprocessableEntity         = 422,
    GRHTTPStatusLocked                      = 423,
    GRHTTPStatusFailedDependency            = 424,
    GRHTTPStatusUpgradeRequired             = 426,

    // Server Error
    GRHTTPStatusInternalServerError         = 500,
    GRHTTPStatusNotImplemented              = 501,
    GRHTTPStatusBadGateway                  = 502,
    GRHTTPStatusServiceUnavailable          = 503,
    GRHTTPStatusGatewayTimeout              = 504,
    GRHTTPStatusHTTPVersionNotSupported     = 505,
    GRHTTPStatusInsufficientStorage         = 507,
    GRHTTPStatusNotExtended                 = 510
};
typedef NSInteger GRHTTPStatusCode;

// Common HTTPRequestHeaders
extern NSString * const GRHTTPHeaderAccept;
extern NSString * const GRHTTPHeaderAcceptCharset;
extern NSString * const GRHTTPHeaderAcceptEncoding;
extern NSString * const GRHTTPHeaderAcceptLanguage;
extern NSString * const GRHTTPHeaderAcceptDatetime;
extern NSString * const GRHTTPHeaderAuthorization;
extern NSString * const GRHTTPHeaderCacheControl;
extern NSString * const GRHTTPHeaderConnection;
extern NSString * const GRHTTPHeaderCookie;
extern NSString * const GRHTTPHeaderContentLength;
extern NSString * const GRHTTPHeaderContentMD5;
extern NSString * const GRHTTPHeaderContentType;
extern NSString * const GRHTTPHeaderDate;
extern NSString * const GRHTTPHeaderExpect;
extern NSString * const GRHTTPHeaderFrom;
extern NSString * const GRHTTPHeaderHost;
extern NSString * const GRHTTPHeaderIfMatch;
extern NSString * const GRHTTPHeaderIfModifiedSince;
extern NSString * const GRHTTPHeaderIfNoneMatch;
extern NSString * const GRHTTPHeaderIfRange;
extern NSString * const GRHTTPHeaderIfUnmodifiedSince;
extern NSString * const GRHTTPHeaderMaxForwards;
extern NSString * const GRHTTPHeaderPragma;
extern NSString * const GRHTTPHeaderProxyAuthorization;
extern NSString * const GRHTTPHeaderRange;
extern NSString * const GRHTTPHeaderReferer;
extern NSString * const GRHTTPHeaderTE;
extern NSString * const GRHTTPHeaderUpgrade;
extern NSString * const GRHTTPHeaderUserAgent;
extern NSString * const GRHTTPHeaderVia;
extern NSString * const GRHTTPHeaderWarning;

// Common HTTPResponseHeaders
extern NSString * const GRHTTPHeaderAccessControlAllowOrigin;
extern NSString * const GRHTTPHeaderAcceptRanges;
extern NSString * const GRHTTPHeaderAge;
extern NSString * const GRHTTPHeaderAllow;
extern NSString * const GRHTTPHeaderContentEncoding;
extern NSString * const GRHTTPHeaderContentLanguage;
extern NSString * const GRHTTPHeaderContentLocation;
extern NSString * const GRHTTPHeaderContentMD5;
extern NSString * const GRHTTPHeaderContentDisposition;
extern NSString * const GRHTTPHeaderContentRange;
extern NSString * const GRHTTPHeaderETag;
extern NSString * const GRHTTPHeaderExpires;
extern NSString * const GRHTTPHeaderLastModified;
extern NSString * const GRHTTPHeaderLink;
extern NSString * const GRHTTPHeaderProxyAuthenticate;
extern NSString * const GRHTTPHeaderRefresh;
extern NSString * const GRHTTPHeaderRetryAfter;
extern NSString * const GRHTTPHeaderServer;
extern NSString * const GRHTTPHeaderSetCookie;
extern NSString * const GRHTTPHeaderStrictTransportSecurity;
extern NSString * const GRHTTPHeaderTrailer;
extern NSString * const GRHTTPHeaderTransferEncoding;
extern NSString * const GRHTTPHeaderVary;
extern NSString * const GRHTTPHeaderWWWAuthenticate;
