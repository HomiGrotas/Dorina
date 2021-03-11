IDEAL
MODEL small
STACK 100h

; ToDO:
;		string type update
;		math operators:   +=, -=, *=, /=
;		boolean opetatos: >, ==, <, !=
;		fix bug of one char var name
;		condition
;		while loop

; HowTo: get var name: insert var length, insert to stack 2 by 2  mem:[length, name, type, value, length, name, type, value...]

DATASEG

; constants
false  equ 0
true   equ 1
DEBUG  equ true	; DEBUG mode

memorySize equ 500
lineLength equ 100
param1 equ [bp + 4]
param2 equ [bp + 6]
param3 equ [bp + 8]
localVar1 equ [bp - 2]
localVar2 equ [bp - 4]
localVar3 equ [bp - 6]

; variables types
integer equ 0
string equ 1
boolean equ 2


memoryVariables dw memorySize dup('*')     ; buffer array - stores the data from the file
memoryInd dw 0 ; can be up to 65,535

; variables for file opening
filename db 'testfile.txt',0	  ; file to operate on
filehandle dw '.'					  ; file handle

; variables for reading the file
buffer db lineLength dup('#')
char db '&'

; keywords
shoutKeyword db 'shout'

; messages
ErrorMsgCouldntFindOp db 'Error: couldnt find an operator or a keyword...', '$'
ErrorMsgOpen db 'Error: while opening code file...','$'   ; error message
ErrorVarDoesntExists db 'Error: var doesnt exists', '$'
MemoryPrintMsg db '----------------------  MEMORY ----------------------', '$'
FinishMsg db 'Finished!', '$' ; finished the program

CODESEG


;------------------------------------------------------------------------------------------------------
;  Macros
;------------------------------------------------------------------------------------------------------

;-------------------------------------------
; Macro: newLine
;   macro to go down a line in console
;-------------------------------------------
macro newLine
	; new line
	mov dl, 10		; ascii ---> 10 New Line
	mov ah, 02h
	int 21h
	mov dl, 13		; ascii ---> 13 Carriage Return
	mov ah, 02h
	int 21h
endm

;-------------------------------------------
; Macro: printMsg
;   macro to print a string as parameter
;-------------------------------------------
macro printMsg msg_to_print
    mov dx, offset &msg_to_print
	mov ah, 9h
	int 21h
endm


;------------------------------------------------------------------------------------------------------
; Helpers procedures - print array, get string, 
;------------------------------------------------------------------------------------------------------

;---------------------
; print array
; param: array length, array offset
;---------------------
proc printArray
	push bp
	mov bp, sp
	
	push bx
	push cx
	push si
	push ax
	push dx
	
	
	mov bx, param1	; array offset 
	mov cx, param2  ; array length
	xor si, si
	
	newLine
	mov ah, 2  		; write mode	
	
	; print array
	printLoop:
		mov dl, [bx + si]
		int 21h
		inc si
		loop printLoop
	
	pop dx
	pop ax
	pop si
	pop cx
	pop bx
	
	pop bp
	ret 4
endp printArray


;-------------------------------
; compare string procedure - with same length and one is the opposite of the other
; params: length, offset to var name(memory), offset to var name(stack)
; returns with dh
;-------------------------------
proc cmpStrings
	push bp
	mov bp, sp
	
	push si
	push di
	push ax
	push bx
	push cx
	
	mov cx, param1 ; length of var name					
	shr cx, 1	   ; comparing word size
	
	mov si, param2 ; offset for first name
	mov bx, param3 ; offset for second name
	
	; loop through the two names (checks in pairs for effiecenty)
	cmpLoop:
		mov ax, [bx]
		mov dx, [si]
		cmp ax, dx
		jne notEq
		
		add si, 2
		add bx, 2
		loop cmpLoop
	
	
	mov ax, param1
	test ax, 1
	jz equals
	
	; compare digit that was left
	mov ah, [byte ptr bx]
	mov dh, [byte ptr si]
	cmp ah, dh
	jne notEq
	
	equals:
		mov dh, true ; default return value - equal
		jmp finishCmpStrings
	
	notEq:
		xor dh, dh ; 0- not equal
	
	finishCmpStrings:
		pop cx
		pop bx
		pop ax
		pop di
		pop si
		
		pop bp
		ret 6
endp cmpStrings


;------------------------------------------------------------------------------------------------------
;  Files management - Start
;------------------------------------------------------------------------------------------------------
; all procedures use constants

