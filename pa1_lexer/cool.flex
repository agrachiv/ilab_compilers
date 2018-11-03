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

int inside_comments = 0;
int len_of_buffer = 0;
bool buffer_ok(int symbol_len);

%}

%option yylineno
%option noyywrap

%Start COMMENTS1 COMMENTS2 STRING STRING_ERROR LONG_ERROR

/*
 * Define names for regular expressions here.
 */

DARROW =>
ASSIGN <-
LE <=
DIGIT [0-9]
TRUE [t][rR][uU][eE]
FALSE [f][aA][lL][sS][eE]
TYPEID [A-Z][a-zA-Z0-9_]*
OBJECTID [a-z][a-zA-Z0-9_]*
%%

 /*
  *  Nested comments
  */
<INITIAL>--                     { BEGIN COMMENTS1; }
<COMMENTS1>[^\n]*               { }
<COMMENTS1>\n                   { curr_lineno++; BEGIN 0; }
<INITIAL>\(\*                   { inside_comments++; BEGIN COMMENTS2; }
<COMMENTS2>\(\*                 { inside_comments++; }
<COMMENTS2>\*\)                 { inside_comments--; if(inside_comments == 0) {  BEGIN 0; } }
<COMMENTS2>[^(*\n]*             { }
<COMMENTS2>[*]/[^()\n]*         { }
<COMMENTS2>\([^*\n]*            { }
<COMMENTS2>\n                   { curr_lineno++; }
<COMMENTS2><<EOF>>              { BEGIN 0;
                                cool_yylval.error_msg = "unexpected EOF";
                                return ERROR;
                                }
<INITIAL>\*\)                   { cool_yylval.error_msg = "unmatched *)";
                                return ERROR;
                                }

 /*
  *  The multiple-character operators.
  */

<INITIAL>{LE}           { return (LE); }
<INITIAL>{DARROW}      	{ return (DARROW); }
<INITIAL>{ASSIGN}       { return (ASSIGN); }

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */

<INITIAL>{TRUE}         { cool_yylval.boolean = true; return (BOOL_CONST); }
<INITIAL>{FALSE}        { cool_yylval.boolean = false; return (BOOL_CONST); }
<INITIAL>(?i:class)     { cool_yylval.symbol = idtable.add_string(yytext); return (CLASS); }
<INITIAL>(?i:else)      { cool_yylval.symbol = idtable.add_string(yytext); return (ELSE); }
<INITIAL>(?i:fi)        { cool_yylval.symbol = idtable.add_string(yytext); return (FI); }
<INITIAL>(?i:if)        { cool_yylval.symbol = idtable.add_string(yytext); return (IF); }
<INITIAL>(?i:in)        { cool_yylval.symbol = idtable.add_string(yytext); return (IN); }
<INITIAL>(?i:inherits)  { cool_yylval.symbol = idtable.add_string(yytext); return (INHERITS); }
<INITIAL>(?i:let)       { cool_yylval.symbol = idtable.add_string(yytext); return (LET); }
<INITIAL>(?i:loop)      { cool_yylval.symbol = idtable.add_string(yytext); return (LOOP); }
<INITIAL>(?i:pool)      { cool_yylval.symbol = idtable.add_string(yytext); return (POOL); }
<INITIAL>(?i:then)      { cool_yylval.symbol = idtable.add_string(yytext); return (THEN); }
<INITIAL>(?i:while)     { cool_yylval.symbol = idtable.add_string(yytext); return (WHILE); }
<INITIAL>(?i:case)      { cool_yylval.symbol = idtable.add_string(yytext); return (CASE); }
<INITIAL>(?i:esac)      { cool_yylval.symbol = idtable.add_string(yytext); return (ESAC); }
<INITIAL>(?i:of)        { cool_yylval.symbol = idtable.add_string(yytext); return (OF); }
<INITIAL>(?i:new)       { cool_yylval.symbol = idtable.add_string(yytext); return (NEW); }
<INITIAL>(?i:isvoid)    { cool_yylval.symbol = idtable.add_string(yytext); return (ISVOID); }
<INITIAL>(?i:not)       { cool_yylval.symbol = idtable.add_string(yytext); return (NOT); }
<INITIAL>{TYPEID}       { cool_yylval.symbol = idtable.add_string(yytext); return (TYPEID); }
<INITIAL>{OBJECTID}     { cool_yylval.symbol = idtable.add_string(yytext); return (OBJECTID); }
<INITIAL>{DIGIT}+       { cool_yylval.symbol = inttable.add_string(yytext); return (INT_CONST); }
<INITIAL>[\t\f\r\v ]+   { }
<INITIAL>\"             {
    len_of_buffer = 0;
    string_buf_ptr = string_buf;
    BEGIN STRING;
}
<INITIAL>[;:(){},.@<=\-+*/~]     { return ((char)yytext[0]); }
<INITIAL>\n                      { curr_lineno++; }
<INITIAL>.                       { yylval.error_msg = yytext; return (ERROR); }

 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for
  *  \n \t \b \f, the result is c.
  *
  */
<STRING>\n {
    yylval.error_msg ="\n i string";
    BEGIN(INITIAL);
    return (ERROR);
}

<STRING>\0 {
    yylval.error_msg ="\0 in string";
    BEGIN(STRING_ERROR);
    return (ERROR);
}

<STRING>\\n         { if(buffer_ok(1) == false) BEGIN(LONG_ERROR); *string_buf_ptr++ = '\n'; }
<STRING>\\b         { if(buffer_ok(1) == false) BEGIN(LONG_ERROR); *string_buf_ptr++ = '\b'; }
<STRING>\\t         { if(buffer_ok(1) == false) BEGIN(LONG_ERROR); *string_buf_ptr++ = '\t'; }
<STRING>\\f         { if(buffer_ok(1) == false) BEGIN(LONG_ERROR); *string_buf_ptr++ = '\f'; }
<STRING>\\\"        { if(buffer_ok(1) == false) BEGIN(LONG_ERROR); *string_buf_ptr++ = '\"'; }
<STRING>\\\\        { if(buffer_ok(1) == false) BEGIN(LONG_ERROR); *string_buf_ptr++ = '\\'; }
<STRING>\\[^\"ntfb\\\0] {
    char tmp_string[1];
    tmp_string[0] = yytext[1];
    if(buffer_ok(1)  == false)
        BEGIN(LONG_ERROR);
    strncpy(string_buf_ptr++, tmp_string, 1);
}

<STRING><<EOF>> {
    yylval.error_msg = "EOF in string constant";
    BEGIN(INITIAL);
    return ERROR;
}

<STRING>[^"\"] {
    int len = strlen(yytext);
    if(buffer_ok(len)  == false)
        BEGIN(LONG_ERROR);
    strncpy(string_buf_ptr, yytext, len);
    string_buf_ptr+=len;
}

<STRING>\" {
    *string_buf_ptr = '\0';
    cool_yylval.symbol = inttable.add_string(string_buf);
    BEGIN(INITIAL);
    return (STR_CONST);
}

 /*
  * errors
  *
  */

<STRING_ERROR>\" {BEGIN(INITIAL);}
<STRING_ERROR>[^\n] {}
<STRING_ERROR>\n {BEGIN(INITIAL); }
<LONG_ERROR>. {
    BEGIN(INITIAL);
    yylval.error_msg = "String constant too long";
    return (ERROR);
}
%%

bool buffer_ok(int symbol_len) {
    len_of_buffer += symbol_len;
    if(len_of_buffer >= MAX_STR_CONST)
    {
        return false;
    }
    return true;
}

