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
# Paths
#
EXP_HDR = <export$dir>

#
# Generic options:
#
MKDIR   = cdir
AS      = objasm
CC      = cc
CMHG    = cmhg
CP      = copy
LD      = link
RM      = remove
MODSQZ  = modsqz
WIPE    = -wipe
CD	= dir


AFLAGS = -depend !Depend ${THROWBACK} -Stamp -quit
CFLAGS  = -depend !Depend ${THROWBACK} -c -pcc -ff -zps1 -zM -I${INCLUDES},. ${DFLAGS} -UTML -DCOMPAT_INET4
CMHGFLAGS = -p -depend !Depend ${THROWBACK}


CPFLAGS = ~cfr~v
WFLAGS  = ~c~v

#
# Libraries
#
CLIB      = CLIB:o.stubs
RLIB      = RISCOSLIB:o.risc_oslib
RSTUBS    = RISCOSLIB:o.rstubs
ROMSTUBS  = RISCOSLIB:o.romstubs
ROMCSTUBS = RISCOSLIB:o.romcstubs
ABSSYM    = RISC_OSLib:o.AbsSym
INETLIB   = TCPIPLibs:o.inetlibzm
SOCKLIB   = TCPIPLibs:o.socklibzm
UNIXLIB   = TCPIPLibs:o.unixlibzm

#
# Include files
#
LEVEL=		^
INCLUDES=	TCPIPLibs:,C:

#DFLAGS   = -dDEBUG
DFLAGS   =

COMPONENT = LanManFS
TARGET    = rm.LanManFS
ROMTARGET = aof.LanManFS
OBJS      = LanMan_MH.o LanMan.o Omni.o Logon.o CoreFn.o Printers.o \
            Xlate.o Interface.o RMInfo.o buflib.o \
            LLC.o NetBIOS.o SMB.o Errors.o Attr.o RPC.o NBIP.o Stats.o

OBJSI     = i.LanMan i.Omni i.Logon i.CoreFn i.Printers \
            i.Xlate i.buflib \
            i.LLC i.NetBIOS i.SMB i.Attr i.RPC i.NBIP i.Stats

OBJSINST  = LanMan_MH.o inst.LanMan inst.Omni inst.Logon inst.CoreFn inst.Printers \
            inst.Xlate inst.buflib Interface.o RMInfo.o Errors.o \
            inst.LLC inst.NetBIOS inst.SMB inst.Attr inst.RPC inst.NBIP inst.Stats

#
# Rule patterns
#
.SUFFIXES:  .o .s .c .i .h .cmhg .inst
.c.o:;      ${CC} ${CFLAGS} -o $@ $<
.c.i:;		$(CC) $(CFLAGS) -c -C -E $< >> $@
.i.inst:;	$(CC) $(CFLAGS) -C++ -o $@ $<
.cmhg.o:;   ${CMHG} ${CMHGFLAGS} -o $@ $<
.s.o:;      ${AS} ${AFLAGS} $< $@

#
# Build target
#
all: ${TARGET}
	@echo ${COMPONENT}: all complete

#
# RISC OS ROM build rules:
#
rom: ${ROMTARGET}
	@echo ${COMPONENT}: rom module built

preprocess: ${OBJSI} local_dirs
	@echo ${COMPONENT}: preprocess build complete

instrument: ${OBJSINST} inst.instlib local_dirs 
	$(LD) -rmf -s link/sym -o rm.AcornPOP3u $(OBJSINST) inst.instlib $(STUBS)
	ModSqz rm.AcornPOP3u rm.AcornPOP3
	@echo ${COMPONENT}: instrument build complete

local_dirs:
	${MKDIR} o
	${MKDIR} aof
	${MKDIR} rm
	${MKDIR} i
	${MKDIR} inst


export: 
	@echo ${COMPONENT}: export complete

install_rom: ${ROMTARGET}
	${CP} ${ROMTARGET} ${INSTDIR}.${COMPONENT} ${CPFLAGS}
	@echo ${COMPONENT}: rom module installed

clean:
	${WIPE} o.* ${WFLAGS}
	${WIPE} i.* ${WFLAGS}
	${WIPE} inst.* ${WFLAGS}
	${RM} ${TARGET}
	${RM} ${ROMTARGET}
	${RM} map.${COMPONENT}
	${RM} linked.${COMPONENT}
	@echo ${COMPONENT}: cleaned

#
# Target 
#
${TARGET}: ${OBJS}
	${LD} -o $@ -rmf ${OBJS} ${UNIXLIB} ${INETLIB} ${SOCKLIB} ${CLIB}
	$(MODSQZ) $(TARGET)

#
# ROM Target 
#
${ROMTARGET}: ${OBJS} ${UNIXLIB} ${INETLIB} ${SOCKLIB}
	${LD} -o $@ -aof ${OBJS} ${ROMCSTUBS} ${UNIXLIB} ${INETLIB} ${SOCKLIB}
	
#
# Final link for the ROM Image (using given base address)
#
rom_link:
	${MKDIR} linked
	${MKDIR} map
	${LD} -o linked.${COMPONENT} -map -bin -base ${ADDRESS} ${ROMTARGET} ${ABSSYM} > map.${COMPONENT}
	truncate map.${COMPONENT} linked.${COMPONENT}
	${CP} linked.${COMPONENT} ${LINKDIR}.${COMPONENT} ${CPFLAGS}
	@echo ${COMPONENT}: rom_link complete

# Dynamic dependencies:
