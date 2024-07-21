
size_of_frame	equ 0780h
line_distance	equ 0050h
XorO_bit	equ   80h
its_X	equ   80h
its_O	equ   00h
player1	equ   40h
player2	equ   20h
pick_table_mask	equ   00000011b

start_of_frame	equ TEMP0	;word, restore fremem when program exits
END_of_frame	equ TEMP2	;word
board_offset	equ TEMP4	;word
TTT_status	equ TEMP6	;byte 
TTT_counts	equ TEMP7	;byte line> HL <position
player_position	equ TEMP8	;word address of new player position
move_table_pointer	equ TEMPA
pick_table_pntr_inx	equ TEMPC
pick_table_pntr_mod	equ TEMPE
;	equ TEMP_addr_0
;	equ TEMP_addr_1
;	equ TEMP_addr_2
;	equ TEMP_addr_3
;	equ TEMP_addr_4
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
	org  8400h
	
	lhld FREMEM 
	shld start_of_frame
	call clear_frame
	lhld END_of_frame
	shld move_table_pointer
	lxi  H,80FFh
	shld delay_val
	mvi  a,2Dh
	sta  TTT_counts
	call message_and_#players 
	
next_game	call add_board
game_loop	call Draw_frame
	call check_for_win
	jc   score 
move_again	call whos_turn?                ;player_input
	jc   exit		
	call position_player
	jc   move_again
	call find_avalible
	call flip_turn
	jmp  game_loop
exit	cmc
	ret
;--------------------------
score	push D
	call inr_board_offset
	lxi  H,line_distance*5+3
	dad  D
	mov  M,a 	;print winner under board 
 	call get_position	;gets next board position 
	jmp next_game 
;--------------- 	
inr_board_offset lhld board_offset
	xchg 
	lxi  H,6
	dad  D 
	shld board_offset
	ret 
;------------
whos_turn?	mvi  b,'O'
	lda  TTT_status
	rlc 
	jnc   skip_P2
	mvi  b,'X'
	rlc 
skip_P2	rlc
	jnc  AI 
player_input	call USART_IN_seed
	cpi  ESC
	stc
	rz   	;needs to be a return
	cpi  '1'
	jc   player_input
	cpi  ':'
	jnc  player_input
	ani  0Fh
	ret
;---
flip_turn	lda  TTT_status 
	xri  XorO_bit
	sta  TTT_status
	jp   flip_O
flip_X	mvi  b,'X'
	ret 
flip_O	mvi  b,'O'
	ret
;--
swap_player	push PSW 
	mvi  a,'O' 	
	cmp  b	
	jnz  swap_O	
swap_X	mvi  b,'X' 
	pop  PSW 
	ret 
swap_O	mvi  b,'O'
	pop  PSW 
	ret	
;---------------
check_for_win	call scan_for_win
	rnc
	cpi  3
	jz   X_wins
	cpi  -3
	jz   O_wins
is_tie	;increment tie count
	mvi  a,'-'
	stc 
	ret
X_wins	;increment X count 
	mvi  a,'X'
	stc 
	ret 
O_wins	;increment O count 
	mvi  a,'O'
	stc 
	ret 
scan_for_win	push H
	push D
	push B 
	lxi  D,check_table
	lxi  H,1600h
next_three	mvi  b,0
	mvi  c,3 
get_next_char	ldax D 
	cpi  0
	jz   no_win
	call look_for_player
	cpi  'X' 
	jnz  no_X 
	inr  b 
	inr  l 
no_X	cpi  'O'
	jnz  no_O 
	dcr  b
	inr  l 
no_O	inx  D 
	dcr  c 
	jnz  get_next_char
	mov  a,b 
	cpi  3
	jz   yes_win
	cpi  -3
	jz   yes_win
	jmp  next_three
no_win	mov  a,h
	cmp  l  
	cmc 
skip_carry_set	mvi  a,' '	
yes_win	pop  B
	pop  D
	pop  H
	cmc  
	ret
;-------------- Expects a-reg. to have position 1-9 and b-reg. to have 'X' or 'O'. Returns with c=1 if an 'X' or 'O' is already been written to memory.
position_player	push H
	call get_player_address
	mov  a,M	
	cpi  ' '
	jz   place_player
	pop  H 
	stc
	ret 
place_player	mov  M,b
	pop  H 
	ret 
;---------------	
look_for_player	push H 
	call get_player_address
	mov  a,M 
	pop  H
	ret 
;---
get_player_address	push D 
	dcr  a
	rlc
	mov  e,a 
	xra  a 
	mov  d,a 
	lxi  H,buttons_table
	dad  D
	mov  e,M 
	inx  H
	mov  d,M 
	lhld board_offset
	dad  D
	shld player_position
	pop  D 
	ret 
;-------------	
clear_frame	lhld start_of_frame
	push H
	lxi  D,07D0h	;total size of frame 
clr_loop	mvi  M,' '
	inx  H 
	dcx  D 
	mov  a,d  
	ora  e 
	jnz  clr_loop
	shld END_of_frame	
	pop  H 
	lxi  D,0050h*3
	dad  D 
 	shld board_offset
	ret
