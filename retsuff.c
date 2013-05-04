/*06���������ѧ�뼼��8�� ����( 200631500240 )*/
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <ctype.h>
#include "lex.h"

#define SIZE 30	/*������еĴ�С*/
#define LENGTH 50 /*�ַ�������󳤶�*/

char err_id[] = "error";
char * midexp;

struct YYLVAL {
  char * val;  /* ��¼���ʽ�м���ʱ���� */
  char * expr; /* ��¼���ʽǰ׺ʽ */
};

typedef struct YYLVAL Yylval;
/*������� ������׺ת���ɺ�׺֮��*/
struct QUEUE
{
	char s[SIZE][LENGTH];	/*������*/
	int head;	/*����ָ��*/
	int tail;	/*��βָ��*/
};

typedef struct QUEUE Queue;

Yylval    *factor     ( void );
Yylval    *term       ( void );
Yylval    *expression ( void );

char *newname( void ); /* ��name.c�ж��� */

extern void freename( char *name );

void statements()
{
	/*  statements -> expression SEMI  |  expression SEMI statements  */
	/*ָ��statement��expression��Yylval�ṹ��ָ�� �����м���ʱ�����ͺ�׺���ʽ*/
	Yylval *temp;
	while( !match(EOI) )	/*���û�Ӽ��̶����ļ�������־*/
	{
		temp = expression();	/*��ȡһ�����ʽexpression*/
		printf( "�ñ��ʽ�ĺ�׺��ʽΪ:  %s\n", temp -> expr );	/*��ӡ�ñ��ʽ�ĺ�׺��ʶ��ʽ*/
		freename( temp -> val );	/*�ͷ��м���ʱ������*/
		free( temp );	/*�ͷ�temp�ڴ�ռ�*/
		if( match( SEMI ) )	/*���ʽ�����*/
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
	char tmppost[LENGTH];	/*��¼��׺���ʽ*/
	memset( tmppost, 0, sizeof( tmppost ) );
	Queue operate, operand;	/*������Ŷ��кͲ���������*/
	operate.head = operand.head = -1;
	operate.tail = operand.tail = -1;
	temp = term();	/*��ȡһ��term*/
	strcpy( operand.s[++operand.tail], temp->expr );	/*�������Ĳ��������*/
	/*����ǰ�鿴��������'+'��'-' ��ǰyytext�ĵ�һ��Ԫ�ؾ��Ǹò�����*/
	while( match( PLUS ) || match (MINUS) )
	{
		/*�򽫸ò�����ȡ��*/
		char op = yytext[0];
		if( op == '+' )	/*����'+'����*/
			strcpy( operate.s[++operate.tail], "+" );/*��"+"���*/
		else if( op == '-' )	/*����'-'����*/
			strcpy( operate.s[++operate.tail], "-" );/*��"-"���*/
		else ;
		advance();	/*����ǰȡһ�����ʵ�Lookahead*/
		temp2 = term();	/*��ȡ�ò������һ��term*/
		strcpy( operand.s[++operand.tail], temp2->expr );	/*�������Ĳ��������*/
		printf("    %s %c= %s\n", temp->val, op, temp2->val );
		freename( temp2->val );
		free( temp2 );
	}
	if( operate.tail != -1 )
	{
		while( operate.head != operate.tail )	/*���Ŷ��л�����*/
		{
			memset( tmppost, 0, sizeof( tmppost ) );
			strcat( tmppost, operand.s[++operand.head] );	/*���������г�������������*/
			strcat( tmppost, " " );
			strcat( tmppost, operand.s[++operand.head] );
			strcat( tmppost, " " );
			strcat( tmppost, operate.s[++operate.head] );	/*���Ŷ���һ�����ų���*/
			strcat( tmppost, " " );
			strcpy( operand.s[operand.head--], tmppost );/*�������������һ��������*/
		}
		memset( temp->expr, '\0', sizeof( temp->expr ) );
		strcpy( temp->expr, tmppost );
	}
	return temp;
}

Yylval * term()
{
	Yylval * temp, * temp2;
	char tmppost[LENGTH];	/*��¼ǰ׺���ʽ*/
	memset( tmppost, 0, sizeof( tmppost ) );
	Queue operate, operand;	/*������Ŷ��кͲ���������*/
	operate.head = operand.head = -1;
	operate.tail = operand.tail = -1;
	temp = factor();
	strcpy( operand.s[++operand.tail], temp->expr );	/*�������Ĳ��������*/
	/*����ǰ�鿴��������'*'��'/' ��ǰyytext�ĵ�һ��Ԫ�ؾ��Ǹò�����*/
	while( match( TIMES ) || match (DIVISION) )
	{
		char op = yytext[0];
		if( op == '*' )	/*����'*'����*/
			strcpy( operate.s[++operate.tail], "*" );/*��"*"���*/
		else if( op == '/' )	/*����'/'����*/
			strcpy( operate.s[++operate.tail], "/" );/*��"/"���*/
		else ;
		advance();	/*����ǰȡһ�����ʵ�Lookahead*/
		temp2 = factor();	/*��ȡ�ò������һ��factor*/
		strcpy( operand.s[++operand.tail], temp2->expr );	/*�������Ĳ��������*/
		printf("    %s %c= %s\n", temp->val, op, temp2->val );
		freename( temp2->val );
		free( temp2 );
	}
	if( operate.tail != -1 )
	{
		while( operate.head != operate.tail )	/*���Ŷ��л�����*/
		{
			memset( tmppost, 0, sizeof( tmppost ) );
			strcat( tmppost, operand.s[++operand.head] );	/*���������г�������������*/
			strcat( tmppost, " " );
			strcat( tmppost, operand.s[++operand.head] );
			strcat( tmppost, " " );
			strcat( tmppost, operate.s[++operate.head] );	/*���Ŷ���һ�����ų���*/
			strcat( tmppost, " " );
			strcpy( operand.s[operand.head--], tmppost );/*�������������һ��������*/
		}
		/*ָ��ֲ�������ָ�벻��������ֵ*/
		memset( temp->expr, '\0', sizeof( temp->expr ) );
		strcpy( temp->expr, tmppost );
	}
	return temp;
}

/*ǰ׺���ʽ����Ҫ����*/
Yylval * factor()
{
	Yylval *temp;
	char * tmpvar, * tmpexpr;
	if( match(NUM_OR_ID) )
	{
		/* ����yytext������'\0'��β,���ֻ�ܴ�ӡyyleng����,�ø�ʽ�����ַ�
		* %0.*s, ����ȡyyleng��Ϊ��ӡ�ĳ���,��Ҳ�Ǳ䳤�ȴ�ӡ�ĳ��÷���
		*/
		tmpvar = newname();
		tmpexpr = ( char * )malloc( yyleng + 1 );

		strncpy( tmpexpr, yytext, yyleng );
		tmpexpr[yyleng] = 0;

		printf("    %s = %s\n", tmpvar, tmpexpr );
		/*һ��Ҫ��̬����
		ָ��ֲ�������ָ����Բ����Ƿ���ֵ*/
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
		else	/*���factor�ǺϷ��� ��������ֵ���ĺ�׺���ʽ ����Ƿ� ����error_id����*/
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
	return temp;	/*temp���ֹ������ ���Ժ������غ��ڴ�ռ���Ȼ����*/
}
/*06���������ѧ�뼼��8�� ����( 200631500240 )*/
