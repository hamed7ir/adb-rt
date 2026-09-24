// adb-rt CANARY (BATCH-ADB-2C §0.4). Three lines of main(), linked against every dependency
// AS SOON AS that dependency is built.
//
// WHY: /MT-vs-/MD, the EH model, RTTI and _ITERATOR_DEBUG_LEVEL are all per-component
// ABI-affecting flags that must agree across the whole link and fail LATE and confusingly when
// they do not. lld's /failifmismatch already detects them -- the fix is to TRIGGER IT EARLY.
// The CRT mismatch cost five rebuilt libraries because nothing linked until the very end.
//
// It pulls in <string> so the STL's own model directives land in the object too.
#include <string>
int main() {
    std::string s("canary");
    return static_cast<int>(s.size()) - 6;
}