;-------------
add_board	lhld board_offset
	lxi  D,tictactoeBOARD$
	mvi  b,5
line_loop	mvi  c,6
mov_char_loop	ldax D 
	mov  M,a 
	inx  H 
	inx  D 
	dcr  c
	jnz  mov_char_loop
	push D
	lxi  D,0050h-6
	dad  D
	pop  D
	dcr  b 
	jnz  line_loop
	ret 
;---------------
find_avalible	push H 
	push D 
	push B 
	push PSW 
	lhld move_table_pointer
	mov  d,h 
	mov  e,l 
	mvi  c,0
	mvi  b,9 
search_loop	mov  a,b  
	call look_for_player
	cpi  ' '
	cz   put_in_table
	dcr  b 
	jnz  search_loop 
	xchg 
	mov  M,c 
	pop  PSW 
	pop  B 
	pop  D 
	pop  H 
	ret 
put_in_table	inr  c 
	inx  H 
	mov  M,b 
	ret 
;---------------
get_position	push B
	lda  TTT_counts
	mov  c,a 
	ani  11110000b
	mov  b,a 
	mov  a,c 
	ani  00001111b 
	dcr  a 
	cz   add_7_lines
	ora  b
	sta  TTT_counts
	pop  B 
	ret 
;---
add_7_lines	mov  a,b  
	sui  16	;subtract 16 to dcr upper nibble
	rst  7
	jz   wipe_screen
	push H 
	push D 
	lhld board_offset
	lxi  D,line_distance*6+2
	dad  D 
	shld board_offset
	pop  D 
	pop  H 
	mvi  a,0Dh
	ret
wipe_screen	call clear_frame
	mvi  a,2Dh
	ret
;-------------
get_line_offset	;called with current frame offset in hl
	push  D  
 	lxi   D,0050h
	dad   D
	pop   D
	ret
;---------------
Draw_frame 	push H
	push D 
	push B 
	lhld start_of_frame
	lxi  D,size_of_frame
	mvi  a,CLR 
	call USART_OUT
Draw_loop_out	mvi  c,line_distance
Draw_loop_in	mov  a,M 
	call USART_OUT
	inx  H
	dcx  D 
	mov  a,d 
	ora  e 
	jz   exit_draw 
	dcr  c
	jnz  Draw_loop_in 
	call CRLF 
	jmp  Draw_loop_out0
exit_draw	pop  B 
	pop  D 
	pop  H 
	ret 
;+++++++++++++++++++++++++++ AI +++++++++++++++++++++++++++++
;1) check every avalible position with current player a win, if find one stay on that spot.
;2) check every avalible position with oposite player a win, if find one move currant player to that spot.
;3) using psudo random number look for avalible odd positions, if none, look for avalible even positions
AI	call find_avalible
	call test_for_win
	cmc 
	rnc
	call swap_player
	call test_for_win
	call swap_player
	cmc 
	rnc 
no_easy_pick	call get_move_table_pointer
	mov  a,c 
	cpi  1
	ldax D 
	rz   
 	mvi  a,5
	call random
	cpi  4
	jc   even_number 
odd_number	lxi  H,pick_table_odd	;load the odd table pointer as the random routine needs it
	mvi  a,5	;random number is between 0 and 5
	call look_for_pick
	cmc
	rnc 
	call get_move_table_pointer		
even_number	lxi  H,pick_table_even	;load the odd table pointer as the random routine needs it
	mvi  a,4	;random number is between 0 and 4
	call look_for_pick
	cmc 
	rnc         ;need player char                    ;jc   make_the_move	
	call get_move_table_pointer
	jmp  odd_number
;+++++++++++++++++++++++++ AI subs +++++++++++++++++++++++++++
test_for_win	push H
	lhld move_table_pointer
	xchg		;5,8,5,3,2,1
	pop  H
	ldax D
	cpi  7
	rnc 		;789  ' X| |O'
	mov  c,a 		;456  ' O| |X'
test_win_loop	inx  D 		;123  '  | | '
	ldax D
	call get_player_address
	mov  M,b 
	call scan_for_win
	mvi  M,' '
	ldax D
	rc   
	dcr  c 
	jnz  test_win_loop 
	ora  a 
	ret
;Subroutine gets a random location in the pick_table(odd or even) to start at. 
;register pair H needs to be preloaded with pick table address
;register a needs to be preloaded with value of the table length. 
get_pick_table_mod	push D
	shld pick_table_pntr_inx
	call random
 	mov  e,a 	
	xra  a  	
	mov  d,a  
	dad  D 
	shld pick_table_pntr_mod
	xchg 
	pop  H	;a=    0, b=pick_count, c=available count, D=       move_table_pointer+1, h=pick_table_odd+rand
	ret
;--------------------------
look_for_pick	push  B
	mov  b,M  	
	inx  H
	call get_pick_table_mod	
pointer_table_loop	ldax D	
	cpi  0
	jz   load_pick_table_pntr_inx
