%option noyywrap

%x CHAR
%x STRING
%x SLCOMMENT 
%x MLCOMMENT 

%{
#include <bits/stdc++.h>
#include "SymbolTable.h"
// #define YYSTYPE SymbolInfo*
#include "y.tab.h"
using namespace std;

// from yacc file
extern YYSTYPE yylval;
// extern SymbolTable *st;
void yyerror(char *);

// for tokens
// ofstream fout("1705044_token.txt"); 

// contants to keep track of stuff
extern int line_count;
extern int error_count;
extern ofstream fout; // to print error

// for proper str and comment i/o
int orig_line = 0;
string orig_str = "";
string input_str = "";
int multiple_ch = 0;


void err_out(string type, string lexeme, int line=0){
	int line_no = line_count;
	if (line != 0) line_no = line; // to handle orig line of str and comments

	cout<<"Error at line "<<line_no<<": "<<type<<" "<<lexeme<<endl<<endl;
	fout<<"Error at line "<<line_no<<": "<<type<<" "<<lexeme<<endl<<endl;
}


int output(int token_val, string token, string lexeme){
	// cout<<"Line no "<<line_count<<": Token <"<<token<<
	// 	  "> Lexeme "<<lexeme<<" found"<<endl<<endl;

	SymbolInfo *s= new  SymbolInfo(lexeme, token);
	yylval.sinfo = s;

	return token_val;
}


int handle_str(int token_val, string token){
	// cout<<"Line no "<<orig_line<<": Token <"<<token<<
	// 	  "> Lexeme "<<orig_str<<" found";

	SymbolInfo *s= new  SymbolInfo(orig_str, token);
	yylval.sinfo = s;

	return token_val;
}


void addStr(string input, string orig=""){
	input_str.append(input);
	orig_str.append(orig);
	// cout<<input<<" => "<<input_str<<" end"<<endl;
}

%}

AlphaNumeric_ [a-zA-Z0-9_]
Alphabet_     [a-zA-Z_]
Number 	      [0-9]


%%
					/* ///////////////////////////////////////// KEYWORDS START */
[ \t]+            	{}
\r?\n 			    {line_count++; }
if                  {return output(IF, "IF", yytext);}  		
for                 {return output(FOR, "FOR", yytext);}
do                  {return output(DO, "DO", yytext);}
int                 {return output(INT, "INT", yytext);}
float               {return output(FLOAT, "FLOAT", yytext);}
void                {return output(VOID, "VOID", yytext);}
switch              {return output(SWITCH, "SWITCH", yytext);}
default             {return output(DEFAULT, "DEFAULT", yytext);}			
else                {return output(ELSE, "ELSE", yytext);}
while               {return output(WHILE, "WHILE", yytext);}
break               {return output(BREAK, "BREAK", yytext);}
char                {return output(CHAR, "CHAR", yytext);}
double              {return output(DOUBLE, "DOUBLE", yytext);}
return              {return output(RETURN, "RETURN", yytext);}
case                {return output(CASE, "CASE", yytext);}
continue            {return output(CONTINUE, "CONTINUE", yytext);}	
printf              {return output(PRINTLN, "PRINTLN", yytext);}	
					/* ///////////////////////////////////////// KEYWORDS END */


					/* ///////////////////////////////////////// CONSTANTS START */
{Number}+ 	    	{return output(CONST_INT, "CONST_INT",yytext);} 
{Number}*(\.{Number}+)?([Ee][+-]?{Number}+)? {
						return output(CONST_FLOAT, "CONST_FLOAT",yytext);
					}
{Number}*(\.{Number}+)(\.{Number}*)+ {
						err_out("Too many decimal points",yytext);
						error_count++;  
						return output(CONST_FLOAT, "CONST_FLOAT",yytext);
					}
{Number}+(({Number}\.{Number}*)*)?([Ee][+-]?(\.?{Number}*)*)* {
						err_out("Ill formed number",yytext);
						error_count++;
						return output(CONST_FLOAT, "CONST_FLOAT",yytext);
					}					   
{Number}+((\.{Number}*)*)?([Ee][+-]?(\.?{Number}*)*)*{Alphabet_}+{AlphaNumeric_}* {
						err_out("Invalid prefix on ID or invalid suffix on Number",yytext);
						error_count++;  
						return output(ID, "ID", yytext);
					}   


\' 					{BEGIN CHAR; input_str=""; orig_str=yytext; orig_line=line_count;}
<CHAR>\'			{
						addStr("", yytext);
						BEGIN INITIAL; 
						if(input_str.length() == 0){
							err_out("Empty character constant error", orig_str); 
							error_count++;
						}
						else if(input_str.length() > 1){
							err_out("Multi character constant error",orig_str); 
							error_count++;
						}
						else{
							return handle_str(CONST_CHAR, "CONST_CHAR");
						}
					}
<CHAR>\\n 			{addStr("\n", yytext);}
<CHAR>\\t 			{addStr("\t", yytext);}
<CHAR>\\\\			{addStr("\\", yytext);}
<CHAR>\\\'  		{addStr("\'", yytext);}
<CHAR>\\\"  		{addStr("\"", yytext);}
<CHAR>\\a 			{addStr("\a", yytext);}
<CHAR>\\f  			{addStr("\f", yytext);}
<CHAR>\\r  			{addStr("\r", yytext);}
<CHAR>\\b  			{addStr("\b", yytext);}
<CHAR>\\v  			{addStr("\v", yytext);}
<CHAR>\\0  			{addStr("\n", yytext);} /* print \n for \0 or everything gets corrupted */
<CHAR>\r?\n			{
						// addStr(yytext, yytext); 
						err_out("Unterminated character",orig_str); 
						error_count++;
						line_count++; 
						BEGIN INITIAL;
					}
