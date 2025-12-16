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
DATASIZE EQU SPRITEWIDTH*SPRITEHEIGHT/16;bytes of data in file


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

; seperate version to print byte values
PROC printIntByte
     ARG @@number:byte
     USES eax, ebx, ecx, edx

     movzx eax, [@@number]

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
ENDP printIntByte

; from excercises
PROC printIntList
	ARG @@arraypt:dword, @@arrayLnt:dword
	USES eax, ebx, ecx, edx

	mov ebx, [@@arraypt]	; locatie in ebx
	mov ecx, [@@arrayLnt]			; waarde in ecx

	mov ah, 2h

	@@printLoop:
		add ebx, 4 				; move to next integer
		call printInt, [word ptr ebx]	; print the number

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
	
	;check if enemy is alive
	cmp [ebx + enemies.health], 0
	je @@done

	;continue if still alive
	mov eax, [ebx + enemies.x]
	shr eax, 2
	push eax
	mov eax, [ebx + enemies.y]
	shr eax, 2
	push eax

	; Draw enemy sprite
	lea eax, [sprite + 8]
	call ReadFile, offset sprite_file, eax, DATASIZE
	pop ebx	; read location from stack
	pop eax
	call drawSprite, offset sprite, VMEMADR, eax, ebx   ;Draw sprite at (0,0)

	@@done:
	ret
ENDP drawEnemy

PROC drawPlayer
	USES eax, ebx, ecx

	lea eax, [sprite + 8]
	push eax

	; read the direction of the player
	mov ebx, offset player
	movzx eax, [ebx + players.dir]
	
	cmp eax, 1
	jne @@up
	pop eax
	call ReadFile, offset player_right_sprite, eax, DATASIZE
	jmp @@draw

 @@up:
	cmp eax, 2
	jne @@left
	pop eax
	call ReadFile, offset player_up_sprite, eax, DATASIZE
	jmp @@draw

 @@left:
	cmp eax, 3
	jne @@down
	pop eax
	call ReadFile, offset player_left_sprite, eax, DATASIZE
	jmp @@draw

 @@down:
	pop eax
	call ReadFile, offset player_down_sprite, eax, DATASIZE

 @@draw:
	; get player location
	mov eax, [ebx + players.x]
	shr eax, 2
	mov ecx, [ebx + players.y]
	shr ecx, 2

	call drawSprite, offset sprite, VMEMADR, eax, ecx   ;Draw sprite at (0,0)

	ret
ENDP drawPlayer

PROC drawBullet
	ARG @@bullet:dword
	USES ebx, ecx

	; read position and push on stack
	mov ebx, [@@bullet]

	cmp [ebx + bullets.active], 0
	je @@done

	mov ecx, [ebx + bullets.x]
	shr ecx, 2
	push ecx
	mov ecx, [ebx + bullets.y]
	shr ecx, 2
	push ecx

	; Draw bullet sprite
	lea eax, [bullet_sprite + 8]  ;load address to store sprite data
	call ReadFile, offset bullet_file, eax, 10*10
	pop ebx	; read y location from stack
	pop eax ; read x location from stack
	call drawSprite, offset bullet_sprite, VMEMADR, eax, ebx

	@@done:
	ret
ENDP drawBullet

; Set the video mode
; from excercises
PROC setVideoMode
	ARG 	@@VM:byte
	USES 	eax

	movzx ax,[@@VM]
	int 10h

	ret
ENDP setVideoMode

; adapted from excercises
PROC drawRectangle
	ARG 	@@x0:dword, @@y0:dword, @@w:dword, @@h:dword, @@col:dword
	USES 	eax, ecx, edx, edi ; note: MUL uses edx!

	; Compute the index of the rectangle's top left corner
	mov eax, [@@y0]
	mov edx, SCRWIDTH
	mul edx
	add	eax, [@@x0]

	; Compute top left corner address
	mov edi, VMEMADR
	add edi, eax
	
	mov ecx,[@@h]
	
	@@rectLoop:
	push ecx
	; Plot the top horizontal edge.
	mov edx, [@@w]	; store width in edx for later reuse
	mov	ecx, edx
	mov	eax,[@@col]
	rep stosb

	sub edi, edx		; reset edi to left-top corner	
	add	edi, SCRWIDTH	; move to next line
	pop ecx
	loop @@rectLoop

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

