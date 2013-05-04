%{
/* control flow translation using backpatching 
	(C) hanfei.wang@gmail.com  
         2009.05.20      			
                  
  supports:
  
  1/ if then else
  2/ switch case
  3/ while do
  4/ repeat until
  5/ for i := e to e do 
  6/ break and continue in loop structure.
  7/ function call in expression
  8/ boolean expression translates in control flow 
  9/ array element

*/

#include <stdio.h>
#include <ctype.h>
#include <malloc.h> 

char last_mark [] = "last";

extern char *yytext;         /* Lexeme, In yylex()     当前识别的字符串 在control.l中定义      */
char *new_label( void );
char *new_name  ( void    );  
void free_name  ( char *s );

typedef struct code {
  char * code;     
  char * label; /* for goto label, used also 
                   for backpatching list pointer */
  struct code * next;
} CODE;	/*链式结构*/
 
typedef struct att {
  CODE * true_list;      /* For E.truelist and S.nextlist */
  CODE * false_list;
  CODE * code;      
  CODE * break_list;     /* add for the break statement */ 
  CODE * continue_list;  /* add for continue statement */
} ATT;
 

void print_code(CODE * code)
{        
  int last_label = 0;
  
  printf("##code _listing:\n");
  
  while (code != NULL) {
    if (code->code != NULL && code->label!=NULL){	/*代码不空 跳转不空*/
      if (!last_label) printf("\t");
      last_label = 0;
      printf("%s %s \n", code->code, code->label);	/*label为代码所要跳转到得标号*/
    }
    else if (code->code != NULL){					/*代码不空 跳转为空*/
      if (!last_label) printf("\t");
      last_label = 0;
      printf("%s\n", code->code);
    }
    else if (code->label!= NULL){					/*代码为空 跳转不空*/
      last_label = 1;
      printf("%s:\t", code->label);
    }
    code = code ->next;
  }
  
  printf("\n##end_listing\n");
     
}

CODE * make_code(char *code, char *label)
{
  CODE * tmp = (CODE *) malloc( sizeof(CODE)) ;
  if (code != NULL) {
    char * s = (char *) malloc( strlen(code)+1);
    strcpy(s, code);
    tmp -> code = s;
  } else 
    tmp -> code = NULL;
  
  tmp -> label = label;
  tmp -> next = NULL;
  return tmp;
}

ATT make_att(CODE * tl, CODE * fl, CODE * code)
{
  ATT * att = (ATT * ) malloc(sizeof(ATT));
  att -> true_list = tl;
  att -> false_list = fl;
  att -> break_list = NULL;
  att -> continue_list = NULL;
  att-> code = code;
  return * att;
}

CODE *join_code(CODE * code1, CODE * code2)
{
	CODE * forward  = code1;
	
	if ( forward == NULL ) 
		return code2;
	
	while( forward -> next != NULL ) 
		forward = forward -> next;
	
	forward->next = code2;
	return code1;
  
}

CODE * get_first(CODE * code)
{
  if (code == NULL) {
    printf("get the beginning of code list error!\n");
    exit(1);
  }
  
  if (code->code  ==  NULL && code->label != NULL)	/*代码为空 跳转不空*/
    return code;
  {
    char * new_l = new_label();
    CODE * new_code = make_code(NULL, new_l);
    new_code -> next = code;
    
    return new_code;
  }
}

/****************用于多个布尔表达式的逻辑连接******************/
CODE * merge( CODE * code1, CODE * code2 )
{ 
	CODE * forward = code1;
	
	if ( code1 == NULL ) return code2;
	
	while( forward -> label != NULL )	/*找出第一个空label*/
		forward = ( CODE * ) forward -> label;	
		
	forward -> label = ( char * ) code2;	/*把第二个布尔表达式的代码指针放入第一个布尔表达式的代码链表的第一个不空的label里*/
	return code1;
}
/************************************************/

void back_patching( CODE *code, char * label )
{
	CODE * tmp;
	if ( code == NULL ) 
		return;
	
	/**********************确实不熟啊**************************
	while( tmp = (CODE *) code->label, code->label = (char *)label, code = tmp )
		; 
	**********************************************************/
	
	
		while (code != NULL) 
		{
			tmp = (CODE *) code ->label;	/*tmp只是为了记录一个空指针*/
			code -> label = label;
			code = tmp;						/*把tmp赋回给code只是想跳出循环*/
		} 
	
}

ATT assign(ATT id, ATT e)
{
  char s[20];
  CODE * code;
  
  sprintf(s, "%s := %s", (char *) id.true_list, (char *) e.true_list);
  code = make_code (s, NULL);
  id.code = join_code(e.code, code);
  id.true_list = NULL;
  id.false_list = NULL;
  
  return id;
}

#define YYSTYPE   ATT

#define YYMAXDEPTH   64
#define YYMAXERR     10
#define YYVERBOSE
%}

