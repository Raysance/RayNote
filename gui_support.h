#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
static NSWindow *nativeNotesWindow;
static id nativeSettingsMenuTarget;
static void (*nativeStatusRefresh)(void);
static IMP nativeBaseSendEvent;
static void nativeSendEvent(id self,SEL cmd,NSEvent *event) {
 ((void(*)(id,SEL,id))nativeBaseSendEvent)(self,cmd,event);
 if(nativeStatusRefresh&&(event.type==NSEventTypeLeftMouseUp||event.type==NSEventTypeKeyUp))nativeStatusRefresh();
}
static Class nativeCreateNotesApplicationClass(Class original) {
 Class c=objc_allocateClassPair(original,"ExtractedNotesApplication",0);
 nativeBaseSendEvent=method_getImplementation(class_getInstanceMethod(NSApplication.class,@selector(sendEvent:)));
 class_addMethod(c,@selector(sendEvent:),(IMP)nativeSendEvent,"v@:@");
 for(NSString *selector in @[@"activateIgnoringOtherApps:"]){
  Method m=class_getInstanceMethod(NSApplication.class,NSSelectorFromString(selector));
  class_addMethod(c,NSSelectorFromString(selector),method_getImplementation(m),method_getTypeEncoding(m));
 }
 objc_registerClassPair(c);return c;
}
static void nativeIgnoreNotification(id self,SEL cmd,id notification) {}
static void nativeShowNotes(void) {
 // Keep the floating note visible when the user switches desktop Spaces.
 NSWindowCollectionBehavior behavior=nativeNotesWindow.collectionBehavior;
 behavior&=~NSWindowCollectionBehaviorMoveToActiveSpace;
 behavior|=NSWindowCollectionBehaviorCanJoinAllSpaces;
 nativeNotesWindow.collectionBehavior=behavior;
 printf("NATIVE NOTES SPACES collectionBehavior=%lu\n",(unsigned long)nativeNotesWindow.collectionBehavior);
 [nativeNotesWindow makeKeyAndOrderFront:nil];
 [NSApp activateIgnoringOtherApps:YES];
}
static void nativeDidLaunch(id self,SEL cmd,id notification) {
 printf("NATIVE NOTES ONLY DID LAUNCH\n");
 [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
 dispatch_async(dispatch_get_main_queue(),^{nativeShowNotes();printf("NATIVE NOTES WINDOW SHOWN\n");});
}
static BOOL nativeReopen(id self,SEL cmd,id app,BOOL visible) {nativeShowNotes();return YES;}
static NSApplicationTerminateReply nativeTerminate(id self,SEL cmd,id app) {[nativeNotesWindow close];return NSTerminateNow;}
static Class nativeCreateNotesDelegateClass(Class original) {
 Class c=objc_getClass("ExtractedNotesOnlyDelegate");if(c)return c;
 c=objc_allocateClassPair(original,"ExtractedNotesOnlyDelegate",0);
 if(!c){fprintf(stderr,"Cannot subclass original app delegate\n");_exit(72);}
 for(NSString *selector in @[@"applicationWillFinishLaunching:",@"applicationWillBecomeActive:",@"applicationWillResignActive:",@"applicationWillTerminate:"]){class_addMethod(c,NSSelectorFromString(selector),(IMP)nativeIgnoreNotification,"v@:@");}
 class_addMethod(c,@selector(applicationDidFinishLaunching:),(IMP)nativeDidLaunch,"v@:@");
 class_addMethod(c,@selector(applicationShouldHandleReopen:hasVisibleWindows:),(IMP)nativeReopen,"B@:@B");
 class_addMethod(c,@selector(applicationShouldTerminate:),(IMP)nativeTerminate,"Q@:@");
 objc_registerClassPair(c);return c;
}
static void nativeCreateStandardMenu(void) {
 NSMenu *menu=[NSMenu new];
 NSMenuItem *app=[NSMenuItem new];app.submenu=[NSMenu new];[menu addItem:app];
 NSMenuItem *settings=[app.submenu addItemWithTitle:@"RayNote Settings…" action:sel_registerName("showIndependentNotesSettings:") keyEquivalent:@","];settings.target=nativeSettingsMenuTarget;
 [app.submenu addItem:NSMenuItem.separatorItem];
 [app.submenu addItemWithTitle:@"Quit RayNote" action:@selector(terminate:) keyEquivalent:@"q"];
 NSMenuItem *edit=[NSMenuItem new];edit.title=@"Edit";edit.submenu=[[NSMenu alloc]initWithTitle:@"Edit"];[menu addItem:edit];
 for(NSArray *entry in @[@[@"Undo",@"undo:",@"z"],@[@"Cut",@"cut:",@"x"],@[@"Copy",@"copy:",@"c"],@[@"Paste",@"paste:",@"v"],@[@"Select All",@"selectAll:",@"a"]]){
  [edit.submenu addItemWithTitle:entry[0] action:NSSelectorFromString(entry[1]) keyEquivalent:entry[2]];
 }
 NSApp.mainMenu=menu;
}
