#import <Foundation/Foundation.h>
#import <Security/Security.h>
#include <sys/stat.h>
extern BOOL nativePreparePrivateCredentials(void);
extern OSStatus nativeLocalSecItemAdd(CFDictionaryRef,CFTypeRef*);
extern OSStatus nativeLocalSecItemCopyMatching(CFDictionaryRef,CFTypeRef*);
int main(int argc,char **argv){@autoreleasepool{
 if(argc<3)return 2;setenv("NATIVE_NOTES_TEST_CREDENTIAL_ROOT",argv[1],1);
 BOOL ready=nativePreparePrivateCredentials();NSString *mode=@(argv[2]);
 if([mode isEqual:@"reject"])return ready?10:0;
 if(!ready)return 11;
 NSMutableDictionary *q=[@{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,(__bridge id)kSecAttrService:@"Native Notes",(__bridge id)kSecAttrAccount:@"database_key"}mutableCopy];
 NSData *fixture=[@"generated-test-fixture-only" dataUsingEncoding:NSUTF8StringEncoding];
 if([mode isEqual:@"write"]){q[(__bridge id)kSecValueData]=fixture;OSStatus s=nativeLocalSecItemAdd((__bridge CFDictionaryRef)q,NULL);if(s!=0)return 12;[q removeObjectForKey:(__bridge id)kSecValueData];}
 q[(__bridge id)kSecReturnData]=@YES;CFTypeRef value=NULL;OSStatus s=nativeLocalSecItemCopyMatching((__bridge CFDictionaryRef)q,&value);BOOL matches=value&&CFEqual(value,(__bridge CFDataRef)fixture);if(value)CFRelease(value);if(s||!matches)return 13;
 q[(__bridge id)kSecAttrService]=@"Raycast";value=NULL;s=nativeLocalSecItemCopyMatching((__bridge CFDictionaryRef)q,&value);if(value)CFRelease(value);if(s!=errSecItemNotFound)return 14;
 struct stat st;NSString *file=[@(argv[1]) stringByAppendingPathComponent:@"PrivateCredentials.plist"];if(stat(file.fileSystemRepresentation,&st)|| (st.st_mode&0777)!=0600)return 15;
 return 0;
}}
