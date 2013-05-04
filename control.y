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

extern char *yytext;         /* Lexeme, In yylex()     ��ǰʶ����ַ��� ��control.l�ж���      */
char *new_label( void );
char *new_name  ( void    );  
void free_name  ( char *s );

typedef struct code {
  char * code;     
  char * label; /* for goto label, used also 
                   for backpatching list pointer */
  struct code * next;
} CODE;	/*��ʽ�ṹ*/
 
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
    if (code->code != NULL && code->label!=NULL){	/*���벻�� ��ת����*/
      if (!last_label) printf("\t");
      last_label = 0;
      printf("%s %s \n", code->code, code->label);	/*labelΪ������Ҫ��ת���ñ��*/
    }
    else if (code->code != NULL){					/*���벻�� ��תΪ��*/
      if (!last_label) printf("\t");
      last_label = 0;
      printf("%s\n", code->code);
    }
    else if (code->label!= NULL){					/*����Ϊ�� ��ת����*/
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
  
  if (code->code  ==  NULL && code->label != NULL)	/*����Ϊ�� ��ת����*/
    return code;
  {
    char * new_l = new_label();
    CODE * new_code = make_code(NULL, new_l);
    new_code -> next = code;
    
    return new_code;
  }
}

/****************���ڶ���������ʽ���߼�����******************/
CODE * merge( CODE * code1, CODE * code2 )
{ 
	CODE * forward = code1;
	
	if ( code1 == NULL ) return code2;
	
	while( forward -> label != NULL )	/*�ҳ���һ����label*/
		forward = ( CODE * ) forward -> label;	
		
	forward -> label = ( char * ) code2;	/*�ѵڶ����������ʽ�Ĵ���ָ������һ���������ʽ�Ĵ�������ĵ�һ�����յ�label��*/
	return code1;
}
/************************************************/

