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

; compile-time constants (with macros)
VMEMADR EQU 0A0000h	; video memory address
SCRWIDTH EQU 320	; screen witdth
SCRHEIGHT EQU 200	; screen height


SPRITEWIDTH EQU 20
SPRITEHEIGHT EQU 20
DATASIZE EQU SPRITEWIDTH*SPRITEHEIGHT;bytes of data in file

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

PROC movementEnemy
    ARG @@enemy: dword
    USES eax, ebx, ecx

    mov ebx, [@@enemy] 

    ; change x position
    mov ax, [ebx + enemies.x]
    add ax, [ebx + enemies.speed_x]

    ; change y position
    mov ax, [ebx + enemies.y]
    add ax, [ebx + enemies.speed_y]
    mov [ebx + enemies.y], ax

    ret
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
	mov  ah, 09h
	int  21h
	
	mov	ah,00h
	int	16h
	call terminateProcess	
ENDP ReadFile

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

gameloop:
    ; Player input and movement

	; stop game when esc is pressed
	movzx eax, [__keyb_rawScanCode] ; last pressed key
	cmp al, 01h					 ; check for escape
	je exit


    ; draw logic
	call fillBackground, 3

	lea eax, [sprite + 8]
	call ReadFile, offset sprite_file, eax, DATASIZE
	call drawSprite, offset sprite, VMEMADR, 20,20   ;Draw sprite at (0,0)

	

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
     color db 1
     health db 100
     sprite dd 0
ENDS enemies



; -------------------------------------------------------------------
; DATA
; -------------------------------------------------------------------
DATASEG
     enemy1 enemies <1, 2, 3, 4, 5, 6, 7>
	gameActive db 1

	; from SPRITEDP
	sprite_file db "Images/Ghost.bin", 0
	openErrorMsg db "could not open file", 13, 10, '$'
	readErrorMsg db "could not read data", 13, 10, '$'
	closeErrorMsg db "error during file closing", 13, 10, '$'
	sprite DD SPRITEWIDTH, SPRITEHEIGHT; see that first two elements are double words specifying sprite dimensions
	DB DATASIZE DUP(0)
; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END init

