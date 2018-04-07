;// ============================================================================
;// BOOT2 
;// v0.1
;// April 2018
;// A.C
;// ----------------------------------------------------------------------------
;// Adapted from Fast Load routines from EAO/APPLE PRODOS/SAM(?)
;// Origin is very unclear!
;// 
;// target: Oric / Pravetz 8D emulation mode (ORICUTRON only)
;// ============================================================================
;
; ON DISK: physical interleaving
; TRACK  : $00
; SECTORS: $07,$0E,$06,$0D
;
;// ============================================================================
;// *= $F000 ; ORG = $F000

; ROM 8D+DISKII I/O addresses

#define P0OFF      $310         ; EQUI A2 = Phase0 OFF          / DRVSM0 / $C080+SLOT*$10
#define P0ON       $311         ; EQUI A2 = Phase0 ON           / DRVSM1 / $C081+SLOT*$10
#define P1OFF      $312         ; EQUI A2 = Phase1 OFF          / DRVSM2 / $C082+SLOT*$10
#define P1ON       $313         ; EQUI A2 = Phase1 ON           / DRVSM3 / $C083+SLOT*$10
#define P2OFF      $314         ; EQUI A2 = Phase2 OFF          / DRVSM4 / $C084+SLOT*$10
#define P2ON       $315         ; EQUI A2 = Phase2 ON           / DRVSM5 / $C085+SLOT*$10
#define P3OFF      $316         ; EQUI A2 = Phase3 OFF          / DRVSM6 / $C086+SLOT*$10
#define P3ON       $317         ; EQUI A2 = Phase3 ON           / DRVSM7 / $C087+SLOT*$10

#define MOTOFF     $318         ; EQUI A2 = Motor  OFF          / DRVOFF / $C088+SLOT*$10
#define MOTON      $319         ; EQUI A2 = Motor  ON           / DRVON  / $C089+SLOT*$10
#define DRSEL1     $31A         ; EQUI A2 = Select DR1          / DRVSL1 / $C08A+SLOT*$10
#define DRSEL2     $31B         ; EQUI A2 = Select DR2          / DRVSL2 / $C08B+SLOT*$10

#define SHIFTREG   $31C         ; EQUI A2 = STROBE DATA LATCH   / DRVRD  / $C08C+SLOT*$10 (Q6L)
#define DATAREG    $31D         ; EQUI A2 = LOAD DATA LATCH     / DRVWR  / $C08D+SLOT*$10 (Q6H)
#define READMODE   $31E         ; EQUI A2 = SET READ MODE       / DRVRDM / $C08E+SLOT*$10 (Q7L)
#define WRITEMODE  $31F         ; EQUI A2 = SET WRITE MODE      / DRVWRM / $C08F+SLOT*$10 (Q7H)
                                                    
; from Beneath Apple DOS (Don Worth/Pieter Lechner)
; Q7L with Q6L = Read
; Q7L with Q6H = Sens Write Protect
; Q7H with Q6L = Write
; Q7H with Q6H = Load Write Latch

#define 8dRomStart $320




; BOOT0 USED adresses
#define TNIBL      $B46C        ; deNibblelization Table (generated during BOOT0)
#define SECONDBUF  $B400        ; buffer primaire 
; -------------------------------------

;//
;// Zero page definition
;//

    .zero

	*= $A0

_zp_start_

; PAGE ZERO
                          
;-PARAMETRES D'ENTREE
PISDEP  .dsb 1      ; $A0       ; PISTE DE DEPART
SECDEP  .dsb 1      ; $A1       ; SECTEUR DE DEPART
BUFFER  .dsb 2      ; $A2 ;+$A3 ; ADRESSE OU L'ON CHARGE
TOTSEC  .dsb 1      ; $A4       ; TOTAL DES SECTEURS A CHARGER 

ACCA    .dsb 1      ; $A5		; valeurs TEMP pour A
ACCB    .dsb 1      ; $A6
ACCC	.dsb 1      ; $A7                          

; utilisation de [$AA-$FF] :
#define INTER       $0            
#define INTER2	    $FE		

_zp_end_


	
 
    .text
  
; $F000               
FLOAD
; entrée : PISDEP/SECDEP/TOTSEC/BUFFER
	
			; init lecture
            LDA MOTON       ; motor on
         	LDA DRSEL1      ; select drive 1 
         	LDA READMODE    ; MODE... 
         	LDA SHIFTREG    ; ...LECTURE (Q7L + Q6L)

	        LDA P0OFF
        	LDA P1OFF
         	LDA P2OFF
         	LDA P3OFF     ; INIT PHASES POUR BRAS
                          ;
         	LDA #1
         	JSR TEMPO
                          ;
         	LDY #3
