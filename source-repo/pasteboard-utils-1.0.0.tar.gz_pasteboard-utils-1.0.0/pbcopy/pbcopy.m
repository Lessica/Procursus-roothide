//
//  pbcopy.m
//  pasteboard-utils
//
//  Created by quiprr on 12/25/20.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

int main (int argc, char* argv[]) {
    @autoreleasepool {
        if (argc == 2) {
            if (strcmp(argv[1], "--help")==0 || strcmp(argv[1], "-h")==0) {
                printf("Usage: pbcopy {--help|-h, --version|-v}\n");
                return 0;
            } else if (strcmp(argv[1], "--version")==0 || strcmp(argv[1], "-v")==0) {
                printf("pbcopy version 1.0.0 Copyright (c) 2020-present quiprr\n");
                printf("Built with Apple clang %s\n", __clang_version__);
                return 0;
            } else {
                printf("Unrecognized argument. Usage: pbcopy {--help|-h, --version|-v}\n");
                return 1;
            }
        } else if (argc > 2) {
            printf("Too many arguments given. Expected {--help|-h, --version|-v}.\n");
            return 1;
        }

        NSData *data = [[NSFileHandle fileHandleWithStandardInput] availableData];
        NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = dataString;

        //hack: sync the pasteboard
        pasteboard.string;

        NSLog(@"Data copied to clipboard.");
    }
}