;-------------------------
; open file procedure
; opens file which his name is in filename variable
;-------------------------
proc OpenFile
	; Open file
	mov ah, 3Dh
	xor al, al
	lea dx, [filename]
	int 21h
	jc openerror
	mov [filehandle], ax
	ret
	
	openerror :
		printMsg ErrorMsgOpen
		jmp exit
	ret
endp OpenFile


;---------------------------------------------
; readLineByLine procedure
; reads whole line and calcs its length
;---------------------------------------------
proc readLineByLine
	xor si, si					  	; buffer length
    read_line:
            mov ah, 3Fh      		;read file
            mov bx, [filehandle]
            lea dx, [char]			; location to store char
            mov cx, 1				; read 1 char

            int 21h					; DOS interrupts

            cmp ax, 0     			;EOF (end of file)
            je EOF

            mov al, [char]			; for comparing the char

            cmp al, 0Ah    			; line feed
            je LF

            mov [offset buffer + si], al			; location in the buffer
            inc si					; inc the location in the buffer
            jmp read_line
			
	EOF: ; end of file
		jmp finish
	
	LF:	; line feed - handle the line and return reading		
		push si 	; buffer length
		call handleOneLineCommand
		xor si, si				; reset buffer length
		jmp read_line			; keep reading
		
	finish:	
		ret
endp readLineByLine

;--------------------
; closeFile procedure
;---------------------
proc closeFile
	mov ah, 3Eh
	mov bx, [filehandle]
	int 21h
	ret
endp closeFile


;------------------------------------------------------------------------------------------------------
; Handlers procedures - understand command 
;------------------------------------------------------------------------------------------------------

;-----------------------------------
; handleOneLineCommand procedure
; param: buffer length
;-----------------------------------
proc handleOneLineCommand
	push bp
	mov bp, sp
	
	push ax
	push bx
	push cx
	
	mov cx, param1    			; buffer length
	
	; print if in DEBUG mode
	mov ah, DEBUG
	cmp ah, 0
	je cmpOp
	
	; print line
	lea bx, [buffer]			; buffer offset
	
	
	; print buffer
	push cx
	push bx
	call printArray
	newLine
	
	cmpOp:
		push cx
		call findOp
		
		; check if operator is '='
		cmp dx, '='
		je handleAssignment
		
		; check if operator is '+='
		cmp dx, '+='
		je handlePlus
		
		; check if shout keyword is used
		push offset shoutKeyword
		push offset buffer
		push 5
		call cmpStrings
		cmp dh, true
		je handleShout
		
		printMsg ErrorMsgCouldntFindOp
		jmp exit
	
	handleAssignment:				; = operator
		push cx						; buffer length
		call assignemtFromBuffer
		jmp finishHandleOneLineCommand
	
	handlePlus:
		push cx
		call plus
		jmp finishHandleOneLineCommand
	
	handleShout:					; shout keyword
		push cx						; buffer length
		call handleShoutKeyword
		
	finishHandleOneLineCommand:
		pop cx
		pop bx
		pop ax
		
		pop bp
		ret 2
endp handleOneLineCommand

;--------------------------------------
; hex to ascii procedure
; value in ax
; prints the ascii value
;--------------------------------------
proc hexToAscii 
	push ax bx cx dx si di bp es
	mov bx, 10	; to divide by 10
	xor cx, cx
	
	loop1:
		mov dx, 0
		div bx			; ax /= 10
		add dl, 30h		; remainder, convert to ascii value
		push dx			; insert into stack in order to change printing order
		inc cx			; for the second loop (amount of iterations)
		cmp ax, 10		; if there is more than 1 digit
		jge loop1
	
	; print digits
	add al, 30h
	mov dl, al
	mov ah, 2		; ah=2, 21h interrupt
	loop2:
		int 21h
		pop dx
		loop loop2
	int 21h		; print last digit
	
	pop es bp di si dx cx bx ax
	ret
endp hexToAscii


