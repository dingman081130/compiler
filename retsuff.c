/*06级计算机科学与技术8班 丁飞( 200631500240 )*/
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <ctype.h>
#include "lex.h"

#define SIZE 30	/*定义队列的大小*/
#define LENGTH 50 /*字符串的最大长度*/

char err_id[] = "error";
char * midexp;

struct YYLVAL {
  char * val;  /* 记录表达式中间临时变量 */
  char * expr; /* 记录表达式前缀式 */
};

typedef struct YYLVAL Yylval;
/*定义队列 用与中缀转换成后缀之用*/
struct QUEUE
{
	char s[SIZE][LENGTH];	/*队列体*/
	int head;	/*队首指针*/
	int tail;	/*队尾指针*/
};

typedef struct QUEUE Queue;

Yylval    *factor     ( void );
Yylval    *term       ( void );
Yylval    *expression ( void );

char *newname( void ); /* 在name.c中定义 */

extern void freename( char *name );

void statements()
{
	/*  statements -> expression SEMI  |  expression SEMI statements  */
	/*指向statement中expression的Yylval结构的指针 包括中间临时变量和后缀表达式*/
	Yylval *temp;
	while( !match(EOI) )	/*如果没从键盘读入文件结束标志*/
	{
		temp = expression();	/*读取一个表达式expression*/
		printf( "该表达式的后缀形式为:  %s\n", temp -> expr );	/*打印该表达式的后缀标识形式*/
		freename( temp -> val );	/*释放中间临时变量名*/
		free( temp );	/*释放temp内存空间*/
		if( match( SEMI ) )	/*表达式读完后*/
			advance();
		else
			fprintf( stderr, "%d: Inserting missing semicolon\n", yylineno );
	}
}

Yylval * expression()
{
	/* expression -> term expression'
	* expression' -> PLUS term expression' |  epsilon
	*/
	Yylval  *temp, *temp2;
	char tmppost[LENGTH];	/*记录后缀表达式*/
	memset( tmppost, 0, sizeof( tmppost ) );
	Queue operate, operand;	/*定义符号队列和操作数队列*/
	operate.head = operand.head = -1;
	operate.tail = operand.tail = -1;
	temp = term();	/*读取一个term*/
	strcpy( operand.s[++operand.tail], temp->expr );	/*将读出的操作数入队*/
	/*若向前查看到操作符'+'或'-' 当前yytext的第一个元素就是该操作符*/
	while( match( PLUS ) || match (MINUS) )
	{
		/*则将该操作符取出*/
		char op = yytext[0];
		if( op == '+' )	/*若是'+'操作*/
			strcpy( operate.s[++operate.tail], "+" );/*将"+"入队*/
		else if( op == '-' )	/*若是'-'操作*/
			strcpy( operate.s[++operate.tail], "-" );/*将"-"入队*/
		else ;
		advance();	/*再向前取一个单词到Lookahead*/
		temp2 = term();	/*读取该操作后的一个term*/
		strcpy( operand.s[++operand.tail], temp2->expr );	/*将读出的操作数入队*/
		printf("    %s %c= %s\n", temp->val, op, temp2->val );
		freename( temp2->val );
		free( temp2 );
	}
	if( operate.tail != -1 )
	{
		while( operate.head != operate.tail )	/*符号队列还不空*/
		{
			memset( tmppost, 0, sizeof( tmppost ) );
			strcat( tmppost, operand.s[++operand.head] );	/*操作数队列出队两个操作数*/
			strcat( tmppost, " " );
			strcat( tmppost, operand.s[++operand.head] );
			strcat( tmppost, " " );
			strcat( tmppost, operate.s[++operate.head] );	/*符号队列一个符号出队*/
			strcat( tmppost, " " );
			strcpy( operand.s[operand.head--], tmppost );/*操作数队列入队一个操作数*/
		}
		memset( temp->expr, '\0', sizeof( temp->expr ) );
		strcpy( temp->expr, tmppost );
	}
	return temp;
}