; replace all colors 2bh with the color on the background
PROC applyTransparancy
	USES eax, ebx, ecx, edx, edi, esi

	mov edi, VMEMADR
	mov al, 2bh	; transparent color
	mov ecx, SCRHEIGHT*SCRWIDTH

	@@lookForHits:
	REPNE scasb	; look for the next value equal to transparent color

	test ecx, ecx
	jz @@end

	mov ebx, edi	; calculate the difference from the starting adress
	sub ebx, VMEMADR
	sub ebx, 1		; we've already counted one byte extra with scasb

	mov esi, offset background	; copy the value of the background pixel to the vmem adress
	mov dl, [esi+ebx+8]; skip the first two elements of background array (width and height, doubles)
	mov [edi-1], dl 

	jmp @@lookForHits ; look for next one

	@@end:
	ret
ENDP applyTransparancy

; -------------------------------------------------------------------
; Other Procedures
; -------------------------------------------------------------------
PROC collision
	;axis-aligned bounding box
	;returns AX = 1 if collision or AX = 0 if no collision
	ARG @@x1: dword, @@y1: dword, @@h1: dword, @@w1: dword, @@x2: dword, @@y2: dword, @@h2: dword, @@w2: dword RETURNS eax
	USES ebx, ecx

	;check the collision!!
	;if (x1 >= x2 + w2) => no collision
	mov ebx, [@@x2]
	add ebx, [@@w2]
	cmp [@@x1], ebx
	jge @@NoHit

	;if (x1 + w1 <= x2) => no collision
	mov ebx, [@@x1]
	add ebx, [@@w1]
	cmp ebx, [@@x2]
	jle @@NoHit
	
	;if (y1 >= y2 + h2) => no collision
	mov ebx, [@@y2]
	add ebx, [@@h2]
	cmp [@@y1], ebx
	jge @@NoHit

	;if (y1 + h1 <= y2) => no collision
	mov ebx, [@@y1]
	add ebx, [@@h1]
	cmp ebx, [@@y2]
	jle @@NoHit
	
	;if all fulfilled
	mov eax, 1
	ret

	;if one not fulfilled
	@@NoHit:
	xor eax, eax
	ret

ENDP collision

PROC collisionBorders
 ;returns cx = 1, 2, 3, 4 of collision on respectively bottom, top, left, right, cx = 0 if no collision
    ARG @@x:dword, @@y:dword, @@w:dword, @@h:dword RETURNS ecx
	USES eax

	;cx = 0 if no border hit -> initialize
	xor ecx, ecx
	xor eax, eax

 ;check bottom limit
	mov eax, VIRSCRHEIGHT
	sub eax, [@@h]
	cmp [@@y], eax
	jle @@checkTop
	mov ecx, 1  ;moves 1 into cx if bottom is hit
	jmp @@checkLeft

 ;check top limit
	@@checkTop:
	cmp [@@y], 0
	jge @@checkLeft
	mov ecx, 2  ;moves 2 into cx if top is hit

 ;check left limit
	@@checkLeft:
	cmp [@@x], 0
	jge @@checkRight
	mov ecx, 3   ;moves 3 into cx if left is hit

 ;check right limit
	@@checkRight:
	mov eax, VIRSCRWIDTH
	sub eax, [@@w]
	cmp [@@x], eax
	jle @@done
	mov ecx, 4   ;moves 4 into cx if right is hit
	jmp @@done

	@@done:
	ret

ENDP collisionBorders


