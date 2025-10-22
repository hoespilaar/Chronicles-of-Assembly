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

; -------------------------------------------------------------------
; CODE
; -------------------------------------------------------------------
CODESEG		
	
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
	
init:
	sti
	cld

    

mainLoop:
    ; Player input and movement



    ; draw logic
    call wait_VBLANK, 1
    jmp gameloop


exit:
	mov	ax,4C00h 	; terminate
	int 21h

; -------------------------------------------------------------------
; DATA
; -------------------------------------------------------------------
DATASEG

; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END init