Yylval * term()
{
	Yylval * temp, * temp2;
	char tmppost[LENGTH];	/*记录前缀表达式*/
	memset( tmppost, 0, sizeof( tmppost ) );
	Queue operate, operand;	/*定义符号队列和操作数队列*/
	operate.head = operand.head = -1;
	operate.tail = operand.tail = -1;
	temp = factor();
	strcpy( operand.s[++operand.tail], temp->expr );	/*将读出的操作数入队*/
	/*若向前查看到操作符'*'或'/' 当前yytext的第一个元素就是该操作符*/
	while( match( TIMES ) || match (DIVISION) )
	{
		char op = yytext[0];
		if( op == '*' )	/*若是'*'操作*/
			strcpy( operate.s[++operate.tail], "*" );/*将"*"入队*/
		else if( op == '/' )	/*若是'/'操作*/
			strcpy( operate.s[++operate.tail], "/" );/*将"/"入队*/
		else ;
		advance();	/*再向前取一个单词到Lookahead*/
		temp2 = factor();	/*读取该操作后的一个factor*/
		strcpy( operand.s[++operand.tail], temp2->expr );	/*将读出的操作数入队*/
		printf("    %s %c= %s\n", temp->val, op, temp2->val );
		freename( temp2->val );
		free( temp2 );
	}
	if( operate.tail != -1 )
	{
		while( operate.head != operate.tail )	/*符号队列还不空*/
		{
			memset( tmppost, 0, sizeof( tmppost ) );
			strcat( tmppost, operand.s[++operand.head] );	/*操作数队列出队两个操作数*/
			strcat( tmppost, " " );
			strcat( tmppost, operand.s[++operand.head] );
			strcat( tmppost, " " );
			strcat( tmppost, operate.s[++operate.head] );	/*符号队列一个符号出队*/
			strcat( tmppost, " " );
			strcpy( operand.s[operand.head--], tmppost );/*操作数队列入队一个操作数*/
		}
		/*指向局部变量的指针不能做返回值*/
		memset( temp->expr, '\0', sizeof( temp->expr ) );
		strcpy( temp->expr, tmppost );
	}
	return temp;
}

/*前缀表达式不需要括号*/
Yylval * factor()
{
	Yylval *temp;
	char * tmpvar, * tmpexpr;
	if( match(NUM_OR_ID) )
	{
		/* 由于yytext不是以'\0'结尾,因此只能打印yyleng长度,用格式控制字符
		* %0.*s, 它将取yyleng作为打印的长度,这也是变长度打印的常用方法
		*/
		tmpvar = newname();
		tmpexpr = ( char * )malloc( yyleng + 1 );

		strncpy( tmpexpr, yytext, yyleng );
		tmpexpr[yyleng] = 0;

		printf("    %s = %s\n", tmpvar, tmpexpr );
		/*一定要动态申请
		指向局部变量的指针绝对不能是返回值*/
		temp = ( Yylval * )malloc( sizeof( Yylval ) );
		temp -> val = tmpvar;
		temp -> expr = tmpexpr;
		advance(); 
	}
	else {
		if( match(LP) )
		{
			advance(); 
			temp = expression();
			if( match(RP) )
				advance();
			else
				fprintf(stderr, "%d: Mismatched parenthesis\n", yylineno );
		}
		else	/*如果factor是合法的 就正常赋值给的后缀表达式 如果非法 则用error_id代替*/
		{
			char * s;
			advance();
			s = ( char * )malloc( 10 );
			strcpy( s, "error_id" );
			fprintf(stderr, "%d: Mismatched parenthesis\n", yylineno );
			temp = ( Yylval * )malloc( sizeof( Yylval ) );
			temp -> val = newname();
			temp -> expr = s;
		}
	}
	return temp;	/*temp是手工分配的 所以函数返回后内存空间依然存在*/
}
/*06级计算机科学与技术8班 丁飞( 200631500240 )*/
