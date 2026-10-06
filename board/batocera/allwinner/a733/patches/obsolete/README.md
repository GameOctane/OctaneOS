Patches here are NOT applied.

host-clang, host-llvm and host-xxd were never applied. For a host package Buildroot looks
for global patches in <patch dir>/<name without the "host-" prefix> (RAWNAME in
package/pkg-generic.mk), so these folders had to be called clang, llvm and xxd. They target
problems that only appear with GCC 15 (the original Steam Deck's compiler): C23 treating
"extern long strtol();" as taking no arguments, and position-independent code for host LLVM.
The build passes on GCC 13 without them. If GCC 15 ever needs them again, rename the folder
(for example obsolete/host-xxd -> patches/xxd) and check the patch applies.
