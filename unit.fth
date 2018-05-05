0 <ok> !
\ This is a Forth test bench for: <https://github.com/howerj/embed>
\
\ The test bench consists of a few support words, and three words that should
\ be used together, they are 'T{', '->' and '}T'.
\
\ 'T{' sets up the test, the test itself should appear on a single line, with
\ the '}T' terminating it. The arguments to a function to test and function to
\ test should appear to the left of the '->' word, and the values it returns
\ should to the right of it. The test bench must also account for any items
\ already on the stack prior to calling 'T{' which must be ignored.
\
\ A few other words are also defined, but they are not strictly needed, they
\ are 'throws?' and 'statistics'. 'throws?' parses the next word in the
\ input stream, and executes it, catching any exceptions. It empties the
\ variable stack and only returns the exception number thrown. This can be
\ used to test that words throw the correct exception in given circumstances.
\ 'statistics' is used for information about the tests; how many tests failed,
\ and how many tests were executed.
\
\ The test benches are not only used to test the internals of the Forth system,
\ and their edge cases, but also to document how the words should be used, so
\ words which this test bench relies on and trivial words are also tested. The
\ best test bench is actually the cross compilation method used to create new
\ images with the metacompiler, it tests nearly every single aspect of the
\ Forth system.
\
\ It might be worth setting up another interpreter loop until the corresponding
\ '}T' is reached so any exceptions can be caught and dealt with.
\
\ The organization of this file needs to be improved, it also contains
\ some useful extensions to the language not present in the 'meta.fth' file.

\ A few generic helper words will be built, to check if a word is defined, or
\ not, and to conditionally execute a line.
: undefined? token find nip 0= ; ( "name", -- f: Is word not in search order? )
: defined? undefined? 0= ;       ( "name", -- f: Is word in search order? )
: ?\ 0= if [compile] \ then ;    ( f --, <string>| : conditional compilation )

\ As a space saving measure some standard words may not be defined in the
\ core Forth image. If they are not defined, we define them here.
undefined? 0<   ?\ : 0< 0 < ;
undefined? 1-   ?\ : 1- 1 - ;
undefined? 2*   ?\ : 2* 1 lshift ;
undefined? rdup ?\ : rdup r> r> dup >r >r >r ;
undefined? 1+!  ?\ : 1+! 1 swap +! ;

: dnegate invert >r invert 1 um+ r> + ; ( d -- d )
: arshift ( n u -- n : arithmetic right shift )
  2dup rshift >r swap $8000 and
  if $10 swap - -1 swap lshift else drop 0 then r> or ;
: 2/  1 rshift ; ( u -- u : non compliant version of '2/' )
: d2* over $8000 and >r 2* swap 2* swap r> if 1 or then ;
: d2/ dup      1 and >r 2/ swap 2/ r> if $8000 or then swap ;
: d+  >r swap >r um+ r> + r> + ; 
\ : d+ rot + -rot um+ rot + ;
: d- dnegate d+ ;
: d= rot = -rot = and ;
: 2swap >r -rot r> -rot ;
: s>d  dup 0< ;                ( n -- d )
: dabs s>d if dnegate then ;   ( d -- ud )
: 2over ( n1 n2 n3 n4 -- n1 n2 n3 n4 n1 n2 )
  >r >r 2dup r> swap >r swap r> r> -rot ;
: 2, , , ;
: 2constant create 2, does> 2@ ;

variable test
test +order definitions hex

variable total    ( total number of tests )
variable passed   ( number of tests that passed )
variable vsp      ( stack depth at execution of '->' )
variable vsp0     ( stack depth at execution of 'T{' )
variable n        ( temporary store for 'equal' )

: quine source type cr ;                 ( -- : print out current input line )
: ndrop for aft drop then next ;         ( a0...an n -- )
: ndisplay for aft . then next ;         ( a0...an n -- )
: empty-stacks depth ndrop ;             ( a0...an -- )
: .pass   ."   ok: " space quine ;       ( -- )
: .failed ." fail: " space quine ;       ( -- )
: pass passed 1+! ;                      ( -- )
: fail empty-stacks -b throw ;           ( -- )

\ 'equal' is the most complex word in this test bench, it tests whether two
\ groups of numbers of the same length are equal, the length of the numbers
\ is specified by the first argument to 'equal'.
: equal ( a0...an b0...bn n -- a0...an b0...bn n f )
  dup n !
  for aft
    r@ pick r@ n @ 1+ + pick xor if rdrop n @ 0 exit then
  then next n @ -1 ;

