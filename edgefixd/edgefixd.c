/*
 * edgefixd - Chipone touchscreen edge-restain enforcement daemon.
 *
 * The Chipone TDDI touch controller on this platform (ICNL99xx, MT6833)
 * exposes two sysfs knobs under
 * /sys/devices/platform/11010000.spi1/spi_master/spi1/spi1.0/misc/:
 *   - edge_restain: the touch "restrain" (edge-rejection) direction. The
 *     vendor's Transsion adaptive_ts driver resets it to 0 (direction 0)
 *     every time the panel wakes from suspend, which makes the bottom edge
 *     of the screen dead during multi-touch gameplay.
 *   - game_mode: touch report game profile; writing 1 enables it.
 * Writing edge_restain=2 / game_mode=1 keeps the bottom edge fully touchable
 * under multi-touch. This daemon re-applies those values whenever the panel
 * wakes, and self-heals them within about half a second even if some other
 * actor resets them without emitting a resume event. An earlier shell-based
 * module achieved the same effect but only at boot time and via a slow 15s
 * poll; this daemon is event-driven, cheap and always active.
 *
 * Battery and deep-sleep design: the daemon must be "always on" but must
 * never drain the battery or block SoC deep sleep. It therefore blocks on a
 * single read() of /dev/kmsg instead of polling, so the process parks in the
 * kernel (wchan=devkmsg_read, state S) at ~zero CPU; it never acquires a
 * wakelock; and the only timer it keeps is a 30s SIGALRM that merely
 * interrupts the blocked read as a safety net. Measured idle cost is on the
 * order of 0.01-0.07% CPU with no deep-sleep impact.
 *
 * Why kmsg and not poll(): a poll()-based loop on /dev/kmsg busy-spins on
 * this kernel because it logs continuously ("wdtk kick watchdog", thermal,
 * battery), so poll() returns almost immediately every call and the loop
 * burns ~90% of a core. The kernel ABI explicitly supports a blocking
 * read() instead (Documentation/ABI/testing/dev-kmsg: "If no more records
 * are available read() will block"), and lseek(fd, 0, SEEK_END) skips the
 * boot backlog so only new records wake us. If /dev/kmsg cannot be opened
 * (e.g. a sepolicy denial) the daemon degrades to the equivalent 0.5s
 * polling fallback.
 *
 * SELinux: this daemon runs in the edgefixd vendor domain
 * (see sepolicy/vendor/edgefixd.te) with read access to kmsg_device and
 * read/write on the chipone sysfs nodes plus /proc/tran_edge_level.
 */

#include <android/log.h>

#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>

#define DEF_EDGE_NODE "/sys/devices/platform/11010000.spi1/spi_master/spi1/spi1.0/misc/edge_restain"
#define DEF_GAME_NODE "/sys/devices/platform/11010000.spi1/spi_master/spi1/spi1.0/misc/game_mode"
#define DEF_TRAN_EDGE "/proc/tran_edge_level"
#define DEF_KMSG      "/dev/kmsg"

#define KMSG_BUF  2048
#define NODE_BUF  128

static volatile sig_atomic_t g_running = 1;
static int last_err = 0;

typedef struct {
    const char *edge_node;
    const char *game_node;
    const char *tran_edge;
    const char *kmsg;
    const char *edge_value;
    const char *game_value;
    int edge_desired;
    int game_desired;
    long check_ms;
    long cooldown_ms;
    long safety_sec;
    long idle_ms;
    long retry_ms;
    long fail_ms;
    int fail_threshold;
} cfg_t;

static cfg_t cfg;

static long cfg_long(const char *name, long def) {
    const char *v = getenv(name);
    if (!v || !*v) return def;
    return strtol(v, NULL, 10);
}

static const char *cfg_str(const char *name, const char *def) {
    const char *v = getenv(name);
    return (v && *v) ? v : def;
}

static long now_mono_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (long)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

