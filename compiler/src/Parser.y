{
module Main where
import Lexer
import Absyn
}

%name      parser
%error     { parseError }
%lexer     { lexwrap }{ Eof }
%monad     { Alex }
%tokentype { Token }

%token
'('         { TOParen     $$ }
')'         { TCParen     $$ }
','         { TComma      $$ }
';'         { TSemi       $$ }
'['         { TOBrack     $$ }
']'         { TCBrack     $$ }
'`'         { TBackquote  $$ }
'{'         { TOCurly     $$ }
'}'         { TCCurly     $$ }
vocurly     { TVOCurly    $$ }
vccurly     { TVCCurly    $$ }
'case'      { TCase       $$ }
'class'     { TClass      $$ }
'data'      { TData       $$ }
'default'   { TDefault    $$ }
'deriving'  { TDeriving   $$ }
'do'        { TDo         $$ }
'else'      { TElse       $$ }
'foreign'   { TForeign    $$ }
'if'        { TIf         $$ }
'import'    { TImport     $$ }
'in'        { TIn         $$ }
'infix'     { TInfix      $$ }
'infixl'    { TInfixl     $$ }
'infixr'    { TInfixr     $$ }
'instance'  { TInstance   $$ }
'let'       { TLet        $$ }
'module'    { TModule     $$ }
'newtype'   { TNewtype    $$ }
'of'        { TOf         $$ }
'then'      { TThen       $$ }
'type'      { TType       $$ }
'where'     { TWhere      $$ }
'_'         { TUnderscore $$ }
'as'        { TAs         $$ }
'hiding'    { THiding     $$ }
'qualified' { TQualified  $$ }
'safe'      { TSafe       $$ }
'unsafe'    { TUnsafe     $$ }
'..'        { TDotdot     $$ }
':'         { TColon      $$ }
'::'        { TDColon     $$ }
'='         { TEqual      $$ }
'\\'        { TLam        $$ }
'|'         { TVBar       $$ }
'<-'        { TLArrow     $$ }
'->'        { TRArrow     $$ }
'@'         { TAt         $$ }
'~'         { TTilde      $$ }
'=>'        { TDArrow     $$ }
'-'         { TMinus      $$ }
'!'         { TBang       $$ }
tvarid      { TVarid      $$ }
tconid      { TConid      $$ }
tvarsym     { TVarsym     $$ }
tconsym     { TConsym     $$ }
tqvarid     { TQVarid     $$ }
tqconid     { TQConid     $$ }
tqvarsym    { TQVarsym    $$ }
tqconsym    { TQConsym    $$ }
tlitint     { TInteger    $$ }
tlitfloat   { TFloat      $$ }
tlitstr     { TString     $$ }
tlitchar    { TChar       $$ }

%%
module: 'module' modid exports_opt 'where' body { mkModule $2 }
  |     body                                    {}

body: '{'     impdecls ';' topdecls '}'         {}
  |   vocurly impdecls ';' topdecls vccurly_opt {}
  |   '{'     impdecls '}'                      {}
  |   vocurly impdecls vccurly_opt              {}
  |   '{'     topdecls '}'                      {}
  |   vocurly topdecls vccurly_opt              {}

impdecls: impdecls ';' impdecl                  {}
  |       impdecl                               {}

exports_opt: exports                            {}
  |          {- empty -}                        {}

exports: '(' cseq_export ',' ')'                {}
  |      '(' cseq_export     ')'                {}

cseq_export: cseq1_export                       {}
  |          {- empry -}                        {}

cseq1_export: cseq1_export ',' export           {}
  |           export                            {}

export: qvar                                    {}
  |     qtycon                                  {}
  |     qtycon '(' '..' ')'                     {}
  |     qtycon '(' cseq_cname ')'               {}
  |     qtycls                                  {}
  |     qtycls '(' '..' ')'                     {}
  |     qtycls '(' cseq_var ')'                 {}
  |     'module' modid                          {}

impdecl: 'import' qual_opt modid as_modid_opt
         impspec_opt                            {}

qual_opt: 'qualified'                           {}
  |       {- empty -}                           {}

as_modid_opt: 'as' modid                        {}
  |           {- empty -}                       {}

impspec_opt: impspec                            {}
  |          {- empty -}                        {}

impspec: '(' cseq_import ',' ')'                {}
  |      '(' cseq_import     ')'                {}
  |      'hiding' '(' cseq_import ',' ')'       {}
  |      'hiding' '(' cseq_import     ')'       {}

cseq_import: cseq1_import                       {}
  |          {- empty -}                        {}

cseq1_import: cseq1_import ',' import           {}
  |           import                            {}

import: var                                     {}
  |     tycon                                   {}
  |     tycon '(' '..' ')'                      {}
  |     tycon '(' cseq_cname ')'                {}
  |     tycls                                   {}
  |     tycls '(' '..' ')'                      {}
  |     tycls '(' cseq_var ')'                  {}

cseq_var: cseq1_var                             {}
  |       {- empty -}                           {}

cseq1_var: cseq1_var ',' var                    {}
  |        var                                  {}

cseq_cname: cseq1_cname                         {}
  |         {- empty -}                         {}

cseq1_cname: cseq1_cname ',' cname              {}
  |          cname                              {}

cname: var                                      {}
  |    con                                      {}

topdecls: sseq1_topdecl                         {}

sseq1_topdecl: sseq1_topdecl ';' topdecl        {}
  |            topdecl                          {}

topdecl: 'type' simpletype '=' type             {}
  |      'data' ctx_opt simpletype
         '=' constrs deriving_opt               {}
  |      'data' ctx_opt simpletype
                     deriving_opt               {}
  |      'newtype' ctx_opt simpletype
         '=' newconstr deriving_opt             {}
  |      'class' sctx_opt tycls tyvar           {}
  |      'class' sctx_opt tycls tyvar
         'where' cdecls                         {}
  |      'instance' sctx_opt qtycls inst        {}
  |      'instance' sctx_opt qtycls inst
         'where' idecls                         {}
  |      'default' '(' cseq_type ')'            {}
  |      'foreign' fdecl                        {}
  |      decl                                   {}

ctx_opt: context '=>'                           {}
  |      {- empty -}                            {}

sctx_opt: scontext '=>'                         {}
  |       {- empty -}                           {}

deriving_opt: deriving                          {}
  |           {- empty -}                       {}

decls: '{'     sseq1_decl '}'                   {}
  |    '{'                '}'                   {}
  |    vocurly sseq1_decl vccurly_opt           {}
  |    vocurly            vccurly_opt           {}

sseq1_decl: sseq1_decl ';' decl                 {}
  |         decl                                {}

decl: gendecl                                   {}
  |   funlhs rhs                                {}
  |   pat    rhs                                {}

cdecls: '{'     sseq1_cdecl '}'                 {}
  |     '{'                 '}'                 {}
  |     vocurly sseq1_cdecl vccurly_opt         {}
  |     vocurly             vccurly_opt         {}

sseq1_cdecl: sseq1_cdecl ';' cdecl              {}
  |          cdecl                              {}

cdecl: gendecl                                  {}
  |    funlhs rhs                               {}
  |    var    rhs                               {}

idecls: '{'     sseq1_idecl '}'                 {}
  |     '{'                 '}'                 {}
  |     vocurly sseq1_idecl vccurly_opt         {}
  |     vocurly             vccurly_opt         {}

sseq1_idecl: sseq1_idecl ';' idecl              {}
  |          idecl                              {}

idecl: funlhs rhs                               {}
  |    var    rhs                               {}
  |    {- empty -}                              {}

gendecl: vars '::' context '=>' type            {}
  |      vars '::'              type            {}
  |      fixity integer ops                     {}
  |      fixity         ops                     {}
  |      {- empty -}                            {}

