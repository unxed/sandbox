# Far Manager imports vs HX

Far 3.0.6745.5025 x86 (FarGroup/FarManager release ci/v3.0.6745.5025) against HX `master` f2276db; run https://github.com/unxed/sandbox/actions/runs/39606631175. DPMILD32 starts a program with missing functions if `DPMILDR=128` is set (`ENVFL_IGNUNRESIMP`; a call of such a function stops the program with "unresolved import called"); a missing DLL still stops the load.

| file | subsystem | OS version | |
|---|---|---|---|
| Far.exe | subsystem 3, 5.0 | OS 5.0 |  |
| Legacy/lua51.dll | subsystem 3, 4.0 | OS 4.0 |  |
| Plugins/Align/Align.dll | subsystem 3, 6.0 | OS 6.0 |  |
| Plugins/AutoWrap/AutoWrap.dll | subsystem 3, 6.0 | OS 6.0 |  |
| Plugins/Brackets/Brackets.dll | subsystem 3, 6.0 | OS 6.0 |  |
| Plugins/Compare/Compare.dll | subsystem 3, 6.0 | OS 6.0 |  |
| Plugins/DrawLine/DrawLine.dll | subsystem 3, 6.0 | OS 6.0 |  |
| Plugins/EMenu/EMenu.dll | subsystem 3, 6.0 | OS 6.0 |  |
| Plugins/EditCase/EditCase.dll | subsystem 3, 6.0 | OS 6.0 |  |
| Plugins/FarCmds/FarCmds.dll | subsystem 3, 6.0 | OS 6.0 |  |
| Plugins/FarColorer/bin/colorer.dll | subsystem 2, 6.0 | OS 6.0 |  |
| Plugins/FileCase/FileCase.dll | subsystem 3, 6.0 | OS 6.0 |  |
| Plugins/HlfViewer/HlfViewer.dll | subsystem 3, 6.0 | OS 6.0 |  |
| Plugins/LuaMacro/LuaMacro.dll | subsystem 3, 6.0 | OS 6.0 |  |
| Plugins/NetBox/NetBox.dll | subsystem 2, 5.1 | OS 5.1 | delay imports |
| Plugins/Network/Network.dll | subsystem 3, 6.0 | OS 6.0 |  |
| Plugins/ProcList/ProcList.dll | subsystem 3, 6.0 | OS 6.0 |  |
| Plugins/SameFolder/SameFolder.dll | subsystem 3, 6.0 | OS 6.0 |  |
| Plugins/TmpPanel/TmpPanel.dll | subsystem 3, 6.0 | OS 6.0 |  |
| Plugins/arclite/7z.dll | subsystem 2, 4.0 | OS 4.0 |  |
| Plugins/arclite/arclite.dll | subsystem 3, 6.0 | OS 6.0 |  |
| lua51.dll | subsystem 3, 4.0 | OS 4.0 |  |
| luafar3.dll | subsystem 3, 6.0 | OS 6.0 |  |
| sqlite3.dll | subsystem 3, 6.0 | OS 6.0 |  |

## DLLs that HX does not have

- `bcrypt.dll`: Plugins/FarColorer/bin/colorer.dll
- `crypt32.dll`: Plugins/NetBox/NetBox.dll (delay)
- `imm32.dll`: Far.exe
- `msvcrt.dll`: Legacy/lua51.dll, Plugins/arclite/7z.dll, lua51.dll
- `netapi32.dll`: Far.exe, Plugins/Network/Network.dll
- `psapi.dll`: Far.exe, Plugins/ProcList/ProcList.dll
- `rpcrt4.dll`: Far.exe, Plugins/FarCmds/FarCmds.dll, Plugins/HlfViewer/HlfViewer.dll, luafar3.dll
- `secur32.dll`: Far.exe, Plugins/NetBox/NetBox.dll
- `setupapi.dll`: Far.exe
- `shlwapi.dll`: Plugins/NetBox/NetBox.dll (delay)
- `userenv.dll`: Far.exe
- `winspool.drv`: Far.exe

## Functions missing from HX DLLs

### COMDLG32 (1 missing)

- `ChooseColorW`: Far.exe

### DADVAPI (13 missing)

