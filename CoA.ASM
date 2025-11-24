; -------------------------------------------------------------------
; 80386
; 32-bit x86 assembly language
; TASM
;
; author:	Manu Coppieters, Emma Hatege
; date:		22/10/2025
; program:	Chronicles of Assembly
; -------------------------------------------------------------------

IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

INCLUDE "KEYB.INC"
INCLUDE "RAND.INC"

; compile-time constants (with macros)
VMEMADR EQU 0A0000h	; video memory address
SCRWIDTH EQU 320	; physical screen witdth
SCRHEIGHT EQU 200	; physical screen height
VIRSCRWIDTH EQU 320*4 ; virtual screen width
VIRSCRHEIGHT EQU 200*4 ; virtual screen height


SPRITEWIDTH EQU 20*4	; virtual sprite size
SPRITEHEIGHT EQU 20*4		; virtual sprite size
DATASIZE EQU SPRITEWIDTH*SPRITEHEIGHT;bytes of data in file


; -------------------------------------------------------------------
; MACROS
; -------------------------------------------------------------------





; -------------------------------------------------------------------
; CODE
; -------------------------------------------------------------------
CODESEG		
	
; -------------------------------------------------------------------
; Debug procedures
; -------------------------------------------------------------------

; from excercises
PROC printInt
     ARG @@number:dword
     USES eax, ebx, ecx, edx

     mov eax, [@@number]

     ; check if it is negative
     test eax, eax
     jns @@skipSign

     ; print minus sign and negate eax
     push eax
     mov ah, 2h
     mov dl, '-'
     int 21h
     pop eax
     neg eax

	@@skipSign:
		mov ebx, 10    ; divisor
		xor ecx, ecx   ; set all ecx to zero, faster than {mov ecx, 0}

	@@getNextDigit:
		inc ecx        ; count up
		xor edx, edx   ; clear
		div ebx        ; divide by ebx
		push dx        ; save to stack
		test eax, eax  ; check if zero
		jnz @@getNextDigit

		mov ah, 2h     ; 21.9
	@@printDigits:
		pop dx
		add dl, '0'    ; Ascii offset off number symbols
		int 21h        ; print
		loop @@printDigits ; loop until all digits are printed

     ret
ENDP printInt

; from excercises
PROC printIntList
	ARG @@arraypt:dword
	USES eax, ebx, ecx, edx

	mov ebx, [@@arraypt]	; locatie in ebx
	mov ecx, [ebx]			; waarde in ecx

	mov ah, 2h

	@@printLoop:
		add ebx, 4 				; move to next integer
		call printInt, [dword ptr ebx]	; print the number

		mov edx, ','			; print comma
		int 21h
		mov edx, ' '
		int 21h
		loop @@printLoop		; don't forget to loop

		
		mov edx, 13				; cr+lf
		int 21h
		mov edx, 10
		int 21h

	ret
ENDP printIntList

; -------------------------------------------------------------------
; drawing procedures
; -------------------------------------------------------------------

PROC drawEnemy
	ARG @@enem:dword
	USES eax, ebx

	; read position and push on stack
	mov ebx, [@@enem]
	movzx eax, [ebx + enemies.x]
	shr eax, 2
	push eax
	movzx eax, [ebx + enemies.y]
	shr eax, 2
	push eax

	; Draw enemy sprite
	lea eax, [sprite + 8]
	call ReadFile, offset sprite_file, eax, DATASIZE
	pop ebx	; read location from stack
	pop eax
	call drawSprite, offset sprite, VMEMADR, eax, ebx   ;Draw sprite at (0,0)

	ret
ENDP drawEnemy


; Set the video mode
; from excercises
PROC setVideoMode
	ARG 	@@VM:byte
	USES 	eax

	movzx ax,[@@VM]
	int 10h

	ret
ENDP setVideoMode

