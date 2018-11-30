// Copyright(c) 2017 POLYGONTEK
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
// http ://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include "Precompiled.h"
#include "Core/Object.h"
#include "Input/KeyCmd.h"
#include "Input/InputSystem.h"
#include "Engine/Engine.h"
#include "Engine/GameClient.h"
#include "Engine/Console.h"
#include "Engine/Common.h"
#include "Platform/PlatformProcess.h"
#include "Simd/Simd.h"
#include "Core/StrColor.h"
#include "Core/CVars.h"
#include "Core/Cmds.h"
#include "File/FileSystem.h"
#include "Game/GameSettings.h"

BE_NAMESPACE_BEGIN

static CVAR(developer, "0", CVar::Bool, "");
static CVAR(logFile, "0", CVar::Bool, "");
static CVAR(forceGenericSIMD, "0", CVar::Bool, "");

static File *   consoleLogFile;

Common          common;

static void Common_Log(const int logLevel, const char *msg) {
    char buffer[16384];
    const char *bufptr;

    if (logLevel == DevLog && !developer.GetBool()) {
        return;
    }
    
    if (logLevel == DevLog) {
        Str::snPrintf(buffer, COUNT_OF(buffer), S_COLOR_CYAN "%s", msg);
        bufptr = buffer;
    } else if (logLevel == WarningLog) {
        Str::snPrintf(buffer, COUNT_OF(buffer), S_COLOR_YELLOW "WARNING: %s", msg);
        bufptr = buffer;
    } else if (logLevel == ErrorLog) {
        Str::snPrintf(buffer, COUNT_OF(buffer), S_COLOR_RED "ERROR: %s", msg);
        bufptr = buffer;
    } else {
        bufptr = msg;
    }

    if (logFile.GetBool()) {
        if (!consoleLogFile) {
            consoleLogFile = fileSystem.OpenFile("console.log", File::WriteMode);
            if (consoleLogFile) {
                time_t t;
                time(&t);
                tm *local_time = localtime(&t);
                BE_LOG("logFile opened on %s\n", asctime(local_time));
            } else {
                logFile.SetBool(false);
                BE_WARNLOG("Can't open the log file\n");
            }
        } else {
            consoleLogFile->Write(bufptr, strlen(bufptr));
        }
    }

    platform->Log(bufptr); //
    
    console.Print(bufptr);
}

static void Common_Error(const int errLevel, const char *msg) {
    static bool errorEntered = false;

    if (errLevel == FatalErr) {
        if (errorEntered) {
            platform->Error(va("Recursive error after: %s", msg));
        }

        errorEntered = true;

        if (consoleLogFile) {
            fileSystem.CloseFile(consoleLogFile);
        }

        cmdSystem.BufferCommandText(CmdSystem::ExecuteNow, "condump \"Log/log\"\n");

        //common.Shutdown();

        platform->Error(msg);
    }
}

void Common::Init(const char *baseDir) {
    Engine::InitBase(baseDir, forceGenericSIMD.GetBool(), (const streamOutFunc_t)Common_Log, (const streamOutFunc_t)Common_Error);

    EventSystem::Init();
    
    SignalSystem::Init();
    
    Object::Init();
    
    console.Init();

    keyCmdSystem.Init();

    cmdSystem.AddCommand("version", Cmd_Version);
    cmdSystem.AddCommand("error", Cmd_Error);
    cmdSystem.AddCommand("quit", Cmd_Quit);

    cmdSystem.BufferCommandText(CmdSystem::ExecuteNow, "exec \"Config/config.cfg\"\n");
    cvarSystem.ClearModified();

    random.SetSeed(0);

    srand((unsigned int)time(nullptr));

    realTime = 0;
    frameTime = 0;
    frameSec = 0;
}

void Common::Shutdown() {
    cmdSystem.BufferCommandText(CmdSystem::ExecuteNow, "condump \"Log/log\"\n");

    SaveConfig("Config/config.cfg");

    cmdSystem.RemoveCommand("version");
    cmdSystem.RemoveCommand("quit");
    cmdSystem.RemoveCommand("error");

    keyCmdSystem.Shutdown();

    console.Shutdown();

    Object::Shutdown();

    EventSystem::Shutdown();
    
    SignalSystem::Shutdown();

    Engine::ShutdownBase();
}

