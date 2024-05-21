# L68

## L68 Supported Assembly sytax

line            → (label? instruction comment?) | comment
label           → ALPHABETIC+ALPHANUMERIC
instruction     → abcd | add | adda | addi | addq | andd | andi | asl | asr | bcc | bchg | bclr | bra | bset | bsr | btst | chk | clr | cmp | cmpa | cmpi | cmpm | dbcc | dc | dcb | divs | ds | end | eor | eori | equ | exg | ext | illegal | jmp | jsr | lea | link | lsl | lsr | move | movea | movep | moveq | muls | mulu | nbcd | neg | negx | nop | not | org | ori | orr | pea | reg | reset | rol | ror | roxl | roxr | rte | rtr | rts | sbcd | scc | set | stop | sub | suba | subi | subq | subx | swap | tas | trap | trapv | tst | unlk 
comment         → ";" ALPHANUMERIC*
aRegister       → ( "A" | "a" )registerNumber
dRegister       → ( "D" | "d" )registerNumber
registerNumber  → "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" 
immediate       → "#"base?NUMBER
base            →  "%" | "@" | "$"
absolute        → base?NUMBER
