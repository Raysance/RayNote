#import <AppKit/AppKit.h>
#include <stdio.h>

// Use the original images under their original names, including native Core lookups.
static BOOL nativeLoadSupplementalImages(NSBundle *application) {
 NSURL *url=[application URLForResource:@"NotesGlyphs" withExtension:@"bundle"];
 NSBundle *bundle=url ? [NSBundle bundleWithURL:url] : nil;
 NSArray<NSString *> *names=bundle.infoDictionary[@"RayNoteIconNames"];
 if(!names.count){fprintf(stderr,"Required NotesGlyphs image catalog is missing\n");return NO;}
 for(NSString *name in names){
  NSImage *image=[bundle imageForResource:name];
  if(!image){fprintf(stderr,"Required Notes glyph could not be loaded: %s\n",name.UTF8String);return NO;}
  [image setName:name];
  if(![NSImage imageNamed:name]){fprintf(stderr,"Required Notes glyph could not be registered: %s\n",name.UTF8String);return NO;}
 }
 return YES;
}
