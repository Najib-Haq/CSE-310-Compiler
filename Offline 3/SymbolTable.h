#ifndef HEADER_H_     // equivalently, #if !defined HEADER_H_
#define HEADER_H_

#include<bits/stdc++.h>
using namespace std;


class SymbolInfo{
    string name;
    string type;
    SymbolInfo* next;

public:
    // extra info
    string value_type; // store VAR, FUNC, ARRAY
    string return_type; // store INT, FLOAT, CHAR, VOID
    bool func_defined; // whether func is defined
    vector<SymbolInfo*>* param_list; // for function parameters

    SymbolInfo(SymbolInfo* copy){
        this->copyValues(copy);
    } 

    SymbolInfo(string name, string type){
        this->name = name;
        this->type = type;
        this->next = nullptr;
        this->value_type = "";
        this->return_type = "";
        this->param_list = nullptr;
    }

    SymbolInfo(string name, string type, string value_type, string return_type){
        this->name = name;
        this->type = type;
        this->next = nullptr;
        this->value_type = value_type;
        this->return_type = return_type;
        this->param_list = nullptr;
    }

    ~SymbolInfo() { 
        this->next = nullptr;
        // cout<<"Deleting sinfo "<<this->name<<" : "<<endl;
        if(this->param_list != nullptr) {
            // this->param_list->at(0)->printInfo();
            // for(int i=0; i<this->param_list->size(); i++){
            //     cout<<"deleting : "<<this->param_list->at(i)->name<<endl;
            // }
            delete this->param_list;
        }
    }

    string getName() { return this->name; }
    string getType() { return this->type; }
    SymbolInfo* getNext() { return this->next; }

    void setName(string name)  { this->name = name; }
    void setType(string type)  { this->type = type; }
    void setNext(SymbolInfo* next) { this->next = next; }

    bool equal(string symbol){
        if(this->name == symbol) return true;
        else return false;
    }

    void add_func_info(string value_type, string return_type, vector<SymbolInfo*>* param_list,
                       bool func_defined){
        this->value_type = value_type;
        this->return_type = return_type;
        this->param_list = param_list;
        this->func_defined = func_defined;
    }

    void printInfo(){
        cout<<"Name : "<<this->name<<endl;
        cout<<"Type : "<<this->type<<endl;
        cout<<"Value type: "<<this->value_type<<endl;
        cout<<"Return type: "<<this->return_type<<endl;  

        string param_name, param_type;
        if(this->param_list != nullptr){
            for(int i = 0; i < this->param_list->size(); i++ ){
                param_name = this->param_list->at(i)->getName();
                param_type = this->param_list->at(i)->return_type;
                cout<<param_type<<" : "<<param_name<<endl;
            }   
        }
    }

    void copyValues(SymbolInfo* copy){
        this->name = copy->name;
        this->type = copy->type;
        this->next = copy->next;
        this->value_type = copy->value_type;
        this->return_type = copy->return_type;
        this->param_list = copy->param_list;
        this->func_defined = copy->func_defined;
    }
};


class ScopeTable{
    SymbolInfo** symbols; // act as array for SymbolInfo objects
    ScopeTable* parentScope; // to maintain list of ScopeTables in SymbolTable
    int total_buckets; // size of initial array
    string id; // unique id for table, <parent_id>.<curr_id>

public:
    ScopeTable(int total_buckets);
    ScopeTable(int total_buckets, string ID, ScopeTable* parent);
    ~ScopeTable();

    // helpers
    ScopeTable* getParentScope() { return this->parentScope; }
    string getID() { return this->id; }
    void setParentScope(ScopeTable* parent) { this->parentScope = parent; }
    void setID(string ID) { this->id = ID; }
    int hash(string name);

    // functions required 
    bool insert(SymbolInfo* symbol);
    SymbolInfo* lookUp(string symbol); 
    bool deleteSymbol(string symbol);
    void print();
};

class SymbolTable{
    ScopeTable* currTable; // to get current ScopeTable
    int curr_id;
    int total_buckets;
    
public:
    SymbolTable(int buckets);
    ~SymbolTable();

    // helpers
    string getName();
    int trackId();

    // functions required
    void enterScope();
    void exitScope();
    bool insert(SymbolInfo* sinfo);
    bool remove(string symbol);
    SymbolInfo* lookUp(string symbol);
    void printCurr();
    void printAll();
};

#endif
