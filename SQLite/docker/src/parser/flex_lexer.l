/**
 * lexer
 *
 *
 */


/***************************
 ** Section 1: Definitions
 ***************************/
%{


#include "bison_parser.h"
#include <stdio.h>
#include <sstream>

#define TOKEN(name) { return SQL_##name; }

static thread_local std::stringstream strbuf, blobstrbuf;
char* substr(const char* source, int from, int to);
%}
%x singlequotedstring
%x blobstring
%s btwand

  int old_condition = 0;
  int current_condition = 0;

/***************************
 ** Section 2: Rules
 ***************************/

/* Define the output files */
%option header-file="flex_lexer.h"
%option outfile="flex_lexer.cpp"

/* Make reentrant */
%option reentrant
%option bison-bridge

/* performance tweeks */
%option never-interactive
%option batch

/* other flags */
%option noyywrap
%option nounput
%option warn
%option case-insensitive
%option prefix="hsql_"
%option bison-locations 
/* %option nodefault */


%s COMMENT

/***************************
 ** Section 3: Rules
 ***************************/
%%

--				BEGIN(COMMENT);
<COMMENT>[^\n]*	/* skipping comment content until a end of line is read */;
<COMMENT>\n 	BEGIN(INITIAL);

[ \t\n]+	/* skip whitespace */;

