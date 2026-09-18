// Same trampolines as package syscall on redox: the runtime exports
// syscall_sysvicall6 / syscall_rawsysvicall6 with a bare //go:linkname.

//go:build redox && amd64

#include "textflag.h"

TEXT ·sysvicall6(SB),NOSPLIT,$0
	JMP	runtime·syscall_sysvicall6(SB)

TEXT ·rawSysvicall6(SB),NOSPLIT,$0
	JMP	runtime·syscall_rawsysvicall6(SB)