\ '?stacks' is given two numbers representing stack depths, if they are
\ not equal it prints out an error message, and calls 'abort'.
: ?stacks ( u u -- )
  2dup xor
  if
    .failed ." Too Few/Many Arguments Provided" cr
    ." Expected:  " u. cr
    ." Got: "       u. cr
    ." Full Stack:" .s cr
    fail exit
  else 2drop then ;

\ 'equal?' takes two lists of numbers of the same length and checks if they
\ are equal, if they are not then an error message is printed and 'abort'
\ is called.
: ?equal ( a0...an b0...bn n -- )
  dup >r
  equal nip 0= if
    .failed ." Argument Value Mismatch" cr
    ." Expected:  " r@ ndisplay cr
    ." Got: "       r@ ndisplay cr
    fail exit
  then r> 2* ndrop ;

only forth definitions test +order

\ @todo update forth syntax highlighting file for 'T{' and '}T'
\ in the <https://github.com/howerj/forth.vim> project

: }T depth vsp0 @ - vsp @ 2* ?stacks vsp @ ?equal pass .pass ;
: -> depth vsp0 @ - vsp ! ;
: T{ depth vsp0 ! total 1+! ;
: statistics total @ passed @ ;
: throws? [compile] ' catch >r empty-stacks r> ; ( "name" -- n  )

hide test
only forth definitions

\ We can define some more functions to test to make sure the arithmetic
\ functions, control structures and recursion works correctly, it is
\ also handy to have these functions documented somewhere in case they come
\ in use
: factorial dup 2 u< if drop 1 exit then dup 1- recurse * ;  ( u -- u )
: permutations over swap - factorial swap factorial swap / ; ( u1 u2 -- u )
: combinations dup dup permutations >r permutations r> / ;   ( u1 u2 -- u )
: gcd dup if tuck mod recurse exit then drop ;               ( u1 u2 -- u )
: lcm 2dup gcd / * ;                                         ( u1 u2 -- u )
: square dup * ;                                             ( u -- u )
: limit rot min max ;                                        ( u hi lo -- u )
: sum 1- 0 $7fff limit for aft + then next ;                 ( a0...an n -- n )

\ From: https://en.wikipedia.org/wiki/Integer_square_root
\ This function computes the integer square root of a number.
: sqrt ( n -- u : integer square root )
  s>d  if -$b throw then ( does not work for signed values )
  dup 2 < if exit then      ( return 0 or 1 )
  dup                       ( u u )
  2 rshift recurse 2*       ( u sc : 'sc' == unsigned small candidate )
  dup                       ( u sc sc )
  1+ dup square             ( u sc lc lc^2 : 'lc' == unsigned large candidate )
  >r rot r> <               ( sc lc bool )
  if drop else nip then ;   ( return small or large candidate respectively )

: log ( u base -- u : compute the integer logarithm of u in 'base' )
  >r
  dup 0= if -b throw then ( logarithm of zero is an error )
  0 swap
  begin
    swap 1+ swap rdup r> / dup 0= ( keep dividing until 'u' is 0 )
  until
  drop 1- rdrop ;

: log2 2 log ; ( u -- u : compute the integer logarithm of u in base )

\ http://forth.sourceforge.net/algorithm/bit-counting/index.html
: count-bits ( number -- bits )
  dup $5555 and swap 1 rshift $5555 and +
  dup $3333 and swap 2 rshift $3333 and +
  dup $0f0f and swap 4 rshift $0f0f and +
  $ff mod ;

\ http://forth.sourceforge.net/algorithm/firstbit/index.html
: first-bit ( number -- first-bit )
  dup   1 rshift or
  dup   2 rshift or
  dup   4 rshift or
  dup   8 rshift or
  dup $10 rshift or
  dup   1 rshift xor ;

: gray-encode dup 1 rshift xor ; ( gray -- u )
: gray-decode ( u -- gray )
\ dup $10 rshift xor ( <- 32 bit )
  dup   8 rshift xor 
  dup   4 rshift xor
  dup   2 rshift xor 
  dup   1 rshift xor ;

: binary $2 base ! ;

\ : + begin dup while 2dup and 1 lshift >r xor r> repeat drop ;

\ \ http://forth.sourceforge.net/word/n-to-r/index.html
\ \ Push n+1 elements on the return stack.
\ : n>r ( xn..x1 n -- , R: -- x1..xn n )
\   dup
\   begin dup
\   while rot r> swap >r >r 1-
\   repeat
\   drop r> swap >r >r ; \ compile-only
\ 
\ \ http://forth.sourceforge.net/word/n-r-from/index.html
\ \ pop n+1 elements from the return stack.
\ : nr> ( -- xn..x1 n, R: x1..xn n -- )
\     r> r> swap >r dup
\     begin dup
\     while r> r> swap >r -rot 1-
\     repeat
\     drop ; \ compile-only

\ : ?exit if rdrop exit then ;

\ $fffe constant rp0
\ : rdepth rp0 rp@ - chars ;
\ \ @todo 'rpick' picks the wrong way around
\ : rpick cells cell+ rp0 swap - @ ; 
\ 
\ \ @todo do not print out 'r.s' on its loop counter when 'r.s' runs
\ : r.s ( -- print out the return stack )
\   [char] < emit rdepth 0 u.r [char] > emit
\   rdepth for aft r@ rpick then next 
\   rdepth for aft u. then next ;
\ 
\ : +leading ( b u -- b u: skip leading space )
\     begin over c@ dup bl = swap 9 = or while 1 /string repeat ;
\ 
\ \ @todo fix >number and numeric input to work with doubles...
\ : >d ( a u -- d|ud )
\   0 0 2swap +leading
\   ?dup if
\     0 >r ( sign )
\     over c@
\     dup  [char] - = if drop rdrop -1 >r 1 /string 
\     else [char] + = if 1 /string then then
\     >number nip 0<> throw
\     r> if dnegate then ( retrieve sign )
\   else drop then ;


\ http://forth.sourceforge.net/word/string-plus/index.html
\ ( addr1 len1 addr2 len2 -- addr1 len3 )
\ append the text specified by addr2 and len2 to the text of length len2
\ in the buffer at addr1. return address and length of the resulting text.
\ an ambiguous condition exists if the resulting text is larger
\ than the size of buffer at addr1.
\ : string+ ( bufaddr buftextlen addr len -- bufaddr buftextlen+len )
\        2over +         ( ba btl a l bta+btl )
\        swap dup >r     ( ba btl a bta+btl l ) ( r: l )
\        move
\        r> + ;


\ ( addr1 len1 c -- addr1 len2 )
\ append c to the text of length len2 in the buffer at addr1.
\ Return address and length of the resulting text.
\ An ambiguous condition exists if the resulting text is larger
\ than the size of buffer at addr1.
\ : string+c ( addr len c -- addr len+1 )
\   dup 2over + c! drop 1+ ;

\ http://forth.sourceforge.net/algorithm/unprocessed/valuable-algorithms.txt
\ : -m/mod over 0< if dup    >r +       r> then u/mod ;         ( d +n - r q )
\ :  m/     dup 0< if negate >r dnegate r> then -m/mod swap drop ; ( d n - q )

.( BEGIN FORTH TEST SUITE ) cr
.( BASE to decimal ) cr
decimal

.s
T{  1. ->  1 0 }T
\ T{ -2. -> -2 -1 }T
\ T{ : RDL1 6. ; RDL1 -> 6 0 }T
\ T{ : RDL2 -4. ; RDL2 -> -4 -1 }T

T{               ->  }T
T{  1            ->  1 }T
T{  1 2 3        ->  1 2 3 }T
T{  1 1+         ->  2 }T
T{  2 2 +        ->  4 }T
T{  3 2 4 within -> -1 }T
T{  2 2 4 within -> -1 }T
T{  4 2 4 within ->  0 }T
T{ 98 4 min      ->  4 }T
T{  1  5 min     ->  1 }T
T{ -1  5 min     -> -1 }T
T{ -6  0 min     -> -6 }T
T{  55 3 max     -> 55 }T
T{ -55 3 max     ->  3 }T
T{  3 10 max     -> 10 }T
T{ -2 negate     ->  2 }T
T{  0 negate     ->  0 }T
T{  2 negate     -> -2 }T
T{ $8000 negate  -> $8000 }T
T{  0 aligned    ->  0 }T
T{  1 aligned    ->  2 }T
T{  2 aligned    ->  2 }T
T{  3 aligned    ->  4 }T
T{  3  4 >       ->  0 }T
T{  3 -4 >       -> -1 }T
T{  5  5 >       ->  0 }T
T{  6  6 u>      ->  0 }T
T{  9 -8 u>      ->  0 }T
T{  5  2 u>      -> -1 }T
T{ -4 abs        ->  4 }T
T{  0 abs        ->  0 }T
T{  7 abs        ->  7 }T
T{ $100 $10 $8  /string -> $108 $8 }T
T{ $100 $10 $18 /string -> $110 $0 }T
T{ 9 log2 -> 3 }T
T{ 8 log2 -> 3 }T
T{ 4 log2 -> 2 }T
T{ 2 log2 -> 1 }T
T{ 1 log2 -> 0 }T
T{ $ffff count-bits -> $10 }T
T{ $ff0f count-bits -> $C }T
T{ $f0ff count-bits -> $C }T
T{ $0001 count-bits -> $1 }T
T{ $0000 count-bits -> $0 }T
T{ $0002 count-bits -> $1 }T
T{ $0032 count-bits -> $3 }T
T{ $0000 first-bit  -> $0 }T
T{ $0001 first-bit  -> $1 }T
T{ $0040 first-bit  -> $40 }T
T{ $8040 first-bit  -> $8000 }T
T{ $0005 first-bit  -> $0004 }T

.( BINARY BASE ) cr
binary

T{ 0    gray-encode ->    0 }T
T{ 1    gray-encode ->    1 }T
T{ 10   gray-encode ->   11 }T
T{ 11   gray-encode ->   10 }T
T{ 100  gray-encode ->  110 }T
T{ 101  gray-encode ->  111 }T
T{ 110  gray-encode ->  101 }T
T{ 111  gray-encode ->  100 }T
T{ 1000 gray-encode -> 1100 }T
T{ 1001 gray-encode -> 1101 }T
T{ 1010 gray-encode -> 1111 }T
T{ 1011 gray-encode -> 1110 }T
T{ 1100 gray-encode -> 1010 }T
T{ 1101 gray-encode -> 1011 }T
T{ 1110 gray-encode -> 1001 }T
T{ 1111 gray-encode -> 1000 }T

T{ 0    gray-decode ->    0 }T
T{ 1    gray-decode ->    1 }T
T{ 11   gray-decode ->   10 }T
T{ 10   gray-decode ->   11 }T
T{ 110  gray-decode ->  100 }T
T{ 111  gray-decode ->  101 }T
T{ 101  gray-decode ->  110 }T
T{ 100  gray-decode ->  111 }T
T{ 1100 gray-decode -> 1000 }T
T{ 1101 gray-decode -> 1001 }T
T{ 1111 gray-decode -> 1010 }T
T{ 1110 gray-decode -> 1011 }T
T{ 1010 gray-decode -> 1100 }T
T{ 1011 gray-decode -> 1101 }T
T{ 1001 gray-decode -> 1110 }T
T{ 1000 gray-decode -> 1111 }T

.( DECIMAL BASE ) cr
decimal
T{ 50 25 gcd -> 25 }T
T{ 13 23 gcd -> 1 }T

T{ 1 2 3 4 5 1 pick -> 1 2 3 4 5 4 }T
T{ 1 2 3 4 5 0 pick -> 1 2 3 4 5 5 }T
T{ 1 2 3 4 5 3 pick -> 1 2 3 4 5 2 }T

T{ 4  square -> 16 }T
T{ -1 square -> 1 }T
T{ -9 square -> 81 }T

T{ 6 factorial -> 720  }T
T{ 0 factorial -> 1  }T
T{ 1 factorial -> 1  }T

T{ 0 sqrt -> 0 }T
T{ 1 sqrt -> 1 }T
T{ 2 sqrt -> 1 }T
T{ 3 sqrt -> 1 }T
T{ 9 sqrt -> 3 }T
T{ 10 sqrt -> 3 }T
T{ 16 sqrt -> 4 }T
T{ 36 sqrt -> 6 }T
T{ -1 throws? sqrt -> -11 }T
T{  4 throws? sqrt ->  0  }T
T{ -9 throws? sqrt -> -11 }T

T{ 10 11 lcm -> 110 }T
T{ 3   2 lcm ->   6 }T
T{ 17 12 lcm -> 204 }T

T{ 3 4 / -> 0 }T
T{ 4 4 / -> 1 }T
T{ 1   0 throws? / -> -10 }T
T{ -10 0 throws? / -> -10 }T
T{ 2 2   throws? / -> 0 }T

.( hex mode ) cr
hex

: s1 $" xxx"   count ;
: s2 $" hello" count ;
: s3 $" 123"   count ;
: <#> 0 <# #s #> ; ( n -- b u )

.( Test Strings: ) cr
.( s1:  ) space s1 type cr
.( s2:  ) space s2 type cr
.( s3:  ) space s3 type cr

T{ s1 crc -> $C35A }T
T{ s2 crc -> $D26E }T

T{ s1 s1 =string -> -1 }T
T{ s1 s2 =string ->  0 }T
T{ s2 s1 =string ->  0 }T
T{ s2 s2 =string -> -1 }T

T{ s3  123 <#> =string -> -1 }T
T{ s3 -123 <#> =string ->  0 }T
T{ s3   99 <#> =string ->  0 }T

hide s1 hide s2 hide s3
hide <#>

T{ 0 ?dup -> 0 }T
T{ 3 ?dup -> 3 3 }T

T{ 1 2 3  rot -> 2 3 1 }T
T{ 1 2 3 -rot -> 3 1 2 }T

T{ 2 3 ' + execute -> 5 }T
T{ : test-1 [ $5 $3 * ] literal ; test-1 -> $f }T

.( Defined variable 'x' ) cr
variable x
T{ 9 x  ! x @ ->  9 }T
T{ 1 x +! x @ -> $a }T
hide x

T{     0 invert -> -1 }T
T{    -1 invert -> 0 }T
T{       $5555 invert -> $aaaa }T

T{     0     0 and ->     0 }T
T{     0    -1 and ->     0 }T
T{    -1     0 and ->     0 }T
T{    -1    -1 and ->    -1 }T
T{ $fa50 $05af and -> $0000 }T
T{ $fa50 $fa00 and -> $fa00 }T

T{     0     0  or ->     0 }T
T{     0    -1  or ->    -1 }T
T{    -1     0  or ->    -1 }T
T{    -1    -1  or ->    -1 }T
T{ $fa50 $05af  or -> $ffff }T
T{ $fa50 $fa00  or -> $fa50 }T

T{     0     0 xor ->     0 }T
T{     0    -1 xor ->    -1 }T
T{    -1     0 xor ->    -1 }T
T{    -1    -1 xor ->     0 }T
T{ $fa50 $05af xor -> $ffff }T
T{ $fa50 $fa00 xor -> $0050 }T

T{ $ffff     1 um+ -> 0 1  }T
T{ $40   $ffff um+ -> $3f 1  }T
T{ 4         5 um+ -> 9 0  }T

T{ $ffff     1 um* -> $ffff     0 }T
T{ $ffff     2 um* -> $fffe     1 }T
T{ $1004  $100 um* ->  $400   $10 }T
T{     3     4 um* ->    $c     0 }T


T{     1     1   < ->  0 }T
T{     1     2   < -> -1 }T
T{    -1     2   < -> -1 }T
T{    -2     0   < -> -1 }T
T{ $8000     5   < -> -1 }T
T{     5    -1   < -> 0 }T

T{     1     1  u< ->  0 }T
T{     1     2  u< -> -1 }T
T{    -1     2  u< ->  0 }T
T{    -2     0  u< ->  0 }T
T{ $8000     5  u< ->  0 }T
T{     5    -1  u< -> -1 }T

T{     1     1   = ->  -1 }T
T{    -1     1   = ->   0 }T
T{     1     0   = ->   0 }T

T{   2 dup -> 2 2 }T
T{ 1 2 nip -> 2 }T
T{ 1 2 over -> 1 2 1 }T
T{ 1 2 tuck -> 2 1 2 }T
T{ 1 negate -> -1 }T
T{ 3 4 swap -> 4 3 }T
T{ 0 0= -> -1 }T
T{ 3 0= ->  0 }T
T{ -5 0< -> -1 }T
T{ 1 2 3 2drop -> 1 }T

T{ 1 2 lshift -> 4 }T
T{ 1 $10 lshift -> 0 }T
T{ $4001 4 lshift -> $0010 }T

T{ 8     2 rshift -> 2 }T
T{ $4001 4 rshift -> $0400 }T
T{ $8000 1 rshift -> $4000 }T

T{ 99 throws? throw -> 99 }T

\ @todo u/mod tests, and more sign related tests
T{ 50 10 /mod ->  0  5 }T
T{ -4 3  /mod -> -1 -1 }T
T{ -8 3  /mod -> -2 -2 }T

.( Created word 'y' 0 , 0 , ) cr
create y 0 , 0 ,
T{ 4 5 y 2! -> }T
T{ y 2@ -> 4 5 }T
hide y

: e1 $" 2 5 + " count ;
: e2 $" 4 0 / " count ;
: e3 $" : z [ 4 dup * ] literal ; " count ;
.( e1: ) space e1 type cr
.( e2: ) space e2 type cr
.( e3: ) space e3 type cr
T{ e1 evaluate -> 7 }T
T{ e2 throws? evaluate -> $a negate }T
T{ e3 evaluate z -> $10 }T
hide e1 hide e2 hide e3 hide z

T{ here 4 , @ -> 4 }T
T{ here 0 , here swap cell+ = -> -1 }T

T{ depth depth depth -> 0 1 2 }T

T{ char 0     -> $30 }T
T{ char 1     -> $31 }T
T{ char g     -> $67 }T
T{ char ghijk -> $67 }T

T{ #vocs 8 min -> 8 }T    \ minimum number of vocabularies is 8
T{ b/buf      -> $400 }T  \ b/buf should always be 1024
defined? sp@ ?\ T{ sp@ 2 3 4 sp@ nip nip nip - abs chars -> 4 }T
T{ here 4 allot -4 allot here = -> -1 }T

defined? d< ?\ T{  0  0  0  0 d< ->  0 }T
defined? d< ?\ T{  0  0  0  1 d< -> -1 }T
defined? d< ?\ T{  0  0  1  0 d< -> -1 }T
defined? d< ?\ T{  0 -1  0  0 d< -> -1 }T
defined? d< ?\ T{  0 -1  0 -1 d< ->  0 }T
defined? d< ?\ T{  0 -1  0  1 d< -> -1 }T
defined? d< ?\ T{ $ffff -1  0  1 d< -> -1 }T
defined? d< ?\ T{ $ffff -1  0  -1 d< -> 0 }T

variable dl
variable dh
variable dhp
variable dlp
variable nn
variable nnp
variable rem
variable quo

: sm/rem ( dl dh nn -- rem quo, symmetric )
    nn ! dh ! dl !
    dl @ dh @ dabs dhp ! dlp !
    nn @ abs  nnp !
    dlp @ dhp @ nnp @ um/mod quo ! rem !
    dh @ 0<
    if  \ negative dividend
        rem @ negate rem !
        nn @ 0>
        if   \ positive divisor
            quo @ negate quo !
        then
    else  \ positive dividend
        nn @ 0<
        if  \ negative divisor
            quo @ negate quo !
        then
    then
    rem @ quo @ ;

: m* 2dup xor 0< >r abs swap abs um* r> if dnegate then ;

: */mod ( a b c -- rem a*b/c , use double precision intermediate value )
    >r m* r> sm/rem ;

$FFFF constant min-int 
$7fff constant max-int
$FFFF constant 1s

T{       0 s>d              1 sm/rem ->  0       0 }T
T{       1 s>d              1 sm/rem ->  0       1 }T
T{       2 s>d              1 sm/rem ->  0       2 }T
T{      -1 s>d              1 sm/rem ->  0      -1 }T
T{      -2 s>d              1 sm/rem ->  0      -2 }T
T{       0 s>d             -1 sm/rem ->  0       0 }T
T{       1 s>d             -1 sm/rem ->  0      -1 }T
T{       2 s>d             -1 sm/rem ->  0      -2 }T
T{      -1 s>d             -1 sm/rem ->  0       1 }T
T{      -2 s>d             -1 sm/rem ->  0       2 }T
T{       2 s>d              2 sm/rem ->  0       1 }T
T{      -1 s>d             -1 sm/rem ->  0       1 }T
T{      -2 s>d             -2 sm/rem ->  0       1 }T
T{       7 s>d              3 sm/rem ->  1       2 }T
T{       7 s>d             -3 sm/rem ->  1      -2 }T
T{      -7 s>d              3 sm/rem -> -1      -2 }T
T{      -7 s>d             -3 sm/rem -> -1       2 }T
T{ max-int s>d              1 sm/rem ->  0 max-int }T
T{ min-int s>d              1 sm/rem ->  0 min-int }T
T{ max-int s>d        max-int sm/rem ->  0       1 }T
T{ min-int s>d        min-int sm/rem ->  0       1 }T
T{      1s 1                4 sm/rem ->  3 max-int }T
T{       2 min-int m*       2 sm/rem ->  0 min-int }T
T{       2 min-int m* min-int sm/rem ->  0       2 }T
T{       2 max-int m*       2 sm/rem ->  0 max-int }T
T{       2 max-int m* max-int sm/rem ->  0       2 }T
T{ min-int min-int m* min-int sm/rem ->  0 min-int }T
T{ min-int max-int m* min-int sm/rem ->  0 max-int }T
T{ min-int max-int m* max-int sm/rem ->  0 min-int }T
T{ max-int max-int m* max-int sm/rem ->  0 max-int }T

\ ========================= FLOATING POINT CODE ===============================
\ This floating point library has been adapted from one found in
\ Forth Dimensions Vol.2, No.4 1986, it should be free to use so long as the
\ following copyright is left in the code:
\ 
\ FORTH-83 FLOATING POINT.
\	  ----------------------------------
\	  COPYRIGHT 1985 BY ROBERT F. ILLYES
\
\		PO BOX 2516, STA. A
\		CHAMPAIGN, IL 61820
\		PHONE: 217/826-2734 
\
hex

: zero  over 0= if drop 0 then ;
: fnegate $8000 xor zero ;                  ( f -- f )
: fabs  $7fff and ;                         ( f -- f )
: norm  >r 2dup or
        if begin s>d invert
           while d2* r> 1- >r
           repeat swap 0< - ?dup
           if r> else $8000 r> 1+ then
        else r> drop then ;

: f2*   1+ zero ;                          ( f -- f )
: f*    rot + $4000 - >r um* r> norm ;     ( f f -- f )
: fsq   2dup f* ;                          ( f -- f )
: f2/   1- zero ;                          ( f -- f )
: um/   dup >r um/mod swap r> over 2* 1+ u< swap 0< or - ;
: f/    rot swap - $4000 + >r
        0 -rot 2dup u<
        if   um/ r> zero
        else >r d2/ fabs r> um/ r> 1+
        then ;

: lalign $20 min for aft d2/ then next ;
: ralign 1- ?dup if lalign then 1 0 d+ d2/ ;
: fsign fabs over 0< if >r dnegate r> $8000 or then ;

: f+    rot 2dup >r >r fabs swap fabs -
        dup if s>d
                if   rot swap  negate
                     r> r> swap >r >r
                then 0 swap ralign
        then swap 0 r> r@ xor 0<
        if   r@ 0< if 2swap then d-
             r> fsign rot swap norm
        else d+ if 1+ 2/ $8000 or r> 1+
                else r> then then ;

: f@ 2@ ;              ( a -- f )
: f! 2! ;              ( f a -- )
: falign align ;       ( -- )
: fdup 2dup ;          ( f -- f f )
: fswap 2swap ;        ( f1 f2 -- f2 f1 )
: fover 2over ;        ( f1 f2 -- f1 f2 f1 )
: fdrop 2drop ;        ( f -- )
: f- fnegate f+ ;      ( f1 f2 -- t )
: f< f- 0< swap drop ; ( f1 f2 -- t )
: f> fswap f< ;        ( f1 f2 -- t )

( floating point input/output ) 
decimal

create precision 3 , 
            1. , ,         10. , ,
          100. , ,       1000. , ,
        10000. , ,     100000. , ,
      1000000. , ,   10000000. , ,
    100000000. , , 1000000000. , ,

: tens 2* cells  [ precision cell+ ] literal + 2@ ;     
hex
: set-precision dup 0 $b within if precision ! exit then -$2B throw ; ( +n -- )
: shifts fabs $4010 - s>d invert if -$2B throw then negate ;
: f#    base @ >r decimal >r precision @ tens drop um* r> shifts
        ralign precision @ ?dup if for aft # then next
        [char] . hold then #s rot sign r> base ! ;
: f.    tuck <# f# #> type space ;
: d>f $4020 fsign norm ;
: point dpl @ ;
: f     d>f point tens d>f f/ ;    ( d -- f )
: fconstant f 2constant ;          ( "name" , f --, Run Time: -- f )
: s>f   s>d d>f ;                  ( n -- f )
: -+    drop swap 0< if negate then ;
: fix   tuck 0 swap shifts ralign -+ ;
: int   tuck 0 swap shifts lalign -+ ;


1.      fconstant one decimal
34.6680 fconstant x1
-57828. fconstant x2
2001.18 fconstant x3
1.4427  fconstant x4

: exp   2dup int dup >r s>f f-
        f2* x2 2over fsq x3 f+ f/
        2over f2/ f-     x1 f+ f/
        one f+ fsq r> + ;
: fexp  x4 f* exp ;
: get   bl word dup 1+ c@ [char] - = tuck -
        0 0 rot ( convert drop ) count >number nip 0<> throw -+ ;
: e     f get >r r@ abs 13301 4004 */mod
        >r s>f 4004 s>f f/ exp r> +
        r> 0< if f/ else f* then ;

: e.    tuck fabs 16384 tuck -
        4004 13301 */mod >r
        s>f 4004 s>f f/ exp f*
        2dup one f<
        if 10 s>f f* r> 1- >r then
        <# r@ abs 0 #s r> sign 2drop
        [char] e hold f# #>     type space ;

\ ========================= FLOATING POINT CODE ===============================
decimal

3 set-precision
20 s>f f. cr
20 s>f 3 s>f f- f. cr
25 s>f f2/ f2/ f. cr
12 s>f fsq f. cr
2 s>f 3 s>f f+ f. cr
2 s>f 4 s>f f* f. cr
400.0 f 2 s>f f/ f. cr
10.3 f f. cr
6 s>f f. cr
-12.34 f e. cr
2 s>f 4 s>f exp f. cr

-1 s>f 2 s>f f< . cr
2 s>f 1 s>f f< . cr

save

\  T{ random random <> -> -1 }T

.( TESTS COMPLETE ) cr
decimal
.( passed: ) statistics u. .( / ) 0 u.r cr
.( here:   ) here . cr
statistics  = ?\ .( [ALL PASSED] ) cr     bye
statistics <> ?\ .( [FAILED]     ) cr   abort

bye
( More Test Code )

\ ## Dynamic Memory Allocation
\ alloc.fth
\  Dynamic Memory Allocation package
\  this code is an adaptation of the routines by
\  Dreas Nielson, 1990; Dynamic Memory Allocation;
\  Forth Dimensions, V. XII, No. 3, pp. 17-27
\ @todo This could use refactoring and better error checking, 'free' could
\ check that its arguments are within bounds and on the free list

\ pointer to beginning of free space
variable freelist  0 , 

\ : cell_size ( addr -- n ) >body cell+ @ ;       \ gets array cell size

: initialize ( start_addr length -- : initialize memory pool )
  over dup freelist !  0 swap !  swap cell+ ! ;

: allocate ( u -- addr ior ) \ allocate n bytes, return pointer to block
                             \ and result flag ( 0 for success )
                             \ check to see if pool has been initialized 
  freelist @ 0= abort" pool not initialized! " 
  cell+ freelist dup
  begin
  while dup @ cell+ @ 2 pick u<
    if 
      @ @ dup   \ get new link
    else   
      dup @ cell+ @ 2 pick - 2 cells max dup 2 cells =
      if 
        drop dup @ dup @ rot !
      else  
        over over swap @ cell+ !   swap @ +
      then
      over over ! cell+ 0  \ store size, bump pointer
    then                   \ and set exit flag
  repeat
  swap drop
  dup 0= ;

: free ( ptr -- ior ) \ free space at ptr, return status ( 0 for success )
  1 cells - dup @ swap over over cell+ ! freelist dup
  begin
    dup 3 pick u< and
  while
    @ dup @
  repeat

  dup @ dup 3 pick ! ?dup
  if 
    dup 3 pick 5 pick + =
    if 
      dup cell+ @ 4 pick + 3 pick cell+ ! @ 2 pick !
    else  
      drop 
    then
  then

  dup cell+ @ over + 2 pick =
  if  
    over cell+ @ over cell+ dup @ rot + swap ! swap @ swap !
  else 
    !
  then
  drop 0 ; \ this code always returns a success flag

\ create pool  1000 allot
\ pool 1000 dynamic-mem
\ 5000 1000 initialize
\ 5000 100 dump
\ 40 allocate throw
\ 80 allocate throw .s swap free throw .s 20 allocate throw .s cr
 