%token IF THEN ELSE WHILE DO SBEGIN END  ID ASSIGN BREAK CONTINUE
%token AND OR NOT TRUE FALSE RELOP FOR TO CASE SWITCH DEFAULT
%token REPEAT UNTIL

%left '+' '-'
%left '*'
%left UMINUS
%left OR
%left AND
%left NOT
%left ELSE

%%
p : s_list '.' {	/*语句列表*/
	ATT * s = &$1	;
	if($1.true_list != NULL) 
	{
		CODE * label_s = make_code(NULL, new_label());
		$1.code = join_code($1.code, label_s);
		back_patching($1.true_list, label_s->label);
	}
       
	if ($1.break_list != NULL)
		printf("Error: break statement misplaced!\n");
  
	if ($1.continue_list != NULL)
		printf("Error: continue statement misplaced!\n");
  
	print_code($1.code);
}
;

s_list  :  s		/*单条语句*/
|  s_list ';' s{	/*多条语句*/
    CODE * code = $3.code;
    if ($1.true_list != NULL ) {
      code = get_first ($3.code);
      back_patching($1.true_list, code->label);
    }  
    
    $1.true_list = $3.true_list;   /* not break */
    
    $1.break_list = merge($1.break_list, $3.break_list);        
    $1.continue_list = merge($1.continue_list, $3.continue_list);        
    
    $1.code = join_code($1.code, code);
    
    $$ = $1;
}
;

s : BREAK {			/*语句break*/
    CODE * goto_s = make_code("goto", NULL);
    ATT att = make_att( NULL, NULL,goto_s);
    att.break_list = goto_s;
    $$ = att;
    
    /*  while a > 0 do 
    switch a 
    begin 
    case 1: a:= 100 
    case 2: case 3: 
    begin a:=2; break end
                case 3: 
        begin a:=3; continue end 
                end.
        
        will translate the following  TAC:
                
           ##code _listing:
           l3:     if (a > 0) goto l4
                   goto l5
           l4:     if (a <> 1) goto  l0
                   a := 100
                   goto l3
           l0:     if (a = 2) goto  l1
                   if (a <> 3) goto  l2
           l1:     a := 2
                   goto l3
                   goto l3
           l2:     if (a <> 3) goto  l3
                   a := 3
                   goto l3
                   goto l3
                   goto l3
           l5:
           ##end_listing 
    */
}
    
|  CONTINUE {		/*continue语句*/
	CODE * goto_s = make_code("goto", NULL);
	ATT att = make_att( NULL, NULL,goto_s);
	att.continue_list = goto_s;
	$$ = att;
}

|   IF b_e THEN s  {	/*if then 语句*/
	/* 请完成！！！ */
	ATT * b_e = &$2;
	ATT * s = &$4;
	
	CODE * tmp;
	
	tmp = get_first( $4.code );	/*获取s前的标号*/
	back_patching( $2.true_list, tmp->label );	/*b_e为真的跳转标号*/
	$4.code = tmp;
	
	$$.code = join_code( $2.code, $4.code );	/*串代码*/

	/*出口*/
	$$.true_list = merge( $2.false_list, $4.true_list);
	$$.false_list = NULL;
	
	$$.break_list = $4.break_list; /*s如有break 则break到的地方就是本if语句要break到的地方*/
	$$.continue_list = $4.continue_list;	/*s如有continue 则continuek到的地方就是本if语句要break到的地方*/
}
    