DEALLOCATE	TOKEN(DEALLOCATE)
PARAMETERS	TOKEN(PARAMETERS)
INTERSECT	TOKEN(INTERSECT)
TEMPORARY	TOKEN(TEMPORARY)
TIMESTAMP	TOKEN(TIMESTAMP)
CURRENT_TIME TOKEN(CURRENT_TIME)
CURRENT_DATE TOKEN(CURRENT_DATE)
CURRENT_TIMESTAMP TOKEN(CURRENT_TIMESTAMP)
DESCRIBE	TOKEN(DESCRIBE)
DISTINCT	TOKEN(DISTINCT)
RESTRICT	TOKEN(RESTRICT)
TRUNCATE	TOKEN(TRUNCATE)
ANALYZE		TOKEN(ANALYZE)
CASCADE		TOKEN(CASCADE)
COLUMNS		TOKEN(COLUMNS)
CONTROL		TOKEN(CONTROL)
CONSTRAINT  TOKEN(CONSTRAINT)
DEFAULT		TOKEN(DEFAULT)
EXECUTE		TOKEN(EXECUTE)
EXPLAIN		TOKEN(EXPLAIN)
INTEGER		TOKEN(INTEGER)
NATURAL		TOKEN(NATURAL)
PREPARE		TOKEN(PREPARE)
PRIMARY		TOKEN(PRIMARY)
SCHEMAS		TOKEN(SCHEMAS)
SPATIAL		TOKEN(SPATIAL)
VIRTUAL		TOKEN(VIRTUAL)
STORED    TOKEN(STORED)
BEFORE		TOKEN(BEFORE)
COLUMN		TOKEN(COLUMN)
CREATE		TOKEN(CREATE)
DELETE		TOKEN(DELETE)
DIRECT		TOKEN(DIRECT)
DOUBLE		TOKEN(DOUBLE)
PRECISION TOKEN(PRECISION)
NUMERIC   TOKEN(NUMERIC)
NUM       TOKEN(NUM)
DECIMAL   TOKEN(DECIMAL)
ESCAPE		TOKEN(ESCAPE)
EXCEPT		TOKEN(EXCEPT)
EXISTS		TOKEN(EXISTS)
EXTRACT 	TOKEN(EXTRACT)
GLOBAL		TOKEN(GLOBAL)
HAVING		TOKEN(HAVING)
IMPORT		TOKEN(IMPORT)
INSERT		TOKEN(INSERT)
ISNULL		TOKEN(ISNULL)
OFFSET		TOKEN(OFFSET)
RENAME		TOKEN(RENAME)
SCHEMA		TOKEN(SCHEMA)
SELECT		TOKEN(SELECT)
SORTED		TOKEN(SORTED)
TABLES		TOKEN(TABLES)
UNIQUE		TOKEN(UNIQUE)
UNLOAD		TOKEN(UNLOAD)
UPDATE		TOKEN(UPDATE)
VALUES		TOKEN(VALUES)
AFTER		TOKEN(AFTER)
ALTER		TOKEN(ALTER)
ARRAY		TOKEN(ARRAY)
CROSS		TOKEN(CROSS)
DELTA		TOKEN(DELTA)
FLOAT		TOKEN(FLOAT)
GROUP		TOKEN(GROUP)
INDEX		TOKEN(INDEX)
INNER		TOKEN(INNER)
LIMIT		TOKEN(LIMIT)
LOCAL		TOKEN(LOCAL)
MERGE		TOKEN(MERGE)
MINUS		TOKEN(MINUS)
ORDER		TOKEN(ORDER)
OUTER		TOKEN(OUTER)
RIGHT		TOKEN(RIGHT)
TABLE		TOKEN(TABLE)
UNION		TOKEN(UNION)
USING		TOKEN(USING)
WHERE		TOKEN(WHERE)
CALL		TOKEN(CALL)
CASE		TOKEN(CASE)
CHAR		  TOKEN(CHAR)
CHARACTER TOKEN(CHARACTER)
NATIVE    TOKEN(NATIVE)
NCHAR     TOKEN(NCHAR)
VARYING   TOKEN(VARYING)
VARCHAR		TOKEN(VARCHAR)
NVARCHAR	TOKEN(NVARCHAR)
DATE		TOKEN(DATE)
DATETIME  TOKEN(DATETIME)
DESC		TOKEN(DESC)
DROP		TOKEN(DROP)
ELSE		TOKEN(ELSE)
FILE		TOKEN(FILE)
FROM		TOKEN(FROM)
FULL		TOKEN(FULL)
HASH		TOKEN(HASH)
HINT		TOKEN(HINT)
INTO		TOKEN(INTO)
JOIN		TOKEN(JOIN)
LEFT		TOKEN(LEFT)
LIKE		TOKEN(LIKE)
LOAD		TOKEN(LOAD)
LONG		TOKEN(LONG)
NULL		TOKEN(NULL)
PLAN		TOKEN(PLAN)
SHOW		TOKEN(SHOW)
TEXT		TOKEN(TEXT)
ANY		    TOKEN(ANY)
STRING		TOKEN(STRINGTOKEN)
CLOB    TOKEN(CLOB)
BLOB    TOKEN(BLOB)
THEN		TOKEN(THEN)
TIME		TOKEN(TIME)
VIEW		TOKEN(VIEW)
WHEN		TOKEN(WHEN)
WITH		TOKEN(WITH)
ADD			TOKEN(ADD)
ALL			TOKEN(ALL)
ASC			TOKEN(ASC)
CSV			TOKEN(CSV)
END			TOKEN(END)
FOR			TOKEN(FOR)
INT			TOKEN(INT)
INT2      TOKEN(INT2)
INT8			TOKEN(INT8)
TINYINT   TOKEN(TINYINT)
SMALLINT  TOKEN(SMALLINT)
MEDIUMINT TOKEN(MEDIUMINT)
BIGINT    TOKEN(BIGINT)
BIG       TOKEN(BIG)
UNSIGNED  TOKEN(UNSIGNED)
REAL		TOKEN(REAL)
BOOL    TOKEN(BOOL)
BOOLEAN TOKEN(BOOLEAN)
KEY			TOKEN(KEY)
NOT			TOKEN(NOT)
OFF			TOKEN(OFF)
SET			TOKEN(SET)
TOP			TOKEN(TOP)
AS			TOKEN(AS)
BY			TOKEN(BY)
IF			TOKEN(IF)
IN			TOKEN(IN)
IS			TOKEN(IS)
OF			TOKEN(OF)
ON			TOKEN(ON)
OR			TOKEN(OR)
TO			TOKEN(TO)
SECOND      TOKEN(SECOND)
MINUTE      TOKEN(MINUTE)
HOUR        TOKEN(HOUR)
DAY         TOKEN(DAY)
MONTH       TOKEN(MONTH)
YEAR        TOKEN(YEAR)

