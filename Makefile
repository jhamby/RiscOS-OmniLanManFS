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
# Component specific options:
#
COMPONENT  = LanManFS
ROM_MODULE = aof.${COMPONENT}
RAM_MODULE = rm.${COMPONENT}
DBG_MODULE = rm.${COMPONENT}D


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


CPFLAGS = ~cfr~v
WFLAGS  = ~c~v

# sbrodie 5/1/99: Define LANMANFS to enable use of NFS headers
DFLAGS    = -UTML -DCOMPAT_INET4 -DLANMANFS -DLONGNAMES
AFLAGS    = -depend !Depend ${THROWBACK} -Stamp -quit
CFLAGS    = -depend !Depend ${THROWBACK} -c -Wpcs -ff -zps1 -zM ${INCLUDES},. ${DFLAGS}
CMHGFLAGS = -depend !Depend ${THROWBACK} -p
INCLUDES  = -ITCPIPLibs:,C:

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



OBJS      = LanMan.o Omni.o Logon.o CoreFn.o Printers.o NameCache.o \
            Xlate.o Interface.o RMInfo.o buflib.o Transact.o \
            LLC.o NetBIOS.o SMB.o Errors.o Attr.o RPC.o NBIP.o Stats.o LanMan_MH.o

ROM_OBJS  = or.LanMan or.Omni or.Logon or.CoreFn or.Printers or.NameCache \
            or.Xlate or.buflib  Interface.o RMInfo.o Errors.o or.Transact \
            or.LLC or.NetBIOS or.SMB or.Attr or.RPC or.NBIP or.Stats LanMan_MH.o 

#DBG_OBJS  = od.LanMan od.Omni od.Logon od.CoreFn od.Printers od.NameCache \
#            od.Xlate od.buflib  Interface.o RMInfo.o Errors.o o.Transact \
#            od.LLC od.NetBIOS od.SMB od.Attr od.RPC od.NBIP od.Stats LanMan_MH.o 

DBG_OBJS  = od.LanMan o.Omni od.Logon od.CoreFn od.Printers od.NameCache \
            od.Xlate od.buflib Interface.o RMInfo.o Errors.o od.Transact \
            o.LLC o.NetBIOS od.SMB o.Attr od.RPC o.NBIP od.Stats LanMan_MH.o 

OBJSI     = i.LanMan i.Omni i.Logon i.CoreFn i.Printers i.NameCache \
            i.Xlate i.buflib i.Transact \
            i.LLC i.NetBIOS i.SMB i.Attr i.RPC i.NBIP i.Stats

OBJSINST  = LanMan_MH.o inst.LanMan inst.Omni inst.Logon inst.CoreFn inst.Printers \
            inst.Xlate inst.buflib Interface.o RMInfo.o Errors.o inst.Transact\
            inst.NameCache\
            inst.LLC inst.NetBIOS inst.SMB inst.Attr inst.RPC inst.NBIP inst.Stats 

LanMan_MH.h: LanMan_MH.o
	${CMHG} ${CMHGFLAGS} cmhg.$* -d $@

#
# Rule patterns
#
.SUFFIXES:  .o .od .or .s .c .i .h .cmhg .inst
.c.o:;      ${CC} ${CFLAGS} -o $@ $<
.c.or:;      ${CC} ${CFLAGS} -DROM -o $@ $<
.c.od:;      ${CC} ${CFLAGS} -DDEBUG -DTRACE -o $@ $<
.c.i:;		$(CC) $(CFLAGS) -c -C -E $< >> $@
.i.inst:;	$(CC) $(CFLAGS) -C++ -o $@ $<
.cmhg.o:;   ${CMHG} ${CMHGFLAGS} -o $@ $< -d $*.h
.s.o:;      ${AS} ${AFLAGS} $< $@

#
# Build target
#
all: ${RAM_MODULE}
	@echo ${COMPONENT}: all complete

#
# RISC OS ROM build rules:
#
rom: ${ROM_MODULE}
	@echo ${COMPONENT}: rom module built

preprocess: ${OBJSI} i.dirs
	@echo ${COMPONENT}: preprocess build complete

instrument: ${OBJSINST} inst.instlib i.dirs o.dirs 
	$(LD) -rmf -o $@ $(OBJSINST) inst.instlib $(STUBS)
	ModSqz $@
	@echo ${COMPONENT}: instrument build complete

o.dirs:
	${MKDIR} o
	${MKDIR} od
	${MKDIR} or
	create o.dirs

i.dirs:
	${MKDIR} i
	${MKDIR} inst

export: 
	@echo ${COMPONENT}: export complete

install_rom: ${ROM_MODULE}
	${CP} ${ROM_MODULE} ${INSTDIR}.${COMPONENT} ${CPFLAGS}
	@echo ${COMPONENT}: rom module installed

clean:
	${WIPE} o ${WFLAGS}
	${WIPE} od ${WFLAGS}
	${WIPE} or ${WFLAGS}
	${WIPE} i ${WFLAGS}
	${WIPE} inst ${WFLAGS}
	${WIPE} map ${WFLAGS}
	${WIPE} linked ${WFLAGS}
	${WIPE} aof ${WFLAGS}
	${WIPE} rm ${WFLAGS}
	${RM} h.LanMan_MH
	${RM} NameCache
	@echo ${COMPONENT}: cleaned

#
# Target 
#
${RAM_MODULE}: ${OBJS} o.dirs
	${MKDIR} rm
	${LD} -o $@ -rmf ${OBJS} ${UNIXLIB} ${INETLIB} ${SOCKLIB} ${CLIB}
	${MODSQZ} $@
	Access $@ RW/R

${DBG_MODULE}: ${DBG_OBJS} o.dirs
	${MKDIR} rm
	${LD} -o $@ -rmf ${DBG_OBJS} ${UNIXLIB} ${INETLIB} ${SOCKLIB} ${CLIB}
	${MODSQZ} $@

#
# ROM Target 
#
${ROM_MODULE}: ${ROM_OBJS} ${UNIXLIB} ${INETLIB} ${SOCKLIB} o.dirs
	${MKDIR} aof
	${LD} -o $@ -aof ${ROM_OBJS} ${ROMCSTUBS} ${UNIXLIB} ${INETLIB} ${SOCKLIB}
	
#
# Final link for the ROM Image (using given base address)
#
rom_link:
	${MKDIR} linked
	${LD} -o linked.${COMPONENT} -rmf -base ${ADDRESS} ${ROM_MODULE} ${ABSSYM}
	${CP} linked.${COMPONENT} ${LINKDIR}.${COMPONENT} ${CPFLAGS}
	@echo ${COMPONENT}: rom_link complete

# Dynamic dependencies:
