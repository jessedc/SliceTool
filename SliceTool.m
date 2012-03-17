//
//  SliceTool
//
//  Created by Chris Miles on 01/08/11.
//  Copyright 2011 Chris Miles. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//  
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//  
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//


#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <stdarg.h>
#import <getopt.h>

#import "NSImage+MGCropExtensions.h"
#import "util.h"

static const char *version = "1.1";

#define kTileSize 256.0f

extern BOOL enable_verbose_output;
extern BOOL enable_debug_output;

void slice_image(NSImage *image, NSColorSpace *colorSpace, NSString *filename, NSString *sub_path, NSString *sliceName)
{
  @autoreleasepool
  {
    NSUInteger row = 0, col = 0;
    for (CGFloat y = 0.0f; y < image.size.height; y += kTileSize)
    {
      col = 0;
      for (CGFloat x = 0.0f; x < image.size.width; x += kTileSize)
      { 
        CGFloat width = fmin(kTileSize, image.size.width - x);
        CGFloat height = fmin(kTileSize, image.size.height - y);
        
        NSRect cropRect = NSMakeRect(x, fmax(0.0f, image.size.height - (y + kTileSize)), width, height);
        NSImage *cropped = [image imageCroppedInRect:cropRect];
        
        NSString *outputName = [NSString stringWithFormat:@"%@_%@_%02d_%02d.png", filename, sliceName, row, col];
        NSString *outputFile = [sub_path stringByAppendingPathComponent:outputName];
        NSData *tiffData = [cropped TIFFRepresentation];
        
        NSBitmapImageRep *bitmapImageRep = [[NSBitmapImageRep imageRepWithData:tiffData]
                                            bitmapImageRepByConvertingToColorSpace:colorSpace renderingIntent:NSColorRenderingIntentDefault];

        [[bitmapImageRep representationUsingType:NSPNGFileType properties:nil] writeToFile:outputFile atomically:YES];
        col++;
      }
      row++;
    }
    
  }
}

int slice_files_at_path(NSString *sub_path)
{
  @autoreleasepool
  {
    NSError *error = nil;
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *dirlist = [fileManager contentsOfDirectoryAtPath:sub_path error:&error];

    if (nil == dirlist)
    {
      error_output(@"contentsOfDirectoryAtPath:\"%@\" error: %@", sub_path, error);
    }
    
    for (NSString *filename in dirlist)
    {
      BOOL isDirectory;
      
      NSString *filePath = [sub_path stringByAppendingPathComponent:filename];
      [fileManager fileExistsAtPath:filePath isDirectory:&isDirectory];

      if ([filename hasPrefix:@"."] || isDirectory)
      {
        continue;
      }
      
      output(@"  * %@", filename);
      
      NSImage *originalImage = [[NSImage alloc] initWithContentsOfFile:filePath];
      
      NSBitmapImageRep *bitmapImageRep = [NSBitmapImageRep imageRepWithData:[originalImage TIFFRepresentation]];
      NSColorSpace *origColorSpace = [bitmapImageRep colorSpace];
      //NSData *colorProfileData = [origColorSpace ICCProfileData];

      NSString *slicedName = [filename stringByDeletingPathExtension];
      NSString *slicedPath = [sub_path stringByAppendingPathComponent:slicedName];

      if (![fileManager createDirectoryAtPath:slicedPath withIntermediateDirectories:YES attributes:nil error:&error])
      {
        error_output(@"createDirectoryAtPath:\"%@\" error: %@", slicedPath, error);
      }

      int sizes = 3;
      
      for (int i = sizes; i >= 0; i--)
      {
        float factor = powf(2, (float)i);
        float inverse_factor = powf(2,(sizes - (float)i));
        NSSize newSize = NSMakeSize(originalImage.size.width / inverse_factor, originalImage.size.height / inverse_factor);

        NSImage *image = [originalImage imageScaledToFitSize:newSize];
        slice_image(image, origColorSpace, slicedName, slicedPath, [NSString stringWithFormat:@"%0.0fx", factor]);
      }
      [originalImage release];
    }

  }

  return 0;
}

int start_slicing(NSString *path)
{
  NSError *error = nil;
  NSFileManager *fileManager = [NSFileManager defaultManager];
  
  NSArray *dirlist = [fileManager contentsOfDirectoryAtPath:path error:&error];
  if (nil == dirlist)
  {
    error_output(@"contentsOfDirectoryAtPath:\"%@\" error: %@", path, error);
  }
  
  for (NSString *subdir in dirlist)
  {
    if ([subdir hasPrefix:@"."])
    {
      continue;
    }

    NSString *sub_path = [path stringByAppendingPathComponent:subdir];
    slice_files_at_path(sub_path);
    
//    NSString *productID = [subdir substringFromIndex:[subdir length] - 5];
//    NSString *newDirName = [NSString stringWithFormat:@"product_%@_large", productID];
//    NSString *newPath = [path stringByAppendingPathComponent:newDirName];
//    if (![fileManager moveItemAtPath:sub_path toPath:newPath error:&error])
//    {
//      error_output(@"moveItemAtPath: \"%@\" toPath: \"%@\" error: %@", sub_path, newPath, error);
//    }

    output(@"Processed %@", sub_path);
  }

  return 0;
}

void usage() {
    error_output(@"SliceTool [-V|--version] [-v|--verbose] [-D|--debug] path");
}

int main (int argc, const char * argv[])
{  
  int ret = 0;

  @autoreleasepool
  {
    enable_verbose_output = YES;
    enable_debug_output = NO;

    BOOL optShowHelp = NO;
    BOOL optShowVersion = NO;

    static struct option optList[] = {
      {"help",		no_argument, NULL, 'h'},
      {"quiet",		no_argument, NULL, 'q'},
      {"debug",		no_argument, NULL, 'D'},
      {"version",		no_argument, NULL, 'V'},
      {NULL,			0, NULL, 0},
    };

    int c;
    int ix;

    while (1)
    {
      c = getopt_long(argc, (char * const *)argv, "hoqVD::", optList, &ix);
      if (c == EOF)
      {
        break;
      }
      switch (c)
      {
        case 'h':
          optShowHelp = YES;
          break;
        case 'q':
          enable_verbose_output = NO;
          break;
        case 'D':
          enable_debug_output = YES;
          break;
        case 'V':
          optShowVersion = YES;
          break;
        default:
          break;
      }
    }
    
    if (optShowHelp)
    {
      usage();
      ret = 1;
    }
    else if (optShowVersion)
    {
      error_output(@"SliceTool version %s.", version);
#ifdef DEBUG
      error_output(@"DEBUG enabled");
#endif
    }
    else
    {
      argc -= optind;
      argv += optind;

      if (argc < 1)
      {
        usage();
        ret = 1;
      }
      else
      {
        NSString *path = [NSString stringWithCString:argv[0] encoding:NSUTF8StringEncoding];

        ret = start_slicing(path);
      }
    }
  }

  return ret;
}
