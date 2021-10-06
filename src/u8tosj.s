.title u8tosj - UTF-8 to Shift_JIS converter

# This file is part of u8tosj, UTF-8 to Shift_JIS converter
# Copyright (C) 2021 Tachibana Erik
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.


.include doscall.mac
.include iocscall.mac

LF: .equ $0a
CR: .equ $0d
STDIN:  .equ 0
STDOUT: .equ 1
STDERR: .equ 2
ROPEN: .equ 0
SEEK_SET: .equ 0
SEEK_END: .equ 2
EXIT_SUCCESS: .equ  0
EXIT_FAILURE: .equ  1


.cpu 68000
.text

ProgramStart:
  lea (16,a0),a0
  suba.l a0,a1

  move.l a1,-(sp)  ;length
  pea (a0)         ;memory block
  DOS _SETBLOCK
  addq.l #8,sp
  tst.l d0
  bpl @f
    bsr SetBlockError
    moveq #EXIT_FAILURE,d0
    bra 9f
  @@:

  bsr Main

  9:
  move d0,-(sp)
  DOS _EXIT2


SetBlockError:
  lea (SetBlockErrorMsg,pc),a0
  bra PrintError
NotEnoughMemoryError:
  lea (NotEnoughMemoryMsg,pc),a0
  bra PrintError
FileOpenError:
  lea (FileOpenErrorMsg,pc),a0
  bra PrintError
FileSeekError:
  lea (FileSeekErrorMsg,pc),a0
  bra PrintError
FileReadError:
  lea (FileReadErrorMsg,pc),a0
  bra PrintError
FileWriteError:
  lea (FileWriteErrorMsg,pc),a0
  bra PrintError

PrintError:
  lea (a0),a1
  @@:
    tst.b (a1)+
    bne @b
  subq.l #1,a1
  suba.l a0,a1  ;string length

  move.l a1,-(sp)
  pea (a0)
  move #STDERR,-(sp)
  DOS _WRITE
  lea (10,sp),sp
  rts


Main:
  bsr CreateU2SArray
  bpl @f
    bsr NotEnoughMemoryError
    bra mainError
  @@:
  movea.l d0,a6

  move.l #STDOUT<<16.or.STDIN,d7

  move d7,d0
  bsr GetFileSize
  beq mainEmptyFile
  bpl @f
    bsr FileSeekError
    bra mainError
  @@:
  move.l  d0,d6

  bsr AllocReadWriteBuffer
  bpl @f
    bsr NotEnoughMemoryError
    bra mainError
  @@:
  movea.l d0,a5

  move d7,d0
  move.l d6,d1
  lea (a5),a0
  bsr ReadFromFile
  cmp.l d0,d6
  beq @f
    bsr FileReadError
    bra mainError
  @@:

  move.l d6,d0
  lea (a5),a0
  bsr Utf8toSjis
  bmi mainError
  move.l d0,d6  ;sjis length

  move.l d7,d0
  swap d0
  move.l d6,d1
  lea (a5),a0
  bsr WriteToFile
  cmp.l d0,d6
  beq @f
    bsr FileWriteError
    bra mainError
  @@:

  mainEmptyFile:
    moveq #EXIT_SUCCESS,d0
    rts
  mainError:
    moveq #EXIT_FAILURE,d0
    rts


OpenFile:
  move #ROPEN,-(sp)
  pea (a0)
  DOS _OPEN
  addq.l #6,sp
  tst.l d0
  rts


GetFileSize:
  move #SEEK_END,-(sp)
  clr.l -(sp)  ;offset=0
  move d0,-(sp)
  DOS _SEEK
  move.l d0,d1
  bmi @f
    move #SEEK_SET,(6,sp)
    DOS _SEEK
    tst.l d0
    bmi @f
      move.l d1,d0
  @@:
  addq.l #8,sp
  tst.l d0
  rts


AllocReadWriteBuffer:
  move.l d0,-(sp)
  DOS _MALLOC
  move.l d0,(sp)+
  rts


ReadFromFile:
  move.l d1,-(sp)
  move.l a0,-(sp)
  move d0,-(sp)
  DOS _READ
  addq.l #10-4,sp
  move.l d0,(sp)+
  rts


WriteToFile:
  move.l d1,-(sp)
  move.l a0,-(sp)
  move d0,-(sp)
  DOS _WRITE
  addq.l #10-4,sp
  move.l d0,(sp)+
  rts


