#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <stdio.h>
#include <unistd.h>
#include <signal.h>
#include <execinfo.h>
#include <sys/ucontext.h>
#include <sandbox.h>
#include "gui_support.h"
#include "branding.h"
static NSString *nativeStorageRoot;
extern void nativeInstallCredentialRebindings(intptr_t);
extern BOOL nativePreparePrivateCredentials(void);
static intptr_t nativeImageSlide;
extern void *nativeSwiftCall4(void *,void *,void *,void *,void *,void *);
static void nativeInitializeTheme(id delegate) {
 void *service=nativeSwiftCall4((__bridge void*)delegate,(void*)(nativeImageSlide+0x100cff5ac),(void*)(nativeImageSlide+0x102e6dcc0),(void*)(nativeImageSlide+0x100cff2ec),(void*)(nativeImageSlide+0x101161b2c),(void*)(nativeImageSlide+0x10115d688));
 void *meta=((void*(*)(uintptr_t))(nativeImageSlide+0x101161b2c))(0);
 void *value[5]={service,NULL,NULL,meta,(void*)(nativeImageSlide+0x102c188c0)};
 ((void(*)(void*))(nativeImageSlide+0x1020e6fd4))(value);
 printf("ORIGINAL THEME PROVIDER INSTALLED %p\n",service);
}
#include "native_settings.h"
static IMP nativeOriginalDirectoryURLs;
static IMP nativeOriginalDirectoryURL;
static NSURL *nativeDataDirectory(NSUInteger directory) {
 NSString *name=nil;
 if(directory==NSApplicationSupportDirectory) name=@"ApplicationSupport";
 if(directory==NSCachesDirectory) name=@"Caches";
 if(directory==NSLibraryDirectory) name=@"Library";
 if(!name)return nil;
 NSString *base=nativeStorageRoot;
 return [NSURL fileURLWithPath:[base stringByAppendingPathComponent:name] isDirectory:YES];
}
static NSArray *nativeDirectoryURLs(id self,SEL cmd,NSUInteger directory,NSUInteger domains) {
 NSURL *url=nativeDataDirectory(directory);
 if(url){printf("ISOLATED DIRECTORY %lu -> %s\n",(unsigned long)directory,url.path.UTF8String);return @[url];}
 return ((id(*)(id,SEL,NSUInteger,NSUInteger))nativeOriginalDirectoryURLs)(self,cmd,directory,domains);
}
static NSURL *nativeDirectoryURL(id self,SEL cmd,NSUInteger directory,NSUInteger domain,NSURL *appropriate,BOOL create,NSError **error) {
 NSURL *url=nativeDataDirectory(directory);
 if(url){if(create && ![[NSFileManager defaultManager] createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:error])return nil;return url;}
 return ((id(*)(id,SEL,NSUInteger,NSUInteger,id,BOOL,NSError**))nativeOriginalDirectoryURL)(self,cmd,directory,domain,appropriate,create,error);
}
static void nativeInstallPathIsolation(void) {
 Method method=class_getInstanceMethod(NSFileManager.class,@selector(URLsForDirectory:inDomains:));nativeOriginalDirectoryURLs=method_setImplementation(method,(IMP)nativeDirectoryURLs);
 method=class_getInstanceMethod(NSFileManager.class,@selector(URLForDirectory:inDomain:appropriateForURL:create:error:));nativeOriginalDirectoryURL=method_setImplementation(method,(IMP)nativeDirectoryURL);
}
static NSURL *nativeIsolatedGroupURL(id self,SEL cmd,NSString *group) {
 NSString *base=[nativeStorageRoot stringByAppendingPathComponent:@"Groups"];
 NSString *safe=[group stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
 NSURL *url=[NSURL fileURLWithPath:[base stringByAppendingPathComponent:safe] isDirectory:YES];
 NSError *error=nil;[[NSFileManager defaultManager] createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:&error];
 printf("ISOLATED GROUP %s -> %s error=%s\n",group.UTF8String,url.path.UTF8String,error.description.UTF8String ?: "none");return url;
}
static void nativeProbeSignalHandler(int sig,siginfo_t *info,void *ctx) {
 ucontext_t *uc=ctx;fprintf(stderr,"SIGNAL %d ADDRESS %p PC %llx\n",sig,info->si_addr,uc->uc_mcontext->__ss.__pc);
 void *frames[60];int n=backtrace(frames,60);backtrace_symbols_fd(frames,n,2);_exit(128+sig);
}
int main(int argc,char **argv){
 setbuf(stdout,NULL);setbuf(stderr,NULL);
 BOOL gui=YES;
 @autoreleasepool {
  nativeStorageRoot=[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/NativeNotesExtracted"];
  [[NSFileManager defaultManager] createDirectoryAtPath:nativeStorageRoot withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:NULL];
  NSString *log=[nativeStorageRoot stringByAppendingPathComponent:@"native-notes.log"];
  freopen(log.fileSystemRepresentation,"a",stdout);freopen(log.fileSystemRepresentation,"a",stderr);setbuf(stdout,NULL);setbuf(stderr,NULL);
  NSString *(^quote)(NSString*)=^NSString*(NSString *s){NSData *d=[NSJSONSerialization dataWithJSONObject:@[s] options:0 error:NULL];NSString *j=[[NSString alloc]initWithData:d encoding:NSUTF8StringEncoding];return [j substringWithRange:NSMakeRange(1,j.length-2)];};
  NSString *originalData=[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/com.raycast.macos"];
  NSString *originalPrefs=[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Preferences/com.raycast.macos.plist"];
  NSString *profile=[NSString stringWithFormat:@"(version 1) (allow default) (deny network*) (deny file-read* file-write* (subpath %@)) (deny file-write* (subpath %@)) (deny file-write* (literal %@)) (deny file-read* (subpath %@))",quote(originalData),quote(@"/Applications/Raycast.app"),quote(originalPrefs),quote([NSHomeDirectory() stringByAppendingPathComponent:@"Library/Keychains"])];
  char *sandboxError=NULL;
  if(sandbox_init(profile.UTF8String,0,&sandboxError)!=0){fprintf(stderr,"Cannot isolate Native Notes: %s\n",sandboxError?:"unknown");return 73;}
  if(!nativePreparePrivateCredentials()){
   fprintf(stderr,"Cannot persist or recover private local database credentials\n");
   NSAlert *alert=[NSAlert new];alert.messageText=@"无法安全打开本地笔记";alert.informativeText=[@"数据库密钥文件缺失、损坏或不可写。为避免覆盖旧数据，应用已停止启动。请恢复整个数据目录的备份：\n" stringByAppendingString:nativeStorageRoot];[alert runModal];return 74;
  }
  nativeInstallPathIsolation();nativeInstallBranding();
  NSString *path=[NSBundle.mainBundle.executablePath.stringByDeletingLastPathComponent stringByAppendingPathComponent:@"NotesCore"];
  printf("LOAD %s\n",path.UTF8String);
  void *h=dlopen(path.fileSystemRepresentation,RTLD_NOW|RTLD_LOCAL);
  if(!h){fprintf(stderr,"DLOPEN FAILED: %s\n",dlerror());return 2;}
  printf("DLOPEN SUCCEEDED %p\n",h);
  for(uint32_t i=0;i<_dyld_image_count();i++) if([[NSString stringWithUTF8String:_dyld_get_image_name(i)] hasSuffix:@"/NotesCore"]) {nativeImageSlide=_dyld_get_image_vmaddr_slide(i);printf("IMAGE BASE %p SLIDE %lx\n",_dyld_get_image_header(i),(unsigned long)nativeImageSlide);}
  struct sigaction sa={0};sa.sa_sigaction=nativeProbeSignalHandler;sa.sa_flags=SA_SIGINFO;
  int signals[]={SIGILL,SIGTRAP,SIGSEGV,SIGBUS,SIGABRT};for(int i=0;i<5;i++)sigaction(signals[i],&sa,NULL);
  nativeInstallCredentialRebindings(nativeImageSlide);
  if(gui || (argc>1 && strcmp(argv[1],"--create-window")==0)) {
   Method groupMethod=class_getInstanceMethod(NSFileManager.class,@selector(containerURLForSecurityApplicationGroupIdentifier:));
   method_setImplementation(groupMethod,(IMP)nativeIsolatedGroupURL);
   printf("CREATE ORIGINAL PRINCIPAL APPLICATION\n");

   Class principal=nativeCreateNotesApplicationClass(objc_getClass("_TtC10RaycastApp11Application"));
   ((id(*)(id,SEL))objc_msgSend)(principal,sel_registerName("sharedApplication"));
   printf("PRINCIPAL APPLICATION READY class=%s\n",object_getClassName(NSApp));

   Class delegateClass=objc_getClass("_TtC10RaycastApp11AppDelegate");
   if(gui)delegateClass=nativeCreateNotesDelegateClass(delegateClass);
   if(delegateClass){
    printf("NATIVE APP DELEGATE INIT\n");
    id delegate=((id(*)(id,SEL))objc_msgSend)(delegateClass,sel_registerName("alloc"));
    delegate=((id(*)(id,SEL))objc_msgSend)(delegate,sel_registerName("init"));
    NSApplication.sharedApplication.delegate=delegate;
    objc_setAssociatedObject(NSApplication.sharedApplication,"delegate-retain",delegate,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    printf("NATIVE APP DELEGATE READY %p\n",(__bridge void*)delegate);
    nativeInitializeTheme(delegate);

   }
   Class cls=objc_getClass("_TtC10RaycastApp18RaycastNotesWindow");
   printf("NATIVE WINDOW ALLOC\n");id raw=((id(*)(id,SEL))objc_msgSend)(cls,sel_registerName("alloc"));
   printf("NATIVE WINDOW INIT %p\n",(__bridge void*)raw);
   NSWindow *window=((id(*)(id,SEL))objc_msgSend)(raw,sel_registerName("init"));
   printf("NATIVE WINDOW CREATED %p title=%s controller=%s\n",(__bridge void*)window,window.title.UTF8String,NSStringFromClass(window.contentViewController.class).UTF8String);
   if(gui){nativeNotesWindow=window;nativeInstallSettingsCallback();nativeCreateStandardMenu();[NSApp run];}
  }
  printf("PROBE COMPLETE\n");
 }
 _exit(0);
}
