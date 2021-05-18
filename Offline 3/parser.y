%{
#include <bits/stdc++.h>
#include "SymbolTable.h"
// #define YYSTYPE SymbolInfo*

using namespace std;

int yyparse(void);
int yylex(void);
extern FILE *yyin;
ofstream fout("1705044_error.txt");

SymbolTable *st = new SymbolTable(30);
int line_count = 1;
int error_count = 0;

// extra info for functions
vector<SymbolInfo*>* cur_param_list; // define new in adding func, delete after adding to func sinfo
bool in_function = false;

string dummy_val = "-100"; // store dummy vals when params declared without id or when an error has occured
// if an error has occured, store return type as dummy_val
// this signals no need to show further errors
string var_type = "-100"; // to store type of variables in declaration_list to match sample io

void yyerror(char *s){
	//write your code
	// cout<<"Error : "<<s<<endl;
	fout<<"Error at line "<<line_count<<": "<<s<<endl<<endl;
	cout<<"Error at line "<<line_count<<": "<<s<<endl<<endl;
	error_count += 1;
}


void print_vals(vector<SymbolInfo*>* vals){
	string value, type;
	SymbolInfo* temp;
	for (auto i = vals->begin(); i != vals->end(); ++i){
		temp = *i;
		value = temp->getName();
		type = temp->getType();

		if(type == "INT" || type == "FLOAT" || type == "VOID" || type == "RETURN" || type == "IF" || 
		   type == "ELSE" || type == "WHILE") value = value + " ";
		else if(type == "SEMICOLON" || type == "LCURL") value = value + "\n";
		else if(type == "RCURL") value = value + "\n\n";

		cout<<value;
	}
	cout<<endl<<endl;
}


void rule_match(string rule, vector<SymbolInfo*>* vals){
	cout<<"Line "<<line_count<<": "<<rule<<endl<<endl;
	print_vals(vals);
}


vector<SymbolInfo*>* add_vals(vector<SymbolInfo*>* vec1, vector<SymbolInfo*>* vec2){
	vec1->insert(vec1->end(), vec2->begin(), vec2->end());
	delete vec2;
	return vec1;
}


void print_error(string message){
	fout<<"Error at line "<<line_count<<": "<<message<<endl<<endl;
	cout<<"Error at line "<<line_count<<": "<<message<<endl<<endl;
	error_count += 1;
}


//////////////////////////// HELPER FUNCTIONS /////////////////////////////////

// helper to insert variables to param_list.
// error handling:
// 1. type cannot by void
// 2. multiple declaration of var
void insert_param(SymbolInfo* id, SymbolInfo* type){
	if(type->getType() == "VOID"){
		print_error("Variable type cannot be void");
		return; 
	}

	if(cur_param_list == nullptr) cur_param_list = new vector<SymbolInfo*>();
	for(int i=0; i<cur_param_list->size(); i++){
		if(cur_param_list->at(i)->getName() == id->getName() && id->getName() != dummy_val) {
			print_error("Multiple declaration of "+ id->getName() + " in parameter");
			return; 
		}
	}

	cur_param_list->push_back(new SymbolInfo(
		id->getName(),
		id->getType(),
		"VAR", 
		type->getType() // variable type
	));
	// cout<<"Inserted "<<id->getName()<<" : "<<id->getType()<<endl;
}


// helper to insert variables in symbol table
// error handling:
// 1. type cannot by void -> handled directly in var_declaration rule according to sample io
// 2. multiple declaration of var
void insert_vars(SymbolInfo* id, string type){
	// if(type == "VOID"){
	// 	print_error("Variable type cannot be void");
	// 	return; 
	// }

	bool success = st->insert(new SymbolInfo(
		id->getName(),
		id->getType(),
		id->value_type,
		type
	));
	if(!success) print_error("Multiple declaration of " + id->getName());
}


// helper for lcurl and rcurl
void handle_lcurl(){
	// enter scope
	st->enterScope();

	// insert params if available and this is lcurl of a function
	if (in_function && cur_param_list != nullptr) {
		SymbolInfo* temp;
		bool success;
		for(int i=0; i<cur_param_list->size(); i++){
				temp = cur_param_list->at(i);
				success = st->insert(new SymbolInfo(temp));  // TODO : TRACK ALL LIFECYCLES, CALL DESTRUCTOR ON PARAM_LIST IN SYMBOLINFO
				// if(!success) print_error("Multiple declaration of "+ temp->getName() + " in parameter"); // TODO
			}
	}
}


void handle_rcurl(){
	st->printAll();
	st->exitScope();
}


// check whether parameters match
// func_call = True means now checking in a function call. else checking in function declaration
// error handling
// 1: number of arguments mismatch
// 2: ith argument type mismatch
bool param_match(vector<SymbolInfo*>* func_params, vector<SymbolInfo*>* called_params, string func_name, bool func_call=false){
	if(func_params == nullptr) func_params = new vector<SymbolInfo*>();
	if(called_params == nullptr) called_params = new vector<SymbolInfo*>();
	
	string declaration_message = "with function declaration ";
	if(func_call) declaration_message = "";
	declaration_message += "in function " + func_name;

	if(func_params->size() != called_params->size()){
		print_error("Total number of arguments mismatch " + declaration_message);
		return false;
	}
	
	for(int i=0; i<called_params->size(); i++){
		// func_params->at(i)->printInfo();
		// called_params->at(i)->printInfo();
		// dummy val error already caught
		if(called_params->at(i)->return_type == dummy_val) continue;
		if(func_params->at(i)->return_type != called_params->at(i)->return_type){
			print_error(to_string(i+1) + "th argument mismatch " + declaration_message);
			return false;
		}
	}
	return true;
}


// handle inserting a function into symbol table
// if define=true then in definition, else in declaration
// error handling:
// 1: Multiple Declaration of Function
// 2: Checks param_match errors
// 3: Function return type mismatch
void handle_func(SymbolInfo* id, SymbolInfo* return_type, bool define=true){
	// insert into function(id) additional info
	SymbolInfo* temp = new SymbolInfo(id->getName(), id->getType());
	temp->add_func_info("FUNC", return_type->getType(), cur_param_list, define);

	// handle multiple declaration
	bool success = st->insert(temp);
	if(!success){
		// if already defined then error
		// if multiple declaration then error
		temp = st->lookUp(id->getName());
		// if temp is not a function then it is something else . so multiple declaration
		if(temp->value_type != "FUNC") print_error("Multiple declaration of " + temp->getName());
		// if defined or already declared(exists in SymbolTable) and this is another declaration
		else if(temp->func_defined || (!define)) print_error("Multiple declaration of " + temp->getName());
		// if only declared not defined, then no error. But check consistency
		else if(define) {
			param_match(temp->param_list, cur_param_list, temp->getName());
			temp->func_defined = true; // now defined

			if(temp->return_type != return_type->getType()){
				print_error("Return type mismatch with function declaration in function " + temp->getName());
			}
		}
	}

	// do these if in func definition not declaration
	if(define){
		// this enables LCURL action : inserts params if available
		in_function = true;
	}
}


// check if id is declared
// if error then return false and 'return_type' attribute will be dummy_val
// error handling : 
// 1: Undeclared variable
// 2: Not a variable
// 3: If array=true: check if id is array. Else check if id is not an array
bool check_var_declared(SymbolInfo* id, bool array = false){
	SymbolInfo* temp = st->lookUp(id->getName());
	id->return_type = dummy_val; // store dummy type in case of error
		
	if(temp == nullptr){
		print_error("Undeclared variable " + id->getName());
		return false;
	}
	else if(temp->value_type != "ARRAY" && temp->value_type != "VAR"){
		print_error("Not a variable");
		return false;
	}
	else{
		// check if array and not 
		if(array && (temp->value_type != "ARRAY")){
			print_error(id->getName() + " not an array");
			return false;
		}
		else if(!array && (temp->value_type == "ARRAY")){
			print_error("Type mismatch, " + id->getName() + " is an array");
			return false;
		}
	}

	// store old values
	id->value_type = temp->value_type;
	id->return_type = temp->return_type;
	return true;
}


// used when type cannot be void
// no need to handle dummy_val here
// error handling:
// 1: expression cannot be void
string check_void(string type){
	if(type == "VOID"){
		print_error("Void function used in expression"); // TODO
		return dummy_val;
	}
	return type;
}

// handle type match. type1 is left exp, type2 is right exp
// choice :
// 0 : basic type mismatch
// 1 : checks whether there is any void term and returns int
// 2 : checks whether both types are integers
// 3 : checks whether both types are integers and floats and returns the highest one
string handle_type(string type1, string type2, int choice=0, string message=""){
	// check if already an error has occured
	if(type1 == dummy_val || type2 == dummy_val) return dummy_val;
	// check if any of the types are void
	if(type1 == "VOID" || type2 == "VOID"){
			print_error("Void function used in expression");
			return dummy_val;
		}

	// make return type int (void and prev_error checked)
	if(choice == 1){
		return "INT";
	}
	
	// if integer is required in both operation
	if(choice == 2 && (type1 != "INT" || type2 != "INT")){
		print_error(message); return dummy_val;
	}	 

	// for adding
	if(choice == 3){
		if(type1 != type2) return "FLOAT"; 
	}

	// if no match
	if(type1 != type2){
		// float = int : then okay
		if(type1 == "FLOAT" && type2 == "INT") return type1;
		else{
			print_error("Type Mismatch"); return dummy_val;
		}
	}

	return type1;
}

%}