<CHAR>.				{addStr(yytext, yytext);}
<CHAR><<EOF>>		{
						addStr(yytext, yytext); 
						err_out("Unterminated character",orig_str); 
						error_count++; 
						BEGIN INITIAL;
					}
					/* ///////////////////////////////////////// CONSTANTS END */



					/* ///////////////////////////////////////// OP AND PUNC START */
"+"|"-"			    {return output(ADDOP, "ADDOP",yytext);}			
"*"|"/"|"%"			{return output(MULOP, "MULOP",yytext);}
"++"				{return output(INCOP, "INCOP",yytext);}
"--"				{return output(DECOP, "DECOP",yytext);}
"<"|"<="|">"|">="|"=="|"!="		{return output(RELOP, "RELOP",yytext);}
"="					{return output(ASSIGNOP, "ASSIGNOP",yytext);}
"&&"|"||"			{return output(LOGICOP, "LOGICOP",yytext);}
"!"					{return output(NOT, "NOT",yytext);}
"("					{return output(LPAREN, "LPAREN",yytext);}
")"					{return output(RPAREN, "RPAREN",yytext);}
"{"					{return output(LCURL, "LCURL",yytext);} 
"}"					{return output(RCURL, "RCURL",yytext);}
"["					{return output(LTHIRD, "LTHIRD",yytext);}
"]"					{return output(RTHIRD, "RTHIRD",yytext);}
","					{return output(COMMA, "COMMA",yytext);}
";"					{return output(SEMICOLON, "SEMICOLON",yytext);}
					/* ///////////////////////////////////////// OP AND PUNC END */

{Alphabet_}{AlphaNumeric_}*  {return output(ID, "ID", yytext);}  /* IDENTIFIERS */


					/* ///////////////////////////////////////// STRING START */
\" 					{BEGIN STRING; input_str="\""; orig_str=yytext; orig_line=line_count;}
<STRING>\"			{addStr("\"", yytext); BEGIN INITIAL; return handle_str(STRING, "STRING");}
<STRING>\\\r?\n 	{line_count++; addStr("", yytext); }  /* need \ before newline to continue */
<STRING>\r?\n|\\[ ]+  	{
						line_count++;
						err_out("Unterminated String",orig_str, orig_line); 
						BEGIN INITIAL; error_count++;
					} /* upper 2 cases handles error */
<STRING>\\n 		{addStr("\n", yytext);}
<STRING>\\t 		{addStr("\t", yytext);} 
<STRING>\\\\		{addStr("\\", yytext);}
<STRING>\\\'  		{addStr("\'", yytext);}
<STRING>\\\"  		{addStr("\"", yytext);}
<STRING>\\a 		{addStr("\a", yytext);}
<STRING>\\f  		{addStr("\f", yytext);}
<STRING>\\r  		{addStr("\r", yytext);}
<STRING>\\b  		{addStr("\b", yytext);}
<STRING>\\v  		{addStr("\v", yytext);}
<STRING>\\0  		{addStr("\n", yytext);}
<STRING>. 			{addStr(yytext, yytext);}
<STRING><<EOF>>		{err_out("Unterminated String",orig_str, orig_line); BEGIN INITIAL; error_count++;}
					/* ///////////////////////////////////////// STRING END */


					/* ///////////////////////////////////////// COMMENT START */
"//" 				{BEGIN SLCOMMENT; input_str=yytext; orig_str=yytext; orig_line=line_count;}
<SLCOMMENT>\\\r?\n 	{line_count++; addStr("\n", yytext);}
<SLCOMMENT>\r?\n	{line_count++; BEGIN INITIAL; handle_str(COMMENT, "COMMENT"); }
<SLCOMMENT>. 		{addStr(yytext, yytext);}
<SLCOMMENT><<EOF>>	{BEGIN INITIAL; handle_str(COMMENT, "COMMENT"); }


"/*"				{BEGIN MLCOMMENT; input_str=yytext; orig_str=yytext; orig_line=line_count;}
<MLCOMMENT>\r?\n 	{line_count++; addStr("\n", yytext);}
<MLCOMMENT>"*/"		{addStr("*/", yytext); BEGIN INITIAL; handle_str(COMMENT, "COMMENT"); }
<MLCOMMENT>. 		{addStr(yytext, yytext);}
<MLCOMMENT><<EOF>>	{err_out("Unterminated Comment", input_str, orig_line); error_count++; BEGIN INITIAL;}
					/* ///////////////////////////////////////// COMMENT END */


. 		    		{err_out("Unrecognized character",yytext); error_count++;}
%%


/* int main(int argc,char *argv[]){	
	if(argc!=2){
		cout<<"Please provide input file name and try again"<<endl;
		return 0;
	}
	
	FILE *fin=fopen(argv[1],"r");
	if(fin==NULL){
		cout<<"Cannot open specified file"<<endl;
		return 0;
	}

	// for logs
	freopen("1705044_log.txt", "w", stdout);
	cout<<endl;

	yyin= fin;
	yylex();
	fclose(yyin);

	st->printAll();
	cout<<"Total lines: "<<line_count<<endl;
	cout<<"Total errors: "<<error_count<<endl;

	fout.close();
	delete st;
	return 0;
} */