;-----------------------------------------
; handle shout keyword procedure
;	checks if content is a string/ var and prints accordingly
;-----------------------------------------
proc handleShoutKeyword
	push bp
	mov bp, sp
	
	push ax
	push dx
	push bx
	push cx
	
	mov cx, param1		; buffer length
	mov si, 6			; 5 shout length, 1 stand on command content
	mov ah, 2			; write char
	
	; check if need to print a string or a variable
	mov dl, [buffer + si]
	cmp dl, '"'
	jne printVar
	
	; printStr:
		inc si		; 1 "
		shoutPrintLoop:
			mov dl, [buffer + si]
			cmp dl, '"'
			je finishHandleShoutKeyword
			
			int 21h	 ; print char
			
			inc si
			jmp shoutPrintLoop
	
	
	printVar:
		; check whether var exists and get its index
		lea bx, [buffer]
		add bx, si
		sub cx, 7
		
		test cx, 1
		jz evenLength
		dec cx		; due to odd length of shout command, the checkExistsVar procedure will increase the var name length by 1
		
		evenLength:
		push bx		; offset of current var
		push cx		; var name length
		call checkExistsVar		; bx now holds the var memory index
		cmp dh, true
		jne varDoesntExists
		
		; get var value
		push bx
		call getValue	 ; value in dx
		
		add bx, [bx]
		mov al, [bx+2]	; type
		cmp al, integer
		je printIntVar
		
		; print value - str
		int 21h
		xchg dl, dh
		int 21h
		jmp finishHandleShoutKeyword
		
		printIntVar:
			mov ax, dx
			call hexToAscii

	
	jmp finishHandleShoutKeyword
	varDoesntExists:
		printMsg ErrorVarDoesntExists
		newLine
	
	finishHandleShoutKeyword:
		newLine					; go a line down in console
		pop cx
		pop bx
		pop dx
		pop ax
		
		pop bp
		ret 2
endp handleShoutKeyword


;-------------------------------------------
; checkExistsVar procedure
; checks whether a variable exists in the memory
; params: var name length, array offset
; returns: dh (0/ 1), si: index in memory
;-------------------------------------------
proc checkExistsVar
	push bp
	mov bp, sp
	
	
	push ax
	push cx
	push di
		
	mov ax, param1 		; var name length
	
	mov cx, param2		; var location in buffer
	xor dh, dh

	lea bx, [memoryVariables]
	
	; handle odd buffer length
	push ax
	
	push 1
	call getValFromBuffer
	cmp ax, 3031
	jnb lengthOk
	
	
	pop ax
	inc ax
	push ax
	
	lengthOk:
	pop ax
	xor si, si	   ; memory index
	
	; finish if memory is empty
	cmp si, [memoryInd]
	je finishCheckExistsVar  ; memoryInd == 0
	
	; keep checking while si < memoryInd
	loopMemory:
		; check have same length
		mov dx, [bx + si]
		cmp dx, ax
		jne keepLooping
		
		; skip length
		add si, 2
		add bx, si

		; compare names
		push cx		; var location in buffer
		push bx		; memory offset
		push ax 	; variable length
		call cmpStrings
		
		; return to original pointer
		sub bx, si
		sub si, 2
		
		; if names are equal
		cmp dh, true
		je found
				
		keepLooping:
			; point to next variable
			add si, [bx + si]	; si += var name length 
			add si, 5			; si += 5 (type 1, length 2, 2 val)
			
			cmp si, [memoryInd]	; keep looping while si < memoryInd
			jb loopMemory
	
	xor dh, dh	   ; default - var doesn't exists
	jmp finishCheckExistsVar
	
	; var exists
	found:
		mov dh, true
		mov bx, si	; index of the start of the variable in memory
		
	finishCheckExistsVar:		
		pop di
		pop cx
		pop ax
		
		pop bp
		ret 4
endp checkExistsVar





