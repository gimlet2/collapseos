; stdio
;
; Allows other modules to print to "standard out", and get data from "standard
; in", that is, the console through which the user is connected in a decoupled
; manner.
;
; Those GetC/PutC routines are hooked in during stdioInit and have this API:
;
; GetC: Blocks until a character is read from the device and return that
;       character in A.
;
; PutC: Write character specified onto the device.
;
; *** Consts ***
; Size of the readline buffer. If a typed line reaches this size, the line is
; flushed immediately (same as pressing return).
.equ	STDIO_BUFSIZE		0x20

; *** Variables ***
; Used to store formatted hex values just before printing it.
.equ	STDIO_HEX_FMT	STDIO_RAMSTART
.equ	STDIO_GETC	@+2
.equ	STDIO_PUTC	@+2

; Line buffer. We read types chars into this buffer until return is pressed
; This buffer is null-terminated.
.equ	STDIO_BUF	@+2

; Index where the next char will go in stdioGetC.
.equ	STDIO_RAMEND	@+STDIO_BUFSIZE

; Sets GetC to the routine where HL points to and PutC to DE.
stdioInit:
	ld	(STDIO_GETC), hl
	ld	(STDIO_PUTC), de
	ret

stdioGetC:
	ld	ix, (STDIO_GETC)
	jp	(ix)

stdioPutC:
	ld	ix, (STDIO_PUTC)
	jp	(ix)

; print null-terminated string pointed to by HL
printstr:
	push	af
	push	hl

.loop:
	ld	a, (hl)		; load character to send
	or	a		; is it zero?
	jr	z, .end		; if yes, we're finished
	call	stdioPutC
	inc	hl
	jr	.loop

.end:
	pop	hl
	pop	af
	ret

; print B characters from string that HL points to
printnstr:
	push	bc
	push	hl
.loop:
	ld	a, (hl)		; load character to send
	call	stdioPutC
	inc	hl
	djnz	.loop

.end:
	pop	hl
	pop	bc
	ret

printcrlf:
	push	af
	ld	a, ASCII_CR
	call	stdioPutC
	ld	a, ASCII_LF
	call	stdioPutC
	pop	af
	ret

; Print the hex char in A
printHex:
	push	bc
	push	hl
	ld	hl, STDIO_HEX_FMT
	call	fmtHexPair
	ld	b, 2
	call	printnstr
	pop	hl
	pop	bc
	ret

; Print the hex pair in HL
printHexPair:
	push	af
	ld	a, h
	call	printHex
	ld	a, l
	call	printHex
	pop	af
	ret

; Repeatedly calls stdioGetC until a whole line was read, that is, when CR or
; LF is read or if the buffer is full. Sets HL to the beginning of the read
; line, which is null-terminated.
;
; This routine also takes care of echoing received characters back to the TTY.
; It also manages backspaces properly.
stdioReadLine:
	push	bc
	ld	hl, STDIO_BUF
	ld	b, STDIO_BUFSIZE-1
.loop:
	; Let's wait until something is typed.
	call	stdioGetC
	; got it. Now, is it a CR or LF?
	cp	ASCII_CR
	jr	z, .complete	; char is CR? buffer complete!
	cp	ASCII_LF
	jr	z, .complete
	cp	ASCII_DEL
	jr	z, .delchr
	cp	ASCII_BS
	jr	z, .delchr

	; Echo the received character right away so that we see what we type
	call	stdioPutC

	; Ok, gotta add it do the buffer
	ld	(hl), a
	inc	hl
	djnz	.loop
	; buffer overflow, complete line
.complete:
	; The line in our buffer is complete.
	; Let's null-terminate it and return.
	xor	a
	ld	(hl), a
	ld	hl, STDIO_BUF
	pop	bc
	ret

.delchr:
	; Deleting is a tricky business. We have to decrease HL and increase B
	; so that everything stays consistent. We also have to make sure that
	; We don't do buffer underflows.
	ld	a, b
	cp	STDIO_BUFSIZE-1
	jr	z, .loop		; beginning of line, nothing to delete
	dec	hl
	inc	b
	; Char deleted in buffer, now send BS + space + BS for the terminal
	; to clear its previous char
	ld	a, ASCII_BS
	call	stdioPutC
	ld	a, ' '
	call	stdioPutC
	ld	a, ASCII_BS
	call	stdioPutC
	jr	.loop
