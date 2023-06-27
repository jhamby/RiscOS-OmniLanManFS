# Copyright 1998 Acorn Computers Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Makefile for LanManFS
#

COMPONENT    = LanManFS
OBJS         = Interface LanManErr mbuf md4c md5c smb_subr #smb_mchain
CINCLUDES    = ${TCPIPINC}
HDRS         =
ASMHDRS      = LanManErr
ASMCHDRS     = LanManErr
CMHGFILE     = LanMan_MH
CMHGDEPENDS  = LanMan Logon Omni
LIBS         = ${NET5LIBS} ${ASMUTILS} ${SYNCLIB}
RES_PATH     = ThirdParty.OmniClient
CDEFINES     = -DKERNEL ${OPTIONS}
CFLAGS       = ${C_NOWARN_NON_ANSI_INCLUDES}
CDFLAGS      = -DDEBUG -DDEBUGLIB -DSMB_DEBUG -DNB_DEBUG
ROMCDEFINES  = -DROM
CMHGDEFINES  = ${OPTIONS}
ifeq ("${CMDHELP}","None")
CMHGDEFINES += -DNO_INTERNATIONAL_HELP
endif
# Carry our own ThirdParty resources, don't put them in the Messages module
CUSTOMRES    = no
RESDIR       = ${MERGEDRDIR}
OBJS        += ${RES_OBJ}
INSTRES_FILES = ROM.Sprites
INSTRES_VERSION = Messages

# Note: without setting EXP_HDR below, the ASM2TXT rule wasn't creating .hdr,
# which prevented "hdr.LanManErr", and therefore "h.LanManErr", from building.
ASM2TXT      = LanManErr hdr
EXP_HDR      = hdr

include CModule

# Dynamic dependencies:
