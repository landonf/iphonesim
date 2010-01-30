/*
 * Author: Landon Fuller <landonf@plausiblelabs.com>
 * Copyright (c) 2008 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

#import "iPhoneSimExample.h"
#import "nsprintf.h"
#import <getopt.h>

/**
 * A simple usage example for the iPhoneSimulatorRemoteClient
 * framework.
 */
@implementation iPhoneSimExample

/**
 * Print usage.
 */
- (void) printUsage {
    fprintf(stderr, "Usage: iphonesim <options> <command> ...\n");
    fprintf(stderr, "Commands:\n");
    fprintf(stderr, "  showsdks\n");
    fprintf(stderr, "  launch [options] <application path>\n");
    fprintf(stderr, "    Options:\n");
    fprintf(stderr, "      -d/--device-family [family]\tSupported device families: iPhone iPad\n");
    fprintf(stderr, "      -s/--sdk-version [version]\tThe SDK version (eg, 3.0, 3.1, 3.2)\n");
}


/**
 * List available SDK roots.
 */
- (int) showSDKs {
    NSArray *roots = [DTiPhoneSimulatorSystemRoot knownRoots];

    nsprintf(@"Simulator SDK Roots:\n");
    for (DTiPhoneSimulatorSystemRoot *root in roots) {
        nsfprintf(stderr, @"'%@' (%@)\n\t%@\n", [root sdkDisplayName], [root sdkVersion], [root sdkRootPath]);
    }

    return EXIT_SUCCESS;
}

- (void) session: (DTiPhoneSimulatorSession *) session didEndWithError: (NSError *) error {
    nsprintf(@"Seesion did end with error %@\n", error);
    
    if (error != nil)
        exit(EXIT_FAILURE);

    exit(EXIT_SUCCESS);
}


- (void) session: (DTiPhoneSimulatorSession *) session didStart: (BOOL) started withError: (NSError *) error {
    if (started) {
        nsprintf(@"Session started\n");
    } else {
        nsprintf(@"Session could not be started: %@", error);
        exit(EXIT_FAILURE);
    }
}


/**
 * Launch the given Simulator binary.
 */
- (int) launchApp: (NSString *) path sdkVersion: (NSString *) version simulatedDeviceFamily: (NSNumber *) simulatedDeviceFamily {
    DTiPhoneSimulatorApplicationSpecifier *appSpec;
    DTiPhoneSimulatorSystemRoot *sdkRoot;
    DTiPhoneSimulatorSessionConfig *config;
    DTiPhoneSimulatorSession *session;
    NSError *error;

    /* Create the app specifier */
    appSpec = [DTiPhoneSimulatorApplicationSpecifier specifierWithApplicationPath: path];
    if (appSpec == nil) {
        nsprintf(@"Could not load application specification for %s", path);
        return EXIT_FAILURE;
    }
    nsprintf(@"App Spec: %@\n", appSpec);

    /* Load the SDK root */
    if (version != nil) {
        sdkRoot = [DTiPhoneSimulatorSystemRoot rootWithSDKVersion: version];
        if (sdkRoot == nil) {
            nsprintf(@"Can't find SDK for version %@", version);
            return EXIT_FAILURE;
        }
    } else {
        sdkRoot = [DTiPhoneSimulatorSystemRoot defaultRoot];
    }

    nsprintf(@"SDK Root: %@\n", sdkRoot);

    /* Set up the session configuration */
    config = [[[DTiPhoneSimulatorSessionConfig alloc] init] autorelease];
    [config setApplicationToSimulateOnStart: appSpec];
    [config setSimulatedSystemRoot: sdkRoot];
    [config setSimulatedApplicationShouldWaitForDebugger: NO];

    [config setSimulatedApplicationLaunchArgs: [NSArray array]];
    [config setSimulatedApplicationLaunchEnvironment: [NSDictionary dictionary]];
    if (simulatedDeviceFamily != nil && [config respondsToSelector: @selector(setSimulatedDeviceFamily:)])
        [config setSimulatedDeviceFamily: simulatedDeviceFamily];

    [config setLocalizedClientName: @"iPhoneSimExample"];

    /* Start the session */
    session = [[[DTiPhoneSimulatorSession alloc] init] autorelease];
    [session setDelegate: self];
    [session setSimulatedApplicationPID: [NSNumber numberWithInt: 35]];

    if (![session requestStartWithConfig: config timeout: 10 error: &error]) {
        nsprintf(@"Could not start simulator session: %@", error);
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}


/**
 * Execute 'main'
 */
- (void) runWithArgc: (int) argc argv: (char **) argv {
    /* Read the command */
    if (argc < 2) {
        [self printUsage];
        exit(EXIT_FAILURE);
    }

    if (strcmp(argv[1], "showsdks") == 0) {
        exit([self showSDKs]);
    }
    else if (strcmp(argv[1], "launch") == 0) {
        /* Requires at least one additional argument */
        if (argc < 3) {
            fprintf(stderr, "Missing application path argument\n");
            [self printUsage];
            exit(EXIT_FAILURE);
        }

        /* Parse any arguments */
        NSString *sdkVersion = nil;
        NSNumber *simulatedDeviceFamily = nil;
        int ch;
        argc -= 1;
        argv += 1;

        static struct option longopts[] = {
             { "device-family", required_argument,     NULL,    'd' },
             { "sdk-version",   required_argument,     NULL,    's'  },
             { NULL,            0,                     NULL,     0  }
        };

        while ((ch = getopt_long(argc, argv, "s:d:", longopts, NULL)) != -1) {
            switch (ch) {
                case 's':
                    sdkVersion = [NSString stringWithUTF8String: optarg];
                    break;
                case 'd':
                    if (strcmp(optarg, "iPad") == 0) {
                        simulatedDeviceFamily = [NSNumber numberWithInt: 2];
                    } else if (strcmp(optarg, "iPhone") == 0) {
                        simulatedDeviceFamily = [NSNumber numberWithInt: 1];
                    } else {
                        fprintf(stderr, "Unknown device type: %s\n", optarg);
                        [self printUsage];
                        exit(EXIT_FAILURE);
                    }
                    break;
                default:
                    fprintf(stderr, "Unknown option %s optarg\n", optarg);
                    [self printUsage];
                    exit(EXIT_FAILURE);
            }
        }
        argc -= optind;
        argv += optind;

        /* Don't exit, adds to runloop */
        [self launchApp: [NSString stringWithUTF8String: argv[0]] sdkVersion: sdkVersion simulatedDeviceFamily: simulatedDeviceFamily];
    } else {
        fprintf(stderr, "Unknown command\n");
        [self printUsage];
        exit(EXIT_FAILURE);
    }
}

@end