; from excercises
PROC drawRectangle
	ARG 	@@x0:dword, @@y0:dword, @@w:dword, @@h:dword, @@col: dword
	USES 	eax, ecx, edx, edi ; note: MUL uses edx!

	; Compute the index of the rectangle's top left corner
	mov eax, [@@y0]
	mov edx, SCRWIDTH
	mul edx
	add	eax, [@@x0]

	; Compute top left corner address
	mov edi, VMEMADR
	add edi, eax
	
	; Plot the top horizontal edge.
	mov edx, [@@w]	; store width in edx for later reuse
	mov	ecx, edx
	mov	eax,[@@col]
	rep stosb
	sub edi, edx		; reset edi to left-top corner
	
	; plot both vertical edges
	mov ecx,[@@h]
	@@vertLoop:
		mov	[edi],al		; left edge
		mov	[edi+edx-1],al	; right edge
		add	edi, SCRWIDTH
		loop @@vertLoop
	; edi should point at the bottom-left corner now
	sub edi, SCRWIDTH

	; Plot the bottom horizontal edge.
	mov	ecx, edx
	rep stosb
	ret
ENDP drawRectangle

; Fill the background (for mode 13h) faster
; (uses stosd optimization)
;	* fillcolor: input color
; from excercises
PROC fillBackground
	ARG 	@@fillcolor:byte
	USES 	eax, ecx, edi

	; Initialize video memory address.
	mov	edi, VMEMADR
	
	; copy color value across all bytes of eax
	mov al, [@@fillcolor]	; ???B
	mov ah, al				; ??BB
	mov cx, ax			
	shl eax, 16				; BB00
	mov ax, cx				; BBBB

	; Scan the whole video memory and assign the background colour.
	mov	ecx, SCRWIDTH*SCRHEIGHT/4
	rep	stosd

	ret
ENDP fillBackground

; from SPRITEDP
PROC drawSprite
	ARG @@spritePtr :dword, \
	@@dstPtr :dword, \
	@@x:dword, \
	@@y:dword
	LOCAL @@w:dword, @@h:dword
	USES eax , ebx , ecx , edx , esi , edi

	mov esi , [ @@spritePtr ]
	xor eax , eax
	lodsd ; read width in EAX, first two values are width and height
	mov [@@w] , eax
	lodsd ; read height in EAX
	mov [@@h] , eax
	mov edi , [ @@dstPtr ]
	mov eax , [@@y]
	mov ebx , SCRWIDTH
	mul ebx
	add edi , eax
	add edi , [@@x] ; EDI points to first pixel
	mov ecx , [@@h]
	@@drawLine :
	push ecx
	mov ecx , [@@w] ; need to copy a line of the sprite
	rep movsb ; copy from esi to edi
	add edi , SCRWIDTH
	sub edi , [@@w] ; edi now points to the next line in dst
	pop ecx
	dec ecx
	jnz @@drawLine
	ret
ENDP drawSprite


; -------------------------------------------------------------------
; Other Procedures
; -------------------------------------------------------------------
PROC collision
	;axis-aligned bounding box
	;returns AX = 1 if collision or AX = 0 if no collision
	ARG @@x1: word, @@y1: word, @@h1: word, @@w1: word, @@x2: word, @@y2: word, @@h2: word, @@w2: word
	USES eax, ebx, ecx

	;check the collision!!
	;if (x1 >= x2 + w2) => no collision
	mov ax, [@@x2]
	add ax, [@@w2]
	cmp [@@x1], ax
	jge @@NoHit

	;if (x1 + w1 <= x2) => no collision
	mov ax, [@@x1]
	add ax, [@@w1]
	cmp ax, [@@x2]
	jle @@NoHit
	
	;if (y1 >= y2 + h2) => no collision
	mov ax, [@@y2]
	add ax, [@@h2]
	cmp [@@y1], ax
	jge @@NoHit

	;if (y1 + h1 <= y2) => no collision
	mov ax, [@@y1]
	add ax, [@@h1]
	cmp ax, [@@y2]
	jle @@NoHit
	
	;if all fulfilled
	mov ax, 1
	ret

	;if one not fulfilled
	@@NoHit:
	xor ax, ax
	ret

ENDP collision

