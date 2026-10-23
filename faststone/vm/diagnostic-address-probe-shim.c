/* Diagnostic only: reject impossible high hints on this 48-bit QEMU guest.
 * Older build headers use an mmap fallback which reports a moved mapping as
 * EEXIST; Wine 11.20's address-limit probe mistakes this for a valid address.
 */
#define _GNU_SOURCE
#include <sys/mman.h>
#include <sys/syscall.h>
#include <unistd.h>
#include <stdint.h>
#include <errno.h>
void *mmap(void *p,size_t n,int prot,int flags,int fd,off_t off)
{
 if ((uintptr_t)p >= 0x800000000000ULL && !(flags & MAP_FIXED)) { errno=ENOMEM;return MAP_FAILED; }
 return (void *)syscall(SYS_mmap,p,n,prot,flags,fd,off);
}
