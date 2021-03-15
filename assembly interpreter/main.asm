IDEAL
MODEL small
STACK 100h

; ToDO:
;		condition
;		while loop

; HowTo:  mem:[length (word), name (unlinited), type (int/str), value (word), length, name, type, value...]

DATASEG

; constants
false  equ 0
true   equ 1
DEBUG  equ false	; DEBUG mode

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
ErrorMsgOpen db 'Error: while opening code file...','$'   ; error messages
ErrorVarDoesntExists db "Error: var doesn't exists", '$'
ErrorDivideByZero db "Error: can't divide by zero", '$'
MemoryPrintMsg db '----------------------  MEMORY ----------------------', '$'
FinishMsg db 'Finished Succesfuly!', '$' ; finished the program
TrueMsg db 'True', '$'
FalseMsg db 'False', '$'

CODESEG
jumps		; support far jumps


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
	
	cmp cx, 0			; if it's just one char -> cmp just byte
	jne cmpLoop
	
	mov ah, [bx]
	mov dh, [si]
	cmp dh, ah
	je equals
	jmp notEq
	
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
		
		;---------------------
		; math operators check:
		
		; check if operator is '='
		cmp dx, '='
		je handleAssignment
		
		; check if operator is '+='
		cmp dx, '+='
		je handlePlus
		
		; check if operator is '-='
		cmp dx, '-='
		je handleMinus
		
		; check if operator is '*='
		cmp dx, '*='
		je handleMultiply
		
		; check if operator is '/='
		cmp dx, '/='
		je handleDivide
		
		; check if operator is '%='
		cmp dx, '%='
		je handleMudolo
		
		; check if operator is '^='
		cmp dx, '^='
		je handlePower
		
		;---------------------
		; boolean operators check:
		cmp dx, '<'
		je handleSmaller
		
		cmp dx, '>'
		je handleGreater
		
		cmp dx, '=='
		je handleEquals
		
		cmp dx, '!='
		je handleNEquals
		
		cmp dx, '<='
		je handleSmallerE
		
		cmp dx, '>='
		je handleBiggerE
		
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
	
	handlePlus:						; += operator
		push cx						; buffer length
		push '+='
		call mathOperators
		jmp finishHandleOneLineCommand
		
	handleMinus:					; -= operator
		push cx						; buffer length
		push '-='
		call mathOperators
		jmp finishHandleOneLineCommand
	
	handleMultiply:					; *= operator
		push cx						; buffer length
		push '*='
		call mathOperators				
		jmp finishHandleOneLineCommand
		
	handleDivide:					; /= operator
		push cx						; buffer length
		push '/='
		call mathOperators				
		jmp finishHandleOneLineCommand
		
		
	handleMudolo:					; %= operator
		push cx						; buffer length
		push '%='
		call mathOperators				
		jmp finishHandleOneLineCommand
	
	handlePower:					; ^= operator
		push cx						; buffer length
		push '^='
		call mathOperators				
		jmp finishHandleOneLineCommand
	
	
	handleSmaller:					; < operator
		push cx						; buffer length
		push '<'
		call booleanOperators
		jmp finishHandleOneLineCommand
		
	handleGreater:					; > operator
		push cx						; buffer length
		push '>'
		call booleanOperators
		jmp finishHandleOneLineCommand
		
	handleEquals:					; == operator
		push cx						; buffer length
		push '=='
		call booleanOperators
		jmp finishHandleOneLineCommand
		
	handleNEquals:					; != operator
		push cx						; buffer length
		push '!='
		call booleanOperators
		jmp finishHandleOneLineCommand
		
	handleSmallerE:					; <= operator
		push cx						; buffer length
		push '<='
		call booleanOperators
		jmp finishHandleOneLineCommand
		
	handleBiggerE:					; >= operator
		push cx						; buffer length
		push '>='
		call booleanOperators
		jmp finishHandleOneLineCommand
	
	
	handleShout:					; shout keyword
		push cx						; buffer length
		call handleShoutKeyword
		jmp finishHandleOneLineCommand
		
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
	mov bx, 10			; to divide by 10
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
	cmp dl, '0'		; if first digit is a zero -> skip
	je loop2
	int 21h
	
	loop2:
		pop dx
		int 21h		; print last digit
		loop loop2
	
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
			call hexToAscii		; print var

	
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
	;
	xor si, si	   ; memory index
	lea bx, [memoryVariables]

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
		cmp ah, 13 				; carriage return
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
		add [memoryInd], si		; length of name
		add [memoryInd], 5		;  2length, 2value, 1type, 1next location
		
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
	sub cx, 6  					; get length of var (odd length is handled later)
	mov bx, cx
	
	; handle 1 digit value
	push 1
	call getValFromBuffer
	
	cmp ax, 3031
	jnb lengthAferValueCheck	; value if more than 1 digit
	
	inc bx
	
	lengthAferValueCheck:
		cmp al, '"'
		jne lengthAfterStrCheck
		sub bx, 2
		
		push 2
		call getValFromBuffer
		cmp ah, '"'
		jne lengthAfterStrCheck
		inc bx
	
	lengthAfterStrCheck:
	mov cx, bx	   ; ax <- var name length
	
	; check if var already exists
	push offset buffer
	push cx  							; var name length
	call checkExistsVar					; var index in bx
	mov localVar1, bx					; var index
	
	; check if var exists
	cmp dh, 1
	je updateVal
	
	; if var doesn't exists - insert to memory
	call insertVarToMemory
		
	jmp finishAssignemtFromBuffer
	
	updateVal:
		; check var type
		add bx, [bx]				; skip var name
		mov bh, [bx+2]  			; get var type
		cmp bh, string
		je updateStr
		
		; get var value
		push 1  ; operator length
		call getValFromBuffer			; ax <- new value
		
		; if it's int type -> get decimal from ascii
		cmp ah, 0						; check if there is only one digit
		jne TwoDigitsValInt
		xchg ah, al
		mov al, 30h
		
		TwoDigitsValInt:
			sub ah, 30h					; get decimal value
			sub al, 30h
			mov dx, ax
			xor ax, ax
			mov al, dl
			mov dl, 10
			mul dl
			xor dl, dl
			xchg dh, dl
			add ax, dx
			jmp updateVar		
		
		updateStr:	; get var value
			push 2 						; operator length + "
			call getValFromBuffer		; ax <- new value
			cmp ah, '"'					; if the str is 1 digit -> delete msb
			jne updateVar
			xor ah, ah
			
		updateVar:
			mov bx, localVar1			; var index
			push ax						; var new value
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
	add bx, [bx] 		; bx += var name length
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
	
	mov dx, param1			; new value
	
	; skip var name
	add bx, [bx] 			; bx += var name length
	
	; update value
	mov [bx + 3], dx  		; skip type and move to val area
	
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
	
	mov bx, param1						; operator length
	
	xor si, si							; buffer index
	loopBuffer:
		mov ah, [buffer + si]
		inc si
		cmp ah, ' '						; stop looping if reached a space (' ')
		je finishedLoopingNameBuffer
		jmp loopBuffer					; keep looping
	
	finishedLoopingNameBuffer:
		add si, bx						; add operator length
		mov al, [buffer + si + 1]		; get value
		mov ah, [buffer + si + 2]
	
	; if the second char is carriage return - insert just the first char
	cmp ah, 13 							; carriage return
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