%union {SymbolInfo* sinfo; vector<SymbolInfo*>* vec;}
%token <sinfo> IF FOR DO INT FLOAT VOID SWITCH DEFAULT ELSE WHILE BREAK CHAR DOUBLE RETURN CASE CONTINUE
%token <sinfo> ADDOP MULOP INCOP DECOP RELOP ASSIGNOP LOGICOP NOT LPAREN RPAREN LCURL RCURL LTHIRD RTHIRD COMMA SEMICOLON 
%token <sinfo> CONST_INT CONST_FLOAT CONST_CHAR ID STRING COMMENT PRINTLN
%type <vec> start program unit func_declaration func_definition parameter_list compound_statement
%type <vec> var_declaration type_specifier declaration_list statements statement expression_statement
%type <vec> variable expression logic_expression rel_expression simple_expression term unary_expression
%type <vec> factor argument_list arguments

%start start

/* %left 
%right
*/

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE 


%%

start : 
	program
	{
		$$ = $1;
		rule_match("start : program", $1);
		delete $$;
	}
	;


program : 
	program unit 
	{
		$$ = add_vals($1, $2);
		rule_match("program : program unit", $$);
	}
	| unit
	{
		$$ = $1;
		rule_match("program : unit", $$);
	}


unit : 
	var_declaration 
	{
		$$ = $1;
		rule_match("unit : var_declaration", $$);
	}
	| func_declaration 
	{
		$$ = $1;
		rule_match("unit : func_declaration", $$);
	}
	| func_definition
	{
		$$ = $1;
		rule_match("unit : func_definition", $$);
	}
	;


