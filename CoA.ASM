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

; -------------------------------------------------------------------
; CODE
; -------------------------------------------------------------------
CODESEG		
	
; -------------------------------------------------------------------
; Debug procedures
; -------------------------------------------------------------------

proc printInt
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
PROC setVideoMode
	ARG 	@@VM:byte
	USES 	eax

	movzx ax,[@@VM]
	int 10h

	ret
ENDP setVideoMode

PROC drawRectangle_dword
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
ENDP drawRectangle_dword

; Fill the background (for mode 13h) faster
; (uses stosd optimization)
;	* fillcolor: input color
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


; -------------------------------------------------------------------
; Other Procedures
; -------------------------------------------------------------------
; wait for @@framecount frames
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

PROC terminateProcess
	USES eax	
	call setVideoMode, 03h
	mov	ax,04C00h
	int 21h
	ret
ENDP terminateProcess

init:
	sti
	cld

    call setVideoMode, 13h
	
	call fillBackground, 3
	
	call __keyb_installKeyboardHandler

gameloop:
    ; Player input and movement

	; stop game when esc is pressed
	movzx eax, [__keyb_rawScanCode] ; last pressed key
	cmp al, 01h					 ; check for escape
	je exit


    ; draw logic
	
	
	; end of loop
    call wait_VBLANK, 1
	cmp [gameActive], 0
	je exit
    jmp gameloop


exit:
	call __keyb_uninstallKeyboardHandler
	call terminateProcess

; -------------------------------------------------------------------
; DATA
; -------------------------------------------------------------------
DATASEG
	gameActive db 1
; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END init
