;Any live cell with fewer than two live neighbors dies, as if by underpopulation.
;Any live cell with two or three live neighbors lives on to the next generation.
;Any live cell with more than three live neighbors dies, as if by overpopulation.
;Any dead cell with exactly three live neighbors becomes a live cell, as if by reproduction.

FACE	equ 1
Bface	equ 2

FRAME	equ 0E043h
FRAMEbuffer	equ 0E630h
;BLOCK	equ 0E631h+66+420+66+66+66
SCRNdistance	equ 1518


GOL_INIT 	call SETUP_gol_count 
	call FILLborders
	call HANDofGOD

GOL_MAINloop	call UPDATEscreen
	call PRNTscreen1
	call EYEofGOD
	call GOLcount 
	jc   exitGAMEofLIFE
	call USART_KEY?
	jnc  GOL_MAINloop 
	cpi  ESC
	jnz  GOL_MAINloop
exitGAMEofLIFE	ora  a 
	ret

;---------------
EYEofGOD	lxi  H,FRAME 
	mvi  c,22
LINEloop	push B 
	call SCANrow
	pop  B 
	inx  H 
	inx  H 
	dcr  c 
	jnz  LINEloop
	ret 
;---------------
SCANrow	mvi  c,64	;	               position
SCANloop	mvi  b,0	;b=neighborcount 	432    
	mvi  a,' ' 	;"Dead cell"    		519           
	cmp  M	;Position 1, is cell alive? 	678
	cnz  CELLisALIVE;yes, Maybe, go look
	lxi  D,0FFBFh ;-65 
	dad  D 	;a="dead cell",b=neighborcount,c=step count,D=CURCELLline,H=CURCELLline-66
	cmp  M	;Position 2
	cnz  isBORDER?
	dcx  H
	cmp  M	;Position 3
	cnz  isBORDER?
	dcx  H
	cmp  M	;Position 4
	cnz  isBORDER?
	lxi  D,66
	dad  D 
	cmp  M	;Position 5
	cnz  isBORDER?	
	dad  D 
	cmp  M	;Position 6
	cnz  isBORDER?
	inx  H 
	cmp  M	;Position 7
	cnz  isBORDER?	
	inx  H 
	cmp  M	;Position 8
	cnz  isBORDER?	
	lxi  D,-66
	dad  D 
	cmp  M	;Position 9
	cnz  isBORDER?	
	xchg 
	lxi  H,1517
	dad  D 
	xchg 
JUDGEMENT	mov  a,b 	;Move neighborcount to a-reg.
	cpi  082h	;Is the cell "alive" and is the neighborcount 2?
	jz   ALIVE	;Yes, so the cell will remain alive.
	ani  7Fh 	;Mask off the cell state information.
	cpi  3	;Is cell value equal to 3?
	jz   ALIVE	;Yes, the cell will be alive. 
DEAD	mvi  a,' '	;Load empty Cell
	stax D 	;Store cell state.
	dcr  c 
	jnz  SCANloop
	ret
ALIVE	mvi  a,FACE
	stax D
 	dcr  c 
	jnz  SCANloop
	ret 
;---
CELLisALIVE	rc 
	mvi  b,80h 
	ret 
isBORDER?	rc
	inr  b 
	ret 	
;---------------
GOLcount	lxi  H,TEMP8
	mvi  c,9
CNTUP	inr  M 
	mov  a,M
	cpi  ':'
	cmc
	rnc    
	mvi  M,'0' 
	dcx  H
	dcr  c 
	rz
	mov  a,M
	cpi  ' '
	jnz  CNTUP
	mvi  M,'0' 
	jmp  CNTUP
;---------------
PRNTscreen1	mvi  a,CLR
	call USART_OUT 
	lxi  H,0E000h 
	mvi  b,1 
	call PRNTLNloop1
	push H 
	lxi  H,TEMP0  
	rst  6
	pop  H 
	mvi  b,23
PRNTLNloop1	mvi  c,66
PRNTCHARloop1	mov  a,M 
	call USART_OUT 
	inx  H
	dcr  C
	jnz  PRNTCHARloop1
 	dcr  b 
	rz
	call CRLF
	jmp  PRNTLNloop1
	ret
;---------------	
USART_KEY?	in   USART_CMD   ;Read USART status
	ani  2           ;Test RxRdy bit
	jnz  USRT_DAT   
	stc
USRT_DAT	in   USART_DATA  ;Read character
	cmc
	ret	
;--------------- 	
FILLborders	lxi  H,0E000h 
	mvi  c,66
	mvi  a,'+'
TOPloop	mov  M,a
	inx  H 
	dcr  c 
	jnz  TOPloop
	lxi  H,0E5EEh 
	mvi  c,66
BOTTOMloop	mov  M,a
	inx  H 
	dcr  c 
	jnz  BOTTOMloop	
	ret 
;--------------
HANDofGOD 	mvi  a,CLR		;clear terminal
	call USART_OUT 
	lxi  H,instructions$	;print instruction header
	rst  6
	call CRLF 		;next line
	lxi  H,FRAMEbuffer	;load address of frame buffer
	mvi  c,22		;total lines
HOG_next_line	mvi  b,64
	mvi  a,'+'
	call PRINTout
FILLline	call USART_IN 
	cpi  BS
	jz   HOGbackspace
	cpi  CR 
	jz   LINEdone?
	cpi  SPACE
	jz   ADDdead_cell
	mvi  a,FACE 
SENDchar	call PRINTout 
	dcr  b 
	jnz  FILLline		;       z c    
ADDborder	mvi  a,'+'		;a<byte 0 1
	call PRINTout		;a=byte 1 0
	call CRLF 		;a>byte 0 0
	dcr  c 
	jnz  HOG_next_line	
	ret 
;---	
HOGbackspace	mov  a,b
	cpi  64	
	jnc   FILLline 
	mvi  a,BS 
	call USART_OUT
	mvi  a,' ' 
	call USART_OUT
	mvi  a,BS 
	call USART_OUT
	dcx  H 
	inr  b 
	jmp  FILLline 
;---
LINEdone?	mov  a,b	
	ora  a 	;Is char count 0?
	jz   ADDborder
	mvi  a,' '
PADloop	call PRINTout
	dcr  b 
	jnz  PADloop 
	jmp  ADDborder
;---
ADDdead_cell	mvi  a,' '
	jmp  SENDchar
;---
PRINTout	call USART_OUT 
	mov  M,a
	inx  H
	ret 	
;---------------
SETUP_gol_count	lxi  D,count$ 
	lxi  H,TEMP0  
SETUPcount_loop	ldax D 
	mov  M,a 
	inx  D 
	inx  H 
	cpi  0 
	jnz  SETUPcount_loop
	ret
;---------------
DELAY	push H 
	lxi  H,4000
DELloop	dcr  l 
	jnz  DELloop
	dcr  h
	jnz  DELloop  
	pop  H 
	ret
;---------------
UPDATEscreen    lxi  H,0E042h	   ;Destination
	lxi  D,FRAMEbuffer ;Source
	lxi  B,005ACh	  ;Count 
UPDATEloop	ldax D
	mov  M,a 
	inx  H 
	inx  D
	dcx  B 
	mov  a,b 
	ora  c 
	jnz  UPDATEloop
	ret
;	    012345678   9  a   b  c   d 
count$	db '        0',CR,LF,NULL
;                     +0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF+             +
instructions$	db  '+++ SPACE = Void, ANYKEY = Life, ENTER when done with the line +++  ESC QUITS',NULL