func_declaration : 
	type_specifier ID LPAREN parameter_list RPAREN SEMICOLON
	{
		// error handling : handle_func errors
		handle_func($2, $1->at(0), false); // definition = false
		cur_param_list = nullptr; // clear param for next use

		$1->insert($1->end(),  {$2, $3});
		$$ = add_vals($1, $4);
		$$->insert($$->end(), {$5, $6});
		rule_match(
			"func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON",
			$$
		);
	}
	| type_specifier ID LPAREN RPAREN SEMICOLON
	{
		// error handling : handle_func errors
		handle_func($2, $1->at(0), false); // definition = false

		$1->insert($1->end(),  {$2, $3, $4, $5});
		$$ = $$;
		rule_match(
			"func_declaration : type_specifier ID LPAREN RPAREN SEMICOLON",
			$$
		);
	}
	| type_specifier ID LPAREN parameter_list error RPAREN SEMICOLON
	{
		// ERROR RECOVERY : for single param in func dec
		// error handling : handle_func errors
		handle_func($2, $1->at(0), false); // definition = false
		cur_param_list = nullptr; // clear param for next use

		$1->insert($1->end(),  {$2, $3});
		$$ = add_vals($1, $4);
		$$->insert($$->end(), {$6, $7});
		rule_match(
			"func_declaration : type_specifier ID LPAREN parameter_list error RPAREN SEMICOLON",
			$$
		);
	}
	| type_specifier ID LPAREN error RPAREN SEMICOLON
	{
		// ERROR RECOVERY : error between ()
		// error handling : handle_func errors
		handle_func($2, $1->at(0), false); // definition = false

		$1->insert($1->end(),  {$2, $3, $5, $6});
		$$ = $$;
		rule_match(
			"func_declaration : type_specifier ID LPAREN error RPAREN SEMICOLON",
			$$
		);
	}
	;


