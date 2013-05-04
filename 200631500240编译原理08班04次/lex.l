/* scanner for a toy Pascal-like language */
     
%{
/* need this for the call to atof() below */
#include <math.h>
#include "Y_TAB.h"
%}
     
     
%%
[1-9][0-9]*	|
[_A-z][_A-z0-9]*	{	return NUM_OR_ID;	}

"+"	|
"*"	|
"("	|
")"	|
"\n"	{	return yytext[0];	}

%%
     
int yywrap()
{ 
	return 1;
}
