# chmod +x script.sh for first run
yacc -d -y -v 1705044.y 
echo '1'  
g++ -w -c -o y.o y.tab.c
echo '2'
flex 1705044.l		
echo '3'
g++ -w -c -o l.o lex.yy.c
echo '4'
g++ SymbolTable.cpp -c
g++ SymbolTable.o y.o l.o -lfl
echo '5'
./a.out $1