PROC movementEnemy
    ARG @@enemy: dword
    USES eax, ebx, ecx
	LOCAL @@randnumx: dword, @@randnumy: dword

    mov ebx, [@@enemy]
	
	cmp [ebx + enemies.health], 0
	je @@done

	;randomized movement
	;random number for x movement
	call rand16     ;random 16-bit number in AX
	movzx eax, ax
	sub eax, 7fffh 	    ; - (2^16) / 2
	sar eax, 13			; / 2^13
	mov [@@randnumx], eax
	
	;random number for y movement
	call rand16     ;random 16-bit number in AX
	movzx eax, ax
	sub eax, 7fffh   	;now also movement in the negative direction
	sar eax, 13
	mov [@@randnumy], eax

	
    ; change x position
    mov eax, [ebx + enemies.x]
    add eax, [@@randnumx]
	add eax, [ebx + enemies.speed_x]
    mov [ebx + enemies.x], eax

    ; change y position
    mov eax, [ebx + enemies.y]
    add eax, [@@randnumy]
	add eax, [ebx + enemies.speed_y]
    mov [ebx + enemies.y], eax

	; apply a limit to x and y to the enemy position so it stays on screen

    call collisionBorders, [ebx + enemies.x], [ebx + enemies.y], SPRITEWIDTH, SPRITEHEIGHT

	jmp [Jump_Table_Enemy + ecx*4]
	
	noCollisionEnemy:
	jmp @@done

	bottomHitEnemy:
	mov [ebx + enemies.y], VIRSCRHEIGHT-SPRITEHEIGHT
	mov [ebx + enemies.speed_y], -1
	jmp @@done
	
	topHitEnemy:
	mov [ebx + enemies.y], 0
	mov [ebx + enemies.speed_y], 1
	jmp @@done

	leftHitEnemy:
	mov [ebx + enemies.x], 0
	mov [ebx + enemies.speed_x], 1
	jmp @@done

	rightHitEnemy:
	mov [ebx + enemies.x], VIRSCRWIDTH-SPRITEWIDTH
	mov [ebx + enemies.speed_x], -1
	jmp @@done

	@@done:
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
	call __keyb_uninstallKeyboardHandler
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
	USES ebx, eax, ecx, edx

	xor eax, eax ; x-directions are in here
	xor ecx, ecx ; y-directions are in here

	xor edx, edx		; direction variable

	@@detectD:
    mov bl, [offset __keyb_keyboardState + 20h] ; test D
    test bl, bl
	jz @@detectZ
	; move right
	add eax, 1
	mov edx, 1

	@@detectZ:
    mov bl, [offset __keyb_keyboardState + 11h] ; test Z
    test bl, bl
    jz @@detectQ  
	; direction up
	add ecx, -1
	mov edx, 2

	@@detectQ:
    mov bl, [offset __keyb_keyboardState + 1Eh] ; test Q
    test bl, bl
    jz @@detectS 
	; move left
	add eax, -1
	mov edx, 3

	@@detectS:
    mov bl, [offset __keyb_keyboardState + 1Fh] ; test D
    test bl, bl
    jz @@setDir
	; move down
	add ecx, 1
	mov edx, 4
	

	@@setDir:
	test edx, edx
	jz @@end

	mov ebx, offset player
	mov [ebx + players.dir], dl

 @@end:
	; for some reason this function changes the value of edx, so call this at the end of the procedure
	call move_player, eax, ecx
	ret
ENDP detectInput


