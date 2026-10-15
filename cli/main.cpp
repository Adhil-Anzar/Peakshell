#include <cerrno>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <iostream>
#include <string>
#include <unistd.h>
#include <vector>

namespace fs = std::filesystem;

static std::string determineConfigDir(const char* argv0) {
    const char* env = std::getenv("PEAKSHELL_CONFIG");
    if (env && env[0] != '\0') {
        return env;
    }

    // 1. Current working directory
    std::error_code ec;
    if (fs::exists("shell.qml", ec)) {
        return fs::current_path(ec).string();
    }

    // 2. Walk up from the executable's directory
    fs::path binPath = fs::canonical(fs::path(argv0), ec);
    if (!ec) {
        fs::path p = binPath.parent_path();
        while (p.has_parent_path() && p != p.parent_path()) {
            if (fs::exists(p / "shell.qml", ec)) {
                return p.string();
            }
            p = p.parent_path();
        }
    }

    // 3. Project source directory recorded at compile time
    if (fs::exists(fs::path(PEAKSHELL_SOURCE_DIR) / "shell.qml", ec)) {
        return PEAKSHELL_SOURCE_DIR;
    }

    // 4. User XDG config: ~/.config/quickshell/peakshell
    const char* home = std::getenv("HOME");
    if (home) {
        fs::path userConfig = fs::path(home) / ".config" / "quickshell" / "peakshell";
        if (fs::exists(userConfig / "shell.qml", ec)) {
            return userConfig.string();
        }
    }

    // 5. System XDG directory: /etc/xdg/quickshell/peakshell
    fs::path sysXdg = "/etc/xdg/quickshell/peakshell";
    if (fs::exists(sysXdg / "shell.qml", ec)) {
        return sysXdg.string();
    }

    // 6. Configured installation directory
    if (fs::exists(fs::path(PEAKSHELL_QSCONFDIR) / "shell.qml", ec)) {
        return PEAKSHELL_QSCONFDIR;
    }

    // Default fallback to source directory
    return PEAKSHELL_SOURCE_DIR;
}

static void setupQmlImportPath(const char* argv0) {
    std::string currentPath;
    const char* env = std::getenv("QML_IMPORT_PATH");
    if (env) {
        currentPath = env;
    }

    std::vector<std::string> extraPaths;
    std::error_code ec;

    // Build directory qml folder recorded at compile time
    fs::path buildQml = fs::path(PEAKSHELL_BINARY_DIR) / "qml";
    if (fs::is_directory(buildQml, ec)) {
        extraPaths.push_back(buildQml.string());
    }

    // Walk up from binary to check for a sibling or parent qml folder
    fs::path binPath = fs::canonical(fs::path(argv0), ec);
    if (!ec) {
        fs::path p = binPath.parent_path();
        while (p.has_parent_path() && p != p.parent_path()) {
            fs::path candidate = p / "qml";
            if (fs::is_directory(candidate / "PeakShell", ec)) {
                extraPaths.push_back(candidate.string());
                break;
            }
            p = p.parent_path();
        }
    }

    // System install location
    if (fs::is_directory(PEAKSHELL_QMLDIR, ec)) {
        extraPaths.push_back(PEAKSHELL_QMLDIR);
    }

    std::string newPath = currentPath;
    for (const auto& p : extraPaths) {
        if (newPath.find(p) == std::string::npos) {
            if (!newPath.empty()) {
                newPath += ":";
            }
            newPath += p;
        }
    }

    if (!newPath.empty()) {
        setenv("QML_IMPORT_PATH", newPath.c_str(), 1);
        setenv("QML2_IMPORT_PATH", newPath.c_str(), 1);
    }
}

static void printVersion() {
    std::cout << "peakshell " PEAKSHELL_VERSION "\n";
}

static void printHelp(const char* argv0) {
    std::cout
        << "Usage: " << argv0 << " [OPTIONS] [SUBCOMMAND [ARGS...]]\n\n"
        << "peakshell – a quickshell based desktop shell.\n\n"
        << "Without a subcommand, launches the shell.\n\n"
        << "OPTIONS:\n"
        << "  -h, --help       Print this help and exit\n"
        << "  -V, --version    Print version and exit\n"
        << "  -d, --daemonize  Detach from the controlling terminal\n"
        << "  -p, --path PATH  Path to a QML file or config folder\n"
        << "  -c, --config NAME Configuration name\n\n"
        << "SUBCOMMANDS (forwarded to quickshell):\n"
        << "  ipc call <target> [fn] [args...]  Call an IPC handler function\n"
        << "  ipc show                          List available IPC targets\n"
        << "  ipc prop <target> <prop> [val]    Get/set an IPC property\n"
        << "  ipc wait <target> <signal>        Wait for an IPC signal\n"
        << "  ipc listen <target> <signal>      Listen for IPC signals\n"
        << "  log                               Print quickshell logs\n"
        << "  list                              List running instances\n"
        << "  kill                              Kill running instances\n\n"
        << "ENVIRONMENT:\n"
        << "  PEAKSHELL_CONFIG  Override the config directory (default: auto-detected)\n";
}

int main(int argc, char* argv[]) {
    bool hasConfigSpecifier = false;
    for (int i = 1; i < argc; ++i) {
        if (std::strcmp(argv[i], "-h") == 0 || std::strcmp(argv[i], "--help") == 0) {
            printHelp(argv[0]);
            return 0;
        }
        if (std::strcmp(argv[i], "-V") == 0 || std::strcmp(argv[i], "--version") == 0) {
            printVersion();
            return 0;
        }
        if (std::strcmp(argv[i], "-p") == 0 || std::strcmp(argv[i], "--path") == 0 ||
            std::strcmp(argv[i], "-c") == 0 || std::strcmp(argv[i], "--config") == 0) {
            hasConfigSpecifier = true;
        }
    }

    setupQmlImportPath(argv[0]);

    std::string config = determineConfigDir(argv[0]);
    std::vector<const char*> args;
    args.push_back("quickshell");

    if (!hasConfigSpecifier) {
        args.push_back("-p");
        args.push_back(config.c_str());
    }

    for (int i = 1; i < argc; ++i) {
        args.push_back(argv[i]);
    }

    args.push_back(nullptr);

    execvp("quickshell", const_cast<char* const*>(args.data()));

    std::cerr << "peakshell: failed to exec quickshell: " << std::strerror(errno) << "\n";
    return 1;
}