PROC collisionBorders
    ARG @@x:word, @@y:word, @@w:word, @@h:word, @@speed_x:word, @@speed_y:word
	USES eax

	mov ax, VIRSCRHEIGHT
	sub ax, [@@h]
	cmp [@@y], ax
	jle @@CheckTopLimit

	mov [@@y], ax
	neg [@@speed_y]
	jmp @@CheckLeftLimit
	
	@@CheckTopLimit:
	cmp [@@y], 0
	jge @@CheckRightLimit
	mov [@@y], 0
	neg [@@speed_y]

	@@CheckRightLimit:
	mov ax, VIRSCRWIDTH
	sub ax, [@@w]
	cmp [@@x], ax
	jle @@CheckLeftLimit

	mov [@@x], ax
	neg [@@speed_x]
	jmp @@done

	@@CheckLeftLimit:
	cmp [@@x], 0
	jge @@done
	mov [@@x], 0
	neg [@@speed_x]

@@done:
	ret
ENDP collisionBorders


PROC movementEnemy
    ARG @@enemy: dword
    USES eax, ebx
	LOCAL @@randnumx: word, @@randnumy: word

    mov ebx, [@@enemy]

	;randomized movement
	;random number for x movement
	call rand16     ;random 16-bit number in AX
	sub ax, 7fffh 	    ; - (2^16) / 2
	sar ax, 13			; / 2^13
	mov [@@randnumx], ax
	
	;random number for y movement
	call rand16     ;random 16-bit number in AX
	;and ax, 0fh
	sub eax, 7fffh   	;now also movement in the negative direction
	sar eax, 13
	mov [@@randnumy], ax

	
    ; change x position
    mov ax, [ebx + enemies.x]
    add ax, [@@randnumx]
	add ax, [ebx + enemies.speed_x]
    mov [ebx + enemies.x], ax

    ; change y position
    mov ax, [ebx + enemies.y]
    add ax, [@@randnumy]	
	add ax, [ebx + enemies.speed_y]
    mov [ebx + enemies.y], ax
	
	
	;apply a limit to x and y to the enemy position so it stays on screen

    call collisionBorders, [ebx + enemies.x], [ebx + enemies.y], SPRITEWIDTH, SPRITEHEIGHT, [ebx + enemies.speed_x], [ebx + enemies.speed_y]

ENDP movementEnemy
; -------------------------------------------------------------------

; wait for @@framecount frames, from dancer example
proc wait_VBLANK
	ARG @@framecount: word
	USES eax, ecx, edx
	mov dx, 03dah 					; Wait for screen refresh
	movzx ecx, [@@framecount]
	
		@@VBlank_phase1:
		in al, dx 
		and al, 8
		jnz @@VBlank_phase1
		@@VBlank_phase2:
		in al, dx 
		and al, 8
		jz @@VBlank_phase2
	loop @@VBlank_phase1
	
	ret 
endp wait_VBLANK

; from excercises
PROC terminateProcess
	USES eax	
	call setVideoMode, 03h
	mov	ax,04C00h
	int 21h
	ret
ENDP terminateProcess

; from SPRITEDP
PROC ReadFile
	ARG	 @@filepathptr: dword,@@dataptr: dword,@@noofbytes: dword 
	USES eax, ebx, ecx, edx, esi, edi
	
	; open file, get filehandle in AX
	mov al, 0 ; read only
	mov edx, [@@filepathptr]
	mov ah, 3dh
	int 21h
	
	mov  edx, offset openErrorMsg
	jc @@print_error ; carry flag is set if error occurs

	; read file data 
	mov bx, ax ; move filehandle to bx
	mov ecx, [@@noofbytes]
	mov edx, [@@dataptr]
	mov ah, 3fh
	int 21h

	mov  edx, offset readErrorMsg
	jc @@print_error
	
	; close file
	mov ah, 3Eh
	int 21h
	
	mov  edx, offset closeErrorMsg
	jc @@print_error
	
	ret

	@@print_error:
	call setVideoMode, 03h
	push ax
	mov  ah, 09h
	int  21h
	
	pop ax
	movzx ebx, al
	call printInt, ebx

	mov	ah,00h
	int	16h
	call terminateProcess	
ENDP ReadFile