;---------------------------------------------------------------
; handle var and memory procedure - inserts new var to memory
; params: None
; mem:[length, name, type, value, length, name, type, value...]
;---------------------------------------------------------------
proc insertVarToMemory
	push bp
	mov bp, sp
	sub sp, 2
	
	; save registers
	push ax
	push bx
	push cx
	push dx
	push di
	
	xor si, si				; buffer index
	mov di, [memoryInd]		; memory index
	
	mov localVar1, di
	add di, 2				; save location for length
	
	insertName:
		mov ah, [buffer + si]
		
		cmp ah, ' '									; stop inserting if reached a space (' ')
		je finishedInsertName
		
		mov [byte ptr memoryVariables + di], ah		; mov char to memory
		inc di										; move to next location in memory
		inc si
		
		jmp insertName
	
	finishedInsertName:
		; insert length
		mov bx, localVar1
		mov [bx], si
		
		continue:

		
		; insert value
		mov al, [buffer + si + 3]
			
		
		inc di
		cmp al, '"'
		je insert1ValStr
		
		mov ah, [buffer + si + 4]
		
		; if the second char is carriage return - insert just the first char
		cmp ah, 13 ; carriage return
		jne insert2ValInt
		xchg ah, al
		mov al, 30h
		
		insert2ValInt:
			sub ah, 30h		; get decimal value
			sub al, 30h
			mov dx, ax
			xor ax, ax
			mov al, dl
			mov dl, 10
			mul dl
			xor dl, dl
			xchg dh, dl
			add ax, dx
			
			; insert type
			mov  [byte ptr memoryVariables + di - 1], integer
			
			; insert value
			mov  [memoryVariables + di], ax
			jmp finishInserting
			
		insert1ValStr:
			mov al, [buffer + si + 4]
			mov ah, [buffer + si + 5]
			cmp ah, '"'
			jne insert2ValStr
			xor ah, ah
			
			insert2ValStr:
				; insert type
				mov  [byte ptr memoryVariables + di - 1], string
				
				; insert value
				mov  [memoryVariables + di], ax
	
	finishInserting:
		add [memoryInd], si	; length of name
		add [memoryInd], 5	;  2length, 2value, 1type, 1next location
		
		add sp, 2
		
		pop di
		pop dx
		pop cx
		pop bx
		pop ax
		pop bp
		ret 
endp insertVarToMemory



;----------------------------------
; findOp procedure
; param: buffer length
; return dx (operator)
;----------------------------------
proc findOp
	push bp
	mov bp, sp
	
	push ax
	push bx
	push cx
	push si
	
	mov cx, param1    			; buffer length
	lea bx, [buffer]			; buffer offset
	xor si, si
	xor dh, dh
	
	; loop until reaches a space
	loopSearch:
		mov al, [bx + si]
		inc si
		cmp al, ' '
		jne loopSearch
	
	; check if operator is one char
	mov dl, [bx + si]
	mov al, [bx + si + 1]
	cmp al, ' '
	je finishFindOp
	
	; move 2 chars operator to dx
	mov dh, dl
	mov dl, [bx + si + 1]
	
	finishFindOp:
		pop si
		pop cx
		pop bx
		pop ax
		pop bp
		ret 2
endp findOp


;---------------------------------
; assignemtFromBuffer procedure
; param: buffer length
;---------------------------------
proc assignemtFromBuffer
	push bp
	mov bp, sp
	
	sub sp, 2
	
	push ax
	push bx
	push cx
	push si
	
	xor ah, ah
	lea bx, [buffer]	; buffer offset
	mov cx, param1		; buffer length
	xor si, si
		
	; callInsertion
	sub cx, 6  							; get length of var (odd length is handled later)
	
	; check if var already exists
	push offset buffer
	push cx  							; var name length
	call checkExistsVar					; var index in bx
	mov localVar1, bx
	
	; check if var exists
	cmp dh, 1
	je updateVal
	
	; if var doesn't exists - insert to memory
	call insertVarToMemory
		
	jmp finishAssignemtFromBuffer
	
	updateVal:
		; get var value
		push 1  ; operator length
		call getValFromBuffer		; ax <- new value
		
		; check var type
		add bx, [bx]	; skip var name
		mov bh, [bx+2]  ; get var type
		cmp bh, string
		je updateVar
		
		; if it's int type -> get decimal from ascii
		cmp ah, 0	; check if there is only one digit
		jne TwoDigitsValInt
		xchg ah, al
		mov al, 30h
		
		TwoDigitsValInt:
			sub ah, 30h		; get decimal value
			sub al, 30h
			mov dx, ax
			xor ax, ax
			mov al, dl
			mov dl, 10
			mul dl
			xor dl, dl
			xchg dh, dl
			add ax, dx
			
			
		updateVar:
			mov bx, localVar1
			push ax
			call updateValProc			; update the variable value

	
	finishAssignemtFromBuffer:
		; reverse param pushes
		pop si
		pop cx
		pop bx
		pop ax
		
		add sp, 2
		pop bp
		ret 2
endp assignemtFromBuffer