void Common::SaveConfig(const char *filename) {
    Str configFilename = filename;
    configFilename.DefaultFileExtension("cfg");

    File *file = fileSystem.OpenFile(configFilename, File::WriteMode);
    if (file) {
        file->Printf("unbindall\n");
        keyCmdSystem.WriteBindings(file);
        cvarSystem.WriteVariables(file);
        fileSystem.CloseFile(file);
    }
}

void Common::RunFrame(int frameMsec) {
    frameTime = frameMsec;
    frameSec = MS2SEC(frameMsec);
    realTime += frameMsec;

    ProcessPlatformEvent();

    cmdSystem.ExecuteCommandBuffer();
}

Common::PlatformId Common::GetPlatformId() const {
#if defined(__IOS__)
    return PlatformId::IOSPlatform;
#elif defined(__ANDROID__)
    return PlatformId::AndroidPlatform;
#elif defined(__WIN32__)
    return PlatformId::WindowsPlatform;
#elif defined(__MACOSX__)
    return PlatformId::MacOSPlatform;
#elif defined(__LINUX__)
    return PlatformId::LinuxPlatform;
#endif
}

Str Common::GetAppPreferenceDir() const {
    Str companyName = GameSettings::playerSettings->GetProperty("companyName").As<Str>();
    Str productName = GameSettings::playerSettings->GetProperty("productName").As<Str>();
    return fileSystem.GetAppDataDir(companyName, productName);
}

int Common::ProcessPlatformEvent() {
    Platform::Event	ev;

    platform->GenerateMouseDeltaEvent();

    while (1) {
        GetPlatformEvent(&ev);

        if (ev.type == Platform::NoEvent) {
            break;
        }

        switch (ev.type) {
        case Platform::KeyEvent:
            gameClient.KeyEvent((KeyCode::Enum)ev.value, ev.value2 ? true : false);
            break;
        case Platform::CharEvent:
            gameClient.CharEvent((char32_t)ev.value);
            break;
        case Platform::CompositionEvent:
            gameClient.CompositionEvent((char32_t)ev.value);
            break;
        case Platform::MouseDeltaEvent:
            gameClient.MouseDeltaEvent((int)ev.value, (int)ev.value2, ev.time);
            break;
        case Platform::MouseMoveEvent:
            gameClient.MouseMoveEvent((int)ev.value, (int)ev.value2, ev.time);
            break;
        case Platform::JoyAxisEvent:
            gameClient.JoyAxisEvent((int)ev.value, (int)ev.value2, ev.time);
            break;
        case Platform::TouchBeganEvent:
            gameClient.TouchEvent(InputSystem::Touch::Started, ev.value, LowDWord(ev.value2), HighDWord(ev.value2), ev.time);
            break;
        case Platform::TouchMovedEvent:
            gameClient.TouchEvent(InputSystem::Touch::Moved, ev.value, LowDWord(ev.value2), HighDWord(ev.value2), ev.time);
            break;
        case Platform::TouchEndedEvent:
            gameClient.TouchEvent(InputSystem::Touch::Ended, ev.value, LowDWord(ev.value2), HighDWord(ev.value2), ev.time);
            break;
        case Platform::TouchCanceledEvent:
            gameClient.TouchEvent(InputSystem::Touch::Canceled, ev.value, 0, 0, ev.time);
            break;
        case Platform::ConsoleEvent:
            cmdSystem.BufferCommandText(CmdSystem::Append, (const char *)ev.ptr);
            cmdSystem.BufferCommandText(CmdSystem::Append, "\n");
            break;
        case Platform::PacketEvent:
            break;
        default:
            BE_FATALERROR("Common::ProcessPlatformEvent: bad event type %i", ev.type);
        }

        if (ev.ptr) {
            Mem_Free(ev.ptr);
        }
    }

    return ev.time;
}

void Common::GetPlatformEvent(Platform::Event *ev) {
    platform->GetEvent(ev);
}

void Common::Cmd_Version(const CmdArgs &args) {
    BE_LOG("%s-%s %s %s %s\n", BE_NAME, PlatformProcess::PlatformName(),
        BE_VERSION, __DATE__, __TIME__);
}

void Common::Cmd_Error(const CmdArgs &args) {
    if (args.Argv(1)) {
        BE_FATALERROR("%s", args.Argv(1));
    }
}

void Common::Cmd_Quit(const CmdArgs &args) {
    gameClient.Shutdown();
    common.Shutdown();
    exit(0);
}

BE_NAMESPACE_END