PROC move_player
	ARG @@dir_x:dword, @@dir_y:dword
	USES eax, ebx, ecx

    mov ebx, offset player

	; calculation x position
    mov eax, [ebx + players.speed_x]
	imul [@@dir_x]
	; movement x
    mov ecx, [ebx + players.x]
	add ecx, eax
    mov [ebx + players.x], ecx


	; calculation y position
    mov eax, [ebx + players.speed_y]
	imul [@@dir_y]
	; movement y
    mov ecx, [ebx + players.y]
	add ecx, eax
    mov [ebx + players.y], ecx

	; apply a limit to x and y to the enemy position so it stays on screen
  	call collisionBorders, [ebx + players.x], [ebx + players.y], SPRITEWIDTH, SPRITEHEIGHT

	jmp [Jump_Table_Player + ecx*4]
	
	noCollisionPlayer:
	jmp @@border_done

	bottomHitPlayer:
	mov [ebx + players.y], VIRSCRHEIGHT-SPRITEHEIGHT
	jmp @@border_done
	
	topHitPlayer:
	mov [ebx + players.y], 0
	jmp @@border_done

	leftHitPlayer:
	mov [ebx + players.x], 0
	jmp @@border_done

	rightHitPlayer:
	mov [ebx + players.x], VIRSCRWIDTH-SPRITEWIDTH
	jmp @@border_done

	@@border_done:
	; Check for collisions with enemies
	mov esi, offset arrayEnemies
	mov ecx, 5
	xor eax, eax

	@@loop_collide_enemies:
	; Read the pointer of enemy and check their collision
	mov edx, [esi]
	call collision, [ebx + players.x], [ebx + players.y], SPRITEHEIGHT, SPRITEWIDTH, [edx + enemies.x], [edx + enemies.y], SPRITEHEIGHT, SPRITEWIDTH

	; Test if collision was found
	test eax, eax
	jnz @@collision_found

	add esi, 4
	loop @@loop_collide_enemies
	jmp @@done

	; if collision is found, pause the game and reset the player position
	@@collision_found:
	call wait_VBLANK, 40
	mov [ebx + players.x], 20
	mov [ebx + players.y], 50

	; remove health from the player
	mov eax, [ebx + players.health]
	sub eax, 20
	cmp eax, 0
	jle @@endgame

	mov [ebx + players.health], eax
	jmp @@done

	@@endgame:
	call setVideoMode, 03h

	mov ah, 09h
	mov edx, offset death_message
	int 21h

	call terminateProcess

	
	@@done:
	ret

ENDP move_player

PROC move_bullet
	;the bullet has 2 states: active (1: flying) and inactive (0: follows player)
	ARG @@bullet: dword
	USES eax, ebx, ecx, edx

	mov ebx, [@@bullet]

    cmp [ebx + bullets.active], 0
    jne @@flying

	; read if shoot key is pressed
	push ebx
	mov bl, [offset __keyb_keyboardState + 39h] ; test spacebar
	test bl, bl
	pop ebx
	jz @@done

	; shoot
	; set position to player position
    mov eax, [player.x]
    mov [ebx + bullets.x], eax

    mov eax, [player.y]
    mov [ebx + bullets.y], eax	

	; set direction
    mov al, [player.dir]
    mov [ebx + bullets.dir], al
	; set active
	mov [ebx + bullets.active], 1

    jmp @@done

	; state 1
	; move bullet in the direction of the player
	@@flying:
	movzx eax, [ebx + bullets.dir]

	cmp eax, 1
	jne @@up
	mov ecx, [ebx + bullets.x]
	add ecx, [ebx + bullets.speed]
	mov [ebx + bullets.x], ecx
	jmp @@dirDone
	
	@@up:
	cmp eax, 2
	jne @@left
	mov ecx, [ebx + bullets.y]
	sub ecx, [ebx + bullets.speed]
	mov [ebx + bullets.y], ecx
	jmp @@dirDone
	
	@@left:
	cmp eax, 3
	jne @@down
	mov ecx, [ebx + bullets.x]
	sub ecx, [ebx + bullets.speed]
	mov [ebx + bullets.x], ecx
	jmp @@dirDone

	@@down:
	mov ecx, [ebx + bullets.y]
	add ecx, [ebx + bullets.speed]
	mov [ebx + bullets.y], ecx

	@@dirDone:
	call collisionBorders, [ebx + bullets.x], [ebx + bullets.y], 40, 40
	test ecx, ecx
	jz @@done

	;collision with border, reset bullet
	mov [ebx + bullets.active], 0
	
	;check collision with enemies
	mov esi, offset arrayEnemies
	;mov ecx, 5	
	;xor eax, eax

	@@collisionEnemiesLoop:
	mov edx, [esi]
	call collision, [ebx + bullets.x], [ebx + bullets.y], 10, 10, [edx + enemies.x], [edx + enemies.y], SPRITEHEIGHT, SPRITEWIDTH
	
	test eax, eax
	jnz @@collisionEnemy
	
	add esi, 4
	;dec ecx
	;jnz @@collisionEnemiesLoop
	loop @@collisionEnemiesLoop
	
	@@collisionEnemy:
	call wait_VBLANK, 30	;short pause on hit
	mov [ebx + bullets.active], 0
	mov [edx + enemies.health], 0	;enemy dies on hit

	@@done:
	ret
