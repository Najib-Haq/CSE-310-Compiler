%{
#include <bits/stdc++.h>
#include "SymbolTable.h"
// #define YYSTYPE SymbolInfo*

using namespace std;

int yyparse(void);
int yylex(void);
extern FILE *yyin;
ofstream fout("error.txt");

SymbolTable *st;
int line_count = 1;
int error_count = 0;

// extra info for functions
vector<SymbolInfo*>* cur_param_list; // define new in adding func, delete after adding to func sinfo
bool in_function = false;

string dummy_val = "-100"; // store dummy vals when params declared without id or when an error has occured
// if an error has occured, store return type as dummy_val
// this signals no need to show further errors
string var_type = "-100"; // to store type of variables in declaration_list to match sample io


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////// ICG VARIABLES AND FUNCTIONS ///////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

ofstream fasm("code.asm");
int label_count = -1; // keep track of labels
int temp_count = -1; // keep track of temporary variables
int total_temp_count = -1; // keep track of TOTAL temps : for efficient temps
int prev_temp_count = -1; // keep track of previous temps : for efficient temps

int scope_id = 0; // keep track of scope for declared variables
string return_variable = "return_value"; // to get output of return value from a function
string init_vars = "\t" + return_variable + " dw ?\n"; // string to keep track of variable initializations
vector<string>* init_vars_list = new vector<string>(); // to keep track of all variables -> specially needed for function call

string newLabel(){
	label_count += 1;
	return "L_"+to_string(label_count);
}

string newTemp(){
	temp_count += 1;
	string new_temp = "t_"+to_string(temp_count);

	// for efficient temps
	if(temp_count > total_temp_count){
		total_temp_count = temp_count;
		init_vars += "\t" + new_temp + " dw ?\n";	// insert temp vars from temp count now
	}
	return new_temp;
}

string print_func(){
	return "print PROC\n"
		   "\tpush ax\n"
		   "\tpush bx\n"  // push the registers
		   "\tpush cx\n"  // assuming ax has the printing value
		   "\tpush dx\n"
		   "\t;check neg\n"
		   "\tcmp ax, 8000H\n" // check if neg
		   "\tjb positive\n" // if ax<2^15, then positive number
		   "negative:\n"
		   "\tneg ax\n" // make ax negative
		   "\tpush ax\n" // save ax
		   "\tmov ah, 2\n" // print mode
		   "\tmov dl, '-'\n" // print minus
		   "\tint 21h\n"
		   "\tpop ax\n"
		   "positive:\n"
		   "\tmov bx, 10\n" // bx = 10
		   "\tmov cx, 0\n"  // cx = 0
		   "getVals:\n"
		   "\tmov dx, 0\n" 
		   "\tdiv bx\n"  // divide by 10
		   "\tpush dx\n" // dx = dx : ax % 10 -> stack
		   "\tinc cx\n"  // cx += 1
		   "\tcmp ax, 0\n"  // ax is now dx : ax / 10
		   "\tjne getVals\n" // if quotient != 0 then continue division
		   "printing:\n"
		   "\tmov ah, 2\n" // print mode
		   "\tpop dx\n" // get stack values
		   "\tadd dl, '0'\n" // get actual print value (ascii + 48)
		   "\tint 21h\n"
		   "\tdec cx\n" // c-=1
		   "\tcmp cx, 0\n"
		   "\tjne printing\n" // if c!=0: more things left to print
		   "\tmov dl, 0Ah\n" // CR
		   "\tint 21h\n" 
		   "\tmov dl, 0Dh\n" // LR
		   "\tint 21h\n"
		   "\tpop dx\n" // return the appropriate values
		   "\tpop cx\n"
		   "\tpop bx\n"
		   "\tpop ax\n"
		   "\tret\n"
		   "print ENDP\n\n";
}

// generate ICG
void ICG(string code){
	// ofstream fasm("code.asm");

	// initialize
	string initiate = ".MODEL small\n"
					  ".STACK 100h\n"
					  ".DATA\n";

	initiate += init_vars + '\n'; // add declared variables
	initiate += ".CODE\n"; // initiate code section
	
	// TODO: write print function
	initiate += print_func();
	// full code
	fasm<<initiate;
	fasm<<code;
	fasm<<"END main";

	fasm.close();
}

// add code values
void add_code(SymbolInfo* s1, SymbolInfo* s2){
	s1->code = s1->code + s2->code;
	if(s1->symbol == "") s1->symbol = s2->symbol; // TODO :  check this
}

// get commands from relation ops -> opposite relations
string get_relop_command(string val){
	if(val == "<") 		 return "jge";
	else if(val == "<=") return "jg";
	else if(val == ">")  return "jle";
	else if(val == ">=") return "jl";
	else if(val == "==") return "jne";
	else if(val == "!=") return "je";
	return "";
}

// get pushed parameters' position in stack
string param_stack_position(int pos, int total){
	int index = (total-pos)*2 + 4;
	return "word ptr [bp + " + to_string(index) + "]";
}

// handle function definition code
void function_code(string func_name, SymbolInfo* func_body, int len_params){
	string code, ret="";
	if(len_params>0) ret = to_string(len_params*2); // pop return saved params of stack

	if(func_name == "main") {
		code = "\tmov ax, @data\n\tmov ds, ax\n" + func_body->code + // data segment for main
			   "\t;dos exit\n\tmov ah, 4ch\n\tint 21h\n"; // return control to dos
	}
	else{
		// push to stack and pop
		// save di too because of array
		code = "\tpush bp\n" 	// save bp
			   "\tmov bp, sp\n"
			   "\tpush ax\n\tpush bx\n\tpush cx\n\tpush dx\n\tpush di\n" + // standard practise
			   func_body->code; // + 
			//    "\tpop di\n\tpop dx\n\tpop cx\n\tpop bx\n\tpop ax\n"
			//    "\tpop bp\n" 	// restore bp
			//    "\tret " + ret + "\n"; // restore stack and return
	}
	
	func_body->code = code; // set string
}


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////// PARSER FUNCTIONS //////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

void yyerror(char *s){
	//write your code
	// cout<<"Error : "<<s<<endl;
	fout<<"Error at line "<<line_count<<": "<<s<<endl<<endl;
	cout<<"Error at line "<<line_count<<": "<<s<<endl<<endl;
	error_count += 1;
}


string print_vals(vector<SymbolInfo*>* vals){
	string value, type;
	SymbolInfo* temp;
	string all_vals = "";
	for (auto i = vals->begin(); i != vals->end(); ++i){
		temp = *i;
		value = temp->getName();
		type = temp->getType();
		
		all_vals += value;
		if(type == "INT" || type == "FLOAT" || type == "VOID" || type == "RETURN" || type == "IF" || 
		   type == "ELSE" || type == "WHILE") {
			   value = value + " ";
			   all_vals += " ";
		   }
		else if(type == "SEMICOLON" || type == "LCURL") {
			value = value + "\n";
			all_vals += " ";
		}
		else if(type == "RCURL") {
			value = value + "\n\n";
			all_vals += " ";
		}

		cout<<value;
	}
	cout<<endl<<endl;
	return all_vals;
}


string rule_match(string rule, vector<SymbolInfo*>* vals){
	cout<<"Line "<<line_count<<": "<<rule<<endl<<endl;
	if (vals != nullptr) return print_vals(vals);
	else return "";
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
	if(cur_param_list == nullptr) cur_param_list = new vector<SymbolInfo*>();
	
	if(type->getType() == "VOID"){
		print_error("Variable type cannot be void");
		return; 
	}

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
	if(type == "VOID"){
		// print_error("Variable type cannot be void");
		return; 
	}

	bool success = st->insert(new SymbolInfo(
		id->getName(),
		id->getType(),
		id->value_type,
		type,
		id->symbol
	));
	if(!success) print_error("Multiple declaration of " + id->getName());
}

// helper for lcurl and rcurl
void handle_lcurl(){
	scope_id += 1; // for ICG variable declaration names
	// enter scope
	st->enterScope();
	// insert params if available and this is lcurl of a function
	if (in_function && cur_param_list != nullptr) {
		SymbolInfo* temp;
		bool success;
		for(int i=0; i<cur_param_list->size(); i++){
				temp = cur_param_list->at(i);
				
				/////// for ICG declared variables /////////////////////////////
				// NOT USING STACK, STORE IN GLOBAL MEMORY
				// temp->symbol = temp->name + "_" + to_string(scope_id); // format name_current scope
				// init_vars += "\t" + temp->symbol + " dw ?\n";	

				// USING STACK
				temp->symbol = param_stack_position(i, cur_param_list->size()-1);

				success = st->insert(new SymbolInfo(temp));  // TODO : TRACK ALL LIFECYCLES, CALL DESTRUCTOR ON PARAM_LIST IN SYMBOLINFO
				// if(!success) print_error("Multiple declaration of "+ temp->getName() + " in parameter"); // TODO
			}
	}
	// efficient temps
	prev_temp_count = temp_count; // save current temp count
	temp_count = -1; // initialize temp count	
}


void handle_rcurl(){
	st->printAll();
	st->exitScope();

	// efficient temps
	temp_count = prev_temp_count; // restore temp count	
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
			
			// if float = int then okay?
			if(func_params->at(i)->return_type == "FLOAT" && called_params->at(i)->return_type == "INT") 
				continue;

			print_error(to_string(i+1) + "th argument mismatch " + declaration_message);
			return false;
		}
	}
	return true;
}