- `CheckTokenMembership`: Far.exe
- `ConvertSecurityDescriptorToStringSecurityDescriptorW`: Plugins/arclite/arclite.dll
- `ConvertSidToStringSidW`: Far.exe, Plugins/ProcList/ProcList.dll
- `ConvertStringSidToSidW`: Far.exe
- `DecryptFileW`: Far.exe
- `EncryptFileW`: Far.exe
- `GetNamedSecurityInfoW`: Far.exe
- `IsTextUnicode`: Far.exe, Plugins/FarCmds/FarCmds.dll, Plugins/TmpPanel/TmpPanel.dll
- `LookupPrivilegeValueW`: Far.exe, Plugins/ProcList/ProcList.dll
- `PrivilegeCheck`: Far.exe
- `RegConnectRegistryW`: Plugins/ProcList/ProcList.dll
- `SetNamedSecurityInfoW`: Far.exe
- `SetSecurityInfo`: Far.exe

### DKRNL32 (77 missing)

- `AcquireSRWLockExclusive`: Plugins/FarColorer/bin/colorer.dll
- `AcquireSRWLockShared`: Plugins/FarColorer/bin/colorer.dll
- `AddConsoleAliasW`: Far.exe
- `AssignProcessToJobObject`: Far.exe
- `BeginUpdateResourceW`: Plugins/arclite/arclite.dll
- `ChangeTimerQueueTimer`: luafar3.dll
- `CompareStringEx`: Plugins/FarColorer/bin/colorer.dll
- `CopyFileExW`: Far.exe
- `CreateHardLinkW`: Far.exe
- `CreateJobObjectW`: Far.exe
- `CreateNamedPipeW`: Far.exe, Plugins/NetBox/NetBox.dll
- `CreateTimerQueue`: Plugins/FarColorer/bin/colorer.dll, luafar3.dll
- `CreateTimerQueueTimer`: Far.exe, Plugins/FarColorer/bin/colorer.dll, luafar3.dll
- `DefineDosDeviceW`: Far.exe
- `DeleteTimerQueue`: Plugins/FarColorer/bin/colorer.dll
- `DeleteTimerQueueEx`: luafar3.dll
- `DeleteTimerQueueTimer`: Far.exe, Plugins/FarColorer/bin/colorer.dll, luafar3.dll
- `EndUpdateResourceW`: Plugins/arclite/arclite.dll
- `EnumResourceLanguagesW`: Plugins/arclite/arclite.dll
- `EnumResourceNamesW`: Plugins/arclite/arclite.dll
- `EnumSystemCodePagesW`: Far.exe, luafar3.dll
- `FindFirstChangeNotificationW`: Plugins/NetBox/NetBox.dll
- `FindFirstVolumeW`: Far.exe
- `FindNextVolumeW`: Far.exe
- `FindVolumeClose`: Far.exe
- `FlsAlloc`: Plugins/FarColorer/bin/colorer.dll
- `FlsFree`: Plugins/FarColorer/bin/colorer.dll
- `FlsGetValue`: Plugins/FarColorer/bin/colorer.dll
- `FlsSetValue`: Plugins/FarColorer/bin/colorer.dll
- `FoldStringW`: Far.exe
- `GetCPInfoExW`: Far.exe, Plugins/NetBox/NetBox.dll, luafar3.dll
- `GetCalendarInfoW`: Far.exe
- `GetCompressedFileSizeW`: Far.exe
- `GetComputerNameExW`: Far.exe
- `GetConsoleAliasExesLengthW`: Far.exe
- `GetConsoleAliasExesW`: Far.exe
- `GetConsoleAliasW`: Far.exe
- `GetConsoleAliasesLengthW`: Far.exe, Plugins/FarCmds/FarCmds.dll
- `GetConsoleAliasesW`: Far.exe, Plugins/FarCmds/FarCmds.dll
- `GetConsoleDisplayMode`: Far.exe
- `GetConsoleFontSize`: Far.exe
- `GetConsoleWindow`: Far.exe, Plugins/FarCmds/FarCmds.dll, Plugins/TmpPanel/TmpPanel.dll
- `GetCurrentConsoleFont`: Far.exe
- `GetFileInformationByHandleEx`: Plugins/FarColorer/bin/colorer.dll
- `GetLocaleInfoEx`: Plugins/FarColorer/bin/colorer.dll
- `GetLogicalDriveStringsW`: luafar3.dll
- `GetPrivateProfileIntW`: Far.exe
- `GetProcessHeaps`: Far.exe
- `GetSystemPowerStatus`: Far.exe
- `GetVolumeNameForVolumeMountPointW`: Far.exe
- `GlobalMemoryStatusEx`: Far.exe, Plugins/arclite/arclite.dll, luafar3.dll
- `HeapQueryInformation`: Far.exe
- `InitOnceBeginInitialize`: Plugins/FarColorer/bin/colorer.dll
- `InitOnceComplete`: Plugins/FarColorer/bin/colorer.dll
- `InitOnceExecuteOnce`: Plugins/FarColorer/bin/colorer.dll
- `InitializeCriticalSectionEx`: Plugins/FarColorer/bin/colorer.dll
- `InterlockedFlushSList`: Plugins/FarColorer/bin/colorer.dll
- `LCMapStringEx`: Plugins/FarColorer/bin/colorer.dll
- `OpenThread`: Far.exe
- `QueryDosDeviceW`: Far.exe
- `ReadDirectoryChangesW`: Far.exe
- `RegisterWaitForSingleObject`: Plugins/FarColorer/bin/colorer.dll
- `ReleaseSRWLockExclusive`: Plugins/FarColorer/bin/colorer.dll
- `ReleaseSRWLockShared`: Plugins/FarColorer/bin/colorer.dll
- `ReplaceFileW`: Far.exe, luafar3.dll
- `SetInformationJobObject`: Far.exe
- `SetThreadExecutionState`: Far.exe, Plugins/arclite/arclite.dll
- `SetVolumeLabelW`: Far.exe
- `SetVolumeMountPointW`: Far.exe
- `SleepConditionVariableSRW`: Plugins/FarColorer/bin/colorer.dll
- `TryAcquireSRWLockExclusive`: Plugins/FarColorer/bin/colorer.dll
- `UnregisterWait`: Plugins/FarColorer/bin/colorer.dll
- `UpdateResourceW`: Plugins/arclite/arclite.dll
- `VerSetConditionMask`: Far.exe, Plugins/EMenu/EMenu.dll, Plugins/NetBox/NetBox.dll, luafar3.dll
- `VerifyVersionInfoW`: Far.exe, Plugins/EMenu/EMenu.dll, Plugins/NetBox/NetBox.dll, luafar3.dll
- `WaitNamedPipeW`: Far.exe
- `WakeAllConditionVariable`: Plugins/FarColorer/bin/colorer.dll