|  IF b_e THEN s ELSE s {	/*if then else 语句*/
	ATT * b_e = &$2;
	ATT * s1 = &$4;
	ATT * s2 = &$6;
	
	CODE * code1, * code2, * goto_s;
	
	code1 = get_first($4.code);	/*在$4前串个标号*/
	back_patching( $2.true_list, code1->label );	/*回填b_e为真的跳转标号*/
	
	code2 = get_first($6.code);	/*在$6前串个标号*/
	back_patching( $2.false_list, code2->label );	/*回填b_e为假的跳转标号*/
	
	goto_s = make_code ("goto", NULL);	/*建一个goto节点做为本if语句执行完毕之后的跳转*/
  
	$6.code = join_code(goto_s, code2);	/*将goto_s放在第一个s与第二个s之间*/
	$4.code = join_code (code1, $6.code );
	$2.code = join_code ($2.code, $4.code);	/*判断条件链接在最前面*/
	/*所形成的形式为if goto goto s goto s*/
	
	/****合并if语句执行完毕后的出口 因为第一个s执行完毕就直接转出口 第二个s执行完毕业也直接转出口***
							goto_s也表示if语句执行完毕后就转出口 故将此三个出口合并 s goto s出口形势*/
	$4.true_list = merge($4.true_list, goto_s);	
	$4.true_list = merge($4.true_list, $6.true_list);
	/******************************************************/
  
	$2.true_list = $4.true_list;	/*本if语句执行完毕后的出口*/
	$2.false_list = NULL;
	
	/*******************合并break出口与continue出口*********************/ 
	$2.break_list = merge ($4.break_list, $6.break_list);
	$2.continue_list = merge($4.continue_list, $6.continue_list);  
	/******************************************************/
	
	$$ = $2;
}

|  REPEAT s_list UNTIL b_e {	/*repeat until 语句*/
	/* 请完成！！！ */
	ATT * s_list = &$2;
	ATT * b_e = &$4;
  
	CODE * code, * tmp;
	
	/*判断真转循环体*/
	code = get_first( $2.code );	/*获取s_list前的标号*/
	back_patching( $4.true_list, code->label );	/*b_e为真时要跳转到的地方为s_list前的标号*/
	$2.code = code;
	
	/*循环体true_list转判断*/
	if( $2.true_list != NULL )
	{
		tmp = get_first( $4.code );	/*将判断条件b_e前串个标号*/
		back_patching( $2.true_list, tmp->label );	/*s_list执行完毕后所要跳转到的地方为b_e前的标号*/
		$4.code = tmp;
	}
	
	/*循环体continue转判断*/
	if( $2.continue_list != NULL )
	{
		tmp = get_first( $4.code );	/*获取b_e前的标号*/
		back_patching( $2.continue_list, tmp->label );	/*s_list如果要continue，则continue到的地方为b_e前的标号*/
		$4.code = tmp;
	}
	
	/*循环体break见后面*/
	
	/*合并代码*/
	$$.code = join_code( $2.code, $4.code );	/*本repeat的语句为*/
	
	/*判断假转出口*/
	$$.true_list = merge( $4.false_list, $2.break_list );
	$$.break_list = NULL;
	$$.false_list = NULL;
  
}
    /*
        l:  s.code
            b_e.code
            ( b_e.true_list to l
              b_e.false_list to next )
             
        example: repeat a := a+b until a>0.
        ==> 
             ##code _listing:
             l0:     t0 := a + b
                     a := t0
                     if (a > 0) goto l0
                     goto l1
             l1:
             ##end_listing
     */ 
   
|  WHILE  b_e DO s {	/*while do 语句 while循环语句*/
	/* 请完成！！！ */
	ATT * b_e = &$2;
	ATT * s = &$4;
	
	CODE * goto_s, * tmp;
   
	/*循环体结束转判断*/
	goto_s = make_code( "goto", NULL );		/*循环体s执行玩一遍之后跳回到判断条件b_e前的判断*/
	tmp = get_first( $2.code );
	back_patching( goto_s, tmp->label );
	$2.code = tmp;
   
	/*判断真转循环体*/
	tmp = get_first( $4.code );	/*获取s前的标号*/
	back_patching( $2.true_list, tmp->label );	/*b_e为真时应跳转到s前的标号*/
	$4.code = tmp;
	
	/*循环体true_list转判断*/
	if( $4.true_list != NULL )
	{
		tmp = get_first( $2.code );	/*获取b_e前的标号*/
		back_patching( $4.true_list, tmp->label );	/*s语句执行完毕后应跳转至b_e前的标号*/
		$2.code = tmp;
	}
	
	/*循环体continue转判断*/
	if( $4.continue_list != NULL )
	{
		tmp = get_first( $2.code );
		back_patching( $4.continue_list,tmp->label );
		$2.code = tmp;
	}
	
	/*合并代码*/
	$$.code = join_code( $2.code, $4.code );	/*串代码*/
	$$.code = join_code( $$.code, goto_s );	/*串代码*/
	
	/*判断假转出口*/
	$$.true_list = merge( $2.false_list, $4.break_list );	/*本语句的出口是b_e为假时要跳转到的地方 也为s要break去的地方*/
	$$.break_list = NULL;
	$$.false_list = NULL;
} 
        