void back_patching( CODE *code, char * label )
{
	CODE * tmp;
	if ( code == NULL ) 
		return;
	
	/**********************ȷʵ���찡**************************
	while( tmp = (CODE *) code->label, code->label = (char *)label, code = tmp )
		; 
	**********************************************************/
	
	
		while (code != NULL) 
		{
			tmp = (CODE *) code ->label;	/*tmpֻ��Ϊ�˼�¼һ����ָ��*/
			code -> label = label;
			code = tmp;						/*��tmp���ظ�codeֻ��������ѭ��*/
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
p : s_list '.' {	/*����б�*/
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

s_list  :  s		/*�������*/
|  s_list ';' s{	/*�������*/
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

s : BREAK {			/*���break*/
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
    
|  CONTINUE {		/*continue���*/
	CODE * goto_s = make_code("goto", NULL);
	ATT att = make_att( NULL, NULL,goto_s);
	att.continue_list = goto_s;
	$$ = att;
}

|   IF b_e THEN s  {	/*if then ���*/
	/* ����ɣ����� */
	ATT * b_e = &$2;
	ATT * s = &$4;
	
	CODE * tmp;
	
	tmp = get_first( $4.code );	/*��ȡsǰ�ı��*/
	back_patching( $2.true_list, tmp->label );	/*b_eΪ�����ת���*/
	$4.code = tmp;
	
	$$.code = join_code( $2.code, $4.code );	/*������*/

	/*����*/
	$$.true_list = merge( $2.false_list, $4.true_list);
	$$.false_list = NULL;
	
	$$.break_list = $4.break_list; /*s����break ��break���ĵط����Ǳ�if���Ҫbreak���ĵط�*/
	$$.continue_list = $4.continue_list;	/*s����continue ��continuek���ĵط����Ǳ�if���Ҫbreak���ĵط�*/
}
    
|  IF b_e THEN s ELSE s {	/*if then else ���*/
	ATT * b_e = &$2;
	ATT * s1 = &$4;
	ATT * s2 = &$6;
	
	CODE * code1, * code2, * goto_s;
	
	code1 = get_first($4.code);	/*��$4ǰ�������*/
	back_patching( $2.true_list, code1->label );	/*����b_eΪ�����ת���*/
	
	code2 = get_first($6.code);	/*��$6ǰ�������*/
	back_patching( $2.false_list, code2->label );	/*����b_eΪ�ٵ���ת���*/
	
	goto_s = make_code ("goto", NULL);	/*��һ��goto�ڵ���Ϊ��if���ִ�����֮�����ת*/
  
	$6.code = join_code(goto_s, code2);	/*��goto_s���ڵ�һ��s��ڶ���s֮��*/
	$4.code = join_code (code1, $6.code );
	$2.code = join_code ($2.code, $4.code);	/*�ж�������������ǰ��*/
	/*���γɵ���ʽΪif goto goto s goto s*/
	
	/****�ϲ�if���ִ����Ϻ�ĳ��� ��Ϊ��һ��sִ����Ͼ�ֱ��ת���� �ڶ���sִ�����ҵҲֱ��ת����***
							goto_sҲ��ʾif���ִ����Ϻ��ת���� �ʽ����������ںϲ� s goto s��������*/
	$4.true_list = merge($4.true_list, goto_s);	
	$4.true_list = merge($4.true_list, $6.true_list);
	/******************************************************/
  
	$2.true_list = $4.true_list;	/*��if���ִ����Ϻ�ĳ���*/
	$2.false_list = NULL;
	
	/*******************�ϲ�break������continue����*********************/ 
	$2.break_list = merge ($4.break_list, $6.break_list);
	$2.continue_list = merge($4.continue_list, $6.continue_list);  
	/******************************************************/
	
	$$ = $2;
}

|  REPEAT s_list UNTIL b_e {	/*repeat until ���*/
	/* ����ɣ����� */
	ATT * s_list = &$2;
	ATT * b_e = &$4;
  
	CODE * code, * tmp;
	
	/*�ж���תѭ����*/
	code = get_first( $2.code );	/*��ȡs_listǰ�ı��*/
	back_patching( $4.true_list, code->label );	/*b_eΪ��ʱҪ��ת���ĵط�Ϊs_listǰ�ı��*/
	$2.code = code;
	
	/*ѭ����true_listת�ж�*/
	if( $2.true_list != NULL )
	{
		tmp = get_first( $4.code );	/*���ж�����b_eǰ�������*/
		back_patching( $2.true_list, tmp->label );	/*s_listִ����Ϻ���Ҫ��ת���ĵط�Ϊb_eǰ�ı��*/
		$4.code = tmp;
	}
	
	/*ѭ����continueת�ж�*/
	if( $2.continue_list != NULL )
	{
		tmp = get_first( $4.code );	/*��ȡb_eǰ�ı��*/
		back_patching( $2.continue_list, tmp->label );	/*s_list���Ҫcontinue����continue���ĵط�Ϊb_eǰ�ı��*/
		$4.code = tmp;
	}
	
	/*ѭ����break������*/
	
	/*�ϲ�����*/
	$$.code = join_code( $2.code, $4.code );	/*��repeat�����Ϊ*/
	
	/*�жϼ�ת����*/
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
   
|  WHILE  b_e DO s {	/*while do ��� whileѭ�����*/
	/* ����ɣ����� */
	ATT * b_e = &$2;
	ATT * s = &$4;
	
	CODE * goto_s, * tmp;
   
	/*ѭ�������ת�ж�*/
	goto_s = make_code( "goto", NULL );		/*ѭ����sִ����һ��֮�����ص��ж�����b_eǰ���ж�*/
	tmp = get_first( $2.code );
	back_patching( goto_s, tmp->label );
	$2.code = tmp;
   
	/*�ж���תѭ����*/
	tmp = get_first( $4.code );	/*��ȡsǰ�ı��*/
	back_patching( $2.true_list, tmp->label );	/*b_eΪ��ʱӦ��ת��sǰ�ı��*/
	$4.code = tmp;
	
	/*ѭ����true_listת�ж�*/
	if( $4.true_list != NULL )
	{
		tmp = get_first( $2.code );	/*��ȡb_eǰ�ı��*/
		back_patching( $4.true_list, tmp->label );	/*s���ִ����Ϻ�Ӧ��ת��b_eǰ�ı��*/
		$2.code = tmp;
	}
	
	/*ѭ����continueת�ж�*/
	if( $4.continue_list != NULL )
	{
		tmp = get_first( $2.code );
		back_patching( $4.continue_list,tmp->label );
		$2.code = tmp;
	}
	
	/*�ϲ�����*/
	$$.code = join_code( $2.code, $4.code );	/*������*/
	$$.code = join_code( $$.code, goto_s );	/*������*/
	
	/*�жϼ�ת����*/
	$$.true_list = merge( $2.false_list, $4.break_list );	/*�����ĳ�����b_eΪ��ʱҪ��ת���ĵط� ҲΪsҪbreakȥ�ĵط�*/
	$$.break_list = NULL;
	$$.false_list = NULL;
} 
        
|  FOR ID ASSIGN e TO e DO s {	/*for := to do ��� forѭ�����*/
	/* ����ɣ����� */
	ATT * id = &$2;
	ATT * e1 = &$4;
	ATT * e2 = &$6;
	ATT * ss = &$8;
	  
	char s[40];
	CODE * code1, *code2, *code3, *goto_s, *tmp;
	
	sprintf( s, "%s := %s", ( char * )$2.true_list, ( char * )$4.true_list );	/*����ֵ*/
	code1 = make_code( s, NULL );
	
	sprintf( s, "if (%s > %s) goto", (char * )$2.true_list,(char * )$6.true_list );	/*�ж�����*/
	code2 = make_code( s, NULL );
	
	sprintf( s, "%s := %s + 1", ( char * )$2.true_list, ( char * )$2.true_list );	/*��ֵ����*/
	code3 = make_code( s, NULL );
	
	goto_s = make_code( "goto", NULL );	/*ѭ����ִ����Ϻ���ת���ж�����*/
	
	/*ѭ�������ת�ж�*/
	tmp = get_first( code2 );	/*��ȡ�ж�����ǰ�ı��*/
	back_patching( goto_s, tmp->label );	/*�ж�����Ϊ��ʱ��Ҫ��ת���ĵط�*/
	$6.code = tmp;
	
	/*ѭ����true_listת�ж�*/
	if( $8.true_list != NULL )
	{
		tmp = get_first( $6.code );
		back_patching( $8.true_list, tmp->label );
		$6.code = tmp;
	}
	
	/*ѭ����continueת�ж�*/
	if( $8.continue_list != NULL )
	{
		tmp = get_first( $6.code );
		back_patching( $8.continue_list, tmp->label );
		$6.code = tmp;
	}
	
	/*�ϲ�����*/
	$$.code = join_code( code1, $6.code );	/*����ֵ���ж�������*/
	$$.code = join_code( $$.code, $8.code );	/*��ѭ���崮*/	
	$$.code = join_code( $$.code, code3 );	/*���ֵ������*/
	$$.code = join_code( $$.code, goto_s );	/*��goto��*/
	
	/*�жϼ�ת����*/
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
    
|  SBEGIN s_list ';' END {	/*begin ����б�; end ��� ��ʼ�������*/
  $$ = $2;
}
   
|  SBEGIN s_list  END {	/*begin end ��� ��ʼ�������*/
  $$ = $2;
}
 
|  l ASSIGN e {	/*:= ��� ��ֵ���*/
	ATT * l = &$1;
	ATT * e = &$3;
	ATT as = assign($1, $3);
	if ($1.code != NULL) as.code = join_code($1.code, as.code);

	$$ = as;
}

|  SWITCH e SBEGIN case_list  END {	/*switch begin end �������*/
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


case_list :   {	/*ƥ���*/
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

	is_enum = ($1.false_list != NULL && $1.false_list->code != NULL && $1.false_list->code[0] == '_');	/*���case����*/
  
	sprintf(s, "if (%s = %s) goto ", $-1.true_list, $3.true_list);
	if_s = make_code(s, NULL);
	tmp = if_s;
  
	/* last case is not consecutive case, backpatching case false link */         
	if ($1.code != NULL && !is_enum ){	/*���Ƕ�case��������һ��case�д���*/
		tmp = get_first(tmp); 
		back_patching($1.false_list, tmp->label);	/*������һ��case�Ĳ�ƥ����ת���*/
	}
  
	$1.code = join_code($1.code, tmp);	/*�ϲ�����case�Ĵ���*/
  
	if( !is_enum )  {	/*���Ƕ�case����*/
		/*������������������������������������Ҫ��������������������������������������*/
		$1.false_list = merge(make_code("_", NULL), $1.true_list); /* false_list will remember case out list */
		$1.true_list = if_s;	/*���ڸ��¸�case����*/
	} else				/*�Ƕ�case����*/
		$1.true_list =  merge($1.true_list, if_s);	/*�ϲ�ƥ�����*/
  
	$$ = $1;   
}   

|  case_list  CASE ID ':' s_list {	/*case id: �������б� ����break��ֱ������*/
	/* ����ɣ����� */
	ATT * case_list = &$1;
	ATT * s_list = &$5, * ss = &$$;
  
	char s[40];
	CODE * if_s, * tmp, * goto_s;
	int is_enum, is_last;
	
	/* must test if last case first, if not so access false_list failure */
	is_last = ($1.false_list != NULL && (strncmp((char *)$1.false_list, "last", 4) == 0));	/*�����һ��case�Ѿ�Ϊlast��*/
  
	if (is_last){
		printf("the default case must be last case!\n");
		exit (1);
	}
	
	/*�ϲ�case��case id:*/	
	is_enum = ($1.false_list != NULL && $1.false_list->code != NULL && $1.false_list->code[0] == '_');
	
	sprintf( s, "if(%s <> %s) goto", $-1.true_list, $3.true_list );
	if_s = make_code( s, NULL );
	tmp = if_s;
	
	if( $1.code == NULL ){
		$1.code = join_code( if_s, $5.code );
	}else{
		if( !is_enum ){	/*ǰcase�д��� ������*/
			tmp = get_first( tmp );
			back_patching( $1.false_list, tmp->label );	/*�ϲ�case��false_listΪ�����caseǰ�ı��*/
			$1.code = join_code( $1.code, tmp );
			$1.code = join_code( $1.code, $5.code );	/*ֱ�Ӵ�s_list*/
		}else{
			$1.code = join_code( $1.code, if_s );	/*ֱ�Ӵ�case_list*/
			tmp = get_first( $5.code );		/*��s_listǰ�ı��*/
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
		/*����Ǽ��� ���ϲ��false_list��������һ����case���ĳ��� ����һ���true_list���¼���Ǹ����Ҫ��ת����ִ�����*/		
		$1.true_list = merge( $1.false_list, goto_s );
		$1.false_list = if_s;
	} 
	
	$1.break_list = merge ($1.break_list, $5.break_list);
	$1.continue_list = merge($1.continue_list, $5.continue_list);  
	
	$$ = $1;
}
    
| case_list  CASE DEFAULT ':' s_list  {	/*case default: �������б�*/
	ATT * case_list = &$1;
	ATT * s_list = &$5;
	
  CODE  *tmp = $5.code;		/*�õ�����б�Ĵ���*/

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
    
| ID '[' e_list ']' {	/*����*/

	ATT * e_list = &$3;
	char cnt[2] = { '2', '\0' };	/*����ά��*/
	CODE * tmp = $3.false_list;
	CODE * result = 0;
	CODE * code;
	char s[32];
	char * name1, * name2, * name3;
	
	if( tmp != 0 && tmp->label != 0 )
		result = join_code( result, ( CODE * )tmp->label );	/*ֱ�Ӽ�����*/
	
	while( tmp->next != 0 )	/*ÿһ��ѭ��Ҫ����һ��name*/
	{
		CODE * tmp1 = tmp->next;	/*��һά*/
		char * name = new_name();	/*����һ��name*/
		
		/*�鿴��һά�Ƿ�Ϊ��*/
		if( tmp1 != 0 )	/*��һά����*/
		{
			char s[20];
			CODE * code;
			if( tmp1->label != 0 )	/*��ά��ַ������δֱ�Ӹ���*/
			{
				result = join_code( result, ( CODE * )tmp1->label );	/*ֱ�Ӽ�����*/	
			}
			/*����ά��Ȩ code�е����ݿ�����ֱ�Ӽ�Ȩ*/
			sprintf( s, "%s := %s * limit( %s, %s )", name, tmp->code, ( char * )$1.true_list, cnt );
			cnt[0] ++;
			code = make_code( s, NULL );
			result = join_code( result, code );
			/*����ά����ά���*/
			sprintf( s, "%s := %s + %s", name, name, tmp1->code );
			code = make_code( s, NULL );
			result = join_code( result, code );
			
			tmp1->code = name;
		}
		
		tmp = tmp1;
	}
	
	name1 = new_name();	/*��¼��ַ*/
	sprintf( s, "%s := const( array of %s )", name1, (char *)$1.true_list );
	code = make_code( s, NULL );
	result = join_code( result, code );
	
	name2 = new_name();	/*��¼ƫ����*/
	sprintf( s, "%s := %s * width( %s )", name2, tmp->code, ( char * )$1.true_list );
	code = make_code( s, NULL );
	result = join_code( result, code );
	
	name3 = new_name();	/*��ֵ*/
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
	/* ����ɣ����� */
	    
}
;    
    
e : e '+' e {
	/* ����ɣ����� */
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

| ID '(' e_list ')' {	/*�����ĵ���*/
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

b_e : b_e OR b_e {	/*�ж����� �߼�ֵ*/
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
