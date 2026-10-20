#import <AppKit/AppKit.h>
#include <stdio.h>
#include <string.h>
#include "image_resources.h"

int main(int argc,char **argv) {
 @autoreleasepool {
  if(argc!=2)return 2;
  NSBundle *application=[NSBundle bundleWithPath:[NSString stringWithUTF8String:argv[1]]];
  if(!application || !nativeLoadSupplementalImages(application))return 3;
  NSURL *url=[application URLForResource:@"ResourceManifest" withExtension:@"json"];
  NSDictionary *manifest=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:url] options:0 error:NULL];
  if(!manifest)return 4;
  for(NSString *name in manifest[@"retained_asset_names"]){
   if(![application imageForResource:name]){fprintf(stderr,"Main catalog image did not load: %s\n",name.UTF8String);return 5;}
  }
  for(NSDictionary *extra in manifest[@"supplemental_catalogs"]){
   for(NSString *name in extra[@"retained_asset_names"]){
    NSImage *image=[NSImage imageNamed:name];
    if(!image || !image.representations.count){fprintf(stderr,"Supplemental image is unavailable: %s\n",name.UTF8String);return 6;}
   }
  }
  // These exact names are requested by the affected native controls.
  for(NSString *name in @[@"command-symbol-16",@"tack-16",@"tack-disabled-16",@"multiply-16"]){
   NSImage *image=[NSImage imageNamed:name];
   if(!image)return 7;
   NSBitmapImageRep *bitmap=[[NSBitmapImageRep alloc]initWithBitmapDataPlanes:NULL pixelsWide:32 pixelsHigh:32 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
   if(!bitmap)return 8;
   memset(bitmap.bitmapData,0,bitmap.bytesPerRow*bitmap.pixelsHigh);
   [NSGraphicsContext saveGraphicsState];
   NSGraphicsContext.currentContext=[NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
   [image drawInRect:NSMakeRect(0,0,32,32)];
   [NSGraphicsContext restoreGraphicsState];
   BOOL visible=NO;
   for(NSInteger y=0;y<32 && !visible;y++)for(NSInteger x=0;x<32;x++)if([bitmap colorAtX:x y:y].alphaComponent>0.001){visible=YES;break;}
   if(!visible){fprintf(stderr,"Required control glyph rendered empty: %s\n",name.UTF8String);return 9;}
  }
  return 0;
 }
}
