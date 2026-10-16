.text
.p2align 2
.globl _nativeSwiftCall4
_nativeSwiftCall4:
 stp x20, x30, [sp, #-16]!
 mov x20, x0
 mov x16, x1
 mov x0, x2
 mov x1, x3
 mov x2, x4
 mov x3, x5
 blr x16
 ldp x20, x30, [sp], #16
 ret
