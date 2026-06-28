module merlin.builder;

import std.stdio;
import std.file;
import std.process;
import std.path;
import std.algorithm;
import std.string;
import std.array;
import core.stdc.stdlib : exit;

import merlin.tui;

int countFiles(string dirPath, string extension) {
    if (!exists(dirPath) || !isDir(dirPath)) return 0;
    int count = 0;
    foreach (DirEntry entry; dirEntries(dirPath, SpanMode.depth)) {
        if (entry.isFile && entry.name.endsWith(extension)) {
            count++;
        }
    }
    return count;
}

void buildTarget(bool release, bool testTarget) {
    string objDir = release ? "obj/release" : "obj/debug";
    mkdirRecurse(objDir);
    mkdirRecurse("bin");

    string cc = environment.get("CC", "clang");

    // Detect C23 standard support flag (fallback to C2x on older compilers)
    string stdFlag = "-std=c23";
    try {
        version(Windows) {
            string nullDevice = "NUL";
        } else {
            string nullDevice = "/dev/null";
        }
        auto res = executeShell(cc ~ " -std=c23 -E - < " ~ nullDevice);
        if (res.status != 0) {
            stdFlag = "-std=c2x";
        }
    } catch (Exception e) {
        stdFlag = "-std=c2x";
    }

    string camelotHome = environment.get("CAMELOT_HOME", "");

    // Build orchestration with full Yutila Security mitigation compliance
    string[] cflags = ["-Wall", "-Wextra", "-Wpedantic", "-Werror", stdFlag];
    version(Posix) {
        cflags ~= ["-fPIE", "-fstack-protector-strong"];
    } else {
        cflags ~= ["-fstack-protector-strong"]; // MSYS usually supports stack protector
    }
    if (camelotHome.length > 0) {
        cflags ~= ["-I" ~ buildPath(camelotHome, "include")];
        cflags ~= ["-Iinclude"];
    } else {
        cflags ~= ["-Iinclude"];
    }

    string[] ldflags;
    version(Posix) {
        ldflags ~= ["-pie", "-Wl,-z,noexecstack"];
    } else {
        ldflags ~= ["-Wl,--dynamicbase", "-Wl,--nxcompat"];
    }

    if (release) {
        cflags ~= ["-O2", "-fwrapv", "-fno-delete-null-pointer-checks", "-fno-strict-overflow"];
        version(Posix) { cflags ~= ["-D_FORTIFY_SOURCE=2"]; }
    } else {
        cflags ~= ["-O0", "-g", "-DDEBUG", "-ftrapv"];
        version(Posix) {
            cflags ~= ["-fsanitize=address,undefined"];
            ldflags ~= ["-fsanitize=address,undefined"];

            // Leak sanitizer is only reliably supported on Linux x86_64
            version(X86_64) {
                version(linux) {
                    cflags ~= ["-fsanitize=leak"];
                    ldflags ~= ["-fsanitize=leak"];
                }
            }

            // Detect compiler identity and configure the appropriate sanitizer runtime.
            // Clang and GCC ship incompatible ASan runtimes — mixing them causes link
            // failures or silent corruption at runtime.
            bool isClang = false;
            try {
                auto ccIdent = executeShell(cc ~ " --version 2>&1");
                if (ccIdent.status == 0 && ccIdent.output.toLower().canFind("clang")) {
                    isClang = true;
                }
            } catch (Exception e) {}

            if (isClang) {
                // Clang: prefer its own compiler-rt sanitizer runtime to avoid
                // accidentally linking against a system-installed GCC libasan.
                cflags ~= ["-static-libsan"];
                ldflags ~= ["-static-libsan"];
            }

            // Diagnostic: warn if multiple libasan versions coexist on the system.
            // This is a common source of "cannot find -lasan" or silent ABI mismatches.
            try {
                auto asanProbe = executeShell("ls /usr/lib64/libasan.so.* /usr/lib/libasan.so.* 2>/dev/null | sort -V");
                if (asanProbe.status == 0) {
                    import std.array : split;
                    auto asanLibs = asanProbe.output.strip().split("\n");
                    // Filter empty entries
                    string[] foundLibs;
                    foreach (lib; asanLibs) {
                        string trimmed = lib.strip();
                        if (trimmed.length > 0) foundLibs ~= trimmed;
                    }

                    if (foundLibs.length > 1) {
                        writefln("\033[1;33m[DIAGNOSTIC]\033[0m Multiple AddressSanitizer runtimes detected on this system:");
                        foreach (lib; foundLibs) {
                            writefln("              %s", lib);
                        }
                        writefln("             \033[33mThis can cause linker conflicts or runtime ABI mismatches.\033[0m");
                        writefln("             \033[33mMerlin will use the compiler's bundled runtime (%s).\033[0m",
                            isClang ? "compiler-rt via -static-libsan" : "GCC libasan");
                        writefln("             \033[33mTo resolve: remove legacy ASan packages (e.g., `dnf remove compat-libasan1`).\033[0m\n");
                    }
                }
            } catch (Exception e) {}
        }
    }

    // Dynamic recursive scanning of project files (strictly portable targets!)
    string[] srcFiles;
    if (exists("src") && isDir("src")) {
        foreach (DirEntry entry; dirEntries("src", SpanMode.depth)) {
            if (entry.isFile && entry.name.endsWith(".c")) {
                srcFiles ~= entry.name;
            }
        }
    } else {
        foreach (DirEntry entry; dirEntries(".", SpanMode.depth)) {
            string base = baseName(entry.name);
            if (entry.name.canFind("/obj/") || entry.name.canFind("/bin/") || base.startsWith(".")) continue;
            if (entry.isFile && entry.name.endsWith(".c") && !entry.name.canFind("test")) {
                srcFiles ~= entry.name;
            }
        }
    }

    if (camelotHome.length > 0) {
        string camelotSrc = buildPath(camelotHome, "src");
        if (exists(camelotSrc) && isDir(camelotSrc)) {
            foreach (DirEntry entry; dirEntries(camelotSrc, SpanMode.depth)) {
                if (entry.isFile && entry.name.endsWith(".c")) {
                    srcFiles ~= entry.name;
                }
            }
        }
    }

    // Dynamic entry point detection (excludes int main during testing passes)
    string mainSrcFile = "";
    foreach (src; srcFiles) {
        try {
            if (readText(src).canFind("int main")) {
                mainSrcFile = src;
            }
        } catch (Exception e) {}
    }

    string[] objFiles;
    foreach (src; srcFiles) {
        if (testTarget && src == mainSrcFile) continue;

        string relPath;
        if (src.startsWith("src/")) relPath = src["src/".length .. $];
        else if (camelotHome.length > 0 && src.startsWith(buildPath(camelotHome, "src"))) relPath = "camelot_" ~ baseName(src);
        else relPath = baseName(src);

        string objPath = buildPath(objDir, relPath.setExtension(".o"));
        mkdirRecurse(dirName(objPath));

        writef("\033[1;36m[COMPILE]\033[0m Building \033[2m%s\033[0m -> %s\n", src, objPath);
        stdout.flush();

        auto cmd = [cc] ~ cflags ~ ["-c", src, "-o", objPath];
        auto pid = spawnProcess(cmd);
        if (wait(pid) != 0) {
            writefln("\n\033[1;31m[COMPILATION ERROR]\033[0m Failed to compile target source: %s\n" ~
                "                    Command: %s\n" ~
                "                    Please review the compiler diagnostics above.\n", src, cmd.join(" "));
            exit(1);
        }
        objFiles ~= objPath;
    }

    if (testTarget) {
        string[] testSrcs;
        string[] failSrcs;
        if (exists("tests") && isDir("tests")) {
            foreach (DirEntry entry; dirEntries("tests", SpanMode.depth)) {
                if (entry.isFile && entry.name.endsWith(".c")) {
                    if (entry.name.endsWith(".fail.c")) {
                        failSrcs ~= entry.name;
                    } else {
                        testSrcs ~= entry.name;
                    }
                }
            }
        } else {
            foreach (DirEntry entry; dirEntries(".", SpanMode.depth)) {
                string base = baseName(entry.name);
                if (entry.name.canFind("/obj/") || entry.name.canFind("/bin/") || base.startsWith(".")) continue;
                if (entry.isFile && entry.name.endsWith(".c") && entry.name.canFind("test")) {
                    if (entry.name.endsWith(".fail.c")) {
                        failSrcs ~= entry.name;
                    } else {
                        testSrcs ~= entry.name;
                    }
                }
            }
        }

        foreach (src; failSrcs) {
            writef("\033[1;35m[TEST COMPILE]\033[0m Building \033[2m%s\033[0m (Expecting Failure)...\n", src);
            stdout.flush();

            auto cmd = [cc] ~ cflags ~ ["-fsyntax-only", src];
            auto res = execute(cmd);
            if (res.status == 0) {
                writefln("\n\033[1;31m[TEST FAILURE]\033[0m Security guard bypassed! Negative test %s unexpectedly COMPILED SUCCESSFULLY.\n" ~
                    "               This means a banned function or syntax error was incorrectly ignored by the compiler.\n", src);
                exit(1);
            }
        }

        foreach (src; testSrcs) {
            string relPath = exists("tests") ? src["tests/".length .. $] : baseName(src);
            string objPath = buildPath(objDir, "tests", relPath.setExtension(".o"));
            mkdirRecurse(dirName(objPath));

            writef("\033[1;36m[TEST COMPILE]\033[0m Building \033[2m%s\033[0m -> %s\n", src, objPath);
            stdout.flush();

            auto cmd = [cc] ~ cflags ~ ["-c", src, "-o", objPath];
            auto pid = spawnProcess(cmd);
            if (wait(pid) != 0) {
                writefln("\n\033[1;31m[COMPILATION ERROR]\033[0m Failed to compile test source: %s\n" ~
                    "                    Command: %s\n" ~
                    "                    Please review the compiler diagnostics above.\n", src, cmd.join(" "));
                exit(1);
            }
            objFiles ~= objPath;
        }

        string testBin = buildPath("bin", "test_" ~ baseName(getcwd()));
        writefln("\033[1;34m[LINK]\033[0m Linking test runner: %s", testBin);
        stdout.flush();

        auto cmd = [cc] ~ objFiles ~ ["-o", testBin] ~ ldflags;
        auto pid = spawnProcess(cmd);
        if (wait(pid) != 0) {
            writefln("\n\033[1;31m[LINKER ERROR]\033[0m Failed to link test runner binary: %s\n" ~
                "               Command: %s\n" ~
                "               Review unresolved external symbols or missing objects.\n", testBin, cmd.join(" "));
            exit(1);
        }
    } else {
        string binPath = buildPath("bin", baseName(getcwd()));
        writefln("\033[1;34m[LINK]\033[0m Linking primary target: %s", binPath);
        stdout.flush();

        auto cmd = [cc] ~ objFiles ~ ["-o", binPath] ~ ldflags;
        auto pid = spawnProcess(cmd);
        if (wait(pid) != 0) {
            writefln("\n\033[1;31m[LINKER ERROR]\033[0m Failed to link primary target binary: %s\n" ~
                "               Command: %s\n" ~
                "               Review unresolved external symbols or missing objects.\n", binPath, cmd.join(" "));
            exit(1);
        }
    }
}