|  FOR ID ASSIGN e TO e DO s {	/*for := to do 语句 for循环语句*/
	/* 请完成！！！ */
	ATT * id = &$2;
	ATT * e1 = &$4;
	ATT * e2 = &$6;
	ATT * ss = &$8;
	  
	char s[40];
	CODE * code1, *code2, *code3, *goto_s, *tmp;
	
	sprintf( s, "%s := %s", ( char * )$2.true_list, ( char * )$4.true_list );	/*赋初值*/
	code1 = make_code( s, NULL );
	
	sprintf( s, "if (%s > %s) goto", (char * )$2.true_list,(char * )$6.true_list );	/*判断条件*/
	code2 = make_code( s, NULL );
	
	sprintf( s, "%s := %s + 1", ( char * )$2.true_list, ( char * )$2.true_list );	/*初值自增*/
	code3 = make_code( s, NULL );
	
	goto_s = make_code( "goto", NULL );	/*循环体执行完毕后跳转回判断条件*/
	
	/*循环体结束转判断*/
	tmp = get_first( code2 );	/*获取判断条件前的标号*/
	back_patching( goto_s, tmp->label );	/*判断条件为假时所要跳转到的地方*/
	$6.code = tmp;
	
	/*循环体true_list转判断*/
	if( $8.true_list != NULL )
	{
		tmp = get_first( $6.code );
		back_patching( $8.true_list, tmp->label );
		$6.code = tmp;
	}
	
	/*循环体continue转判断*/
	if( $8.continue_list != NULL )
	{
		tmp = get_first( $6.code );
		back_patching( $8.continue_list, tmp->label );
		$6.code = tmp;
	}
	
	/*合并代码*/
	$$.code = join_code( code1, $6.code );	/*赋初值和判断条件串*/
	$$.code = join_code( $$.code, $8.code );	/*与循环体串*/	
	$$.code = join_code( $$.code, code3 );	/*与初值自增串*/
	$$.code = join_code( $$.code, goto_s );	/*与goto串*/
	
	/*判断假转出口*/
	$$.true_list = merge( code2, $8.break_list );
	$$.break_list = NULL;
	$$.false_list = NULL;
	
  /*  ID := e1
     l1:    e2.code
            if ID.place > e2.place goto l2
        s.code
            ID.place := ID.place + 1
        goto l1
         l2: 
         
         examples: 
          
          for i:=1 to 100 do a:= a+1 .
          ===>
          ##code _listing:
                  i := 1
          l0:     if (i > 100) goto  l1
                  t0 := a + 1
                  a := t0
                  i := i + 1
                  goto l0
          l1:
          ##end_listin
         
         
         */
}
    
|  SBEGIN s_list ';' END {	/*begin 语句列表; end 语句 开始结束语句*/
  $$ = $2;
}
   
|  SBEGIN s_list  END {	/*begin end 语句 开始结束语句*/
  $$ = $2;
}
 
|  l ASSIGN e {	/*:= 语句 赋值语句*/
	ATT * l = &$1;
	ATT * e = &$3;
	ATT as = assign($1, $3);
	if ($1.code != NULL) as.code = join_code($1.code, as.code);

	$$ = as;
}