ops: ops ',' op                                 {}
  |  op                                         {}

vars: vars ',' var                              {}
  |   var                                       {}

fixity: 'infixl'                                {}
  |     'infixr'                                {}
  |     'infix'                                 {}

type: btype '->' atype                          {}
  |              atype                          {}

cseq_type: cseq1_type                           {}
  |        {- empty -}                          {}

cseq1_type: cseq1_type ',' type                 {}
  |         type                                {}

btype: btype atype                              {}
  |          atype                              {}

atype: gtycon                                   {}
  |    tyvar                                    {}
  |    '(' cseq1_type ',' type ')'              {}
  |    '[' type ']'                             {}
  |    '(' type ')'                             {}

seq_atype: seq_atype atype                      {}
  |        {- empty -}                          {}

gtycon: qtycon                                  {}
  |     '(' ')'                                 {}
  |     '[' ']'                                 {}
  |     '(' '->' ')'                            {}
  |     '(' seq1_commas ')'                     {}

seq1_commas: seq1_commas ','                    {}
  |          ','                                {}

context: class                                  {}
  |      '(' cseq_class ')'                     {}

cseq_class: cseq1_class                         {}
  |         {- empty -}                         {}

cseq1_class: cseq1_class ',' class              {}
  |          class                              {}

class: qtycls tyvar                             {}
  |    qtycls '(' tyvar seq_atype ')'           {}

scontext: simpleclass                           {}
  |       '(' cseq_simpleclass ')'              {}

cseq_simpleclass: cseq1_simpleclass             {}
   |              {- empty -}                   {}

cseq1_simpleclass: cseq1_simpleclass ',' simpleclass
                                                {}
   |               simpleclass                  {}

simpleclass: qtycls tyvar                       {}

simpletype: tycon seq_tyvar                     {}

constrs: constrs '|' constr                     {}
  |      constr                                 {}

constr: con seq_banopt_atype                    {}
  |     borbatype conop borbatype               {}
  |     con '{' cseq_fielddecl '}'              {}

cseq_fielddecl: cseq1_fielddecl                 {}
  |             {- empty -}                     {}

cseq1_fielddecl: cseq1_fielddecl ',' fielddecl  {}
  |              fielddecl                      {}

borbatype: btype                                {}
  |        '!' atype                            {}

seq_banopt_atype: seq_banopt_atype banopt_atype {}
  |               banopt_atype                  {}

banopt_atype: '!' atype                         {}
  |               atype                         {}

newconstr: con atype                            {}
  |        con '{' var '::' type '}'            {}

fielddecl: vars '::' type                       {}
  |        vars '::' '!' atype                  {}

deriving: 'deriving' dclass                     {}
  |       'deriving' '(' cseq_dclass ')'        {}

cseq_dclass: cseq1_dclass                       {}
  |          {- empty -}                        {}

cseq1_dclass: cseq1_dclass ',' dclass           {}
  |           dclass                            {}

dclass: qtycls                                  {}

inst: gtycon                                    {}
  |   '(' seq_tyvar ')'                         {}
  |   '(' cseq1_tyvar ',' tyvar ')'             {}
  |   '[' tyvar ']'                             {}
  |   '(' tyvar '->' tyvar ')'                  {}

seq_tyvar: seq_tyvar tyvar                      {}
  |       {- empty -}                           {}

cseq1_tyvar: cseq1_tyvar ',' tyvar              {}
  |          tyvar                              {}

fdecl: 'import' callconv safety impent var '::'
       ftype                                    {}

callconv: {- tbd -}                             {}

impent: string                                  {}
  |     {- empty -}                             {}

safety: 'unsafe'                                {}
  |     'safe'                                  {}
  |     {- empty -}                             {}

ftype: frtype                                   {}
  |    fatype '->' ftype                        {}

frtype: fatype                                  {}
  |     '(' ')'                                 {}
fatype: qtycon seq_atype                        {}