;--------------------------------------------------------------------------------
; Operators
;--------------------------------------------------------------------------------


;---------------------------------------------------------
; math operator procedure
; handles all the math operators
; params: buffer length, operator
;---------------------------------------------------------
proc mathOperators
	push bp
	mov bp, sp
	sub sp, 2
	
	push ax
	push bx
	push cx
	push dx
	
	mov cx, param2		; buffer length
	dec cx				; remove CR (carriage return)
	
	; check var length (buffer length - value length - 2 space, 2 operator)
	push 2
	call getValFromBuffer
	cmp ax, 3031
	jb lengthAferValueCheckOperator
	
	dec cx ; 1 val
	
	lengthAferValueCheckOperator:
		sub cx, 5					;  2 space, 2 operator, 1 val
		
		; check assigned var exists
		push offset buffer
		push cx
		call checkExistsVar
		
		; raise error if var doesnt exists
		cmp dh, 0
		je errorVarDoesntExistsOperator
				
		; get current var value
		push si
		call getValue				; dx hold current value
		
		; get value from buffer
		push 2
		call getValFromBuffer		; ax holds value from buffer
		
		call bufferNumToRealNum		; ax holds hex value
		mov cx, param1				; operator

		cmp cx, '+='
		je plus
		
		cmp cx, '-='
		je minus
		
		cmp cx, '*='
		je multiply
		
		cmp cx, '/='
		je divide
		
		cmp cx, '%='
		je modulo
		
		cmp cx, '^='
		je power
		
		plus:
			add ax, dx
			jmp updateVarOperator
		
		minus:
			sub dx, ax
			mov ax, dx
			jmp updateVarOperator
		
		multiply:
			mul dx
			jmp updateVarOperator

		divide:
			cmp ax, 0
			je errorDivideByZeroOperator
			
			xchg ax, dx
			mov cx, dx
			xor dx, dx
			div cx
			jmp updateVarOperator

		modulo:
			cmp ax, 0
			je errorDivideByZeroOperator
			
			xchg ax, dx
			mov cx, dx
			xor dx, dx
			div cx
			mov ax, dx		; remainder after divide
			jmp updateVarOperator
			
		power:
			push bx			; save bx
			mov cx, ax		; mul amount
			mov ax, 1		; start value
			mov bx, dx		; mul value
			xor dx, dx
			
			mulLoop:
				mul bx
				loop mulLoop
			pop bx			; restore bx
			jmp updateVarOperator
						
		updateVarOperator:
			; updates var
			push ax
			call updateValProc
		
		jmp finishMathOperators
		errorDivideByZeroOperator:
			printMsg ErrorDivideByZero
			jmp exit
			
		errorVarDoesntExistsOperator:
			printMsg ErrorVarDoesntExists
			jmp exit
		
		finishMathOperators:
			pop dx
			pop cx
			pop bx
			pop ax
		
			add sp, 2
			pop bp
			ret 4
