IDEAL
MODEL small
STACK 100h

; ToDO: math operators
;		interpret location assignments
;		insert value procedure
;		get value procedure

DATASEG

memorySize equ 500
lineLength equ 100

memoryVariables db memorySize dup('@')     ; buffer array - stores the data from the file

; variables for file opening
filename db 'testfile.txt',0	  ; file to operate on
filehandle dw '$'					  ; file handle
ErrorMsg db 'Error', 10, 13,'$'   ; error message

; variables for reading the file
buffer db lineLength dup('#')
char db '&'

CODESEG

; constants
param1 equ [bp + 4]
param2 equ [bp + 6]
param3 equ [bp + 8]

;------------------------------------------------------------------------------------------------------
;  Macros
;------------------------------------------------------------------------------------------------------
macro newLine
	; new line
	MOV dl, 10		; ascii ---> 10 New Line
	MOV ah, 02h
	INT 21h
	MOV dl, 13		; ascii ---> 13 Carriage Return
	MOV ah, 02h
	INT 21h
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
	
	xor si, si				; buffer length
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


;------------------------------------------------------------------------------------------------------
; Handlers procedures - understand command 
;------------------------------------------------------------------------------------------------------
proc handleOneLineCommand
	push bp
	mov bp, sp
	
	mov ax, param1    			; buffer length
	lea bx, [buffer]			; buffer offset
	
	push ax
	push bx
	call printArray
	
	pop bp
	ret 2
endp handleOneLineCommand


;----------------
; START
;----------------
start:
	mov ax, @data
	mov ds, ax
	
	; Process file
	call OpenFile
	call readLineByLine
	call CloseFile


exit: 
	mov ax, 4c00h
	int 21h
	END start