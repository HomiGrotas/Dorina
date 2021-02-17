IDEAL
MODEL small
STACK 100h

; ToDO:
;		insert only if var doesnt exists
;		print
;		math operators
;		get value procedure
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


;-------------------------------------------
; Macro: pushSpace
;   macro to push to stack until reaches space char (' ')
;-------------------------------------------
macro pushSpace
	local pushLoop, callInsertion1Var, finishPushSpace
	pushLoop:
		mov al, [bx + si]
		cmp al, ' '
		je finishPushSpace
		
		inc si
		mov ah, [bx + si]
		cmp ah, ' '
		je callInsertion1Var
		
		inc si
		push ax
		jmp pushLoop
	
	; push char if remained
	callInsertion1Var:
		xor ah, ah
		push ax
	
	finishPushSpace:
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
	
	
	mov bx, param1	; array length
	mov cx, param2  ; array offset
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
	
	mov cx, param1 ; length
	
	mov si, param2 ; offset for first name
	mov bx, param3 ; offset for second name
	add bx, cx
	
	; handle odd length
	test cx, 1
	je continueCmp
	mov [word ptr bx], 0
	inc bx
	inc cx
	
	continueCmp:
	xor di, di
	sub di, 2
	
	shr cx, 1
	; loop through the two names
	cmpLoop:
		mov ax, [bx + di]
		mov dx, [si]
		cmp ax, dx
		jne notEq
		
		sub di, 2
		add si, 2
		loop cmpLoop
		
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
		push si 
		call handleOneLineCommand
		xor si, si				; reset buffer length
		jmp read_line
		
	finish:	
		ret
endp readLineByLine


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
; params: var name length, var name
; returns: dh (0/ 1)
;-------------------------------------------
proc checkExistsVar
	push bp
	mov bp, sp
	
	sub sp, 2
	
	push ax
	push bx
	push si
	push di
		
	mov ax, param1 ; var name length
	mov cx, offset buffer
	xor dh, dh
	mov localVar1, ax
	; make even length
	test ax, 1
	je continue
	inc ax

	continue:
	lea bx, [memoryVariables]
	xor si, si	   ; memory index
	
	; finish if memory is empty
	cmp si, [memoryInd]
	je finishCheckExistsVar
	
	; keep checking while si < memoryInd
	loopMemory:
		; check have same length
		mov dx, [bx + si]
		cmp dx, ax
		jne keepLoopingNoLength
	
		add si, 2
		add bx, si

		; compare names
		push cx
		push bx
		push localVar1 ; variable length
		call cmpStrings
		sub bx, si
		
		; if names are equal
		cmp dh, true
		je found
		
		jmp keepLooping
		keepLoopingNoLength:
			add si, 2
		
		keepLooping:
			; point to next variable
			add si, [bx + si - 2]
			add si, 4
			
			cmp si, [memoryInd]
			jb loopMemory
	
	xor dh, dh	   ; default - var doesn't exists
	jmp finishCheckExistsVar
	
	; var exists
	found:
		mov dh, true
		
	finishCheckExistsVar:
		add sp, 2
		
		pop di
		pop si
		pop bx
		pop ax
		
		pop bp
		ret 2
endp checkExistsVar



;---------------------------------------------------------------
; handle var and memory procedure - inserts new var to memory
; params: var name length, var name, var value
; mem:[length, name, type, value, length, name, type, value...]
;---------------------------------------------------------------
proc insertVarToMemory
	push bp
	mov bp, sp
	
	; save registers
	push ax
	push bx
	push cx
	push dx
	push di
	
	
	; get name length
	mov cx, param1
	lea bx, [memoryVariables]
	mov di, [memoryInd]
	
	
	; add var name length to mem
	mov [bx + di], cx
	add di, 2

	; update memory index
	add [memoryInd], cx
	add [memoryInd], 6 ; 2 for name, type, value

	shr cx, 1 ; stack is divided per words, therefore, should divide iterations by 2
	
	mov si, 6 ; location in stack from where the name starts

	; gets name part from the stack and inserts it to the memory
	getNamePartInsertMem:		
		; get word from stack and insert to memory
		mov ax, [bp + si]
		mov [bx + di], ax
		
		; update index
		add di, 2	
		add si, 2
		loop getNamePartInsertMem
	
	
	; insert var type
	mov si, 6
	add si, param1
	mov ax, [bp + si]
	mov [bx + di], ax
	
	; move to next param and next location in memory
	add di, 2
	add si, 2

	
	; insert value to memory - after the var name
	mov ax, [bp + si]
	mov [bx + di], ax
		
		
	; return sp to its original value
	sub di, [memoryInd]
	add di, 2  ; original address location on stack
	add sp, di
	
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
	
	loopSearch:
		mov al, [bx + si]
		inc si
		cmp al, ' '
		jne loopSearch
	
	mov dl, [bx + si]
	mov al, [bx + si + 1]
	cmp al, ' '
	je finishFindOp
	
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


;
; assignemtFromBuffer procedure
;
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
	
	sub si, 2
	mov al, [byte ptr bx + si]   ; variable value
	
	
	; check whether var already exists
	
	; ToDO: check type
	push ax	 	 ; var value
	push string  ; var type
	
	; push until space char
	xor si, si
	pushSpace
		
	callInsertion:
		sub cx, 4  ; type, val
		
		; check if var name length is even
		test cx, 1
		jz pushEven
		dec cx ; make length even
		
		pushEven:
			push cx  ; var name length
			call insertVarToMemory
	
	finishAssignemtFromBuffer:
		add sp, 6
		add sp, cx
	
	finishAssignemtFromBufferNoPushes:
		pop si
		pop cx
		pop bx
		pop ax
		
		pop bp
		ret 2
endp assignemtFromBuffer

;----------------
; START
;----------------
start:
	mov ax, @data
	mov ds, ax

	call OpenFile
	call readLineByLine
	call closeFile
	
	mov [buffer], 'h'
	mov [buffer+1], 'i'


	push 2    ; length
	call checkExistsVar
	cmp dh, 1
	je exit
	
	; if debug mode is on - print memory
	mov ah, DEBUG
	cmp ah, 0
	je exit
	
	; print memory
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