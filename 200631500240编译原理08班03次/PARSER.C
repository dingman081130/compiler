/* Copyright hanfei.wang@gmail.com 2009.03.31 */

#include "xml_tree.h"
#include "token.h"
extern int yylineno;	/*声明外部变量 yylineno 由flex xml.l生成*/
extern int yylex();	/*声明外部变量 yylex() 由flex xml.l生成*/
/*定义全局变量 存储识别token后所创建的xml_tree结点指针 在xml.l文件中声明为外部变量*/
Xml_tree * yylval;

static lookahead = -1;

int match(int token)
{
	if (lookahead == -1)
		lookahead = yylex();
	return token == lookahead;
}

int advance()
{
	lookahead = yylex();
	return lookahead;
}


/*
 * XML Grammar:
 * tag_list -> STAG tag_list ETAG tag_list
 *          |  TEXT tag_list
 *          |  Epsilon
 */

List * tag_list()
{
	List * list = NULL;

	if( match( STAG ) )
	{
		list = make_list( yylval );	//匹配到开始标签
		advance();
		add_child( list, tag_list() ); //添加孩子
		if( strcmp( yylval->tag_name, list->node->tag_name ) != 0 )	//处理标签不匹配问题
		{
			printf( "发生标签不匹配问题，在.xml文件中%d行的%s标签与在%d行%s标签不匹配！\n", 
				yylval->lineno, yylval->tag_name, list->node->lineno, list->node->tag_name );
			exit( 0 );
		}
		advance();
		add_list( list, tag_list() );	//添加同级标签
	}
	else if( match( TEXT ) )
	{
		list = make_list( yylval );
		advance();
		add_list( list, tag_list() );
	}
	else if( match( ETAG ) )	//匹配到结束标签 直接返回空
		;
	return list;
}


int main()
{
	List * root;	/*定义语义树根结点*/
	root = tag_list();	/*递归下降分析返回根结点*/
	print_tree(0, root); /*打印树到屏幕*/
	return 0;
}