;d0 = length
;a0 = read/write buffer
Utf8toSjis:
  movem.l d3-d7/a3-a5,-(sp)
  move.l d0,d7
  beq utf8tosjisEnd

  move.l a0,d6  ;buffer head
  lea (a0),a4   ;write pointer

  utf8tosjisLoop0:
    moveq #0,d0
  utf8tosjisLoop:
    move.b (a0)+,d0
    bmi @f
      move.b d0,(a4)+  ;U+0000..U+007F
      subq.l #1,d7
      bhi utf8tosjisLoop
      bra utf8tosjisLoopEnd
    @@:
      bsr Utf8ToCodePoint
      bmi utf8tosjisInvalid

      bsr CodePointToSjis
      move d0,-(sp)
      move.b (sp)+,d2
      beq @f
        move.b d2,(a4)+
      @@:
      move.b d0,(a4)+

      sub.l d1,d7
      lea (-1,a0,d1.l),a0
      bhi utf8tosjisLoop0
      bra utf8tosjisLoopEnd

  utf8tosjisLoopEnd:
  move.l a4,d0
  sub.l d6,d0  ;sjis length

  utf8tosjisEnd:
  movem.l (sp)+,d3-d7/a3-a5
  tst.l d0
  rts

  utf8tosjisInvalid:
    subq.l #1,a0
    neg.l d0
    bsr PrintInvalidSequence

    moveq #-1,d0
    bra utf8tosjisEnd



;in d0.l = first byte ($80..$ff)
;   d7.l = rest bytes
;   a0.l = second byte
;out d0.l = code point
;    d1.l = sequence length (2..4)
;break d2-d3/a1

Utf8ToCodePoint:
  move.l d0,d1
  lsr.b #3,d1
  move.b (Utf8LengthTable-16,pc,d1.l),d1
  beq utf8tocodepointInvalid_1  ;continuation byte or overlong encoding
  cmp.l d1,d7
  bcs utf8tocodepointInvalid_d7  ;string ending before end of character

  ;d1=2,3,4
  and.b (Utf8MaskTable-2,pc,d1.l),d0
  lea (a0),a1
  moveq #%0100_0000,d3

  move.b (a1)+,d2
  add.b d3,d2
  add.b d3,d2
  bcc utf8tocodepointInvalid_d1

  lsl #6,d0
  or.b d2,d0

  cmpi.b #3,d1
  beq 3f
  bcs 2f
      move.b (a1)+,d2
      add.b d3,d2
      add.b d3,d2
      bcc utf8tocodepointInvalid_d1

      lsl #6,d0
      or.b d2,d0
    3:
    move.b (a1)+,d2
    add.b d3,d2
    add.b d3,d2
    bcc utf8tocodepointInvalid_d1

    lsl.l #6,d0
    or.b d2,d0
  2:
  move d1,d2
  lsl #2,d2
  cmp.l (Utf8LowerLimitTable-4*2,pc,d2.w),d0
  bcs utf8tocodepointInvalid_d1  ;invalid code point

  tst.l d0
  utf8tocodepointEnd:
  rts

  utf8tocodepointInvalid_1:
    moveq #-1,d0
    bra utf8tocodepointEnd
  utf8tocodepointInvalid_d1:
    move.l d1,d0
    bra @f
  utf8tocodepointInvalid_d7:
    move.l d7,d0
  @@:
    neg.l d0
    bra utf8tocodepointEnd


.quad
Utf8LowerLimitTable:
  .dc.l $80,$800,$10000
Utf8LengthTable:
  .dc.b 0,0,0,0,0,0,0,0,2,2,2,2,3,3,4,0
Utf8MaskTable:
  .dc.b %0001_1111,%0000_1111,%0000_0111
  .even
UndefinedCharSjisCodeL:
  .dc 0  ;,$81a6
UndefinedCharSjisCode:
  .dc $81a6,$81a6
.quad


CreateU2SArray:
  movem.l d4-d7/a0-a6,-(sp)
  .xref U2STableBufferSize
  move.l (U2STableBufferSize,pc),-(sp)
  DOS _MALLOC
  move.l d0,(sp)+
  bmi 9f
  move.l d0,d7

  .xref U2STableBitmap
  .xref U2STableOffset
  lea (U2STableBitmap,pc),a6  ;short[16]
  lea (U2STableOffset,pc),a5  ;short[??]

  movea.l d7,a4  ;void*[256]
  lea ($100*4,a4),a0  ;short[256] sjis
  move.l a0,d4

  move.l (UndefinedCharSjisCode,pc),d0
  moveq #$100/4-1,d6
  @@:
    move.l d0,(a0)+
    move.l d0,(a0)+
  dbra d6,@b

  moveq #$100/16-1,d6
  1:
    swap d6
    move (a6)+,d5  ;bitmap
    move #16-1,d6
    2:
      move.l d4,d0
      add d5,d5
      bcc @f  ;all undefined code point
        move (a5)+,d0
        lea (-2,a5,d0.w),a1  ;U_**xx address

        move.l a1,(a0)
        move.l a0,d0
        lea ($100*2,a0),a0

        not.l d0  ;minus = uninitialized
      @@:
      move.l d0,(a4)+
    dbra d6,2b
    swap d6
  dbra d6,1b

  move.l d7,d0
  9:
  movem.l (sp)+,d4-d7/a0-a6
  tst.l d0
  rts


