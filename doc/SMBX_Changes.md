Mac OS X 10.10.5 SMB Client Integration Notes
=============================================

Author: Jake Hamby<br>
Date:   28 Jun 2023

Goals:
------

 * Add support for SMB 2 and SMB 3 protocols and features.
 * Add support for direct TCP connections on port 445.
 * Remove support for NetBEUI and for "pre-NTLM" SMB 1 servers.
 * Add support for encrypted and signed packets.
 * Add async read-ahead and write-behind caching for performance.
 * Improve mapping between UTF-16 and RISC OS filenames.
 * Add support for DNS and mDNS (Bonjour) server discovery.
 * Add support for MS-RPC-based share and printer enumeration.
 * Support Kerberos authentication (Active Directory).
 * Improve error messages and error handling.

Additional License Text:
------------------------

Please note that binary distributions of this client now require that
`Copyright (c) 2000-2001, Boris Popov` plus the rest of the "4-clause BSD
license" be included somewhere in an open source acknowledgements file(s).
This text was also added to the LICENSE file in the parent directory.

Additionally, code from LibreSSL has been included with the requirement
to include `This product includes cryptographic software written by
Eric Young (eay@cryptsoft.com)` in the open source acknowledgements.
This text was also added to the LICENSE file in the parent directory.

The APPLE_LICENSE text from Apple's source archives was added to "doc".
It applies to the source files that Apple didn't import from NetBSD,
and doesn't add any requirements related to binary distributions.


Code import notes:
------------------

Original OS X 10.10.5 code archives (the final release of the SMB client):

 - `smb-smb-759.40.1`
 - `xnu-xnu-2782.40.9`

Apple's corecrypto libraries aren't available under a suitable open-source
license, so calls to code from **[LibreSSL](https://www.libressl.org/)**
3.7.3 (latest stable release) have been substituted in `smb_crypt.c`.

MD4 and MD5 source files were updated with the latest FreeBSD versions
of the RSA reference source code.

Individual source files were copied into the "c" and "h" directories,
with tabs expanded to 4 spaces. Apple's code will be referred to as
"SmbX", and the kernel as "xnu".

The handlers in `c/Omni` and `c/CoreFn` map closely to `smbfs_vfsops.c`
and `smbfs_vnops.c`, but the SmbX files implement many more features
than RISC OS requires, so some unused sections of code may be removed
from `smbfs_vfsops.c` and `smbfs_vnops.c` in the future for clarity.

For simplicity, `vnode_t` will be defined as a `struct smbnode`, making
`VTOSMB()` a no-op, and `struct mount` is also `struct smbmount`.

Apple's original code includes a user-mode `SMBClient` framework and an
ioctl interface to direct the kernel module to mount and dismount
filesystems and other functions. These correspond to some of the
SWI interfaces handled in `c/Omni` and will be passed through directly.


System variables:
-----------------

 - `LanMan$Abc` - TODO
 - `LanMan$Abc` - TODO
 - `LanMan$Abc` - TODO


Limits and tuneable parameters:
------------------------------

 - `MAX_SERVERS` = 64 (table of pointers)
 - `MAX_FILES` = 250 (size of active files table)
 - `SMB_MAXSHARENAMELEN` = 240 (max share name length in bytes)
 - `FREE_AFTER_CLOSE` = 30 (seconds before closed files are freed)


Deleted files:
--------------

 - `c/Attr` and `h/Attr`
 - `c/Auth` and `h/Auth`
 - `c/LLC` and `h/LLC`
 - `c/NBIP` and `h/NBIP`
 - `c/NetBIOS` and `h/NetBIOS`
 - `c/Transact` and `h/Transact`


New header files:
-----------------

 - `(xnu)/bsd/machine/byte_order.h -> h/smb_byte_order`
    - Conversion to/from little-endian and big-endian byte orders
 - `kernel/mysys/sys/smb_apple.h -> h/smb_riscos`
    - OS-specific definitions for kernel malloc, etc.
 - `kernel/netsmb/smb.h -> h/smb_smb`
    - Common definitions and structures for SMB/CIFS protocol
 - `kernel/netsmb/smb_subr.h -> h/smb_subr`
    - Definitions for debug, string conversion, locking, etc.
 - `kernel/netsmb/smb_tran.h -> h/smb_tran`
    - Function interface for SMB transports (i.e. NetBIOS)
 - `kernel/netsmb/smb_trantcp.h -> h/smb_trantcp`
    - Definitions for NetBIOS-over-TCP/IP transport
 - `kernel/sys5/sys/mchain.h -> h/mchain`
    - Definitions for mbuf chain functions
 - `kernel/sys5/sys/msfscc.h -> h/msfscc`
    - MS-FSCC: Microsoft File System Control Codes
 - `kernel/smbfs/smbfs.h -> h/smbfs`
    - Definitions for SMB filesystem interface
 - `kernel/smbfs/smbfs_node.h -> h/smbfs_node`
    - Definitions for SMB file and directory operations
 - `kernel/smbfs/smbfs_subr.h -> h/smbfs_subr`
    - Definitions for SMB subroutines


New source files:
-----------------

 - `kernel/netsmb/smb_subr.c -> c/smb_subr`
   - Mapping of NTSTATUS errors to LanManErr codes, other funcs
 - `kernel/smbfs/smbfs_io.c -> c/smbfs_io`
   - Do read, do write, zero fill, etc..
 - `kernel/sys5/kern/subr_mchain.c -> c/subr_mchain`
   - Mbuf chain functions


Kernel source files not copied:
-------------------------------

 - `kernel/netsmb/smb_dev.c`
 - `kernel/netsmb/smb_dev.h`
 - `kernel/netsmb/smb_dev_2.h`
 - `kernel/netsmb/smb_sleephandler.cpp`
 - `kernel/netsmb/smb_sleephandler.h`
 - `kernel/netsmb/smb_usr.c`
 - `kernel/netsmb/smb_usr_2.c`


Mbufs memory manager:
---------------------

The Mbuf manager is a RISC OS implementation of the BSD mbuf
memory allocator, which is optimized for speed for short-lived,
small allocations, such as network packet headers.

SmbX includes some utility functions for chains of mbufs, called
`struct mbchain` and `struct mdchain`, with pointer typedefs
`mbchain_t` and `mdchain_t`. The difference between them is
`mbchain_t` has members to hold a byte count and free space in
the current mbuf, for composing requests, while `mdchain_t` has
a `u_char *` to an offset in `md_cur`, for parsing replies. There
are methods to write to an `mbchain_t` in either byte order, and
to read from an `mdchain_t` in either byte order.

The BSD subsystem of the xnu kernel allows the SMB client to
call internal socket functions to send and receive mbufs. RISC OS
has socket variants of `readv` and `writev` that take `iovec` arrays.
The encryption and decryption routines operate on mbuf chains in place,
so encryption doesn't increase the mbuf demands. However, if encryption
or decryption fails, the mbuf chain is deleted.

Because the transport receive code never requests more than 8 KB at once,
it's possible to set up the socket iovec on the stack with an array of
a maximum of 8 items, which happens to be the same as `UIO_SMALLIOV`, the
max number of iovecs that the TCP/IP library can handle in the same way
(without calling malloc). By implementing an equivalent to the xnu socket
calls that send/receive mbufs, the number of memcpys is reduced.

For sending large mbuf chains, `socketwritev` will be called on up to
8 mbufs of data at a time, to avoid the additional malloc requirement
when the number of iovec entries is higher than `UIO_SMALLIOV`. The
maximum request size can be decreased if it turns out that large write
messages are exhausting the mbuf memory area or other system resources.


Data structures:
----------------

 - global array of pointers to mount data
    - (which SmbX structs map to a Mount op?)

 - `struct smb_share`
 - `struct smb_vc`
 - `struct smbnode`
    - `struct smb_open_dir`
    - `struct smb_open_file`
 - `SMBFID`
 - `struct smb_rq`
 - `struct smbiod`
 - `struct smb_t2rq`
 - `struct smb_ntrq`
 - `struct smb_connobj`
 - `vfs_context_t`


Reentrancy and locking:
-----------------------

 - `lck_rw_alloc_init / lck_rw_init / lck_rw_destroy`
    - `lck_rw_lock_shared / lck_rw_unlock_shared`
    - `lck_rw_lock_exclusive / lck_rw_unlock_exclusive`
 - `lck_mtx_alloc_init / lck_mtx_free / lck_mtx_destroy`
    - `lck_mtx_lock / lck_mtx_unlock`


RISC OS SWI -> SmbX function mapping:
-------------------------------------

Module load, unload, and shutdown:

 - Module has to register with Omni client and FileSwitch.
 - Module has to load and unload Mbuf manager.
 - Module has to unmount and close shares on shutdown.

Handlers for LanMan_OmniOp SWI and * commands:

```
Mount
  In:
    R0 = 0
    R1 = server name (char *)
    R2 = username (char *)
    R3 = password (char *)
    R4 = share name (char *)
    R5 = mount path (char *)
  Out:
    R1 = mount ID, or 0 for error
  RISC OS entry:
    - Omni_MountServer
  SmbX entry:
    - SMBOpenServerEx
    - SMBMountShareEx
    - SMBReleaseServer
  SmbX subroutines:
    - SMBServerConnect
    - SMBPasswordPrompt
    - smb_connect
    - smb_share_connect
    - SMBServerContext
    - smb_open_session
    - smb_ctx_setshare
    - smb_mount
    - smb_resolve
    - smb_negotiate

Dismount
  In:
    R0 = 1
    R1 = mount ID from mount op
  Out:
  RISC OS entry:
    - Omni_DismountServer
  SmbX entry:
  SmbX subroutines:

Free space (64-bit version in Omni_FreeOp_SWI)
  In:
    R0 = 2
    R1 = mount ID
  Out:
    R1 = free space in bytes
    R2 = used space in bytes
    R3 = total space in bytes
  RISC OS entry:
    - Omni_FreeSpace
  SmbX entry:
  SmbX subroutines:

Enumerate servers
  In:
    R0 = 3
    R1 = pointer to output buffer
    R2 = output buffer size
    R3 = continuation token, or 0
  Out:
    R1 = pointer to last byte written plus one
    R3 = token to return more entries
  RISC OS entry:
    - Omni_ListServers
  SmbX entry:
  SmbX subroutines:

Enumerate mounts
  In:
    R0 = 4
    R1 = pointer to output buffer
    R2 = output buffer size
    R3 = continuation token, or 0
    R4 = server ID
    R5 = server name (char *)
  Out:
    R1 = pointer to last byte written plus one
    R3 = token to return more entries
  RISC OS entry:
    - Omni_ListMounts
  SmbX entry:
  SmbX subroutines:

Enumerate active mounts
  In:
    R0 = 5
    R1 = pointer to output buffer
    R2 = output buffer size
    R3 = continuation token, or 0
  Out:
    R1 = pointer to last byte written plus one
    R3 = token to return more entries
  RISC OS entry:
    - Omni_ListActiveMounts
  SmbX entry:
  SmbX subroutines:

Open root of mount
  In:
    R0 = 6
    R1 = mount ID
  Out:
  RISC OS entry:
    - Omni_OpenRoot
  SmbX entry:
  SmbX subroutines:

Open user root of mount
  In:
    R0 = 7
    R1 = mount ID
  Out:
  RISC OS entry:
    - Omni_OpenUserRoot
  SmbX entry:
  SmbX subroutines:

Get new mount info
  In:
    R0 = 8
    R1 =
    R2 =
  Out:
    R1 =
  RISC OS entry:
    - Omni_GetNewMountInfo
  SmbX entry:
  SmbX subroutines:

Get active mount info
  In:
    R0 = 9
    R1 =
  Out:
    R1 =
    R2 =
    R3 =
    R4 =
    R6 =
  RISC OS entry:
    - Omni_GetMountInfo
  SmbX entry:
  SmbX subroutines:

Create print job
  In:
    R0 = 10
    R1 =
    R2 =
    R3 =
    R4 =
  Out:
    R1 =
  RISC OS entry:
    - Prn_CreateJob
  SmbX entry:
  SmbX subroutines:

Send to print job
  In:
    R0 = 11
    R1 =
    R2 =
    R3 =
  Out:
  RISC OS entry:
    - Prn_WriteData
  SmbX entry:
  SmbX subroutines:

End print job
  In:
    R0 = 12
    R1 =
  Out:
  RISC OS entry:
    - Prn_CloseJob
  SmbX entry:
  SmbX subroutines:

Abort print job
  In:
    R0 = 13
    R1 =
  Out:
  RISC OS entry:
    - Prn_CloseJob
  SmbX entry:
  SmbX subroutines:

Get print job info
  In:
    R0 = 14
    R1 =
  Out:
    R1 =
  RISC OS entry:
    - Prn_GetJobStatus
  SmbX entry:
  SmbX subroutines:

Clear print job
  In:
    R0 = 15
    R1 =
  Out:
  RISC OS entry:
    - Prn_ClearJob
  SmbX entry:
  SmbX subroutines:

Enumerate printers
  In:
    R0 = 16
    R1 =
    R2 =
    R3 =
  Out:
    R1 =
    R3 =
  RISC OS entry:
    - Omni_ListPrinters
  SmbX entry:
  SmbX subroutines:
```

Handlers for LanMan_FreeOp SWI:

```
```

FileSwitch entry handlers:

```
FSEntry_Open (open file)
  In:
    R0 = reason code (0 = read, 1 = create for write, 2 = read/write)
    R1 = filename (char *)
    R3 = FileSwitch handle for the file
    R6 = pointer to special field, or 0
  Out:
    R0 = file information word
    R1 = filing system handle for file (0 if not found)
    R2 = FileSwitch buffer size (0 = unbuffered, or 64 to 4096 bytes)
    R3 = file size (buffered files only)
    R4 = space currently allocated (multiple of buffer size)
  RISC OS entry:
    - fsentry_open
  Original functions:
    - Xlt_ConvertPath, SMB_Open, Xlt_CnvROtoDOS, SMB_Create
  Adaptation notes:
    - "struct vnode" can be greatly simplified from the BSD/xnu version
    - modify BSD namecache to work with canonical RISC OS pathnames
    - "vnop_compound_open" is unique to Apple
  SmbX entry:
    - smbfs_vnop_compound_open ( struct vnop_compound_open_args *ap )
  SmbX subroutines:
    - smb_get_share_with_reference
    - smb2fs_smb_cmpd_query_dir_one
    - smbfs_smb_qpathinfo
    - smbnode_lock
    - smbfs_nget
    - smbfs_vnop_open_common
    - smbfs_setattr
    - smbfs_smb_fsync
    - smbfs_create_open
    - smbfs_open
    - smbfs_smb_reopen_file
    - smbfs_get_rights_shareMode
    - smbfs_close
    - FindFileRef
    - smb2_smb_dur_handle_init
    - smbfs_smb_ntcreatex
    - AddFileRef
    - smbfs_smb_open_file
    - smbfs_smb_close
    - smbfs_update_RW_cnts
    - vnode_setnocache
    - smb_share_rele

FSEntry_GetBytes (buffered file)
  In:
    R1 = filing system handle from open
    R2 = pointer to buffer
    R3 = number of bytes to read
    R4 = file offset to read from
  Out:
  RISC OS entry:
    - fsentry_getbytes
  Original functions:
    - SMB_Read
  SmbX entry:
    - smbfs_vnop_read
  SmbX subroutines:
    - smb_get_share_with_reference
    - smbfs_doread

FSEntry_GetBytes (unbuffered file)
  In:
    R1 = filing system handle from open
  Out:
    R0 = byte read, C clear
    R0 = undefined, C set if EOF
  Adaptation notes:
    - original code didn't support unbuffered files

FSEntry_PutBytes (buffered file)
  In:
    R1 = filing system handle
    R2 = pointer to buffer
    R3 = number of bytes to write
    R4 = file offset to write to
  Out:
  RISC OS entry:
    - fsentry_putbytes
  Original functions:
    - SMB_Write
  SmbX entry:
    - smbfs_vnop_write
  SmbX subroutines:
    - smb_get_share_with_reference
    - smbfs_smb_reopen_file
    - smbfs_dowrite

FSEntry_PutBytes (unbuffered file)
  In:
    R0 = byte to put to file
    R1 = filing system handle from open
  Out:
  Adaptation notes:
    - original code didn't support unbuffered files

FSEntry_Args 0 - read sequential (unbuffered) file pointer
  In:
    R0 = 0
    R1 = filing system handle
  Out:
    R2 = sequential file pointer
  RISC OS entry:
    - fsentry_args
  SmbX entry:
  SmbX subroutines:

FSEntry_Args 1 - write sequential (unbuffered) file pointer
  In:
    R0 = 1
    R1 = filing system handle
    R2 = new sequential file pointer
  Out:
    R2 = sequential file pointer
  RISC OS entry:
    - fsentry_args
  SmbX entry:
  SmbX subroutines:

FSEntry_Args 2 - read file extent
  In:
    R0 = 2
    R1 = filing system handle
  Out:
    R2 = file extent
  RISC OS entry:
    - fsentry_args
  SmbX entry:
  SmbX subroutines:

FSEntry_Args 3 - write file extent
  In:
    R0 = 3
    R1 = filing system handle
    R2 = new file extent
  Out:
    R2 = file extent
  RISC OS entry:
    - fsentry_args
  SmbX entry:
  SmbX subroutines:

FSEntry_Args 4 - read size allocated to file
  In:
    R0 = 4
    R1 = filing system handle
  Out:
    R2 = size allocated to file
  RISC OS entry:
    - fsentry_args
  SmbX entry:
  SmbX subroutines:

FSEntry_Args 5 - EOF check (unbuffered files)
  In:
    R0 = 5
    R1 = filing system handle
  Out:
    R2 = -1 if at EOF, otherwise 0
  RISC OS entry:
    - fsentry_args
  SmbX entry:
  SmbX subroutines:

FSEntry_Args 6 - flush modified data
  In:
    R0 = 6
    R1 = filing system handle
  Out:
    R2 = load address of file (or 0)
    R3 = execution address of file (or 0)
  RISC OS entry:
    - fsentry_args
  SmbX entry:
  SmbX subroutines:

FSEntry_Args 7 - ensure file size
  In:
    R0 = 7
    R1 = filing system handle
    R2 = size of file to ensure
  Out:
    R2 = size of file actually ensured
  RISC OS entry:
    - fsentry_args
  SmbX entry:
  SmbX subroutines:

FSEntry_Args 8 - write zeros to file
  In:
    R0 = 8
    R1 = filing system handle
    R2 = file offset at which to write
    R3 = number of zero bytes to write
  Out:
    - fsentry_args
  RISC OS entry:
  SmbX entry:
  SmbX subroutines:

FSEntry_Args 9 - read file datestamp
  In:
    R0 = 9
    R1 = filing system handle
  Out:
    R2 = load address of file (or 0)
    R3 = execution address of file (or 0)
  RISC OS entry:
    - fsentry_args
  SmbX entry:
  SmbX subroutines:

FSEntry_Close
  In:
    R1 = filing system handle
    R2 = new load address to save with file
    R3 = new execution address to save with file
  Out:
  RISC OS entry:
    - fsentry_close
  SmbX entry:
  SmbX subroutines:

FSEntry_File 0 - save file
  In:
    R0 = 0
    R1 = pointer to filename
    R2 = load address for file
    R3 = execution address for file
    R4 = pointer to start of buffer
    R5 = pointer to byte after end of buffer
    R6 = pointer to special field, or 0
  Out:
    R6 = pointer to leafname for printing *OPT 1 info
  RISC OS entry:
    - fsentry_file
  SmbX entry:
  SmbX subroutines:

FSEntry_File 1 - write catalogue info
  In:
    R0 = 1
    R1 = pointer to wildcarded filename
    R2 = load address for file
    R3 = execution address for file
    R5 = new file attributes
    R6 = pointer to special field, or 0
  Out:
  RISC OS entry:
    - fsentry_file
  SmbX entry:
  SmbX subroutines:

FSEntry_File 2 - write load address
  In:
    R0 = 2
    R1 = pointer to wildcarded filename
    R2 = load address for file
    R6 = pointer to special field, or 0
  Out:
  RISC OS entry:
    - fsentry_file
  SmbX entry:
  SmbX subroutines:

FSEntry_File 3 - write exec address
  In:
    R0 = 3
    R1 = pointer to wildcarded filename
    R3 = execution address for file
    R6 = pointer to special field, or 0
  Out:
  RISC OS entry:
    - fsentry_file
  SmbX entry:
  SmbX subroutines:

FSEntry_File 4 - write attributes
  In:
    R0 = 4
    R1 = pointer to wildcarded filename
    R5 = new file attributes
    R6 = pointer to special field, or 0
  Out:
  RISC OS entry:
    - fsentry_file
  SmbX entry:
  SmbX subroutines:

FSEntry_File 5 - read catalogue information
  In:
    R0 = 5
    R1 = pointer to wildcarded filename
    R6 = pointer to special field, or 0
  Out:
    R0 = object type: (0 = not found, 1 = file, 2 = dir)
    R2 = load address
    R3 = execution address
    R4 = file length
    R5 = file attributes
  RISC OS entry:
    - fsentry_file
  SmbX entry:
  SmbX subroutines:

FSEntry_File 6 - delete object
  In:
    R0 = 6
    R1 = pointer to wildcarded filename
    R6 = pointer to special field, or 0
  Out:
    R0 = object type: (0 = not found, 1 = file, 2 = dir)
    R2 = load address
    R3 = execution address
    R4 = file length
    R5 = file attributes
  RISC OS entry:
    - fsentry_file
  SmbX entry:
  SmbX subroutines:

FSEntry_File 7 - create file
  In:
    R0 = 7
    R1 = pointer to wildcarded filename
    R2 = load address to associate with file
    R3 = execution address to associate with file
    R4 = start address in memory of data
    R5 = end address in memory plus one
    R6 = pointer to special field, or 0
  Out:
    R6 = pointer to leafname for printing *OPT 1 info
  RISC OS entry:
    - fsentry_file
  SmbX entry:
  SmbX subroutines:

FSEntry_File 8 - create directory
  In:
    R0 = 8
    R1 = pointer to directory name
    R2 = load address to associate with file
    R3 = execution address to associate with file
    R4 = number of entries (0 for default)
    R6 = pointer to special field, or 0
  Out:
  RISC OS entry:
    - fsentry_file
  SmbX entry:
  SmbX subroutines:

FSEntry_File 9 - read catalogue info
  In:
    R0 = 9
    R1 = pointer to directory name
    R6 = pointer to special field, or 0
  Out:
    R0 = object type
    R2 = load address
    R3 = execution address
    R5 = file attributes
  RISC OS entry:
    - fsentry_file
  SmbX entry:
  SmbX subroutines:

FSEntry_File 10 - read block size
  In:
    R0 = 10
    R1 = pointer to filename
    R6 = pointer to special field, or 0
  Out:
    R2 = natural block size of the file, in bytes
  RISC OS entry:
    - fsentry_file
  SmbX entry:
  SmbX subroutines:

FSEntry_File 255 - load file
  In:
    R0 = 255
    R1 = pointer to wildcarded filename
    R2 = address to load file
    R6 = pointer to special field, or 0
  Out:
    R2 = load address
    R3 = execution address
    R4 = file length
    R5 = file attributes
    R6 = pointer to filename for printing *OPT 1 info
  RISC OS entry:
    - fsentry_file
  SmbX entry:
  SmbX subroutines:


FSEntry_Func 0 - set current directory
  In:
    R0 = 0
    R1 = pointer to wildcarded directory name
    R6 = pointer to special field, or 0
  Out:
  RISC OS entry:
    - fsentry_func
  SmbX entry:
  SmbX subroutines:

FSEntry_Func 1 - set library directory
  In:
    R0 = 1
    R1 = pointer to wildcarded directory name
    R6 = pointer to special field, or 0
  Out:
  RISC OS entry:
    - fsentry_func
  SmbX entry:
  SmbX subroutines:

FSEntry_Func 2 - catalogue directory (*Cat command)
  In:
    R0 = 2
    R1 = pointer to wildcarded directory name
    R6 = pointer to special field, or 0
  Out:
  RISC OS entry:
    - fsentry_func
  SmbX entry:
  SmbX subroutines:

FSEntry_Func 3 - examine directory (*Ex command)
  In:
    R0 = 3
    R1 = pointer to wildcarded directory name
    R6 = pointer to special field, or 0
  Out:
  RISC OS entry:
    - fsentry_func
  SmbX entry:
  SmbX subroutines:

FSEntry_Func 4 - catalogue library directory (*LCat command)
  In:
    R0 = 4
    R1 = pointer to wildcarded directory name
    R6 = pointer to special field, or 0
  Out:
  RISC OS entry:
    - fsentry_func
  SmbX entry:
  SmbX subroutines:

FSEntry_Func 5 - examine directory (*LEx command)
  In:
    R0 = 5
    R1 = pointer to wildcarded directory name
    R6 = pointer to special field, or 0
  Out:
  RISC OS entry:
    - fsentry_func
  SmbX entry:
  SmbX subroutines:

FSEntry_Func 6 - examine objects (*Info command)
  In:
    R0 = 6
    R1 = pointer to wildcarded pathname
    R6 = pointer to special field, or 0
  Out:
  RISC OS entry:
    - fsentry_func
  SmbX entry:
  SmbX subroutines:

FSEntry_Func 7 - set filing system options (*Opt command)
  In:
    R0 = 7
    R1 = new option (or 0 to reset all to defaults)
    R2 = new parameter
    R6 = 0
  Out:
  RISC OS entry:
    - fsentry_func
  SmbX entry:
  SmbX subroutines:

FSEntry_Func 8 - rename object
  In:
    R0 = 8
    R1 = pointer to pathname of object to rename
    R2 = pointer to new pathname for object
    R6 = pointer to first special field, or 0
    R7 = pointer to second special field, or 0
  Out:
    R1 = 0 on success (non-zero, otherwise)
  RISC OS entry:
    - fsentry_func
  SmbX entry:
  SmbX subroutines:

FSEntry_Func 9 - access objects (*Access command)
  In:
    R0 = 9
    R1 = pointer to wildcarded pathname
    R2 = pointer to access string (null, space, or ctrl-char terminated)
    R6 = pointer to special field, or 0
  Out:
  RISC OS entry:
    - fsentry_func
  SmbX entry:
  SmbX subroutines:

FSEntry_Func 10 - perform boot action
  In:
    R0 = 10
  Out:
  RISC OS entry:
    - fsentry_func
  SmbX entry:
  SmbX subroutines:

FSEntry_Func 11 - read name and boot (*OPT 4) option of disc
  In:
    R0 = 11
    R2 = pointer to buffer to return data
    R6 = 0
  Out:
  RISC OS entry:
    - fsentry_func
  SmbX entry:
  SmbX subroutines:

FSEntry_Func 12 - read current directory name and privilege byte
  In:
    R0 = 12
    R2 = pointer to buffer to return data
    R6 = 0
  Out:
  RISC OS entry:
    - fsentry_func
  SmbX entry:
  SmbX subroutines:

FSEntry_Func 13 - read library directory name and privilege byte
  In:
    R0 = 13
    R2 = pointer to buffer to return data
    R6 = 0
  Out:
  RISC OS entry:
    - fsentry_func
  SmbX entry:
  SmbX subroutines:

FSEntry_Func 14 - read directory entries
FSEntry_Func 15 - read directory entries and information
FSEntry_Func 19 - read directory entries and information
  In:
    R0 = 14, 15, 19
    R1 = pointer to wildcarded directory name
    R2 = pointer to buffer to return data
    R3 = number of object names to read
    R4 = offset of first item to read (0 for start of directory)
    R5 = length of buffer
    R6 = pointer to special field, or 0
  Out:
    R3 = number of names read
    R4 = offset of next item to read in directory (-1 if end)
  RISC OS entry:
    - fsentry_func
  SmbX entry:
  SmbX subroutines:

FSEntry_Func 20 - output full info on objects
  In:
    R0 = 20
    R2 = pointer to pathname
    R6 = pointer to special field, or 0
  Out:
  Adaptation notes:
    - only called if bit 25 of info word was set during initialisation
  RISC OS entry:
    - fsentry_func
  SmbX entry:
  SmbX subroutines:

FSEntry_Func 23 - canonicalise special field and disc name
  In:
    R0 = 23
    ...
  Out:
    ...
  Adaptation notes:
    - only called if bit 23 of info word was set during initialisation
  RISC OS entry:
    - fsentry_func
  SmbX entry:
  SmbX subroutines:

FSEntry_Func 24 - resolve wildcard
  In:
    R0 = 24
    ...
  Out:
    ...
  Adaptation notes:
    - only called if bit 23 of info word was set during initialisation
  RISC OS entry:
    - fsentry_func
  SmbX entry:
  SmbX subroutines:

FSEntry_Func 25 - read defect list
  In:
    R0 = 25
    ...
  Out:
    ...
  RISC OS entry:
    - fsentry_func
  SmbX entry:
  SmbX subroutines:

FSEntry_Func 26 - add a defect
  In:
    R0 = 26
    ...
  Out:
    ...
  RISC OS entry:
    - fsentry_func
  SmbX entry:
  SmbX subroutines:

FSEntry_Func 27 - read boot option
  In:
    R0 = 27
    ...
  Out:
    ...
  RISC OS entry:
    - fsentry_func
  SmbX entry:
  SmbX subroutines:

FSEntry_Func 28 - write boot option
  In:
    R0 = 28
    ...
  Out:
    ...
  RISC OS entry:
    - fsentry_func
  SmbX entry:
  SmbX subroutines:

FSEntry_Func 29 - read used space map
  In:
    R0 = 29
    ...
  Out:
    ...
  RISC OS entry:
    - fsentry_func
  SmbX entry:
  SmbX subroutines:

FSEntry_Func 30 - read free space
  In:
    R0 = 30
    ...
  Out:
    ...
  RISC OS entry:
    - fsentry_func
  SmbX entry:
  SmbX subroutines:

FSEntry_Func 31 - name image
  In:
    R0 = 31
    ...
  Out:
    ...
  RISC OS entry:
    - fsentry_func
  SmbX entry:
  SmbX subroutines:

FSEntry_Func 32 - stamp image
  In:
    R0 = 32
    ...
  Out:
    ...
  RISC OS entry:
    - fsentry_func
  SmbX entry:
  SmbX subroutines:

FSEntry_Func 33 - get usage of offset
  In:
    R0 = 33
    ...
  Out:
    ...
  RISC OS entry:
    - fsentry_func
  SmbX entry:
  SmbX subroutines:

FSEntry_Func 34 - notification of changed directory
  In:
    R0 = 34
    ...
  Out:
    ...
  RISC OS entry:
    - fsentry_func
  SmbX entry:
  SmbX subroutines:

FSEntry_GBPB 1 and 2 (unbuffered write)
  In:
    R0 = 1 or 2
    R1 = filing system handle
    R2 = pointer to buffer
    R3 = number of bytes to put to file
    if R0 = 1
      R4 = seq. file pointer to use for start
  Out:
    R0, R1 preserved
    R2 = address of byte after last one transferred
    R3 = number of bytes not transferred
    R4 = initial file pointer + number of bytes transferred
  RISC OS entry:
    - fsentry_gpbp
  SmbX entry:
  SmbX subroutines:
    - original code didn't support unbuffered files

FSEntry_GBPB 3 and 4 (unbuffered read)
  In:
    R0 = 3 or 4
    R1 = filing system handle
    R2 = pointer to buffer
    R3 = number of bytes to put to file
    if R0 = 3
      R4 = seq. file pointer to use for start
  Out:
    R0, R1 preserved
    R2 = address of byte after last one transferred
    R3 = number of bytes not transferred
    R4 = initial file pointer + number of bytes transferred
  RISC OS entry:
    - fsentry_gpbp
  SmbX entry:
  SmbX subroutines:
    - original code didn't support unbuffered files
```


RISC OS <-> UTF-16 filename mapping:
------------------------------------

This client follows the standard RISC OS filename mapping practice of
swapping "." and "/" characters, converting ASCII space to non-breaking
space (0xA0), and supports `,ttt` and `,llllllll-eeeeeeee` extensions
to indicate RISC OS filetype or load and execute addresses, respectively.

Additionally, UTF-16 characters on the server that can't be mapped to the
8-bit RISC OS character set are escaped in the following way: the RISC OS
filename is encoded in the same manner as UTF-7, where an escape character
indicates the start of a modified Base64-encoded region, with another
character to end the Base64-encoded region, which can be omitted if there
are no unencoded characters to follow, or if the next directly-mapped
character isn't in the modified Base64-encoding character set.

There are a few modifications to the usual UTF-7 and its Base64 mapping
to better accommodate the purpose of having a relatively compact, unambiguous
legal RISC OS filename that maps as many non-ASCII characters as possible
to/from the RISC OS character set directly (ISO Latin-1 with extensions).
Rather than using `+` to start a Base64-encoded sequence, the macron (0xAF)
is used, which is visible in ISO Latin 1, and unlikely to be used by itself.

Also, because `/` can't be used in the Base64 encoding itself, `=` is
substituted, because it's no longer needed as a padding character (the
character to end the Base64-encoded region is `-`, the same as UTF-7).
Besides these modifications, the primary difference from UTF-7 is that as
many characters as possible are mapped directly to a RISC OS 8-bit value.

Because space is mapped to 0xA0, if 0xA0 (non-breaking space) is encountered
in an SMB file, it's mapped to macron (0xAF) plus non-breaking space, to
avoid ambiguity. Some characters that have special meaning in SMB, notably
`?`, are mapped using the Microsoft Services for Macintosh (SFM) convention
of using a private UTF-16 space to map those special characters.

This filename transcoding algorithm hasn't yet been implemented, but the
conversion tables have been added to `c/Xlate` in preparation to write it.


Read-ahead/write-behind block cache:
------------------------------------

SMB 2.1 and above use a metering system where the client must request
"credits" from the server prior to sending additional SMB requests.
Each message costs a minimum of 1 credit, but if the message payload
(the variable-length data section) is over 64 KiB in size, then
the cost is calculated according to this formula:

`(max(SendPayloadSize, Expected ResponsePayloadSize) - 1) / 65536 + 1`

This provides an incentive to read and write files in multiples of
64 KiB blocks, although SMB credits will probably not be a bottleneck
in practice, assuming the server is not especially busy.

A more relevant reason to use a relatively large file payload size
and RAM cache block size is to reduce the per-SMB-message processing
overhead. This becomes more relevant with signing or encryption enabled.

The incentive to not ask for an excessive amount of read-ahead data is
to not waste CPU time, RAM, server credits, and network bandwidth for
data that processes may not ever read. FileSwitch will only read/write
in units of the natural block size returned by the filing system, with
a maximum block size of 4096 bytes, and buffers nonaligned and smaller
transfers internally.

Since most files aren't exact multiples of the filing system block size,
RISC OS writes the file extent (size) with an FSEntry_Args 3 call just
before closing an open file.

There's a risk of keeping stale data in the read cache that's greatly
reduced in SMB 2 and 3 by the oplock and lease features, which allow
the client to monitor files and get async events when other clients
modify the data. Because of this feature, recently-closed files are
remembered in the cache and the file's oplock or lease is freed after
30 seconds if no other process opens it.

The plan is to allocate a file block cache of, by default, 1/128th
the amount of free physical memory, rounded up to the nearest MiB,
as a dynamic area, and then directly map 64 KiB blocks of files,
naturally aligned, to blocks of memory in the dynamic area, using
a free bitmap and an LRU replacement that updates a counter whenever
a page is accessed for reading. Then, when a contiguous range of
pages is requested, it's possible to scan first for free pages and
then for the collectively oldest range of pages to free for reuse.

The same page cache will also be used for write-behind file caching,
with a different bitmap and a flush mechanism when files are closed.
Both read-ahead and write-behind activities will proceed in the
background using the Internet event callback to handle receiving
async responses and, if necessary, sending additional requests.


SMB NTSTATUS error mapping:
---------------------------

The original version of `smb_subr.c` maps NTSTATUS errors to POSIX `errno`
values. For RISC OS, the `nt2errno` array now maps the error values to
RISC OS error number values included from `Interface/LanManErr.h` which
is generated from the assembler source in `s/LanManErr`, based on the
error definition files in SDFS and SCSIFS.


