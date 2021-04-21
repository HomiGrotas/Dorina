IDEAL
MODEL small
STACK 100h

; ToDO:
;		for loop
;		upgarde string length

; Interpreter memory structure: [length (word), name (unlinited), type (int/str), value (word), length, name, type, value...]

DATASEG

; ---------------------------------------------- constants ----------------------------------------------
FALSE  				equ 0
TRUE   				equ 1
DEBUG  				equ FALSE			; 	DEBUG mode (prints code lines while interpreting and prints program memory at the end)

FILENAME_MAX_LENGTH 		equ 26 				;	(max length is 25, 1 for $)
MEMORY_SIZE			equ 500				; 	interpreter variables memory
LINE_LENGTH 			equ 100				; 	max line length (used in the buffer)
VARIABLE_MEM_SIZE		equ 20				; 	bytes size of var in memory (int is 2 bytes & str is dependant of this constant)

; ---------- procedures parameters -------------
PARAM1 	   		  	equ [bp + 4]
PARAM2     		  	equ [bp + 6]
PARAM3    		  	equ [bp + 8]

; ---------- procedure local variables ---------
LOCAL_VAR1 		  	equ [bp - 2]
LOCAL_VAR2 		  	equ [bp - 4]
LOCAL_VAR3 		  	equ [bp - 6]

; --------------- variables types --------------
INTEGER 		  	equ 0
STRING 			  	equ 1
BOOLEAN 		  	equ 2

; ---------------------------------------------- variables ----------------------------------------------
memoryVariables 	dw MEMORY_SIZE dup(0)           ; buffer array - stores the data from the file
memoryInd 		dw 0				  ; can be up to 65,535 bits

; variables for file opening
filename 		db FILENAME_MAX_LENGTH   	  ; file to operate on
filehandle  		dw '.'				  ; file handle

; variables for reading the file
buffer 			db LINE_LENGTH dup('#')		  ; buffer (line)
char 			db ?				  ; char from file 

; keywords
shoutKeyword 		db 'shout'
ifKeyword 		db 'if'
endIfKeyword		db 'endif'
whileKeyword	db 'while'
endwhileKeyword db 'endwhile'
inIf 			db FALSE			  ; whether the interpreter is in an if statement 
execIf 			db FALSE			  ; whether the if statement is true (and therefore the code should be executed)
inWhile			db FALSE
execWhile		db FALSE
whileStartCX	dw ?
whileStartDX	dw ?

; ---------- messages ----------

; error messages
ErrorMsgCouldntFindOp 	db 'Error: couldnt find an operator or a keyword...', '$'
ErrorMsgCouldntFindBoolOp 	db 'Error: couldnt find boolean operator...', '$'
ErrorMsgOpen 		db 'Error: error while opening code file','$'
ErrorVarDoesntExists 	db "Error: var doesn't exists", '$'
ErrorDivideByZero 	db "Error: can't divide by zero", '$'
ErrorStringTooLong 	db "Warning: the string entered is to long. Entered max length possible.",'$'

; other messages (informative)
EnterFileNameMsg 	db "Please enter a valid file name:", '$'
StartedInterpreting 	db 'Started interpreting...', 13, 10, 13, 10, 13, 10
			db '_______Output_______', '$'
					
