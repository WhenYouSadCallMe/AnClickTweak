#import "AnClickNetworkService.h"

@interface AnClickNetworkService ()
@property (nonatomic, strong) NSMutableSet<NSURLSessionDataTask *> *activeTasks;
- (void)trackTask:(NSURLSessionDataTask *)task;
- (void)untrackTask:(NSURLSessionDataTask *)task;
@end

static NSString * const AnClickDefaultContentType = @"application/json; charset=utf-8";
static NSString * const AnClickDefaultUserAgent = @"Mozilla/5.0 (iPhone; CPU iPhone OS 16_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.1 Mobile/15E148 Safari/604.1";

@implementation AnClickNetworkService

- (instancetype)init {
    self = [super init];
    if (self) {
        _activeTasks = [NSMutableSet set];
    }
    return self;
}

- (NSString *)trimmedText:(id)value {
    if (![value isKindOfClass:NSString.class]) {
        if ([value respondsToSelector:@selector(stringValue)]) {
            value = [value stringValue];
        } else if (value) {
            value = [value description];
        }
    }
    NSString *text = [value isKindOfClass:NSString.class] ? value : @"";
    return [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

- (NSString *)normalizedURLString:(NSString *)urlText {
    NSString *trimmed = [self trimmedText:urlText];
    if (trimmed.length == 0) {
        return nil;
    }
    if ([trimmed rangeOfString:@"://"].location == NSNotFound) {
        trimmed = [@"https://" stringByAppendingString:trimmed];
    }
    NSURLComponents *components = [NSURLComponents componentsWithString:trimmed];
    if (!components) {
        NSString *encoded = [trimmed stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLFragmentAllowedCharacterSet];
        components = encoded.length > 0 ? [NSURLComponents componentsWithString:encoded] : nil;
    }
    if (!components || components.scheme.length == 0 || components.host.length == 0) {
        return nil;
    }
    NSString *path = components.path ?: @"";
    if (path.length > 0) {
        NSString *encodedPath = [path stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLPathAllowedCharacterSet];
        if (encodedPath.length > 0) {
            components.percentEncodedPath = encodedPath;
        }
    }
    NSString *query = components.query ?: @"";
    if (query.length > 0) {
        NSString *encodedQuery = [query stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];
        if (encodedQuery.length > 0) {
            components.percentEncodedQuery = encodedQuery;
        }
    }
    NSString *fragment = components.fragment ?: @"";
    if (fragment.length > 0) {
        NSString *encodedFragment = [fragment stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLFragmentAllowedCharacterSet];
        if (encodedFragment.length > 0) {
            components.percentEncodedFragment = encodedFragment;
        }
    }
    return components.URL.absoluteString;
}

- (NSString *)stringFromData:(NSData *)data {
    if (data.length == 0) {
        return @"";
    }

    NSString *body = nil;
    [NSString stringEncodingForData:data encodingOptions:nil convertedString:&body usedLossyConversion:nil];
    if (body.length > 0) {
        return body;
    }
    body = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return body ?: @"";
}

- (BOOL)hasJudgementConditionWithTrueText:(NSString *)trueText falseText:(NSString *)falseText {
    return [self trimmedText:trueText].length > 0 || [self trimmedText:falseText].length > 0;
}

- (BOOL)body:(NSString *)body matchesRegexPattern:(NSString *)pattern {
    NSString *regexPattern = [self trimmedText:pattern];
    if (regexPattern.length == 0) {
        return NO;
    }

    NSString *response = body ?: @"";
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:regexPattern
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:&error];
    if (!regex || error) {
        return NO;
    }
    NSRange range = NSMakeRange(0, response.length);
    return [regex firstMatchInString:response options:0 range:range] != nil;
}

- (NSString *)regexPatternFromRuleText:(NSString *)ruleText {
    NSString *rule = [self trimmedText:ruleText];
    NSString *lowercaseRule = rule.lowercaseString;
    NSArray<NSString *> *prefixes = @[@"re:", @"regex:", @"正则:"];
    for (NSString *prefix in prefixes) {
        if ([lowercaseRule hasPrefix:prefix]) {
            return [self trimmedText:[rule substringFromIndex:prefix.length]];
        }
    }
    return nil;
}

- (BOOL)body:(NSString *)body matchesRuleText:(NSString *)ruleText {
    NSString *rule = [self trimmedText:ruleText];
    if (rule.length == 0) {
        return NO;
    }

    NSString *regexPattern = [self regexPatternFromRuleText:rule];
    if (regexPattern.length > 0) {
        return [self body:body matchesRegexPattern:regexPattern];
    }

    NSString *response = body ?: @"";
    return [response rangeOfString:rule options:NSCaseInsensitiveSearch].location != NSNotFound;
}

- (NSNumber *)statusBooleanFromBody:(NSString *)body {
    NSData *data = [(body ?: @"") dataUsingEncoding:NSUTF8StringEncoding];
    if (data.length == 0) {
        return nil;
    }

    NSError *error = nil;
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error || ![object isKindOfClass:NSDictionary.class]) {
        return nil;
    }

    id statusValue = ((NSDictionary *)object)[@"status"];
    if ([statusValue isKindOfClass:NSNumber.class]) {
        return @([statusValue boolValue]);
    }
    if ([statusValue isKindOfClass:NSString.class]) {
        NSString *statusText = [self trimmedText:statusValue].lowercaseString;
        if ([statusText isEqualToString:@"true"]) {
            return @YES;
        }
        if ([statusText isEqualToString:@"false"]) {
            return @NO;
        }
    }
    return nil;
}

