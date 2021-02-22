IDEAL
MODEL small
STACK 100h

; ToDO:
;		get value procedure
;		math operators
;		handle shout command

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
filehandle dw '$'					  ; file handle

; variables for reading the file
buffer db lineLength dup('#')
char db '&'

; messages
ErrorMsgCouldntFindOp db 'Error: couldnt find an operator...', '$'
ErrorMsgOpen db 'Error: while opening code file...','$'   ; error message
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

	
	; print if in DEBUG mode
	mov ah, DEBUG
	cmp ah, 0
	je cmpOp
	
	; print line
	mov cx, param1    			; buffer length
	lea bx, [buffer]			; buffer offset
	
	
	; print array
	push cx
	push bx
	call printArray
	
	cmpOp:
		push cx
		call findOp
		
		cmp dx, '='
		je handleAssignment
		
		printMsg ErrorMsgCouldntFindOp
		jmp exit
	
	handleAssignment:
		push cx
		call assignemtFromBuffer	
	
	finishHandleOneLineCommand:
		pop cx
		pop bx
		pop ax
		
		pop bp
		ret 2
endp handleOneLineCommand



;-------------------------------------------
; checkExistsVar procedure
; checks whether a variable exists in the memory
; params: var name length, uses buffer)
; returns: dh (0/ 1), si: index in memory
;-------------------------------------------
proc checkExistsVar
	push bp
	mov bp, sp
	
	
	push ax
	push bx
	push cx
	push di
		
	mov ax, param1 ; buffer length
	
	mov cx, offset buffer
	xor dh, dh

	lea bx, [memoryVariables]
	
	push ax
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
		push cx		; buffer offset
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
			add si, 6			; si += 6 (type 1, length 2, move to next var 2)
			
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
		pop bx
		pop ax
		
		pop bp
		ret 2
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
		inc si
		
		cmp ah, ' '									; stop inserting if reached a space (' ')
		je finishedInsertName
		
		mov [byte ptr memoryVariables + di], ah		; mov char to memory
		inc di										; move to next location in memory
		jmp insertName
	
	finishedInsertName:
		; insert length
		mov bx, localVar1
		dec si
		mov [bx], si
		
		
		; handle odd name length (memoryInd -= 1)
		test si, 1
		jz continue
		
		mov ax, [memoryInd]
		dec ax
		mov [memoryInd], ax
		
		continue:
		; insert type
		mov  [byte ptr memoryVariables + di], string
		
		; insert value
		inc di
		mov al, [buffer + si + 3]
		mov ah, [buffer + si + 4]
		
		; if the second char is carriage return - insert just the first char
		cmp ah, 13 ; carriage return
		jne insert2Val
		xor ah, ah
		
		insert2Val:
			mov  [memoryVariables + di], ax

	
	finishInserting:
		add [memoryInd], si	; length of name
		add [memoryInd], 6	; length, value, type
		
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
	
	push ax
	push bx
	push cx
	push si
	
	xor ah, ah
	lea bx, [buffer]	; buffer offset
	mov cx, param1		; buffer length
	mov si, cx
	
	sub si, 2 ; remove carriage return
	xor si, si
		
	; callInsertion
	sub cx, 6  							; type, val, length
	
	; check if var already exists
	push cx  							; var name length
	call checkExistsVar
	
	; check if var exists
	cmp dh, 1
	je updateVal
	
	; if var doesn't exists - insert to mem
	call insertVarToMemory
		
	jmp finishAssignemtFromBuffer
	
	updateVal:
		call getValFromBuffer		; ax <- new value
		push ax
		push si
		call updateValProc			; update the variable value

	
	finishAssignemtFromBuffer:
		; reverse param pushes
		pop si
		pop cx
		pop bx
		pop ax
		
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
	mov dx, [bx + 4]
		
	pop bx
	pop bp
	ret 2
endp getValue

;----------------------------------
; updateVal procedure
; params: value index, new value
;----------------------------------
proc updateValProc
	push bp
	mov bp, sp
	
	mov dx, param2		; new value
	lea bx, [memoryVariables]
	
	; skip var name
	add bx, [bx] ; bx += var name length
	
	; update value
	mov [bx + 3], dx  ; skip type and move to val area
	
	pop bp
	ret 4
endp updateValProc


;----------------------------------------
; 	getValFromBuffer procedure
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
	
	xor si, si				; buffer index
	loopBuffer:
		mov ah, [buffer + si]
		inc si
		cmp ah, ' '									; stop inserting if reached a space (' ')
		je finishedLoopingNameBuffer
		jmp loopBuffer		; keep looping
	
	finishedLoopingNameBuffer:
		mov al, [buffer + si + 2]
		mov ah, [buffer + si + 3]
	
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
		ret 
endp getValFromBuffer








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