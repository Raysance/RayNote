// UI labels only. Original runtime class names and stored note text are retained.
static NSString *nativeBrandedLabel(NSString *text,BOOL commandOnly) {
 if(!text)return text;
 if(commandOnly && [text rangeOfString:@"Open Raycast Notes Settings" options:NSCaseInsensitiveSearch].location==NSNotFound)return text;
 NSString *result=text;
 for(NSString *name in @[@"Raycast Notes",@"Raycast Note",@"Native Notes",@"Raycast"])
  result=[result stringByReplacingOccurrencesOfString:name withString:@"RayNote" options:NSCaseInsensitiveSearch range:NSMakeRange(0,result.length)];
 return result;
}
static IMP nativeWindowTitleIMP,nativeMenuTitleIMP,nativeTooltipIMP,nativeFieldStringIMP,nativeFieldAttributedIMP;
static void nativeWindowTitle(id self,SEL cmd,NSString *value){((void(*)(id,SEL,id))nativeWindowTitleIMP)(self,cmd,nativeBrandedLabel(value,NO));}
static void nativeMenuTitle(id self,SEL cmd,NSString *value){((void(*)(id,SEL,id))nativeMenuTitleIMP)(self,cmd,nativeBrandedLabel(value,NO));}
static void nativeTooltip(id self,SEL cmd,NSString *value){((void(*)(id,SEL,id))nativeTooltipIMP)(self,cmd,nativeBrandedLabel(value,NO));}
static void nativeFieldString(id self,SEL cmd,NSString *value){((void(*)(id,SEL,id))nativeFieldStringIMP)(self,cmd,nativeBrandedLabel(value,YES));}
static void nativeFieldAttributed(id self,SEL cmd,NSAttributedString *value){
 NSString *label=nativeBrandedLabel(value.string,YES);
 if(![label isEqual:value.string]){
  NSMutableAttributedString *copy=[value mutableCopy];
  NSRange match=[copy.string rangeOfString:@"Raycast Notes" options:NSCaseInsensitiveSearch];
  if(match.location!=NSNotFound)[copy replaceCharactersInRange:match withString:@"RayNote"];
  value=copy;
 }
 ((void(*)(id,SEL,id))nativeFieldAttributedIMP)(self,cmd,value);
}
static void nativeInstallBranding(void){
 nativeWindowTitleIMP=method_setImplementation(class_getInstanceMethod(NSWindow.class,@selector(setTitle:)),(IMP)nativeWindowTitle);
 nativeMenuTitleIMP=method_setImplementation(class_getInstanceMethod(NSMenuItem.class,@selector(setTitle:)),(IMP)nativeMenuTitle);
 nativeTooltipIMP=method_setImplementation(class_getInstanceMethod(NSView.class,@selector(setToolTip:)),(IMP)nativeTooltip);
 nativeFieldStringIMP=method_setImplementation(class_getInstanceMethod(NSTextField.class,@selector(setStringValue:)),(IMP)nativeFieldString);
 nativeFieldAttributedIMP=method_setImplementation(class_getInstanceMethod(NSTextField.class,@selector(setAttributedStringValue:)),(IMP)nativeFieldAttributed);
}
