%option noyywrap

%x CHAR
%x STRING
%x SLCOMMENT 
%x MLCOMMENT 

%{
#include <bits/stdc++.h>
#include "SymbolTable.cpp"
using namespace std;

// symbol table
SymbolTable* st = new SymbolTable(7);

// for tokens
ofstream fout("1705044_token.txt"); 

// contants to keep track of stuff
int line_count = 1;
int error_count = 0;

// for proper str and comment i/o
int orig_line = 0;
string orig_str = "";
string input_str = "";
int multiple_ch = 0;


void err_out(string type, string lexeme, int line=0){
	int line_no = line_count;
	if (line != 0) line_no = line; // to handle orig line of str and comments

	cout<<"Error at line no "<<line_no<<": "<<type<<" "<<lexeme<<endl<<endl;
}


void output(string token, string lexeme, char mode='b', bool insert=false){
	cout<<"Line no "<<line_count<<": Token <"<<token<<
		  "> Lexeme "<<lexeme<<" found"<<endl<<endl;

	if(insert) {
		// insert to symboltable
		bool success = st->insert(lexeme, token);
		if(success) st->printAll();
	}

	switch(mode){
		case 'b': // both
			fout<<"<"<<token<<", "<<lexeme<<"> ";
			break;
		case 't': // token
			fout<<"<"<<token<<"> ";
			break;
		default:
			break;
	}
}


void handle_str(string token, bool processed=false, bool insert=false){
	cout<<"Line no "<<orig_line<<": Token <"<<token<<
		  "> Lexeme "<<orig_str<<" found";

	if (token == "CONST_CHAR") token = "CHAR_CONST";
	if(processed) {
		cout<<" --> <"<<token<<", "<<input_str<<"> ";
		// output to token file
		fout<<"<"<<token<<", "<<input_str<<"> "; 
	}
	cout<<endl<<endl;

	if(insert) {
		// insert to symboltable
		if (token == "CHAR_CONST") token = "CONST_CHAR";
		bool success = st->insert(orig_str, token);
		if(success) st->printAll();
	}
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
if                  {output("IF", yytext,'t');}  		
for                 {output("FOR", yytext,'t');}
do                  {output("DO", yytext,'t');}
int                 {output("INT", yytext,'t');}
float               {output("FLOAT", yytext,'t');}
void                {output("VOID", yytext, 't');}
switch              {output("SWITCH", yytext, 't');}
default             {output("DEFAULT", yytext, 't');}			
else                {output("ELSE", yytext, 't');}
while               {output("WHILE", yytext, 't');}
break               {output("BREAK", yytext, 't');}
char                {output("CHAR", yytext, 't');}
double              {output("DOUBLE", yytext, 't');}
return              {output("RETURN", yytext, 't');}
case                {output("CASE", yytext, 't');}
continue            {output("CONTINUE", yytext, 't');}
					/* ///////////////////////////////////////// KEYWORDS END */


					/* ///////////////////////////////////////// CONSTANTS START */
{Number}+ 	    	{output("CONST_INT",yytext, 'b', true);} 
{Number}*(\.{Number}+)?([Ee][+-]?{Number}+)? {
						output("CONST_FLOAT",yytext, 'b', true);
					}
{Number}*(\.{Number}+)(\.{Number}*)+ {
						err_out("Too many decimal points",yytext);
						error_count++;  
					}
{Number}*(({Number}\.{Number}*)*)?([Ee][+-]?(\.?{Number}*)*)* {
						err_out("Ill formed number",yytext);
						error_count++;
					}					   
{Number}+((\.{Number}*)*)?([Ee][+-]?(\.?{Number}*)*)*{Alphabet_}+{AlphaNumeric_}* {
						err_out("Invalid prefix on ID or invalid suffix on Number",yytext);
						error_count++;  
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
							handle_str("CONST_CHAR", true, true);
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
"+"|"-"			    {output("ADDOP",yytext);}			
"*"|"/"|"%"			{output("MULOP",yytext);}
"++"|"--"			{output("INCOP",yytext);}
"<"|"<="|">"|">="|"=="|"!="		{output("RELOP",yytext);}
"="					{output("ASSIGNOP",yytext);}
"&&"|"||"			{output("LOGICOP",yytext);}
"!"					{output("NOT",yytext);}
"("					{output("LPAREN",yytext);}
")"					{output("RPAREN",yytext);}
"{"					{output("LCURL",yytext); st->enterScope();} 
"}"					{output("RCURL",yytext); st->exitScope(); }
"["					{output("LTHIRD",yytext);}
"]"					{output("RTHIRD",yytext);}
","					{output("COMMA",yytext);}
";"					{output("SEMICOLON",yytext);}		/////// OP AND PUNC END
					/* ///////////////////////////////////////// OP AND PUNC END */


{Alphabet_}{AlphaNumeric_}*  {output("ID",yytext, 'b', true);}  /* IDENTIFIERS */


					/* ///////////////////////////////////////// STRING START */
\" 					{BEGIN STRING; input_str="\""; orig_str=yytext; orig_line=line_count;}
<STRING>\"			{addStr("\"", yytext); handle_str("STRING",true); BEGIN INITIAL; }
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
<SLCOMMENT>\r?\n	{line_count++; handle_str("COMMENT", false); BEGIN INITIAL;}
<SLCOMMENT>. 		{addStr(yytext, yytext);}
<SLCOMMENT><<EOF>>	{handle_str("COMMENT", false); BEGIN INITIAL;}


"/*"				{BEGIN MLCOMMENT; input_str=yytext; orig_str=yytext; orig_line=line_count;}
<MLCOMMENT>\r?\n 	{line_count++; addStr("\n", yytext);}
<MLCOMMENT>"*/"		{addStr("*/", yytext); handle_str("COMMENT", false); BEGIN INITIAL;}
<MLCOMMENT>. 		{addStr(yytext, yytext);}
<MLCOMMENT><<EOF>>	{err_out("Unterminated Comment", input_str, orig_line); error_count++; BEGIN INITIAL; }
					/* ///////////////////////////////////////// COMMENT END */


. 		    		{err_out("Unrecognized character",yytext); error_count++; }
%%


int main(int argc,char *argv[]){	
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
}