;break d2/a0
CodePointToSjis:
  cmpi.l #$ffff,d0
  bls @f
    move.l (UndefinedCharSjisCodeL,pc),d0
    rts
  @@:
  move d0,d2
  clr.b d2
  lsr #8-2,d2  ;highbyte*4

  move.l (a6,d2.w),d2
  movea.l d2,a1  ;short[256] sjis
  bpl 9f
    not.l d2  ;uninitialized
    movea.l d2,a1

    move d0,d2
    clr.b d2
    lsr #8-2,d2
    move.l a1,(a6,d2.w)  ;short[256] sjis

    bsr CreateU2SArray2
  9:
  andi #$ff,d0
  add d0,d0
  move (a1,d0.w),d0
  rts


CreateU2SArray2:
  movem.l d0/d4-d7/a0-a2,-(sp)

  movea.l (a1),a0  ;U_**xx bitmap
  lea ($100/8,a0),a2  ;short[??] sjis

  move (UndefinedCharSjisCode,pc),d4
  moveq #$100/16-1,d7
  1:
    move (a0)+,d5
    moveq #16-1,d6
    2:
      move d4,d0
      add d5,d5
      bcc @f
        move (a2)+,d0
      @@:
      move d0,(a1)+
    dbra d6,2b
  dbra d7,1b

  movem.l (sp)+,d0/d4-d7/a0-a2
  rts


PrintInvalidSequence:
  move.l d3,-(sp)
  link a6,#-64
  move d0,d3   ;length
  lea (a0),a2  ;byte sequence

  lea (InvalidUtf8Sequence,pc),a1
  lea (sp),a0
  bsr Strcpy_a1a0
  @@:
    move.b #' ',(a0)+
    move.b (a2)+,d0
    bsr StringifyHexByte
  subq #1,d3
  bne @b

  lea (NewLine,pc),a1
  bsr Strcpy_a1a0

  lea (sp),a0
  bsr PrintError

  unlk a6
  move.l (sp)+,d3
  rts

Strcpy_a1a0:
  @@:
    move.b (a1)+,(a0)+
    bne @b
  subq.l #1,a0
  rts



StringifyHexByte:
  moveq #2-1,d2
  ror.l #8,d0
  bra StringifyHex
StringifyHexWord:
  moveq #4-1,d2
  swap d2
  bra StringifyHex
StringifyHexLongword:
  moveq #8-1,d2
  bra StringifyHex

StringifyHex:
  @@:
    rol.l #4,d0
    moveq #$f,d1
    and.b d0,d1
    move.b (HexTable,pc,d1.w),(a0)+
    dbra d2,@b
  clr.b (a0)
  rts

HexTable:
  .dc.b '0123456789abcdef'
  .even



.ifdef debug

PrintHexLongwordAndString:
  move.l a0,-(sp)
  bsr PrintHexLongword
  movea.l (sp)+,a0
  bra PrintString

PrintString:
  lea (a0),a1
  IOCS _B_PRINT
  rts

PrintNewLine:
  lea (NewLine,pc),a1
  IOCS _B_PRINT
  rts

PrintHexLongword:
  link a6,#-12
  lea (sp),a0
  bsr StringifyHexLongword
  lea (sp),a1
  IOCS _B_PRINT
  unlk a6
  rts

.endif


.data
.even

Title:
  .dc.b 'u8tosj 1.0.0',0

InvalidUtf8Sequence:
  .dc.b 'Invalid byte sequence in UTF-8:',0

SetBlockErrorMsg:
  .dc.b 'Setblock error',CR,LF,0
NotEnoughMemoryMsg:
  .dc.b 'Not enough memory',CR,LF,0
FileOpenErrorMsg:
  .dc.b 'File open error',CR,LF,0
FileSeekErrorMsg:
  .dc.b 'File seek error',CR,LF,0
FileReadErrorMsg:
  .dc.b 'File read error',CR,LF,0
FileWriteErrorMsg:
  .dc.b 'File write error',CR,LF,0



.ifdef debug

MainResultMsg:
  .dc.b ': Main',CR,LF,0
MallocMsg:
  .dc.b ': DOS _MALLOC',CR,LF,0
FileOpenResultMsg:
  .dc.b ': DOS _OPEN',CR,LF,0
FileSeekResultMsg:
  .dc.b ': DOS _SEEK',CR,LF,0
FileReadResultMsg:
  .dc.b ': DOS _READ',CR,LF,0
FileWriteResultMsg:
  .dc.b ': DOS _Write',CR,LF,0
SjisLengthMsg:
  .dc.b ': Shift_JIS length',CR,LF,0
NewLine:
  .dc.b CR,LF,0

.endif



.quad

.end ProgramStart