func_definition : 
	type_specifier ID LPAREN parameter_list RPAREN{ handle_func($2, $1->at(0)); } compound_statement
	{
		// error handling : handle_func errors
		cur_param_list = nullptr; // clear param for next use
		in_function = false; // out of function
		
		$1->insert($1->end(),  {$2, $3});
		$$ = add_vals($1, $4);
		$$->push_back($5);
		$$ = add_vals($$, $7);
		rule_match(
			"func_definition : type_specifier ID LPAREN parameter_list RPAREN compound_statement",
			$$
		);
	}
	| type_specifier ID LPAREN RPAREN{ handle_func($2, $1->at(0)); } compound_statement
	{
		// error handling : handle_func errors
		in_function = false; // out of function

		$1->insert($1->end(),  {$2, $3, $4});
		$$ = add_vals($1, $6);
		rule_match(
			"func_definition : type_specifier ID LPAREN RPAREN compound_statement",
			$$
		);
	}
	| type_specifier ID LPAREN parameter_list error RPAREN{ handle_func($2, $1->at(0)); } compound_statement
	{
		// ERROR RECOVERY : for single params in func def
		// error handling : handle_func errors
		cur_param_list = nullptr; // clear param for next use
		in_function = false; // out of function
		
		$1->insert($1->end(),  {$2, $3});
		$$ = add_vals($1, $4);
		$$->push_back($6);
		$$ = add_vals($$, $8);
		rule_match(
			"func_definition : type_specifier ID LPAREN parameter_list error RPAREN compound_statement",
			$$
		);
	}
	| type_specifier ID LPAREN error RPAREN{ handle_func($2, $1->at(0)); } compound_statement
	{
		// ERROR RECOVERY : error between ()
		// error handling : handle_func errors
		in_function = false; // out of function

		$1->insert($1->end(),  {$2, $3, $5});
		$$ = add_vals($1, $7);
		rule_match(
			"func_definition : type_specifier ID LPAREN error RPAREN compound_statement",
			$$
		);
	}
	;				


parameter_list  : 
	parameter_list COMMA type_specifier ID
	{
		// error handling : insert_param errors
		insert_param($4, $3->at(0)); 
		
		$1->push_back($2);
		$$ = add_vals($1, $3);
		$$->push_back($4);
		rule_match(
			"parameter_list : parameter_list COMMA type_specifier ID",
			$$
		);
	}
	| parameter_list COMMA type_specifier
	{
		// error handling : insert_param errors
		insert_param(new SymbolInfo(dummy_val, "ID"), $3->at(0)); // dummy variable name

		$1->push_back($2);
		$$ = add_vals($1, $3);
		rule_match(
			"parameter_list : parameter_list COMMA type_specifier",
			$$
		);
	}
	| type_specifier ID
	{
		// error handling : insert_param errors
		insert_param($2, $1->at(0)); 

		$1->push_back($2);
		$$ = $1;
		rule_match(
			"parameter_list : type_specifier ID",
			$$
		);
	}
	| type_specifier
	{
		// error handling : insert_param errors
		insert_param(new SymbolInfo(dummy_val, "ID"), $1->at(0)); // dummy variable name
		
		$$ = $1;
		rule_match(
			"parameter_list : type_specifier",
			$$
		);
	}
	| parameter_list error COMMA type_specifier ID
	{
		// ERROR RECOVERY : for multiple params
		// error handling : insert_param errors
		insert_param($5, $4->at(0)); 
		
		$1->push_back($3);
		$$ = add_vals($1, $4);
		$$->push_back($5);
		rule_match(
			"parameter_list : parameter_list error COMMA type_specifier ID",
			$$
		);
	}
	| parameter_list error COMMA type_specifier
	{
		// ERROR RECOVERY : for multiple params
		// error handling : insert_param errors
		insert_param(new SymbolInfo(dummy_val, "ID"), $4->at(0)); // dummy variable name

		$1->push_back($3);
		$$ = add_vals($1, $4);
		rule_match(
			"parameter_list : parameter_list error COMMA type_specifier",
			$$
		);
	}
	;


compound_statement : 
	LCURL{ handle_lcurl();} statements RCURL
	{
		$$ = new vector<SymbolInfo*>({$1});
		$$ = add_vals($$, $3);
		$$->push_back($4);
		rule_match(
			"compound_statement : LCURL statements RCURL",
			$$
		); 
		handle_rcurl();
	}
	| LCURL{ handle_lcurl(); } RCURL
	{
		$$ = new vector<SymbolInfo*>({$1, $3});
		rule_match(
			"compound_statement : LCURL RCURL",
			$$
		);
		handle_rcurl();
	}
	;


