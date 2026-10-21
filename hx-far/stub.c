/* Empty stand-in for a system DLL that HX does not have (imm32, psapi, ...).
   It exports one dummy function only, so every import from it stays
   unresolved; with DPMILDR=128 the HX loader starts the program anyway and
   stops it only if such a function is really called. */
__declspec(dllexport) int HxStubDummy(void) { return 0; }

int __stdcall DllMainCRTStartup(void *inst, unsigned long reason, void *res)
{
    (void)inst; (void)reason; (void)res;
    return 1;
}