INILEC2  	LDA #0
         	JSR TEMPO
         	DEY
         	BNE INILEC2
			; ----

			; calcul des buffer 
			LDA BUFFER
         	STA BUF3+1
         	SEC
         	SBC #$AB
         	STA BUF1+1
         	LDA BUFFER+1
         	SBC #0
         	STA BASE1
                          
         	LDA BUFFER+1
         	STA BASE3
                          
         	LDA BUFFER
         	SEC
         	SBC #$54
         	STA BUF2+1
         	LDA BUFFER+1
         	SBC #0
         	STA BASE2
			; ----

			; lecture TOUT
         	LDA SECDEP	
            STA FIRSTSEC+1
            LDA TOTSEC			; initialisation compteur du nombre de secteurs à lire
        	STA COUNT2			; compteur principal (décrémenter à chaque lecture)  
                          
LITDIS1  	LDA #00
			STA COUNT3			; initialisation compteur nb de secteurs à lire pour la piste courante
			LDA COUNT2
			STA COUNT1			; nb global de secteurs restant à lire (cette piste comprise)
			LDX PISDEP			; piste à atteindre
			JSR ARMOVE			; déplacement tête sur la piste à lire

         	; mark sectors à lire pour la piste courante
			LDA #01				; marker
FIRSTSEC	LDX #00				; premier secteur de la piste courante à lire
BMARK
			STA TMARKSECT,X		; on remplit
			INC COUNT3
			DEC COUNT1			
			BEQ s1				; cas : dernier secteur de la dernière piste à lire ?	
			INX
			CPX #$10			; 16 ? piste pleine
			BNE BMARK
			
s1	        JSR LITPIS		; lecture piste
         	BNE fin			; sans encombre ? on continue
         	
         	LDA #00
			STA FIRSTSEC+1		; on met à 0 pour le début de la piste suivante
         	LDA COUNT2			; au bout du nombre
         	BEQ	fin 			; de secteurs total à lire ?
         	INC PISDEP			; si non piste suivante
         	JMP LITDIS1 		; on boucle
                          
fin	    	LDA MOTOFF  		; drive off
         	RTS					; sortie


; ============================================================================
; routine de lecture d'une piste
; in		: BASE1,BASE2,BASE3,PISTE
; out		: BASE1,BASE2,BASE3, 
; retour 	: 0 si OK, $FF sinon
                          
LITPIS

            LDA COUNT3
            STA NBSEC		; nb de secteurs à lire pour cette piste
                          
LITPIS6                  
         	JSR	LOCSEC			; localisation secteur. OK ? 
         	BNE LITPIS6			; si non (recalibration a eu lieu), on boucle sur la localisation secteur
                          
LITPIS3  	LDY	SECTOR
         	LDA	TMARKSECT,Y		; on checke si le secteur est "bien" à lire
         	BEQ	LITPIS6			; si non on en localise un autre...

			; calcul buffer pour la lecture de CE secteur
         	LDA	SECTOR			
         	SEC			
         	SBC	FIRSTSEC+1		; on soustrait le premier secteur de la piste en cours de lecture (SECDEP si début, 00 sinon)		
         	TAY
         	CLC
         	ADC	BASE1
         	STA	BUF1+2
         	TYA
         	CLC
         	ADC	BASE2
         	STA	BUF2+2
         	TYA
         	CLC
         	ADC	BASE3
         	STA	BUF3+2
         	; ----

         	JSR LITSEC			; lit secteur. OK ?
         	BNE LITPIS6			; si non, on retry (infinite)
                          
LITPIS5  	LDY	SECTOR			; on marque le secteur
         	LDA	#0				; comme lu
         	STA	TMARKSECT,Y		; OK
			DEC COUNT2			; on décrémente le nombre total de secteurs à lire
         	DEC COUNT3			; on décrémente le nombre de secteurs à lire pour CETTE piste
         	BNE	LITPIS6			; il en reste ? Oui, on boucle (on cherche le secteur suivant). Non, on sort.
                          
            ; sortie - mise à jour des buffers pour la piste suivante
         	LDA	BASE1
         	CLC
         	ADC	NBSEC
         	STA	BASE1
         	LDA	BASE2
         	CLC
         	ADC	NBSEC
         	STA	BASE2
         	LDA	BASE3
         	CLC
         	ADC	NBSEC
         	STA	BASE3
         	LDA #00				; tout est (normalement) OK
         	RTS

; ============================================================================
; routine localisation secteur / recalibration si nécessaire
; in 	: PISTE
; out 	: n° SECTOR localisé

LOCSEC
   	
         	; check entete       
LOCSEC11 	LDA	SHIFTREG
         	BPL LOCSEC11
         	CMP	#$D5
         	BNE	LOCSEC11
