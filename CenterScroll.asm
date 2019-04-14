
!Setting_CenterScroll_ScrollType	= 1
 ;^0 = Normal, L/R scrolling is possible (normal version);
 ;     *$142A [2 bytes] -> The X position to scroll the screen.
 ;     *$142C-$142F [4 bytes] unused (cleared on reset,
 ;      titlescreen load, overworld load and cutscene load) Vertical
 ;      Scroll movement is the same as original game even when
 ;      "Vertical Scroll at will" is used.
 ; 1 = Adjustable scroll line positions (disables LR scrolling),
 ;     (advanced version):
 ;     *$142A [2 bytes] -> The player X position to scroll the screen.
 ;     *$142C [2 bytes] -> The player Y position to scroll the screen.
 ;     *$142E [2 bytes] -> unused, same being cleared mentioned above.
 ;     This mode is useful in cases if your hack have scenes like go
 ;     to a certain spot and the screen tries to pan to a location
 ;     to let you see further, for example, a runner level heading right
 ;     makes the screen to the right of player so the view focuses on the
 ;     area ahead of the player.
 ; By the way, the area (line since this patch shrinks the region
 ; to a single pixel) the player is at in which the screen doesn't move
 ; is called the "Static Camera Region". $0000 would represent the left
 ; or top of the screen, while increasing would move the line rightwards
 ; or downwards (which moves the screen towards the left or upwards from
 ; player).
 
!Setting_CenterScroll_FreeVerticalScroll	= 1
 ;^Matters only if you have !Setting_CenterScroll_ScrollType set to 0.
 ; Otherwise will always scroll vertically freely when "Vertical Scroll at Will"
 ; being used without touching the ground.
 ; *0 = SMW's wait till you are on the ground
 ; *1 = follow you freely vertical (edits $00F878)
 
!Setting_CenterScroll_EnableLRScrolling		= 0
 ;^This only applies if !Setting_CenterScroll_ScrollType is set to 0, otherwise
 ; it is always disabled.
 ;  0 = disabled
 ;  1 = enabled (if !Setting_CenterScroll_ScrollType set to 0).
 ; Currently, the screen doesn't revert itself should the player attempts to go
 ; to a direction the edge of the screen closest to the player unlike the vanilla game,
 ; upon debugging, I've found out whats causing it but cannot fix it: Codes at $00CE56
 ; to $00CE5C ($00CE5E) ALWAYS branch and skips the auto-adjust screen code because 
 ; the code at $00CE59 CMP.W $00F6CB,Y always results comparing a value that is equal
 ; to whats stored in $142A. Trying to remove the branch results a freeze after L/R
 ; scrolling, therefore I highly recommend setting this to 0, and use uberasm and code
 ; your own L/R scrolling, unless you want it so that the player have to manually revert
 ; the screen.
!Setting_CenterScroll_GradualScroll	= 1
 ;^0 = Will instantly scroll the screen to the player when far enough (if player teleports,
 ;     the screen will jump to a location within a single frame.)
 ; 1 = Will scroll horizontal gradually to the player when far enough instead of SMW's way
 ;     (will scroll 8 pixels per frame towards the player). Note that with
 ;     !Setting_CenterScroll_ScrollType set to 0, will still scroll the same as SMW's handling.
 
;Default scroll line positions to move screen (when entering level):
 !Setting_CenterScroll_InitalXPos	= $0078
 !Setting_CenterScroll_InitalYPos	= $0070

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Sa-1 detector
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	!dp = $0000
	!addr = $0000
	!sa1 = 0
	!gsu = 0

if read1($00FFD6) == $15
	sfxrom
	!dp = $6000
	!addr = !dp
	!gsu = 1
elseif read1($00FFD5) == $23
	sa1rom
	!dp = $3000
	!addr = $6000
	!sa1 = 1