var_declaration : 
	type_specifier declaration_list SEMICOLON
	{
		// error handling
		// handle variable void error here : according to sample io
		if($1->at(0)->getType() == "VOID") print_error("Variable type cannot be void"); 

		$$ = add_vals($1, $2);
		$$->push_back($3);
		rule_match("var_declaration : type_specifier declaration_list SEMICOLON", $$);
	}
	|
	type_specifier declaration_list error SEMICOLON
	{
		// ERROR RECOVERY : for error before semicolon and after declaration_list
		// error handling
		// handle variable void error here : according to sample io
		if($1->at(0)->getType() == "VOID") print_error("Variable type cannot be void"); 

		$$ = add_vals($1, $2);
		$$->push_back($4);
		rule_match("var_declaration : type_specifier declaration_list error SEMICOLON", $$);
	}
	;	


type_specifier	: 
	INT 
	{
		var_type = $1->getType(); // only needed to store for declaration list : to match sample io
		$$ = new vector<SymbolInfo*>({$1});
		rule_match("type_specifier : INT", $$);
	}
	| FLOAT 
	{
		var_type = $1->getType();
		$$ = new vector<SymbolInfo*>({$1});
		rule_match("type_specifier : FLOAT", $$);
	}
	| VOID 
	{
		var_type = $1->getType();
		$$ = new vector<SymbolInfo*>({$1});
		rule_match("type_specifier : VOID", $$);
	}
	;


declaration_list : 
	declaration_list COMMA ID 
	{
		// error handling : insert_vars errors
		$3->value_type = "VAR";
		$$ = add_vals($1, new vector<SymbolInfo*>({$2, $3}));
		insert_vars($3, var_type); 
		rule_match("declaration_list : declaration_list COMMA ID", $$);
	}
	| declaration_list COMMA ID LTHIRD CONST_INT RTHIRD
	{
		// error handling : insert_vars errors
		$3->value_type = "ARRAY";
		$$ = add_vals($1, new vector<SymbolInfo*>(
			{$2, $3, $4, $5, $6}
		));
		insert_vars($3, var_type); 
		rule_match(
			"declaration_list : declaration_list COMMA ID LTHIRD CONST_INT RTHIRD", 
			$$
		);
	}
	| ID 
	{
		// error handling : insert_vars errors
		$1->value_type = "VAR";
		$$ = new vector<SymbolInfo*>({$1});
		insert_vars($1, var_type);  
		rule_match("declaration_list : ID", $$); 
	}
	| ID LTHIRD CONST_INT RTHIRD 
	{
		// error handling : insert_vars errors
		$1->value_type = "ARRAY";
		$$ = new vector<SymbolInfo*>({$1, $2, $3, $4}); 
		insert_vars($1, var_type); 
		rule_match("declaration_list : ID LTHIRD CONST_INT RTHIRD", $$);
	}
	| 
	declaration_list error COMMA ID
	{
		// ERROR RECOVERY : error before comma var
		// error handling : insert_vars errors
		$4->value_type = "VAR";
		$$ = add_vals($1, new vector<SymbolInfo*>({$3, $4}));
		insert_vars($4, var_type); 
		rule_match("declaration_list : declaration_list error COMMA ID", $$);
	}
	| declaration_list error COMMA ID LTHIRD CONST_INT RTHIRD
	{
		// ERROR RECOVERY : error before comma array
		// error handling : insert_vars errors
		$4->value_type = "ARRAY";
		$$ = add_vals($1, new vector<SymbolInfo*>(
			{$3, $4, $5, $6, $7}
		));
		insert_vars($4, var_type); 
		rule_match(
			"declaration_list : declaration_list error COMMA ID LTHIRD CONST_INT RTHIRD", 
			$$
		);
	}
	;


statements : 
	statement
	{
		$$ = $1;
		rule_match(
			"statements : statement",
			$$
		);
	}
	| statements statement
	{
		$$ = add_vals($1, $2);
		rule_match(
			"statements : statements statement",
			$$
		);
	}
	;

