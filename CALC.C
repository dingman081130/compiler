
/************************************************************/
/*      copyright hanfei.wang@gmail.com                     */
/*             2009. 04.27                                  */
/************************************************************/

#include "calc.h"

int count = 0;
SYMREC sym_table [16];
void free_node(SyntaxTree tree);

void free_symb(void);

int putsym (char *sym_name, int value)
{
  if (count >=16) {
		printf(" there are too many atoms(%d)!\n", count);
		exit(-1);
	}
  
  sym_table[count].value = value;
  sym_table[count].name = (char *) malloc(strlen(sym_name) + 1);
  strcpy(sym_table[count].name, sym_name);
  count ++;
  return 1;
}

int getsym (char *sym_name)
{
	int k ;
	for (k = 0; k<= count -1 ; k++) {
		if (strcmp(sym_name, sym_table[k].name) == 0)
			return k;
	}
	return k;
}



SyntaxTree mkOpNode(Kind op, SyntaxTree tree1, SyntaxTree tree2)
{
	SyntaxTree mytree;
	mytree = ( SyntaxTree) malloc(sizeof(STreeNode));
	mytree->op = op;
	mytree->lchild = tree1;
	mytree->rchild = tree2;
	return mytree;
}

SyntaxTree mkNumNode(int val)
{
	SyntaxTree mytree;
	mytree = ( SyntaxTree) malloc(sizeof(STreeNode));

	mytree->op = ConstKind;

	mytree->lchild = NULL;
	mytree->rchild = NULL;
	mytree->val.true_value = val;
	return mytree;
}

SyntaxTree mkAtomNode( SYMREC * id)
{
	SyntaxTree mytree;
	mytree = ( SyntaxTree) malloc(sizeof(STreeNode));

	mytree->op = Atom;

	mytree->lchild = NULL;
	mytree->rchild = NULL;
	mytree->val.atom = id;
	return mytree;
}

void evaluate(SyntaxTree tree)
{
	char * and, * or;	/*析取范式与合取范式*/
	printf( "truth table:\n" );
	if( count == 0 )
	{
		int result = evaluate1( tree );
		printf( "\t\tresult\n" );
		printf( "pass = 0\t%d\n", result );
		if( result == 1 )
		{
			printf( "the disjunction normal form is:\n\n" );
			printf( "the number of miniterms is 1.\n\n\n" );
			printf( "the conjunction normal form is:\n" );
			printf( "(It's a tautology！)\n" );
		}
		else
		{
			printf( "the disjunction normal form is:\n" );
			printf( "It's a contradiction！\n\n\n" );
			printf( "the conjunction normal form is:\n" );
			printf( "()\n" );
			printf( "the number of maxterm is 1.\n\n" );
		}
	}
	else
	{
		int passNum = ( int )pow( 2, count );		
		int i, j, andN = 0, orN = 0 ;
		and = ( char * )malloc( 1024 );
		or = ( char * )malloc( 1024 );
		strcpy( and, "" );
		strcpy( or, "" );
		printf( "\t\t" );
		for( i = 0; i < count; i ++ )
			printf( "%s	", sym_table[i].name );
		printf( "reslut\n" );
		for( i = 0; i < passNum; i ++ )
		{
			int result;	/*声明结果*/
			int k = i;
			/*赋值*/
			for( j = 0; j < count; j ++ )
			{
				sym_table[count-1-j].value = k % 2;
				k = ( k - sym_table[count-1-j].value ) / 2;
			}

			result = evaluate1( tree );	/*求取结果*/
			
			/*打印每一次的复制以及赋值后的结果*/
			printf( "pass = %d\t", i );
			for( k = 0; k < count; k ++ )
				printf( "%d	", sym_table[k].value );
			printf( "%d\n", result );

			if( result == 1 )
			{
				orN ++;
				for( k = 0; k < count; k ++ )
				{
					if( sym_table[k].value == 1 )
					{
						strcat( or, sym_table[k].name );
						strcat( or, "&" );
					}
					else
					{
						strcat( or, "-" );
						strcat( or, sym_table[k].name );
						strcat( or, "&" );
					}
				}
				or[strlen(or)-1] = '\0';
				strcat( or, " | " );
			}
			else
			{
				andN ++;
				strcat( and, "(" );
				for( k = 0; k < count; k ++ )
				{
					if( sym_table[k].value == 0 )
					{
						strcat( and, sym_table[k].name );
						strcat( and, "|" );
					}
					else
					{
						strcat( and, "-" );
						strcat( and, sym_table[k].name );
						strcat( and, "|" );
					}
				}
				and[strlen(and)-1] = '\0';
				strcat( and, ")" );
				strcat( and, " & " );
			}
		}
		and[strlen(and)-2] = '\0';
		or[strlen(or)-2] = '\0';
		/*打印析取范式与合取范式*/
		printf( "the disjunction normal form is:\n" );
		printf( "%s\n", or );
		printf( "the number of miniterms is %d.\n\n", orN );

		printf( "the conjunction normal form is:\n" );
		printf( "%s\n", and );
		printf( "the number of maxterm is %d.\n\n", andN );
		count = 0;
		free( and ); free( or );
	}
}

int evaluate1(SyntaxTree tree)
{
  switch (tree->op ){
   case And: return evaluate1(tree->lchild) && evaluate1(tree->rchild);
   case Or: return evaluate1(tree->lchild) || evaluate1(tree->rchild);
   case Impl: return evaluate1(tree->lchild)?  (evaluate1(tree->rchild)): 1;
   case Equi: return evaluate1(tree->lchild) == evaluate1(tree->rchild);
   case Not: return  ! evaluate1(tree->lchild);
   case ConstKind: return tree->val.true_value;
   case Atom: return (tree->val.atom)->value;
   default:  printf("evaluate error!\n"); exit(0);
   }
}

void free_node(SyntaxTree tree)
{
  switch (tree->op ){
    case And:
    case Or:
    case Impl:
    case Equi: free_node(tree->lchild); free_node(tree->rchild); break;
    case Not: free_node(tree->lchild); break;
    default:  free(tree); return;
  }
  free(tree);
}

void free_symb(void)
{
  int k ;
  for (k = 0 ; k <count; k++)
    free(sym_table[k].name);
}