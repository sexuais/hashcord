#import "HashcordRuntime.h"
#import "HashcordJSI.h"
#import "LoaderConfig.h"
#import "Logger.h"
#import "Utils.h"

using namespace facebook;

static NSData *downloadHashcord(NSURL *directory) {
    LoaderConfig *config = [[LoaderConfig alloc] init];
    [config loadConfig];

    NSURL *url = nil;
    if (config.customLoadUrlEnabled && config.customLoadUrl) {
        url = config.customLoadUrl;
    } else {
        url = [NSURL URLWithString:
            @"https://raw.githubusercontent.com/sexuais/hashcord/dist/hashcord.min.js"];
    }

    if (!url) return nil;

    NSURL *cached = [directory URLByAppendingPathComponent:@"bundle.js"];
    NSData *old = [NSData dataWithContentsOfURL:cached];

    NSMutableURLRequest *request =
        [NSMutableURLRequest requestWithURL:url
                                cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                            timeoutInterval:5.0];

    NSString *etag =
        [NSString stringWithContentsOfURL:
            [directory URLByAppendingPathComponent:@"etag.txt"]
                                  encoding:NSUTF8StringEncoding
                                     error:nil];

    if (etag && old) {
        [request setValue:etag forHTTPHeaderField:@"If-None-Match"];
    }

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __block NSData *result = nil;
    __block NSString *newEtag = nil;

    NSURLSession *session =
        [NSURLSession sessionWithConfiguration:
            [NSURLSessionConfiguration defaultSessionConfiguration]];

    [[session dataTaskWithRequest:request
                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;

            if (http.statusCode == 200 && data.length) {
                result = data;
                newEtag = [http valueForHTTPHeaderField:@"Etag"];
            } else if (http.statusCode == 304 && old.length) {
                result = old;
            }
        }

        if (error) {
            BunnyLog(@"[HashcordRuntime] download error: %@", error.localizedDescription);
        }

        dispatch_semaphore_signal(sem);
    }] resume];

    dispatch_semaphore_wait(
        sem,
        dispatch_time(DISPATCH_TIME_NOW, 6 * NSEC_PER_SEC));

    if (result) {
        [result writeToURL:cached atomically:YES];
        if (newEtag) {
            [newEtag writeToURL:
                [directory URLByAppendingPathComponent:@"etag.txt"]
                      atomically:YES
                        encoding:NSUTF8StringEncoding
                           error:nil];
        }
    }

    return result ?: old;
}

void HashcordLoadIntoRuntime(jsi::Runtime &runtime,
                          NSString *resourcesBundlePath,
                          NSURL *pyoncordDirectory) {
    static BOOL loaded = NO;
    if (loaded) return;
    loaded = YES;

    NSBundle *resources =
        [NSBundle bundleWithPath:resourcesBundlePath];

    if (!resources) {
        BunnyLog(@"[HashcordRuntime] HashcordResources.bundle not found at %@",
                 resourcesBundlePath);
        loaded = NO;
        return;
    }

    NSURL *payload =
        [resources URLForResource:@"payload-base"
                    withExtension:@"js"];

    if (payload) {
        NSData *payloadData = [NSData dataWithContentsOfURL:payload];
        [HashcordJSI evaluate:payloadData
                       tag:@"hashcord:loader"
                   runtime:runtime];
    } else {
        BunnyLog(@"[HashcordRuntime] payload-base.js missing");
    }

    NSData *bundle = downloadHashcord(pyoncordDirectory);

    if (!bundle.length) {
        BunnyLog(@"[HashcordRuntime] No Hashcord bundle available");
        return;
    }

    [HashcordJSI evaluate:bundle
                   tag:@"hashcord:bundle"
               runtime:runtime];

    NSURL *preloads =
        [pyoncordDirectory URLByAppendingPathComponent:@"preloads"];

    NSArray *files =
        [[NSFileManager defaultManager]
            contentsOfDirectoryAtURL:preloads
            includingPropertiesForKeys:nil
                               options:0
                                 error:nil];

    for (NSURL *file in files) {
        if ([[file.pathExtension lowercaseString] isEqualToString:@"js"]) {
            NSData *data = [NSData dataWithContentsOfURL:file];
            if (data.length) {
                [HashcordJSI evaluate:data
                               tag:[@"hashcord:preload:" stringByAppendingString:file.lastPathComponent]
                           runtime:runtime];
            }
        }
    }

    BunnyLog(@"[HashcordRuntime] Hashcord bundle executed in new-architecture runtime");
}
