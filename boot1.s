;// ============================================================================
;// BOOT1
;// v0.1
;// April 2018
;// A.C
;// ----------------------------------------------------------------------------
;// Adapted from BOOT1 routines coming from Apple II 80s French scene.
;// Origin is very unclear!
;// 
;// target: Oric / Pravetz 8D emulation mode (ORICUTRON only)
;// ============================================================================
;
; ON DISK: physical interleaving
; TRACK : $00
; SECTOR: $00
;
; note: THIS DISK WILL NOT BOOT ON REAL HARDWARE. 
; Because interleaving is currently set for ORICUTRON compatibility (DOS3.3 hard-coded).
; On a real DISK II, sectors will not be loaded properly (need to set a different interleaving)
;
;// ============================================================================
;// *= $B800 ; ORG = $B800

; ROM 8D I/O addresses

#define P0OFF      $310 
#define P0ON       $311     
#define P1OFF      $312
#define P1ON       $313
#define P2OFF      $314
#define P2ON       $315
#define P3OFF      $316
#define P3ON       $317
#define MOTOFF     $318
#define MOTON      $319         ; (EQUI A2 - MTRON)
#define DRSEL1     $31A         ; (EQUI A2 - SELDRV1)
#define DRSEL2     $31B
#define SHIFTREG   $31C         ; (EQUI A2 - Q6L = $C08C)
#define DATAREG    $31D
#define READMODE   $31E         ; (EQUI A2 - Q7L = )
#define WRITEMODE  $31F    
#define 8dRomStart $320

; BOOT0 USED adresses
#define TNIBL      $B46C        ; deNibblelization Table (generated during BOOT0)
#define SECONDBUF  $B400        ; buffer primaire 
; -------------------------------------
#define MAIN       $F400
; -------------------------------------
;//
;// Zero page definition
;//

	.zero

	*= $78

ptr_DESTBUF		    .dsb 2      ; $78/$79
tmp1				.dsb 1      ; $7A


	.text

; $B800
        
        ; disable ROM to use overlay RAM ($C000-$FFFF)

        ; from iss: http://forum.defence-force.com/viewtopic.php?f=23&t=1277&sid=cf89250b43e1b4e963f3fd93fd808042&start=15#p13312
        ; for DOS-8D ROM BOOT CODE (advanced version)
        ; POKE#380,X : RAM16K - disabled   BASIC ROM - enabled    DRIVER - activated (default state after RESET)
        ; POKE#381,X : RAM16K - enabled    BASIC ROM - disabled   DRIVER - activated
        ; POKE#382,X : RAM16K - disabled   BASIC ROM - enabled    BOOT - activated
        ; POKE#383,X : RAM16K - enabled    BASIC ROM - disabled   BOOT - activated
        
       
        SEI                   ; disable INT
        LDA #$01
        STA $383              ; RAM 16K ENABLED/BASIC ROM DISABLED/BOOT ACTIVATED

        ; --------------------------------------------
        ; READING DIRECTLY DATA ! NO check of the ADDRESSES
        ; interleaving for DATA to read is very important.
        

        LDA #00
        STA ptr_DESTBUF       ; Buffer Low (Dest Buffer)
        LDA #$F0              ; Buffer Hi (Dest Buffer)
        STA ptr_DESTBUF+1
br0
r0      LDA SHIFTREG
        BPL r0
rt1     EOR #$D5              ; check Header 1 champ DA
        BNE r0
r1      LDA SHIFTREG
        BPL r1
        CMP #$AA              ; check Header 2 champ DA
        BNE rt1
r2      LDA SHIFTREG
        BPL r2
        CMP #$AD              ; check Header 3 champ DA
        BNE rt1
        
        LDA #$00
        LDY #$56              ; 80 nibbles

br3
        STY tmp1
r3      LDY SHIFTREG          ; on commence à lire
        BPL r3   
        EOR TNIBL-$96,Y       ; $B46C-$96 = $NIBBLE TABLE (issu du BOOT0) - $96
        LDY tmp1
        DEY
        STA SECONDBUF,Y       ; vers le Buffer secondaire
        BNE br3

br4
        STY tmp1
r4      LDY SHIFTREG          ; lecture DATA
        BPL r4
        EOR TNIBL-$96,Y       ; $B46C-$96 = $NIBBLE TABLE (issu du BOOT0) - $96
        LDY tmp1
        STA (ptr_DESTBUF),Y   ; vers le Buffer primaire
        INY
        BNE br4

r5      LDY SHIFTREG
        BPL r5
        EOR TNIBL-$96,Y       ; dénibblelization du checksum
        BNE BADGUY            ; verification: =0 ? ça colle pas ? -> badguy

        LDY #$00              ; début Post Nibblelisation
 bn1    LDX #$56
 bn2    DEX
        BMI bn1
        LDA (ptr_DESTBUF),Y   ; buffer primaire
        LSR SECONDBUF,X       ; buffer secondaire
        ROL
        LSR SECONDBUF,X
        ROL
        STA (ptr_DESTBUF),Y   ; sauvegarde buffer final
        INY
        BNE bn2
        INC ptr_DESTBUF+1     ; Dest Buffer Hi + 1 (next page)
        DEC nbRSECT           ; on décrémente le nb de secteur à lire
        BNE br0


GOODGUY JMP MAIN              ; saut Boot 2. Voilà c'est fini!
BADGUY  JMP BADGUY            ; infinite loop if error
         
nbRSECT .byt 05               ; nombre de secteurs à lire   (4 pour FLOAD + 1 pour MAIN)