%{
#include <stdio.h>
FILE *hyplink;
%}
%x FORM
%x LINK
%x SCPT
%x STYLE
%%
("<"[sS][cC][rR][iI][pP][tT][^>]*">") 	 	BEGIN(SCPT);
<SCPT>("</"[sS][cC][rR][iI][pP][tT][^>]*">")  	BEGIN(INITIAL);
("<"[sS][tT][yY][lL][eE][^>]*">") 	 	BEGIN(STYLE);
<STYLE>("</"[sS][tT][yY][lL][eE][^>]*">")  	BEGIN(INITIAL);
("<"[fF][oO][rR][mM][^>]*">") 	 		BEGIN(FORM);
<FORM>("</"[fF][oO][rR][mM][^>]*">")  		BEGIN(INITIAL);
"<"[Aa] 					BEGIN(LINK);
<LINK>">" 					BEGIN(INITIAL);

<LINK>[hH][rR][eE][fF][ \t\r\n]*"="[ \t\r\n]*["'][^ '"\t\r\n>]+ {
			char *s;
			s = strchr(yytext,'=');
			fprintf(hyplink, "%s\n", s+2);
		}
<LINK>[hH][rR][eE][fF][ \t\r\n]*"="[ \t\r\n]*[^ '"\t\r\n>]+ {
			char *s;
			s = strchr(yytext,'=');
			fprintf(hyplink, "%s\n", s+1);
		}
<SCPT,STYLE,LINK,FORM>.|\n 	;

("<"[^aA][^>]*">") 		;

&qot[;]?	fprintf( hyplink, "'" );
&gt[;]?		fprintf( hyplink, ">" );
&lt[;]?		fprintf( hyplink, "<" );
&amp[;]?	fprintf( hyplink, "&" );
&nbsp[;]?	fprintf( hyplink, " " );

[\t ]*		;
%%

main( argc, argv )
int argc;
char **argv;
{
	++argv, --argc;
	if ( argc > 0 ) {
		if ((yyin = fopen( argv[0], "rb" )) == NULL) {
			printf("the file %s could'nt open!\n", argv[0]);
			exit (0);
		}
	}
	else
	yyin = stdin;
	if ((hyplink = fopen("hyplink.txt", "w")) == NULL) {
		printf("coud'nt create hyperlink file!\n");
		exit(0);
	}
	yylex();
	fclose(yyin);
	fclose(hyplink);
}



int yywrap()
{
	return 1;
}