funlhs: var apat seq_apat                       {}
  |     pat varop pat                           {}
  |     '(' funlhs ')' apat seq_apat            {}

rhs: '=' exp 'where' decls                      {}
  |  '=' exp                                    {}
  |  gdrhs   'where' decls                      {}
  |  gdrhs                                      {}

gdrhs: guards '=' exp gdrhs                     {}
  |    guards '=' exp                           {}

guards: '|' guards guard                        {}
  |     '|' guard                               {}

guard: pat '<-' infixexp                        {}
  |    'let' decls                              {}
  |    infixexp                                 {}

exp: infixexp '::' context '=>' type            {}
  |  infixexp              '=>' type            {}
  |  infixexp                                   {}

infixexp: lexp qop infixexp                     {}
  |       '-' infixexp                          {}
  |       lexp                                  {}

lexp: '\\' seq1_apat '->' exp                   {}
  |   'let' decls 'in' exp                      {}
  |   'if'   exp semi_opt
      'then' exp semi_opt
      'else' exp                                {}
  |   'case' exp 'of' '{' alts '}'              {}
  |   'case' exp 'of' vocurly alts vccurly_opt  {}
  |   'do' '{' stmt '}'                         {}
  |   'do' vocurly stmt vccurly_opt             {}
  |   fexp                                      {}

vccurly_opt: vccurly                            {}
  |          {- empty -}                        { {- pop ctx -} }

semi_opt: ';'                                   {}
  |    {- empty -}                              {}


seq1_apat: seq1_apat apat                       {}
  |        apat                                 {}

fexp: fexp aexp                                 {}
  |   aexp                                      {}

aexp: qvar                                      {}
  |   gcon                                      {}
  |   literal                                   {}
  |   '(' exp ')'                               {}
  |   '(' seq1_exp ',' exp ')'                  {}
  |   '[' seq1_exp ']'                          {}
  |   '[' exp         '..'     ']'              {}
  |   '[' exp         '..' exp ']'              {}
  |   '[' exp ',' exp '..'     ']'              {}
  |   '[' exp ',' exp '..' exp ']'              {}
  |   '[' exp '|' seq1_qual ']'                 {}
  |   '(' infixexp qop ')'                      {}
  |   '(' qop_ infixexp ')'                     {}
  |   qcon '{' seq_fbind '}'                    {}
  |   aexp '{' seq1_fbind '}'                   {}

seq1_exp: seq1_exp ',' exp                      {}
  |       exp                                   {}

seq1_qual: seq1_qual ',' qual                   {}
  |        qual                                 {}

seq_fbind : seq1_fbind                          {}
  |         {- empty -}                         {}

seq1_fbind: seq1_fbind ',' fbind                {}
  |         fbind                               {}

qual: pat '<-' exp                              {}
  |   'let' decls                               {}
  |   exp                                       {}

alts: alts ';' alt                              {}
  |   alt                                       {}

alt: pat '->' exp                               {}
  |  pat '->' exp 'where' decls                 {}
  |  pat gdpat                                  {}
  |  pat gdpat 'where' decls                    {}

gdpat: guards '->' exp                          {}
  |    guards '->' exp gdpat                    {}

stmts: seq_stmt exp semi_opt                    {}

seq_stmt: seq_stmt stmt                         {}
  |       {- empty -}                           {}

stmt: exp ';'                                   {}
  |   pat '<-' exp ';'                          {}
  |   'let' decls ';'                           {}
  |   ';'                                       {}

fbind: qvar '=' exp                             {}

pat: lpat qconop pat                            {}
  |  lpat                                       {}

lpat: apat                                      {}
  |   '-' integer                               {}
  |   '-' float                                 {}
  |   gcon seq_apat                             {}

seq_apat: seq_apat apat                         {}
  |       {- empty -}                           {}