; Player input
PROC detectInput
	USES ebx, eax, ecx

	xor eax, eax ; x-directions are in here
	xor ecx, ecx ; y-directions are in here

	@@detectZ:
    mov bl, [offset __keyb_keyboardState + 11h]
    test bl, bl
    jz @@detectD  
	; direction up
	add ecx, -1

	@@detectD:
    mov bl, [offset __keyb_keyboardState + 20h]
    test bl, bl
	jz @@detectQ
	; move right
	add eax, 1

	@@detectQ:
    mov bl, [offset __keyb_keyboardState + 1Eh]
    test bl, bl
    jz @@detectS 
	; move left
	add eax, -1

	@@detectS:
    mov bl, [offset __keyb_keyboardState + 1Fh]
    test bl, bl
    jz @@end
	; move down
	add ecx, 1

	@@end:
	
	call move_player, eax, ecx

	ret
ENDP detectInput


PROC move_player
	ARG @@dir_x:dword, @@dir_y:dword
	USES eax, ebx, ecx

    mov ebx, offset player

	; calculation x position
    mov ax, [ebx + players.speed_x]
	imul [@@dir_x]
	; movement x
    mov cx, [ebx + players.x]
	add cx, ax
    mov [ebx + players.x], cx


	; calculation y position
    mov ax, [ebx + players.speed_y]
	imul [@@dir_y]
	; movement y
    mov cx, [ebx + players.y]
	add cx, ax
    mov [ebx + players.y], cx


	;apply a limit to x and y to the enemy position so it stays on screen
  	call collisionBorders, [ebx + players.x], [ebx + players.y], SPRITEWIDTH, SPRITEHEIGHT, [ebx + players.speed_x], [ebx + players.speed_y]

ENDP move_player

init:
	sti
	cld
	
	; blijkbaar super nodig voor iets
	push ds
	pop	es

	; Set the video mode
    call setVideoMode, 13h
	
	; Start the keyboard handler
	call __keyb_installKeyboardHandler

	; Read the background file
	lea eax, [background + 8]
	call ReadFile, offset background_file, eax, SCRHEIGHT*SCRWIDTH

gameloop:
    ; Player input and movement
	call detectInput

	; stop game when esc is pressed
	movzx eax, [__keyb_rawScanCode] ; last pressed key
	cmp al, 01h					 ; check for escape
	je exit


	; NPC tick
	call movementEnemy, offset enemy1

    ; draw logic
<<<<<<< HEAD
	call fillBackground, 3
=======
	call drawSprite, offset background, VMEMADR, 0, 0 
>>>>>>> f4e9b353938786e3ec55a8a64e1de8eac6a5ec64

	; draw enemies
	call drawEnemy, offset enemy1
	
	; draw player
	mov ebx, offset player
	movzx eax, [ebx + players.x]
	shr eax, 2
	movzx ecx, [ebx + players.y]
	shr ecx, 2
	call drawRectangle, eax, ecx, 20, 20, 6
	


	; end of loop
    call wait_VBLANK, 1
	cmp [gameActive], 0
	je exit
    jmp gameloop


exit:
	call __keyb_uninstallKeyboardHandler
	call terminateProcess
     
STRUC enemies
     x  dw 0  
     y  dw 0  
     speed_x dw 0  
     speed_y dw 0  
     health dw 100
     sprite dd 0
ENDS enemies

STRUC players
	x dw 0
	y dw 0
    speed_x dw 0
    speed_y dw 0
	health db 100
ENDS players


<<<<<<< HEAD
=======

>>>>>>> f4e9b353938786e3ec55a8a64e1de8eac6a5ec64
; -------------------------------------------------------------------
; DATA
; -------------------------------------------------------------------
DATASEG
	player players <0, 0, 1, 1, 100>
    enemy1 enemies <0, 100, 1, 1, 100, 7>

	gameActive db 1

	; from SPRITEDP
	sprite_file db "Images/Ghost.bin", 0
	openErrorMsg db "could not open file", 13, 10, '$'
	readErrorMsg db "could not read data", 13, 10, '$'
	closeErrorMsg db "error during file closing", 13, 10, '$'
	sprite DD SPRITEWIDTH/4, SPRITEHEIGHT/4 ; see that first two elements are double words specifying sprite dimensions
	DB DATASIZE DUP (0)

	background_file db "Images\Backg.bin", 0
	background DD SCRWIDTH, SCRHEIGHT
	DB SCRWIDTH*SCRHEIGHT DUP (0)
; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END init