LOCSEC1  	LDA SHIFTREG
         	BPL LOCSEC1
         	CMP #$AA
         	BNE	LOCSEC11
LOCSEC2  	LDA	SHIFTREG
         	BPL	LOCSEC2
         	CMP #$96
         	BNE	LOCSEC11
            
            ; lecture info du sector
         	LDY	#0
LOCSEC4  	LDA SHIFTREG
         	BPL LOCSEC4
         	STA LOCSECA
LOCSEC5  	LDA SHIFTREG
         	BPL LOCSEC5
         	SEC
         	ROL LOCSECA
         	AND LOCSECA
         	STA TENTETE,Y
         	INY
         	CPY	#3
         	BNE LOCSEC4
            ; sauve numéro (software) du secteur 
         	LDX	SECPHY
         	LDA TSECT,X
         	STA	SECTOR
         	; check piste
         	LDA	TRACK
         	CMP	PISDEP
         	BNE	recal			; recalibration si ce n'est pas la bonne piste
            ; good guy (z = 0 , BNE non pris - pas besoin de LDA #00)
            RTS       
                   
recal      ; retour piste 0
         	LDA #48
         	STA CURTRK1
         	LDX #0
         	JSR ARMOVE
            
            ; déplacement piste demandée
         	LDX PISDEP
         	JSR ARMOVE
         	LDA #$FF			; pour forcer une relecture      
		  	RTS					;
 
; ============================================================================
; routine de lecture/décodage d'un SECTEUR
; 
LITSEC   	
		

            ; lecture entête DATA (D5AAAD)
LITSEC11 	LDA SHIFTREG
         	BPL LITSEC11
         	CMP #$D5
         	BNE LITSEC11
LITSEC8  	LDA SHIFTREG
         	BPL LITSEC8
          	CMP #$AA
         	BNE LITSEC11
LITSEC9  	LDA SHIFTREG
         	BPL LITSEC9
         	CMP #$AD
         	BNE LITSEC11
               
            ; lecture/decodage DATA           
         	LDA #0
         	LDX #$AA
LITSEC1  	STA ACCA
LITSEC7  	LDY SHIFTREG
         	BPL LITSEC7
         	LDA TABDEC,Y
         	STA INTER,X
         	EOR ACCA
         	INX
         	BNE LITSEC1
                         
         	LDX #$AA
         	BNE LITSEC2		; always jmp
BUF1     	STA $FFFF,X
LITSEC2  	LDY SHIFTREG
         	BPL LITSEC2
         	EOR TABDEC,Y
         	LDY INTER,X
         	EOR FONC1,Y
         	INX
         	BNE BUF1
         	
         	STA ACCB              
         	AND #$FC
                          
         	LDX #$AA
LITSEC3  	LDY SHIFTREG
         	BPL LITSEC3
         	EOR TABDEC,Y
         	LDY INTER,X
         	EOR FONC2,Y
BUF2     	STA $FFFF,X
         	INX
         	BNE LITSEC3
         	
         	AND	#$FC
                         
LITSEC13 	LDY	SHIFTREG
         	BPL	LITSEC13
         	LDX #$AC
LITSEC12 	EOR TABDEC,Y
         	LDY INTER2,X
         	EOR FONC3,Y
BUF3     	STA $FFFF,X
LITSEC4  	LDY SHIFTREG
         	BPL LITSEC4
         	INX
         	BNE LITSEC12
         	
         	AND #$FC              
         	EOR TABDEC,Y
         	BNE errchk

LITSEC6  	LDA BUF1+1
         	STA LITSEC14+1
         	LDA BUF1+2
         	CLC
         	ADC #1
         	STA LITSEC14+2
         	LDA ACCB
LITSEC14 	STA $FFFF
			LDA #00				; retour OK
         	RTS              	;

; ERREUR DE CHECKSUM
errchk      LDA #$FF
         	RTS

; ============================================================================
; routine déplacement tête de lecture - positionnement sur la piste                          
; In 	: X : PISTE , (CURTRK1 = 0)
; Out	: CURTRK1

ARMOVE 

    		TXA				; piste à atteindre -> A
         	ASL   
         	STA ACCA
ARMOVE1  	LDA CURTRK1
         	STA ACCB
         	SEC
         	SBC ACCA
         	BEQ ARMOVE2
         	BCS ARMOVE3
         	INC CURTRK1
         	BCC ARMOVE4
ARMOVE3  	DEC CURTRK1
ARMOVE4  	JSR ARMOVE5
         	JSR ARMOVE6
         	LDA ACCB
         	AND #3
         	ASL  
         	ORA #0         ;POUR RESPECTER LE TIMING
         	TAY
         	LDA P0OFF,Y
         	JSR ARMOVE6
         	BEQ ARMOVE1
ARMOVE5  	LDA CURTRK1
         	AND #3
         	ASL  
         	ORA #0         ;IDEM
         	TAY
         	LDA P0ON,Y
ARMOVE2  	RTS
ARMOVE6  	LDA #$28
TEMPO     	SEC
ARMOVE7  	STA ACCC
ARMOVE8  	SBC #1
         	BNE ARMOVE8
         	LDA ACCC
         	SBC #1
         	BNE ARMOVE7
         	RTS

; ============================================================================
CURTRK1   .byt 0		; piste de départ DRIVE 1 <= A fixer avant premier appel à FLOAD si !=0

TMARKSECT .byt $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00                       
;TSECT     .byt $00,$07,$0E,$06,$0D,$05,$0C,$04,$0B,$03,$0A,$02,$09,$01,$08,$0F   ; interleaving DOS/normal
TSECT     .byt $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0A,$0B,$0C,$0D,$0E,$0F  ; interleaving physical
LOCSECA   .byt 0
SECTOR    .byt 0   
                      
TENTETE
VOLUME    .byt 0
TRACK     .byt 0
SECPHY    .byt 0

COUNT1	  .byt 0
COUNT2	  .byt 0
COUNT3	  .byt 0
         
BASE1	  .byt 0
BASE2	  .byt 0
BASE3	  .byt 0
         
NBSEC	  .byt 0
; =============================================================================

; Tables Décodage + variables diverses
; --> 258 valeurs
FONC1     .byt 00
FONC2	  .byt 00
FONC3     .byt 00,00,02,00,00,00,01,00,00,00,03,00,00,00,00,02,00,00,02,02,00,00,01,02,00,00,03,02,00,00,00,01
		  .byt 00,00,02,01,00,00,01,01,00,00,03,01,00,00,00,03,00,00,02,03,00,00,01,03,00,00,03,03,00,00,00,00
		  .byt 02,00,02,00,02,00,01,00,02,00,03,00,02,00,00,02,02,00,02,02,02,00,01,02,02,00,03,02,02,00,00,01
		  .byt 02,00,02,01,02,00,01,01,02,00

TABDEC	; $96 bytes (150) inutilisés entre TABDEC ET FTABDEC d'où l'idée de reprendre une partie de la table FONC !	
		  .byt 03,01,02,00,00,03,02,00,02,03,02,00,01,03,02,00,03,03,02,00,00,00							   ; 22
		  .byt 01,00,02,00,01,00,01,00,01,00,03,00,01,00,00,02,01,00,02,02,01,00,01,02,01,00,03,02,01,00,00,01 ; 32 
		  .byt 01,00,02,01,01,00,01,01,01,00,03,01,01,00,00,03,01,00,02,03,01,00,01,03,01,00,03,03,01,00,00,00 ; 32
		  .byt 03,00,02,00,03,00,01,00,03,00,03,00,03,00,00,02,03,00,02,02,03,00,01,02,03,00,03,02,03,00,00,01 ; 32
		  .byt 03,00,02,01,03,00,01,01,03,00,03,01,03,00,00,03,03,00,02,03,03,00,01,03,03,00,03,03,03,00,00,00 ; 32
; <--																										   ; = 150 !

FTABDEC   .byt $00,$04
          .byt $FC
          .byt $FC,$08,$0C
          .byt $FC,$10,$14,$18
          .byt $FC
          .byt $FC
          .byt $FC
          .byt $FC
          .byt $FC
          .byt $FC,$1C,$20
          .byt $FC
          .byt $FC
          .byt $FC,$24,$28,$2C,$30,$34
          .byt $FC
          .byt $FC,$38,$3C,$40,$44,$48,$4C
          .byt $FC,$50,$54,$58,$5C,$60,$64,$68
          .byt $FC
          .byt $FC
          .byt $FC
          .byt $FC
          .byt $FC
          .byt $FC
          .byt $FC
          .byt $FC
          .byt $FC
          .byt $FC
          .byt $FC,$6C
          .byt $FC,$70,$74,$78
          .byt $FC
          .byt $FC
          .byt $FC,$7C
          .byt $FC
          .byt $FC,$80,$84
          .byt $FC,$88,$8C,$90,$94,$98,$9C,$A0
          .byt $FC
          .byt $FC
          .byt $FC
          .byt $FC
          .byt $FC,$A4,$A8,$AC
          .byt $FC,$B0,$B4,$B8,$BC,$C0,$C4,$C8
          .byt $FC
          .byt $FC,$CC,$D0,$D4,$D8,$DC,$E0
          .byt $FC,$E4,$E8,$EC,$F0,$F4,$F8
          .byt $FC