apat: var                                       {}
  |   var '@' apat                              {}
  |   gcon                                      {}
  |   qcon '{' seq_fpat '}'                     {}
  |   literal                                   {}
  |   '_'                                       {}
  |   '(' pat ')'                               {}
  |   '(' seq1_pat ',' pat ')'                  {}
  |   '[' seq1_pat ']'                          {}
  |   '~' apat                                  {}

seq1_pat: seq1_pat pat                          {}
  |       pat                                   {}

seq_fpat: seq_fpat fpat                         {}
  |       {- empty -}                           {}

fpat: qvar '=' pat                              {}

gcon: '(' ')'                                   {}
  |   '[' ']'                                   {}
  |   '(' ',' seq_commas ')'                    {}
  |   qcon                                      {}

seq_commas: seq_commas ','                      {}
  |         {- empty -}                         {}

var: varid                                      {}
  |  '(' varsym ')'                             {}

qvar: qvarid                                    {}
  |  '(' qvarsym ')'                            {}
  |   var                                       {}

con: conid                                      {}
  |  '(' consym ')'                             {}

qcon : qconid                                   {}
  |    '(' gconsym ')'                          {}
  |    con                                      {}

varop : varsym                                  {}
  |     '`' varid '`'                           {}

qvarop: qvarsym                                 {}
  |     '`' qvarid '`'                          {}
  |     varop                                   {}

conop: consym                                   {}
  |    '`' conid '`'                            {}

qconop: gconsym                                 {}
  |     '`' qconid '`'                          {}
  |     conop                                   {}

op: varop                                       {}
  | conop                                       {}

qop: qvarop                                     {}
  |  qconop                                     {}

-- qop<->
qop_: varsym_                                   {}
  |   '`' varid '`'                             {}
  |   qvarsym                                   {}
  |   '`' qvarid '`'                            {}
  |   qconop                                    {}

gconsym: ':'                                    {}
  | qconsym                                     {}


modid:  qconid                  { $1 }
  |     conid                   { $1 }

varid: tvarid                                   { mkName $1 }
  |    'as'                                     { mkName ("as", $1) }
  |    'hiding'                                 { mkName ("hiding", $1) }
  |    'qualified'                              { mkName ("qualified", $1) }
  |    'safe'                                   { mkName ("safe", $1) }
  |    'unsafe'                                 { mkName ("unsafe", $1) }

conid: tconid                                   { mkName $1 }

varsym: tvarsym                                 { mkName $1 }
  |     '-'                                     { mkName ("-", $1) }
  |     '!'                                     { mkName ("!", $1) }

varsym_: tvarsym                                {}
  |      '!'                                    {}

consym: tconsym                                 {}

qvarid: tqvarid                                 { mkName $1 }
qconid: tqconid                                 { mkName $1 }
qvarsym: tqvarsym                               {}
qconsym: tqconsym                               {}
qtycon: qconid                                  {}

tyvar: varid                                    {}
tycon: conid                                    {}
tycls: conid                                    {}
qtycls: qconid                                  {}
  |     conid                                   {}

integer: tlitint                                {}
float:   tlitfloat                              {}
char:    tlitchar                               {}
string:  tlitstr                                {}

literal: integer                                {}
  |      float                                  {}
  |      char                                   {}
  |      string                                 {}
{
extrPos :: AlexPosn -> Pos
extrPos (AlexPn _ line col) = (line, col)

extrQual qual name =
  case span (/= '.') name of
    (_, "")      -> (qual, name)
    (q, ('.':n)) -> extrQual (qual ++ q ++ ".") n
    (q, n)       -> extrQual (qual ++ q ++ ".") n

mkName (s, pos) = Name { name_body = body
                       , name_qual = qual
                       , name_pos  = extrPos pos }
  where
    (qual, body) = extrQual "" s

mkModule modid = Module modid []

lexwrap :: (Token -> Alex a) -> Alex a
lexwrap = (alexMonadScan >>=)

parseError :: Token -> Alex a
parseError t = alexError $ "parseError: " ++ show t

parse s = runAlex s parser

main :: IO ()
main = getContents >>= print . parse
}