MemoryPrintMsg 		db '----------------------  MEMORY ----------------------', '$'
FinishMsg 		db 'Finished Succesfuly!', '$' 																			; finished the program
DorinaOpenMsg   	db "  _____             _               									", 13                                            
					db " |  __ \           (_)                                                         		", 13
					db " | |  | | ___  _ __ _ _ __   __ _                                              		", 13 
					db " | |  | |/ _ \| '__| | '_ \ / _` |                                             		", 13 
					db " | |__| | (_) | |  | | | | | (_| |                                             		", 13
					db " |_____/ \___/|_|  |_|_| |_|\__,_|                                          		", 13
					db "                                                                                    	", 13
					db "  ____            _   _           _                  _____ _                 _      	", 13
					db " |  _ \       _  | \ | |         | |                / ____| |               (_)		", 13
					db " | |_) |_   _(_) |  \| | __ _  __| | __ ___   __   | (___ | |__   __ _ _ __  _ 		", 13
					db " |  _ <| | | |   | . ` |/ _` |/ _` |/ _` \ \ / /    \___ \| '_ \ / _` | '_ \| |		", 13 
					db " | |_) | |_| |_  | |\  | (_| | (_| | (_| |\ V /     ____) | | | | (_| | | | | |		", 13
					db " |____/ \__, (_) |_| \_|\__,_|\__,_|\__,_| \_/     |_____/|_| |_|\__,_|_| |_|_|		", 13
					db "         __/ |                                                                 		", 13 
					db " __     |___/              ___   ___ ___  __                                   		", 13 
					db " \ \   / /             _  |__ \ / _ \__ \/_ |                                 		", 13 
					db "  \ \_/ /__  __ _ _ __(_)    ) | | | | ) || |                                  		", 13 
					db "   \   / _ \/ _` | '__|     / /| | | |/ / | |                                  		", 13 
					db "    | |  __/ (_| | |   _   / /_| |_| / /_ | |                                  		", 13 
					db "    |_|\___|\__,_|_|  (_) |____|\___/____||_|                                  		", 13, '$'
				

CODESEG
jumps		; support far jumps


;------------------------------------------------------------------------------------------------------
;  Macros
;------------------------------------------------------------------------------------------------------

;-------------------------------------------
; Macro: newLine
;   macro to go down a line in console
;-------------------------------------------
macro newLine times
	local newLineLoop		; adding local label (prevent error due to several calls to this macro)
	push cx
	mov cx, times
	
	newLineLoop:
		; new line
		mov dl, 10		; ascii ---> 10 New Line
		mov ah, 02h
		int 21h
		mov dl, 13		; ascii ---> 13 Carriage Return
		mov ah, 02h
		int 21h
		loop newLineLoop
	pop cx
endm

;-------------------------------------------
; Macro: printMsg
;   macro to print a STRING as parameter
;-------------------------------------------
macro printMsg msg_to_print
    mov dx, offset &msg_to_print
	mov ah, 9h
	int 21h
endm


;------------------------------------------------------------------------------------------------------
; Helpers procedures - print array, get STRING, 
;------------------------------------------------------------------------------------------------------

;-----------------------------------
; print array
; param: array length, array offset
;-----------------------------------
proc printArray
	push bp
	mov bp, sp
	
	push bx
	push cx
	push si
	push ax
	push dx
	
	
	mov bx, PARAM1				; array offset 
	mov cx, PARAM2  			; array length
	xor si, si
	
	newLine 1
	mov ah, 2  				; write mode	
	
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


;-----------------------------------
; compare STRING procedure - with the same length
; params: length, offset to STRING1, offset to STRING2
; returns with dh
;-----------------------------------
proc cmpStrings
	push bp
	mov bp, sp
	
	push si
	push di
	push ax
	push bx
	push cx
	
	mov cx, PARAM1 						; length of var name					
	shr cx, 1	   					; comparing word size
	
	mov si, PARAM2 						; offset for first name
	mov bx, PARAM3 						; offset for second name
	
	cmp cx, 0						; if it's just one char -> cmp just byte
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
	
	
	mov ax, PARAM1						; if length is odd there is one more digit to compare
	test ax, 1
	jz equals
	
	; compare digit that was left
	mov ah, [byte ptr bx]
	mov dh, [byte ptr si]
	cmp ah, dh
	jne notEq
	
	equals:
		mov dh, TRUE 					; default return value - equal
		jmp finishCmpStrings
	
	notEq:
		xor dh, dh 					; 0 - not equal
	
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


;--------------------------------------------------------------------
; proc get filename from user procedure
;--------------------------------------------------------------------
proc getFilename
	push ax
	push bx
	push si
	
	mov dx, offset filename
	mov ah, 0Ah
	int 21h
	
	mov si, offset filename + 1 			; 1- number of  chars entered.
	mov cl, [ si ]					; move length to cl.
	mov ch, 0      					; clear ch to use cx. 
	inc cx 						; to reach last char.
	add si, cx 					; now si points to last char.
	mov al, 0
	mov [ si ], al 					; replace last chat (ENTER) BY '$'.	
	newLine 1
	
	pop si
	pop bx
	pop	ax
	ret
endp getFilename

