/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
  if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
    YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;


/*
 *  Add Your own definitions here
 */
  int comment_level=0;
%}

/*
 * Define names for regular expressions here.
 */
TWODASH         --
DARROW          =>
DIGIT           [0-9]
ALPHABET        [a-zA-Z]
LOWERALPHABET   [a-z]
CAPIALPHABET    [A-Z] 
ID              [a-zA-Z0-9_]*
OPENCOMMENT     ("(*")
CLOSECOMMENT    ("*)")

%x INCOMMENT INSTRING BROKENSTRING
%% 



 /* 
  *  Nested comments  (* *) form get nested
  */
<INITIAL,INCOMMENT>{OPENCOMMENT} {
  comment_level++;
 BEGIN(INCOMMENT);
}

<INCOMMENT>{CLOSECOMMENT} {
comment_level--;
if(comment_level==0){  
  //end of the comment
  BEGIN(INITIAL);

}
if(comment_level<0){
  //it is an error
  BEGIN(INITIAL);
  comment_level=0;
  yylval.error_msg="Unmatched *)";
  return ERROR;
}
}

<INITIAL>{CLOSECOMMENT} {
 //it is an error
  BEGIN(INITIAL);
  comment_level=0;
  yylval.error_msg="Unmatched *)";
  return ERROR;
}
<INCOMMENT><<EOF>> {
//it is an error,Comments cannot cross file boundaries.
   BEGIN(INITIAL);
   comment_level=0;
   yylval.error_msg="EOF in comment";
  return ERROR;
}
<INCOMMENT>. {  
// pass anything in comment
}

{TWODASH}([^\n]*)\n {   curr_lineno++;
// pass anything in comment
 }

{TWODASH}.* {   curr_lineno++;
// pass anything in comment
 }

 /*
  *  The multiple-character operators.
  */
{DARROW} { return (DARROW); }
"<="  { return LE;} 
"<-" {return ASSIGN;}
 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */
(?i:if) {  return IF;}

(?i:then) {return THEN;}

(?i:else) {return ELSE;}

(?i:fi) {return FI;}

(?i:while) {return WHILE;}

(?i:loop) {return LOOP;}

(?i:pool) {return POOL;}

(?i:class) {return CLASS;}

(?i:inherits) {return INHERITS;}

(?i:let)   {return LET;}

(?i:in) {return IN;}

(?i:case) {return CASE;}

(?i:of) {return OF;}

(?i:esac) {return ESAC;}

(?i:new) {return NEW;}

(?i:isvoid) {return ISVOID;}

(?i:not) {return NOT;}

t(?i:rue) { cool_yylval.boolean=true;  return BOOL_CONST;}

f(?i:alse) { cool_yylval.boolean=false; return BOOL_CONST;}
  
{LOWERALPHABET}{ID}*|"self" {   
   cool_yylval.symbol=idtable.add_string(yytext,yyleng); 
    return OBJECTID;
  }
 
{CAPIALPHABET}{ID}*|"SELF_TYPE" { 
  cool_yylval.symbol=idtable.add_string(yytext,yyleng);
   return TYPEID;
}

{DIGIT}+ { 
    cool_yylval.symbol = inttable.add_string(yytext);
  return INT_CONST; }


 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */
  
  <INSTRING>\" { 
  *string_buf_ptr=0; 
  BEGIN(INITIAL);
  string_buf_ptr=&(string_buf[0]);
  int length=strlen(string_buf_ptr);
  if(length>=MAX_STR_CONST){
    cool_yylval.error_msg="string constants too long"; 
    return ERROR;
  }
  else{
  cool_yylval.symbol=stringtable.add_string(strdup(string_buf)); 
  string_buf_ptr=&(string_buf[0]);
  return STR_CONST;
  }
}

<INITIAL>\" {  
  BEGIN(INSTRING);
  string_buf_ptr=&(string_buf[0]);
}

<INSTRING>(\0|\\\0) {
  
  cool_yylval.error_msg = "String contains null character";
  BEGIN(BROKENSTRING);
  return (ERROR);
}

<BROKENSTRING>.*[\"\n] {
                    //"//Get to the end of broken string  
                    //reference:https://github.com/jordn/Compiler/blob/master/PA2%20Lexer/cool.flex#L82 line 195
                    BEGIN(INITIAL); 
                }

<INSTRING>(\\.|\\\n) {
  char unescaped = 0;
  switch (yytext[1]) {
  case 'n': unescaped = '\n'; break;
  case 'b': unescaped = '\b'; break;
  case 'f': unescaped = '\f'; break;
  case 't': unescaped = '\t'; break;
  case '\n': curr_lineno++;
  default: unescaped = yytext[1]; break;
  }
  *string_buf_ptr=unescaped;
  string_buf_ptr++;
}

<INSTRING><<EOF>> {
  BEGIN(INITIAL);
  cool_yylval.error_msg = "EOF in string constant";
  return (ERROR);
 }

<INSTRING>. {
  *string_buf_ptr=yytext[0];
  string_buf_ptr++;
 }

 <INSTRING>\n {
  /* If a string contains an unescaped newline, report that error as Unterminated string constant
     and resume lexing at the beginning of the next line  assume the programmer simply forgot the
     close-quote.
  */
  curr_lineno++; //always always increment the line count
  cool_yylval.error_msg = "Unterminated string constant";
  BEGIN(INITIAL);
  return (ERROR);
 }
<INITIAL,INCOMMENT>\n { curr_lineno++; }
 /*
  *  The single-character operators.
  */
  
"/"             { return '/'; }
"+"             { return '+'; }
"-"             { return '-'; }
"*"             { return '*'; }
"("             { return '('; }
")"             { return ')'; }
"="             { return '='; }
"<"             { return '<'; }
"."             { return '.'; }
"~"             { return '~'; }
","             { return ','; }
";"             { return ';'; }
":"             { return ':'; }
"@"             { return '@'; }
"{"             { return '{'; }
"}"             { return '}'; }


 [ \t\v\n\f\r] { }
 .      {   cool_yylval.error_msg=yytext;  return ERROR; /* other bad characters */ }

%%