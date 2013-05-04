%{
#include<stdio.h>
#include<math.h>
#include<ctype.h>

typedef struct{
	char * affix;	/*记录综合属性affix或者继承属性in*/
	char op;		/*记录前符号属性op*/
} semantic_value;
#define YYSTYPE semantic_value

extern char * yytext;
extern int yylex();

%}
%token NUM_OR_ID
%left '+'
%left '*'
%%
input:	/*空串*/
	| input line
	;

line:	'\n'
	| exp_s '\n'
	;

exp_s:	exp	{
			$$.affix = $1.affix;
			printf( "\n*** 前缀表达式为:\n" );
			printf( "*** %s\n", $$.affix );
			printf( "*****************************************\n\n" );
		}
	;

exp:	term '+' {
					$$.op = '+';
					if( $0.op == '+' )
					{
						char * s;
						if( !$0.affix )
							$0.affix = "";
						s = ( char * )malloc( strlen( $0.affix ) + strlen( $1.affix ) + 4 );
						sprintf( s, "+ %s %s", $0.affix, $1.affix );
						$$.affix = s;
					}
					else
					{
						char * s = ( char * )malloc( strlen( $1.affix ) + 1 );
						sprintf( s, "%s", $1.affix );
						$$.affix = s;
					}
					
				} exp {
					char * s;
					$$.op = $0.op;
					s = ( char * )malloc( strlen( $4.affix ) + 1 );
					sprintf( s, "%s", $4.affix );
					$$.affix = s;
				}
	| term		{
					$$.op = $0.op;
					if( $$.op == '+' )
					{
						char * s;
						if( !$0.affix )
							$0.affix = "";	/*不存在则补空串*/
						s = ( char * )malloc( strlen( $0.affix ) + strlen( $1.affix ) + 4 );	
						sprintf( s, "+ %s %s", $0.affix, $1.affix );
						$$.affix = s;
					}
					else
					{
						char * s = ( char * )malloc( strlen( $1.affix ) + 1 );
						sprintf( s, "%s", $1.affix );
						$$.affix = s;
					}
				}
	;

term:	factor '*' {
						$$.op = '*';
						if( $0.op == '*' )
						{
							char * s;
							if( !$0.affix )
								$0.affix = "";	/*不存在则补空串*/
							s = ( char * )malloc( strlen( $0.affix ) + strlen( $1.affix ) + 4 );
							sprintf( s, "* %s %s", $0.affix, $1.affix );
							$$.affix = s;
						}
						else
						{
							char * s = ( char * )malloc( strlen( $1.affix ) + 1 );
							sprintf( s, "%s", $1.affix );
							$$.affix = s;
						}
				}term {
						char * s;
						$$.op = $0.op;
						s = ( char * )malloc( strlen( $4.affix ) + 1 );
						sprintf( s, "%s", $4.affix );
						$$.affix = s;
				}
	| factor	{
					$$.op = $0.op;
					if( $$.op == '*' )
					{
						char * s;
						if( !$0.affix )
							$0.affix = "";	/*不存在则补空串*/
						s = ( char * )malloc( strlen( $0.affix ) + strlen( $1.affix ) + 4 );
						sprintf( s, "* %s %s", $0.affix, $1.affix );
						$$.affix = s;
					}
					else
					{
						char * s = ( char * )malloc( strlen( $1.affix ) + 1 );
						sprintf( s, "%s", $1.affix );
						$$.affix = s;
					}
			}
	;

factor:	NUM_OR_ID	{
				char * s = ( char * )malloc( strlen( yytext ) + 1 );
				sprintf( s, "%s", yytext );
				$$.affix = s;
			}
	| '(' exp ')'	{
				char * s = ( char * )malloc( strlen( $2.affix ) + 1 );
				sprintf( s, "%s", $2.affix );
				$$.affix = s;
			}
	;

%%
main()
{
	yyparse();
}

yyerror( s )
char * s;
{
	printf( "%s\n", s );
}