// handle inserting a function into symbol table
// if define=true then in definition, else in declaration
// bonus task : invalid scoping of function
// error handling:
// 1: No param with no name if in definition -> return type becomes dummy
// 2: Multiple Declaration of Function
// 3: Checks param_match errors
// 4: Function return type mismatch
void handle_func(SymbolInfo* id, SymbolInfo* return_type, bool define=true){
	// check if in global scope
	if (st->getCurrID() != "1") return;

	// insert into function(id) additional info
	SymbolInfo* temp = new SymbolInfo(id->getName(), id->getType());

	// handle param with no name if in definition
	if(define && cur_param_list != nullptr){
		for(int i=0; i<cur_param_list->size(); i++){
			if(cur_param_list->at(i)->getName() == dummy_val){
				print_error(to_string(i+1) + "th parameter's name not given in function definition of " + id->getName());
				temp->add_func_info("FUNC", dummy_val, new vector<SymbolInfo*>(), false); // replace return type with dummy_val
				st->insert(temp);
				return ;
			}
		}
	}
		
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
	id->symbol = temp->symbol; // ICG
	id->code = temp->code;
	// fasm<<"var declare : "<<id->code<<endl;
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
%type <vec> factor argument_list arguments enter_lcurl 

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
		rule_match("start : program", nullptr);

		ICG($1->at(0)->code);
		delete $$;
	}
	;


program : 
	program unit 
	{
		add_code($1->at(0), $2->at(0));
		$$ = add_vals($1, $2);
		rule_match("program : program unit", $$);
	}
	| unit
	{
		$$ = $1;
		rule_match("program : unit", $$);
	}
	| program error unit 
	{
		// ERROR RECOVERY : high level error recovery
		$$ = add_vals($1, $3);
		rule_match("program : program unit", $$);
	}
	;


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

		// to match log table no
		st->enterScope();
		st->exitScope();
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

		// to match log table no
		st->enterScope();
		st->exitScope();
	}
	| type_specifier ID LPAREN parameter_list error RPAREN SEMICOLON
	{
		// ERROR RECOVERY : for error after some param_list in func dec
		// error handling : handle_func errors
		handle_func($2, $1->at(0), false); // definition = false
		cur_param_list = nullptr; // clear param for next use

		$1->insert($1->end(),  {$2, $3});
		$$ = add_vals($1, $4);
		$$->insert($$->end(), {$6, $7});
		rule_match(
			"func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON",
			$$
		);

		// to match log table no
		st->enterScope();
		st->exitScope();
	}
	| type_specifier ID LPAREN error RPAREN SEMICOLON
	{
		// ERROR RECOVERY : error between ()
		// error handling : handle_func errors
		handle_func($2, $1->at(0), false); // definition = false

		$1->insert($1->end(),  {$2, $3, $5, $6});
		$$ = $$;
		rule_match(
			"func_declaration : type_specifier ID LPAREN RPAREN SEMICOLON",
			$$
		);

		// to match log table no
		st->enterScope();
		st->exitScope();
	}
	| type_specifier ID LPAREN parameter_list RPAREN error
	{
		// ERROR RECOVERY : if no semicolon in the end
		// error handling : handle_func errors
		handle_func($2, $1->at(0), false); // definition = false
		cur_param_list = nullptr; // clear param for next use
		SymbolInfo* temp = new SymbolInfo(";","SEMICOLON"); // include a semicolon

		$1->insert($1->end(),  {$2, $3});
		$$ = add_vals($1, $4);
		$$->insert($$->end(), {$5, temp});
		rule_match(
			"func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON",
			$$
		);

		// to match log table no
		st->enterScope();
		st->exitScope();
	}
	| type_specifier ID LPAREN RPAREN error
	{
		// ERROR RECOVERY : if no semicolon in the end
		// error handling : handle_func errors
		handle_func($2, $1->at(0), false); // definition = false
		SymbolInfo* temp = new SymbolInfo(";","SEMICOLON"); // include a semicolon

		$1->insert($1->end(),  {$2, $3, $4, temp});
		$$ = $$;
		rule_match(
			"func_declaration : type_specifier ID LPAREN RPAREN SEMICOLON",
			$$
		);

		// to match log table no
		st->enterScope();
		st->exitScope();
	}
	| type_specifier ID LPAREN parameter_list error RPAREN error
	{
		// ERROR RECOVERY : for error after some param_list in func dec and if no semicolon in the end
		// error handling : handle_func errors
		handle_func($2, $1->at(0), false); // definition = false
		cur_param_list = nullptr; // clear param for next use
		SymbolInfo* temp = new SymbolInfo(";","SEMICOLON"); // include a semicolon

		$1->insert($1->end(),  {$2, $3});
		$$ = add_vals($1, $4);
		$$->insert($$->end(), {$6, temp});
		rule_match(
			"func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON",
			$$
		);

		// to match log table no
		st->enterScope();
		st->exitScope();
	}
	| type_specifier ID LPAREN error RPAREN error
	{
		// ERROR RECOVERY : error between () and if no semicolon in the end
		// error handling : handle_func errors
		handle_func($2, $1->at(0), false); // definition = false
		SymbolInfo* temp = new SymbolInfo(";","SEMICOLON"); // include a semicolon

		$1->insert($1->end(),  {$2, $3, $5, temp});
		$$ = $$;
		rule_match(
			"func_declaration : type_specifier ID LPAREN RPAREN SEMICOLON",
			$$
		);

		// to match log table no
		st->enterScope();
		st->exitScope();
	}
	;