;-------------------------
; open file procedure
; opens file which his name is in filename variable
;-------------------------
proc OpenFile	
	; Open file
	mov ah, 3Dh
	xor al, al						; read only
	mov dx, offset filename + 2
	int 21h
	jc openerror						; CF flag - if on means there is an error
	mov [filehandle], ax					; file handle we got from DOS (used later for closing the file)
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
			cmp si, 0
			jne continueReading
			cmp [inWhile], FALSE
			jne continueReading
			
			; save while start location
			mov ah, 42h		          	;function
			mov al, 1           		;to calculate offset from current poisition
			mov dx, offset filehandle     		;from opening the file
			mov cx, 0     			 	;most significant part of offset
			mov dx, 0        			;least significant part of offset
			int 21h             		;system call
			mov [whileStartCX], dx
			mov [whileStartDX], ax
			
			continueReading:
			mov ah, 3Fh      					;read file
            mov bx, [filehandle]
            lea dx, [char]					; location to store char
            mov cx, 1						; read 1 char

            int 21h						; DOS interrupts

            cmp ax, 0     					; EOF (end of file)
            je EOF

            mov al, [char]					; for comparing the char

            cmp al, 0Ah    					; line feed
            je LF

            mov [offset buffer + si], al			; location in the buffer
            inc si						; inc the location in the buffer
            jmp read_line
			
	EOF: 							; end of file
		jmp finish
	
	LF:							; line feed - handle the line and return reading		
		push si 					; buffer length
		call handleOneLineCommand
		xor si, si					; reset buffer length
		jmp read_line					; keep reading
		
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
; Handlers procedures - understand a command 
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
	
	mov cx, PARAM1    			; buffer length
	
	; print if in DEBUG mode
	mov ah, DEBUG
	cmp ah, 0
	je cmpOp
	
	; print line
	lea bx, [buffer]			; buffer offset
	
	
	; print buffer if in DEBUG mode
	push cx
	push bx
	call printArray
	newLine 1
	
	cmpOp:
		; check whether endif keyword is used
		push offset endIfKeyword
		push offset buffer
		push 5
		call cmpStrings
		
		; if endif keyword is used -> jmp to it's label
		cmp dh, TRUE
		je endIfLbl
		
		
		; check whether 'endwhile' keyword is used
		push offset endwhileKeyword
		push offset buffer
		push 8
		call cmpStrings
		
		; if endif keyword is used -> jmp to it's label
		cmp dh, TRUE
		je endWhileLbl
		
		; check whether while keyword is used
		push offset whileKeyword
		push offset buffer
		push 5
		call cmpStrings
		
		cmp dh, TRUE
		je startWhile
		
		; if in if statement and it's FALSE -> don't execute
		cmp [inIf], FALSE
		je checkInWhile
		cmp [execIf], FALSE
		je finishHandleOneLineCommand
		
		checkInWhile:
		; if in while statement and it's FALSE -> don't execute
		cmp [inWhile], FALSE
		je checkOp
		cmp [execWhile], FALSE
		je finishHandleOneLineCommand 
		
		
		; search for operator / keyword
		checkOp:
		push offset buffer
		push cx
		call findOp		; dx <- operator
		
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
		
		; check whether'if' keyword is used
		push offset ifKeyword
		push offset buffer
		push 2
		call cmpStrings
		
		cmp dh, TRUE
		je startIf
		
		; check if shout keyword is used
		push offset shoutKeyword
		push offset buffer
		push 5
		call cmpStrings
		
		cmp dh, TRUE
		je handleShout
		
		
		printMsg ErrorMsgCouldntFindOp
		jmp exit
	
	handleAssignment:					; = operator
		push cx						; buffer length
		call assignemtFromBuffer
		jmp finishHandleOneLineCommand
	
	handlePlus:						; += operator
		push cx						; buffer length
		push '+='
		call mathOperators
		jmp finishHandleOneLineCommand
		
	handleMinus:						; -= operator
		push cx						; buffer length
		push '-='
		call mathOperators
		jmp finishHandleOneLineCommand
	
	handleMultiply:						; *= operator
		push cx						; buffer length
		push '*='
		call mathOperators				
		jmp finishHandleOneLineCommand
		
	handleDivide:						; /= operator
		push cx						; buffer length
		push '/='
		call mathOperators				
		jmp finishHandleOneLineCommand
		
		
	handleMudolo:						; %= operator
		push cx						; buffer length
		push '%='
		call mathOperators				
		jmp finishHandleOneLineCommand
	
	handlePower:						; ^= operator
		push cx						; buffer length
		push '^='
		call mathOperators				
		jmp finishHandleOneLineCommand
	
	startWhile:
		mov [inWhile], TRUE				; we are in if statement now (TRUE)
		lea bx, [buffer]
		add bx, 6					; 5 while, 1 space (offset)
		sub cx, 6					; 5 while, 1 space (array lengthי
		mov di, 2					; operator size (2/1)	

		push bx						; array offset
		push cx						; array length
		call findOp					; dx <- operator
		
		cmp dh, 0					; handle 1 digit operator
		jne checkValLengthWhile
		dec di
		inc cx
		
		checkValLengthWhile:
			; check var length (buffer length - 1/2 value length - 2 space, 1/2 operator)
			push 6					; start index (while length +1)
			push di					; operator size
			call getValFromBuffer
			cmp ax, 3031
			jb handleOperator
			
			dec cx ; 1 val
			jmp handleOperator
		
	; handle if keyword
	startIf:
		mov [inIf], TRUE				; we are in if statement now (TRUE)
		lea bx, [buffer]
		add bx, 3					; 2 if, 1 space (offset)
		sub cx, 3					; 2 if, 1 space (array length)
		mov di, 2					; 2 if		

		push bx						; array offset
		push cx						; array length
		call findOp					; dx <- operator
		
		cmp dh, 0					; handle 1 digit operator
		jne checkValLength
		dec di
		inc cx
		
		
		checkValLength:
		; check var length (buffer length - 1/2 value length - 2 space, 1/2 operator)
		push 3
		push di
		call getValFromBuffer
		cmp ax, 3031
		jb handleOperator
		
		dec cx ; 1 val
		
		
		handleOperator:
		;---------------------
		; BOOLEAN operators check:
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
		jmp unknownOperator
		
		handleSmaller:						; < operator
			push bx
			push cx						; buffer length
			push '<'
			call booleanOperators
			jmp checkTRUECondition
			
		handleGreater:						; > operator
			push bx
			push cx						; buffer length
			push '>'
			call booleanOperators
			jmp checkTRUECondition
			
		handleEquals:						; == operator
			push bx
			push cx						; buffer length
			push '=='
			call booleanOperators
			jmp checkTRUECondition
			
		handleNEquals:						; != operator
			push bx
			push cx						; buffer length
			push '!='
			call BooleanOperators
			jmp checkTRUECondition
			
		handleSmallerE:						; <= operator
			push bx
			push cx						; buffer length
			push '<='
			call booleanOperators
			jmp checkTRUECondition
			
		handleBiggerE:						; >= operator
			push bx
			push cx						; buffer length
			push '>='
			call booleanOperators
			jmp checkTRUECondition
		
		unknownOperator:
			printMsg ErrorMsgCouldntFindBoolOp
			newLine 1
		
		checkTRUECondition:
			cmp [inWhile], TRUE
			je updateExecWhile
			
			mov [execIf], dh				; condition TRUE/ FALSE
			jmp finishHandleOneLineCommand

			updateExecWhile:
				mov [execWhile], dh
				cmp dh, TRUE
				jne  finishHandleOneLineCommand
			
				jmp finishHandleOneLineCommand
				
				
	endIfLbl:
		mov [inIf], FALSE
		jmp finishHandleOneLineCommand
		
	endWhileLbl:
		mov [inWhile], FALSE
		cmp [execWhile], FALSE
		je finishHandleOneLineCommand
		
		mov [inWhile], TRUE
		mov ah, 42h		          	;function
		mov al, 0           		;to calculate offset from beginning of file
		mov dx, offset filehandle     		;from opening the file
		mov cx, [whileStartCX]     			 	;most significant part of offset
		mov dx, [whileStartDX]       			;least significant part of offset
		int 21h             		;system call
		jmp finishHandleOneLineCommand
	
	handleShout:							; shout keyword
		push cx							; buffer length
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
; prints in ascii format
;--------------------------------------
proc printInAsciiFormat 
	push ax
	push bx
	push cx
	push dx
	
	mov bx, 10			; to divide by 10
	xor cx, cx			; amount of iterations
	
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
	mov ah, 2			; ah=2, 21h interrupt
	cmp dl, '0'			; if first digit is a zero -> skip
	je loop2
	int 21h
	
	loop2:
		pop dx
		int 21h			; print from the last digit
		loop loop2
	
	pop dx
	pop	cx 
	pop bx
	pop ax
	ret
endp printInAsciiFormat


;-----------------------------------------
; handle shout keyword procedure
;	checks if the content is a STRING/ var and prints accordingly
;-----------------------------------------
proc handleShoutKeyword
	push bp
	mov bp, sp
	
	push ax
	push dx
	push bx
	push cx
	
	mov cx, PARAM1				; buffer length
	mov si, 6				; 5 shout length, 1 stand on command content
	mov ah, 2				; write to screen
	
	; check if need to print a STRING or a variable
	mov dl, [buffer + si]
	cmp dl, '"'
	jne printVar
	
	; printStr:
		inc si				; 1 "
		shoutPrintLoop:
			mov dl, [buffer + si]
			cmp dl, '"'
			je finishHandleShoutKeyword
			
			int 21h	 		; print char
			
			inc si
			jmp shoutPrintLoop
	
	
	printVar:
		; check whether var exists and get its index
		lea bx, [buffer]
		add bx, si				; index of var name in buffer
		sub cx, 7				; 5 shout, 1 space, 1 CR
		
		push bx					; offset of current var
		push cx					; var name length
		call checkExistsVar			; bx now holds the var memory index
		cmp dh, TRUE
		jne varDoesntExists
		
		push bx
		add bx, [bx]
		mov al, [bx+2]				; type
		cmp al, INTEGER
		je printIntVar
		add sp, 2					; delete last push
		
		; print value - str
		add bx, 3					; get to var value
		mov cx, 2					; count length
		mov ah, 2					; print mode
		printStrLoop:
			mov dx, [bx]
			cmp dx, 0							; array is initalized by 0. if reached to 0 mean str ended
			je finishHandleShoutKeyword
			int 21h
			mov dl, dh
			int 21h
			
			cmp cx, VARIABLE_MEM_SIZE
			jae finishHandleShoutKeyword
			
			add cx, 2
			add bx, 2							; get next 2 chars
			jmp printStrLoop					; continue printing
		
		jmp finishHandleShoutKeyword
		
		printIntVar:
			; get var value
			call getValue	 			; value in dx
			
			mov ax, dx
			call printInAsciiFormat		; print var in decimal format

	
	jmp finishHandleShoutKeyword
	varDoesntExists:
		printMsg ErrorVarDoesntExists
		newLine 1
	
	finishHandleShoutKeyword:
		newLine	1				; go a line down in console
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
			
	mov ax, PARAM1 				; var name length
	
	mov cx, PARAM2				; var location in buffer
	xor dh, dh
	
	xor si, si	   			; memory index
	lea bx, [memoryVariables]

	; finish if memory is empty
	cmp si, [memoryInd]
	je finishCheckExistsVar  		; memoryInd == 0
	
	; keep checking while si < memoryInd
	loopMemory:
		; check if var name of the var in the buffer has same length of the one in memory
		mov dx, [bx + si]
		cmp dx, ax
		jne keepLooping
		
		; skip length
		add si, 2				; index of var in memory
		add bx, si

		; compare names
		push cx					; var location in buffer
		push bx					; memory offset
		push ax 				; variable length
		call cmpStrings
		
		; return to original pointer
		sub bx, si
		sub si, 2
		
		; if names are equal
		cmp dh, TRUE
		je found
				
		keepLooping:
			; point to next variable
			add si, [bx + si]		; si += var name length 
			add si, 3			; si += 3 (type 1, length 2)
			add si, VARIABLE_MEM_SIZE
			
			cmp si, [memoryInd]		; keep looping while si < memoryInd
			jb loopMemory
	
	xor dh, dh	   				; default - var doesn't exists
	jmp finishCheckExistsVar
	
	; var exists
	found:
		mov dh, TRUE
		mov bx, si				; index of the start of the variable in memory
		
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
	
	xor si, si										; buffer index
	mov di, [memoryInd]									; memory index
	
	mov LOCAL_VAR1, di									; LOCAL_VAR1 <- memory ind
	add di, 2										; save location for length
		
	; insert name until reaches a space
	insertName:
		mov ah, [buffer + si]
		
		cmp ah, ' '									; stop inserting if reached a space (' ')
		je finishedInsertName
		
		mov [byte ptr memoryVariables + di], ah						; mov char to memory
		inc di										; move to next location in memory
		inc si
		
		jmp insertName
	
	finishedInsertName:
		; insert length
		mov bx, LOCAL_VAR1
		mov [bx], si									; si <- var name length
		
		; check value type
		mov al, [buffer + si + 3]
			
		
		inc di
		cmp al, '"'
		je insert1ValStr								; STRING type - at least 1 char
		
		; int type:
		mov ah, [buffer + si + 4]
		
		; if the second char is carriage return - insert just the first char
		cmp ah, 13 									; carriage return
		jne insert2ValInt
		xchg ah, al									; move the digit to MSB
		mov al, 30h									; will be substracted in the next label (make sure it's value will be 0)
		
		insert2ValInt:
			call bufferNumToHexVal							; get hex value of number in buffer
			
			; insert type
			mov  [byte ptr memoryVariables + di - 1], INTEGER
			
			; insert value
			mov  [memoryVariables + di], ax
			jmp finishInserting
			
		insert1ValStr:
			; insert type
			mov  [byte ptr memoryVariables + di - 1], STRING
			lea bx, [buffer]
			add bx, si
			add bx, 4
			
			mov cx, 1										; mesuare length
			; get 2 digits value from buffer and check whether it's only 1 digit
			insertStrLoop:
				mov al, [bx]								; get char from buffer
				cmp al, '"'
				je finishInserting
				mov [byte ptr memoryVariables + di], al		; insert char to memory
				
				cmp cx, VARIABLE_MEM_SIZE					; check str isn't too long
				je lengthError
				
				inc di
				inc bx
				inc cx				
				jmp insertStrLoop

	jmp finishInserting
	lengthError:
		printMsg ErrorStringTooLong
		newLine 1
		
	finishInserting:
		add [memoryInd], si								;  length of name
		add [memoryInd], 3								;  2 length, 1type
		add [memoryInd], VARIABLE_MEM_SIZE						;  val length in memory
		
		
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
; param: buffer offset, buffer length
; return dx (operator)
;----------------------------------
proc findOp
	push bp
	mov bp, sp
	
	push ax
	push bx
	push cx
	push si
	
	mov cx, PARAM1    				; buffer length
	mov bx, PARAM2					; buffer offset
	xor si, si					; buffer index
	xor dh, dh					; operator
	
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
		ret 4
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
	lea bx, [buffer]					; buffer offset
	mov cx, PARAM1						; buffer length
	xor si, si
	
	; cx <- length of var name
	sub cx, 6  						; get length of var name (odd length is handled later)
	
	; handle 1 digit value
	push 0							; start from index 0
	push 1							; = operator is 1 digit
	call getValFromBuffer
	
	cmp ax, 3031
	jnb lengthAferValueCheck				; check whether is more than 1 digit
	
	inc cx							; var name length += 1
	
	lengthAferValueCheck:
		cmp al, '"'
		jne lengthAfterStrCheck	; jump if value isn't in str format
		
		; STRING value
		call getStrLengthBuffer
		sub cx, dx					; sub x digits value						$ ToDo: sub str length on buffer
			
		; check 1 digit str
		push 0						; start index
		push 2						; operator size
		call getValFromBuffer
		cmp ah, '"'
		jne lengthAfterStrCheck
	
	lengthAfterStrCheck:
	
	; check if var already exists
	push offset buffer
	push cx  						; var name length
	call checkExistsVar					; var index in bx
	mov LOCAL_VAR1, bx					; var index
	
	; check if var exists
	cmp dh, 1
	je updateVal
	
	; if var doesn't exists - insert to memory
	call insertVarToMemory
		
	jmp finishAssignemtFromBuffer
	
	updateVal:
		; check var type
		add bx, [bx]					; skip var name
		mov bh, [bx+2]  				; get var type
		cmp bh, STRING
		je updateStr
		
		; get var value
		push 0
		push 1  							; operator length
		call getValFromBuffer				; ax <- new value
		call bufferNumToHexVal				; hex value <- buffer num
		jmp updateVar		
		
		; get var value
		updateStr:
			mov bx, LOCAL_VAR1			; var index
			call updateStrVar
			jmp finishAssignemtFromBuffer
			
		updateVar:
			mov bx, LOCAL_VAR1			; var index
			push ax					; var new value
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

; params: 
;		bx: var index in memory
proc updateStrVar
	push bp
	mov bp, sp
	
	add bx, [bx]				; skip var name length
	add bx, 2
	xor si, si					; buffer index
	mov cx, 1					; count value length
	dec si
	reachStrLoop:
		inc si
		mov al, [buffer + si]
		cmp al, '"'
		jne reachStrLoop
	
	updateStrLoop:
		inc si
		inc bx
		inc cx
		mov dh, [buffer + si]
		cmp dh, '"'
		je deleteRestLoop
		mov [bx], dh
		jmp updateStrLoop
	
	deleteRestLoop:
		mov [word ptr bx], 0
		inc bx
		loop deleteRestLoop
		
	finishUpdateStrVar:
		pop bp
		ret
endp updateStrVar

; return: dx - str length
proc getStrLengthBuffer
	xor dx, dx			; counter
	xor si, si			; buffer index
	lea bx, [buffer]
	
	dec dx
	dec si
	
	loopStrStart:
		inc si
		
		mov ah, [byte ptr bx + si]
		cmp ah, '"'
		jne loopStrStart
	
	strLengthLoop:
		inc si
		inc dx
		
		mov ah, [byte ptr bx + si]
		cmp ah, '"'
		jne strLengthLoop
	ret
endp getStrLengthBuffer


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
	add bx, PARAM1
	
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
	
	mov dx, PARAM1			; new value
	
	; skip var name
	add bx, [bx] 			; bx += var name length
	
	; update value
	mov [bx + 3], dx  		; skip type and move to val area
	
	pop bp
	ret 2
endp updateValProc


;----------------------------------------
; 	getValFromBuffer procedure
; param:   operator length, buffer start index
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
	
	mov bx, PARAM1						; operator length
	mov si, PARAM2					    	; buffer index
	
	loopBuffer:
		mov ah, [buffer + si]
		inc si
		cmp ah, ' '					; stop looping if reached a space (' ')
		je finishedLoopingNameBuffer
		jmp loopBuffer					; keep looping
	
	finishedLoopingNameBuffer:
		add si, bx					; add operator length
		mov al, [buffer + si + 1]			; get value
		mov ah, [buffer + si + 2]
	
	; if the second char is carriage return - insert just the first char
	cmp ah, 13 						; carriage return
	jne finishLoopingBuffer
	xor ah, ah
	
	finishLoopingBuffer:		
		pop di
		pop dx
		pop cx
		pop bx
		pop bp
		ret 4
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
	
	mov cx, PARAM2					; buffer length
	dec cx						; remove CR (carriage return)
	
	; check var length (buffer length - value length - 2 space, 2 operator)
	push 0
	push 2
	call getValFromBuffer
	cmp ax, 3031
	jb lengthAferValueCheckOperator
	
	dec cx ; 1 val
	
	lengthAferValueCheckOperator:
		sub cx, 5				;  2 space, 2 operator, 1 val
		
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
		push 0
		push 2
		call getValFromBuffer			; ax holds value from buffer
		
		call bufferNumToHexVal			; ax holds hex value
		mov cx, PARAM1				; operator

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
			mov ax, dx				; remainder after divide
			jmp updateVarOperator
			
		power:
			push bx					; save bx
			mov cx, ax				; mul amount
			mov ax, 1				; start value
			mov bx, dx				; mul value
			xor dx, dx
			cmp cx, 0
			je powerZero
			
			mulLoop:
				mul bx
				loop mulLoop
			pop bx					; restore bx
			jmp updateVarOperator
			
			powerZero:
				pop bx
						
		updateVarOperator:
			; updates var
			push ax
			call updateValProc
		
		jmp finishMathOperators
		errorDivideByZeroOperator:			; ERROR: divide by zero
			printMsg ErrorDivideByZero
			jmp exit
			
		errorVarDoesntExistsOperator:			; ERROR: var doesn't exists
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
; BOOLEAN operators
; <, >, ==, !=, <=, >=
; params: offset to search in,  length, operator, while keyword? (TRUE/ FALSE)
; returns: dh (TRUE/ FALSE)
;----------------------------------------
proc booleanOperators
	push bp
	mov bp, sp
	sub sp, 2
	
	push ax
	push bx
	push cx
	
	mov LOCAL_VAR1, ax				; while loop?			
	
	mov cx, PARAM2						; buffer length
	dec cx							; remove CR (carriage return)
	
	lengthAferValueCheckBoolOperator:		
		sub cx, 5					;  2 space, 2 operator, 1 val
		
		; check assigned var exists
		push PARAM3
		push cx
		call checkExistsVar
		
		; raise error if var doesnt exists
		cmp dh, 0
		je errorVarDoesntExistsOperator
				
		; get current var value
		push si
		call getValue					; dx hold current value
		mov bx, dx					; bx hold current value (dh is the return value)
		
		; get value from buffer
		cmp [inWhile], FALSE
		jne whileKeywordPushLength
		push 3
		jmp getValFromBufferWhileIf
		whileKeywordPushLength:
		push 6
		
		getValFromBufferWhileIf:
		push di
		call getValFromBuffer				; ax holds value from buffer
		
		call bufferNumToHexVal				; ax holds hex value
		mov cx, PARAM1					; operator
		xor dh, dh					; default status (FALSE)
		
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
			jb TRUECondition
			jmp finishBooleanOperators
			
		greater:
			cmp bx, ax
			ja TRUECondition
			jmp finishBooleanOperators
			
		equalsOp:
			cmp bx, ax
			je TRUECondition
			jmp finishBooleanOperators
		
		nEquals:
			cmp bx, ax
			jne TRUECondition
			jmp finishBooleanOperators
		
		smallerE:
			cmp bx, ax
			jbe TRUECondition
			jmp finishBooleanOperators
		
		biggerE:
			cmp bx, ax
			jae TRUECondition
			jmp finishBooleanOperators
		
	jmp finishBooleanOperators
	TRUECondition:
		mov dh, TRUE

	finishBooleanOperators:		
		pop cx
		pop bx
		pop ax
		
		add sp, 2
		pop bp
		ret 6
endp booleanOperators


;--------------------------------------------------------------------
; buffer to real num procedure
; param: ax
; does: converts 1/2 digits into a number. For example: 30 32 -> 20, 35 00 -> 5
;--------------------------------------------------------------------
proc bufferNumToHexVal
	push bx
	push dx
	
	mov bl, 10			; multiply for tens
	cmp ah, 0
	jne twoDigit
	
	sub al, 30h
	
	
	jmp finishBufferNumToHexVal
	twoDigit:
		xchg ah, al
		sub ah, 30h		; get decimal digits
		sub al, 30h
		mov dl, al
		mov al, ah
		xor ah, ah
		mul bl			; mul to get tens
		add al, dl		; add units
	
	finishBufferNumToHexVal:
		pop dx
		pop bx
		ret
endp bufferNumToHexVal


;----------------
; START
;----------------
start:
	mov ax, @data
	mov ds, ax
	
	; print Dorina Big title
	printMsg DorinaOpenMsg
	newLine 1

	printMsg EnterFileNameMsg
	newLine 1

	call getFilename	
	
	; open codefile(with .txt extension)
	call OpenFile
	
	printMsg StartedInterpreting
	newLine 2
	; read file content and execute commands
	call readLineByLine
	
	; close file
	call closeFile
	
		
	; if debug mode is on - print memory
	mov ah, DEBUG
	cmp ah, 0
	je exit
	
	; print memory
	newLine 3
	printMsg MemoryPrintMsg
	push MEMORY_SIZE
	push offset memoryVariables
	call printArray
	
	newLine 2
	printMsg FinishMsg
	
exit:
	mov ax, 4c00h
	int 21h
	END start
