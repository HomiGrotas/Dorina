IDEAL
MODEL small
STACK 100h

; ToDO:
;	    handle big var names - Done
;		math operators
;		interpret location assignments
;		insert value procedure
;		get value procedure

; HowTo: get var name: insert var length, insert to stack 2 by 2  mem:[length, name, value, length, name, value...]

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


; ToDo: change format
proc checkExistsVar
	push bp
	mov bp, sp
	
	xor dh, dh	   ; default - var doesn't exists
	mov ax, param1 ; var name
	xor si, si
	
	cmp si, [memoryInd]
	je finishCheckExistsVar
	
	lea bx, [memoryVariables]
	sub si, 2
	
	; looping through the memoryVariables
	keepChecking:
		add si, 2
		push [bx + si]
		push ax
		call cmpStrings
		
		cmp dh, true
		je found
		
		cmp si, [memoryInd]
		jne keepChecking
	
	; var exists
	found:
		mov dh, true
		
	finishCheckExistsVar:
		pop bp
		ret 2
endp checkExistsVar



;-----------------------------------------------------------
; handle var and memory procedure - inserts new var to memory
; params: var name length, var name, var value
; mem:[length, name, value, length, name, value...]
;-----------------------------------------------------------
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
	add [memoryInd], 4 ; 2 more for name length and 2 more for value

	shr cx, 1 ; stack is divided per words, therefore, should divide iterations by 2
	
	mov si, 4 ; location in stack from where the name starts
	add si, param1

	; gets name part from the stack and inserts it to the memory
	getNamePartInsertMem:		
		; get word from stack and insert to memory
		mov ax, [bp + si]
		mov [bx + di], ax
		
		; update index
		add di, 2	
		sub si, 2
		loop getNamePartInsertMem
	
	
	; insert value to memory - after the var name
	mov si, 6
	add si, param1
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
	
	push 50  ; value
	push 'he'
	push 'll'
	push '0!'
	push 6    ; length
	call handleVarAndMem
	
	
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