|  SWITCH e SBEGIN case_list  END {	/*switch begin end 开关语句*/
  /*  if ($4.false_list != NULL)
      if ($4.false_list->code != NULL)
    if (($4.false_list->code)[0] == '_') {
      printf("the action in enumerated cases is empty!\n");
      exit (1);
      } 
  */
  int is_enum, is_last;

  is_last = ($4.false_list != NULL && 
         (strncmp((char*)$4.false_list, "last", 4) == 0));

  if( is_last ){
    $4.false_list = NULL;
  }

  is_enum = ($4.false_list != NULL && 
         $4.false_list->code != NULL &&
         $4.false_list->code[0] == '_');

  if (is_enum) {
    printf("the action in enumerated cases is empty!\n");
    exit (1);
  }

  $2.code = join_code($2.code, $4.code);
  $2.true_list = merge($4.true_list, $4.false_list);
  $2.true_list = merge($2.true_list, $4.break_list);
  
  $2.continue_list = $4.continue_list;
     /* break is accepted in switch statement just like C switch */
    
  $2.false_list = NULL;
    
  $$ = $2;
}
;
        /* 
                    e.code
                    if e.place <> V1 goto l1
                    s1.code
                    goto next
           l1:      if e.place <> V2 goto l2
                    s2.code
                    ...
           lp:      if e.place <> Vp+1 goto  lp+1
                    sp+1.code
                    goto next
           lp+1:    default.code 
           next: 
       */


case_list :   {	/*匹配空*/
  $$ = make_att(NULL, NULL, NULL);
}   /* epsilon */

| case_list  CASE ID ':' { /* consecutive "CASE ID" */
	char s [40];
	CODE * goto_s, * if_s, * tmp;
	int is_enum, is_last;
	ATT * case_list = &$1;

	/* must test if last case first, if not so access false_list failure */
	is_last = ($1.false_list != NULL && (strncmp((char *)$1.false_list, "last", 4) == 0));
  
	if (is_last){
		printf("the default case must be last case!\n");
		exit (1);
	}

	is_enum = ($1.false_list != NULL && $1.false_list->code != NULL && $1.false_list->code[0] == '_');	/*多个case联合*/
  
	sprintf(s, "if (%s = %s) goto ", $-1.true_list, $3.true_list);
	if_s = make_code(s, NULL);
	tmp = if_s;
  
	/* last case is not consecutive case, backpatching case false link */         
	if ($1.code != NULL && !is_enum ){	/*不是多case联合且上一层case有代码*/
		tmp = get_first(tmp); 
		back_patching($1.false_list, tmp->label);	/*回填上一层case的不匹配跳转标号*/
	}
  
	$1.code = join_code($1.code, tmp);	/*合并两层case的代码*/
  
	if( !is_enum )  {	/*不是多case联合*/
		/*！！！！！！！！！！！！！！！！很重要！！！！！！！！！！！！！！！！！！！*/
		$1.false_list = merge(make_code("_", NULL), $1.true_list); /* false_list will remember case out list */
		$1.true_list = if_s;	/*用于给下个case回填*/
	} else				/*是多case联合*/
		$1.true_list =  merge($1.true_list, if_s);	/*合并匹配出口*/
  
	$$ = $1;   
}   

|  case_list  CASE ID ':' s_list {	/*case id: 后的语句列表 无需break就直接跳出*/
	/* 请完成！！！ */
	ATT * case_list = &$1;
	ATT * s_list = &$5, * ss = &$$;
  
	char s[40];
	CODE * if_s, * tmp, * goto_s;
	int is_enum, is_last;
	
	/* must test if last case first, if not so access false_list failure */
	is_last = ($1.false_list != NULL && (strncmp((char *)$1.false_list, "last", 4) == 0));	/*如果上一层case已经为last了*/
  
	if (is_last){
		printf("the default case must be last case!\n");
		exit (1);
	}
	
	/*上层case是case id:*/	
	is_enum = ($1.false_list != NULL && $1.false_list->code != NULL && $1.false_list->code[0] == '_');
	
	sprintf( s, "if(%s <> %s) goto", $-1.true_list, $3.true_list );
	if_s = make_code( s, NULL );
	tmp = if_s;
	
	if( $1.code == NULL ){
		$1.code = join_code( if_s, $5.code );
	}else{
		if( !is_enum ){	/*前case有代码 不级联*/
			tmp = get_first( tmp );
			back_patching( $1.false_list, tmp->label );	/*上层case的false_list为本层的case前的标号*/
			$1.code = join_code( $1.code, tmp );
			$1.code = join_code( $1.code, $5.code );	/*直接串s_list*/
		}else{
			$1.code = join_code( $1.code, if_s );	/*直接串case_list*/
			tmp = get_first( $5.code );		/*串s_list前的标号*/
			back_patching( $1.true_list, tmp->label );
			$1.code = join_code( $1.code, tmp );
		}
	}
	
	goto_s = make_code( "goto", NULL );
	$1.code = join_code( $1.code, goto_s ); 
	
	if( !is_enum ){
		$1.true_list = merge( $1.true_list, goto_s );
		$1.false_list = if_s;
	}else{
		/*如果是级联 则上层的false_list备份了上一级的case语句的出口 则上一层的true_list则记录的是该语句要跳转到的执行语句*/		
		$1.true_list = merge( $1.false_list, goto_s );
		$1.false_list = if_s;
	} 
	
	$1.break_list = merge ($1.break_list, $5.break_list);
	$1.continue_list = merge($1.continue_list, $5.continue_list);  
	
	$$ = $1;
}
    
