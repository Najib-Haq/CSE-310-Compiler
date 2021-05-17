#include<bits/stdc++.h>

using namespace std;

//////////////////////// SYMBOLINFO ///////////////////////////////////////
class SymbolInfo{
    string name;
    string type;
    SymbolInfo* next;

public:
    SymbolInfo(string name, string type){
        this->name = name;
        this->type = type;
        this->next = nullptr;
    }
    ~SymbolInfo() { this->next = nullptr; }

    string getName() { return this->name; }
    string getType() { return this->type; }
    SymbolInfo* getNext() { return this->next; }

    void setName(string name)  { this->name = name; }
    void setType(string type)  { this->type = type; }
    void setNext(SymbolInfo* next) { this->next = next; }

    bool equal(string symbol) {
        if(this->name == symbol) return true;
        else return false;
    }
};


//////////////////////// SCOPETABLE ///////////////////////////////////////
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

// define functions of ScopeTable
ScopeTable::ScopeTable(int total_buckets){
    this->total_buckets = total_buckets;
    this->symbols = new SymbolInfo*[total_buckets];
    for(int i=0; i<total_buckets; i++) symbols[i] = nullptr; // initialize with null pointer
    this->parentScope = nullptr;
    this->id = "";
}

ScopeTable::ScopeTable(int total_buckets, string ID, ScopeTable* parent){
    this->total_buckets = total_buckets;
    this->symbols = new SymbolInfo*[total_buckets];
    for(int i=0; i<total_buckets; i++) symbols[i] = nullptr; // initialize with null pointer
    this->parentScope = parent;
    this->id = ID;
}

ScopeTable::~ScopeTable(){
    SymbolInfo* temp;
    SymbolInfo* next;
    for(int i=0; i<total_buckets; i++){
        // delete individual symbolInfo
        if(this->symbols[i] != nullptr) {
            temp = this->symbols[i];
            while(temp != nullptr){
                // cout<<"Deleting "<<i<<" : "<<temp->getName()<<endl;
                next = temp->getNext();
                delete temp;
                temp = next;
            } 
        }
    }
    // delete the array
    delete[] this->symbols;
}

int ScopeTable::hash(string name){
    int sum = 0;
    for(int i=0; i<name.size(); i++) sum += int(name[i]); // get ascii values of char
    // cout<<"Hash is : "<<sum % this->total_buckets<<endl;
    return sum % this->total_buckets;
}

SymbolInfo* ScopeTable::lookUp(string symbol){
    // get hash value
    int index = this->hash(symbol);
    SymbolInfo* temp = this->symbols[index];
    int chainIndex = 0;
    while(temp != nullptr){
        if(temp->equal(symbol)) {
            cout<<"Found in ScopeTable# "<<this->id
                <<" at position "<<index<<", "<<chainIndex<<endl;
            return temp; 
        }
        temp = temp->getNext();
        chainIndex += 1;
    }
    return temp;
}

bool ScopeTable::insert(SymbolInfo* symbol){
    // get hash value
    int index = this->hash(symbol->getName());
    int insertIndex = 0;

    SymbolInfo* temp = this->symbols[index];

    // search for free space
    // first element in index
    if(temp == nullptr) this->symbols[index] = symbol;
    else{
        // chaining
        while(true){
            insertIndex += 1;
            // if equal to some other symbol dont insert
            if(temp->equal(symbol->getName())) {
                cout<<"<"<<symbol->getName()<<","<<symbol->getType()
                    <<"> already exists in current ScopeTable"<<endl;
                return false;
            }
            // if next free then insert
            if(temp->getNext() == nullptr){
                temp->setNext(symbol);
                break;
            }
            temp = temp->getNext();
        }
    }

    cout<<"Inserted in ScopeTable# "<<this->id
        <<" at position "<<index<<", "<<insertIndex<<endl;
    return true;
}

bool ScopeTable::deleteSymbol(string symbol){
    // get hash value
    int index = this->hash(symbol);
    int insertIndex = 0;
    SymbolInfo* place = this->symbols[index];
    SymbolInfo* temp = nullptr;
    while(place != nullptr){
        if(place->equal(symbol)){
            // if place is first element
            if(temp == nullptr) this->symbols[index] = place->getNext();
            else temp->setNext(place->getNext());

            delete place; 

            cout<<"Deleted Entry "<<index<<", "<<insertIndex
                <<" from current ScopeTable"<<endl;
            return true; // deleted
        }
        else {
            temp = place;
            place = place->getNext();
            insertIndex += 1;
        } 
    }

    cout<<symbol<<" not found"<<endl;
    return false; // nullpointer means symbol doesnt exist
}