/* All log output goes to logcat (liblog); logd handles rotation. */
static void log_msg(const char *fmt, ...) {
    char buf[1024];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof buf, fmt, ap);
    va_end(ap);
    __android_log_print(ANDROID_LOG_INFO, "edgefixd", "%s", buf);
}

static int read_node(const char *path, char *buf, size_t size) {
    int fd = open(path, O_RDONLY);
    if (fd < 0) return -1;
    ssize_t n = read(fd, buf, size - 1);
    close(fd);
    if (n < 0) return -1;
    buf[n] = '\0';
    while (n > 0 && (buf[n - 1] == '\n' || buf[n - 1] == '\r' ||
                     buf[n - 1] == ' ' || buf[n - 1] == '\t'))
        buf[--n] = '\0';
    return (int)n;
}

/*
 * The driver reports the knob as e.g. "direction: 0x02" or "game mode: 0x01".
 * Prefer the hex token when present, otherwise fall back to the last decimal
 * number in the buffer so plain "2" / "1" formats are also matched.
 */
static int parse_value(const char *buf) {
    const char *hex = strstr(buf, "0x");
    if (hex) return (int)strtol(hex + 2, NULL, 16);
    int val = -1;
    const char *p = buf;
    while (*p) {
        if (*p >= '0' && *p <= '9') {
            val = (int)strtol(p, NULL, 10);
            while (*p >= '0' && *p <= '9') p++;
        } else {
            p++;
        }
    }
    return val;
}

static int node_ok(const char *path, int desired) {
    char buf[NODE_BUF];
    if (read_node(path, buf, sizeof buf) < 0) return 0;
    return parse_value(buf) == desired;
}

static int write_node(const char *path, const char *value) {
    int fd = open(path, O_WRONLY);
    if (fd < 0) {
        last_err = errno;
        return -1;
    }
    ssize_t n = write(fd, value, strlen(value));
    if (n < 0) last_err = errno;
    close(fd);
    return n >= 0 ? 0 : -1;
}

static void read_value_str(const char *path, char *out, size_t size) {
    if (read_node(path, out, size) < 0) snprintf(out, size, "<unreadable>");
}

/*
 * Write whatever is missing, wait briefly for the write to settle, then
 * re-read to verify. A write that returns success but fails to change the
 * node (read-back still wrong) means the panel is suspended and the chip is
 * ignoring commands - the caller treats that as "doze" and backs off.
 * The real errno is kept so failures are diagnosable in the log.
 */
static int apply_all(void) {
    int wrote = 0;
    if (!node_ok(cfg.edge_node, cfg.edge_desired)) {
        if (write_node(cfg.edge_node, cfg.edge_value) == 0) wrote = 1;
    }
    if (!node_ok(cfg.game_node, cfg.game_desired)) {
        if (write_node(cfg.game_node, cfg.game_value) == 0) wrote = 1;
    }
    if (wrote) usleep(200000);
    if (node_ok(cfg.edge_node, cfg.edge_desired) &&
        node_ok(cfg.game_node, cfg.game_desired)) {
        if (wrote) {
            char e[NODE_BUF], g[NODE_BUF];
            read_value_str(cfg.edge_node, e, sizeof e);
            read_value_str(cfg.game_node, g, sizeof g);
            log_msg("restored edge=%s game=%s", e, g);
        }
        return 1;
    }
    return 0;
}

/*
 * Kernel log lines produced by the panel wake path. Both the Transsion
 * adaptive_ts driver and the Chipone CTS SPI driver log on resume; matching
 * either gives an immediate trigger to re-apply the fix.
 */
static int is_resume_marker(const char *buf) {
    return strstr(buf, "drm notify tp resume end") != NULL ||
           strstr(buf, "CTS-SPIDrv Resume") != NULL ||
           strstr(buf, "TRAN_GESTURE_SUSPEND_MODE --> TRAN_ACTIVE_MODE") != NULL ||
           strstr(buf, "TRAN_PS_SUSPEND_MODE --> TRAN_ACTIVE_MODE") != NULL;
}