endif
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Notify if level has not been saved.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;This tells asar to check in the rom to see if lunar magic has modify snes address $00F6E4 from
	;[SBC #$000C] to [JML $1FB1A0] (actually, not always $1FB1A0):

	assert read1($00F6E4) == $5C, "Save at least one level in lunar magic!"
	assert read1($009708) == $22, "Hijack for Horizontal Scroll Fix from Lunar Magic not detected!"

	;^Note: if the assembler tool was to be updated, and the way it reads the rom is changed, then this
	;patch needs to be updated so that it still works with the latest patching tool.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Hijacks and edits.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Free up $142C and $142E (2 bytes each).
	if !Setting_CenterScroll_ScrollType == 0
		org $00F6B3
		db $78,$00,$7A,$00	;>scroll tables
	else
		org $00F6B3
		db $90,$00,$60,$00	;>scroll tables
	endif
	
	org $00F6E3			;>Get rid of the SEC
	nop #1
	
	org read3($00F6E4+1)		;\Get rid of the SBC in LM's restore code
	nop #6				;/
	;^To understand this, after saving a level in Lunar magic, it changes the opcode at $00F6E4
	;from SBC.W #$000C to JMP $AABBCC (formated in raw code, hex numbers: 5C CC BB AA). By
	;using 3 bytes after the opcode itself, Asar only reads the address that Lunar magic jumps
	;to (modifying address $AABBCC). It should now ALWAYS hijack the LM code regardless of its
	;location.

	org $00F6EA			;>Get rid of the CLC ADC
	nop #7

	;org $00F72D			;>free up $142C and $142E
	;SBC $142A|!addr	

	org $00F77C			;>free up $142C and $142E (vertical level horizontal scrolling)
	SBC $142A|!addr	
;LR scrolling
	if and(equal(!Setting_CenterScroll_ScrollType, 0), notequal(!Setting_CenterScroll_EnableLRScrolling, 0))
		org $00CDF6		;\Enable LR scrolling
		LDA $17			;|
		AND.b #$CF		;|
		
		org $00CCC3		;|
		JSR.w $00CDDD		;/
	else
		org $00CDF6		;\Kill L/R scrolling and "auto look ahead"
		JML $00CE78		;|
		
		org $00CCC3		;|
		nop #3			;/
	endif
;Initialize scroll lines position
	org $00A7B9			;\Set initial scroll line positions
	autoclean JSL InitScrollPos	;/
	nop #4

	org read3($009708+1)+$15	;\Above hijack commented out due to LM adding jumps to skip
	autoclean JSL InitScrollPos	;|codes this patch relies on, thus have to edit LM code instead.
	nop #2				;/(not sure why sometimes the above hijacks only executes or this one).
	;LM hijack offset note (for future reference)
	;---------------------------------------------
	;009708 jsl $1082a8   [1082a8]
	;
	;1082a8 lda #$20               
	;1082aa sta $5e       [00005e] 
	;1082ac bit $13cd     [0013cd] 
	;1082af stz $13cd     [0013cd] 
	;1082b2 bvc $82b6     [1082b6] 
	;1082b4 stz $76       [000076] 
	;1082b6 bpl $82c7     [1082c7] 
	;1082b8 rep #$21               
	;1082ba lda #$0080             ;\Modify this. [offset +$12 ($1082ba - $1082a8)]
	;1082bd sta $142a     [00142a] ;/
	;1082c0 pla                    ;\Modify stack to jump to $00970f
	;1082c1 adc #$0003             ;|instead of $00970C after RTL, this skips
	;1082c4 pha                    ;/[JSR.w $00A796]
	;1082c5 sep #$20               
	;1082c7 rtl                    
	;---------------------------------------------
	;^This above hijack no longer works, as LM 3.03 changed it to this:
	;009708 jsl $1082a8   [1082a8] 
	;
	;1082a8 lda [$65]     [0685b5] 
	;1082aa and #$1f               
	;1082ac inc                    
	;1082ad sta $5e       [00005e] 
	;1082af bit $13cd     [0013cd] 
	;1082b2 stz $13cd     [0013cd] 
	;1082b5 bvc $82b9     [1082b9] 
	;1082b9 bpl $82ca     [1082ca] 
	;1082bb rep #$21               
	;1082bd lda #$0080             ;\Should modify this [offset +$15 ($1082bd - $1082a8)]
	;1082c0 sta $142a     [00142a] ;/
	;1082c3 pla                    
	;1082c4 adc #$0003             
	;1082c7 pha                    
	;1082ca rtl                    
	;---------------------------------------------
;Position scrolling lines (this moves the screen)
	org $00F72C
	autoclean JML NewXScroll	;>New horizontal scroll routine (horizontal level)

	org $00F789
	autoclean JML NewXScroll2	;>Same as above but vertical level.
	nop #1

	if !Setting_CenterScroll_ScrollType == 0
		if read1($00F810) == $5C
			autoclean read3($00F810+1)
		endif
		org $00F810
		SEC
		SBC.w $00F69F,y
	else
		org $00F810
		autoclean JML NewYScroll
	endif
	if !Setting_CenterScroll_FreeVerticalScroll == 0
		org $00F878
		db $D0
	else
		org $00F878
		db $80
	endif
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Freespace codes
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
freecode
;---------------------------------------------------------------------------
InitScrollPos: ;>JSL from $00A7B9 (actually, read3($009708+1)+$12)
	LDA.w #!Setting_CenterScroll_InitalXPos		;\Move scroll line to exact center
	STA $142A|!addr					;/for X-scroll.
	if !Setting_CenterScroll_ScrollType != 0
		LDA.w #!Setting_CenterScroll_InitalYPos		;\same as above but for Y-scroll.
		STA $142C|!addr					;/
	endif
	;LDA $1417|!addr				;\Fix a disalignment of layer 2.
	;DEC						;|
	;STA $1417|!addr				;|
	;SEP #$20					;/
	;LDA #$00					;\So screen doesn't randomly positioned
	;STA $142E|!addr					;/in a no vertical scroll area
	RTL
;---------------------------------------------------------------------------
NewXScroll: ;>JML from $00F72C
	JSL Sub_HorizPos

	LDA $5E			;>Load last screen.
	DEC			;>Minus 1
	XBA			;>Transfer it to high byte
	AND #$FF00		;>Get rid of value of $5F since we're 16-bit
	CMP $1A			;\Prevent screen from going past
	BPL .Good		;|right edge of level.
	STA $1A			;/

	.Good
	JML $00F75A		;>Continue on with the game
;---------------------------------------------------------------------------
NewXScroll2: ;>JML from $00F789
	JSL Sub_HorizPos

	LDA #$0100		;\Prevent screen from going past
	CMP $1A			;|right edge of level (vertical level)
	BPL .Good		;|
	STA $1A			;/

	.Good
	JML $00F79D
;---------------------------------------------------------------------------
	if !Setting_CenterScroll_ScrollType != 0
		NewYScroll: ;>JML from $00F810
		LDX $0100|!addr			;\Prevent screen from spawning 8 pixels down during level load
		CPX #$14			;|when transferring from a "vertical scroll at will" to "no vertical
		BNE .NoVscroll			;/scroll".
		LDX $1412|!addr			;\Value in A is reserved for something else,
		CPX #$01			;/such as other than "vertical scroll at will".
		BNE .StandardVScroll		;>If other than vertical scroll at will, use smw's behavior.

		.ScrollToMario
		if !Setting_CenterScroll_GradualScroll != 0
			LDA $142C|!addr			;\If Y position of the scroll line is above player, scroll down to player.
			CMP $00				;|
			BMI ..ScrollDown		;/
			
			..ScrollUp
			LDA $1C
			SEC
			SBC #$0008
			STA $1C
			JSL UpdatePlayerYCoordinateOnScreen
			LDA $142C
			CMP $00
			BMI ..SnapYpos
			BRA .Done
			
			..ScrollDown
			LDA $1C
			CLC
			ADC #$0008
			STA $1C
			JSL UpdatePlayerYCoordinateOnScreen
			LDA $142C|!addr
			CMP $00
			BPL ..SnapYpos
			BRA .Done
		endif
		..SnapYpos
		LDA $96			;>Mario's y position in level
		SEC			;\Distance between top of screen
		SBC $142C|!addr		;/and Mario
		STA $1C			;>And set screen Y position within level.
		.NoVscroll
		.Done
		JSL VerticalboundsCheck
		JML $00F8AA

		.StandardVScroll
		SEC			;\Restore code (if you wanted Enable if flying/climbing/etc.)
		SBC.w $00F69F,y		;|
		JML $00F814		;/
	endif
;---------------------------------------------------------------------------
Sub_HorizPos:
	.ScrollToMarioHorizontally
	if !Setting_CenterScroll_GradualScroll != 0
		SEP #$20
		LDA $0100|!addr			;\Don't start at x = 0
		CMP #$11			;|
		BCC ..NotInital			;|
		CMP #$14			;|
		BCS ..NotInital			;/

		..Inital
		REP #$20
		LDA $94				;\Inital screen x position
		SEC				;|
		SBC $142A|!addr			;|
		STA $1A 			;/

		..NotInital
		REP #$20
		LDA $142A|!addr
		CMP $00				;>Mario's x pos on-screen
		BMI ..ScrollRight
		
		..ScrollLeft
		LDA $1A
		SEC
		SBC #$0008
		STA $1A
		JSL UpdatePlayerXCoordinateOnScreen
		LDA $142A|!addr
		CMP $00
		BMI ..SnapXpos
		BRA ..PreventLeftPass
		
		..ScrollRight
		LDA $1A
		CLC
		ADC #$0008
		STA $1A
		JSL UpdatePlayerXCoordinateOnScreen
		LDA $142A|!addr
		CMP $00
		BPL ..SnapXpos
		BRA ..PreventLeftPass
	endif
	..SnapXpos
	LDA $94			;>Mario's x position in level
	SEC			;\Distance between the left edge of screen
	SBC $142A|!addr		;/and Mario
	STA $1A			;>And set screen X position within level.

	..PreventLeftPass
	LDA #$0000		;\Prevent screen from going
	CMP $1A			;|past left edge of level.
	BMI .Valid		;|
	STA $1A			;/

	.Valid
	RTL
;---------------------------------------------------------------------------
VerticalboundsCheck:
	LDA #$0000		;\Prevent screen from going past the top
	CMP $1C			;|of the level.
	BMI +			;|
	STA $1C			;/
	+
	LDA $5B			;>Load vertical screen settings
	LSR			;>Move vertical layer 1 bit flag to carry
	BCS .VerticalLevel	;>If carry set, use different Y bound

	.HorizontalLevel
	LDA $04			;>$04 Y position of the lowest screen can scroll down (compare to $13D7)
	CMP $1C			;>Compare with screen Y pos
	BPL .VertBoundDone	;>If bound Y position is more down than screen, don't set
	STA $1C
	BRA .VertBoundDone

	.VerticalLevel
	SEP #$20
	LDA $5F			;\Prevent going below the bottom
	DEC			;|edge of vertical level.
	XBA			;|
	LDA #$00		;|
	REP #$20		;|
	CMP $1C			;|
	BPL +			;|
	STA $1C			;/
	+
	.VertBoundDone
	RTL
;---------------------------------------------------------------------------
UpdatePlayerXCoordinateOnScreen:
	LDA $94
	SEC
	SBC $1A
	STA $00
	RTL
;---------------------------------------------------------------------------
UpdatePlayerYCoordinateOnScreen:
	LDA $96
	SEC
	SBC $1C
	STA $00
	RTL