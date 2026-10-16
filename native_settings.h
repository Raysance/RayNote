// The original Notes provider builds every form item and binding. The host
// supplies only a window and the original reusable RaycastUI section list container.
#import <sys/mman.h>
static NSWindow *nativeSettingsWindow;
static void *nativeSettingsProvider;
static void nativeShowSettings(void) {
 if(!nativeSettingsWindow){
  void *metadata=((void*(*)(uintptr_t))(nativeImageSlide+0x100a52fd0))(0);
  nativeSettingsProvider=((void*(*)(void*,void*))(nativeImageSlide+0x100a4ac3c))(metadata,(void*)(nativeImageSlide+0x102be6810));
  void *items=nativeSwiftCall4(nativeSettingsProvider,(void*)(nativeImageSlide+0x100a6bc64),NULL,NULL,NULL,NULL);
  Class formClass=objc_getClass("_TtC9RaycastUI18ListViewController");
  NSViewController *form=[[formClass alloc]initWithNibName:nil bundle:nil];
  if(!form||!items){fprintf(stderr,"Original Notes preferences could not be initialized\n");return;}
  form.view.frame=NSMakeRect(0,0,620,480);
  nativeSettingsWindow=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,620,480) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO];
  nativeSettingsWindow.title=@"RayNote Settings";
  nativeSettingsWindow.level=nativeNotesWindow.level+1;
  nativeSettingsWindow.releasedWhenClosed=NO;
  NSViewController *container=[NSViewController new];
  container.view=[[NSView alloc]initWithFrame:NSMakeRect(0,0,620,480)];
  [container addChildViewController:form];
  [container.view addSubview:form.view];
  form.view.frame=container.view.bounds;
  form.view.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;
  nativeSettingsWindow.contentViewController=container;
  [nativeSettingsWindow setContentSize:NSMakeSize(620,480)];
  nativeSwiftCall4((__bridge void*)form,(void*)(nativeImageSlide+0x101ee3764),items,NULL,(void*)1,NULL);
  ((void(*)(void*))(nativeImageSlide+0x102571004))(items);
  [nativeSettingsWindow center];
  printf("ORIGINAL NOTES PREFERENCES PROVIDER AND SECTION LIST CREATED\n");
 }
 [nativeSettingsWindow makeKeyAndOrderFront:nil];[NSApp activateIgnoringOtherApps:YES];
}
static void nativeSettingsAction(id self,SEL cmd,id sender){nativeShowSettings();}
static void nativeSettingsCallback(void){nativeShowSettings();}
static void nativeRefreshOriginalStatus(void) {
 nativeSwiftCall4((__bridge void*)NSApp.delegate,(void*)(nativeImageSlide+0x100cfde58),NULL,NULL,NULL,NULL);
}
static void nativeStatusOpen(id self,SEL cmd){nativeShowNotes();}
static void nativeInstallSettingsCallback(void) {
 Class statusClass=objc_getClass("_TtC10RaycastApp32RaycastNotesStatusItemController");
 Method open=class_getInstanceMethod(statusClass,sel_registerName("openRaycastNotes"));
 if(open)method_setImplementation(open,(IMP)nativeStatusOpen);
 nativeStatusRefresh=nativeRefreshOriginalStatus;
 nativeRefreshOriginalStatus();
 // NSApplicationMain's Swift import is unused because the launcher entry point
 // is removed. Reuse that slot for the Notes-only preferences bridge.
 uintptr_t address=nativeImageSlide+0x102b93440ULL;
 size_t size=getpagesize();uintptr_t page=address&~(size-1);
 if(mprotect((void*)page,size,PROT_READ|PROT_WRITE)!=0){perror("Notes settings bridge");_exit(75);}
 *(void**)address=(void*)nativeSettingsCallback;
 if(mprotect((void*)page,size,PROT_READ)!=0){perror("Notes settings bridge protection");_exit(76);}
 Class actions=objc_allocateClassPair(NSObject.class,"NativeNotesMenuActions",0);
 class_addMethod(actions,sel_registerName("showIndependentNotesSettings:"),(IMP)nativeSettingsAction,"v@:@");
 objc_registerClassPair(actions);nativeSettingsMenuTarget=[actions new];
}