void ScopeTable::print(){
    // print id
    cout<<"ScopeTable # "<<this->id<<endl;
    // print contents
    SymbolInfo* symbolList;
    for(int i=0; i<this->total_buckets; i++){
        cout<<i<<" --> ";
        symbolList = this->symbols[i];
        while(symbolList != nullptr){
            cout<<"< "<<symbolList->getName()<<" : "<<symbolList->getType()<<" > ";
            symbolList = symbolList->getNext();
        }
        cout<<endl;
    }
}


//////////////////////// SYMBOLTABLE ///////////////////////////////////////
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
    bool insert(SymbolInfo* symbol);
    bool remove(string symbol);
    SymbolInfo* lookUp(string symbol);
    void printCurr();
    void printAll();
};

SymbolTable::SymbolTable(int buckets){
    this->currTable = new ScopeTable(
        buckets, 
        "1", 
        nullptr
    );
    this->total_buckets = buckets;
    this->curr_id = 1;
}

SymbolTable::~SymbolTable(){
    ScopeTable* temp;
    while(this->currTable != nullptr){
        temp = this->currTable;
        this->currTable = temp->getParentScope();
        // cout<<"Deleting Table id : "<<temp->getID()<<endl;
        delete temp;
    }
}

string SymbolTable::getName(){
    string id = "";
    if(this->currTable != nullptr) id += this->currTable->getID() + ".";
    return  id + to_string(this->curr_id);
}

int SymbolTable::trackId(){
    string lastName = this->currTable->getID();
    int index = lastName.find_last_of(".");
    return stoi(lastName.substr(index+1)) + 1;
}

void SymbolTable::enterScope(){
    ScopeTable* newTable = new ScopeTable(
        this->total_buckets, 
        this->getName(), 
        this->currTable
    );
    this->currTable = newTable;
    this->curr_id = 1; // if new created then next will be new too
    cout<<"New ScopeTable with id "<<newTable->getID()<<" created"<<endl;
}

void SymbolTable::exitScope(){
    if(this->currTable == nullptr) return; 
    this->curr_id = this->trackId();
    ScopeTable* temp = this->currTable;
    cout<<"ScopeTable with id "<<temp->getID()<<" removed"<<endl;
    this->currTable = this->currTable->getParentScope();
    delete temp;
}

bool SymbolTable::insert(SymbolInfo* symbol){
    if(this->currTable != nullptr){
        return this->currTable->insert(symbol);
    }
    else return false;
    
}

bool SymbolTable::remove(string symbol){
    if(this->currTable != nullptr){
        return this->currTable->deleteSymbol(symbol);
    }
    else return false;
    
}

SymbolInfo* SymbolTable::lookUp(string symbol){
    if(this->currTable == nullptr) return nullptr;

    SymbolInfo* temp = this->currTable->lookUp(symbol);
    ScopeTable* tempTable = this->currTable->getParentScope();
    // if not found search all parent tables
    while(temp == nullptr){
        if(tempTable == nullptr) {
            cout<<"Not found"<<endl;
            return nullptr;
        }
        temp = tempTable->lookUp(symbol);
        tempTable = tempTable->getParentScope();
    }
    return temp;
}

void SymbolTable::printCurr(){
    if(this->currTable != nullptr) this->currTable->print();
}

void SymbolTable::printAll(){
    ScopeTable* temp = this->currTable;
    while(temp != nullptr){
        temp->print();
        cout<<endl;
        temp = temp->getParentScope();
    }
}



////////////////////////////// MAIN ////////////////////////////////
void io(){
    int buckets;
    char command;
    string str1, str2;
    cin>>buckets;
    SymbolTable* st = new SymbolTable(buckets);

    while(true){
        cin>>command;
        if(cin.eof()) break; // finish reading file
        cout<<command<<" "; 

        // insert
        if(command == 'I'){
            cin>>str1; // symbol name
            cin>>str2; // symbol type
            cout<<str1<<" "<<str2<<"\n\n";
            st->insert(new SymbolInfo(str1, str2));
        }

        // lookup
        else if(command == 'L'){
            cin>>str1; // symbol name
            cout<<str1<<"\n\n";
            st->lookUp(str1);
        }

        // delete
        else if(command == 'D'){
            cin>>str1; // symbol name
            cout<<str1<<"\n\n";
            st->remove(str1);
        }

        // print
        else if(command == 'P'){
            cin>>str1;
            cout<<str1<<"\n\n";
            if(str1 == "A") st->printAll();
            else if(str1 == "C") st->printCurr();
        }

        // enter new scope
        else if(command == 'S') {
            cout<<"\n\n";
            st->enterScope();
        }
        
        // exit curr scope
        else if(command == 'E') {
            cout<<"\n\n";
            st->exitScope();
        }

        cout<<"\n";
    }
    delete st;
}


int main(){
    // read write from files
    freopen("input.txt", "r", stdin);
    freopen("output.txt", "w", stdout);

    io(); // principle function
    return 0;
}