Async event-driven design:
--------------------------

The original code uses a kernel thread implemented in `smb_iod.c` to
handle async socket I/O, while synchronous requests are often managed
from the calling thread, using the appropriate struct locking. For
RISC OS, the logic is as similar as possible, with the exception of
the Internet event callback replacing the wait for new events in the
original kernel thread. Any callback that needs to wait for more info
can block on the relevant lock with `mutex_sleep_lock()`.


Test plan:
----------

Existing test programs:

 - `test/LMTest`
 - `test/Contentious,ffb`


Performance testing:
--------------------

Once the code is functioning, performance and reliability testing will
require running various benchmarks across different hardware and
network configurations (speed, latency).

 - Use iobench, iozone, filebench, etc..
 - test increasing the mbuf min and max buffer sizes
 - test different read-ahead / write-behind values
 - Use `showstat` to verify the mbuf manager isn't getting too full

Year 2038 compatibility:
------------------------

The SMBX code uses `struct timespec` extensively, which is implemented with
`time_t` (seconds since 1 Jan 1970), defined as `unsigned int` in RISC OS.
This has two implications: first, the code should continue to work past the
19 Jan 2038 signed 32-bit `time_t` wraparound to negative values, until the
unsigned 32-bit `time_t` wraps around on 7 Feb 2106. The other implication
is that all the time arithmetic code needs to be reviewed to make sure that
none of it assumes that a `time_t` can hold a negative value.