void cleanAll() {
    writefln("\033[1;33m[CLEAN] Removing all caches, object files, and binaries...\033[0m");
    if (exists("obj")) rmdirRecurse("obj");
    if (exists("bin")) rmdirRecurse("bin");
    writefln("\033[1;32m[CLEAN] Workspace cleaned successfully.\033[0m");
}

void runTests(bool release) {
    buildTarget(release, true);
    string testBin = buildPath("bin", "test_" ~ baseName(getcwd()));
    writefln("\n\033[1;36m[TEST] Initiating sanitizer testing check...\033[0m");
    writefln("\033[1;33m[RUN] Executing %s Test Suite...\033[0m\n", baseName(getcwd()));
    stdout.flush();

    auto pid = spawnProcess([testBin]);
    if (wait(pid) != 0) {
        writefln("\n\033[1;31m[RUNTIME ERROR]\033[0m Test suite failed during execution: %s\n" ~
            "                A sanitizer trap (ASan/UBSan/Leak) or assertion was triggered. Review the stack trace above.\n", testBin);
        exit(1);
    }
    writefln("\n\033[1;32m[TEST SUCCESS] All tests passed successfully.\033[0m\n");
}

void runTarget(bool release) {
    buildTarget(release, false);
    string binPath = buildPath("bin", baseName(getcwd()));
    writefln("\n\033[1;33m[RUN] Launching %s...\033[0m\n", baseName(getcwd()));
    stdout.flush();
    auto pid = spawnProcess([binPath]);
    wait(pid);
}