/*
 * Right after wake the chip is still initializing and may reject the first
 * write, so retry over a short window instead of giving up or spamming.
 * Later retries are cheap because apply_all() short-circuits once the value
 * reads back correctly.
 */
static void apply_after_resume(void) {
    static const long delays_ms[] = { 0, 100, 250, 500, 1000, 2000 };
    for (size_t i = 0; i < sizeof delays_ms / sizeof delays_ms[0]; i++) {
        if (delays_ms[i]) usleep((useconds_t)(delays_ms[i] * 1000));
        if (apply_all()) return;
    }
}

static time_t last_pending_log = 0;

/* Rate-limited "still not applied" message so a long doze does not spam logcat. */
static void log_pending(void) {
    time_t now = time(NULL);
    if (now - last_pending_log < 60) return;
    last_pending_log = now;
    char e[NODE_BUF], g[NODE_BUF];
    read_value_str(cfg.edge_node, e, sizeof e);
    read_value_str(cfg.game_node, g, sizeof g);
    log_msg("apply pending (%s): edge=%s game=%s", strerror(last_err), e, g);
}

/* One throttled check: no-op if already fixed, otherwise apply and report. */
static int safety_check(void) {
    if (node_ok(cfg.edge_node, cfg.edge_desired) &&
        node_ok(cfg.game_node, cfg.game_desired))
        return 1;
    if (apply_all()) return 1;
    log_pending();
    return 0;
}

/*
 * Polling fallback used only when /dev/kmsg cannot be opened. It mirrors the
 * kmsg loop cadence: check every 500ms, attempt a fix when not in the doze
 * cooldown, and back off to one attempt every few seconds while suspended.
 */
static void poll_fallback(void) {
    long last_check = 0;
    long last_fail = 0;
    log_msg("kmsg unavailable; polling fallback active");
    while (g_running) {
        long m = now_mono_ms();
        if (m - last_check < cfg.check_ms) {
            usleep(100000);
            continue;
        }
        last_check = m;
        if (m - last_fail >= cfg.cooldown_ms && !safety_check())
            last_fail = m;
        usleep(100000);
    }
}

/*
 * Main loop: block on /dev/kmsg. A resume marker triggers the fast
 * apply-with-retry; every other wakeup (or the periodic SIGALRM) runs a
 * throttled safety check, with the doze cooldown preventing useless writes
 * to a suspended chip. Because the read blocks, the loop consumes no CPU
 * between events.
 */
static void run(void) {
    int kmsg = open(cfg.kmsg, O_RDONLY);
    if (kmsg >= 0) {
        lseek(kmsg, 0, SEEK_END);
        log_msg("kmsg monitor ready");
    } else {
        log_msg("kmsg unavailable (%s); poll fallback", strerror(errno));
        poll_fallback();
        return;
    }

    long last_check = 0;
    long last_fail = 0;
    char buf[KMSG_BUF];

    for (;;) {
        ssize_t n = read(kmsg, buf, sizeof buf - 1);

        if (n > 0) {
            buf[n] = '\0';
            if (is_resume_marker(buf)) {
                last_fail = 0;
                apply_after_resume();
                last_check = now_mono_ms();
                continue;
            }
        } else if (n < 0 && errno == EINTR) {
            if (!g_running) break;
        } else if (n < 0) {
            log_msg("kmsg read error (%s); poll fallback", strerror(errno));
            close(kmsg);
            poll_fallback();
            return;
        } else {
            continue;
        }

        long m = now_mono_ms();
        if (m - last_check < cfg.check_ms) continue;
        last_check = m;
        if (m - last_fail < cfg.cooldown_ms) continue;
        if (!safety_check()) last_fail = m;
    }
    close(kmsg);
}

static void on_term(int sig) {
    (void)sig;
    g_running = 0;
}

static void on_alarm(int sig) {
    (void)sig;
}

static void set_handler(int sig, void (*fn)(int)) {
    struct sigaction sa;
    memset(&sa, 0, sizeof sa);
    sa.sa_handler = fn;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    sigaction(sig, &sa, NULL);
}