INDEXED		TOKEN(INDEXED)
PRAGMA		TOKEN(PRAGMA)
REINDEX		TOKEN(REINDEX)
GENERATED	TOKEN(GENERATED)
ALWAYS		TOKEN(ALWAYS)
CHECK		TOKEN(CHECK)
REFERENCES	TOKEN(REFERENCES)
CONFLICT	TOKEN(CONFLICT)
IGNORE		TOKEN(IGNORE)
REPLACE		TOKEN(REPLACE)
ROLLBACK	TOKEN(ROLLBACK)
ABORT		TOKEN(ABORT)
FAIL		TOKEN(FAIL)
AUTOINCR	TOKEN(AUTOINCR)
AUTOINCREMENT	TOKEN(AUTOINCREMENT)
BEGIN		TOKEN(BEGIN)
TRIGGER		TOKEN(TRIGGER)
TEMP		TOKEN(TEMP)
INSTEAD		TOKEN(INSTEAD)
EACH		TOKEN(EACH)
ROW			TOKEN(ROW)
OVER		TOKEN(OVER)
FILTER		TOKEN(FILTER)
CURRENT		TOKEN(CURRENT)
EXCLUDE		TOKEN(EXCLUDE)
FOLLOWING	TOKEN(FOLLOWING)
GROUPS		TOKEN(GROUPS)
NO			TOKEN(NO)
OTHERS		TOKEN(OTHERS)
PRECEDING	TOKEN(PRECEDING)
RANGE		TOKEN(RANGE)
ROWS		TOKEN(ROWS)
TIES		TOKEN(TIES)
UNBOUNDED	TOKEN(UNBOUNDED)
WINDOW		TOKEN(WINDOW)
PARTITION	TOKEN(PARTITION)
ATTACH		TOKEN(ATTACH)
DETACH		TOKEN(DETACH)
DATABASE	TOKEN(DATABASE)
CAST		TOKEN(CAST)
SAVEPOINT	TOKEN(SAVEPOINT)
RELEASE		TOKEN(RELEASE)

VACUUM 		TOKEN(VACUUM)
TRANSACTION TOKEN(TRANSACTION)
DEFERRABLE  TOKEN(DEFERRABLE)
DEFERRED    TOKEN(DEFERRED)
IMMEDIATE   TOKEN(IMMEDIATE)
FOREIGN     TOKEN(FOREIGN)
INITIALLY   TOKEN(INITIALLY)
ACTION      TOKEN(ACTION)
DEFFERED 	TOKEN(DEFFERED)
EXCLUSIVE 	TOKEN(EXCLUSIVE)
IMEDIATE 	TOKEN(IMEDIATE)
COMMIT 		TOKEN(COMMIT)
GLOB 		TOKEN(GLOB)
MATCH 		TOKEN(MATCH)
REGEXP 		TOKEN(REGEXP)
NOTHING 	TOKEN(NOTHING)
NULLS 		TOKEN(NULLS)
LAST 		TOKEN(LAST)
FIRST 		TOKEN(FIRST)
DO 			TOKEN(DO)
COLLATE 	TOKEN(COLLATE)
WITHOUT		TOKEN(WITHOUT)
ROWID		TOKEN(ROWID)
STRICT		TOKEN(STRICT)
_ROWID_		TOKEN(ROWID)
RAISE   TOKEN(RAISE)
RECURSIVE TOKEN(RECURSIVE)
RETURNING TOKEN(RETURNING)