ENDP move_bullet

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

	;Enemies NPC movement
	mov esi, offset arrayEnemies
	mov cx, 5

	loop_movement_enemies:
	mov ebx, [esi]
	call movementEnemy, ebx
	add esi, 4
	dec cx
	jnz loop_movement_enemies
	
	; move bullet
	call move_bullet, offset bullet

	;---------------------
    ; draw logic
	; start with background
	call drawSprite, offset background, VMEMADR, 0, 0 

	; draw enemies
	mov esi, offset arrayEnemies
	mov cx, 5

	loop_draw_enemies:
	mov eax, [esi]
	call drawEnemy, eax
	add esi, 4
	dec cx
	jnz loop_draw_enemies


	; draw bullet
	call drawBullet, offset bullet
	
	; draw player
	call drawPlayer
	
	; apply the transparancy
	call applyTransparancy

	; draw UI
	mov ebx, offset player
	call drawRectangle, 5, 5, [ebx + players.health], 5, [hpBarColor]

	; end of loop
    call wait_VBLANK, 1
    jmp gameloop
exit:
	call terminateProcess
     
STRUC enemies
     x  dd 0  
     y  dd 0  
     speed_x dd 0  
     speed_y dd 0  
     health dd 100
ENDS enemies

STRUC players
	x dd 0
	y dd 0
    speed_x dd 0
    speed_y dd 0
	dir db 0
	health dd 100

ENDS players

STRUC bullets
	x dd 0
	y dd 0
	speed dd 0
	dir db 0        
    active db 0
ENDS bullets
; -------------------------------------------------------------------
; DATA
; -------------------------------------------------------------------
DATASEG
	player players <20, 50, 3, 3, 0, 100>
    enemy1 enemies <500, 70, 1, 1, 100>
	enemy2 enemies <200, 400, -1, 1, 100>
	enemy3 enemies <230, 350, 1, 1, 100>
	enemy4 enemies <330, 130, 1, -1, 100>
	enemy5 enemies <400, 260, -1, -1, 100>
	bullet bullets <40, 200, 6, 1, 0>
	
	arrayEnemies dd offset enemy1, offset enemy2, offset enemy3, offset enemy4, offset enemy5

	; from SPRITEDP
	sprite_file db "Images/Ghost.bin", 0
	openErrorMsg db "could not open file", 13, 10, '$'
	readErrorMsg db "could not read data", 13, 10, '$'
	closeErrorMsg db "error during file closing", 13, 10, '$'
	sprite DD SPRITEWIDTH/4, SPRITEHEIGHT/4 ; see that first two elements are double words specifying sprite dimensions
	DB DATASIZE DUP (0)

	hpBarColor dd 27h ; written here so debugging to aid debugging

	player_up_sprite db "Images/PUp.bin", 0
	player_down_sprite db "Images/PDown.bin", 0
	player_left_sprite db "Images/PLeft.bin", 0
	player_right_sprite db "Images/PRight.bin", 0
	
	bullet_file db "Images/Bull.bin", 0
	bullet_sprite dd 10, 10
	db DATASIZE DUP (0)

	background_file db "Images\Backg.bin", 0
	background DD SCRWIDTH, SCRHEIGHT
	DB SCRWIDTH*SCRHEIGHT DUP (0)

	death_message db "You died!", 10, 13, '$'
	
	; Jump Tables for collision handling
	Jump_Table_Player dd noCollisionPlayer, bottomHitPlayer, topHitPlayer, leftHitPlayer, rightHitPlayer
	Jump_Table_Enemy dd noCollisionEnemy, bottomHitEnemy, topHitEnemy, leftHitEnemy, rightHitEnemy
; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END init