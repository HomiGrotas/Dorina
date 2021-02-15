IDEAL
MODEL small
STACK 100h

; ToDO:
;	    handle big var names - Done
;		math operators
;		interpret location assignments
;		insert value procedure
;		get value procedure

; HowTo: get var name: insert var length, insert to stack 2 by 2  mem:[length, name, type, value, length, name, type, value...]

DATASEG

; constants
false  equ 0
true   equ 1
DEBUG  equ true
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
ErrorMsg db 'Error!','$'   ; error message
FinishMsg db 'Finished!', '$' ; finished the program


CODESEG


;------------------------------------------------------------------------------------------------------
;  Macros
;------------------------------------------------------------------------------------------------------

; goes a line down
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
		mov dx, offset ErrorMsg
		mov ah, 9h
		int 21h
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
; Helpers procedures - print array, get string, 
;------------------------------------------------------------------------------------------------------

;---------------------
; print array
; param: array length, array offset
;---------------------
proc printArray
	push bp
	mov bp, sp
	
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
	
	pop bp
	ret 4
endp printArray


;-------------------------------
; compare string procedure
; params: 2 chars, 2 chars (word size each param)
; returns with dh
;-------------------------------
proc cmpStrings
	push bp
	mov bp, sp
	
	push si
	push di
	push ax
	
	mov dh, true  ; default return value - equal 
	mov si, param1
	mov di, param2
	
	dec si
	keepCmp:
		inc si
		lodsb ; load al with next char from string 1 (si register)
		cmp [di], al
		jne notEq
		
		cmp al, 0
		jne finishCmpStrings  ; end of string?
		
		jmp keepCmp
	
	
	notEq:
		xor dh, dh ; 0- not equal
	
	finishCmpStrings:
		pop ax
		pop di
		pop si
		
		pop bp
		ret 4
endp cmpStrings


;------------------------------------------------------------------------------------------------------
; Handlers procedures - understand command 
;------------------------------------------------------------------------------------------------------
proc handleOneLineCommand
	push bp
	mov bp, sp
	
	sub sp, 6 ; 3 local vars - first element, operator, second element
	
	push ax
	push bx
	push si
	push dx
	
	; print if in DEBUG mode
	mov ah, DEBUG
	cmp ah, 0
	je finishHandleOneLineCommand
	
	; print line
	mov ax, param1    			; buffer length
	lea bx, [buffer]			; buffer offset
	
	; print array
	push ax
	push bx
	call printArray
		
	
	findVar:
		; ToDO: handle 1 char var name
		
		; load var and value
		mov dh, [bx]
		mov dl, [bx + 1]
		
		mov ah, [bx + 3]
		mov al, [bx + 4]
		
		push ax
		push dx
		call handleVarAndMem
		
	finishHandleOneLineCommand:
		pop dx
		pop si
		pop bx
		pop ax
		
		add sp, 6
		pop bp
		ret 2
endp handleOneLineCommand

;-------------------------------------------
; checkExistsVar procedure
; checks whether a variable exists in the memory
; params: var name length, var name
;-------------------------------------------
proc checkExistsVar
	push bp
	mov bp, sp
	
	sub sp, 2  ; for localVar1
	
	xor dh, dh	   ; default - var doesn't exists
	mov ax, param1 ; var name length
	mov localVar1, ax
	
	mov si, 6	   ; source index in stack (2 for return address, 2 for param1)
	xor di, di	   ; index in memory
	lea bx, [memoryVariables]
	xor ax, ax
	
	
	loopingMem:
		mov cx, [bx + di]  ; length of var name

		; if var name length in stack != var name length in memory -> jump to procedure end
		cmp localVar1, cx
		jne continueLooping
		
		
		; if they have same length
		shr cx, 1  ; word size need half iterations
		loopingNames:
			; ToDO: check useful way
			push [bp + si]
			sub si, 4	; have constant difference of 4 between stack and memory
			
			add si, ax
			push [bx + si]
			call cmpStrings	; compare 2 chars from stack and 2 from memory
			sub si, ax
			
			; if don't match -> continue to next var in mem
			cmp dh, 0
			je continueLooping
			
			; match -> keep compare the rest of the variables names
			add si, 6
			loop loopingNames
		jmp found
		
		
		continueLooping:
			; go to next var in mem
			add di, [bx]
			add di, 6
			mov si, 6	   ; source index in stack (2 for return address, 2 for param1)
			
			add ax, [bx + di]
			add ax, 6
			
			cmp di, [memoryInd]      
			jbe loopingMem
	
		
	jmp finishCheckExistsVar
	
	; var exists
	found:
		mov dh, true
		
	finishCheckExistsVar:
		add sp, 2
		pop bp
		ret 2
endp checkExistsVar



;---------------------------------------------------------------
; handle var and memory procedure - inserts new var to memory
; params: var name length, var name, var value
; mem:[length, name, type, value, length, name, type, value...]
;---------------------------------------------------------------
proc handleVarAndMem
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
endp handleVarAndMem




;----------------
; START
;----------------
start:
	mov ax, @data
	mov ds, ax

	;call OpenFile
	;call readLineByLine
	;call closeFile
	
	; insert value to memory
	push '50'  ; value
	push string
	push 'ab'
	push 'cd'
	push 4    ; length
	call handleVarAndMem
	
	; insert value to memory
	push '30'  ; value
	push string
	push 'we'
	push 'll'
	push 4    ; length
	call handleVarAndMem
	
	
	; insert value to memory
	push '30'  ; value
	push string
	push 'po'
	push 'ab'
	push 4    ; length
	call handleVarAndMem
	
	; insert value to memory
	push '30'  ; value
	push string
	push 'po'
	push 'ab'
	push 4    ; length
	call handleVarAndMem
	
	; insert value to memory
	push '30'  ; value
	push string
	push 'po'
	push 'a1'
	push 4    ; length
	call handleVarAndMem
	
	; insert value to memory
	push '30'  ; value
	push string
	push 'p2'
	push '1b'
	push 4    ; length
	call handleVarAndMem
	
	
	; check if value in memory
	push 'po'
	push 'a1'
	push 4
	call checkExistsVar
	

	; print memory
	push memorySize
	push offset memoryVariables
	call printArray
		
	newLine
	newLine
	newLine
	newLine
	printMsg FinishMsg


exit: 
	mov ax, 4c00h
	int 21h
	END start