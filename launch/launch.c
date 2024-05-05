// cl -TC -c foo.c && lib -nologo foo.obj -out:foo.lib
#include <stdlib.h>
void launch(const char *cmd) { system(cmd); }