statement : 
	var_declaration
	{
		$$ = $1;
		rule_match(
			"statement : var_declaration",
			$$
		);
	}
	| expression_statement
	{
		$$ = $1;
		rule_match(
			"statement : expression_statement",
			$$
		);
	}
	| compound_statement
	{
		$$ = $1;
		rule_match(
			"statement : compound_statement",
			$$
		);
	}
	| FOR LPAREN expression_statement expression_statement expression RPAREN statement
	{
		$$ = new vector<SymbolInfo*>({$1, $2});
		$$ = add_vals($$, $3);
		$$ = add_vals($$, $4);
		$$ = add_vals($$, $5);
		$$->push_back($6);
		$$ = add_vals($$, $7);
		rule_match(
			"statement : FOR LPAREN expression_statement expression_statement expression RPAREN statement",
			$$
		);
	}
	| IF LPAREN expression RPAREN statement	%prec LOWER_THAN_ELSE
	{
		$$ = new vector<SymbolInfo*>({$1, $2});
		$$ = add_vals($$, $3);
		$$->push_back($4);
		$$ = add_vals($$, $5);
		rule_match(
			"statement : IF LPAREN expression RPAREN statement",
			$$
		);
	}
	| IF LPAREN expression RPAREN statement ELSE statement
	{
		$$ = new vector<SymbolInfo*>({$1, $2});
		$$ = add_vals($$, $3);
		$$->push_back($4);
		$$ = add_vals($$, $5);
		$$->push_back($6);
		$$ = add_vals($$, $7);
		rule_match(
			"statement : IF LPAREN expression RPAREN statement ELSE statement",
			$$
		);
	}
	| WHILE LPAREN expression RPAREN statement
	{
		$$ = new vector<SymbolInfo*>({$1, $2});
		$$ = add_vals($$, $3);
		$$->push_back($4);
		$$ = add_vals($$, $5);
		rule_match(
			"statement : WHILE LPAREN expression RPAREN statement",
			$$
		);
	}
	| PRINTLN LPAREN ID RPAREN SEMICOLON
	{
		// error handling : 
	    // 1: check declaration
		check_var_declared($3);

		$$ = new vector<SymbolInfo*>({$1, $2, $3, $4, $5});
		rule_match(
			"statement : PRINTLN LPAREN ID RPAREN SEMICOLON",
			$$
		);
	}
	| RETURN expression SEMICOLON
	{
		$$ = new vector<SymbolInfo*>({$1});
		$$ = add_vals($$, $2);
		$$->push_back($3);
		rule_match(
			"statement : RETURN expression SEMICOLON",
			$$
		);
	}
	| error expression_statement
	{
		// ERROR RECOVERY
		// if an error occurs: bison disregards stack tokens and shifts next tokens to find a suitable erro rule
		// yyclearin; // clears lookahead
		yyerrok; // clears input tokens
		$$ = $2;
		rule_match(
			"statement : error expression_statement",
			$$
		);
	}
	;

	  
expression_statement : 
	SEMICOLON			
	{
		$$ = new vector<SymbolInfo*>({$1});
		rule_match(
			"expression_statement : SEMICOLON",
			$$
		);
	}
	| expression SEMICOLON 
	{
		$$ = $1;
		$$->push_back($2);
		rule_match(
			"expression_statement : expression SEMICOLON",
			$$
		);
	}
	;
	   

variable : 
	ID 		
	{
		// error handling: 
		// 1. check declaration
		check_var_declared($1);

		$$ = new vector<SymbolInfo*>({$1});
		rule_match(
			"variable : ID",
			$$
		);
	}
	| ID LTHIRD expression RTHIRD 
	{
		// error handling: 
		// 1. check declaration
		// 2. expression here must be INT
		if(check_var_declared($1, true)){
			// if return type is dummy_val then already an error has occured so no need to show this
			if(($3->at(0)->return_type != "INT") && ($3->at(0)->return_type != dummy_val))
				print_error("Expression inside third brackets not an integer");

		}

		$$ = new vector<SymbolInfo*>({$1, $2});
		$$ = add_vals($$, $3);
		$$->push_back($4);
		rule_match(
			"variable : ID LTHIRD expression RTHIRD",
			$$
		);
	}
	;
	 

 expression : 
 	logic_expression	
	{
		$$ = $1;
		rule_match(
			"expression : logic_expression",
			$$
		);
	}
	| variable ASSIGNOP logic_expression 	
	{
		// error handling:
		// 1: L.H.S error
		// 2: R.H.S void
		// 3: Type Mismatch
		// if no variable error 
		if($1->at(0)->return_type != dummy_val){
			// check whether right side is void or not
			$3->at(0)->return_type = check_void(
				$3->at(0)->return_type
			);

			// if not void then check for mismatch
			$1->at(0)->return_type = handle_type(
				$1->at(0)->return_type, 
				$3->at(0)->return_type
			);
		}
	

		$$ = $1;
		$$->push_back($2);
		$$ = add_vals($$, $3);
		rule_match(
			"expression : variable ASSIGNOP logic_expression",
			$$
		);
	}