| case_list  CASE DEFAULT ':' s_list  {	/*case default: 后的语句列表*/
	ATT * case_list = &$1;
	ATT * s_list = &$5;
	
  CODE  *tmp = $5.code;		/*得到语句列表的代码*/

  int is_enum, is_last, test;

  is_last = ($1.false_list != NULL && 
         (strncmp((char *) $1.false_list, "last", 4) == 0));
 
  /* test if there is a duplicate default case */
  if (is_last) {
    printf("Duplicated default case!\n");
    exit (1);
  }

  is_enum = ($1.false_list != NULL &&
         $1.false_list->code != NULL &&
         $1.false_list->code [0] == '_');

  test =  ($1.code != NULL && !is_enum);
  
  if ( test ) {
    tmp = get_first($5.code);
    back_patching($1.false_list, tmp->label);
  } else {
    if (is_enum) { 
      tmp = get_first($5.code);
      back_patching($1.true_list, tmp ->label);  
      $1.true_list =(CODE *) $1.false_list ->label;
    }
  }
        
  $1.code = join_code($1.code, tmp);
    
  if ($5.true_list != NULL) 
    $1.true_list = merge($1.true_list, $5.true_list);
     
  $1.false_list =  (CODE *) last_mark;
      /* a mark of last case */
        
  $1.break_list = merge ($1.break_list, $5.break_list);

  $1.continue_list = merge($1.continue_list, $5.continue_list);    
      
  $$ = $1;    
}
;

l :  ID {
	ATT * id = &$1;
	$$ = $1;
}
    
| ID '[' e_list ']' {	/*数组*/

	ATT * e_list = &$3;
	char cnt[2] = { '2', '\0' };	/*计数维数*/
	CODE * tmp = $3.false_list;
	CODE * result = 0;
	CODE * code;
	char s[32];
	char * name1, * name2, * name3;
	
	if( tmp != 0 && tmp->label != 0 )
		result = join_code( result, ( CODE * )tmp->label );	/*直接加入结果*/
	
	while( tmp->next != 0 )	/*每一层循环要申请一个name*/
	{
		CODE * tmp1 = tmp->next;	/*下一维*/
		char * name = new_name();	/*申请一个name*/
		
		/*查看下一维是否为空*/
		if( tmp1 != 0 )	/*下一维不空*/
		{
			char s[20];
			CODE * code;
			if( tmp1->label != 0 )	/*下维地址存在且未直接给出*/
			{
				result = join_code( result, ( CODE * )tmp1->label );	/*直接加入结果*/	
			}
			/*将本维加权 code中的内容可用于直接加权*/
			sprintf( s, "%s := %s * limit( %s, %s )", name, tmp->code, ( char * )$1.true_list, cnt );
			cnt[0] ++;
			code = make_code( s, NULL );
			result = join_code( result, code );
			/*将本维与下维相加*/
			sprintf( s, "%s := %s + %s", name, name, tmp1->code );
			code = make_code( s, NULL );
			result = join_code( result, code );
			
			tmp1->code = name;
		}
		
		tmp = tmp1;
	}
	
	name1 = new_name();	/*记录首址*/
	sprintf( s, "%s := const( array of %s )", name1, (char *)$1.true_list );
	code = make_code( s, NULL );
	result = join_code( result, code );
	
	name2 = new_name();	/*记录偏移量*/
	sprintf( s, "%s := %s * width( %s )", name2, tmp->code, ( char * )$1.true_list );
	code = make_code( s, NULL );
	result = join_code( result, code );
	
	name3 = new_name();	/*赋值*/
	sprintf( s, "%s := %s[%s]", name3, name1, name2 );
	code = make_code( s, NULL );
	result = join_code( result, code );
/*	
	sprintf( s, "%s := %s", ( char * )$-3.true_list, name3 );
	code = make_code( s, NULL );
	result = join_code( result, code );
*/	
	$$.true_list = ( CODE * )name3;
	$$.code = result;
	
	/* array element */
	/*
		a:= a[b, c, d].
		t0 := b * limit(a, 2)
		t0 := t0 + c
		t1 := t0 * limit(a, 3)
		t1 := t1 + d
		t2 := const(array of a)
		t3 := t1 * width of a
		t4 := t2 [t3]
		a := t4 
	*/

	/*
		a:=b[c+d, e+f, g+h, i+j].
		##code _listing:
		t0 := c + d
		t1 := e + f
		t4 := t0 * limit(b, 2)
		t4 := t4 + t1
		t2 := g + h
		t5 := t4 * limit(b, 3)
		t5 := t5 + t2
		t3 := i + j
		t6 := t5 * limit(b, 4)
		t6 := t6 + t3
		t7 := const (array of  b)
		t8 := t6 * width ( b )
		t9 := t7 [ t8 ]
		a := t9
	
		##end_listing
	*/
	/* 请完成！！！ */
	    
}
;    
    
