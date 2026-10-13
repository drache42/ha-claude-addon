/* LD_PRELOAD shim: report $CLAUDE_FAKE_HOSTNAME as this process's hostname.
 * Home Assistant fixes the add-on container hostname (<hash>-claude-code) and
 * grants no CAP_SYS_ADMIN to change it, so the name shown in Remote Control is
 * overridden for the claude process only. */
#define _GNU_SOURCE
#include <stdlib.h>
#include <string.h>
#include <sys/utsname.h>
#include <dlfcn.h>

int gethostname(char *name, size_t len)
{
    const char *h = getenv("CLAUDE_FAKE_HOSTNAME");
    if (h && *h) {
        if (strlen(h) >= len)
            return -1;
        strcpy(name, h);
        return 0;
    }
    int (*real)(char *, size_t) = dlsym(RTLD_NEXT, "gethostname");
    return real(name, len);
}

int uname(struct utsname *buf)
{
    int (*real)(struct utsname *) = dlsym(RTLD_NEXT, "uname");
    int rc = real(buf);
    const char *h = getenv("CLAUDE_FAKE_HOSTNAME");
    if (rc == 0 && h && *h && strlen(h) < sizeof(buf->nodename))
        strcpy(buf->nodename, h);
    return rc;
}