logic_expression : 
	rel_expression 	
	{
		$$ = $1;
		rule_match(
			"logic_expression : rel_expression",
			$$
		);
	}
	| rel_expression LOGICOP rel_expression 	
	{
		// error handling:
		// 1: check if either L.H.S or R.H.S is void
		$1->at(0)->return_type = handle_type(
			$1->at(0)->return_type, 
			$3->at(0)->return_type,
			1, 
			"" //"Non-Integer result of LOGICOP"
		);

		$$ = $1;
		$$->push_back($2);
		$$ = add_vals($$, $3);
		rule_match(
			"logic_expression : rel_expression LOGICOP rel_expression",
			$$
		);
	}
	;


rel_expression	: 
	simple_expression 
	{
		$$ = $1;
		rule_match(
			"rel_expression : simple_expression",
			$$
		);
	}
	| simple_expression RELOP simple_expression	
	{
		// error handling:
		// 1: check if either L.H.S or R.H.S is void
		$1->at(0)->return_type = handle_type(
			$1->at(0)->return_type, 
			$3->at(0)->return_type,
			1,
			"" //"Non-integer result of RELOP"
		);

		$$ = $1;
		$$->push_back($2);
		$$ = add_vals($$, $3);
		rule_match(
			"rel_expression : simple_expression RELOP simple_expression",
			$$
		);
	}
	;


simple_expression : 
	term 
	{
		$$ = $1;
		rule_match(
			"simple_expression : term",
			$$
		);
	}
	| simple_expression ADDOP term 
	{
		// error handling:
		// 1: Check if either L.H.S or R.H.S is void and type compatibility
		$1->at(0)->return_type = handle_type(
			$1->at(0)->return_type, 
			$3->at(0)->return_type,
			3,
			"" //"Incompatible type in ADDOP"
		);

		$$ = $1;
		$$->push_back($2);
		$$ = add_vals($$, $3);
		rule_match(
			"simple_expression : simple_expression ADDOP term",
			$$
		);
	}
	/* | simple_expression ADDOP error term 
	{
		yyclearin;
		yyerrok;
		// ERROR RECOVERY
		// error handling:
		// 1: Check if either L.H.S or R.H.S is void and type compatibility
		$1->at(0)->return_type = handle_type(
			$1->at(0)->return_type, 
			$4->at(0)->return_type,
			3,
			"" //"Incompatible type in ADDOP"
		);

		$$ = $1;
		$$->push_back($2);
		$$ = add_vals($$, $4);
		rule_match(
			"simple_expression : simple_expression ADDOP error term",
			$$
		);
	}
	; */


term :	
	unary_expression
	{
		$$ = $1;
		rule_match(
			"term : unary_expression",
			$$
		);
	}
	|  term MULOP unary_expression
	{
		// error handling
		// 1: Check if either L.H.S or R.H.S is void and type compatibility
		// 2: Non-integer operand for %
		// 3: Modulus by zero
		int choice = 3;
		string message = ""; // "Incompatible type in MULOP";
		if($2->getName() == "%"){
			choice = 2;
			message = "Non-Integer operand on modulus operator";
		}

		$1->at(0)->return_type = handle_type(
			$1->at(0)->return_type, 
			$3->at(0)->return_type,
			choice,
			message
		);

		// handle modulus by zero error if no other error occurs
		if(($2->getName() == "%") && $1->at(0)->return_type != dummy_val){
			if($3->at(0)->return_type == "INT" && $3->at(0)->getName() == "0"){
				print_error("Modulus by Zero");
				$1->at(0)->return_type = dummy_val;
			}
		}

		$$ = $1;
		$$->push_back($2);
		$$ = add_vals($$, $3);
		rule_match(
			"term : term MULOP unary_expression",
			$$
		);
	}
	;


unary_expression : 
	ADDOP unary_expression  
	{
		// error handling
		// 1: check if void
		$1->return_type = check_void(
			$2->at(0)->return_type
		);

		$$ = new vector<SymbolInfo*>({$1});
		$$ = add_vals($$, $2);
		rule_match(
			"unary_expression : ADDOP unary_expression",
			$$
		);
	}
	| NOT unary_expression 
	{
		// error handling
		// 1: check if void
		$1->return_type = check_void(
			$2->at(0)->return_type
		);

		$$ = new vector<SymbolInfo*>({$1});
		$$ = add_vals($$, $2);
		rule_match(
			"unary_expression : NOT unary_expression",
			$$
		);
	}
	| factor 
	{
		$$ = $1;
		rule_match(
			"unary_expression : factor",
			$$
		);
	}
	;
	

