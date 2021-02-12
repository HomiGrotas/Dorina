IDEAL
MODEL small
STACK 100h

; ToDO: math operators
;		interpret location assignments
;		insert value procedure
;		get value procedure


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
ErrorMsg db 'Error', 10, 13,'$'   ; error message

; variables for reading the file
buffer db lineLength dup('#')
char db '&'


CODESEG


;------------------------------------------------------------------------------------------------------
;  Macros
;------------------------------------------------------------------------------------------------------
macro newLine
	; new line
	mov dl, 10		; ascii ---> 10 New Line
	mov ah, 02h
	int 21h
	mov dl, 13		; ascii ---> 13 Carriage Return
	mov ah, 02h
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
	mov ah, 2  		; write mode	
	
	newLine
		
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



;-----------------------------------------------------------
; handle var and memory procedure
; params: var value, var name
;-----------------------------------------------------------
proc handleVarAndMem
	push bp
	mov bp, sp
	
	; save registers
	push ax
	push bx
	push dx
	push si
	
	; get aruments
	mov ax, param1  ; var name
	mov dx, param2  ; var value
	
	; save in mem
	lea bx, [memoryVariables]
	mov si, [memoryInd]
	mov [bx + si], ax	; save var name
	add si, 2
	mov [bx + si], dx	; save var value
	
	add [memoryInd], 2
	
	pop si
	pop dx
	pop bx
	pop ax
	
	pop bp
	ret 4
endp handleVarAndMem



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

;----------------
; START
;----------------
start:
	mov ax, @data
	mov ds, ax
	
	call OpenFile
	call readLineByLine
	call closeFile
	
	push memorySize
	push [memoryVariables]
	call printArray


exit: 
	mov ax, 4c00h
	int 21h
	END start