#import "HashcordRuntimeC.h"
#import "HashcordRuntime.h"

extern "C" void HashcordLoadIntoRuntimePtr(void *runtime, NSString *bundlePath, NSURL *pyoncordDir)
{
    if (!runtime) return;
    HashcordLoadIntoRuntime(*static_cast<facebook::jsi::Runtime *>(runtime), bundlePath, pyoncordDir);
}