factor	: 
	variable 
	{
		$$ = $1;
		rule_match(
			"factor : variable",
			$$
		);
	}
	| ID LPAREN argument_list RPAREN
	{
		// error handling:
		// 1: ID is a function or not
		// 2: if parameter no, type, sequence match
		// check if called ID is a function
		SymbolInfo* temp = st->lookUp($1->getName());
		if(temp == nullptr){
			print_error("Undeclared function " + $1->getName());
			$1->return_type = dummy_val;
		}
		else if(temp->value_type != "FUNC") {
			print_error("Not a function : " + temp->getName());
			// fill in as dummy vals
			$1->return_type = dummy_val; 
		}
		else {
			$1->copyValues(temp);
			// check if parameter no and type match with argument_list
			vector<SymbolInfo*>* args = new vector<SymbolInfo*>();
			for(int i=0; i<$3->size(); i++){
				// store expression ret type in first symbolinfo of each arg expression
				if((i == 0) || ($3->at(i-1)->getType() == "COMMA")) args->push_back($3->at(i)); 
			}
			// if params doesnt match then store error (fill in as dummy vals)
			if(!param_match($1->param_list, args, $1->getName(), true)) $1->return_type = dummy_val;
			delete args;
		}

		$$ = new vector<SymbolInfo*>({$1, $2});
		$$ = add_vals($$, $3);
		$$->push_back($4);
		rule_match(
			"factor : ID LPAREN argument_list RPAREN",
			$$
		);
	}
	| LPAREN expression RPAREN
	{
		$1->return_type = $2->at(0)->return_type; // pass on return type

		$$ = new vector<SymbolInfo*>({$1});
		$$ = add_vals($$, $2);
		$$->push_back($3);
		rule_match(
			"factor : LPAREN expression RPAREN",
			$$
		);
	}
	| CONST_INT 
	{
		$1->return_type = "INT";

		$$ = new vector<SymbolInfo*>({$1});
		rule_match(
			"factor : CONST_INT",
			$$
		);
	}
	| CONST_FLOAT
	{
		$1->return_type = "FLOAT";

		$$ = new vector<SymbolInfo*>({$1});
		rule_match(
			"factor : CONST_FLOAT",
			$$
		);
	}
	| variable INCOP 
	{
		$$ = $1;
		$$->push_back($2);
		rule_match(
			"factor : variable INCOP",
			$$
		);
	}
	| variable DECOP
	{
		$$ = $1;
		$$->push_back($2);
		rule_match(
			"factor : variable DECOP",
			$$
		);
	}
	;
	

argument_list : 
	arguments
	{
		$$ = $1;
		rule_match(
			"argument_list : arguments",
			$$
		);
	}
	| 
	{
		$$ = new vector<SymbolInfo*>(); // empty
		rule_match(
			"argument_list : ",
			$$
		);
	}
	;
	

arguments : 
	arguments COMMA logic_expression
	{
		$$ = $1;
		$$->push_back($2);
		$$ = add_vals($$, $3);
		rule_match(
			"arguments : arguments COMMA logic_expression",
			$$
		);
	}
	| logic_expression
	{
		$$ = $1;
		rule_match(
			"arguments : logic_expression",
			$$
		);
	}
	;


%%


int main(int argc,char *argv[])
{
	FILE *fp;
	if((fp=fopen(argv[1],"r"))==NULL)
	{
		printf("Cannot Open Input File.\n");
		exit(1);
	}

	freopen("1705044_log.txt", "w", stdout);

	/* fp2= fopen(argv[2],"w");
	fclose(fp2);
	fp3= fopen(argv[3],"w");
	fclose(fp3);
	
	fp2= fopen(argv[2],"a");
	fp3= fopen(argv[3],"a"); */
	

	yyin=fp;
	yyparse();
	
	cout<<"symbol table:"<<endl;
	st->printAll();
	cout<<"Total lines: "<<line_count<<endl;
	cout<<"Total errors: "<<error_count<<endl;
	fout<<"Total errors: "<<error_count<<endl;
	fout.close();
	/* fclose(fp2);
	fclose(fp3); */
	
	return 0;
}