TRUE		TOKEN(TRUE)
FALSE		TOKEN(FALSE)

                /* Allow =/== see https://sqlite.org/lang_expr.html#collateop */
"=="		TOKEN(EQUALS)
"!=" 		TOKEN(NOTEQUALS)
"<>" 		TOKEN(NOTEQUALS)
"<="		TOKEN(LESSEQ)
">="		TOKEN(GREATEREQ)
"||"		TOKEN(CONCAT)

">>"    TOKEN(RSHIFT)
"<<"    TOKEN(LSHIFT)

BETWEEN	  { BEGIN btwand; current_condition = YY_START; return SQL_BETWEEN; }
<btwand>AND  { BEGIN INITIAL; current_condition = YY_START; return SQL_BTWAND; }

AND			{ return SQL_AND; }

[-+*/(){},.;<>=^%:?[\]|]	{ return yytext[0]; }

[0-9]+"."[0-9]*[eE][+-]?[0-9]+ |
"."[0-9]+[eE][+-]?[0-9]+ |
[0-9]+[eE][+-]?[0-9]+ {   /* exponentiation clause */
  yylval->sval = strdup(yytext);
  return SQL_EXPVAL;
}

[0-9]+	{   /* Integer */
	yylval->ival = atol(yytext);
	return SQL_INTVAL;
}

[0-9]+"."[0-9]* |
"."[0-9]+	{ /* Floating point */
	yylval->fval = atof(yytext);
	return SQL_FLOATVAL;
}

0x[0-9A-Fa-f]+ {
  yylval->sval = strdup(yytext);
  return SQL_HEXVAL;
}

\"[^\"\n]+\" {
	// Crop the leading and trailing quote char
	yylval->sval = substr(yytext, 1, strlen(yytext)-1);
	return SQL_IDENTIFIER;
}

[xX]\'              { old_condition = current_condition; BEGIN blobstring; blobstrbuf = std::stringstream{}; }
<blobstring>\'\'    { blobstrbuf << '\''; }
<blobstring>[^']*   { blobstrbuf << yytext; }
<blobstring>\'      { current_condition = old_condition; BEGIN (old_condition); yylval->sval = strdup(blobstrbuf.str().c_str()); return SQL_BLOBSTRING; }
<blobstring><<EOF>> {  /*fprintf(stdout, "[SQL-Lexer-Error] Unterminated string\n"); */ return 0; }

[A-Za-z][A-Za-z0-9_]* {
	yylval->sval = strdup(yytext);
	return SQL_IDENTIFIER;
}

\'                          { old_condition = current_condition; 
                              //printf("++ current_condition: %d, old_condition: %d\n", current_condition, old_condition); 
                              BEGIN singlequotedstring; 
                              strbuf = std::stringstream{}; 
                            }
<singlequotedstring>\'\'    { strbuf << '\''; }
<singlequotedstring>[^']*   { strbuf << yytext; }
<singlequotedstring>\'      { current_condition = old_condition; 
                              //printf("-- current_condition: %d, old_condition: %d\n", current_condition, old_condition); 
                              BEGIN (old_condition); 
                              yylval->sval = strdup(strbuf.str().c_str()); 
                              return SQL_STRING;
                            }
<singlequotedstring><<EOF>> {  /*fprintf(stdout, "[SQL-Lexer-Error] Unterminated string\n"); */ return 0; }

. { /*fprintf(stdout, "[SQL-Lexer-Error] Unknown Character: %c\n", yytext[0]); */ return 0; }


%%
/***************************
 ** Section 3: User code
 ***************************/

char* substr(const char* source, int from, int to) {
    int len = to - from;
    char* copy = (char*)malloc(len + 1);
    ;
    strncpy(copy, source + from, len);
    copy[len] = '\0';
    return copy;
}

int yyerror(const char *msg) {
    fprintf(stdout, "[SQL-Lexer-Error] %s\n",msg); return 0;
}