- (BOOL)bodyMatchesDefaultTrue:(NSString *)body {
    NSNumber *jsonStatus = [self statusBooleanFromBody:body];
    if (jsonStatus) {
        return jsonStatus.boolValue;
    }

    NSString *response = body ?: @"";
    if ([self body:response matchesRegexPattern:@"\"status\"\\s*:\\s*true"]) {
        return YES;
    }
    NSString *trimmed = [response stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].lowercaseString;
    return [trimmed isEqualToString:@"true"];
}

- (BOOL)bodyMatchesDefaultFalse:(NSString *)body {
    NSNumber *jsonStatus = [self statusBooleanFromBody:body];
    if (jsonStatus) {
        return !jsonStatus.boolValue;
    }

    NSString *response = body ?: @"";
    if ([self body:response matchesRegexPattern:@"\"status\"\\s*:\\s*false"]) {
        return YES;
    }
    NSString *trimmed = [response stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].lowercaseString;
    return [trimmed isEqualToString:@"false"];
}

- (BOOL)body:(NSString *)body
    matchesTrueText:(NSString *)trueText
    falseText:(NSString *)falseText
    defaultExpectedTrue:(BOOL)defaultExpectedTrue {
    NSString *trueRule = [self trimmedText:trueText];
    NSString *falseRule = [self trimmedText:falseText];
    if (falseRule.length > 0 && [self body:body matchesRuleText:falseRule]) {
        return NO;
    }
    if (trueRule.length > 0) {
        return [self body:body matchesRuleText:trueRule];
    }
    if (defaultExpectedTrue) {
        if ([self bodyMatchesDefaultFalse:body]) {
            return NO;
        }
        return [self bodyMatchesDefaultTrue:body];
    }
    return YES;
}

- (BOOL)body:(NSString *)body matchesBlockText:(NSString *)falseText defaultExpectedTrue:(BOOL)defaultExpectedTrue {
    NSString *falseRule = [self trimmedText:falseText];
    if (falseRule.length > 0) {
        return [self body:body matchesRuleText:falseRule];
    }
    if (defaultExpectedTrue) {
        return [self bodyMatchesDefaultFalse:body];
    }
    return NO;
}

- (NSString *)statusTextWithMatched:(BOOL)matched
                    requestSucceeded:(BOOL)requestSucceeded
                          statusCode:(NSInteger)statusCode
                               error:(NSError *)error {
    if (matched) {
        return @"命中运行";
    }
    if (error) {
        return @"网络请求失败";
    }
    if (!requestSucceeded && statusCode > 0) {
        return [NSString stringWithFormat:@"网络状态%ld", (long)statusCode];
    }
    return @"未命中运行";
}

- (void)performRequestWithURLString:(NSString *)urlString
                              method:(NSString *)method
                             headers:(NSDictionary *)headers
                            postBody:(NSString *)postBody
                            trueText:(NSString *)trueText
                           falseText:(NSString *)falseText
                 defaultExpectedTrue:(BOOL)defaultExpectedTrue
                             timeout:(NSTimeInterval)timeout
                          completion:(AnClickNetworkRequestCompletion)completion {
    NSString *normalizedURLString = [self normalizedURLString:urlString];
    NSURL *url = normalizedURLString.length > 0 ? [NSURL URLWithString:normalizedURLString] : nil;
    if (!url) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain
                                                 code:NSURLErrorBadURL
                                             userInfo:@{NSLocalizedDescriptionKey: @"链接无效"}];
            completion(NO, NO, @"", 0, error);
        }
        return;
    }

    NSTimeInterval requestTimeout = MIN(60.0, MAX(1.0, timeout));
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:requestTimeout];
    NSString *normalizedMethod = [self trimmedText:method].uppercaseString;
    BOOL usesPost = [normalizedMethod isEqualToString:@"POST"];
    request.HTTPMethod = usesPost ? @"POST" : @"GET";
    [request setValue:AnClickDefaultContentType forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json, text/plain, */*" forHTTPHeaderField:@"Accept"];
    [request setValue:AnClickDefaultUserAgent forHTTPHeaderField:@"User-Agent"];
    (void)headers;
    if (usesPost) {
        NSString *bodyText = postBody ?: @"";
        request.HTTPBody = [bodyText dataUsingEncoding:NSUTF8StringEncoding];
    }

    __block __weak NSURLSessionDataTask *weakTask = nil;
    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSURLSessionDataTask *finishedTask = weakTask;
        NSInteger statusCode = 0;
        if ([response isKindOfClass:NSHTTPURLResponse.class]) {
            statusCode = ((NSHTTPURLResponse *)response).statusCode;
        }
        NSString *body = [weakSelf stringFromData:data];
        BOOL requestSucceeded = !error && (statusCode == 0 || (statusCode >= 200 && statusCode < 400));
        BOOL matched = requestSucceeded && [weakSelf body:body
                                          matchesTrueText:trueText
                                                falseText:falseText
                                      defaultExpectedTrue:defaultExpectedTrue];
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf untrackTask:finishedTask];
            if (error.code == NSURLErrorCancelled) {
                return;
            }
            if (completion) {
                completion(matched, requestSucceeded, body, statusCode, error);
            }
        });
    }];
    weakTask = task;
    [self trackTask:task];
    [task resume];
}

- (void)trackTask:(NSURLSessionDataTask *)task {
    if (!task) {
        return;
    }
    [_activeTasks addObject:task];
}

- (void)untrackTask:(NSURLSessionDataTask *)task {
    if (!task) {
        return;
    }
    [_activeTasks removeObject:task];
}

- (void)cancelActiveTasks {
    NSSet<NSURLSessionDataTask *> *tasks = [_activeTasks copy];
    [_activeTasks removeAllObjects];
    for (NSURLSessionDataTask *task in tasks) {
        [task cancel];
    }
}

@end