e : e '+' e {
	/* 请完成！！！ */
	char * tmp = new_name();
	char s[20];
	CODE * code;
	
	sprintf( s, "%s := %s + %s", tmp, ( char * )$1.true_list, ( char * )$3.true_list );
	code = make_code( s, NULL );
	
	$1.true_list = ( CODE * )tmp;
	$1.code = join_code( $1.code, $3.code );
	$1.code = join_code( $1.code, code );
	
	$$ = $1;
}

	|  e '*' e {
	char * tmp = new_name();
	char  s[20];
	CODE * code ;
    
	sprintf (s, "%s := %s * %s", tmp, (char *) $1.true_list, (char *) $3.true_list);
	code  = make_code(s, NULL);
    
	$1.true_list = (CODE *) tmp;
	$1.code = join_code($1.code, $3.code);
	$1.code = join_code ($1.code, code);
    
	$$ = $1;
}

|  e '-' e {
	char * tmp = new_name();
	char  s[20];
	CODE * code ;
    
	sprintf (s, "%s := %s - %s", tmp, (char *) $1.true_list, (char *) $3.true_list);
	code  = make_code(s, NULL);
    
	$1.true_list = (CODE *) tmp;
	$1.code = join_code($1.code, $3.code);
	$1.code = join_code ($1.code, code);
    
	$$ = $1;
}

| '-' e %prec UMINUS {
	char * tmp = new_name();
	char  s[20];
	CODE * code ;
    
	sprintf (s, "%s := - %s", tmp, (char *) $2.true_list);
	code  = make_code(s, NULL);
    
	$2.true_list = (CODE *) tmp;
	$2.code = join_code($2.code, code);
    
	$$ = $2;
}
  

| '(' e ')' {
	$$ = $2;
}

| l

| ID '(' e_list ')' {	/*函数的调用*/
	/* function call */
	int count = 0;
	char * tmp = new_name();
	CODE * param = NULL, * code = NULL;
	CODE * ptr  = $3.false_list;
	char s[30];
	
	while(ptr != NULL) {
		char s [30] ;
		sprintf(s, "param %s", (ptr)-> code);
		code = join_code(code, (CODE*)ptr->label);
		param = join_code (param, make_code(s, NULL));
		ptr = ptr ->next;
		count++;
	}
        
	sprintf(s, "%s := call %s, %d", tmp, $1.true_list, count);
	param = join_code(param, make_code(s, NULL));
    
	$1.code = join_code(code, param);
	$1.true_list = (CODE *)tmp;
    
	$$ = $1;
}
/*
  a:=b(a*c,e-f, -d) * 300 -100.
  ==>
  ##code _listing:
  t0 := a * c
  t1 := e - f
  t2 := - d
  param t0
  param t1
  param t2
  t3 := call b, 3
  t4 := t3 * 300
  t5 := t4 - 100
  a := t5

  ##end_listing
*/
  