move_table_loop	cmp  M
	stc
	jz   exit_look_for_pick
	inx  H
	dcr  c
	jnz  move_table_loop
	lhld move_table_pointer	;load the move_table pointer into H 
	mov  c,M	;get the move_table count 
	inx  H	;increment H 
	inx  D
	dcr  b
	jnz  pointer_table_loop
	ora  a 
exit_look_for_pick	pop  B 
	ret
;---
load_pick_table_pntr_inx	push H
	lhld pick_table_pntr_inx
	xchg 
	pop  H 
	jmp  pointer_table_loop
;--- Loads pick_table_pntr_mod in D with the pick_table count loaded into b-reg.
load_pick_table_pntr_mod	push H
	lhld pick_table_pntr_mod
	xchg 
	pop  H
	ret 
;--
get_move_table_pointer	lhld move_table_pointer	;load the move_table pointer into H 
	mov  c,M	;get the move_table count 
	inx  H
	xchg
	ret 
;----------------------------------------------------------------
message_and_#players	lxi  H,080FFh
	shld delay_val
	mvi  a,CLR
	call USART_OUT
	lxi  H,shall_we_play$
	call SendMSG
	call number_of_players
	rc 
	call delay
	call CRLF
	lxi  H,esc_quits$
	call SendMSG
	ret 

number_of_players	call USART_IN_seed
	cpi  ESC 
	stc
	rz 
	cpi  '0'
	jz   store_status
	cpi  '1'
	jz   store_status
	cpi  '2'
	jz   store_status
	jc   number_of_players 
store_status	call USART_OUT 
	cpi  '2'
	jnz  skip_inr
	inr  a 
skip_inr	ani  00000011b
	rrc
	rrc
	rrc 
	ori  10000000b
	sta  TTT_status
	ret

;(((((((((((((((((((((((((( delays ))))))))))))))))))))))))))
long_delay	call delay	
	dcr  c 
	jnz  long_delay
	ret 
;---
delay	push H
	lhld delay_val
delay_loop	dcr  l 
	jnz  delay_loop
	dcr  h
 	jnz  delay_loop
	pop  H 
	ret 
;(((((((((((((((((((((((((((( end )))))))))))))))))))))))))))
;Example 6-13: An ASCII-BASED, Decimal-toBinary Conversion Subroutine	
DECBIN	push D 
	mov  d,b
	MVI  C,0
DECIT	MOV  A,M
	INX  H
	CPI  '0'
	CMC
	JNC  EXIT_DECBIN
	CPI  ':'
	JNC  EXIT_DECBIN
	ANI  00001111B
	MOV  B,A 
	MOV  A,C 
	RLC
	jc   exit_decbin_error
	RLC 
	jc   exit_decbin_error
	ADD  C 
	jc   exit_decbin_error
	RLC 
	jc   exit_decbin_error
	ADD  B
	jc   exit_decbin_error
	MOV  C,A 
	DCR  B 
	Jmp  DECIT
exit_decbin_error	mvi  a,0Eh	
EXIT_DECBIN	mov  b,d 
	pop  D
	RET  
;--------------------------
SendMSG	mov  a,M 
	inx  H 
	cpi  0 
	rz 
	cpi  '('
	cz   do_delay
	cpi  ')'
	jz   SendMSG
	call USART_OUT
	cpi  CR 
	jz   SendMSG
	cpi  LF
	jz   SendMSG
skip_send_char	call delay 
	jmp  SendMSG
;--------------------------
do_delay 	call DECBIN
	call long_delay
	ret 
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
USART_IN_seed 	push B 
USART_IN_seed_loop 	in   USART_CMD   ;Read USART status
	inr  c 
	ani  2           ;Test RxRdy bit
	jz   USART_IN_seed_loop    ;Wait for the data
	in   USART_DATA  ;Read character
	mov  b,a 
	mov  a,c 
	sta  random_seed
	mov  a,b 
	pop  B 
	ret
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Strings and Tables >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>	
pick_table_odd	db 5,7,5,1,3,9,0     ;00000111b mask of random - 4  
pick_table_even	db 4,6,2,8,4,0 
check_table	db 9,8,7,6,5,4,3,2,1,9,6,3,8,5,2,7,4,1,9,5,1,7,5,3,0
buttons_table	dw 141h,143h,145h,0A1h,0A3h,0A5h,001h,003h,005h
tictactoeBOARD$	db 020h,020h,0BAh,020h,0BAh,020h 
	db 020h,0CDh,0CEh,0CDh,0CEh,0CDh
	db 020h,020h,0BAh,020h,0BAh,020h
	db 020h,0CDh,0CEh,0CDh,0CEh,0CDh
	db 020h,020h,0BAh,020h,0BAh,020h
shall_we_play$	db 'Shall(5) we play(4) a game(4) of TIC-TAC-TOE?(10)',CR,LF,'How many players? ',NULL	
esc_quits$	db 'Press ESC to quit.(10)',NULL         
wins$	db 'Wins!',NULL
tie$	db '-Tie-',NULL

;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

	







	
	