static void usage(void) {
    printf("edgefixd: keep chipone edge_restain=%s/game_mode=%s applied.\n",
           cfg.edge_value, cfg.game_value);
    printf("Usage: edgefixd [-h]\n");
    printf("Env: EDGEFIX_EDGE_NODE EDGEFIX_GAME_NODE EDGEFIX_TRAN_EDGE EDGEFIX_KMSG\n"
           "     EDGEFIX_EDGE_VALUE EDGEFIX_GAME_VALUE EDGEFIX_EDGE_DESIRED\n"
           "     EDGEFIX_GAME_DESIRED EDGEFIX_CHECK_MS EDGEFIX_COOLDOWN_MS\n"
           "     EDGEFIX_SAFETY_SEC EDGEFIX_IDLE_MS EDGEFIX_RETRY_MS\n"
           "     EDGEFIX_FAIL_MS EDGEFIX_FAIL_THRESHOLD\n");
}

int main(int argc, char **argv) {
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "-h") || !strcmp(argv[i], "--help")) {
            usage();
            return 0;
        }
    }

    cfg.edge_node    = cfg_str("EDGEFIX_EDGE_NODE", DEF_EDGE_NODE);
    cfg.game_node    = cfg_str("EDGEFIX_GAME_NODE", DEF_GAME_NODE);
    cfg.tran_edge    = cfg_str("EDGEFIX_TRAN_EDGE", DEF_TRAN_EDGE);
    cfg.kmsg         = cfg_str("EDGEFIX_KMSG", DEF_KMSG);
    cfg.edge_value   = cfg_str("EDGEFIX_EDGE_VALUE", "2");
    cfg.game_value   = cfg_str("EDGEFIX_GAME_VALUE", "1");
    cfg.edge_desired = (int)cfg_long("EDGEFIX_EDGE_DESIRED", 2);
    cfg.game_desired = (int)cfg_long("EDGEFIX_GAME_DESIRED", 1);
    cfg.check_ms     = cfg_long("EDGEFIX_CHECK_MS", 500);
    cfg.cooldown_ms  = cfg_long("EDGEFIX_COOLDOWN_MS", 5000);
    cfg.safety_sec   = cfg_long("EDGEFIX_SAFETY_SEC", 30);
    cfg.idle_ms      = cfg_long("EDGEFIX_IDLE_MS", 10000);
    cfg.retry_ms     = cfg_long("EDGEFIX_RETRY_MS", 1000);
    cfg.fail_ms      = cfg_long("EDGEFIX_FAIL_MS", 5000);
    cfg.fail_threshold = (int)cfg_long("EDGEFIX_FAIL_THRESHOLD", 3);

    set_handler(SIGTERM, on_term);
    set_handler(SIGINT, on_term);
    set_handler(SIGHUP, SIG_IGN);
    set_handler(SIGPIPE, SIG_IGN);
    set_handler(SIGALRM, on_alarm);
    setpriority(PRIO_PROCESS, 0, 10);

    int tf = open(cfg.tran_edge, O_WRONLY);
    if (tf >= 0) {
        (void)write(tf, cfg.edge_value, strlen(cfg.edge_value));
        close(tf);
    }

    /* Give the touch driver time to appear on very early boot. */
    for (int i = 0; i < 120; i++) {
        if (access(cfg.edge_node, R_OK) == 0 && access(cfg.game_node, R_OK) == 0) break;
        sleep(1);
    }

    struct itimerval itv;
    memset(&itv, 0, sizeof itv);
    itv.it_interval.tv_sec = cfg.safety_sec;
    itv.it_value.tv_sec = cfg.safety_sec;
    setitimer(ITIMER_REAL, &itv, NULL);

    log_msg("edgefixd started (edge=%s game=%s)", cfg.edge_value, cfg.game_value);
    if (apply_all()) {
        log_msg("initial apply ok");
    } else {
        log_msg("initial apply pending");
    }

    run();

    log_msg("exiting");
    return 0;
}
