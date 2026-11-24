// Tudo que vem de C, traduzido de uma vez para o módulo Zig `c`. O app pode trocar pelo
// dele (`addImport("c", …)` no módulo `larperkit`), desde que tenha o que está aqui.
#include <SDL3/SDL.h>
#include "dcimgui.h"
#include "dcimgui_impl_sdl3.h"
#include "dcimgui_impl_sdlrenderer3.h"
#ifdef _WIN32
#include <windows.h>
#include <shellapi.h>
#include <shlobj.h>
#include <fcntl.h>
#include <io.h>
#include <direct.h>
#include <process.h>
#include <dirent.h>
#else
#include <fcntl.h>
#include <sys/inotify.h>
#include <sys/file.h>
#include <unistd.h>
#include <dirent.h>
#endif
#include <stdio.h>
#include <sys/stat.h>