### DUSER32 (12 missing)

- `CreateDialogParamW`: Plugins/EMenu/EMenu.dll
- `FlashWindowEx`: Far.exe
- `GetGuiResources`: Plugins/ProcList/ProcList.dll
- `GetMenuItemInfoW`: Plugins/EMenu/EMenu.dll
- `GetMenuStringW`: Plugins/EMenu/EMenu.dll
- `GetMonitorInfoW`: Far.exe
- `LoadImageW`: Far.exe
- `MapVirtualKeyExW`: Far.exe
- `MonitorFromWindow`: Far.exe
- `RegisterClipboardFormatW`: Far.exe
- `ToUnicodeEx`: Far.exe
- `VkKeyScanExW`: Far.exe

### MPR (4 missing)

- `WNetEnumResourceW`: Far.exe, Plugins/Network/Network.dll
- `WNetGetResourceInformationW`: Plugins/Network/Network.dll
- `WNetGetResourceParentW`: Plugins/Network/Network.dll
- `WNetOpenEnumW`: Far.exe, Plugins/Network/Network.dll

### OLE32 (4 missing)

- `CoSetProxyBlanket`: Plugins/ProcList/ProcList.dll
- `CreateFileMoniker`: Far.exe
- `PropVariantClear`: Plugins/arclite/arclite.dll
- `PropVariantCopy`: Plugins/arclite/arclite.dll

### SHELL32 (3 missing)

- `SHFileOperationW`: Far.exe, Plugins/NetBox/NetBox.dll
- `ShellExecuteExW`: Far.exe, Plugins/NetBox/NetBox.dll
- `ShellExecuteW`: Plugins/TmpPanel/TmpPanel.dll, luafar3.dll

### WS2_32 (4 missing)

- `WSASend`: Plugins/NetBox/NetBox.dll (delay)
- `freeaddrinfo`: Plugins/NetBox/NetBox.dll (delay)
- `getaddrinfo`: Plugins/NetBox/NetBox.dll (delay)
- `getnameinfo`: Plugins/NetBox/NetBox.dll (delay)


Total: 118 missing functions in 8 HX DLLs, 12 DLLs without an HX counterpart.
