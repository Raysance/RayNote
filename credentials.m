// Local generated database keys only. No Raycast account secrets or system
// Keychain access. The key file is private (0600), not Keychain protected.
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <sys/stat.h>
#import <fcntl.h>
#import <unistd.h>
#import <errno.h>
static NSObject *nativeCredentialsLock;
static NSMutableArray<NSMutableDictionary *> *nativeCredentials;
static NSURL *nativeCredentialsURL;
static BOOL nativeCredentialsValid=YES;
static NSString *nativeCredentialRoot(void) {
#ifdef NATIVE_CREDENTIALS_TEST
 return NSProcessInfo.processInfo.environment[@"NATIVE_NOTES_TEST_CREDENTIAL_ROOT"];
#else
 return [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/NativeNotesExtracted"];
#endif
}
static NSString *nativeCredentialService(void){return NSBundle.mainBundle.infoDictionary[@"CFBundleName"] ?: @"Native Notes";}

static void nativeInitializeCredentials(void) {
 static dispatch_once_t token;dispatch_once(&token,^{
  nativeCredentialsLock=[NSObject new];
  NSString *root=nativeCredentialRoot();
  [[NSFileManager defaultManager] createDirectoryAtPath:root withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:NULL];
  nativeCredentialsURL=[NSURL fileURLWithPath:[root stringByAppendingPathComponent:@"PrivateCredentials.plist"]];
  BOOL exists=[[NSFileManager defaultManager] fileExistsAtPath:nativeCredentialsURL.path];
  NSArray *stored=[NSArray arrayWithContentsOfURL:nativeCredentialsURL];
  nativeCredentials=[NSMutableArray array];
  if(exists && ![stored isKindOfClass:NSArray.class])nativeCredentialsValid=NO;
  if(nativeCredentialsValid)for(id item in stored){
   if(![item isKindOfClass:NSDictionary.class] || ![item[(__bridge id)kSecValueData] isKindOfClass:NSData.class] || ![item[(__bridge id)kSecAttrService] isKindOfClass:NSString.class] || ![item[(__bridge id)kSecAttrAccount] isKindOfClass:NSString.class]){nativeCredentialsValid=NO;break;}
   [nativeCredentials addObject:[item mutableCopy]];
  }
 });
}
static BOOL nativeCredentialMatches(NSDictionary *item,NSDictionary *query) {
 for(id key in @[(__bridge id)kSecClass,(__bridge id)kSecAttrService,(__bridge id)kSecAttrAccount,(__bridge id)kSecAttrAccessGroup]){
  id expected=query[key];if(expected && ![expected isEqual:item[key]])return NO;
 }
 return YES;
}
static NSMutableDictionary *nativeCredentialAttributes(NSDictionary *query) {
 NSMutableDictionary *d=[NSMutableDictionary dictionary];
 for(id key in @[(__bridge id)kSecClass,(__bridge id)kSecAttrService,(__bridge id)kSecAttrAccount,(__bridge id)kSecAttrAccessGroup,(__bridge id)kSecAttrLabel,(__bridge id)kSecAttrComment,(__bridge id)kSecAttrGeneric,(__bridge id)kSecAttrAccessible,(__bridge id)kSecValueData])if(query[key])d[key]=query[key];
 return d;
}
static BOOL nativeSaveCredentials(void) {
 NSError *error=nil;
 NSData *bytes=[NSPropertyListSerialization dataWithPropertyList:nativeCredentials format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error];
 if(!bytes)return NO;
 NSString *temporary=[nativeCredentialsURL.path stringByAppendingFormat:@".%@.tmp",NSUUID.UUID.UUIDString];
 int fd=open(temporary.fileSystemRepresentation,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0600);
 if(fd<0)return NO;
 const uint8_t *p=bytes.bytes;size_t left=bytes.length;BOOL ok=YES;
 while(left){ssize_t n=write(fd,p,left);if(n<0&&errno==EINTR)continue;if(n<=0){ok=NO;break;}p+=n;left-=n;}
 if(ok&&fsync(fd)!=0)ok=NO;close(fd);
 if(ok&&rename(temporary.fileSystemRepresentation,nativeCredentialsURL.fileSystemRepresentation)!=0)ok=NO;
 if(!ok)unlink(temporary.fileSystemRepresentation);
 return ok;
}
BOOL nativePreparePrivateCredentials(void) {
 nativeInitializeCredentials();
 @synchronized(nativeCredentialsLock){
  if(!nativeCredentialsValid)return NO;
  NSString *identifier=NSBundle.mainBundle.bundleIdentifier ?: @"local.notes.native-extracted";
  NSString *database=[nativeCredentialRoot() stringByAppendingPathComponent:[NSString stringWithFormat:@"ApplicationSupport/%@/raycast-enc.sqlite",identifier]];
  if([[NSFileManager defaultManager] fileExistsAtPath:database]){
   BOOL hasKey=NO;for(NSDictionary *item in nativeCredentials)if([item[(__bridge id)kSecAttrAccount] isEqual:@"database_key"] && [item[(__bridge id)kSecAttrService] isEqual:nativeCredentialService()])hasKey=YES;
   if(!hasKey)return NO;
  }
  struct stat st;
  if(lstat(nativeCredentialsURL.fileSystemRepresentation,&st)==0 && (!S_ISREG(st.st_mode)||st.st_uid!=getuid()))return NO;
  return nativeSaveCredentials();
 }
}
static BOOL nativeAllowedCredential(NSDictionary *q) {
 NSString *account=q[(__bridge id)kSecAttrAccount];
 return [q[(__bridge id)kSecClass] isEqual:(__bridge id)kSecClassGenericPassword] &&
  [q[(__bridge id)kSecAttrService] isEqual:nativeCredentialService()] &&
  ([@"database_key" isEqual:account] || [@"urlcache_key" isEqual:account]);
}
static id nativeCredentialResult(NSDictionary *item,NSDictionary *query) {
 BOOL data=[query[(__bridge id)kSecReturnData] boolValue],attrs=[query[(__bridge id)kSecReturnAttributes] boolValue];
 if(attrs){NSMutableDictionary *result=[item mutableCopy];if(!data)[result removeObjectForKey:(__bridge id)kSecValueData];return result;}
 if(data)return item[(__bridge id)kSecValueData];
 return nil;
}
OSStatus nativeLocalSecItemCopyMatching(CFDictionaryRef raw,CFTypeRef *output) {
 nativeInitializeCredentials();NSDictionary *query=(__bridge NSDictionary*)raw;if(output)*output=NULL;if(!nativeAllowedCredential(query))return errSecItemNotFound;
 @synchronized(nativeCredentialsLock){
  NSMutableArray *found=[NSMutableArray array];for(NSDictionary *item in nativeCredentials)if(nativeCredentialMatches(item,query))[found addObject:item];

  if(!found.count)return errSecItemNotFound;
  id result=nil;
  if([query[(__bridge id)kSecMatchLimit] isEqual:(__bridge id)kSecMatchLimitAll]){NSMutableArray *all=[NSMutableArray array];for(id item in found){id v=nativeCredentialResult(item,query);if(v)[all addObject:v];}result=all;}
  else result=nativeCredentialResult(found.firstObject,query);
  if(output && result)*output=CFBridgingRetain(result);return errSecSuccess;
 }
}
OSStatus nativeLocalSecItemAdd(CFDictionaryRef raw,CFTypeRef *output) {
 nativeInitializeCredentials();NSDictionary *query=(__bridge NSDictionary*)raw;if(output)*output=NULL;if(!nativeAllowedCredential(query))return errSecItemNotFound;
 @synchronized(nativeCredentialsLock){
  for(NSDictionary *item in nativeCredentials)if(nativeCredentialMatches(item,query))return errSecDuplicateItem;
  NSMutableDictionary *item=nativeCredentialAttributes(query);[nativeCredentials addObject:item];
  if(!nativeSaveCredentials())return errSecIO;

  id value=nativeCredentialResult(item,query);if(output&&value)*output=CFBridgingRetain(value);return errSecSuccess;
 }
}
OSStatus nativeLocalSecItemUpdate(CFDictionaryRef raw,CFDictionaryRef updates) {
 nativeInitializeCredentials();NSDictionary *query=(__bridge NSDictionary*)raw;if(!nativeAllowedCredential(query))return errSecParam;
 @synchronized(nativeCredentialsLock){BOOL found=NO;for(NSMutableDictionary *item in nativeCredentials)if(nativeCredentialMatches(item,query)){[item addEntriesFromDictionary:nativeCredentialAttributes((__bridge NSDictionary*)updates)];found=YES;}if(!found)return errSecItemNotFound;return nativeSaveCredentials()?errSecSuccess:errSecIO;}
}
OSStatus nativeLocalSecItemDelete(CFDictionaryRef raw) {
 nativeInitializeCredentials();NSDictionary *query=(__bridge NSDictionary*)raw;if(!nativeAllowedCredential(query))return errSecParam;
 @synchronized(nativeCredentialsLock){NSIndexSet *indexes=[nativeCredentials indexesOfObjectsPassingTest:^BOOL(id item,NSUInteger idx,BOOL*stop){return nativeCredentialMatches(item,query);}];if(!indexes.count)return errSecItemNotFound;[nativeCredentials removeObjectsAtIndexes:indexes];return nativeSaveCredentials()?errSecSuccess:errSecIO;}
}

#import <sys/mman.h>
#import <unistd.h>
#import "security_slots.h"
void nativeInstallCredentialRebindings(intptr_t slide) {
 struct {uintptr_t address;void *replacement;const char *name;} bindings[]={
  {NATIVE_SLOT_SecItemAdd,(void*)nativeLocalSecItemAdd,"SecItemAdd"},
  {NATIVE_SLOT_SecItemCopyMatching,(void*)nativeLocalSecItemCopyMatching,"SecItemCopyMatching"},
  {NATIVE_SLOT_SecItemUpdate,(void*)nativeLocalSecItemUpdate,"SecItemUpdate"},
  {NATIVE_SLOT_SecItemDelete,(void*)nativeLocalSecItemDelete,"SecItemDelete"}};
 size_t pageSize=getpagesize();uintptr_t page=(slide+bindings[0].address)&~(pageSize-1);
 if(mprotect((void*)page,pageSize,PROT_READ|PROT_WRITE)!=0){perror("mprotect keychain bindings");_exit(70);}
 for(unsigned i=0;i<4;i++){
  void **slot=(void**)(slide+bindings[i].address);
  *slot=bindings[i].replacement;
 }
 if(mprotect((void*)page,pageSize,PROT_READ)!=0){perror("restore binding protection");_exit(71);}
}
