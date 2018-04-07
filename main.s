;// ============================================================================
;// MAIN (Hires Pictures Loading Part) 
;// v0.1
;// April 2018
;// A.C
;// ----------------------------------------------------------------------------
;// 
;// target: Oric / Pravetz 8D emulation mode (ORICUTRON only)
;// ============================================================================
;
;
; ON DISK: physical interleaving
; TRACK : $00
; SECTOR: $05
;
; PICTURES:
; eastwood.hir      T$01/S$00-T$02/S$0F
; yessagician.hir   T$03/S$00-T$04/S$0F
; blueface.hir      T$05/S$00-T$06/S$0F
; fists.hir         T$07/S$00-T$08/S$0F
; karate.hir        T$09/S$00-T$0A/S$0F
; trois_mats.hir    T$0B/S$00-T$0C/S$0F
; beast.hir         T$0D/S$00-T$0E/S$0F
; dragons.hir       T$0F/S$00-T$10/S$0F
; karhu.hir         T$11/S$00-T$12/S$0F
; oric1.hir         T$13/S$00-T$14/S$0F
; einstein.hir      T$15/S$00-T$16/S$0F     
; lena.hir          T$17/S$00-T$18/S$0F
; mondrian.hir      T$19/S$00-T$1A/S$0F
; homer.hir         T$1B/S$00-T$1C/S$0F
;
;// ============================================================================
;// *= $F400 ; ORG = $F400


#define FLOAD   $F000

; PZ
#define PISDEP  $A0       ; PISTE DE DEPART
#define SECDEP  $A1       ; SECTEUR DE DEPART
#define BUFFER  $A2       ; +$A3 ; ADRESSE OU L'ON CHARGE
#define TOTSEC  $A4       ; TOTAL DES SECTEURS A CHARGER 
; -------------------------------------

	.zero

	*= $50

indexP   .dsb 1           ; index images

	.text
        

        ; mode HIRES
        LDA #$1E         
        STA $BFDF

        ; clear Hires
        LDY #00
        LDX #32
        LDA #$40                 
bc      STA $A000,Y
        INY
        BNE bc
        INC bc+2
        DEX
        BNE bc
        ; ----------

        
b1      ; boucle principale
        LDX #00
b2      STX indexP

        ; chargement ROUTINES
	
        LDA TTrack,X
		STA PISDEP			; piste de départ
        LDA #$00
		STA BUFFER          ; dest (low = $00)
        STA SECDEP			; first sector  (=$00)
 		LDA #$A0			; dest (high = $A0)
		STA BUFFER+1
		LDA #$20            ; nombre de secteurs à charger ($20)
		STA TOTSEC
        		
		JSR FLOAD			; chargement !
       
        LDX indexP
        INX
        CPX #14
        BNE b2
        JMP b1

        ; --------------------------------------------

TTrack      .byt $01,$03,$05,$07,$09,$0B,$0D,$0F,$11,$13,$15,$17,$19,$1B