func_definition : 
	type_specifier ID LPAREN parameter_list RPAREN{ handle_func($2, $1->at(0)); } compound_statement
	{
		// error handling : handle_func errors
		in_function = false; // out of function

		int len_params = 0;
		if(cur_param_list != nullptr) len_params = cur_param_list->size();
		function_code($2->name, $7->at(0), len_params);
		$1->at(0)->code = $2->name + " PROC\n" + $7->at(0)->code + "\n" + $2->name + " ENDP\n";

		$1->insert($1->end(),  {$2, $3});
		$$ = add_vals($1, $4);
		$$->push_back($5);
		$$ = add_vals($$, $7);
		rule_match(
			"func_definition : type_specifier ID LPAREN parameter_list RPAREN compound_statement",
			$$
		);

		// need cur param list length to check length
		cur_param_list = nullptr; // clear param for next use						   
	}
	| type_specifier ID LPAREN RPAREN{ handle_func($2, $1->at(0)); } compound_statement
	{
		// error handling : handle_func errors
		in_function = false; // out of function

		function_code($2->name, $6->at(0), 0);
		$1->at(0)->code = $2->name + " proc\n" + $6->at(0)->code + "\n" + $2->name + " endp\n";

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
			"func_definition : type_specifier ID LPAREN parameter_list RPAREN compound_statement",
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
			"func_definition : type_specifier ID LPAREN RPAREN compound_statement",
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
			"parameter_list : parameter_list COMMA type_specifier ID",
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
			"parameter_list : parameter_list COMMA type_specifier",
			$$
		);
	}
	;


enter_lcurl : { handle_lcurl(); } ;

