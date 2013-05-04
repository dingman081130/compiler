%{
/* Copyright hanfei.wang@gmail.com 2009.03.31 */

#include <string.h>
#include "token.h"
#include "xml_tree.h"

extern Xml_tree * yylval;	/*声明指向树结点的外部变量 在parser.c文件中定义*/
static char * stag_name ;
/*
 * By W3CExtensible Markup Language (XML) 1.0 (Third Edition)
 * (http://www.w3.org/TR/2004/REC-xml-20040204/)
 * There are tree form of TAG:
 * 
 * 1/ Start Tag:   '<' Name (S Attribute)* S? '>'  
 * 2/ End Tag:    '</' Name S? '>'
 * 3/ Empty-Element Tags:   '<' Name (S Attribute)* S? '/>'
 *
 * Because Empty-Element Tags  are not balanced, 
 * we will trait Empty-Element Tags as a pair of
 * STAG & ETAG. ie. if the scanner see <link a="b"/>,
 * it will return an STAG just as <link a="b"> and unput
 * an ETAG </link> back to input bufffer and make EMPTY
 * in the Xml_tree node 
 */    

%}
%option yylineno
%x doctype
%x comment
%x stag
%x inlinedtd

%%

"<!DOCTYPE"  BEGIN(doctype)    ;/* Skip DTD Section */

<doctype>"[" BEGIN(inlinedtd)  ;
<doctype>">" BEGIN(INITIAL)    ;
<doctype>[^>]                  ;

<inlinedtd>"]" BEGIN(doctype)  ;
<inlinedtd>[^\]]               ;    


"<!--"    BEGIN(comment)         ;/*Skip comment Section*/
<comment>"-->"    BEGIN(INITIAL) ;
<comment>.|\n ;


"<"[^/!?][^\t >\n\r/]* {
		stag_name = (char *) malloc( yyleng );
		if ( yytext[2] == '>' )
			Error( "Empty start tag at line %d!", yylineno );
 
		strcpy( stag_name, yytext + 1 );	/* 去掉'<'字符 将纯标签名存入stag_name中 */
		BEGIN( stag );
	}

<stag>[^>]*">" { 
		/* for STAG and Empty-Element Tags */
		char * att_list;
		int tag_type = ELEMENT;

		if (yyleng == 1)	/*无属性ELEMENT标签*/
			att_list = NULL;
		else if ( yytext[yyleng -2] == '/' ) {	/*属性不为空且为EMPTY型标签*/
			int i;
			att_list = ( char * ) malloc( yyleng );
			strncpy ( att_list, yytext, yyleng -2 );	/*去掉匹配字符串后的'/'和'>' 将剩余提取部分赋给att_list*/
			att_list[yyleng -2] = 0;
			unput('>');	/*回退字符串'</stag_name>'到输入 使EMPTY标签拆分为一对ELEMENT标签*/
			for ( i = strlen( stag_name ) -1; i >= 0; i-- )
				unput(stag_name[i]);
			unput ('/'); unput ('<');
			tag_type = EMPTY;
		} else {
			att_list = ( char * ) malloc ( yyleng );
			strncpy ( att_list, yytext, yyleng - 1 );
			att_list[yyleng-1] = 0;
		}
 
		yylval = make_node ( tag_type, stag_name, att_list, yylineno );/*为开始标签创建一个节点*/
  
		/*  printf("%s %s\n", stag_name, att_list); */
		BEGIN(INITIAL);
		return STAG; 
	}

"</"[^>]*">"   {
		/* End Tag */
		/* 请完成！*/ 
		char * att_list = NULL;	/*结束标签里 属性列表始终为空*/
		int tag_type = ELEMENT;	/*结束标签一定为ELEMENT型*/
		stag_name = (  char * )malloc( yyleng );
		strncpy( stag_name, yytext + 2, yyleng - 3 );	/*存标签名 只要文本不要</>等字符*/
		stag_name[yyleng - 3] = 0;
		yylval = make_node( tag_type, stag_name, att_list, yylineno );
		return ETAG;
	}

(" "|\t)+   ;	/*顶行*/

([^<\n \t][^<\n]*)|("<?"[^<?]+"?>")|("<![CDATA["([^\]]+"]"|[^\]])*"]]>")  {
		/* TEXT */
		/* 请完成！*/
		int tag_type = PCDATA;/*文本*/
		char * att_list;
		stag_name = NULL;/*标签名空*/
		att_list = ( char * )malloc( yyleng );
		strcpy( att_list, yytext );	/*文本存入属性列表里*/
		yylval = make_node( tag_type, stag_name, att_list, yylineno );
		return TEXT;
	}

">" ;

\n      /* printf("%s" , yytext)*/;

%%


int yywrap()

{
        return 1;
}