endp mathOperators


;----------------------------------------
; boolean operators
; <, >, ==, !=, <=, >=
; params: buffer length, operator
; returns: dh (true/ false)
;----------------------------------------
proc booleanOperators
	push bp
	mov bp, sp
	sub sp, 2
	
	push ax
	push bx
	push cx
	
	mov cx, param2		; buffer length
	dec cx				; remove CR (carriage return)
	
	; check var length (buffer length - value length - 2 space, 2 operator)
	push 2
	call getValFromBuffer
	cmp ax, 3031
	jb lengthAferValueCheckBoolOperator
	
	dec cx ; 1 val
	
	lengthAferValueCheckBoolOperator:
		sub cx, 5					;  2 space, 2 operator, 1 val
		
		; check assigned var exists
		push offset buffer
		push cx
		call checkExistsVar
		
		; raise error if var doesnt exists
		cmp dh, 0
		je errorVarDoesntExistsOperator
				
		; get current var value
		push si
		call getValue				; dx hold current value
		mov bx, dx					; bx hold current value (dh is the return value)
		
		; get value from buffer
		push 2
		call getValFromBuffer		; ax holds value from buffer
		
		call bufferNumToRealNum		; ax holds hex value
		mov cx, param1				; operator
		xor dh, dh					; default status (false)
		
		cmp cx, '<'
		je smaller
		
		cmp cx, '>'
		je greater
		
		cmp cx, '=='
		je equalsOp
		
		cmp cx, '!='
		je nEquals
		
		cmp cx, '<='
		je smallerE
		
		cmp cx, '>='
		je biggerE
		
		smaller:
			cmp bx, ax
			jb trueCondition
			jmp finishBooleanOperators
			
		greater:
			cmp bx, ax
			ja trueCondition
			jmp finishBooleanOperators
			
		equalsOp:
			cmp bx, ax
			je trueCondition
			jmp finishBooleanOperators
		
		nEquals:
			cmp bx, ax
			jne trueCondition
			jmp finishBooleanOperators
		
		smallerE:
			cmp bx, ax
			jbe trueCondition
			jmp finishBooleanOperators
		
		biggerE:
			cmp bx, ax
			jae trueCondition
			jmp finishBooleanOperators
		
	jmp finishBooleanOperators
	trueCondition:
		mov dh, true

	finishBooleanOperators:
		pop cx
		pop bx
		pop ax
		
		add sp, 2
		pop bp
		ret 4
endp booleanOperators


;--------------------------------------------------------------------
; buffer to real num procedure
; param: ax
; does: converts 1/2 digits into a number. For example: 30 32 -> 20, 35 00 -> 5
;--------------------------------------------------------------------
proc bufferNumToRealNum
	push bx
	push dx
	
	mov bl, 10			; multiply for tens
	cmp ah, 0
	jne twoDigit
	
	sub al, 30h
	
	
	jmp finishBufferNumToRealNum
	twoDigit:
		xchg ah, al
		sub ah, 30h		; get decimal digits
		sub al, 30h
		mov dl, al
		mov al, ah
		xor ah, ah
		mul bl			; mul to get tens
		add al, dl		; add units
	
	finishBufferNumToRealNum:
		pop dx
		pop bx
		ret
endp bufferNumToRealNum

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
	
	newLine
	newLine
	printMsg FinishMsg
exit:
	mov ax, 4c00h
	int 21h
	END start