;

e_list : e  {
  /* use code list to link actual parameter,
     and code->code holds the a.p. tmp result. 
     and code->label holds the code chain of evaluation a.p.
     and the list head will store in att.false_list */
          
  $1.false_list = make_code((char *)$1.true_list, (char *) $1.code);
  $$ = $1;
}
          
| e_list ',' e {
	ATT * e_list = &$1;
	ATT * e = &$3;
	
	CODE * e_result = make_code((char *)$3.true_list, (char *) $3.code);
    
	$1.false_list = join_code($1.false_list, e_result);

	$$ = $1;
}
;

b_e : b_e OR b_e {	/*判断条件 逻辑值*/
	ATT * b_e1 = &$1;
	ATT * b_e2 = &$3;
	
	CODE * code= get_first($3.code);
    
	back_patching($1.false_list, code->label);
    
	$1.false_list = $3.false_list;
	$1.true_list = merge($1.true_list, $3.true_list);
	$1.code = join_code ($1.code, code);
    
	$$ = $1;
}
    
| b_e AND b_e { 
	CODE  * code = get_first($3.code);
    
	back_patching($1.true_list, code ->label);
    
	$1.true_list = $3.true_list;
	$1.false_list = merge($1.false_list, $3.false_list);
	$1.code = join_code ($1.code, code);
    
	$$ = $1;
}

| NOT b_e {
	CODE * tmp = $2.true_list;
    
	$2.true_list = $2.false_list;
	$2.false_list = tmp;
    
	$$ = $2;
}

| '(' b_e ')' {
	$$ = $2;
}

| e RELOP e {
	ATT * e1 = &$1;
	ATT * e2 = &$3;
	char  s [40];
	CODE *code1, *code2;
    
	sprintf(s, "if (%s %s %s) goto", (char * )$1.true_list,(char * )$2.true_list,(char * )$3.true_list);
        
	code1 = make_code (s, NULL);
	code2 = make_code ("goto", NULL);

	$1.code = join_code (code1, code2);
	$1.true_list = code1;
	$1.false_list = code2;
    
	$$ = $1;
}

| TRUE {
	CODE * code  = make_code("goto", NULL);
	ATT  att  = make_att(code, NULL, code);
	$$ = att;
}

| FALSE {
	CODE * code  = make_code("goto", NULL);
	ATT att  = make_att(NULL, code, code);
	$$ = att;
}
;

/* M  :  {
   $$ = make_att(NULL, NULL, make_code(NULL, new_label()));
   }
   ;
*/


    
%%
/*----------------------------------------------------------------------*/
#ifdef __TURBOC__
#pragma argsused
#endif
/*----------------------------------------------------------------------*/
char  *Names[] = { "t0", "t1", "t2", "t3", "t4", "t5", "t6", "t7","t8","t9",
           "t10", "t11", "t12", "t13", "t14", "t15", "t16", "t17","t18","t19",
           "t20", "t21", "t22", "t23", "t24", "t25", "t26", "t27","t28","t29", 
           "t30", "t31", "t32", "t33", "t34", "t35", "t36", "t37","t38","t29"  };
char  **Namep  = Names;

char    *new_name()
{
  /* Return a temporary-variable name by popping one off the name stack.  */

  if( Namep >= &Names[ sizeof(Names)/sizeof(*Names) ] )
    {
      yyerror("Expression too complex\n");
      exit( 1 );
    }

  return( *Namep++ );
}

char  *LNames[] = { "l0", "l1", "l2", "l3", "l4", "l5", "l6", "l7","l8","l9" ,
            "l10", "l11", "l12", "l13", "l14", "l15", "l16", "l17","l18","l19"};
char  **LNamep  = LNames;

char    *new_label()
{
  /* Return a temporary-variable name by popping one off the name stack.  */

  if( LNamep >= &LNames[ sizeof(LNames)/sizeof(*LNames) ] )
    {
      yyerror("Expression too complex\n");
      exit( 1 );
    }

  return( *LNamep++ );
}


void free_name(s)
     char    *s;
{           /* Free up a previously allocated name */
  *--Namep = s;
}

int yyerror(char *s)
{
  printf("%s\n", s);
}


int main( argc, argv )
     int  argc;
     char **argv;
{
  yyparse();
  return 0;
}