;----------------------------------
;	getValue (from memory) procedure
; params: index of variable
; returns: dx - value of variable
;----------------------------------
proc getValue
	push bp
	mov bp, sp
	
	push bx
		
	; bx should point for the length of the variable
	lea bx, [memoryVariables]
	add bx, param1
	
	; skip var name
	add bx, [bx] ; bx += var name length
	mov dx, [bx + 3]	; skip type 1, var name length 2
		
	pop bx
	pop bp
	ret 2
endp getValue

;----------------------------------
; updateVal procedure
; params:  new value (uses bx as source index)
;----------------------------------
proc updateValProc
	push bp
	mov bp, sp
	
	mov dx, param1		; new value
	
	; skip var name
	add bx, [bx] ; bx += var name length
	
	; update value
	mov [bx + 3], dx  ; skip type and move to val area
	
	pop bp
	ret 2
endp updateValProc


;----------------------------------------
; 	getValFromBuffer procedure
; param: operator length
; returns: ax
;----------------------------------------
proc getValFromBuffer
	push bp
	mov bp, sp
	
	; save registers
	push bx
	push cx
	push dx
	push di
	
	mov bx, param1	; operator length
	
	xor si, si				; buffer index
	loopBuffer:
		mov ah, [buffer + si]
		inc si
		cmp ah, ' '									; stop looping if reached a space (' ')
		je finishedLoopingNameBuffer
		jmp loopBuffer		; keep looping
	
	finishedLoopingNameBuffer:
		add si, bx		; add operator length
		mov al, [buffer + si + 1]		; get value
		mov ah, [buffer + si + 2]
	
	; if the second char is carriage return - insert just the first char
	cmp ah, 13 					; carriage return
	jne finishLoopingBuffer
	xor ah, ah
	
	finishLoopingBuffer:		
		pop di
		pop dx
		pop cx
		pop bx
		pop bp
		ret 2
endp getValFromBuffer


; checks whether dl holds a digit
; return: dh (true/ false)
proc isDigit
	xor dh, dh
	
	; 30h <= dl <= 39h
	cmp dl, 30h
	jb isDigitEnd
	cmp dl, 39h
	ja isDigitEnd
	
	mov dh, true		; dl holds a digit
	isDigitEnd:
		ret
endp isDigit

;--------------------------------------------------------------------------------
;	math operators
;--------------------------------------------------------------------------------



;--------------------
; plus procedure

proc plus
	push bp
	mov bp, sp
	sub sp, 2
	
	mov cx, param1		; buffer length
	dec cx
	
	; check var length (buffer length - value length - 2 space, 2 operator)
	push 2
	call getValFromBuffer
	cmp ax, 3031
	jb plusLengthOk
	
	dec cx ; 1 val
	
	plusLengthOk:
	sub cx, 5	;  2 space, 2 operator, 1 val
	
	; check assigned var exists
	push offset buffer
	push cx
	call checkExistsVar
	mov localVar1, bx
	; raise error if var doesnt exists
	cmp dh, 0
	je errorVarDoesntExistsPlus
	
	; get current var value
	push si
	call getValue				; dx hold current value
	
	; get value from buffer
	push 2
	call getValFromBuffer		; ax holds value from buffer
	cmp ah, 0
	je addDigit
	
	; calc addition of var and 2 digits value
	sub ah, 30h		; get decimal value
	sub al, 30h
	xchg ah, al		; add units
	add dl, al
	xor al, al
	xchg ah, al
	mov cl, 10
	mul cl		; get value in tens
	add dx, ax	; add tens
	mov ax, dx
	jmp update2Digits
	
	; calc addition of var and a digit 
	addDigit:
		sub al, 30h
		add dl, al
		mov ax, dx
	
	; updates var
	update2Digits:
		mov bx, localVar1		; location of var in memory
		push ax
		call updateValProc
	
	jmp finishPlus
	errorVarDoesntExistsPlus:
		printMsg ErrorVarDoesntExists
		jmp exit
	
	finishPlus:
		add sp, 2
		pop bp
		ret 2
endp plus

;----------------
; START
;----------------
start:
	mov ax, @data
	mov ds, ax
	
	call OpenFile
	call readLineByLine
	call closeFile
	
		
	; if debug mode is on - print memory
	mov ah, DEBUG
	cmp ah, 0
	je exit
	
	; print memory
	newLine
	newLine
	newLine
	printMsg MemoryPrintMsg
	push memorySize
	push offset memoryVariables
	call printArray
	

exit:
	newLine
	newLine
	newLine
	newLine
	printMsg FinishMsg
	mov ax, 4c00h
	int 21h
	END start