compound_statement : 
	LCURL enter_lcurl statements RCURL
	{
		add_code($1, $3->at(0));
		$$ = new vector<SymbolInfo*>({$1});
		$$ = add_vals($$, $3);
		$$->push_back($4);
		rule_match(
			"compound_statement : LCURL statements RCURL",
			$$
		); 
		handle_rcurl();		
	}
	| LCURL enter_lcurl RCURL
	{
		$$ = new vector<SymbolInfo*>({$1, $3});
		rule_match(
			"compound_statement : LCURL RCURL",
			$$
		);
		handle_rcurl();
	}
	| LCURL enter_lcurl error statements  RCURL
	{
		// ERROR RECOVERY : 1st statement is wrong
		$$ = new vector<SymbolInfo*>({$1});
		$$ = add_vals($$, $4);
		$$->push_back($5);
		rule_match(
			"compound_statement : LCURL statements  RCURL",
			$$
		); 
		handle_rcurl();
	}
	| LCURL enter_lcurl statements error RCURL 
	{
		// ERROR RECOVERY : last statement is wrong
		$$ = new vector<SymbolInfo*>({$1});
		$$ = add_vals($$, $3);
		$$->push_back($5);
		rule_match(
			"compound_statement : LCURL statements RCURL",
			$$
		); 
		handle_rcurl();
	}
	| LCURL enter_lcurl error RCURL
	{
		// ERROR RECOVERY : only wrong statement
		// yyclearin;
		// yyerrok;
		$$ = new vector<SymbolInfo*>({$1, $4});
		rule_match(
			"compound_statement : LCURL statements RCURL",
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
	| type_specifier declaration_list error SEMICOLON
	{
		// ERROR RECOVERY : for error before semicolon and after declaration_list
		// error handling
		// handle variable void error here : according to sample io
		if($1->at(0)->getType() == "VOID") print_error("Variable type cannot be void"); 

		$$ = add_vals($1, $2);
		$$->push_back($4);
		rule_match("var_declaration : type_specifier declaration_list SEMICOLON", $$);
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

		$3->symbol = $3->name + "_" + to_string(scope_id); // format name_current scope
		init_vars += "\t" + $3->symbol + " dw ?\n";	
		init_vars_list->push_back($3->symbol);

		$$ = add_vals($1, new vector<SymbolInfo*>({$2, $3}));
		insert_vars($3, var_type); 
		rule_match("declaration_list : declaration_list COMMA ID", $$);	
	}
	| declaration_list COMMA ID LTHIRD CONST_INT RTHIRD
	{
		// error handling : insert_vars errors
		$3->value_type = "ARRAY";
		
		$3->symbol = $3->name + "_" + to_string(scope_id); // format name_current scope
		init_vars += "\t" + $3->symbol + " dw " + $5->name + " dup(?)\n";
		init_vars_list->push_back($3->symbol);

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

		$1->symbol = $1->name + "_" + to_string(scope_id); // format name_current scope
		init_vars += "\t" + $1->symbol + " dw ?\n";
		init_vars_list->push_back($1->symbol);

		$$ = new vector<SymbolInfo*>({$1});
		insert_vars($1, var_type);  
		rule_match("declaration_list : ID", $$); 
	}
	| ID LTHIRD CONST_INT RTHIRD 
	{
		// error handling : insert_vars errors
		$1->value_type = "ARRAY";

		$1->symbol = $1->name + "_" + to_string(scope_id); // format name_current scope
		init_vars += "\t" + $1->symbol + " dw " + $3->name + " dup(?)\n";
		init_vars_list->push_back($1->symbol);

		$$ = new vector<SymbolInfo*>({$1, $2, $3, $4}); 
		insert_vars($1, var_type); 
		rule_match("declaration_list : ID LTHIRD CONST_INT RTHIRD", $$);
	}
	| declaration_list error COMMA ID
	{
		// ERROR RECOVERY : error before comma var
		// error handling : insert_vars errors
		$4->value_type = "VAR";
		$$ = add_vals($1, new vector<SymbolInfo*>({$3, $4}));
		insert_vars($4, var_type); 
		rule_match("declaration_list : declaration_list COMMA ID", $$);
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
			"declaration_list : declaration_list COMMA ID LTHIRD CONST_INT RTHIRD", 
			$$
		);
	}
	| ID LTHIRD CONST_INT error RTHIRD 
	{
		// ERROR RECOVERY
		// error handling : insert_vars errors
		$1->value_type = "ARRAY";
		$$ = new vector<SymbolInfo*>({$1, $2, $3, $5}); 
		insert_vars($1, var_type); 
		rule_match("declaration_list : ID LTHIRD CONST_INT RTHIRD", $$);
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
		add_code($1->at(0), $2->at(0));
		$$ = add_vals($1, $2);
		rule_match(
			"statements : statements statement",
			$$
		);
	}
	| statements error statement
	{
		// ERROR RECOVERY : handle errors between statements
		$$ = add_vals($1, $3);
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
		string value = rule_match(
			"statement : var_declaration",
			$$
		);

		// $$->at(0)->code = "\t;" + value + "\n" + $$->at(0)->code; // no need to show var declaration
	}
	| expression_statement
	{
		$$ = $1;
		string value = rule_match(
			"statement : expression_statement",
			$$
		);

		$$->at(0)->code = "\t;" + value + "\n" + $$->at(0)->code;
	}
	| compound_statement
	{
		$$ = $1;
		string value = rule_match(
			"statement : compound_statement",
			$$
		);

		$$->at(0)->code = "\t;" + value + "\n" + $$->at(0)->code;
	}
	| FOR LPAREN expression_statement expression_statement expression RPAREN statement
	{
		string label_start = newLabel(), label_end = newLabel();
		$1->code = $3->at(0)->code + // initialization
				   label_start + ":\n" +  // start loop
				   $4->at(0)->code + // condition calculate
				   "\tmov ax, " + $4->at(0)->symbol + "\n" // condition eval
				   "\tcmp ax, 0\n"
				   "\tje " + label_end + "\n" + // if false then end loop 
				   $7->at(0)->code + // statement in loop
				   $5->at(0)->code + // change
				   "\tjmp " + label_start + "\n" + // continue loop
				   label_end + ":\n"; // exit
				   


		$$ = new vector<SymbolInfo*>({$1, $2});
		$$ = add_vals($$, $3);
		$$ = add_vals($$, $4);
		$$ = add_vals($$, $5);
		$$->push_back($6);
		$$ = add_vals($$, $7);
		string value = rule_match(
			"statement : FOR LPAREN expression_statement expression_statement expression RPAREN statement",
			$$
		);

		$$->at(0)->code = "\t;" + value + "\n" + $$->at(0)->code;
	}
	| IF LPAREN expression RPAREN statement	%prec LOWER_THAN_ELSE
	{
		string label = newLabel();
		$1->code = $3->at(0)->code + 
				   "\tmov ax, " + $3->at(0)->symbol + "\n"
				   "\tcmp ax, 0\n" // if not true
				   "\tje " + label + "\n" + // jump to end
				   $5->at(0)->code +  // else execute statement
				   label + ":\n";

		$$ = new vector<SymbolInfo*>({$1, $2});
		$$ = add_vals($$, $3);
		$$->push_back($4);
		$$ = add_vals($$, $5);
		string value = rule_match(
			"statement : IF LPAREN expression RPAREN statement",
			$$
		);

		$$->at(0)->code = "\t;" + value + "\n" + $$->at(0)->code;
	}
	| IF LPAREN expression RPAREN statement ELSE statement
	{
		string label_else = newLabel(), label_exit = newLabel();
		$1->code = $3->at(0)->code + 
				   "\tmov ax, " + $3->at(0)->symbol + "\n"
				   "\tcmp ax, 0\n" // if not true
				   "\tje " + label_else + "\n" + // jump to else
				   $5->at(0)->code +  // if conditioned statement
				   "\tjmp " + label_exit + "\n" +// move to exit
				   label_else + ":\n" +
				   $7->at(0)->code +  // else conditioned statement
				   label_exit + ":\n";

		$$ = new vector<SymbolInfo*>({$1, $2});
		$$ = add_vals($$, $3);
		$$->push_back($4);
		$$ = add_vals($$, $5);
		$$->push_back($6);
		$$ = add_vals($$, $7);
		string value = rule_match(
			"statement : IF LPAREN expression RPAREN statement ELSE statement",
			$$
		);

		$$->at(0)->code = "\t;" + value + "\n" + $$->at(0)->code;
	}
	| WHILE LPAREN expression RPAREN statement
	{
		string label1 = newLabel(), label2 = newLabel();
		$1->code = label1 + ":\n" +
				   $3->at(0)->code + // do condition code
				   "\tmov ax, " + $3->at(0)->symbol + "\n"
				   "\tcmp ax, 0\n" // compare
				   "\tje " + label2 + "\n" + // go out of while loop if (false)
				   $5->at(0)->code + // execute statement
				   "\tjmp " + label1 + "\n" + // continue while loop
				   label2 + ":\n";

		$$ = new vector<SymbolInfo*>({$1, $2});
		$$ = add_vals($$, $3);
		$$->push_back($4);
		$$ = add_vals($$, $5);
		string value = rule_match(
			"statement : WHILE LPAREN expression RPAREN statement",
			$$
		);

		$$->at(0)->code = "\t;" + value + "\n" + $$->at(0)->code;
	}
	| PRINTLN LPAREN ID RPAREN SEMICOLON
	{
		// error handling : 
	    // 1: check declaration
		check_var_declared($3);

		$1->code = "\tmov ax, " + $3->symbol + "\n"
				   "\tcall print\n";

		$$ = new vector<SymbolInfo*>({$1, $2, $3, $4, $5});
		string value = rule_match(
			"statement : PRINTLN LPAREN ID RPAREN SEMICOLON",
			$$
		);

		$$->at(0)->code = "\t;" + value + "\n" + $$->at(0)->code;
	}
	| RETURN expression SEMICOLON
	{

		// TODO : now done using temp val
		int len = 0;
		if(cur_param_list != nullptr) len = cur_param_list->size();
		$1->code = $2->at(0)->code + // get statement
				   "\tmov ax, " + $2->at(0)->symbol + "\n" 
				   "\tmov " + return_variable + ", ax\n" // save return value
				   "\tpop di\n\tpop dx\n\tpop cx\n\tpop bx\n\tpop ax\n\tpop bp\n" // pop stack values
				   "\tret " +  to_string(len*2) + "\n"; // return
				   // return needs to be here for recursion function
				   // TODO : but a function can have no return too ??

		$$ = new vector<SymbolInfo*>({$1});
		$$ = add_vals($$, $2);
		$$->push_back($3);
		string value = rule_match(
			"statement : RETURN expression SEMICOLON",
			$$
		);

		$$->at(0)->code = "\t;" + value + "\n" + $$->at(0)->code;
	}
	| func_declaration
	{
		// NEW BONUS
		delete $1; // free memory
		$$ = new vector<SymbolInfo*>();
		print_error("Function declared inside a function");
	}
	| func_definition 
	{
		// NEW BONUS
		delete $1; // free memory
		$$ = new vector<SymbolInfo*>();
		print_error("Function defined inside a function");
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

		$1->code = $3->at(0)->code + "\tmov di, " +$3->at(0)->symbol + "\n"
						             "\tadd di, di\n";

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


		string if_array = "";
		if ($1->at(0)->value_type == "ARRAY") if_array = "[di]"; // saves array index
		$1->at(0)->code += $3->at(0)->code + \
						   "\tmov ax, " + $3->at(0)->symbol + "\n"
						   "\tmov " + $1->at(0)->symbol + if_array + ", ax\n";

		$$ = $1;
		$$->push_back($2);
		$$ = add_vals($$, $3);
		rule_match(
			"expression : variable ASSIGNOP logic_expression",
			$$
		);
	}
	;


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

		add_code($1->at(0), $3->at(0));
		string label1 = newLabel(), label2 = newLabel(), temp = newTemp(), code = ""; 
		if($2->name == "&&"){
			code = "\tcmp " + $1->at(0)->symbol + ", 0\n" // compare 1st element to 0
				   "\tje " + label1 + "\n" // if yes then go to label1
				   "\tcmp " + $3->at(0)->symbol + ", 0\n" // compare 2nd element to 0
				   "\tje " + label1 + "\n" // if yes then go to label1
				   "\tmov " + temp + ", 1\n" // result = true
				   "\tjmp " + label2 + "\n" + // jmp to label2 if 1&&2 = true
				   label1 + ":\n"
				   "\tmov " + temp + ", 0\n" + // 1&&2 = false
				   label2 + ":\n";
		}
		else if($2->name == "||"){
			code = "\tcmp " + $1->at(0)->symbol + ", 0\n" // compare 1st element to 0
				   "\tjne " + label1 + "\n" // if = 1 then go to label1
				   "\tcmp " + $3->at(0)->symbol + ", 0\n" // compare 2nd element to 0
				   "\tjne " + label1 + "\n" // if = 1 then go to label1
				   "\tmov " + temp + ", 0\n" // result = false
				   "\tjmp " + label2 + "\n" + // jmp to label2 if 1||2 = false
				   label1 + ":\n"
				   "\tmov " + temp + ", 1\n" + // 1||2 = true
				   label2 + ":\n";
		}		   

		$1->at(0)->code += code;
		$1->at(0)->symbol = temp;

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

		add_code($1->at(0), $3->at(0));
		string label1 = newLabel(), label2 = newLabel(), temp = newTemp(), code = "";
		code = "\tmov ax, " + $1->at(0)->symbol + "\n" 			// move L.H.S to ax reg
			   "\tcmp ax, " + $3->at(0)->symbol + "\n" +        // compare L.H.S and R.H.S
			   "\t" + get_relop_command($2->name) + " " + label1 + "\n" // if (false) jump to label1
			   "\tmov " + temp + ", 1\n" // result = true
			   "\tjmp " + label2 + "\n" + // jmp to label2 to continue
			   label1 + ":\n"
			   "\tmov " + temp + ", 0\n" + // result = false
			   label2 + ":\n";
		$1->at(0)->code += code;
		$1->at(0)->symbol = temp;
		

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

        add_code($1->at(0), $3->at(0));
		string sign = "";
		if($2->name == "+") sign = "add";
		else if($2->name == "-") sign = "sub"; 
		string temp = newTemp();
		$1->at(0)->code += "\tmov ax, " + $1->at(0)->symbol + "\n"
						  "\t" + sign + " ax, " + $3->at(0)->symbol + "\n"
						  "\tmov " + temp + ", ax\n"; // store score in temp variable
		$1->at(0)->symbol = temp; // store representative variable


		$$ = $1;
		$$->push_back($2);
		$$ = add_vals($$, $3);
		rule_match(
			"simple_expression : simple_expression ADDOP term",
			$$
		);
	}
	;


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

		// TODO : signed or unsigned, for some reason -1, -6, .. shows up when x % 5 == 0 instead of 0, -5
		add_code($1->at(0), $3->at(0));
		string op, temp = newTemp(), result_reg = "ax";		
		// set operation
		if($2->name == "*") op = "\tmul bx\n";
		else if($2->name == "/" || $2->name == "%") {
			op = "\t;check negative\n" // if ax is neg then dx must be 0ffffh
				 "\tcmp ax, 8000h\n"
				 "\tjb dividend_positive\n"
				 "\tmov dx, 0fffh\n" // if neg then dx = 0fffh
				 "\tjmp divop\n"
				 "dividend_positive:\n"
				 "\txor dx, dx\n" // if pos then dx = 0000
				 "divop:\n"
				 "\tdiv bx\n";
		}
		// set destination reg
		if($2->name == "%") result_reg = "dx";
		
		$1->at(0)->code += "\tmov ax, " + $1->at(0)->symbol + "\n"
					       "\tmov bx, " + $3->at(0)->symbol + "\n" +
						   op + // * : DX::AX = AX * BX, ||||||  / : AX = DX::AX / BX and DX = DX::AX % BX
						   "\tmov " + temp + ", " + result_reg + "\n"; 
		$1->at(0)->symbol = temp;

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

		// TODO : checking for negative number here. anything else?
		string temp = newTemp();
		if($1->name == "-") {
			$1->code = $2->at(0)->code + 
					   "\tmov ax, " + $2->at(0)->symbol + "\n" 
					   "\tneg ax\n"
					   "\tmov " + temp + ", ax\n";
			$1->symbol = temp;
		}

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

		$1->code = $2->at(0)->code + 
				   "\tmov ax, " + $2->at(0)->symbol + "\n" + 
				   "\tnot ax\n" + 
				   "\tmov " + newTemp() + ", ax\n";
 
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
		// 1: ID is a defined function or not
		// 2: if parameter no, type, sequence match
		// check if called ID is a function
		SymbolInfo* temp = st->lookUp($1->getName());
		if(temp == nullptr){
			print_error("Undeclared function " + $1->getName());
			$1->return_type = dummy_val;
		}
		else if(!temp->func_defined){
			print_error("Undefined function " + $1->getName());
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

		// get saving variables in stack string for RECURSION
		string push_stack = "", pop_stack = "", temp_str;
		// get declared vars
		for (auto i = init_vars_list->begin(); i != init_vars_list->end(); ++i){
			temp_str = *i;
			push_stack += "\tpush " + temp_str + "\n";
			pop_stack = "\tpop " + temp_str + "\n" + pop_stack; // add in the end to maintain stack nature
		} 
		// get temp vars
		for(int i=0; i<temp_count+1; i++){
			push_stack += "\tpush t_" + to_string(i) + "\n";
			pop_stack = "\tpop t_" + to_string(i) + "\n" + pop_stack;
		}

		string temp_var = newTemp();
		$1->code += push_stack; // push temp vars
		add_code($1, $3->at(0)); // push all arguments to stack code
		$1->code += "\tcall " + $1->name + "\n"; // call the function
		$1->code += pop_stack + // pop temp vars
			     	"\tmov ax, " + return_variable + "\n" // store the return value in new temp var for recursion
					"\tmov " + temp_var + ", ax\n";
		$1->symbol = temp_var; // store return value in ax,
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

		add_code($1, $2->at(0));
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

		$1->symbol = $1->name;

		$$ = new vector<SymbolInfo*>({$1});
		rule_match(
			"factor : CONST_INT",
			$$
		);
	}
	| CONST_FLOAT
	{
		$1->return_type = "FLOAT";

		$1->symbol = $1->name;
		
		$$ = new vector<SymbolInfo*>({$1});
		rule_match(
			"factor : CONST_FLOAT",
			$$
		);
	}
	| variable INCOP 
	{
		// handle postfix
		string temp = newTemp();
		$1->at(0)->code += "\tmov ax, " + $1->at(0)->symbol + "\n"
						   "\tmov " + temp + ", ax\n" 
						   "\tinc "+$1->at(0)->symbol+"\n";
		$1->at(0)->symbol = temp;

		$$ = $1;
		$$->push_back($2);
		rule_match(
			"factor : variable INCOP",
			$$
		);
	}
	| variable DECOP
	{
		
		// handle postfix
		string temp = newTemp();
		$1->at(0)->code += "\tmov ax, " + $1->at(0)->symbol + "\n"
						   "\tmov " + temp + ", ax\n" 
						   "\tdec "+$1->at(0)->symbol+"\n";
		$1->at(0)->symbol = temp;
		
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
		add_code($1->at(0), $3->at(0));
		$1->at(0)->code += $3->at(0)->code + 
						   "\tpush " + $3->at(0)->symbol + "\n"; // push to stack

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
		$1->at(0)->code += "\tpush " + $1->at(0)->symbol + "\n"; // push to stack

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
	st = new SymbolTable(30);
	FILE *fp;
	if((fp=fopen(argv[1],"r"))==NULL)
	{
		printf("Cannot Open Input File.\n");
		exit(1);
	}

	freopen("log.txt", "w", stdout);

	yyin=fp;
	yyparse();
	
	/* cout<<"symbol table:"<<endl; */
	st->printAll();
	cout<<"Total lines: "<<line_count<<endl;
	cout<<"Total errors: "<<error_count<<endl;
	/* fout<<"Total errors: "<<error_count<<endl; */
	fout.close();
	fclose(fp);
	
	
	/* delete yyin; */
	delete st;
	delete cur_param_list;
	
	return 0;
}

