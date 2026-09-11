#include "sentry.h"

#include <cstdio>
#include <cstdlib>
#include <stdexcept>

int
main()
{
    const char *dsn = std::getenv("SENTRY_DSN");
    if (!dsn || !*dsn) {
        std::fputs("Set SENTRY_DSN for the crash report.\n", stderr);
        return 1;
    }

    sentry_options_t *options = sentry_options_new();
    sentry_options_set_crash_reporting_mode(
        options, SENTRY_CRASH_REPORTING_MODE_NATIVE_WITH_MINIDUMP);
    if (sentry_init(options) != 0) {
        return 1;
    }
    sentry_set_tag("test.case", "cpp-exception");

    std::puts("Throwing an uncaught std::runtime_error.");
    std::fflush(stdout);
    throw std::runtime_error("something went wrong");
}