void initProject(string targetPath, string projectName) {
    if (!exists(targetPath)) {
        mkdirRecurse(targetPath);
    }
    
    mkdirRecurse(buildPath(targetPath, "src"));
    mkdirRecurse(buildPath(targetPath, "include"));
    mkdirRecurse(buildPath(targetPath, "tests"));
    
    string mainC = 
        "#include <stdio.h>\n\n" ~
        "int main(void) {\n" ~
        "    printf(\"Hello from " ~ projectName ~ "!\\n\");\n" ~
        "    return 0;\n" ~
        "}\n";
    std.file.write(buildPath(targetPath, "src", "main.c"), mainC);
    
    string testMainC = 
        "#include <stdio.h>\n\n" ~
        "int test_" ~ projectName ~ "(void) {\n" ~
        "    printf(\"Running tests for " ~ projectName ~ "...\\n\");\n" ~
        "    return 0;\n" ~
        "}\n";
    std.file.write(buildPath(targetPath, "tests", "test_main.c"), testMainC);
    
    string gitignore = 
        "obj/\n" ~
        "bin/\n" ~
        "*.o\n" ~
        "*.out\n" ~
        "*.exe\n" ~
        ".vscode/\n" ~
        ".zed/\n";
    std.file.write(buildPath(targetPath, ".gitignore"), gitignore);
    
    string camelotHome = environment.get("CAMELOT_HOME", "");
    string compileFlags = 
        "-Iinclude\n" ~
        "-Wall\n" ~
        "-Wextra\n" ~
        "-Wpedantic\n" ~
        "-Werror\n" ~
        "-std=c23\n";
    if (camelotHome.length > 0) {
        compileFlags ~= "-I" ~ buildPath(camelotHome, "include") ~ "\n";
    }
    std.file.write(buildPath(targetPath, "compile_flags.txt"), compileFlags);

    // VS Code tasks — Ctrl+Shift+B to build, command palette for test/run/clean
    mkdirRecurse(buildPath(targetPath, ".vscode"));
    string vscodeTasks =
        "{\n" ~
        "    \"version\": \"2.0.0\",\n" ~
        "    \"tasks\": [\n" ~
        "        {\n" ~
        "            \"label\": \"Build\",\n" ~
        "            \"type\": \"shell\",\n" ~
        "            \"command\": \"make all\",\n" ~
        "            \"group\": { \"kind\": \"build\", \"isDefault\": true },\n" ~
        "            \"problemMatcher\": \"$gcc\",\n" ~
        "            \"presentation\": { \"reveal\": \"always\", \"panel\": \"shared\", \"clear\": true },\n" ~
        "            \"detail\": \"Compile via Merlin (Debug)\"\n" ~
        "        },\n" ~
        "        {\n" ~
        "            \"label\": \"Build (Release)\",\n" ~
        "            \"type\": \"shell\",\n" ~
        "            \"command\": \"make all RELEASE=1\",\n" ~
        "            \"group\": \"build\",\n" ~
        "            \"problemMatcher\": \"$gcc\",\n" ~
        "            \"presentation\": { \"reveal\": \"always\", \"panel\": \"shared\", \"clear\": true },\n" ~
        "            \"detail\": \"Compile via Merlin (Release, hardened)\"\n" ~
        "        },\n" ~
        "        {\n" ~
        "            \"label\": \"Test\",\n" ~
        "            \"type\": \"shell\",\n" ~
        "            \"command\": \"make test\",\n" ~
        "            \"group\": { \"kind\": \"test\", \"isDefault\": true },\n" ~
        "            \"problemMatcher\": \"$gcc\",\n" ~
        "            \"presentation\": { \"reveal\": \"always\", \"panel\": \"shared\", \"clear\": true },\n" ~
        "            \"detail\": \"Build and run the sanitized test suite (ASan/UBSan)\"\n" ~
        "        },\n" ~
        "        {\n" ~
        "            \"label\": \"Run\",\n" ~
        "            \"type\": \"shell\",\n" ~
        "            \"command\": \"make run\",\n" ~
        "            \"group\": \"none\",\n" ~
        "            \"problemMatcher\": [],\n" ~
        "            \"presentation\": { \"reveal\": \"always\", \"panel\": \"shared\", \"clear\": true },\n" ~
        "            \"detail\": \"Build and launch the target executable\"\n" ~
        "        },\n" ~
        "        {\n" ~
        "            \"label\": \"Clean\",\n" ~
        "            \"type\": \"shell\",\n" ~
        "            \"command\": \"make clean\",\n" ~
        "            \"group\": \"none\",\n" ~
        "            \"problemMatcher\": [],\n" ~
        "            \"presentation\": { \"reveal\": \"always\", \"panel\": \"shared\", \"clear\": true },\n" ~
        "            \"detail\": \"Remove all build artifacts (bin/, obj/)\"\n" ~
        "        }\n" ~
        "    ]\n" ~
        "}\n";
    std.file.write(buildPath(targetPath, ".vscode", "tasks.json"), vscodeTasks);

    // Zed tasks — accessible via the Zed command palette
    mkdirRecurse(buildPath(targetPath, ".zed"));
    string zedTasks =
        "[\n" ~
        "    {\n" ~
        "        \"label\": \"Build\",\n" ~
        "        \"command\": \"make all\",\n" ~
        "        \"use_new_terminal\": false,\n" ~
        "        \"allow_concurrent_runs\": false,\n" ~
        "        \"reveal\": \"always\",\n" ~
        "        \"tags\": [\"build\"]\n" ~
        "    },\n" ~
        "    {\n" ~
        "        \"label\": \"Build (Release)\",\n" ~
        "        \"command\": \"make all RELEASE=1\",\n" ~
        "        \"use_new_terminal\": false,\n" ~
        "        \"allow_concurrent_runs\": false,\n" ~
        "        \"reveal\": \"always\",\n" ~
        "        \"tags\": [\"build\"]\n" ~
        "    },\n" ~
        "    {\n" ~
        "        \"label\": \"Test\",\n" ~
        "        \"command\": \"make test\",\n" ~
        "        \"use_new_terminal\": false,\n" ~
        "        \"allow_concurrent_runs\": false,\n" ~
        "        \"reveal\": \"always\",\n" ~
        "        \"tags\": [\"test\"]\n" ~
        "    },\n" ~
        "    {\n" ~
        "        \"label\": \"Run\",\n" ~
        "        \"command\": \"make run\",\n" ~
        "        \"use_new_terminal\": false,\n" ~
        "        \"allow_concurrent_runs\": false,\n" ~
        "        \"reveal\": \"always\"\n" ~
        "    },\n" ~
        "    {\n" ~
        "        \"label\": \"Clean\",\n" ~
        "        \"command\": \"make clean\",\n" ~
        "        \"use_new_terminal\": false,\n" ~
        "        \"allow_concurrent_runs\": false,\n" ~
        "        \"reveal\": \"always\"\n" ~
        "    }\n" ~
        "]\n";
    std.file.write(buildPath(targetPath, ".zed", "tasks.json"), zedTasks);

    writefln("\033[1;32m[INIT] Created project '%s' at '%s'\033[0m", projectName, targetPath.length > 0 && targetPath != "." ? targetPath : getcwd());
}
