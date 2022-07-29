
%{

/*#define YYDEBUG 1*/
/*-------------------------------------------------------------------------
 *
 * gram.y
 *	  POSTGRESQL BISON rules/actions
 *
 * Portions Copyright (c) 1996-2021, PostgreSQL Global Development Group
 * Portions Copyright (c) 1994, Regents of the University of California
 *
 *
 * IDENTIFICATION
 *	  src/backend/parser/gram.y
 *
 * HISTORY
 *	  AUTHOR			DATE			MAJOR EVENT
 *	  Andrew Yu			Sept, 1994		POSTQUEL to SQL conversion
 *	  Andrew Yu			Oct, 1994		lispy code conversion
 *
 * NOTES
 *	  CAPITALS are used to represent terminal symbols.
 *	  non-capitals are used to represent non-terminals.
 *
 *	  In general, nothing in this file should initiate database accesses
 *	  nor depend on changeable state (such as SET variables).  If you do
 *	  database accesses, your code will fail when we have aborted the
 *	  current transaction and are just parsing commands to find the next
 *	  ROLLBACK or COMMIT.  If you make use of SET variables, then you
 *	  will do the wrong thing in multi-query strings like this:
 *			SET constraint_exclusion TO off; SELECT * FROM foo;
 *	  because the entire string is parsed by gram.y before the SET gets
 *	  executed.  Anything that depends on the database or changeable state
 *	  should be handled during parse analysis so that it happens at the
 *	  right time not the wrong time.
 *
 * WARNINGS
 *	  If you use a list, make sure the datum is a node so that the printing
 *	  routines work.
 *
 *	  Sometimes we assign constants to makeStrings. Make sure we don't free
 *	  those.
 *
 *-------------------------------------------------------------------------
 */
#include "postgres.h"

#include <ctype.h>
#include <limits.h>
#include <vector>
#include <string>

#include "../include/ast.h"
#include "../include/relopt_generator.h"
//#include "access/tableam.h"
//#include "catalog/index.h"
//#include "catalog/namespace.h"
#include "catalog/pg_am.h"
#include "catalog/pg_trigger.h"
#include "commands/defrem.h"
//#include "commands/trigger.h"
//#include "nodes/makefuncs.h"
//#include "nodes/nodeFuncs.h"
#include "parser/gramparse.h"
#include "parser/parser.h"
//#include "storage/lmgr.h"
#include "utils/date.h"
#include "utils/datetime.h"
#include "utils/numeric.h"
//#include "utils/xml.h"
#include "../include/define.h"


#define palloc    malloc
#define pfree     free
#define repalloc  realloc
#define pstrdup   strdup

/*
 * Location tracking support --- simpler than bison's default, since we only
 * want to track the start position not the end position of each nonterminal.
 */
#define YYLLOC_DEFAULT(Current, Rhs, N) \
	do { \
		if ((N) > 0) \
			(Current) = (Rhs)[1]; \
		else \
			(Current) = (-1); \
	} while (0)

/*
 * The above macro assigns -1 (unknown) as the parse location of any
 * nonterminal that was reduced from an empty rule, or whose leftmost
 * component was reduced from an empty rule.  This is problematic
 * for nonterminals defined like
 *		OptFooList: / * EMPTY * / { ... } | OptFooList Foo { ... } ;
 * because we'll set -1 as the location during the first reduction and then
 * copy it during each subsequent reduction, leaving us with -1 for the
 * location even when the list is not empty.  To fix that, do this in the
 * action for the nonempty rule(s):
 *		if (@$ < 0) @$ = @2;
 * (Although we have many nonterminals that follow this pattern, we only
 * bother with fixing @$ like this when the nonterminal's parse location
 * is actually referenced in some rule.)
 *
 * A cleaner answer would be to make YYLLOC_DEFAULT scan all the Rhs
 * locations until it's found one that's not -1.  Then we'd get a correct
 * location for any nonterminal that isn't entirely empty.  But this way
 * would add overhead to every rule reduction, and so far there's not been
 * a compelling reason to pay that overhead.
 */

/*
 * Bison doesn't allocate anything that needs to live across parser calls,
 * so we can easily have it use palloc instead of malloc.  This prevents
 * memory leaks if we error out during parsing.  Note this only works with
 * bison >= 2.0.  However, in bison 1.875 the default is to use alloca()
 * if possible, so there's not really much problem anyhow, at least if
 * you're building with gcc.
 */
#define YYMALLOC palloc
#define YYFREE   pfree

/* Private struct for the result of privilege_target production */
typedef struct PrivTarget
{
	GrantTargetType targtype;
	ObjectType	objtype;
	List	   *objs;
} PrivTarget;

/* Private struct for the result of import_qualification production */
typedef struct ImportQual
{
	ImportForeignSchemaType type;
	List	   *table_names;
} ImportQual;

/* Private struct for the result of opt_select_limit production */
typedef struct SelectLimit
{
	Node *limitOffset;
	Node *limitCount;
	LimitOption limitOption;
} SelectLimit;

/* Private struct for the result of group_clause production */
typedef struct GroupClause
{
	bool	distinct;
	List   *list;
} GroupClause;

/* ConstraintAttributeSpec yields an integer bitmask of these flags: */
#define CAS_NOT_DEFERRABLE			0x01
#define CAS_DEFERRABLE				0x02
#define CAS_INITIALLY_IMMEDIATE		0x04
#define CAS_INITIALLY_DEFERRED		0x08
#define CAS_NOT_VALID				0x10
#define CAS_NO_INHERIT				0x20


#define parser_yyerror(msg)  scanner_yyerror(msg, yyscanner)
#define parser_errposition(pos)  scanner_errposition(pos, yyscanner)

static void base_yyerror(YYLTYPE *yylloc, IR* result, IR **pIR, vector<IR*> all_gen_ir, vector<IR*> rov_ir,
            core_yyscan_t yyscanner, const char *msg);
static char* alloc_and_cat(const char*, const char*);
static char* alloc_and_cat(const char*, const char*, const char*);

%}

%define api.pure
%expect 0
// JUST USE THE OLD STYLE, PLEASE!!!!
%name-prefix="base_yy"
//%define api.prefix {base_yy}
%locations

%parse-param {IR* res} {IR **pIR} {vector<IR*> all_gen_ir} {vector<IR*>& rov_ir } {core_yyscan_t yyscanner}
%lex-param   {core_yyscan_t yyscanner}

%union
{
	core_YYSTYPE		core_yystype;
	/* these fields must match core_YYSTYPE: */
	int					ival;
	char				*str;
	const char			*keyword;

	IR                  *ir;
}

%type <ir>	stmt toplevel_stmt schema_stmt routine_body_stmt
		AlterEventTrigStmt AlterCollationStmt
		AlterDatabaseStmt AlterDatabaseSetStmt AlterDomainStmt AlterEnumStmt
		AlterFdwStmt AlterForeignServerStmt AlterGroupStmt
		AlterObjectDependsStmt AlterObjectSchemaStmt AlterOwnerStmt
		AlterOperatorStmt AlterTypeStmt AlterSeqStmt AlterSystemStmt AlterTableStmt
		AlterTblSpcStmt AlterExtensionStmt AlterExtensionContentsStmt
		AlterCompositeTypeStmt AlterUserMappingStmt
		AlterRoleStmt AlterRoleSetStmt AlterPolicyStmt AlterStatsStmt
		AlterDefaultPrivilegesStmt DefACLAction
		AnalyzeStmt CallStmt ClosePortalStmt ClusterStmt CommentStmt
		ConstraintsSetStmt CopyStmt CreateAsStmt CreateCastStmt
		CreateDomainStmt CreateExtensionStmt CreateGroupStmt CreateOpClassStmt
		CreateOpFamilyStmt AlterOpFamilyStmt CreatePLangStmt
		CreateSchemaStmt CreateSeqStmt CreateStmt CreateStatsStmt CreateTableSpaceStmt
		CreateFdwStmt CreateForeignServerStmt CreateForeignTableStmt
		CreateAssertionStmt CreateTransformStmt CreateTrigStmt CreateEventTrigStmt
		CreateUserStmt CreateUserMappingStmt CreateRoleStmt CreatePolicyStmt
		CreatedbStmt DeclareCursorStmt DefineStmt DeleteStmt DiscardStmt DoStmt
		DropOpClassStmt DropOpFamilyStmt DropStmt
		DropCastStmt DropRoleStmt
		DropdbStmt DropTableSpaceStmt
		DropTransformStmt
		DropUserMappingStmt ExplainStmt FetchStmt
		GrantStmt GrantRoleStmt ImportForeignSchemaStmt IndexStmt InsertStmt
		ListenStmt LoadStmt LockStmt NotifyStmt ExplainableStmt PreparableStmt
		CreateFunctionStmt AlterFunctionStmt ReindexStmt RemoveAggrStmt
		RemoveFuncStmt RemoveOperStmt RenameStmt ReturnStmt RevokeStmt RevokeRoleStmt
		RuleActionStmt RuleActionStmtOrEmpty RuleStmt
		SecLabelStmt SelectStmt TransactionStmt TransactionStmtLegacy TruncateStmt
		UnlistenStmt UpdateStmt VacuumStmt
		VariableResetStmt VariableSetStmt VariableShowStmt
		ViewStmt CheckPointStmt CreateConversionStmt
		DeallocateStmt PrepareStmt ExecuteStmt
		DropOwnedStmt ReassignOwnedStmt
		AlterTSConfigurationStmt AlterTSDictionaryStmt
		CreateMatViewStmt RefreshMatViewStmt CreateAmStmt
		CreatePublicationStmt AlterPublicationStmt
		CreateSubscriptionStmt AlterSubscriptionStmt DropSubscriptionStmt

%type <ir>	select_no_parens select_with_parens select_clause
				simple_select values_clause
				PLpgSQL_Expr PLAssignStmt

%type <ir>	alter_column_default opclass_item opclass_drop alter_using
%type <ir>	add_drop opt_asc_desc opt_nulls_order

%type <ir>	alter_table_cmd alter_type_cmd opt_collate_clause
	   replica_identity partition_cmd index_partition_cmd
%type <ir>	alter_table_cmds alter_type_cmds
%type <ir>    alter_identity_column_option_list
%type <ir>  alter_identity_column_option

%type <ir>	opt_drop_behavior

%type <ir>	createdb_opt_list createdb_opt_items copy_opt_list
				transaction_mode_list
				create_extension_opt_list alter_extension_opt_list
%type <ir>	createdb_opt_item copy_opt_item
				transaction_mode_item
				create_extension_opt_item alter_extension_opt_item

%type <ir>	opt_lock lock_type cast_context
%type <str>		utility_option_name
%type <ir>	utility_option_elem
%type <ir>	utility_option_list
%type <ir>	utility_option_arg
%type <ir>	drop_option
%type <ir>	opt_or_replace opt_no
				opt_grant_grant_option opt_grant_admin_option
				opt_nowait opt_if_exists opt_with_data
				opt_transaction_chain
%type <ir>	opt_nowait_or_skip

%type <ir>	OptRoleList AlterOptRoleList
%type <ir>	CreateOptRoleElem AlterOptRoleElem

%type <ir>		opt_type
%type <ir>		foreign_server_version opt_foreign_server_version
%type <ir>		opt_in_database

%type <ir>		OptSchemaName
%type <ir>	OptSchemaEltList

%type <ir>		am_type

%type <ir> TriggerForSpec TriggerForType
%type <ir>	TriggerActionTime
%type <ir>	TriggerEvents TriggerOneEvent
%type <ir>	TriggerFuncArg
%type <ir>	TriggerWhen
%type <ir>		TransitionRelName
%type <ir>	TransitionRowOrTable TransitionOldOrNew
%type <ir>	TriggerTransition

%type <ir>	event_trigger_when_list event_trigger_value_list
%type <ir>	event_trigger_when_item
%type <ir>		enable_trigger

%type <ir>		copy_file_name
				access_method_clause
				table_access_method_clause
				opt_index_name cluster_index_specification

%type <str>     attr_name name cursor_name file_name

%type <ir>	func_name handler_name qual_Op qual_all_Op subquery_Op
				opt_class opt_inline_handler opt_validator validator_clause
				opt_collate

%type <ir>	qualified_name insert_target OptConstrFromTable

%type <ir>		all_Op MathOp

%type <ir>		row_security_cmd RowSecurityDefaultForCmd
%type <ir> RowSecurityDefaultPermissive
%type <ir>	RowSecurityOptionalWithCheck RowSecurityOptionalExpr
%type <ir>	RowSecurityDefaultToRole RowSecurityOptionalToRole

%type <ir>		iso_level opt_encoding
%type <ir> grantee
%type <ir>	grantee_list
%type <ir> privilege
%type <ir>	privileges privilege_list
%type <ir> privilege_target
%type <ir> function_with_argtypes aggregate_with_argtypes operator_with_argtypes
%type <ir>	function_with_argtypes_list aggregate_with_argtypes_list operator_with_argtypes_list
%type <ir>	defacl_privilege_target
%type <ir>	DefACLOption
%type <ir>	DefACLOptionList
%type <ir>	import_qualification_type
%type <ir> import_qualification
%type <ir>	vacuum_relation
%type <ir> opt_select_limit select_limit limit_clause

%type <ir>	parse_toplevel stmtmulti routine_body_stmt_list
				OptTableElementList TableElementList OptInherit definition
				OptTypedTableElementList TypedTableElementList
				reloptions opt_reloptions
				OptWith opt_definition func_args func_args_list
				func_args_with_defaults func_args_with_defaults_list
				aggr_args aggr_args_list
				func_as createfunc_opt_list opt_createfunc_opt_list alterfunc_opt_list
				old_aggr_definition old_aggr_list
				oper_argtypes RuleActionList RuleActionMulti
				opt_column_list columnList opt_name_list
				sort_clause opt_sort_clause sortby_list index_params stats_params
				opt_include opt_c_include index_including_params
				name_list role_list from_clause from_list opt_array_bounds
				qualified_name_list any_name any_name_list type_name_list
				any_operator expr_list attrs
				distinct_clause opt_distinct_clause
				target_list opt_target_list insert_column_list set_target_list
				set_clause_list set_clause
				def_list operator_def_list indirection opt_indirection
				reloption_list TriggerFuncArgs opclass_item_list opclass_drop_list
				opclass_purpose opt_opfamily transaction_mode_list_or_empty
				OptTableFuncElementList TableFuncElementList opt_type_modifiers
				prep_type_clause
				execute_param_clause using_clause returning_clause
				opt_enum_val_list enum_val_list table_func_column_list
				create_generic_options alter_generic_options
				relation_expr_list dostmt_opt_list
				transform_element_list transform_type_list
				TriggerTransitions TriggerReferencing
				vacuum_relation_list opt_vacuum_relation_list
				drop_option_list

%type <ir>	opt_routine_body
%type <ir> group_clause
%type <ir>	group_by_list
%type <ir>	group_by_item empty_grouping_set rollup_clause cube_clause
%type <ir>	grouping_sets_clause
%type <ir>	opt_publication_for_tables publication_for_tables

%type <ir>	opt_fdw_options fdw_options
%type <ir>	fdw_option

%type <ir>	OptTempTableName
%type <ir>	into_clause create_as_target create_mv_target

%type <ir>	createfunc_opt_item common_func_opt_item dostmt_opt_item
%type <ir> func_arg func_arg_with_default table_func_column aggr_arg
%type <ir> arg_class
%type <ir>	func_return func_type

%type <ir>  opt_trusted opt_restart_seqs
%type <ir>	 OptTemp
%type <ir>	 OptNoLog
%type <ir> OnCommitOption

%type <ir>	for_locking_strength
%type <ir>	for_locking_item
%type <ir>	for_locking_clause opt_for_locking_clause for_locking_items
%type <ir>	locked_rels_list
%type <ir> set_quantifier

%type <ir>	join_qual
%type <ir>	join_type

%type <ir>	extract_list overlay_list position_list
%type <ir>	substr_list trim_list
%type <ir>	opt_interval interval_second
%type <ir>		unicode_normal_form

%type <ir> opt_instead
%type <ir> opt_unique opt_concurrently opt_verbose opt_full
%type <ir> opt_freeze opt_analyze opt_default opt_recheck
%type <ir>	opt_binary copy_delimiter

%type <ir> copy_from opt_program

%type <ir>	event cursor_options opt_hold opt_set_data
%type <ir>	object_type_any_name object_type_name object_type_name_on_any_name
				drop_type_name

%type <ir>	fetch_args select_limit_value
				offset_clause select_offset_value
				select_fetch_first_value I_or_F_const
%type <ir>	row_or_rows first_or_next

%type <ir>	OptSeqOptList SeqOptList OptParenthesizedSeqOptList
%type <ir>	SeqOptElem

%type <ir>	insert_rest
%type <ir>	opt_conf_expr
%type <ir> opt_on_conflict

%type <ir> generic_set set_rest set_rest_more generic_reset reset_rest
				 SetResetClause FunctionSetResetClause

%type <ir>	TableElement TypedTableElement ConstraintElem TableFuncElement
%type <ir>	columnDef columnOptions
%type <ir>	def_elem reloption_elem old_aggr_elem operator_def_elem
%type <ir>	def_arg columnElem where_clause where_or_current_clause
				a_expr b_expr c_expr AexprConst indirection_el opt_slice_bound
				columnref in_expr having_clause func_table xmltable array_expr
				OptWhereClause operator_def_arg
%type <ir>	rowsfrom_item rowsfrom_list opt_col_def_list
%type <ir> opt_ordinality
%type <ir>	ExclusionConstraintList ExclusionConstraintElem
%type <ir>	func_arg_list func_arg_list_opt
%type <ir>	func_arg_expr
%type <ir>	row explicit_row implicit_row type_list array_expr_list
%type <ir>	case_expr case_arg when_clause case_default
%type <ir>	when_clause_list
%type <ir>	opt_search_clause opt_cycle_clause
%type <ir>	sub_type opt_materialized
%type <ir>	NumericOnly
%type <ir>	NumericOnly_list
%type <ir>	alias_clause opt_alias_clause opt_alias_clause_for_join_using
%type <ir>	func_alias_clause
%type <ir>	sortby
%type <ir>	index_elem index_elem_options
%type <ir>	stats_param
%type <ir>	table_ref
%type <ir>	joined_table
%type <ir>	relation_expr
%type <ir>	relation_expr_opt_alias
%type <ir>	tablesample_clause opt_repeatable_clause
%type <ir>	target_el set_target insert_column_item

%type <str>		generic_option_name
%type <ir>	generic_option_arg
%type <ir>	generic_option_elem alter_generic_option_elem
%type <ir>	generic_option_list alter_generic_option_list

%type <ir>	reindex_target_type reindex_target_multitable

%type <ir>	copy_generic_opt_arg copy_generic_opt_arg_list_item
%type <ir>	copy_generic_opt_elem
%type <ir>	copy_generic_opt_list copy_generic_opt_arg_list
%type <ir>	copy_options

%type <ir>	Typename SimpleTypename ConstTypename
				GenericType Numeric opt_float
				Character ConstCharacter
				CharacterWithLength CharacterWithoutLength
				ConstDatetime ConstInterval
				Bit ConstBit BitWithLength BitWithoutLength
%type <ir>		character
%type <ir>		extract_arg
%type <ir> opt_varying opt_timezone opt_no_inherit

%type <ir>	Iconst SignedIconst
%type <str>		Sconst comment_text notify_payload
%type <str>		RoleId opt_boolean_or_string
%type <ir>	var_list
%type <str>		ColId ColLabel BareColLabel
%type <str>		NonReservedWord NonReservedWord_or_Sconst
%type <str>		var_name type_function_name param_name
%type <ir>		createdb_opt_name plassign_target
%type <ir>	var_value zone_value
%type <ir> auth_ident  opt_granted_by
%type <str> RoleSpec

%type <str> unreserved_keyword type_func_name_keyword
%type <str> col_name_keyword reserved_keyword
%type <str> bare_label_keyword

%type <ir>	TableConstraint TableLikeClause
%type <ir>	TableLikeOptionList TableLikeOption
%type <ir>		column_compression opt_column_compression
%type <ir>	ColQualList
%type <ir>	ColConstraint ColConstraintElem ConstraintAttr
%type <ir>	key_actions key_delete key_match key_update key_action
%type <ir>	ConstraintAttributeSpec ConstraintAttributeElem
%type <ir>		ExistingIndex

%type <ir>	constraints_set_list
%type <ir> constraints_set_mode
%type <ir>		OptTableSpace OptConsTableSpace
%type <ir> OptTableSpaceOwner
%type <ir>	opt_check_option

%type <ir>		opt_provider security_label

%type <ir>	xml_attribute_el
%type <ir>	xml_attribute_list xml_attributes
%type <ir>	xml_root_version opt_xml_root_standalone
%type <ir>	xmlexists_argument
%type <ir>	document_or_content
%type <ir> xml_whitespace_option
%type <ir>	xmltable_column_list xmltable_column_option_list
%type <ir>	xmltable_column_el
%type <ir>	xmltable_column_option_el
%type <ir>	xml_namespace_list
%type <ir>	xml_namespace_el

%type <ir>	func_application func_expr_common_subexpr
%type <ir>	func_expr func_expr_windowless
%type <ir>	common_table_expr
%type <ir>	with_clause opt_with_clause
%type <ir>	cte_list

%type <ir>	within_group_clause
%type <ir>	filter_clause
%type <ir>	window_clause window_definition_list opt_partition_clause
%type <ir>	window_definition over_clause window_specification
				opt_frame_clause frame_extent frame_bound
%type <ir>	opt_window_exclusion_clause
%type <ir>		opt_existing_window_name
%type <ir> opt_if_not_exists
%type <ir>	generated_when override_kind
%type <ir>	PartitionSpec OptPartitionSpec
%type <ir>	part_elem
%type <ir>		part_params
%type <ir> PartitionBoundSpec
%type <ir>		hash_partbound
%type <ir>		hash_partbound_elem

%type <ir> opt_with opt_as opt_using opt_procedural from_in opt_from_in opt_transaction
%type <ir> plassign_equals opt_column opt_by FUNCTION_or_PROCEDURE TriggerForOptEach xml_passing_mech
%type <ir> opt_outer opt_table opt_restrict opt_equal any_with opt_all_clause opt_asymmetric

%type <str> analyze_keyword


/*
 * Non-keyword token types.  These are hard-wired into the "flex" lexer.
 * They must be listed first so that their numeric codes do not depend on
 * the set of keywords.  PL/pgSQL depends on this so that it can share the
 * same lexer.  If you add/change tokens here, fix PL/pgSQL to match!
 *
 * UIDENT and USCONST are reduced to IDENT and SCONST in parser.c, so that
 * they need no productions here; but we must assign token codes to them.
 *
 * DOT_DOT is unused in the core SQL grammar, and so will always provoke
 * parse errors.  It is needed by PL/pgSQL.
 */
%token <str>	IDENT UIDENT FCONST SCONST USCONST BCONST XCONST Op
%token <ir>	PARAM
%token <ival>   ICONST
%token			TYPECAST DOT_DOT COLON_EQUALS EQUALS_GREATER
%token			LESS_EQUALS GREATER_EQUALS NOT_EQUALS

/*
 * If you want to make any keyword changes, update the keyword table in
 * src/include/parser/kwlist.h and add new keywords to the appropriate one
 * of the reserved-or-not-so-reserved keyword lists, below; search
 * this file for "Keyword category lists".
 */

/* ordinary key words in alphabetical order */
%token <str> ABORT_P ABSOLUTE_P ACCESS ACTION ADD_P ADMIN AFTER
	AGGREGATE ALL ALSO ALTER ALWAYS ANALYSE ANALYZE AND ANY ARRAY AS ASC
	ASENSITIVE ASSERTION ASSIGNMENT ASYMMETRIC ATOMIC AT ATTACH ATTRIBUTE AUTHORIZATION

	BACKWARD BEFORE BEGIN_P BETWEEN BIGINT BINARY BIT
	BOOLEAN_P BOTH BREADTH BY

	CACHE CALL CALLED CASCADE CASCADED CASE CAST CATALOG_P CHAIN CHAR_P
	CHARACTER CHARACTERISTICS CHECK CHECKPOINT CLASS CLOSE
	CLUSTER COALESCE COLLATE COLLATION COLUMN COLUMNS COMMENT COMMENTS COMMIT
	COMMITTED COMPRESSION CONCURRENTLY CONFIGURATION CONFLICT
	CONNECTION CONSTRAINT CONSTRAINTS CONTENT_P CONTINUE_P CONVERSION_P COPY
	COST CREATE CROSS CSV CUBE CURRENT_P
	CURRENT_CATALOG CURRENT_DATE CURRENT_ROLE CURRENT_SCHEMA
	CURRENT_TIME CURRENT_TIMESTAMP CURRENT_USER CURSOR CYCLE

	DATA_P DATABASE DAY_P DEALLOCATE DEC DECIMAL_P DECLARE DEFAULT DEFAULTS
	DEFERRABLE DEFERRED DEFINER DELETE_P DELIMITER DELIMITERS DEPENDS DEPTH DESC
	DETACH DICTIONARY DISABLE_P DISCARD DISTINCT DO DOCUMENT_P DOMAIN_P
	DOUBLE_P DROP

	EACH ELSE ENABLE_P ENCODING ENCRYPTED END_P ENUM_P ESCAPE EVENT EXCEPT
	EXCLUDE EXCLUDING EXCLUSIVE EXECUTE EXISTS EXPLAIN EXPRESSION
	EXTENSION EXTERNAL EXTRACT

	FALSE_P FAMILY FETCH FILTER FINALIZE FIRST_P FLOAT_P FOLLOWING FOR
	FORCE FOREIGN FORWARD FREEZE FROM FULL FUNCTION FUNCTIONS

	GENERATED GLOBAL GRANT GRANTED GREATEST GROUP_P GROUPING GROUPS

	HANDLER HAVING HEADER_P HOLD HOUR_P

	IDENTITY_P IF_P ILIKE IMMEDIATE IMMUTABLE IMPLICIT_P IMPORT_P IN_P INCLUDE
	INCLUDING INCREMENT INDEX INDEXES INHERIT INHERITS INITIALLY INLINE_P
	INNER_P INOUT INPUT_P INSENSITIVE INSERT INSTEAD INT_P INTEGER
	INTERSECT INTERVAL INTO INVOKER IS ISNULL ISOLATION

	JOIN

	KEY

	LABEL LANGUAGE LARGE_P LAST_P LATERAL_P
	LEADING LEAKPROOF LEAST LEFT LEVEL LIKE LIMIT LISTEN LOAD LOCAL
	LOCALTIME LOCALTIMESTAMP LOCATION LOCK_P LOCKED LOGGED

	MAPPING MATCH MATERIALIZED MAXVALUE METHOD MINUTE_P MINVALUE MODE MONTH_P MOVE

	NAME_P NAMES NATIONAL NATURAL NCHAR NEW NEXT NFC NFD NFKC NFKD NO NONE
	NORMALIZE NORMALIZED
	NOT NOTHING NOTIFY NOTNULL NOWAIT NULL_P NULLIF
	NULLS_P NUMERIC

	OBJECT_P OF OFF OFFSET OIDS OLD ON ONLY OPERATOR OPTION OPTIONS OR
	ORDER ORDINALITY OTHERS OUT_P OUTER_P
	OVER OVERLAPS OVERLAY OVERRIDING OWNED OWNER

	PARALLEL PARSER PARTIAL PARTITION PASSING PASSWORD PLACING PLANS POLICY
	POSITION PRECEDING PRECISION PRESERVE PREPARE PREPARED PRIMARY
	PRIOR PRIVILEGES PROCEDURAL PROCEDURE PROCEDURES PROGRAM PUBLICATION

	QUOTE

	RANGE READ REAL REASSIGN RECHECK RECURSIVE REF REFERENCES REFERENCING
	REFRESH REINDEX RELATIVE_P RELEASE RENAME REPEATABLE REPLACE REPLICA
	RESET RESTART RESTRICT RETURN RETURNING RETURNS REVOKE RIGHT ROLE ROLLBACK ROLLUP
	ROUTINE ROUTINES ROW ROWS RULE

	SAVEPOINT SCHEMA SCHEMAS SCROLL SEARCH SECOND_P SECURITY SELECT SEQUENCE SEQUENCES
	SERIALIZABLE SERVER SESSION SESSION_USER SET SETS SETOF SHARE SHOW
	SIMILAR SIMPLE SKIP SMALLINT SNAPSHOT SOME SQL_P STABLE STANDALONE_P
	START STATEMENT STATISTICS STDIN STDOUT STORAGE STORED STRICT_P STRIP_P
	SUBSCRIPTION SUBSTRING SUPPORT SYMMETRIC SYSID SYSTEM_P

	TABLE TABLES TABLESAMPLE TABLESPACE TEMP TEMPLATE TEMPORARY TEXT_P THEN
	TIES TIME TIMESTAMP TO TRAILING TRANSACTION TRANSFORM
	TREAT TRIGGER TRIM TRUE_P
	TRUNCATE TRUSTED TYPE_P TYPES_P

	UESCAPE UNBOUNDED UNCOMMITTED UNENCRYPTED UNION UNIQUE UNKNOWN
	UNLISTEN UNLOGGED UNTIL UPDATE USER USING

	VACUUM VALID VALIDATE VALIDATOR VALUE_P VALUES VARCHAR VARIADIC VARYING
	VERBOSE VERSION_P VIEW VIEWS VOLATILE

	WHEN WHERE WHITESPACE_P WINDOW WITH WITHIN WITHOUT WORK WRAPPER WRITE

	XML_P XMLATTRIBUTES XMLCONCAT XMLELEMENT XMLEXISTS XMLFOREST XMLNAMESPACES
	XMLPARSE XMLPI XMLROOT XMLSERIALIZE XMLTABLE

	YEAR_P YES_P

	ZONE

/*
 * The grammar thinks these are keywords, but they are not in the kwlist.h
 * list and so can never be entered directly.  The filter in parser.c
 * creates these tokens when required (based on looking one token ahead).
 *
 * NOT_LA exists so that productions such as NOT LIKE can be given the same
 * precedence as LIKE; otherwise they'd effectively have the same precedence
 * as NOT, at least with respect to their left-hand subexpression.
 * NULLS_LA and WITH_LA are needed to make the grammar LALR(1).
 */
%token		NOT_LA NULLS_LA WITH_LA

/*
 * The grammar likewise thinks these tokens are keywords, but they are never
 * generated by the scanner.  Rather, they can be injected by parser.c as
 * the initial token of the string (using the lookahead-token mechanism
 * implemented there).  This provides a way to tell the grammar to parse
 * something other than the usual list of SQL commands.
 */
%token		MODE_TYPE_NAME
%token		MODE_PLPGSQL_EXPR
%token		MODE_PLPGSQL_ASSIGN1
%token		MODE_PLPGSQL_ASSIGN2
%token		MODE_PLPGSQL_ASSIGN3


/* Precedence: lowest to highest */
%nonassoc	SET				/* see relation_expr_opt_alias */
%left		UNION EXCEPT
%left		INTERSECT
%left		OR
%left		AND
%right		NOT
%nonassoc	IS ISNULL NOTNULL	/* IS sets precedence for IS NULL, etc */
%nonassoc	'<' '>' '=' LESS_EQUALS GREATER_EQUALS NOT_EQUALS
%nonassoc	BETWEEN IN_P LIKE ILIKE SIMILAR NOT_LA
%nonassoc	ESCAPE			/* ESCAPE must be just above LIKE/ILIKE/SIMILAR */
/*
 * To support target_el without AS, it used to be necessary to assign IDENT an
 * explicit precedence just less than Op.  While that's not really necessary
 * since we removed postfix operators, it's still helpful to do so because
 * there are some other unreserved keywords that need precedence assignments.
 * If those keywords have the same precedence as IDENT then they clearly act
 * the same as non-keywords, reducing the risk of unwanted precedence effects.
 *
 * We need to do this for PARTITION, RANGE, ROWS, and GROUPS to support
 * opt_existing_window_name (see comment there).
 *
 * The frame_bound productions UNBOUNDED PRECEDING and UNBOUNDED FOLLOWING
 * are even messier: since UNBOUNDED is an unreserved keyword (per spec!),
 * there is no principled way to distinguish these from the productions
 * a_expr PRECEDING/FOLLOWING.  We hack this up by giving UNBOUNDED slightly
 * lower precedence than PRECEDING and FOLLOWING.  At present this doesn't
 * appear to cause UNBOUNDED to be treated differently from other unreserved
 * keywords anywhere else in the grammar, but it's definitely risky.  We can
 * blame any funny behavior of UNBOUNDED on the SQL standard, though.
 *
 * To support CUBE and ROLLUP in GROUP BY without reserving them, we give them
 * an explicit priority lower than '(', so that a rule with CUBE '(' will shift
 * rather than reducing a conflicting rule that takes CUBE as a function name.
 * Using the same precedence as IDENT seems right for the reasons given above.
 */
%nonassoc	UNBOUNDED		/* ideally would have same precedence as IDENT */
%nonassoc	IDENT PARTITION RANGE ROWS GROUPS PRECEDING FOLLOWING CUBE ROLLUP
%left		Op OPERATOR		/* multi-character ops and user-defined operators */
%left		'+' '-'
%left		'*' '/' '%'
%left		'^'
/* Unary Operators */
%left		AT				/* sets precedence for AT TIME ZONE */
%left		COLLATE
%right		UMINUS
%left		'[' ']'
%left		'(' ')'
%left		TYPECAST
%left		'.'
/*
 * These might seem to be low-precedence, but actually they are not part
 * of the arithmetic hierarchy at all in their use as JOIN operators.
 * We make them high-precedence to support their use as function names.
 * They wouldn't be given a precedence at all, were it not that we need
 * left-associativity among the JOIN rules themselves.
 */
%left		JOIN CROSS LEFT FULL RIGHT INNER_P NATURAL


%destructor { free($$); } IDENT BCONST XCONST SCONST USCONST UIDENT Op FCONST
%destructor { free($$); } Sconst NonReservedWord opt_boolean_or_string NonReservedWord_or_Sconst
%destructor { free($$); } ColLabel BareColLabel comment_text notify_payload RoleSpec RoleId ColId
%destructor { free($$); } var_name type_func_name_keyword param_name attr_name name cursor_name file_name
%destructor { free($$); } generic_option_name analyze_keyword type_function_name utility_option_name


%%


parse_toplevel:

    stmtmulti {
        auto tmp1 = $1;
        *pIR = new IR(kParseToplevel, OP3("", "", ""), tmp1);
        res = *pIR;
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | MODE_TYPE_NAME Typename {
        auto tmp1 = $2;
        *pIR = new IR(kParseToplevel, OP3("", "", ""), tmp1);
        res = *pIR;
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | MODE_PLPGSQL_EXPR PLpgSQL_Expr {
        auto tmp1 = $2;
        *pIR = new IR(kParseToplevel, OP3("", "", ""), tmp1);
        res = *pIR;
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | MODE_PLPGSQL_ASSIGN1 PLAssignStmt {
        auto tmp1 = $2;
        *pIR = new IR(kParseToplevel, OP3("", "", ""), tmp1);
        res = *pIR;
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | MODE_PLPGSQL_ASSIGN2 PLAssignStmt {
        auto tmp1 = $2;
        *pIR = new IR(kParseToplevel, OP3("", "", ""), tmp1);
        res = *pIR;
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | MODE_PLPGSQL_ASSIGN3 PLAssignStmt {
        auto tmp1 = $2;
        *pIR = new IR(kParseToplevel, OP3("", "", ""), tmp1);
        res = *pIR;
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* At top level, we wrap each stmt with a RawStmt node carrying start location
* and length of the stmt's text.  Notice that the start loc/len are driven
* entirely from semicolon locations (@2).  It would seem natural to use
* @1 or @3 to get the true start location of a stmt, but that doesn't work
* for statements that can start with empty nonterminals (opt_with_clause is
* the main offender here); as noted in the comments for YYLLOC_DEFAULT,
* we'd get -1 for the location in such cases.
* We also take care to discard empty statements entirely.
*/

stmtmulti:

    stmtmulti ';' toplevel_stmt {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kStmtmulti, OP3("", ";", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | toplevel_stmt {
        auto tmp1 = $1;
        res = new IR(kStmtmulti, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* toplevel_stmt includes BEGIN and END.  stmt does not include them, because
* those words have different meanings in function bodys.
*/

toplevel_stmt:

    stmt
    | TransactionStmtLegacy
;


stmt:

    AlterEventTrigStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | AlterCollationStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | AlterDatabaseStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | AlterDatabaseSetStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | AlterDefaultPrivilegesStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | AlterDomainStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | AlterEnumStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | AlterExtensionStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | AlterExtensionContentsStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | AlterFdwStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | AlterForeignServerStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | AlterFunctionStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | AlterGroupStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | AlterObjectDependsStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | AlterObjectSchemaStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | AlterOwnerStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | AlterOperatorStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | AlterTypeStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | AlterPolicyStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | AlterSeqStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | AlterSystemStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | AlterTableStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | AlterTblSpcStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | AlterCompositeTypeStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | AlterPublicationStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | AlterRoleSetStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | AlterRoleStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | AlterSubscriptionStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | AlterStatsStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | AlterTSConfigurationStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | AlterTSDictionaryStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | AlterUserMappingStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | AnalyzeStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CallStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CheckPointStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ClosePortalStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ClusterStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CommentStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ConstraintsSetStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CopyStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CreateAmStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CreateAsStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CreateAssertionStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CreateCastStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CreateConversionStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CreateDomainStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CreateExtensionStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CreateFdwStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CreateForeignServerStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CreateForeignTableStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CreateFunctionStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CreateGroupStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CreateMatViewStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CreateOpClassStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CreateOpFamilyStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CreatePublicationStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | AlterOpFamilyStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CreatePolicyStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CreatePLangStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CreateSchemaStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CreateSeqStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CreateStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CreateSubscriptionStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CreateStatsStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CreateTableSpaceStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CreateTransformStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CreateTrigStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CreateEventTrigStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CreateRoleStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CreateUserStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CreateUserMappingStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CreatedbStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DeallocateStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DeclareCursorStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DefineStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DeleteStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DiscardStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DoStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DropCastStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DropOpClassStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DropOpFamilyStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DropOwnedStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DropStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DropSubscriptionStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DropTableSpaceStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DropTransformStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DropRoleStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DropUserMappingStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DropdbStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ExecuteStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ExplainStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FetchStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | GrantStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | GrantRoleStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ImportForeignSchemaStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | IndexStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | InsertStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ListenStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | RefreshMatViewStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | LoadStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | LockStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NotifyStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | PrepareStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ReassignOwnedStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ReindexStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | RemoveAggrStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | RemoveFuncStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | RemoveOperStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | RenameStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | RevokeStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | RevokeRoleStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | RuleStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SecLabelStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SelectStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TransactionStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TruncateStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | UnlistenStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | UpdateStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | VacuumStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | VariableResetStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | VariableSetStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | VariableShowStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ViewStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kStmt, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
* CALL statement
*
*****************************************************************************/


CallStmt:

    CALL func_application {
        auto tmp1 = $2;
        res = new IR(kCallStmt, OP3("CALL", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
* Create a new Postgres DBMS role
*
*****************************************************************************/


CreateRoleStmt:

    CREATE ROLE RoleId opt_with OptRoleList {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $4;
        res = new IR(kCreateRoleStmt_1, OP3("CREATE ROLE", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kCreateRoleStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_iden_type(kDataRoleName, kNoModi);
    }

;



opt_with:

    WITH {
        res = new IR(kOptWith, OP3("WITH", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | WITH_LA {
        res = new IR(kOptWith, OP3("WITH", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptWith, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* Options for CREATE ROLE and ALTER ROLE (also used by CREATE/ALTER USER
* for backwards compatibility).  Note: the only option required by SQL99
* is "WITH ADMIN name".
*/

OptRoleList:

    OptRoleList CreateOptRoleElem {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kOptRoleList, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kOptRoleList, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


AlterOptRoleList:

    AlterOptRoleList AlterOptRoleElem {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kAlterOptRoleList, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kAlterOptRoleList, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


AlterOptRoleElem:

    PASSWORD Sconst {
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        res = new IR(kAlterOptRoleElem, OP3("PASSWORD", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | PASSWORD NULL_P {
        res = new IR(kAlterOptRoleElem, OP3("PASSWORD NULL", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ENCRYPTED PASSWORD Sconst {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        res = new IR(kAlterOptRoleElem, OP3("ENCRYPTED PASSWORD", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | UNENCRYPTED PASSWORD Sconst {
        /* Yu: Force change it to ENCRYPTED PASSWORD. UNENCRYPTED PASSWORD is not supported anymore. */
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        res = new IR(kAlterOptRoleElem, OP3("ENCRYPTED PASSWORD", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | INHERIT {
        res = new IR(kAlterOptRoleElem, OP3("INHERIT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CONNECTION LIMIT SignedIconst {
        auto tmp1 = $3;
        res = new IR(kAlterOptRoleElem, OP3("CONNECTION LIMIT", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | VALID UNTIL Sconst {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        res = new IR(kAlterOptRoleElem, OP3("VALID UNTIL", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | USER role_list {
        auto tmp1 = $2;
        res = new IR(kAlterOptRoleElem, OP3("USER", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_rolelist_type(kDataRoleName, kUse);
    }

    | IDENT {
        /* Yu: Restricted the possible option for ALTER role option list. If unreconized, change it to superuser. */
        /* FixLater: Can we directly give $1 to OP3()?*/
        auto tmp1 = $1;
        if (!strcmp($1, "superuser") ||
		    !strcmp($1, "nosuperuser") ||
		    !strcmp($1, "createrole") ||
		    !strcmp($1, "nocreaterole") ||
		    !strcmp($1, "replication") ||
		    !strcmp($1, "noreplication") ||
		    !strcmp($1, "createdb") ||
		    !strcmp($1, "nocreatedb") ||
		    !strcmp($1, "login") ||
		    !strcmp($1, "nologin") ||
		    !strcmp($1, "bypassrls") ||
		    !strcmp($1, "nobypassrls") ||
		    !strcmp($1, "noinherit"))
		{
            res = new IR(kAlterOptRoleElem, string($1));
        all_gen_ir.push_back(res);
		} else {
            res = new IR(kAlterOptRoleElem, OP3("superuser", "", ""));
        all_gen_ir.push_back(res);
        }
        free($1);
        $$ = res;
    }

;


CreateOptRoleElem:

    AlterOptRoleElem {
        auto tmp1 = $1;
        res = new IR(kCreateOptRoleElem, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SYSID Iconst {
        auto tmp1 = $2;
        res = new IR(kCreateOptRoleElem, OP3("SYSID", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ADMIN role_list {
        auto tmp1 = $2;
        res = new IR(kCreateOptRoleElem, OP3("ADMIN", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_rolelist_type(kDataRoleName, kUse);
    }

    | ROLE role_list {
        auto tmp1 = $2;
        res = new IR(kCreateOptRoleElem, OP3("ROLE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_rolelist_type(kDataRoleName, kUse);
    }

    | IN_P ROLE role_list {
        auto tmp1 = $3;
        res = new IR(kCreateOptRoleElem, OP3("IN ROLE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_rolelist_type(kDataRoleName, kUse);
    }

    | IN_P GROUP_P role_list {
        auto tmp1 = $3;
        res = new IR(kCreateOptRoleElem, OP3("IN GROUP", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_rolelist_type(kDataRoleName, kUse);
    }

;


/*****************************************************************************
*
* Create a new Postgres DBMS user (role with implied login ability)
*
*****************************************************************************/


CreateUserStmt:

    CREATE USER RoleId opt_with OptRoleList {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $4;
        res = new IR(kCreateUserStmt_1, OP3("CREATE USER", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kCreateUserStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
* Alter a postgresql DBMS role
*
*****************************************************************************/


AlterRoleStmt:

    ALTER ROLE RoleSpec opt_with AlterOptRoleList {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $4;
        res = new IR(kAlterRoleStmt_1, OP3("ALTER ROLE", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kAlterRoleStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER USER RoleSpec opt_with AlterOptRoleList {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $4;
        res = new IR(kAlterRoleStmt_2, OP3("ALTER USER", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kAlterRoleStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_in_database:

    /* EMPTY */ {
        res = new IR(kOptInDatabase, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | IN_P DATABASE name {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        res = new IR(kOptInDatabase, OP3("IN DATABASE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


AlterRoleSetStmt:

    ALTER ROLE RoleSpec opt_in_database SetResetClause {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $4;
        res = new IR(kAlterRoleSetStmt_1, OP3("ALTER ROLE", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kAlterRoleSetStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER ROLE ALL opt_in_database SetResetClause {
        auto tmp1 = $4;
        auto tmp2 = $5;
        res = new IR(kAlterRoleSetStmt, OP3("ALTER ROLE ALL", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER USER RoleSpec opt_in_database SetResetClause {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $4;
        res = new IR(kAlterRoleSetStmt_2, OP3("ALTER USER", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kAlterRoleSetStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER USER ALL opt_in_database SetResetClause {
        auto tmp1 = $4;
        auto tmp2 = $5;
        res = new IR(kAlterRoleSetStmt, OP3("ALTER USER ALL", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
* Drop a postgresql DBMS role
*
* XXX Ideally this would have CASCADE/RESTRICT options, but a role
* might own objects in multiple databases, and there is presently no way to
* implement cascading to other databases.  So we always behave as RESTRICT.
*****************************************************************************/


DropRoleStmt:

    DROP ROLE role_list {
        auto tmp1 = $3;
        res = new IR(kDropRoleStmt, OP3("DROP ROLE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DROP ROLE IF_P EXISTS role_list {
        auto tmp1 = $5;
        res = new IR(kDropRoleStmt, OP3("DROP ROLE IF EXISTS", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DROP USER role_list {
        auto tmp1 = $3;
        res = new IR(kDropRoleStmt, OP3("DROP USER", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DROP USER IF_P EXISTS role_list {
        auto tmp1 = $5;
        res = new IR(kDropRoleStmt, OP3("DROP USER IF EXISTS", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DROP GROUP_P role_list {
        auto tmp1 = $3;
        res = new IR(kDropRoleStmt, OP3("DROP GROUP", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_rolelist_type(kDataRoleName, kUndefine);
    }

    | DROP GROUP_P IF_P EXISTS role_list {
        auto tmp1 = $5;
        res = new IR(kDropRoleStmt, OP3("DROP GROUP IF EXISTS", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_rolelist_type(kDataRoleName, kUndefine);
    }

;


/*****************************************************************************
*
* Create a postgresql group (role without login ability)
*
*****************************************************************************/


CreateGroupStmt:

    CREATE GROUP_P RoleId opt_with OptRoleList {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $4;
        res = new IR(kCreateGroupStmt_1, OP3("CREATE GROUP", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kCreateGroupStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_iden_type(kDataGroupName, kNoModi);
    }

;


/*****************************************************************************
*
* Alter a postgresql group
*
*****************************************************************************/


AlterGroupStmt:

    ALTER GROUP_P RoleSpec add_drop USER role_list {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $4;
        res = new IR(kAlterGroupStmt_1, OP3("ALTER GROUP", "", "USER"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kAlterGroupStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_iden_type(kDataGroupName, kUse);
        tmp3->set_rolelist_type(kDataUserName, kUse);
    }

;


add_drop:

    ADD_P {
        res = new IR(kAddDrop, OP3("ADD", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DROP {
        res = new IR(kAddDrop, OP3("DROP", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
* Manipulate a schema
*
*****************************************************************************/


CreateSchemaStmt:

    CREATE SCHEMA OptSchemaName AUTHORIZATION RoleSpec OptSchemaEltList {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($5), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($5);
        res = new IR(kCreateSchemaStmt_1, OP3("CREATE SCHEMA", "AUTHORIZATION", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kCreateSchemaStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CREATE SCHEMA ColId OptSchemaEltList {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $4;
        res = new IR(kCreateSchemaStmt, OP3("CREATE SCHEMA", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CREATE SCHEMA IF_P NOT EXISTS OptSchemaName AUTHORIZATION RoleSpec OptSchemaEltList {
        /* Yu: Ignore optSchemaEltList. It is not supported here. */
        if ($9) {
            /* $9 -> deep_drop(); */
            rov_ir.push_back($9);
        }
        auto tmp1 = $6;
        auto tmp2 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($8);
        res = new IR(kCreateSchemaStmt, OP3("CREATE SCHEMA IF NOT EXISTS", "AUTHORIZATION", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CREATE SCHEMA IF_P NOT EXISTS ColId OptSchemaEltList {
        /* Yu: Ignore optSchemaEltList. It is not supported here. */
        if ($7) {
            /* $7 -> deep_drop(); */
            rov_ir.push_back($7);
        }
        auto tmp1 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($6);
        res = new IR(kCreateSchemaStmt, OP3("CREATE SCHEMA IF NOT EXISTS", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


OptSchemaName:

    ColId {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kOptSchemaName, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kOptSchemaName, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


OptSchemaEltList:

    OptSchemaEltList schema_stmt {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kOptSchemaEltList, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kOptSchemaEltList, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
*	schema_stmt are the ones that can show up inside a CREATE SCHEMA
*	statement (in addition to by themselves).
*/

schema_stmt:

    CreateStmt {
        auto tmp1 = $1;
        res = new IR(kSchemaStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | IndexStmt {
        auto tmp1 = $1;
        res = new IR(kSchemaStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CreateSeqStmt {
        auto tmp1 = $1;
        res = new IR(kSchemaStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CreateTrigStmt {
        auto tmp1 = $1;
        res = new IR(kSchemaStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | GrantStmt {
        auto tmp1 = $1;
        res = new IR(kSchemaStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ViewStmt {
        auto tmp1 = $1;
        res = new IR(kSchemaStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
* Set PG internal variable
*	  SET name TO 'var_value'
* Include SQL syntax (thomas 1997-10-22):
*	  SET TIME ZONE 'var_value'
*
*****************************************************************************/


VariableSetStmt:

    SET set_rest {
        auto tmp1 = $2;
        res = new IR(kVariableSetStmt, OP3("SET", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SET LOCAL set_rest {
        auto tmp1 = $3;
        res = new IR(kVariableSetStmt, OP3("SET LOCAL", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SET SESSION set_rest {
        auto tmp1 = $3;
        res = new IR(kVariableSetStmt, OP3("SET SESSION", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


set_rest:

    TRANSACTION transaction_mode_list {
        auto tmp1 = $2;
        res = new IR(kSetRest, OP3("TRANSACTION", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SESSION CHARACTERISTICS AS TRANSACTION transaction_mode_list {
        auto tmp1 = $5;
        res = new IR(kSetRest, OP3("SESSION CHARACTERISTICS AS TRANSACTION", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | set_rest_more {
        auto tmp1 = $1;
        res = new IR(kSetRest, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


generic_set:

    var_name TO var_list {
        IR* tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back(tmp1);
        free($1);
        auto tmp2 = $3;
        res = new IR(kGenericSet, OP3("", "TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        res -> set_generic_set_type(kDataRelOption, kUse);
        res -> set_rel_option_type(RelOptionType::SetConfigurationOptions);
    }

    | var_name '=' var_list {
        IR* tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back(tmp1);
        free($1);
        auto tmp2 = $3;
        res = new IR(kGenericSet, OP3("", "=", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        res -> set_generic_set_type(kDataRelOption, kUse);
        res -> set_rel_option_type(RelOptionType::SetConfigurationOptions);
    }

    | var_name TO DEFAULT {
        IR* tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back(tmp1);
        free($1);
        res = new IR(kGenericSet, OP3("", "TO DEFAULT", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;

        res -> set_generic_set_type(kDataRelOption, kUse);
        res -> set_rel_option_type(RelOptionType::SetConfigurationOptions);
    }

    | var_name '=' DEFAULT {
        IR* tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back(tmp1);
        free($1);
        res = new IR(kGenericSet, OP3("", "= DEFAULT", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;

        res -> set_generic_set_type(kDataRelOption, kUse);
        res -> set_rel_option_type(RelOptionType::SetConfigurationOptions);

    }

;


set_rest_more:

    generic_set {
        auto tmp1 = $1;
        res = new IR(kSetRestMore, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | var_name FROM CURRENT_P {
        IR* tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back(tmp1);
        free($1);
        res = new IR(kSetRestMore, OP3("", "FROM CURRENT", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TIME ZONE zone_value {
        auto tmp1 = $3;
        res = new IR(kSetRestMore, OP3("TIME ZONE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CATALOG_P Sconst {
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        res = new IR(kSetRestMore, OP3("CATALOG", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SCHEMA Sconst {
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        res = new IR(kSetRestMore, OP3("SCHEMA", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NAMES opt_encoding {
        auto tmp1 = $2;
        res = new IR(kSetRestMore, OP3("NAMES", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ROLE NonReservedWord_or_Sconst {
        /* Yu: Cannot find exact example shown on the documentation. Use it as kUse of Role. */
        IR* tmp1 = new IR(kIdentifier, string($2), kDataRoleName, 0, kUse);
        all_gen_ir.push_back(tmp1);
        free($2);
        res = new IR(kSetRestMore, OP3("ROLE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SESSION AUTHORIZATION NonReservedWord_or_Sconst {
        /* Yu: This is username. This is just the wrapper for Role. */
        IR* tmp1 = new IR(kIdentifier, string($3), kDataRoleName, 0, kUse);
        all_gen_ir.push_back(tmp1);
        free($3);
        res = new IR(kSetRestMore, OP3("ROLE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SESSION AUTHORIZATION DEFAULT {
        res = new IR(kSetRestMore, OP3("SESSION AUTHORIZATION DEFAULT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | XML_P OPTION document_or_content {
        auto tmp1 = $3;
        res = new IR(kSetRestMore, OP3("XML OPTION", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TRANSACTION SNAPSHOT Sconst {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        res = new IR(kSetRestMore, OP3("TRANSACTION SNAPSHOT", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

var_name:

    ColId
    | var_name '.' ColId {
        char* mem = alloc_and_cat($1, ".", $3);
        free($1);
        free($3);
        $$ = mem;
    }

;


var_list:

    var_value {
        auto tmp1 = $1;
        res = new IR(kVarList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | var_list ',' var_value {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kVarList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


var_value:

    opt_boolean_or_string {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kVarValue, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NumericOnly {
        auto tmp1 = $1;
        res = new IR(kVarValue, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


iso_level:

    READ UNCOMMITTED {
        res = new IR(kIsoLevel, OP3("READ UNCOMMITTED", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | READ COMMITTED {
        res = new IR(kIsoLevel, OP3("READ COMMITTED", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | REPEATABLE READ {
        res = new IR(kIsoLevel, OP3("REPEATABLE READ", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SERIALIZABLE {
        res = new IR(kIsoLevel, OP3("SERIALIZABLE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_boolean_or_string:

    TRUE_P {
        $$ = strdup($1);
    }

    | FALSE_P {
        $$ = strdup($1);
    }

    | ON {
        $$ = strdup($1);
    }

    | NonReservedWord_or_Sconst

;

/* Timezone values can be:
* - a string such as 'pst8pdt'
* - an identifier such as "pst8pdt"
* - an integer or floating point number
* - a time interval per SQL99
* ColId gives reduce/reduce errors against ConstInterval and LOCAL,
* so use IDENT (meaning we reject anything that is a key word).
*/

zone_value:

    Sconst {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kZoneValue, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | IDENT {
        /* Yu: Change it to a fixed location. Do not accept in random string.  */
        free($1);
        res = new IR(kZoneValue, OP3("America/Chicago", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ConstInterval Sconst opt_interval {
        auto tmp1 = $1;
        auto tmp2 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($2);
        res = new IR(kZoneValue_1, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $3;
        res = new IR(kZoneValue, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ConstInterval '(' Iconst ')' Sconst {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kZoneValue_2, OP3("", "(", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($5), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($5);
        res = new IR(kZoneValue, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NumericOnly {
        auto tmp1 = $1;
        res = new IR(kZoneValue, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DEFAULT {
        res = new IR(kZoneValue, OP3("DEFAULT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | LOCAL {
        res = new IR(kZoneValue, OP3("LOCAL", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_encoding:

    Sconst {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kOptEncoding, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DEFAULT {
        res = new IR(kOptEncoding, OP3("DEFAULT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptEncoding, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


NonReservedWord_or_Sconst:

    NonReservedWord
    | Sconst
;


VariableResetStmt:

    RESET reset_rest {
        auto tmp1 = $2;
        res = new IR(kVariableResetStmt, OP3("RESET", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


reset_rest:

    generic_reset {
        auto tmp1 = $1;
        res = new IR(kResetRest, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TIME ZONE {
        res = new IR(kResetRest, OP3("TIME ZONE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TRANSACTION ISOLATION LEVEL {
        res = new IR(kResetRest, OP3("TRANSACTION ISOLATION LEVEL", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SESSION AUTHORIZATION {
        res = new IR(kResetRest, OP3("SESSION AUTHORIZATION", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


generic_reset:

    var_name {
        IR* tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        free($1);
        all_gen_ir.push_back(tmp1);
        res = new IR(kGenericReset, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALL {
        res = new IR(kGenericReset, OP3("ALL", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/* SetResetClause allows SET or RESET without LOCAL */

SetResetClause:

    SET set_rest {
        auto tmp1 = $2;
        res = new IR(kSetResetClause, OP3("SET", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | VariableResetStmt {
        auto tmp1 = $1;
        res = new IR(kSetResetClause, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/* SetResetClause allows SET or RESET without LOCAL */

FunctionSetResetClause:

    SET set_rest_more {
        auto tmp1 = $2;
        res = new IR(kFunctionSetResetClause, OP3("SET", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | VariableResetStmt {
        auto tmp1 = $1;
        res = new IR(kFunctionSetResetClause, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;



VariableShowStmt:

    SHOW var_name {
        IR* tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back(tmp1);
        free($2);
        res = new IR(kVariableShowStmt, OP3("SHOW", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SHOW TIME ZONE {
        res = new IR(kVariableShowStmt, OP3("SHOW TIME ZONE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SHOW TRANSACTION ISOLATION LEVEL {
        res = new IR(kVariableShowStmt, OP3("SHOW TRANSACTION ISOLATION LEVEL", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SHOW SESSION AUTHORIZATION {
        res = new IR(kVariableShowStmt, OP3("SHOW SESSION AUTHORIZATION", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SHOW ALL {
        res = new IR(kVariableShowStmt, OP3("SHOW ALL", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;



ConstraintsSetStmt:

    SET CONSTRAINTS constraints_set_list constraints_set_mode {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kConstraintsSetStmt, OP3("SET CONSTRAINTS", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


constraints_set_list:

    ALL {
        res = new IR(kConstraintsSetList, OP3("ALL", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | qualified_name_list {
        auto tmp1 = $1;
        res = new IR(kConstraintsSetList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


constraints_set_mode:

    DEFERRED {
        res = new IR(kConstraintsSetMode, OP3("DEFERRED", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | IMMEDIATE {
        res = new IR(kConstraintsSetMode, OP3("IMMEDIATE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*
* Checkpoint statement
*/

CheckPointStmt:

    CHECKPOINT {
        res = new IR(kCheckPointStmt, OP3("CHECKPOINT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
* DISCARD { ALL | TEMP | PLANS | SEQUENCES }
*
*****************************************************************************/


DiscardStmt:

    DISCARD ALL {
        res = new IR(kDiscardStmt, OP3("DISCARD ALL", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DISCARD TEMP {
        res = new IR(kDiscardStmt, OP3("DISCARD TEMP", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DISCARD TEMPORARY {
        res = new IR(kDiscardStmt, OP3("DISCARD TEMPORARY", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DISCARD PLANS {
        res = new IR(kDiscardStmt, OP3("DISCARD PLANS", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DISCARD SEQUENCES {
        res = new IR(kDiscardStmt, OP3("DISCARD SEQUENCES", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
*	ALTER [ TABLE | INDEX | SEQUENCE | VIEW | MATERIALIZED VIEW | FOREIGN TABLE ] variations
*
* Note: we accept all subcommands for each of the variants, and sort
* out what's really legal at execution time.
*****************************************************************************/


AlterTableStmt:

    ALTER TABLE relation_expr alter_table_cmds {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kAlterTableStmt, OP3("ALTER TABLE", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1 -> set_relation_expr_type(kDataTableName, kUse);
    }

    | ALTER TABLE IF_P EXISTS relation_expr alter_table_cmds {
        auto tmp1 = $5;
        auto tmp2 = $6;
        res = new IR(kAlterTableStmt, OP3("ALTER TABLE IF EXISTS", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1 -> set_relation_expr_type(kDataTableName, kUse);

    }

    | ALTER TABLE relation_expr partition_cmd {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kAlterTableStmt, OP3("ALTER TABLE", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1 -> set_relation_expr_type(kDataTableName, kUse);

    }

    | ALTER TABLE IF_P EXISTS relation_expr partition_cmd {
        auto tmp1 = $5;
        auto tmp2 = $6;
        res = new IR(kAlterTableStmt, OP3("ALTER TABLE IF EXISTS", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1 -> set_relation_expr_type(kDataTableName, kUse);
    }

    | ALTER TABLE ALL IN_P TABLESPACE name SET TABLESPACE name opt_nowait {
        auto tmp1 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($6);
        auto tmp2 = new IR(kIdentifier, string($9), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($9);
        res = new IR(kAlterTableStmt_1, OP3("ALTER TABLE ALL IN TABLESPACE", "SET TABLESPACE", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $10;
        res = new IR(kAlterTableStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_iden_type(kDataTableSpaceName, kUse);
        tmp2->set_iden_type(kDataTableSpaceName, kUse);
    }

    | ALTER TABLE ALL IN_P TABLESPACE name OWNED BY role_list SET TABLESPACE name opt_nowait {
        auto tmp1 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($6);
        auto tmp2 = $9;
        res = new IR(kAlterTableStmt_2, OP3("ALTER TABLE ALL IN TABLESPACE", "OWNED BY", "SET TABLESPACE"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($12), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($12);
        res = new IR(kAlterTableStmt_3, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $13;
        res = new IR(kAlterTableStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_iden_type(kDataTableSpaceName, kUse);
        tmp3->set_iden_type(kDataTableSpaceName, kUse);
    }

    | ALTER INDEX qualified_name alter_table_cmds {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kAlterTableStmt, OP3("ALTER INDEX", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_qualified_name_type(kDataIndexName, kUse);
    }

    | ALTER INDEX IF_P EXISTS qualified_name alter_table_cmds {
        auto tmp1 = $5;
        auto tmp2 = $6;
        res = new IR(kAlterTableStmt, OP3("ALTER INDEX IF EXISTS", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_qualified_name_type(kDataIndexName, kUse);
    }

    | ALTER INDEX qualified_name index_partition_cmd {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kAlterTableStmt, OP3("ALTER INDEX", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_qualified_name_type(kDataIndexName, kUse);
    }

    | ALTER INDEX ALL IN_P TABLESPACE name SET TABLESPACE name opt_nowait {
        auto tmp1 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($6);
        auto tmp2 = new IR(kIdentifier, string($9), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($9);
        res = new IR(kAlterTableStmt_4, OP3("ALTER INDEX ALL IN TABLESPACE", "SET TABLESPACE", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $10;
        res = new IR(kAlterTableStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_iden_type(kDataTableSpaceName, kUse);
        tmp2->set_iden_type(kDataTableSpaceName, kUse);
    }

    | ALTER INDEX ALL IN_P TABLESPACE name OWNED BY role_list SET TABLESPACE name opt_nowait {
        auto tmp1 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($6);
        auto tmp2 = $9;
        res = new IR(kAlterTableStmt_5, OP3("ALTER INDEX ALL IN TABLESPACE", "OWNED BY", "SET TABLESPACE"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($12), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($12);
        res = new IR(kAlterTableStmt_6, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $13;
        res = new IR(kAlterTableStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_iden_type(kDataTableSpaceName, kUse);
        tmp2->set_rolelist_type(kDataRoleName, kUse);
        tmp3->set_iden_type(kDataTableSpaceName, kUse);
    }

    | ALTER SEQUENCE qualified_name alter_table_cmds {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kAlterTableStmt, OP3("ALTER SEQUENCE", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_qualified_name_type(kDataSequenceName, kUse);
    }

    | ALTER SEQUENCE IF_P EXISTS qualified_name alter_table_cmds {
        auto tmp1 = $5;
        auto tmp2 = $6;
        res = new IR(kAlterTableStmt, OP3("ALTER SEQUENCE IF EXISTS", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_qualified_name_type(kDataSequenceName, kUse);
    }

    | ALTER VIEW qualified_name alter_table_cmds {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kAlterTableStmt, OP3("ALTER VIEW", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_qualified_name_type(kDataViewName, kUse);
    }

    | ALTER VIEW IF_P EXISTS qualified_name alter_table_cmds {
        auto tmp1 = $5;
        auto tmp2 = $6;
        res = new IR(kAlterTableStmt, OP3("ALTER VIEW IF EXISTS", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_qualified_name_type(kDataViewName, kUse);
    }

    | ALTER MATERIALIZED VIEW qualified_name alter_table_cmds {
        auto tmp1 = $4;
        auto tmp2 = $5;
        res = new IR(kAlterTableStmt, OP3("ALTER MATERIALIZED VIEW", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_qualified_name_type(kDataViewName, kUse);
    }

    | ALTER MATERIALIZED VIEW IF_P EXISTS qualified_name alter_table_cmds {
        auto tmp1 = $6;
        auto tmp2 = $7;
        res = new IR(kAlterTableStmt, OP3("ALTER MATERIALIZED VIEW IF EXISTS", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_qualified_name_type(kDataViewName, kUse);
    }

    | ALTER MATERIALIZED VIEW ALL IN_P TABLESPACE name SET TABLESPACE name opt_nowait {
        auto tmp1 = new IR(kIdentifier, string($7), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($7);
        auto tmp2 = new IR(kIdentifier, string($10), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($10);
        res = new IR(kAlterTableStmt_7, OP3("ALTER MATERIALIZED VIEW ALL IN TABLESPACE", "SET TABLESPACE", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $11;
        res = new IR(kAlterTableStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_iden_type(kDataTableSpaceName, kUse);
        tmp2->set_iden_type(kDataTableSpaceName, kUse);
    }

    | ALTER MATERIALIZED VIEW ALL IN_P TABLESPACE name OWNED BY role_list SET TABLESPACE name opt_nowait {
        auto tmp1 = new IR(kIdentifier, string($7), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($7);
        auto tmp2 = $10;
        res = new IR(kAlterTableStmt_8, OP3("ALTER MATERIALIZED VIEW ALL IN TABLESPACE", "OWNED BY", "SET TABLESPACE"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($13), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($13);
        res = new IR(kAlterTableStmt_9, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $14;
        res = new IR(kAlterTableStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_iden_type(kDataTableSpaceName, kUse);
        tmp3->set_iden_type(kDataTableSpaceName, kUse);
    }

    | ALTER FOREIGN TABLE relation_expr alter_table_cmds {
        auto tmp1 = $4;
        auto tmp2 = $5;
        res = new IR(kAlterTableStmt, OP3("ALTER FOREIGN TABLE", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_relation_expr_type(kDataForeignTableName, kUse);
    }

    | ALTER FOREIGN TABLE IF_P EXISTS relation_expr alter_table_cmds {
        auto tmp1 = $6;
        auto tmp2 = $7;
        res = new IR(kAlterTableStmt, OP3("ALTER FOREIGN TABLE IF EXISTS", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_relation_expr_type(kDataForeignTableName, kUse);
    }

;


alter_table_cmds:

    alter_table_cmd {
        auto tmp1 = $1;
        res = new IR(kAlterTableCmds, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | alter_table_cmds ',' alter_table_cmd {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kAlterTableCmds, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


partition_cmd:

    ATTACH PARTITION qualified_name PartitionBoundSpec {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kPartitionCmd, OP3("ATTACH PARTITION", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_qualified_name_type(kDataTableName, kUse);

    }

    | DETACH PARTITION qualified_name opt_concurrently {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kPartitionCmd, OP3("DETACH PARTITION", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_qualified_name_type(kDataTableName, kUse);
    }

    | DETACH PARTITION qualified_name FINALIZE {
        auto tmp1 = $3;
        res = new IR(kPartitionCmd, OP3("DETACH PARTITION", "FINALIZE", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_qualified_name_type(kDataTableName, kUse);
    }

;


index_partition_cmd:

    ATTACH PARTITION qualified_name {
        auto tmp1 = $3;
        res = new IR(kIndexPartitionCmd, OP3("ATTACH PARTITION", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


alter_table_cmd:

    ADD_P columnDef {
        auto tmp1 = $2;
        res = new IR(kAlterTableCmd, OP3("ADD", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ADD_P IF_P NOT EXISTS columnDef {
        auto tmp1 = $5;
        res = new IR(kAlterTableCmd, OP3("ADD IF NOT EXISTS", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ADD_P COLUMN columnDef {
        auto tmp1 = $3;
        res = new IR(kAlterTableCmd, OP3("ADD COLUMN", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ADD_P COLUMN IF_P NOT EXISTS columnDef {
        auto tmp1 = $6;
        res = new IR(kAlterTableCmd, OP3("ADD COLUMN IF NOT EXISTS", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER opt_column ColId alter_column_default {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kAlterTableCmd_1, OP3("ALTER", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $4;
        res = new IR(kAlterTableCmd, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER opt_column ColId DROP NOT NULL_P {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kAlterTableCmd, OP3("ALTER", "", "DROP NOT NULL"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER opt_column ColId SET NOT NULL_P {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kAlterTableCmd, OP3("ALTER", "", "SET NOT NULL"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER opt_column ColId DROP EXPRESSION {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kAlterTableCmd, OP3("ALTER", "", "DROP EXPRESSION"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER opt_column ColId DROP EXPRESSION IF_P EXISTS {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kAlterTableCmd, OP3("ALTER", "", "DROP EXPRESSION IF EXISTS"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER opt_column ColId SET STATISTICS SignedIconst {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kAlterTableCmd_2, OP3("ALTER", "", "SET STATISTICS"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kAlterTableCmd, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER opt_column Iconst SET STATISTICS SignedIconst {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kAlterTableCmd_3, OP3("ALTER", "", "SET STATISTICS"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kAlterTableCmd, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER opt_column ColId SET reloptions {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kAlterTableCmd_4, OP3("ALTER", "", "SET"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kAlterTableCmd, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp3->set_reloptions_option_type(RelOptionType::AlterAttribute);
    }

    | ALTER opt_column ColId RESET reloptions {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kAlterTableCmd_5, OP3("ALTER", "", "RESET"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kAlterTableCmd, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp3->set_reloptions_option_type(RelOptionType::AlterAttributeReset);
    }

    | ALTER opt_column ColId SET STORAGE ColId {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kAlterTableCmd_6, OP3("ALTER", "", "SET STORAGE"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($6);
        res = new IR(kAlterTableCmd, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER opt_column ColId SET column_compression {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kAlterTableCmd_7, OP3("ALTER", "", "SET"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kAlterTableCmd, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER opt_column ColId ADD_P GENERATED generated_when AS IDENTITY_P OptParenthesizedSeqOptList {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kAlterTableCmd_8, OP3("ALTER", "", "ADD GENERATED"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kAlterTableCmd_9, OP3("", "", "AS IDENTITY"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $9;
        res = new IR(kAlterTableCmd, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER opt_column ColId alter_identity_column_option_list {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kAlterTableCmd_10, OP3("ALTER", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $4;
        res = new IR(kAlterTableCmd, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER opt_column ColId DROP IDENTITY_P {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kAlterTableCmd, OP3("ALTER", "", "DROP IDENTITY"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER opt_column ColId DROP IDENTITY_P IF_P EXISTS {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kAlterTableCmd, OP3("ALTER", "", "DROP IDENTITY IF EXISTS"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DROP opt_column IF_P EXISTS ColId opt_drop_behavior {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($5), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($5);
        res = new IR(kAlterTableCmd_11, OP3("DROP", "IF EXISTS", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kAlterTableCmd, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DROP opt_column ColId opt_drop_behavior {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kAlterTableCmd_12, OP3("DROP", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $4;
        res = new IR(kAlterTableCmd, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER opt_column ColId opt_set_data TYPE_P Typename opt_collate_clause alter_using {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kAlterTableCmd_13, OP3("ALTER", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $4;
        res = new IR(kAlterTableCmd_14, OP3("", "", "TYPE"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $6;
        res = new IR(kAlterTableCmd_15, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $7;
        res = new IR(kAlterTableCmd_16, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        auto tmp6 = $8;
        res = new IR(kAlterTableCmd, OP3("", "", ""), res, tmp6);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER opt_column ColId alter_generic_options {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kAlterTableCmd_17, OP3("ALTER", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $4;
        res = new IR(kAlterTableCmd, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ADD_P TableConstraint {
        auto tmp1 = $2;
        res = new IR(kAlterTableCmd, OP3("ADD", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER CONSTRAINT name ConstraintAttributeSpec {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $4;
        res = new IR(kAlterTableCmd, OP3("ALTER CONSTRAINT", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | VALIDATE CONSTRAINT name {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        res = new IR(kAlterTableCmd, OP3("VALIDATE CONSTRAINT", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DROP CONSTRAINT IF_P EXISTS name opt_drop_behavior {
        auto tmp1 = new IR(kIdentifier, string($5), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($5);
        auto tmp2 = $6;
        res = new IR(kAlterTableCmd, OP3("DROP CONSTRAINT IF EXISTS", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DROP CONSTRAINT name opt_drop_behavior {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $4;
        res = new IR(kAlterTableCmd, OP3("DROP CONSTRAINT", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SET WITHOUT OIDS {
        res = new IR(kAlterTableCmd, OP3("SET WITHOUT OIDS", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CLUSTER ON name {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        res = new IR(kAlterTableCmd, OP3("CLUSTER ON", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SET WITHOUT CLUSTER {
        res = new IR(kAlterTableCmd, OP3("SET WITHOUT CLUSTER", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SET LOGGED {
        res = new IR(kAlterTableCmd, OP3("SET LOGGED", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SET UNLOGGED {
        res = new IR(kAlterTableCmd, OP3("SET UNLOGGED", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ENABLE_P TRIGGER name {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        res = new IR(kAlterTableCmd, OP3("ENABLE TRIGGER", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ENABLE_P ALWAYS TRIGGER name {
        auto tmp1 = new IR(kIdentifier, string($4), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($4);
        res = new IR(kAlterTableCmd, OP3("ENABLE ALWAYS TRIGGER", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ENABLE_P REPLICA TRIGGER name {
        auto tmp1 = new IR(kIdentifier, string($4), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($4);
        res = new IR(kAlterTableCmd, OP3("ENABLE REPLICA TRIGGER", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ENABLE_P TRIGGER ALL {
        res = new IR(kAlterTableCmd, OP3("ENABLE TRIGGER ALL", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ENABLE_P TRIGGER USER {
        res = new IR(kAlterTableCmd, OP3("ENABLE TRIGGER USER", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DISABLE_P TRIGGER name {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        res = new IR(kAlterTableCmd, OP3("DISABLE TRIGGER", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DISABLE_P TRIGGER ALL {
        res = new IR(kAlterTableCmd, OP3("DISABLE TRIGGER ALL", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DISABLE_P TRIGGER USER {
        res = new IR(kAlterTableCmd, OP3("DISABLE TRIGGER USER", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ENABLE_P RULE name {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        res = new IR(kAlterTableCmd, OP3("ENABLE RULE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ENABLE_P ALWAYS RULE name {
        auto tmp1 = new IR(kIdentifier, string($4), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($4);
        res = new IR(kAlterTableCmd, OP3("ENABLE ALWAYS RULE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ENABLE_P REPLICA RULE name {
        auto tmp1 = new IR(kIdentifier, string($4), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($4);
        res = new IR(kAlterTableCmd, OP3("ENABLE REPLICA RULE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DISABLE_P RULE name {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        res = new IR(kAlterTableCmd, OP3("DISABLE RULE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | INHERIT qualified_name {
        auto tmp1 = $2;
        res = new IR(kAlterTableCmd, OP3("INHERIT", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NO INHERIT qualified_name {
        auto tmp1 = $3;
        res = new IR(kAlterTableCmd, OP3("NO INHERIT", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | OF any_name {
        auto tmp1 = $2;
        res = new IR(kAlterTableCmd, OP3("OF", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NOT OF {
        res = new IR(kAlterTableCmd, OP3("NOT OF", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | OWNER TO RoleSpec {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        res = new IR(kAlterTableCmd, OP3("OWNER TO", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SET TABLESPACE name {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        res = new IR(kAlterTableCmd, OP3("SET TABLESPACE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SET reloptions {
        auto tmp1 = $2;
        res = new IR(kAlterTableCmd, OP3("SET", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | RESET reloptions {
        auto tmp1 = $2;
        res = new IR(kAlterTableCmd, OP3("RESET", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | REPLICA IDENTITY_P replica_identity {
        auto tmp1 = $3;
        res = new IR(kAlterTableCmd, OP3("REPLICA IDENTITY", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ENABLE_P ROW LEVEL SECURITY {
        res = new IR(kAlterTableCmd, OP3("ENABLE ROW LEVEL SECURITY", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DISABLE_P ROW LEVEL SECURITY {
        res = new IR(kAlterTableCmd, OP3("DISABLE ROW LEVEL SECURITY", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FORCE ROW LEVEL SECURITY {
        res = new IR(kAlterTableCmd, OP3("FORCE ROW LEVEL SECURITY", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NO FORCE ROW LEVEL SECURITY {
        res = new IR(kAlterTableCmd, OP3("NO FORCE ROW LEVEL SECURITY", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | alter_generic_options {
        auto tmp1 = $1;
        res = new IR(kAlterTableCmd, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


alter_column_default:

    SET DEFAULT a_expr {
        auto tmp1 = $3;
        res = new IR(kAlterColumnDefault, OP3("SET DEFAULT", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DROP DEFAULT {
        res = new IR(kAlterColumnDefault, OP3("DROP DEFAULT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_drop_behavior:

    CASCADE {
        res = new IR(kOptDropBehavior, OP3("CASCADE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | RESTRICT {
        res = new IR(kOptDropBehavior, OP3("RESTRICT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kOptDropBehavior, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_collate_clause:

    COLLATE any_name {
        auto tmp1 = $2;
        res = new IR(kOptCollateClause, OP3("COLLATE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_any_name_type(kDataCollate, kNoModi);
    }

    | /* EMPTY */ {
        res = new IR(kOptCollateClause, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


alter_using:

    USING a_expr {
        auto tmp1 = $2;
        res = new IR(kAlterUsing, OP3("USING", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kAlterUsing, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


replica_identity:

    NOTHING {
        res = new IR(kReplicaIdentity, OP3("NOTHING", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FULL {
        res = new IR(kReplicaIdentity, OP3("FULL", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DEFAULT {
        res = new IR(kReplicaIdentity, OP3("DEFAULT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | USING INDEX name {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        res = new IR(kReplicaIdentity, OP3("USING INDEX", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


reloptions:

    '(' reloption_list ')' {
        auto tmp1 = $2;
        res = new IR(kReloptions, OP3("(", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_reloptions:

    WITH reloptions {
        auto tmp1 = $2;
        res = new IR(kOptReloptions, OP3("WITH", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kOptReloptions, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


reloption_list:

    reloption_elem {
        auto tmp1 = $1;
        res = new IR(kReloptionList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | reloption_list ',' reloption_elem {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kReloptionList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/* This should match def_elem and also allow qualified names */

reloption_elem:

    ColLabel '=' def_arg {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = $3;
        res = new IR(kReloptionElem, OP3("", "=", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);

        res->set_reloption_elem_type(kDataRelOption, kFlagUnknown);
        res -> set_rel_option_type(RelOptionType::StorageParameters);
        $$ = res;
    }

    | ColLabel {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kReloptionElem, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);

        res->set_reloption_elem_type(kDataRelOption, kFlagUnknown);
        res -> set_rel_option_type(RelOptionType::StorageParameters);
        $$ = res;
    }

    | ColLabel '.' ColLabel '=' def_arg {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kReloptionElem_1, OP3("", ".", "="), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kReloptionElem, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);

        res->set_reloption_elem_type(kDataRelOption, kFlagUnknown);
        res -> set_rel_option_type(RelOptionType::StorageParameters);
        $$ = res;
    }

    | ColLabel '.' ColLabel {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kReloptionElem, OP3("", ".", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);

        res->set_reloption_elem_type(kDataRelOption, kFlagUnknown);
        res -> set_rel_option_type(RelOptionType::StorageParameters);
        $$ = res;
    }

;


alter_identity_column_option_list:

    alter_identity_column_option {
        auto tmp1 = $1;
        res = new IR(kAlterIdentityColumnOptionList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | alter_identity_column_option_list alter_identity_column_option {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kAlterIdentityColumnOptionList, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


alter_identity_column_option:

    RESTART {
        res = new IR(kAlterIdentityColumnOption, OP3("RESTART", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | RESTART opt_with NumericOnly {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kAlterIdentityColumnOption, OP3("RESTART", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SET SeqOptElem {
        /* Yu: Avoid using seqoptelem that is not supported.  */
        auto tmp1 = $2;
        if (tmp1) {
            /* tmp1 -> deep_drop(); */
            rov_ir.push_back(tmp1);
            $$ = new IR(kAlterIdentityColumnOption, OP3("SET RESTART", "", ""));
        } else {
            $$ = new IR(kAlterIdentityColumnOption, OP3("SET", "", ""), tmp1);
        }
    }

    | SET GENERATED generated_when {
        auto tmp1 = $3;
        res = new IR(kAlterIdentityColumnOption, OP3("SET GENERATED", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


PartitionBoundSpec:

    FOR VALUES WITH '(' hash_partbound ')' {
        auto tmp1 = $5;
        res = new IR(kPartitionBoundSpec, OP3("FOR VALUES WITH (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FOR VALUES IN_P '(' expr_list ')' {
        auto tmp1 = $5;
        res = new IR(kPartitionBoundSpec, OP3("FOR VALUES IN (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FOR VALUES FROM '(' expr_list ')' TO '(' expr_list ')' {
        auto tmp1 = $5;
        auto tmp2 = $9;
        res = new IR(kPartitionBoundSpec, OP3("FOR VALUES FROM (", ") TO (", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DEFAULT {
        res = new IR(kPartitionBoundSpec, OP3("DEFAULT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


hash_partbound_elem:

    NonReservedWord Iconst {
        /* Yu: From the documentation, I can only see "modulus" and "remainder" available for NonReserveredWord. */
        IR* tmp1 = $2;

        if (!strcmp($1, "modulus") || !strcmp($1, "remainder")) {
            res = new IR(kHashPartboundElem_1, string($1));
            all_gen_ir.push_back(res);
        } else {
            res = new IR(kHashPartboundElem_1, string("modulus"));
            all_gen_ir.push_back(res);
        }

        res = new IR(kHashPartboundElem, OP0(), res, tmp1);
        all_gen_ir.push_back(res);
        free($1);
        $$ = res;
    }

;


hash_partbound:

    hash_partbound_elem {
        auto tmp1 = $1;
        res = new IR(kHashPartbound, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | hash_partbound ',' hash_partbound_elem {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kHashPartbound, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
*	ALTER TYPE
*
* really variants of the ALTER TABLE subcommands with different spellings
*****************************************************************************/


AlterCompositeTypeStmt:

    ALTER TYPE_P any_name alter_type_cmds {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kAlterCompositeTypeStmt, OP3("ALTER TYPE", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


alter_type_cmds:

    alter_type_cmd {
        auto tmp1 = $1;
        res = new IR(kAlterTypeCmds, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | alter_type_cmds ',' alter_type_cmd {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kAlterTypeCmds, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


alter_type_cmd:

    ADD_P ATTRIBUTE TableFuncElement opt_drop_behavior {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kAlterTypeCmd, OP3("ADD ATTRIBUTE", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DROP ATTRIBUTE IF_P EXISTS ColId opt_drop_behavior {
        auto tmp1 = new IR(kIdentifier, string($5), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($5);
        auto tmp2 = $6;
        res = new IR(kAlterTypeCmd, OP3("DROP ATTRIBUTE IF EXISTS", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DROP ATTRIBUTE ColId opt_drop_behavior {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $4;
        res = new IR(kAlterTypeCmd, OP3("DROP ATTRIBUTE", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER ATTRIBUTE ColId opt_set_data TYPE_P Typename opt_collate_clause opt_drop_behavior {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $4;
        res = new IR(kAlterTypeCmd_1, OP3("ALTER ATTRIBUTE", "", "TYPE"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kAlterTypeCmd_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $7;
        res = new IR(kAlterTypeCmd_3, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $8;
        res = new IR(kAlterTypeCmd, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
*		QUERY :
*				close <portalname>
*
*****************************************************************************/


ClosePortalStmt:

    CLOSE cursor_name {
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        res = new IR(kClosePortalStmt, OP3("CLOSE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CLOSE ALL {
        res = new IR(kClosePortalStmt, OP3("CLOSE ALL", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
*		QUERY :
*				COPY relname [(columnList)] FROM/TO file [WITH] [(options)]
*				COPY ( query ) TO file	[WITH] [(options)]
*
*				where 'query' can be one of:
*				{ SELECT | UPDATE | INSERT | DELETE }
*
*				and 'file' can be one of:
*				{ PROGRAM 'command' | STDIN | STDOUT | 'filename' }
*
*				In the preferred syntax the options are comma-separated
*				and use generic identifiers instead of keywords.  The pre-9.0
*				syntax had a hard-wired, space-separated set of options.
*
*				Really old syntax, from versions 7.2 and prior:
*				COPY [ BINARY ] table FROM/TO file
*					[ [ USING ] DELIMITERS 'delimiter' ] ]
*					[ WITH NULL AS 'null string' ]
*				This option placement is not supported with COPY (query...).
*
*****************************************************************************/


CopyStmt:

    COPY opt_binary qualified_name opt_column_list copy_from opt_program copy_file_name copy_delimiter opt_with copy_options where_clause {
        /* Yu: Do not allow opt_program and copy_file_name at the same time.  */
        /* Yu: Do not allow copy_from and where_clause at the same time.  */
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kCopyStmt_1, OP3("COPY", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $4;
        res = new IR(kCopyStmt_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $5;
        res = new IR(kCopyStmt_3, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $6;
        res = new IR(kCopyStmt_4, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        if ($6->is_empty() &&
            (!strcmp($7->get_prefix(), "STDIN") || !strcmp($7->get_prefix(), "STDOUT"))
        ){
            auto tmp6 = $7;
            res = new IR(kCopyStmt_5, OP3("", "", ""), res, tmp6);
            all_gen_ir.push_back(res);
            printf("In 1");
        } else {
            /* $7 -> deep_drop(); */
            rov_ir.push_back($7);
            printf("In 2\n");
        }
        auto tmp7 = $8;
        res = new IR(kCopyStmt_6, OP3("", "", ""), res, tmp7);
        all_gen_ir.push_back(res);
        auto tmp8 = $9;
        res = new IR(kCopyStmt_7, OP3("", "", ""), res, tmp8);
        all_gen_ir.push_back(res);
        auto tmp9 = $10;
        res = new IR(kCopyStmt_8, OP3("", "", ""), res, tmp9);
        all_gen_ir.push_back(res);

        if (!$5->is_empty()) {
            auto tmp10 = $11;
            res = new IR(kCopyStmt, OP3("", "", ""), res, tmp10);
            all_gen_ir.push_back(res);
        } else {
            /* $11->deep_drop(); */
            rov_ir.push_back($11);
        }
        $$ = res;
    }

    | COPY '(' PreparableStmt ')' TO opt_program copy_file_name opt_with copy_options {
        /* Yu: Do not allow opt_program and copy_file_name at the same time.  */
        auto tmp1 = $3;
        auto tmp2 = $6;
        res = new IR(kCopyStmt_9, OP3("COPY (", ") TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        if (!$6->is_empty() &&
            (!strcmp($6->get_prefix(), "STDIN") || !strcmp($6->get_prefix(), "STDOUT"))
        ){
            auto tmp3 = $7;
            res = new IR(kCopyStmt_10, OP3("", "", ""), res, tmp3);
            all_gen_ir.push_back(res);
        } else {
            /* $7 -> deep_drop(); */
            rov_ir.push_back($7);
        }
        auto tmp4 = $8;
        res = new IR(kCopyStmt_11, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $9;
        res = new IR(kCopyStmt, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


copy_from:

    FROM {
        res = new IR(kCopyFrom, OP3("FROM", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TO {
        res = new IR(kCopyFrom, OP3("TO", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_program:

    PROGRAM {
        res = new IR(kOptProgram, OP3("PROGRAM", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kOptProgram, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* copy_file_name NULL indicates stdio is used. Whether stdin or stdout is
* used depends on the direction. (It really doesn't make sense to copy from
* stdout. We silently correct the "typo".)		 - AY 9/94
*/

copy_file_name:

    Sconst {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kCopyFileName, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | STDIN {
        res = new IR(kCopyFileName, OP3("STDIN", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | STDOUT {
        res = new IR(kCopyFileName, OP3("STDOUT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


copy_options:

    copy_opt_list {
        auto tmp1 = $1;
        res = new IR(kCopyOptions, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '(' copy_generic_opt_list ')' {
        auto tmp1 = $2;
        res = new IR(kCopyOptions, OP3("(", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/* old COPY option syntax */

copy_opt_list:

    copy_opt_list copy_opt_item {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kCopyOptList, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kCopyOptList, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


copy_opt_item:

    BINARY {
        res = new IR(kCopyOptItem, OP3("BINARY", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FREEZE {
        res = new IR(kCopyOptItem, OP3("FREEZE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DELIMITER opt_as Sconst {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kCopyOptItem, OP3("DELIMITER", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NULL_P opt_as Sconst {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kCopyOptItem, OP3("NULL", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CSV {
        res = new IR(kCopyOptItem, OP3("CSV", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | HEADER_P {
        res = new IR(kCopyOptItem, OP3("HEADER", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | QUOTE opt_as Sconst {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kCopyOptItem, OP3("QUOTE", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ESCAPE opt_as Sconst {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kCopyOptItem, OP3("ESCAPE", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FORCE QUOTE columnList {
        auto tmp1 = $3;
        res = new IR(kCopyOptItem, OP3("FORCE QUOTE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FORCE QUOTE '*' {
        res = new IR(kCopyOptItem, OP3("FORCE QUOTE *", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FORCE NOT NULL_P columnList {
        auto tmp1 = $4;
        res = new IR(kCopyOptItem, OP3("FORCE NOT NULL", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FORCE NULL_P columnList {
        auto tmp1 = $3;
        res = new IR(kCopyOptItem, OP3("FORCE NULL", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ENCODING Sconst {
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        res = new IR(kCopyOptItem, OP3("ENCODING", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/* The following exist for backward compatibility with very old versions */


opt_binary:

    BINARY {
        res = new IR(kOptBinary, OP3("BINARY", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptBinary, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


copy_delimiter:

    opt_using DELIMITERS Sconst {
        auto tmp1 = $1;
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kCopyDelimiter, OP3("", "DELIMITERS", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kCopyDelimiter, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_using:

    USING {
        res = new IR(kOptUsing, OP3("USING", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptUsing, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/* new COPY option syntax */

copy_generic_opt_list:

    copy_generic_opt_elem {
        auto tmp1 = $1;
        res = new IR(kCopyGenericOptList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | copy_generic_opt_list ',' copy_generic_opt_elem {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kCopyGenericOptList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


copy_generic_opt_elem:

    ColLabel copy_generic_opt_arg {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = $2;
        res = new IR(kCopyGenericOptElem, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


copy_generic_opt_arg:

    opt_boolean_or_string {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kCopyGenericOptArg, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NumericOnly {
        auto tmp1 = $1;
        res = new IR(kCopyGenericOptArg, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '*' {
        res = new IR(kCopyGenericOptArg, OP3("*", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '(' copy_generic_opt_arg_list ')' {
        auto tmp1 = $2;
        res = new IR(kCopyGenericOptArg, OP3("(", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kCopyGenericOptArg, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


copy_generic_opt_arg_list:

    copy_generic_opt_arg_list_item {
        auto tmp1 = $1;
        res = new IR(kCopyGenericOptArgList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | copy_generic_opt_arg_list ',' copy_generic_opt_arg_list_item {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kCopyGenericOptArgList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/* beware of emitting non-string list elements here; see commands/define.c */

copy_generic_opt_arg_list_item:

    opt_boolean_or_string {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kCopyGenericOptArgListItem, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
*		QUERY :
*				CREATE TABLE relname
*
*****************************************************************************/


CreateStmt:

    CREATE OptTemp TABLE qualified_name '(' OptTableElementList ')' OptInherit OptPartitionSpec table_access_method_clause OptWith OnCommitOption OptTableSpace {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kCreateStmt_1, OP3("CREATE", "TABLE", "("), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kCreateStmt_2, OP3("", "", ")"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $8;
        res = new IR(kCreateStmt_3, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $9;
        res = new IR(kCreateStmt_4, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        auto tmp6 = $10;
        res = new IR(kCreateStmt_5, OP3("", "", ""), res, tmp6);
        all_gen_ir.push_back(res);
        auto tmp7 = $11;
        res = new IR(kCreateStmt_6, OP3("", "", ""), res, tmp7);
        all_gen_ir.push_back(res);
        auto tmp8 = $12;
        res = new IR(kCreateStmt_7, OP3("", "", ""), res, tmp8);
        all_gen_ir.push_back(res);
        auto tmp9 = $13;
        res = new IR(kCreateStmt, OP3("", "", ""), res, tmp9);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp2->set_qualified_name_type(kDataTableName, kDefine);
    }

    | CREATE OptTemp TABLE IF_P NOT EXISTS qualified_name '(' OptTableElementList ')' OptInherit OptPartitionSpec table_access_method_clause OptWith OnCommitOption OptTableSpace {
        auto tmp1 = $2;
        auto tmp2 = $7;
        res = new IR(kCreateStmt_8, OP3("CREATE", "TABLE IF NOT EXISTS", "("), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $9;
        res = new IR(kCreateStmt_9, OP3("", "", ")"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $11;
        res = new IR(kCreateStmt_10, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $12;
        res = new IR(kCreateStmt_11, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        auto tmp6 = $13;
        res = new IR(kCreateStmt_12, OP3("", "", ""), res, tmp6);
        all_gen_ir.push_back(res);
        auto tmp7 = $14;
        res = new IR(kCreateStmt_13, OP3("", "", ""), res, tmp7);
        all_gen_ir.push_back(res);
        auto tmp8 = $15;
        res = new IR(kCreateStmt_14, OP3("", "", ""), res, tmp8);
        all_gen_ir.push_back(res);
        auto tmp9 = $16;
        res = new IR(kCreateStmt, OP3("", "", ""), res, tmp9);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp2->set_qualified_name_type(kDataTableName, kDefine);

    }

    | CREATE OptTemp TABLE qualified_name OF any_name OptTypedTableElementList OptPartitionSpec table_access_method_clause OptWith OnCommitOption OptTableSpace {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kCreateStmt_15, OP3("CREATE", "TABLE", "OF"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kCreateStmt_16, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $7;
        res = new IR(kCreateStmt_17, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $8;
        res = new IR(kCreateStmt_18, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        auto tmp6 = $9;
        res = new IR(kCreateStmt_19, OP3("", "", ""), res, tmp6);
        all_gen_ir.push_back(res);
        auto tmp7 = $10;
        res = new IR(kCreateStmt_20, OP3("", "", ""), res, tmp7);
        all_gen_ir.push_back(res);
        auto tmp8 = $11;
        res = new IR(kCreateStmt_21, OP3("", "", ""), res, tmp8);
        all_gen_ir.push_back(res);
        auto tmp9 = $12;
        res = new IR(kCreateStmt, OP3("", "", ""), res, tmp9);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp2->set_qualified_name_type(kDataTableName, kDefine);

    }

    | CREATE OptTemp TABLE IF_P NOT EXISTS qualified_name OF any_name OptTypedTableElementList OptPartitionSpec table_access_method_clause OptWith OnCommitOption OptTableSpace {
        auto tmp1 = $2;
        auto tmp2 = $7;
        res = new IR(kCreateStmt_22, OP3("CREATE", "TABLE IF NOT EXISTS", "OF"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $9;
        res = new IR(kCreateStmt_23, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $10;
        res = new IR(kCreateStmt_24, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $11;
        res = new IR(kCreateStmt_25, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        auto tmp6 = $12;
        res = new IR(kCreateStmt_26, OP3("", "", ""), res, tmp6);
        all_gen_ir.push_back(res);
        auto tmp7 = $13;
        res = new IR(kCreateStmt_27, OP3("", "", ""), res, tmp7);
        all_gen_ir.push_back(res);
        auto tmp8 = $14;
        res = new IR(kCreateStmt_28, OP3("", "", ""), res, tmp8);
        all_gen_ir.push_back(res);
        auto tmp9 = $15;
        res = new IR(kCreateStmt, OP3("", "", ""), res, tmp9);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp2->set_qualified_name_type(kDataTableName, kDefine);

    }

    | CREATE OptTemp TABLE qualified_name PARTITION OF qualified_name OptTypedTableElementList PartitionBoundSpec OptPartitionSpec table_access_method_clause OptWith OnCommitOption OptTableSpace {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kCreateStmt_29, OP3("CREATE", "TABLE", "PARTITION OF"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $7;
        res = new IR(kCreateStmt_30, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $8;
        res = new IR(kCreateStmt_31, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $9;
        res = new IR(kCreateStmt_32, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        auto tmp6 = $10;
        res = new IR(kCreateStmt_33, OP3("", "", ""), res, tmp6);
        all_gen_ir.push_back(res);
        auto tmp7 = $11;
        res = new IR(kCreateStmt_34, OP3("", "", ""), res, tmp7);
        all_gen_ir.push_back(res);
        auto tmp8 = $12;
        res = new IR(kCreateStmt_35, OP3("", "", ""), res, tmp8);
        all_gen_ir.push_back(res);
        auto tmp9 = $13;
        res = new IR(kCreateStmt_36, OP3("", "", ""), res, tmp9);
        all_gen_ir.push_back(res);
        auto tmp10 = $14;
        res = new IR(kCreateStmt, OP3("", "", ""), res, tmp10);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp2->set_qualified_name_type(kDataTableName, kDefine);
        tmp3->set_qualified_name_type(kDataTableName, kUse);

    }

    | CREATE OptTemp TABLE IF_P NOT EXISTS qualified_name PARTITION OF qualified_name OptTypedTableElementList PartitionBoundSpec OptPartitionSpec table_access_method_clause OptWith OnCommitOption OptTableSpace {
        auto tmp1 = $2;
        auto tmp2 = $7;
        res = new IR(kCreateStmt_37, OP3("CREATE", "TABLE IF NOT EXISTS", "PARTITION OF"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $10;
        res = new IR(kCreateStmt_38, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $11;
        res = new IR(kCreateStmt_39, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $12;
        res = new IR(kCreateStmt_40, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        auto tmp6 = $13;
        res = new IR(kCreateStmt_41, OP3("", "", ""), res, tmp6);
        all_gen_ir.push_back(res);
        auto tmp7 = $14;
        res = new IR(kCreateStmt_42, OP3("", "", ""), res, tmp7);
        all_gen_ir.push_back(res);
        auto tmp8 = $15;
        res = new IR(kCreateStmt_43, OP3("", "", ""), res, tmp8);
        all_gen_ir.push_back(res);
        auto tmp9 = $16;
        res = new IR(kCreateStmt_44, OP3("", "", ""), res, tmp9);
        all_gen_ir.push_back(res);
        auto tmp10 = $17;
        res = new IR(kCreateStmt, OP3("", "", ""), res, tmp10);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp2->set_qualified_name_type(kDataTableName, kDefine);
        tmp3->set_qualified_name_type(kDataTableName, kUse);
    }

;

/*
* Redundancy here is needed to avoid shift/reduce conflicts,
* since TEMP is not a reserved word.  See also OptTempTableName.
*
* NOTE: we accept both GLOBAL and LOCAL options.  They currently do nothing,
* but future versions might consider GLOBAL to request SQL-spec-compliant
* temp table behavior, so warn about that.  Since we have no modules the
* LOCAL keyword is really meaningless; furthermore, some other products
* implement LOCAL as meaning the same as our default temp table behavior,
* so we'll probably continue to treat LOCAL as a noise word.
*/

OptTemp:

    TEMPORARY {
        res = new IR(kOptTemp, OP3("TEMPORARY", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TEMP {
        res = new IR(kOptTemp, OP3("TEMP", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | LOCAL TEMPORARY {
        res = new IR(kOptTemp, OP3("LOCAL TEMPORARY", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | LOCAL TEMP {
        res = new IR(kOptTemp, OP3("LOCAL TEMP", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | GLOBAL TEMPORARY {
        res = new IR(kOptTemp, OP3("GLOBAL TEMPORARY", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | GLOBAL TEMP {
        res = new IR(kOptTemp, OP3("GLOBAL TEMP", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | UNLOGGED {
        res = new IR(kOptTemp, OP3("UNLOGGED", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptTemp, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


OptTableElementList:

    TableElementList {
        auto tmp1 = $1;
        res = new IR(kOptTableElementList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptTableElementList, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


OptTypedTableElementList:

    '(' TypedTableElementList ')' {
        auto tmp1 = $2;
        res = new IR(kOptTypedTableElementList, OP3("(", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptTypedTableElementList, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


TableElementList:

    TableElement {
        auto tmp1 = $1;
        res = new IR(kTableElementList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TableElementList ',' TableElement {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kTableElementList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


TypedTableElementList:

    TypedTableElement {
        auto tmp1 = $1;
        res = new IR(kTypedTableElementList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TypedTableElementList ',' TypedTableElement {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kTypedTableElementList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


TableElement:

    columnDef {
        auto tmp1 = $1;
        res = new IR(kTableElement, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TableLikeClause {
        auto tmp1 = $1;
        res = new IR(kTableElement, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TableConstraint {
        auto tmp1 = $1;
        res = new IR(kTableElement, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


TypedTableElement:

    columnOptions {
        auto tmp1 = $1;
        res = new IR(kTypedTableElement, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TableConstraint {
        auto tmp1 = $1;
        res = new IR(kTypedTableElement, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


columnDef:

    ColId Typename opt_column_compression create_generic_options ColQualList {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = $2;
        res = new IR(kColumnDef_1, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $3;
        res = new IR(kColumnDef_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $4;
        res = new IR(kColumnDef_3, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $5;
        res = new IR(kColumnDef, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_iden_type(kDataColumnName, kDefine);
    }

;


columnOptions:

    ColId ColQualList {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = $2;
        res = new IR(kColumnOptions, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_iden_type(kDataColumnName, kDefine);
    }

    | ColId WITH OPTIONS ColQualList {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = $4;
        res = new IR(kColumnOptions, OP3("", "WITH OPTIONS", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_iden_type(kDataColumnName, kDefine);
    }

;


column_compression:

    COMPRESSION ColId {
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        res = new IR(kColumnCompression, OP3("COMPRESSION", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | COMPRESSION DEFAULT {
        res = new IR(kColumnCompression, OP3("COMPRESSION DEFAULT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_column_compression:

    column_compression {
        auto tmp1 = $1;
        res = new IR(kOptColumnCompression, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptColumnCompression, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


ColQualList:

    ColQualList ColConstraint {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kColQualList, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kColQualList, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


ColConstraint:

    CONSTRAINT name ColConstraintElem {
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        auto tmp2 = $3;
        res = new IR(kColConstraint, OP3("CONSTRAINT", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_iden_type(kDataConstraintName, kUse);
    }

    | ColConstraintElem {
        auto tmp1 = $1;
        res = new IR(kColConstraint, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ConstraintAttr {
        auto tmp1 = $1;
        res = new IR(kColConstraint, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | COLLATE any_name {
        auto tmp1 = $2;
        res = new IR(kColConstraint, OP3("COLLATE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_any_name_type(kDataCollate, kNoModi);
    }

;

/* DEFAULT NULL is already the default for Postgres.
* But define it here and carry it forward into the system
* to make it explicit.
* - thomas 1998-09-13
*
* WITH NULL and NULL are not SQL-standard syntax elements,
* so leave them out. Use DEFAULT NULL to explicitly indicate
* that a column may have that value. WITH NULL leads to
* shift/reduce conflicts with WITH TIME ZONE anyway.
* - thomas 1999-01-08
*
* DEFAULT expression must be b_expr not a_expr to prevent shift/reduce
* conflict on NOT (since NOT might start a subsequent NOT NULL constraint,
* or be part of a_expr NOT LIKE or similar constructs).
*/

ColConstraintElem:

    NOT NULL_P {
        res = new IR(kColConstraintElem, OP3("NOT NULL", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NULL_P {
        res = new IR(kColConstraintElem, OP3("NULL", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | UNIQUE opt_definition OptConsTableSpace {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kColConstraintElem, OP3("UNIQUE", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | PRIMARY KEY opt_definition OptConsTableSpace {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kColConstraintElem, OP3("PRIMARY KEY", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CHECK '(' a_expr ')' opt_no_inherit {
        auto tmp1 = $3;
        auto tmp2 = $5;
        res = new IR(kColConstraintElem, OP3("CHECK (", ")", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DEFAULT b_expr {
        auto tmp1 = $2;
        res = new IR(kColConstraintElem, OP3("DEFAULT", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | GENERATED generated_when AS IDENTITY_P OptParenthesizedSeqOptList {
        auto tmp1 = $2;
        auto tmp2 = $5;
        res = new IR(kColConstraintElem, OP3("GENERATED", "AS IDENTITY", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | GENERATED generated_when AS '(' a_expr ')' STORED {
        /* Yu: Enforced ALWAYS in the generated_when. */
        auto tmp1 = $2;
        if (!strcmp(tmp1->get_prefix(), "BY DEFAULT")){
            /* tmp1->deep_drop(); */
            rov_ir.push_back(tmp1);
            tmp1 = new IR(kGeneratedWhen, OP3("ALWAYS", "", ""));
            all_gen_ir.push_back(tmp1);
        }
        auto tmp2 = $5;
        res = new IR(kColConstraintElem, OP3("GENERATED", "AS (", ") STORED"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | REFERENCES qualified_name opt_column_list key_match key_actions {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kColConstraintElem_1, OP3("REFERENCES", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $4;
        res = new IR(kColConstraintElem_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $5;
        res = new IR(kColConstraintElem, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


generated_when:

    ALWAYS {
        res = new IR(kGeneratedWhen, OP3("ALWAYS", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | BY DEFAULT {
        res = new IR(kGeneratedWhen, OP3("BY DEFAULT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* ConstraintAttr represents constraint attributes, which we parse as if
* they were independent constraint clauses, in order to avoid shift/reduce
* conflicts (since NOT might start either an independent NOT NULL clause
* or an attribute).  parse_utilcmd.c is responsible for attaching the
* attribute information to the preceding "real" constraint node, and for
* complaining if attribute clauses appear in the wrong place or wrong
* combinations.
*
* See also ConstraintAttributeSpec, which can be used in places where
* there is no parsing conflict.  (Note: currently, NOT VALID and NO INHERIT
* are allowed clauses in ConstraintAttributeSpec, but not here.  Someday we
* might need to allow them here too, but for the moment it doesn't seem
* useful in the statements that use ConstraintAttr.)
*/

ConstraintAttr:

    DEFERRABLE {
        res = new IR(kConstraintAttr, OP3("DEFERRABLE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NOT DEFERRABLE {
        res = new IR(kConstraintAttr, OP3("NOT DEFERRABLE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | INITIALLY DEFERRED {
        res = new IR(kConstraintAttr, OP3("INITIALLY DEFERRED", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | INITIALLY IMMEDIATE {
        res = new IR(kConstraintAttr, OP3("INITIALLY IMMEDIATE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;



TableLikeClause:

    LIKE qualified_name TableLikeOptionList {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kTableLikeClause, OP3("LIKE", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_qualified_name_type(kDataTableName, kUse);
    }

;


TableLikeOptionList:

    TableLikeOptionList INCLUDING TableLikeOption {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kTableLikeOptionList, OP3("", "INCLUDING", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TableLikeOptionList EXCLUDING TableLikeOption {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kTableLikeOptionList, OP3("", "EXCLUDING", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kTableLikeOptionList, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


TableLikeOption:

    COMMENTS {
        res = new IR(kTableLikeOption, OP3("COMMENTS", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | COMPRESSION {
        res = new IR(kTableLikeOption, OP3("COMPRESSION", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CONSTRAINTS {
        res = new IR(kTableLikeOption, OP3("CONSTRAINTS", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DEFAULTS {
        res = new IR(kTableLikeOption, OP3("DEFAULTS", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | IDENTITY_P {
        res = new IR(kTableLikeOption, OP3("IDENTITY", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | GENERATED {
        res = new IR(kTableLikeOption, OP3("GENERATED", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | INDEXES {
        res = new IR(kTableLikeOption, OP3("INDEXES", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | STATISTICS {
        res = new IR(kTableLikeOption, OP3("STATISTICS", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | STORAGE {
        res = new IR(kTableLikeOption, OP3("STORAGE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALL {
        res = new IR(kTableLikeOption, OP3("ALL", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/* ConstraintElem specifies constraint syntax which is not embedded into
*	a column definition. ColConstraintElem specifies the embedded form.
* - thomas 1997-12-03
*/

TableConstraint:

    CONSTRAINT name ConstraintElem {
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        auto tmp2 = $3;
        res = new IR(kTableConstraint, OP3("CONSTRAINT", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_iden_type(kDataConstraintName, kDefine);
    }

    | ConstraintElem {
        auto tmp1 = $1;
        res = new IR(kTableConstraint, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


ConstraintElem:

    CHECK '(' a_expr ')' ConstraintAttributeSpec {
        auto tmp1 = $3;
        auto tmp2 = $5;
        res = new IR(kConstraintElem, OP3("CHECK (", ")", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | UNIQUE '(' columnList ')' opt_c_include opt_definition OptConsTableSpace ConstraintAttributeSpec {
        auto tmp1 = $3;
        auto tmp2 = $5;
        res = new IR(kConstraintElem_1, OP3("UNIQUE (", ")", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kConstraintElem_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $7;
        res = new IR(kConstraintElem_3, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $8;
        res = new IR(kConstraintElem, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_columnlist_type(kDataColumnName, kUse);
    }

    | UNIQUE ExistingIndex ConstraintAttributeSpec {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kConstraintElem, OP3("UNIQUE", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | PRIMARY KEY '(' columnList ')' opt_c_include opt_definition OptConsTableSpace ConstraintAttributeSpec {
        auto tmp1 = $4;
        auto tmp2 = $6;
        res = new IR(kConstraintElem_4, OP3("PRIMARY KEY (", ")", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $7;
        res = new IR(kConstraintElem_5, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $8;
        res = new IR(kConstraintElem_6, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $9;
        res = new IR(kConstraintElem, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_columnlist_type(kDataColumnName, kUse);
    }

    | PRIMARY KEY ExistingIndex ConstraintAttributeSpec {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kConstraintElem, OP3("PRIMARY KEY", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | EXCLUDE access_method_clause '(' ExclusionConstraintList ')' opt_c_include opt_definition OptConsTableSpace OptWhereClause ConstraintAttributeSpec {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kConstraintElem_7, OP3("EXCLUDE", "(", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kConstraintElem_8, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $7;
        res = new IR(kConstraintElem_9, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $8;
        res = new IR(kConstraintElem_10, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        auto tmp6 = $9;
        res = new IR(kConstraintElem_11, OP3("", "", ""), res, tmp6);
        all_gen_ir.push_back(res);
        auto tmp7 = $10;
        res = new IR(kConstraintElem, OP3("", "", ""), res, tmp7);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FOREIGN KEY '(' columnList ')' REFERENCES qualified_name opt_column_list key_match key_actions ConstraintAttributeSpec {
        auto tmp1 = $4;
        auto tmp2 = $7;
        res = new IR(kConstraintElem_12, OP3("FOREIGN KEY (", ") REFERENCES", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $8;
        res = new IR(kConstraintElem_13, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $9;
        res = new IR(kConstraintElem_14, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $10;
        res = new IR(kConstraintElem_15, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        auto tmp6 = $11;
        res = new IR(kConstraintElem, OP3("", "", ""), res, tmp6);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_columnlist_type(kDataColumnName, kUse);
        tmp2->set_qualified_name_type(kDataTableName, kUse);
        tmp3->set_opt_columnlist_type(kDataColumnName, kUse);
    }

;


opt_no_inherit:

    NO INHERIT {
        res = new IR(kOptNoInherit, OP3("NO INHERIT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kOptNoInherit, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_column_list:

    '(' columnList ')' {
        auto tmp1 = $2;
        res = new IR(kOptColumnList, OP3("(", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptColumnList, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


columnList:

    columnElem {
        auto tmp1 = $1;
        res = new IR(kColumnList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | columnList ',' columnElem {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kColumnList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


columnElem:

    ColId {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kColumnElem, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_iden_type(kDataColumnName, kUse);
    }

;


opt_c_include:

    INCLUDE '(' columnList ')' {
        auto tmp1 = $3;
        res = new IR(kOptCInclude, OP3("INCLUDE (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kOptCInclude, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


key_match:

    MATCH FULL {
        res = new IR(kKeyMatch, OP3("MATCH FULL", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | MATCH PARTIAL {
        /* Yu: MATCH PARTIAL is not yet implemented. */
        res = new IR(kKeyMatch, OP3("MATCH FULL", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | MATCH SIMPLE {
        res = new IR(kKeyMatch, OP3("MATCH SIMPLE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kKeyMatch, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


ExclusionConstraintList:

    ExclusionConstraintElem {
        auto tmp1 = $1;
        res = new IR(kExclusionConstraintList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ExclusionConstraintList ',' ExclusionConstraintElem {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kExclusionConstraintList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


ExclusionConstraintElem:

    index_elem WITH any_operator {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kExclusionConstraintElem, OP3("", "WITH", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | index_elem WITH OPERATOR '(' any_operator ')' {
        auto tmp1 = $1;
        auto tmp2 = $5;
        res = new IR(kExclusionConstraintElem, OP3("", "WITH OPERATOR (", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


OptWhereClause:

    WHERE '(' a_expr ')' {
        auto tmp1 = $3;
        res = new IR(kOptWhereClause, OP3("WHERE (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptWhereClause, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* We combine the update and delete actions into one value temporarily
* for simplicity of parsing, and then break them down again in the
* calling production.  update is in the left 8 bits, delete in the right.
* Note that NOACTION is the default.
*/

key_actions:

    key_update {
        auto tmp1 = $1;
        res = new IR(kKeyActions, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | key_delete {
        auto tmp1 = $1;
        res = new IR(kKeyActions, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | key_update key_delete {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kKeyActions, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | key_delete key_update {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kKeyActions, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kKeyActions, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


key_update:

    ON UPDATE key_action {
        auto tmp1 = $3;
        res = new IR(kKeyUpdate, OP3("ON UPDATE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


key_delete:

    ON DELETE_P key_action {
        auto tmp1 = $3;
        res = new IR(kKeyDelete, OP3("ON DELETE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


key_action:

    NO ACTION {
        res = new IR(kKeyAction, OP3("NO ACTION", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | RESTRICT {
        res = new IR(kKeyAction, OP3("RESTRICT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CASCADE {
        res = new IR(kKeyAction, OP3("CASCADE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SET NULL_P {
        res = new IR(kKeyAction, OP3("SET NULL", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SET DEFAULT {
        res = new IR(kKeyAction, OP3("SET DEFAULT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


OptInherit:

    INHERITS '(' qualified_name_list ')' {
        auto tmp1 = $3;
        res = new IR(kOptInherit, OP3("INHERITS (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_qualified_name_list_type(kDataTableName, kUse);
    }

    | /*EMPTY*/ {
        res = new IR(kOptInherit, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/* Optional partition key specification */

OptPartitionSpec:

    PartitionSpec {
        auto tmp1 = $1;
        res = new IR(kOptPartitionSpec, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptPartitionSpec, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


PartitionSpec:

    PARTITION BY ColId '(' part_params ')' {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $5;
        res = new IR(kPartitionSpec, OP3("PARTITION BY", "(", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_iden_type(kDataFunctionName, kUse);
    }

;


part_params:

    part_elem {
        auto tmp1 = $1;
        res = new IR(kPartParams, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | part_params ',' part_elem {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kPartParams, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


part_elem:

    ColId opt_collate opt_class {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = $2;
        res = new IR(kPartElem_1, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $3;
        res = new IR(kPartElem, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_iden_type(kDataColumnName, kUse);
    }

    | func_expr_windowless opt_collate opt_class {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kPartElem_2, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $3;
        res = new IR(kPartElem, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '(' a_expr ')' opt_collate opt_class {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kPartElem_3, OP3("(", ")", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kPartElem, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


table_access_method_clause:

    USING name {
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        res = new IR(kTableAccessMethodClause, OP3("USING", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kTableAccessMethodClause, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/* WITHOUT OIDS is legacy only */

OptWith:

    WITH reloptions {
        auto tmp1 = $2;
        res = new IR(kOptWith, OP3("WITH", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | WITHOUT OIDS {
        res = new IR(kOptWith, OP3("WITHOUT OIDS", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptWith, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


OnCommitOption:

    ON COMMIT DROP {
        res = new IR(kOnCommitOption, OP3("ON COMMIT DROP", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ON COMMIT DELETE_P ROWS {
        res = new IR(kOnCommitOption, OP3("ON COMMIT DELETE ROWS", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ON COMMIT PRESERVE ROWS {
        res = new IR(kOnCommitOption, OP3("ON COMMIT PRESERVE ROWS", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOnCommitOption, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


OptTableSpace:

    TABLESPACE name {
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        res = new IR(kOptTableSpace, OP3("TABLESPACE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_iden_type(kDataTableSpaceName, kUse);
    }

    | /*EMPTY*/ {
        res = new IR(kOptTableSpace, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


OptConsTableSpace:

    USING INDEX TABLESPACE name {
        auto tmp1 = new IR(kIdentifier, string($4), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($4);
        res = new IR(kOptConsTableSpace, OP3("USING INDEX TABLESPACE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptConsTableSpace, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


ExistingIndex:

    USING INDEX name {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        res = new IR(kExistingIndex, OP3("USING INDEX", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_iden_type(kDataIndexName, kUse);
    }

;

/*****************************************************************************
*
*		QUERY :
*				CREATE STATISTICS [IF NOT EXISTS] stats_name [(stat types)]
*					ON expression-list FROM from_list
*
* Note: the expectation here is that the clauses after ON are a subset of
* SELECT syntax, allowing for expressions and joined tables, and probably
* someday a WHERE clause.  Much less than that is currently implemented,
* but the grammar accepts it and then we'll throw FEATURE_NOT_SUPPORTED
* errors as necessary at execution.
*
*****************************************************************************/


CreateStatsStmt:

    CREATE STATISTICS any_name opt_name_list ON stats_params FROM from_list {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kCreateStatsStmt_1, OP3("CREATE STATISTICS", "", "ON"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kCreateStatsStmt_2, OP3("", "", "FROM"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $8;
        res = new IR(kCreateStatsStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_any_name_type(kDataStatisticName, kDefine);
    }

    | CREATE STATISTICS IF_P NOT EXISTS any_name opt_name_list ON stats_params FROM from_list {
        auto tmp1 = $6;
        auto tmp2 = $7;
        res = new IR(kCreateStatsStmt_3, OP3("CREATE STATISTICS IF NOT EXISTS", "", "ON"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $9;
        res = new IR(kCreateStatsStmt_4, OP3("", "", "FROM"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $11;
        res = new IR(kCreateStatsStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_any_name_type(kDataStatisticName, kDefine);
    }

;

/*
* Statistics attributes can be either simple column references, or arbitrary
* expressions in parens.  For compatibility with index attributes permitted
* in CREATE INDEX, we allow an expression that's just a function call to be
* written without parens.
*/


stats_params:

    stats_param {
        auto tmp1 = $1;
        res = new IR(kStatsParams, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | stats_params ',' stats_param {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kStatsParams, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


stats_param:

    ColId {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kStatsParam, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_iden_type(kDataColumnName, kUse);
    }

    | func_expr_windowless {
        auto tmp1 = $1;
        res = new IR(kStatsParam, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '(' a_expr ')' {
        auto tmp1 = $2;
        res = new IR(kStatsParam, OP3("(", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
*		QUERY :
*				ALTER STATISTICS [IF EXISTS] stats_name
*					SET STATISTICS  <SignedIconst>
*
*****************************************************************************/


AlterStatsStmt:

    ALTER STATISTICS any_name SET STATISTICS SignedIconst {
        auto tmp1 = $3;
        auto tmp2 = $6;
        res = new IR(kAlterStatsStmt, OP3("ALTER STATISTICS", "SET STATISTICS", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER STATISTICS IF_P EXISTS any_name SET STATISTICS SignedIconst {
        auto tmp1 = $5;
        auto tmp2 = $8;
        res = new IR(kAlterStatsStmt, OP3("ALTER STATISTICS IF EXISTS", "SET STATISTICS", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
*		QUERY :
*				CREATE TABLE relname AS SelectStmt [ WITH [NO] DATA ]
*
*
* Note: SELECT ... INTO is a now-deprecated alternative for this.
*
*****************************************************************************/


CreateAsStmt:

    CREATE OptTemp TABLE create_as_target AS SelectStmt opt_with_data {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kCreateAsStmt_1, OP3("CREATE", "TABLE", "AS"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kCreateAsStmt_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $7;
        res = new IR(kCreateAsStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CREATE OptTemp TABLE IF_P NOT EXISTS create_as_target AS SelectStmt opt_with_data {
        auto tmp1 = $2;
        auto tmp2 = $7;
        res = new IR(kCreateAsStmt_3, OP3("CREATE", "TABLE IF NOT EXISTS", "AS"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $9;
        res = new IR(kCreateAsStmt_4, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $10;
        res = new IR(kCreateAsStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


create_as_target:

    qualified_name opt_column_list table_access_method_clause OptWith OnCommitOption OptTableSpace {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kCreateAsTarget_1, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $3;
        res = new IR(kCreateAsTarget_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $4;
        res = new IR(kCreateAsTarget_3, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $5;
        res = new IR(kCreateAsTarget_4, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        auto tmp6 = $6;
        res = new IR(kCreateAsTarget, OP3("", "", ""), res, tmp6);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_qualified_name_type(kDataTableName, kDefine);
        tmp2->set_opt_columnlist_type(kDataColumnName, kDefine);
    }

;


opt_with_data:

    WITH DATA_P {
        res = new IR(kOptWithData, OP3("WITH DATA", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | WITH NO DATA_P {
        res = new IR(kOptWithData, OP3("WITH NO DATA", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptWithData, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
*		QUERY :
*				CREATE MATERIALIZED VIEW relname AS SelectStmt
*
*****************************************************************************/


CreateMatViewStmt:

    CREATE OptNoLog MATERIALIZED VIEW create_mv_target AS SelectStmt opt_with_data {
        auto tmp1 = $2;
        auto tmp2 = $5;
        res = new IR(kCreateMatViewStmt_1, OP3("CREATE", "MATERIALIZED VIEW", "AS"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $7;
        res = new IR(kCreateMatViewStmt_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $8;
        res = new IR(kCreateMatViewStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CREATE OptNoLog MATERIALIZED VIEW IF_P NOT EXISTS create_mv_target AS SelectStmt opt_with_data {
        auto tmp1 = $2;
        auto tmp2 = $8;
        res = new IR(kCreateMatViewStmt_3, OP3("CREATE", "MATERIALIZED VIEW IF NOT EXISTS", "AS"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $10;
        res = new IR(kCreateMatViewStmt_4, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $11;
        res = new IR(kCreateMatViewStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


create_mv_target:

    qualified_name opt_column_list table_access_method_clause opt_reloptions OptTableSpace {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kCreateMvTarget_1, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $3;
        res = new IR(kCreateMvTarget_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $4;
        res = new IR(kCreateMvTarget_3, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $5;
        res = new IR(kCreateMvTarget, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1 -> set_qualified_name_type(kDataViewName, kDefine);
        tmp2 -> set_opt_columnlist_type(kDataColumnName, kDefine);
    }

;


OptNoLog:

    UNLOGGED {
        res = new IR(kOptNoLog, OP3("UNLOGGED", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptNoLog, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
*		QUERY :
*				REFRESH MATERIALIZED VIEW qualified_name
*
*****************************************************************************/


RefreshMatViewStmt:

    REFRESH MATERIALIZED VIEW opt_concurrently qualified_name opt_with_data {
        auto tmp1 = $4;
        auto tmp2 = $5;
        res = new IR(kRefreshMatViewStmt_1, OP3("REFRESH MATERIALIZED VIEW", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kRefreshMatViewStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
*		QUERY :
*				CREATE SEQUENCE seqname
*				ALTER SEQUENCE seqname
*
*****************************************************************************/


CreateSeqStmt:

    CREATE OptTemp SEQUENCE qualified_name OptSeqOptList {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kCreateSeqStmt_1, OP3("CREATE", "SEQUENCE", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kCreateSeqStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp2->set_qualified_name_type(kDataSequenceName, kDefine);
    }

    | CREATE OptTemp SEQUENCE IF_P NOT EXISTS qualified_name OptSeqOptList {
        auto tmp1 = $2;
        auto tmp2 = $7;
        res = new IR(kCreateSeqStmt_2, OP3("CREATE", "SEQUENCE IF NOT EXISTS", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $8;
        res = new IR(kCreateSeqStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp2->set_qualified_name_type(kDataSequenceName, kDefine);

    }

;


AlterSeqStmt:

    ALTER SEQUENCE qualified_name SeqOptList {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kAlterSeqStmt, OP3("ALTER SEQUENCE", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER SEQUENCE IF_P EXISTS qualified_name SeqOptList {
        auto tmp1 = $5;
        auto tmp2 = $6;
        res = new IR(kAlterSeqStmt, OP3("ALTER SEQUENCE IF EXISTS", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


OptSeqOptList:

    SeqOptList {
        auto tmp1 = $1;
        res = new IR(kOptSeqOptList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptSeqOptList, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


OptParenthesizedSeqOptList:

    '(' SeqOptList ')' {
        auto tmp1 = $2;
        res = new IR(kOptParenthesizedSeqOptList, OP3("(", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptParenthesizedSeqOptList, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


SeqOptList:

    SeqOptElem {
        auto tmp1 = $1;
        res = new IR(kSeqOptList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SeqOptList SeqOptElem {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kSeqOptList, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


SeqOptElem:

    AS SimpleTypename {
        auto tmp1 = $2;
        res = new IR(kSeqOptElem, OP3("AS", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CACHE NumericOnly {
        auto tmp1 = $2;
        res = new IR(kSeqOptElem, OP3("CACHE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CYCLE {
        res = new IR(kSeqOptElem, OP3("CYCLE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NO CYCLE {
        res = new IR(kSeqOptElem, OP3("NO CYCLE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | INCREMENT opt_by NumericOnly {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kSeqOptElem, OP3("INCREMENT", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | MAXVALUE NumericOnly {
        auto tmp1 = $2;
        res = new IR(kSeqOptElem, OP3("MAXVALUE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | MINVALUE NumericOnly {
        auto tmp1 = $2;
        res = new IR(kSeqOptElem, OP3("MINVALUE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NO MAXVALUE {
        res = new IR(kSeqOptElem, OP3("NO MAXVALUE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NO MINVALUE {
        res = new IR(kSeqOptElem, OP3("NO MINVALUE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | OWNED BY any_name {
        auto tmp1 = $3;
        res = new IR(kSeqOptElem, OP3("OWNED BY", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SEQUENCE NAME_P any_name {
        auto tmp1 = $3;
        res = new IR(kSeqOptElem, OP3("SEQUENCE NAME", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | START opt_with NumericOnly {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kSeqOptElem, OP3("START", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | RESTART {
        res = new IR(kSeqOptElem, OP3("RESTART", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | RESTART opt_with NumericOnly {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kSeqOptElem, OP3("RESTART", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_by:

    BY {
        res = new IR(kOptBy, OP3("BY", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kOptBy, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


NumericOnly:

    FCONST {
        auto tmp1 = new IR(kFloatLiteral, string($1), kDataLiteral, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        res = new IR(kNumericOnly, OP0(), tmp1);
        all_gen_ir.push_back(res);
        free($1);
        $$ = res;
    }

    | '+' FCONST {
        auto tmp1 = new IR(kFloatLiteral, string($2), kDataLiteral, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        res = new IR(kNumericOnly, OP0(), tmp1);
        all_gen_ir.push_back(res);
        free($2);
        $$ = res;
    }

    | '-' FCONST {
        auto tmp1 = new IR(kFloatLiteral, string($2), kDataLiteral, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        res = new IR(kNumericOnly, OP0(), tmp1);
        all_gen_ir.push_back(res);
        free($2);
        $$ = res;
    }

    | SignedIconst {
        auto tmp1 = $1;
        res = new IR(kNumericOnly, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


NumericOnly_list:

    NumericOnly {
        auto tmp1 = $1;
        res = new IR(kNumericOnlyList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NumericOnly_list ',' NumericOnly {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kNumericOnlyList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
*		QUERIES :
*				CREATE [OR REPLACE] [TRUSTED] [PROCEDURAL] LANGUAGE ...
*				DROP [PROCEDURAL] LANGUAGE ...
*
*****************************************************************************/


CreatePLangStmt:

    CREATE opt_or_replace opt_trusted opt_procedural LANGUAGE name {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kCreatePLangStmt_1, OP3("CREATE", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $4;
        res = new IR(kCreatePLangStmt_2, OP3("", "", "LANGUAGE"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp4 );
        free($6);
        res = new IR(kCreatePLangStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CREATE opt_or_replace opt_trusted opt_procedural LANGUAGE name HANDLER handler_name opt_inline_handler opt_validator {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kCreatePLangStmt_3, OP3("CREATE", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $4;
        res = new IR(kCreatePLangStmt_4, OP3("", "", "LANGUAGE"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp4 );
        free($6);
        res = new IR(kCreatePLangStmt_5, OP3("", "", "HANDLER"), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $8;
        res = new IR(kCreatePLangStmt_6, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        auto tmp6 = $9;
        res = new IR(kCreatePLangStmt_7, OP3("", "", ""), res, tmp6);
        all_gen_ir.push_back(res);
        auto tmp7 = $10;
        res = new IR(kCreatePLangStmt, OP3("", "", ""), res, tmp7);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_trusted:

    TRUSTED {
        res = new IR(kOptTrusted, OP3("TRUSTED", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptTrusted, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/* This ought to be just func_name, but that causes reduce/reduce conflicts
* (CREATE LANGUAGE is the only place where func_name isn't followed by '(').
* Work around by using simple names, instead.
*/

handler_name:

    name {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kHandlerName, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | name attrs {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = $2;
        res = new IR(kHandlerName, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_inline_handler:

    INLINE_P handler_name {
        auto tmp1 = $2;
        res = new IR(kOptInlineHandler, OP3("INLINE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptInlineHandler, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


validator_clause:

    VALIDATOR handler_name {
        auto tmp1 = $2;
        res = new IR(kValidatorClause, OP3("VALIDATOR", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NO VALIDATOR {
        res = new IR(kValidatorClause, OP3("NO VALIDATOR", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_validator:

    validator_clause {
        auto tmp1 = $1;
        res = new IR(kOptValidator, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptValidator, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_procedural:

    PROCEDURAL {
        res = new IR(kOptProcedural, OP3("PROCEDURAL", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptProcedural, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
*		QUERY:
*             CREATE TABLESPACE tablespace LOCATION '/path/to/tablespace/'
*
*****************************************************************************/


CreateTableSpaceStmt:

    CREATE TABLESPACE name OptTableSpaceOwner LOCATION Sconst opt_reloptions {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $4;
        res = new IR(kCreateTableSpaceStmt_1, OP3("CREATE TABLESPACE", "", "LOCATION"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($6);
        res = new IR(kCreateTableSpaceStmt_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $7;
        res = new IR(kCreateTableSpaceStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


OptTableSpaceOwner:

    OWNER RoleSpec {
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        res = new IR(kOptTableSpaceOwner, OP3("OWNER", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY */ {
        res = new IR(kOptTableSpaceOwner, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
*		QUERY :
*				DROP TABLESPACE <tablespace>
*
*		No need for drop behaviour as we cannot implement dependencies for
*		objects in other databases; we can only support RESTRICT.
*
****************************************************************************/


DropTableSpaceStmt:

    DROP TABLESPACE name {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        res = new IR(kDropTableSpaceStmt, OP3("DROP TABLESPACE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DROP TABLESPACE IF_P EXISTS name {
        auto tmp1 = new IR(kIdentifier, string($5), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($5);
        res = new IR(kDropTableSpaceStmt, OP3("DROP TABLESPACE IF EXISTS", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
*		QUERY:
*             CREATE EXTENSION extension
*             [ WITH ] [ SCHEMA schema ] [ VERSION version ]
*
*****************************************************************************/


CreateExtensionStmt:

    CREATE EXTENSION name opt_with create_extension_opt_list {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $4;
        res = new IR(kCreateExtensionStmt_1, OP3("CREATE EXTENSION", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kCreateExtensionStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CREATE EXTENSION IF_P NOT EXISTS name opt_with create_extension_opt_list {
        auto tmp1 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($6);
        auto tmp2 = $7;
        res = new IR(kCreateExtensionStmt_2, OP3("CREATE EXTENSION IF NOT EXISTS", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $8;
        res = new IR(kCreateExtensionStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


create_extension_opt_list:

    create_extension_opt_list create_extension_opt_item {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kCreateExtensionOptList, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kCreateExtensionOptList, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


create_extension_opt_item:

    SCHEMA name {
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        res = new IR(kCreateExtensionOptItem, OP3("SCHEMA", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | VERSION_P NonReservedWord_or_Sconst {
        /* Yu: The version string of the extension. No need to mutate I guess. */
        /* FixLater: Can we just input $2 into the OP3?*/
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        res = new IR(kCreateExtensionOptItem, OP3("VERSION", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FROM NonReservedWord_or_Sconst {
        /* Yu: This symtax no longer supported. Change it to CASCADE. */
        free($2);
        res = new IR(kCreateExtensionOptItem, OP3("CASCADE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CASCADE {
        res = new IR(kCreateExtensionOptItem, OP3("CASCADE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
* ALTER EXTENSION name UPDATE [ TO version ]
*
*****************************************************************************/


AlterExtensionStmt:

    ALTER EXTENSION name UPDATE alter_extension_opt_list {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $5;
        res = new IR(kAlterExtensionStmt, OP3("ALTER EXTENSION", "UPDATE", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


alter_extension_opt_list:

    alter_extension_opt_list alter_extension_opt_item {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kAlterExtensionOptList, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kAlterExtensionOptList, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


alter_extension_opt_item:

    TO NonReservedWord_or_Sconst {
        /* Yu: This is again, just the verion name for the extension. No need to mutate.  */
        /* FixLater: Can we give $2 to OP3 directly? */
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        res = new IR(kAlterExtensionOptItem, OP3("TO", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
* ALTER EXTENSION name ADD/DROP object-identifier
*
*****************************************************************************/


AlterExtensionContentsStmt:

    ALTER EXTENSION name add_drop object_type_name name {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $4;
        res = new IR(kAlterExtensionContentsStmt_1, OP3("ALTER EXTENSION", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kAlterExtensionContentsStmt_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp4 );
        free($6);
        res = new IR(kAlterExtensionContentsStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER EXTENSION name add_drop object_type_any_name any_name {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $4;
        res = new IR(kAlterExtensionContentsStmt_3, OP3("ALTER EXTENSION", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kAlterExtensionContentsStmt_4, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $6;
        res = new IR(kAlterExtensionContentsStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER EXTENSION name add_drop AGGREGATE aggregate_with_argtypes {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $4;
        res = new IR(kAlterExtensionContentsStmt_5, OP3("ALTER EXTENSION", "", "AGGREGATE"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kAlterExtensionContentsStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER EXTENSION name add_drop CAST '(' Typename AS Typename ')' {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $4;
        res = new IR(kAlterExtensionContentsStmt_6, OP3("ALTER EXTENSION", "", "CAST ("), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $7;
        res = new IR(kAlterExtensionContentsStmt_7, OP3("", "", "AS"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $9;
        res = new IR(kAlterExtensionContentsStmt, OP3("", "", ")"), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER EXTENSION name add_drop DOMAIN_P Typename {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $4;
        res = new IR(kAlterExtensionContentsStmt_8, OP3("ALTER EXTENSION", "", "DOMAIN"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kAlterExtensionContentsStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER EXTENSION name add_drop FUNCTION function_with_argtypes {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $4;
        res = new IR(kAlterExtensionContentsStmt_9, OP3("ALTER EXTENSION", "", "FUNCTION"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kAlterExtensionContentsStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER EXTENSION name add_drop OPERATOR operator_with_argtypes {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $4;
        res = new IR(kAlterExtensionContentsStmt_10, OP3("ALTER EXTENSION", "", "OPERATOR"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kAlterExtensionContentsStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER EXTENSION name add_drop OPERATOR CLASS any_name USING name {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $4;
        res = new IR(kAlterExtensionContentsStmt_11, OP3("ALTER EXTENSION", "", "OPERATOR CLASS"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $7;
        res = new IR(kAlterExtensionContentsStmt_12, OP3("", "", "USING"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = new IR(kIdentifier, string($9), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp4 );
        free($9);
        res = new IR(kAlterExtensionContentsStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER EXTENSION name add_drop OPERATOR FAMILY any_name USING name {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $4;
        res = new IR(kAlterExtensionContentsStmt_13, OP3("ALTER EXTENSION", "", "OPERATOR FAMILY"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $7;
        res = new IR(kAlterExtensionContentsStmt_14, OP3("", "", "USING"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = new IR(kIdentifier, string($9), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp4 );
        free($9);
        res = new IR(kAlterExtensionContentsStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER EXTENSION name add_drop PROCEDURE function_with_argtypes {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $4;
        res = new IR(kAlterExtensionContentsStmt_15, OP3("ALTER EXTENSION", "", "PROCEDURE"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kAlterExtensionContentsStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER EXTENSION name add_drop ROUTINE function_with_argtypes {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $4;
        res = new IR(kAlterExtensionContentsStmt_16, OP3("ALTER EXTENSION", "", "ROUTINE"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kAlterExtensionContentsStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER EXTENSION name add_drop TRANSFORM FOR Typename LANGUAGE name {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $4;
        res = new IR(kAlterExtensionContentsStmt_17, OP3("ALTER EXTENSION", "", "TRANSFORM FOR"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $7;
        res = new IR(kAlterExtensionContentsStmt_18, OP3("", "", "LANGUAGE"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = new IR(kIdentifier, string($9), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp4 );
        free($9);
        res = new IR(kAlterExtensionContentsStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER EXTENSION name add_drop TYPE_P Typename {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $4;
        res = new IR(kAlterExtensionContentsStmt_19, OP3("ALTER EXTENSION", "", "TYPE"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kAlterExtensionContentsStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
*		QUERY:
*             CREATE FOREIGN DATA WRAPPER name options
*
*****************************************************************************/


CreateFdwStmt:

    CREATE FOREIGN DATA_P WRAPPER name opt_fdw_options create_generic_options {
        auto tmp1 = new IR(kIdentifier, string($5), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($5);
        auto tmp2 = $6;
        res = new IR(kCreateFdwStmt_1, OP3("CREATE FOREIGN DATA WRAPPER", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $7;
        res = new IR(kCreateFdwStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


fdw_option:

    HANDLER handler_name {
        auto tmp1 = $2;
        res = new IR(kFdwOption, OP3("HANDLER", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NO HANDLER {
        res = new IR(kFdwOption, OP3("NO HANDLER", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | VALIDATOR handler_name {
        auto tmp1 = $2;
        res = new IR(kFdwOption, OP3("VALIDATOR", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NO VALIDATOR {
        res = new IR(kFdwOption, OP3("NO VALIDATOR", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


fdw_options:

    fdw_option {
        auto tmp1 = $1;
        res = new IR(kFdwOptions, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | fdw_options fdw_option {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kFdwOptions, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_fdw_options:

    fdw_options {
        auto tmp1 = $1;
        res = new IR(kOptFdwOptions, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptFdwOptions, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
*		QUERY :
*				ALTER FOREIGN DATA WRAPPER name options
*
****************************************************************************/


AlterFdwStmt:

    ALTER FOREIGN DATA_P WRAPPER name opt_fdw_options alter_generic_options {
        auto tmp1 = new IR(kIdentifier, string($5), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($5);
        auto tmp2 = $6;
        res = new IR(kAlterFdwStmt_1, OP3("ALTER FOREIGN DATA WRAPPER", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $7;
        res = new IR(kAlterFdwStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER FOREIGN DATA_P WRAPPER name fdw_options {
        auto tmp1 = new IR(kIdentifier, string($5), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($5);
        auto tmp2 = $6;
        res = new IR(kAlterFdwStmt, OP3("ALTER FOREIGN DATA WRAPPER", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/* Options definition for CREATE FDW, SERVER and USER MAPPING */

create_generic_options:

    OPTIONS '(' generic_option_list ')' {
        auto tmp1 = $3;
        res = new IR(kCreateGenericOptions, OP3("OPTIONS (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kCreateGenericOptions, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


generic_option_list:

    generic_option_elem {
        auto tmp1 = $1;
        res = new IR(kGenericOptionList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | generic_option_list ',' generic_option_elem {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kGenericOptionList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/* Options definition for ALTER FDW, SERVER and USER MAPPING */

alter_generic_options:

    OPTIONS '(' alter_generic_option_list ')' {
        auto tmp1 = $3;
        res = new IR(kAlterGenericOptions, OP3("OPTIONS (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


alter_generic_option_list:

    alter_generic_option_elem {
        auto tmp1 = $1;
        res = new IR(kAlterGenericOptionList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | alter_generic_option_list ',' alter_generic_option_elem {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kAlterGenericOptionList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


alter_generic_option_elem:

    generic_option_elem {
        auto tmp1 = $1;
        res = new IR(kAlterGenericOptionElem, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SET generic_option_elem {
        auto tmp1 = $2;
        res = new IR(kAlterGenericOptionElem, OP3("SET", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ADD_P generic_option_elem {
        auto tmp1 = $2;
        res = new IR(kAlterGenericOptionElem, OP3("ADD", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DROP generic_option_name {
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        res = new IR(kAlterGenericOptionElem, OP3("DROP", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


generic_option_elem:

    generic_option_name generic_option_arg {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = $2;
        res = new IR(kGenericOptionElem, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


generic_option_name:
    ColLabel
;

/* We could use def_arg here, but the spec only requires string literals */

generic_option_arg:

    Sconst {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kGenericOptionArg, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
*		QUERY:
*             CREATE SERVER name [TYPE] [VERSION] [OPTIONS]
*
*****************************************************************************/


CreateForeignServerStmt:

    CREATE SERVER name opt_type opt_foreign_server_version FOREIGN DATA_P WRAPPER name create_generic_options {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $4;
        res = new IR(kCreateForeignServerStmt_1, OP3("CREATE SERVER", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kCreateForeignServerStmt_2, OP3("", "", "FOREIGN DATA WRAPPER"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = new IR(kIdentifier, string($9), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp4 );
        free($9);
        res = new IR(kCreateForeignServerStmt_3, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $10;
        res = new IR(kCreateForeignServerStmt, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CREATE SERVER IF_P NOT EXISTS name opt_type opt_foreign_server_version FOREIGN DATA_P WRAPPER name create_generic_options {
        auto tmp1 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($6);
        auto tmp2 = $7;
        res = new IR(kCreateForeignServerStmt_4, OP3("CREATE SERVER IF NOT EXISTS", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $8;
        res = new IR(kCreateForeignServerStmt_5, OP3("", "", "FOREIGN DATA WRAPPER"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = new IR(kIdentifier, string($12), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp4 );
        free($12);
        res = new IR(kCreateForeignServerStmt_6, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $13;
        res = new IR(kCreateForeignServerStmt, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_type:

    TYPE_P Sconst {
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        res = new IR(kOptType, OP3("TYPE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptType, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;



foreign_server_version:

    VERSION_P Sconst {
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        res = new IR(kForeignServerVersion, OP3("VERSION", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | VERSION_P NULL_P {
        res = new IR(kForeignServerVersion, OP3("VERSION NULL", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_foreign_server_version:

    foreign_server_version {
        auto tmp1 = $1;
        res = new IR(kOptForeignServerVersion, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptForeignServerVersion, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
*		QUERY :
*				ALTER SERVER name [VERSION] [OPTIONS]
*
****************************************************************************/


AlterForeignServerStmt:

    ALTER SERVER name foreign_server_version alter_generic_options {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $4;
        res = new IR(kAlterForeignServerStmt_1, OP3("ALTER SERVER", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kAlterForeignServerStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER SERVER name foreign_server_version {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $4;
        res = new IR(kAlterForeignServerStmt, OP3("ALTER SERVER", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER SERVER name alter_generic_options {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $4;
        res = new IR(kAlterForeignServerStmt, OP3("ALTER SERVER", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
*		QUERY:
*             CREATE FOREIGN TABLE relname (...) SERVER name (...)
*
*****************************************************************************/


CreateForeignTableStmt:

    CREATE FOREIGN TABLE qualified_name '(' OptTableElementList ')' OptInherit SERVER name create_generic_options {
        auto tmp1 = $4;
        auto tmp2 = $6;
        res = new IR(kCreateForeignTableStmt_1, OP3("CREATE FOREIGN TABLE", "(", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $8;
        res = new IR(kCreateForeignTableStmt_2, OP3("", "", "SERVER"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = new IR(kIdentifier, string($10), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp4 );
        free($10);
        res = new IR(kCreateForeignTableStmt_3, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $11;
        res = new IR(kCreateForeignTableStmt, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_qualified_name_type(kDataForeignTableName, kDefine);

    }

    | CREATE FOREIGN TABLE IF_P NOT EXISTS qualified_name '(' OptTableElementList ')' OptInherit SERVER name create_generic_options {
        auto tmp1 = $7;
        auto tmp2 = $9;
        res = new IR(kCreateForeignTableStmt_4, OP3("CREATE FOREIGN TABLE IF NOT EXISTS", "(", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $11;
        res = new IR(kCreateForeignTableStmt_5, OP3("", "", "SERVER"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = new IR(kIdentifier, string($13), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp4 );
        free($13);
        res = new IR(kCreateForeignTableStmt_6, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $14;
        res = new IR(kCreateForeignTableStmt, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_qualified_name_type(kDataForeignTableName, kDefine);

    }

    | CREATE FOREIGN TABLE qualified_name PARTITION OF qualified_name OptTypedTableElementList PartitionBoundSpec SERVER name create_generic_options {
        auto tmp1 = $4;
        auto tmp2 = $7;
        res = new IR(kCreateForeignTableStmt_7, OP3("CREATE FOREIGN TABLE", "PARTITION OF", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $8;
        res = new IR(kCreateForeignTableStmt_8, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $9;
        res = new IR(kCreateForeignTableStmt_9, OP3("", "", "SERVER"), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = new IR(kIdentifier, string($11), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp5 );
        free($11);
        res = new IR(kCreateForeignTableStmt_10, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        auto tmp6 = $12;
        res = new IR(kCreateForeignTableStmt, OP3("", "", ""), res, tmp6);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_qualified_name_type(kDataForeignTableName, kDefine);
        tmp2->set_qualified_name_type(kDataTableName, kUse);
    }

    | CREATE FOREIGN TABLE IF_P NOT EXISTS qualified_name PARTITION OF qualified_name OptTypedTableElementList PartitionBoundSpec SERVER name create_generic_options {
        auto tmp1 = $7;
        auto tmp2 = $10;
        res = new IR(kCreateForeignTableStmt_11, OP3("CREATE FOREIGN TABLE IF NOT EXISTS", "PARTITION OF", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $11;
        res = new IR(kCreateForeignTableStmt_12, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $12;
        res = new IR(kCreateForeignTableStmt_13, OP3("", "", "SERVER"), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = new IR(kIdentifier, string($14), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp5 );
        free($14);
        res = new IR(kCreateForeignTableStmt_14, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        auto tmp6 = $15;
        res = new IR(kCreateForeignTableStmt, OP3("", "", ""), res, tmp6);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_qualified_name_type(kDataForeignTableName, kDefine);
        tmp2->set_qualified_name_type(kDataTableName, kUse);
    }

;

/*****************************************************************************
*
*		QUERY:
*				IMPORT FOREIGN SCHEMA remote_schema
*				[ { LIMIT TO | EXCEPT } ( table_list ) ]
*				FROM SERVER server_name INTO local_schema [ OPTIONS (...) ]
*
****************************************************************************/


ImportForeignSchemaStmt:

    IMPORT_P FOREIGN SCHEMA name import_qualification FROM SERVER name INTO name create_generic_options {
        auto tmp1 = new IR(kIdentifier, string($4), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($4);
        auto tmp2 = $5;
        res = new IR(kImportForeignSchemaStmt_1, OP3("IMPORT FOREIGN SCHEMA", "", "FROM SERVER"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($8);
        res = new IR(kImportForeignSchemaStmt_2, OP3("", "", "INTO"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = new IR(kIdentifier, string($10), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp4 );
        free($10);
        res = new IR(kImportForeignSchemaStmt_3, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $11;
        res = new IR(kImportForeignSchemaStmt, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


import_qualification_type:

    LIMIT TO {
        res = new IR(kImportQualificationType, OP3("LIMIT TO", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | EXCEPT {
        res = new IR(kImportQualificationType, OP3("EXCEPT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


import_qualification:

    import_qualification_type '(' relation_expr_list ')' {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kImportQualification, OP3("", "(", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kImportQualification, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
*		QUERY:
*             CREATE USER MAPPING FOR auth_ident SERVER name [OPTIONS]
*
*****************************************************************************/


CreateUserMappingStmt:

    CREATE USER MAPPING FOR auth_ident SERVER name create_generic_options {
        auto tmp1 = $5;
        auto tmp2 = new IR(kIdentifier, string($7), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($7);
        res = new IR(kCreateUserMappingStmt_1, OP3("CREATE USER MAPPING FOR", "SERVER", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $8;
        res = new IR(kCreateUserMappingStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CREATE USER MAPPING IF_P NOT EXISTS FOR auth_ident SERVER name create_generic_options {
        auto tmp1 = $8;
        auto tmp2 = new IR(kIdentifier, string($10), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($10);
        res = new IR(kCreateUserMappingStmt_2, OP3("CREATE USER MAPPING IF NOT EXISTS FOR", "SERVER", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $11;
        res = new IR(kCreateUserMappingStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/* User mapping authorization identifier */

auth_ident:

    RoleSpec {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kAuthIdent, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | USER {
        res = new IR(kAuthIdent, OP3("USER", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
*		QUERY :
*				DROP USER MAPPING FOR auth_ident SERVER name
*
* XXX you'd think this should have a CASCADE/RESTRICT option, even if it's
* only pro forma; but the SQL standard doesn't show one.
****************************************************************************/


DropUserMappingStmt:

    DROP USER MAPPING FOR auth_ident SERVER name {
        auto tmp1 = $5;
        auto tmp2 = new IR(kIdentifier, string($7), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($7);
        res = new IR(kDropUserMappingStmt, OP3("DROP USER MAPPING FOR", "SERVER", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DROP USER MAPPING IF_P EXISTS FOR auth_ident SERVER name {
        auto tmp1 = $7;
        auto tmp2 = new IR(kIdentifier, string($9), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($9);
        res = new IR(kDropUserMappingStmt, OP3("DROP USER MAPPING IF EXISTS FOR", "SERVER", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
*		QUERY :
*				ALTER USER MAPPING FOR auth_ident SERVER name OPTIONS
*
****************************************************************************/


AlterUserMappingStmt:

    ALTER USER MAPPING FOR auth_ident SERVER name alter_generic_options {
        auto tmp1 = $5;
        auto tmp2 = new IR(kIdentifier, string($7), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($7);
        res = new IR(kAlterUserMappingStmt_1, OP3("ALTER USER MAPPING FOR", "SERVER", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $8;
        res = new IR(kAlterUserMappingStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
*		QUERIES:
*				CREATE POLICY name ON table
*					[AS { PERMISSIVE | RESTRICTIVE } ]
*					[FOR { SELECT | INSERT | UPDATE | DELETE } ]
*					[TO role, ...]
*					[USING (qual)] [WITH CHECK (with check qual)]
*				ALTER POLICY name ON table [TO role, ...]
*					[USING (qual)] [WITH CHECK (with check qual)]
*
*****************************************************************************/


CreatePolicyStmt:

    CREATE POLICY name ON qualified_name RowSecurityDefaultPermissive RowSecurityDefaultForCmd RowSecurityDefaultToRole RowSecurityOptionalExpr RowSecurityOptionalWithCheck {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $5;
        res = new IR(kCreatePolicyStmt_1, OP3("CREATE POLICY", "ON", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kCreatePolicyStmt_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $7;
        res = new IR(kCreatePolicyStmt_3, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $8;
        res = new IR(kCreatePolicyStmt_4, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        auto tmp6 = $9;
        res = new IR(kCreatePolicyStmt_5, OP3("", "", ""), res, tmp6);
        all_gen_ir.push_back(res);
        auto tmp7 = $10;
        res = new IR(kCreatePolicyStmt, OP3("", "", ""), res, tmp7);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


AlterPolicyStmt:

    ALTER POLICY name ON qualified_name RowSecurityOptionalToRole RowSecurityOptionalExpr RowSecurityOptionalWithCheck {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $5;
        res = new IR(kAlterPolicyStmt_1, OP3("ALTER POLICY", "ON", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kAlterPolicyStmt_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $7;
        res = new IR(kAlterPolicyStmt_3, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $8;
        res = new IR(kAlterPolicyStmt, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


RowSecurityOptionalExpr:

    USING '(' a_expr ')' {
        auto tmp1 = $3;
        res = new IR(kRowSecurityOptionalExpr, OP3("USING (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kRowSecurityOptionalExpr, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


RowSecurityOptionalWithCheck:

    WITH CHECK '(' a_expr ')' {
        auto tmp1 = $4;
        res = new IR(kRowSecurityOptionalWithCheck, OP3("WITH CHECK (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kRowSecurityOptionalWithCheck, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


RowSecurityDefaultToRole:

    TO role_list {
        auto tmp1 = $2;
        res = new IR(kRowSecurityDefaultToRole, OP3("TO", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kRowSecurityDefaultToRole, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


RowSecurityOptionalToRole:

    TO role_list {
        auto tmp1 = $2;
        res = new IR(kRowSecurityOptionalToRole, OP3("TO", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kRowSecurityOptionalToRole, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


RowSecurityDefaultPermissive:

    AS IDENT {
        if (strcmp($2, "permissive") == 0) {
            res = new IR(kRowSecurityDefaultPermissive, OP3("AS permissive", "", ""));
            all_gen_ir.push_back(res);
        }
        else if (strcmp($2, "restrictive") == 0) {
            res = new IR(kRowSecurityDefaultPermissive, OP3("AS restrictive", "", ""));
            all_gen_ir.push_back(res);
        }
        else if (strcmp($2, "") == 0) {
            res = new IR(kRowSecurityDefaultPermissive, OP0());
            all_gen_ir.push_back(res);
        }
        else {
            /* Force using empty, if the option is not supported.  */
            res = new IR(kRowSecurityDefaultPermissive, OP0());
            all_gen_ir.push_back(res);
        }
        free($2);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kRowSecurityDefaultPermissive, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


RowSecurityDefaultForCmd:

    FOR row_security_cmd {
        auto tmp1 = $2;
        res = new IR(kRowSecurityDefaultForCmd, OP3("FOR", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kRowSecurityDefaultForCmd, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


row_security_cmd:

    ALL {
        res = new IR(kRowSecurityCmd, OP3("ALL", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SELECT {
        res = new IR(kRowSecurityCmd, OP3("SELECT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | INSERT {
        res = new IR(kRowSecurityCmd, OP3("INSERT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | UPDATE {
        res = new IR(kRowSecurityCmd, OP3("UPDATE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DELETE_P {
        res = new IR(kRowSecurityCmd, OP3("DELETE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
*		QUERY:
*             CREATE ACCESS METHOD name HANDLER handler_name
*
*****************************************************************************/


CreateAmStmt:

    CREATE ACCESS METHOD name TYPE_P am_type HANDLER handler_name {
        auto tmp1 = new IR(kIdentifier, string($4), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($4);
        auto tmp2 = $6;
        res = new IR(kCreateAmStmt_1, OP3("CREATE ACCESS METHOD", "TYPE", "HANDLER"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $8;
        res = new IR(kCreateAmStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


am_type:

    INDEX {
        res = new IR(kAmType, OP3("INDEX", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TABLE {
        res = new IR(kAmType, OP3("TABLE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
*		QUERIES :
*				CREATE TRIGGER ...
*
*****************************************************************************/


CreateTrigStmt:

    CREATE opt_or_replace TRIGGER name TriggerActionTime TriggerEvents ON qualified_name TriggerReferencing TriggerForSpec TriggerWhen EXECUTE FUNCTION_or_PROCEDURE func_name '(' TriggerFuncArgs ')' {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($4), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($4);
        res = new IR(kCreateTrigStmt_1, OP3("CREATE", "TRIGGER", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kCreateTrigStmt_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $6;
        res = new IR(kCreateTrigStmt_3, OP3("", "", "ON"), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $8;
        res = new IR(kCreateTrigStmt_4, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        auto tmp6 = $9;
        res = new IR(kCreateTrigStmt_5, OP3("", "", ""), res, tmp6);
        all_gen_ir.push_back(res);
        auto tmp7 = $10;
        res = new IR(kCreateTrigStmt_6, OP3("", "", ""), res, tmp7);
        all_gen_ir.push_back(res);
        auto tmp8 = $11;
        res = new IR(kCreateTrigStmt_7, OP3("", "", "EXECUTE"), res, tmp8);
        all_gen_ir.push_back(res);
        auto tmp9 = $13;
        res = new IR(kCreateTrigStmt_8, OP3("", "", ""), res, tmp9);
        all_gen_ir.push_back(res);
        auto tmp10 = $14;
        res = new IR(kCreateTrigStmt_9, OP3("", "", "("), res, tmp10);
        all_gen_ir.push_back(res);
        auto tmp11 = $16;
        res = new IR(kCreateTrigStmt, OP3("", "", ")"), res, tmp11);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CREATE opt_or_replace CONSTRAINT TRIGGER name AFTER TriggerEvents ON qualified_name OptConstrFromTable ConstraintAttributeSpec FOR EACH ROW TriggerWhen EXECUTE FUNCTION_or_PROCEDURE func_name '(' TriggerFuncArgs ')' {
        /* Yu: Do not allow "OR REPLACE" in this sentence. */
        auto tmp1 = $2;
        if (!tmp1->is_empty()){
            /* tmp1 ->deep_drop(); */
            rov_ir.push_back(tmp1);
            tmp1 = new IR(kOptOrReplace, OP3("", "", ""));
            all_gen_ir.push_back(tmp1);
        }
        auto tmp2 = new IR(kIdentifier, string($5), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($5);
        res = new IR(kCreateTrigStmt_10, OP3("CREATE", "CONSTRAINT TRIGGER", "AFTER"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $7;
        res = new IR(kCreateTrigStmt_11, OP3("", "", "ON"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $9;
        res = new IR(kCreateTrigStmt_12, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $10;
        res = new IR(kCreateTrigStmt_13, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        auto tmp6 = $11;
        res = new IR(kCreateTrigStmt_14, OP3("", "", "FOR EACH ROW"), res, tmp6);
        all_gen_ir.push_back(res);
        auto tmp7 = $15;
        res = new IR(kCreateTrigStmt_15, OP3("", "", "EXECUTE"), res, tmp7);
        all_gen_ir.push_back(res);
        auto tmp8 = $17;
        res = new IR(kCreateTrigStmt_16, OP3("", "", ""), res, tmp8);
        all_gen_ir.push_back(res);
        auto tmp9 = $18;
        res = new IR(kCreateTrigStmt_17, OP3("", "", "("), res, tmp9);
        all_gen_ir.push_back(res);
        auto tmp10 = $20;
        res = new IR(kCreateTrigStmt, OP3("", "", ")"), res, tmp10);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


TriggerActionTime:

    BEFORE {
        res = new IR(kTriggerActionTime, OP3("BEFORE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | AFTER {
        res = new IR(kTriggerActionTime, OP3("AFTER", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | INSTEAD OF {
        res = new IR(kTriggerActionTime, OP3("INSTEAD OF", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


TriggerEvents:

    TriggerOneEvent {
        auto tmp1 = $1;
        res = new IR(kTriggerEvents, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TriggerEvents OR TriggerOneEvent {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kTriggerEvents, OP3("", "OR", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


TriggerOneEvent:

    INSERT {
        res = new IR(kTriggerOneEvent, OP3("INSERT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DELETE_P {
        res = new IR(kTriggerOneEvent, OP3("DELETE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | UPDATE {
        res = new IR(kTriggerOneEvent, OP3("UPDATE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | UPDATE OF columnList {
        auto tmp1 = $3;
        res = new IR(kTriggerOneEvent, OP3("UPDATE OF", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TRUNCATE {
        res = new IR(kTriggerOneEvent, OP3("TRUNCATE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


TriggerReferencing:

    REFERENCING TriggerTransitions {
        auto tmp1 = $2;
        res = new IR(kTriggerReferencing, OP3("REFERENCING", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kTriggerReferencing, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


TriggerTransitions:

    TriggerTransition {
        auto tmp1 = $1;
        res = new IR(kTriggerTransitions, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TriggerTransitions TriggerTransition {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kTriggerTransitions, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


TriggerTransition:

    TransitionOldOrNew TransitionRowOrTable opt_as TransitionRelName {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kTriggerTransition_1, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $3;
        res = new IR(kTriggerTransition_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $4;
        res = new IR(kTriggerTransition, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


TransitionOldOrNew:

    NEW {
        res = new IR(kTransitionOldOrNew, OP3("NEW", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | OLD {
        res = new IR(kTransitionOldOrNew, OP3("OLD", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


TransitionRowOrTable:

    TABLE {
        res = new IR(kTransitionRowOrTable, OP3("TABLE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ROW {
        res = new IR(kTransitionRowOrTable, OP3("ROW", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


TransitionRelName:

    ColId {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kTransitionRelName, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


TriggerForSpec:

    FOR TriggerForOptEach TriggerForType {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kTriggerForSpec, OP3("FOR", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kTriggerForSpec, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


TriggerForOptEach:

    EACH {
        res = new IR(kTriggerForOptEach, OP3("EACH", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kTriggerForOptEach, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


TriggerForType:

    ROW {
        res = new IR(kTriggerForType, OP3("ROW", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | STATEMENT {
        res = new IR(kTriggerForType, OP3("STATEMENT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


TriggerWhen:

    WHEN '(' a_expr ')' {
        auto tmp1 = $3;
        res = new IR(kTriggerWhen, OP3("WHEN (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kTriggerWhen, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


FUNCTION_or_PROCEDURE:

    FUNCTION {
        res = new IR(kFUNCTIONOrPROCEDURE, OP3("FUNCTION", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | PROCEDURE {
        res = new IR(kFUNCTIONOrPROCEDURE, OP3("PROCEDURE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


TriggerFuncArgs:

    TriggerFuncArg {
        auto tmp1 = $1;
        res = new IR(kTriggerFuncArgs, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TriggerFuncArgs ',' TriggerFuncArg {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kTriggerFuncArgs, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kTriggerFuncArgs, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


TriggerFuncArg:

    Iconst {
        auto tmp1 = $1;
        res = new IR(kTriggerFuncArg, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FCONST {
        auto tmp1 = new IR(kFloatLiteral, string($1), kDataLiteral, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        res = new IR(kTriggerFuncArg, OP0(), tmp1);
        all_gen_ir.push_back(res);
        free($1);
        $$ = res;
    }

    | Sconst {
        auto tmp1 = new IR(kIdentifier, string($1), kDataLiteral, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kTriggerFuncArg, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ColLabel {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kTriggerFuncArg, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


OptConstrFromTable:

    FROM qualified_name {
        auto tmp1 = $2;
        res = new IR(kOptConstrFromTable, OP3("FROM", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptConstrFromTable, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


ConstraintAttributeSpec:

    /*EMPTY*/ {
        res = new IR(kConstraintAttributeSpec, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ConstraintAttributeSpec ConstraintAttributeElem {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kConstraintAttributeSpec, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


ConstraintAttributeElem:

    NOT DEFERRABLE {
        res = new IR(kConstraintAttributeElem, OP3("NOT DEFERRABLE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DEFERRABLE {
        res = new IR(kConstraintAttributeElem, OP3("DEFERRABLE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | INITIALLY IMMEDIATE {
        res = new IR(kConstraintAttributeElem, OP3("INITIALLY IMMEDIATE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | INITIALLY DEFERRED {
        res = new IR(kConstraintAttributeElem, OP3("INITIALLY DEFERRED", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NOT VALID {
        res = new IR(kConstraintAttributeElem, OP3("NOT VALID", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NO INHERIT {
        res = new IR(kConstraintAttributeElem, OP3("NO INHERIT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
*		QUERIES :
*				CREATE EVENT TRIGGER ...
*				ALTER EVENT TRIGGER ...
*
*****************************************************************************/


CreateEventTrigStmt:

    CREATE EVENT TRIGGER name ON ColLabel EXECUTE FUNCTION_or_PROCEDURE func_name '(' ')' {
        auto tmp1 = new IR(kIdentifier, string($4), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($4);
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kCreateEventTrigStmt_1, OP3("CREATE EVENT TRIGGER", "ON", "EXECUTE"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $8;
        res = new IR(kCreateEventTrigStmt_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $9;
        res = new IR(kCreateEventTrigStmt, OP3("", "", "( )"), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CREATE EVENT TRIGGER name ON ColLabel WHEN event_trigger_when_list EXECUTE FUNCTION_or_PROCEDURE func_name '(' ')' {
        auto tmp1 = new IR(kIdentifier, string($4), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($4);
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kCreateEventTrigStmt_3, OP3("CREATE EVENT TRIGGER", "ON", "WHEN"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $8;
        res = new IR(kCreateEventTrigStmt_4, OP3("", "", "EXECUTE"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $10;
        res = new IR(kCreateEventTrigStmt_5, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $11;
        res = new IR(kCreateEventTrigStmt, OP3("", "", "( )"), res, tmp5);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


event_trigger_when_list:

    event_trigger_when_item {
        auto tmp1 = $1;
        res = new IR(kEventTriggerWhenList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | event_trigger_when_list AND event_trigger_when_item {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kEventTriggerWhenList, OP3("", "AND", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


event_trigger_when_item:

    ColId IN_P '(' event_trigger_value_list ')' {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = $4;
        res = new IR(kEventTriggerWhenItem, OP3("", "IN (", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


event_trigger_value_list:

    SCONST {
        auto tmp1 = new IR(kStringLiteral, string($1));
        all_gen_ir.push_back( tmp1 );
        res = new IR(kEventTriggerValueList, OP0(), tmp1);
        all_gen_ir.push_back(res);
        free($1);
        $$ = res;
    }

    | event_trigger_value_list ',' SCONST {
        auto tmp1 = $1;
        auto tmp2 = new IR(kStringLiteral, string($3));
        all_gen_ir.push_back( tmp2 );
        res = new IR(kEventTriggerValueList, OP0(), tmp1, tmp2);
        all_gen_ir.push_back(res);
        free($3);
        $$ = res;
    }

;


AlterEventTrigStmt:

    ALTER EVENT TRIGGER name enable_trigger {
        auto tmp1 = new IR(kIdentifier, string($4), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($4);
        auto tmp2 = $5;
        res = new IR(kAlterEventTrigStmt, OP3("ALTER EVENT TRIGGER", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_iden_type(kDataTriggerName, kUse);
    }

;


enable_trigger:

    ENABLE_P {
        res = new IR(kEnableTrigger, OP3("ENABLE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ENABLE_P REPLICA {
        res = new IR(kEnableTrigger, OP3("ENABLE REPLICA", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ENABLE_P ALWAYS {
        res = new IR(kEnableTrigger, OP3("ENABLE ALWAYS", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DISABLE_P {
        res = new IR(kEnableTrigger, OP3("DISABLE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
*		QUERY :
*				CREATE ASSERTION ...
*
*****************************************************************************/


CreateAssertionStmt:

    CREATE ASSERTION any_name CHECK '(' a_expr ')' ConstraintAttributeSpec {
        auto tmp1 = $3;
        auto tmp2 = $6;
        res = new IR(kCreateAssertionStmt_1, OP3("CREATE ASSERTION", "CHECK (", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $8;
        res = new IR(kCreateAssertionStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
*		QUERY :
*				define (aggregate,operator,type)
*
*****************************************************************************/


DefineStmt:

    CREATE opt_or_replace AGGREGATE func_name aggr_args definition {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kDefineStmt_1, OP3("CREATE", "AGGREGATE", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kDefineStmt_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $6;
        res = new IR(kDefineStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CREATE opt_or_replace AGGREGATE func_name old_aggr_definition {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kDefineStmt_3, OP3("CREATE", "AGGREGATE", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kDefineStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CREATE OPERATOR any_operator definition {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kDefineStmt, OP3("CREATE OPERATOR", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CREATE TYPE_P any_name definition {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kDefineStmt, OP3("CREATE TYPE", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CREATE TYPE_P any_name {
        auto tmp1 = $3;
        res = new IR(kDefineStmt, OP3("CREATE TYPE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CREATE TYPE_P any_name AS '(' OptTableFuncElementList ')' {
        auto tmp1 = $3;
        auto tmp2 = $6;
        res = new IR(kDefineStmt, OP3("CREATE TYPE", "AS (", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CREATE TYPE_P any_name AS ENUM_P '(' opt_enum_val_list ')' {
        auto tmp1 = $3;
        auto tmp2 = $7;
        res = new IR(kDefineStmt, OP3("CREATE TYPE", "AS ENUM (", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CREATE TYPE_P any_name AS RANGE definition {
        auto tmp1 = $3;
        auto tmp2 = $6;
        res = new IR(kDefineStmt, OP3("CREATE TYPE", "AS RANGE", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CREATE TEXT_P SEARCH PARSER any_name definition {
        auto tmp1 = $5;
        auto tmp2 = $6;
        res = new IR(kDefineStmt, OP3("CREATE TEXT SEARCH PARSER", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CREATE TEXT_P SEARCH DICTIONARY any_name definition {
        auto tmp1 = $5;
        auto tmp2 = $6;
        res = new IR(kDefineStmt, OP3("CREATE TEXT SEARCH DICTIONARY", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CREATE TEXT_P SEARCH TEMPLATE any_name definition {
        auto tmp1 = $5;
        auto tmp2 = $6;
        res = new IR(kDefineStmt, OP3("CREATE TEXT SEARCH TEMPLATE", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CREATE TEXT_P SEARCH CONFIGURATION any_name definition {
        auto tmp1 = $5;
        auto tmp2 = $6;
        res = new IR(kDefineStmt, OP3("CREATE TEXT SEARCH CONFIGURATION", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CREATE COLLATION any_name definition {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kDefineStmt, OP3("CREATE COLLATION", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CREATE COLLATION IF_P NOT EXISTS any_name definition {
        auto tmp1 = $6;
        auto tmp2 = $7;
        res = new IR(kDefineStmt, OP3("CREATE COLLATION IF NOT EXISTS", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CREATE COLLATION any_name FROM any_name {
        auto tmp1 = $3;
        auto tmp2 = $5;
        res = new IR(kDefineStmt, OP3("CREATE COLLATION", "FROM", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CREATE COLLATION IF_P NOT EXISTS any_name FROM any_name {
        auto tmp1 = $6;
        auto tmp2 = $8;
        res = new IR(kDefineStmt, OP3("CREATE COLLATION IF NOT EXISTS", "FROM", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


definition:

    '(' def_list ')' {
        auto tmp1 = $2;
        res = new IR(kDefinition, OP3("(", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


def_list:

    def_elem {
        auto tmp1 = $1;
        res = new IR(kDefList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | def_list ',' def_elem {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kDefList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


def_elem:

    ColLabel '=' def_arg {
        /* Yu: Treat this as reloption type. Will fix later in the validate functions */
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = $3;
        res = new IR(kDefElem, OP3("", "=", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        res -> set_type(kDataRelOption, kUse);
        res -> set_rel_option_type(RelOptionType::StorageParameters);

    }

    | ColLabel {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kDefElem, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1 -> set_iden_type(kDataRelOption, kUse);
        tmp1 -> set_rel_option_type(RelOptionType::StorageParameters);
    }

;

/* Note: any simple identifier will be returned as a type name! */

def_arg:

    func_type {
        auto tmp1 = $1;
        res = new IR(kDefArg, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | reserved_keyword {
        /* This is a specitial use, we are using a read-only char to initialize the string! */
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        res = new IR(kDefArg, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | qual_all_Op {
        auto tmp1 = $1;
        res = new IR(kDefArg, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NumericOnly {
        auto tmp1 = $1;
        res = new IR(kDefArg, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | Sconst {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kDefArg, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NONE {
        res = new IR(kDefArg, OP3("NONE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


old_aggr_definition:

    '(' old_aggr_list ')' {
        auto tmp1 = $2;
        res = new IR(kOldAggrDefinition, OP3("(", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


old_aggr_list:

    old_aggr_elem {
        auto tmp1 = $1;
        res = new IR(kOldAggrList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | old_aggr_list ',' old_aggr_elem {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kOldAggrList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* Must use IDENT here to avoid reduce/reduce conflicts; fortunately none of
* the item names needed in old aggregate definitions are likely to become
* SQL keywords.
*/

old_aggr_elem:

    IDENT '=' def_arg {
        /* Yu: Fixing it as an identifier = config. We might need to fix them later in the validate function */
        IR* tmp1;
        if (    strcmp($1, "SFUNC") == 0 || // Required
                strcmp($1, "STYPE") == 0 || // Required
                strcmp($1, "SSPACE") == 0 || // Optional
                strcmp($1, "FINALFUNC") == 0 || // Optional
                strcmp($1, "FINALFUNC_EXTRA") == 0 || // Optional
                strcmp($1, "FINALFUNC_MODIFY") == 0 || // Optional
                strcmp($1, "COMBINEFUNC") == 0 || // Optional
                strcmp($1, "SERIALFUNC") == 0 || // Optional
                strcmp($1, "DESERIALFUNC") == 0 || // Optional
                strcmp($1, "INITCOND") == 0 || // Optional
                strcmp($1, "MSFUNC") == 0 || // Optional
                strcmp($1, "MINVFUNC") == 0 || // Optional
                strcmp($1, "MSTYPE") == 0 || // Optional
                strcmp($1, "MSSPACE") == 0 || // Optional
                strcmp($1, "MFINALFUNC") == 0 || // Optional
                strcmp($1, "MFINALFUNC_EXTRA") == 0 || // Optional
                strcmp($1, "MFINALFUNC_MODIFY") == 0 || // Optional
                strcmp($1, "MINITCOND") == 0 || // Optional
                strcmp($1, "SORTOP") == 0 || // Optional
                strcmp($1, "PARALLEL") == 0 // Optional
        ) {
            tmp1 = new IR(kIdentifier, string($1), kDataAggregateArguments, kFlagUnknown);
            free($1);
            all_gen_ir.push_back(tmp1);
        } else {
            tmp1 = new IR(kIdentifier, string("SFUNC"), kDataAggregateArguments, kFlagUnknown);
            free($1);
            all_gen_ir.push_back(tmp1);
        }

        auto tmp2 = $3;
        auto res = new IR(kOldAggrElem, OP3("", "=", ""), tmp1, tmp2);
        $$ = res;
        all_gen_ir.push_back(res);
    }

;


opt_enum_val_list:

    enum_val_list {
        auto tmp1 = $1;
        res = new IR(kOptEnumValList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptEnumValList, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


enum_val_list:

    Sconst {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kEnumValList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | enum_val_list ',' Sconst {
        auto tmp1 = $1;
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kEnumValList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
*	ALTER TYPE enumtype ADD ...
*
*****************************************************************************/


AlterEnumStmt:

    ALTER TYPE_P any_name ADD_P VALUE_P opt_if_not_exists Sconst {
        auto tmp1 = $3;
        auto tmp2 = $6;
        res = new IR(kAlterEnumStmt_1, OP3("ALTER TYPE", "ADD VALUE", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($7), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($7);
        res = new IR(kAlterEnumStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER TYPE_P any_name ADD_P VALUE_P opt_if_not_exists Sconst BEFORE Sconst {
        auto tmp1 = $3;
        auto tmp2 = $6;
        res = new IR(kAlterEnumStmt_2, OP3("ALTER TYPE", "ADD VALUE", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($7), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($7);
        res = new IR(kAlterEnumStmt_3, OP3("", "", "BEFORE"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = new IR(kIdentifier, string($9), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp4 );
        free($9);
        res = new IR(kAlterEnumStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER TYPE_P any_name ADD_P VALUE_P opt_if_not_exists Sconst AFTER Sconst {
        auto tmp1 = $3;
        auto tmp2 = $6;
        res = new IR(kAlterEnumStmt_4, OP3("ALTER TYPE", "ADD VALUE", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($7), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($7);
        res = new IR(kAlterEnumStmt_5, OP3("", "", "AFTER"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = new IR(kIdentifier, string($9), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp4 );
        free($9);
        res = new IR(kAlterEnumStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER TYPE_P any_name RENAME VALUE_P Sconst TO Sconst {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterEnumStmt_6, OP3("ALTER TYPE", "RENAME VALUE", "TO"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($8);
        res = new IR(kAlterEnumStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_if_not_exists:

    IF_P NOT EXISTS {
        res = new IR(kOptIfNotExists, OP3("IF NOT EXISTS", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kOptIfNotExists, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
*		QUERIES :
*				CREATE OPERATOR CLASS ...
*				CREATE OPERATOR FAMILY ...
*				ALTER OPERATOR FAMILY ...
*				DROP OPERATOR CLASS ...
*				DROP OPERATOR FAMILY ...
*
*****************************************************************************/


CreateOpClassStmt:

    CREATE OPERATOR CLASS any_name opt_default FOR TYPE_P Typename USING name opt_opfamily AS opclass_item_list {
        auto tmp1 = $4;
        auto tmp2 = $5;
        res = new IR(kCreateOpClassStmt_1, OP3("CREATE OPERATOR CLASS", "", "FOR TYPE"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $8;
        res = new IR(kCreateOpClassStmt_2, OP3("", "", "USING"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = new IR(kIdentifier, string($10), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp4 );
        free($10);
        res = new IR(kCreateOpClassStmt_3, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $11;
        res = new IR(kCreateOpClassStmt_4, OP3("", "", "AS"), res, tmp5);
        all_gen_ir.push_back(res);
        auto tmp6 = $13;
        res = new IR(kCreateOpClassStmt, OP3("", "", ""), res, tmp6);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opclass_item_list:

    opclass_item {
        auto tmp1 = $1;
        res = new IR(kOpclassItemList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | opclass_item_list ',' opclass_item {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kOpclassItemList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opclass_item:

    OPERATOR Iconst any_operator opclass_purpose opt_recheck {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kOpclassItem_1, OP3("OPERATOR", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $4;
        res = new IR(kOpclassItem_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $5;
        res = new IR(kOpclassItem, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | OPERATOR Iconst operator_with_argtypes opclass_purpose opt_recheck {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kOpclassItem_3, OP3("OPERATOR", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $4;
        res = new IR(kOpclassItem_4, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $5;
        res = new IR(kOpclassItem, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FUNCTION Iconst function_with_argtypes {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kOpclassItem, OP3("FUNCTION", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FUNCTION Iconst '(' type_list ')' function_with_argtypes {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kOpclassItem_5, OP3("FUNCTION", "(", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kOpclassItem, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | STORAGE Typename {
        auto tmp1 = $2;
        res = new IR(kOpclassItem, OP3("STORAGE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_default:

    DEFAULT {
        res = new IR(kOptDefault, OP3("DEFAULT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptDefault, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_opfamily:

    FAMILY any_name {
        auto tmp1 = $2;
        res = new IR(kOptOpfamily, OP3("FAMILY", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptOpfamily, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opclass_purpose:

    FOR SEARCH {
        res = new IR(kOpclassPurpose, OP3("FOR SEARCH", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FOR ORDER BY any_name {
        auto tmp1 = $4;
        res = new IR(kOpclassPurpose, OP3("FOR ORDER BY", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOpclassPurpose, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_recheck:

    RECHECK {
        /* Yu: RECHECK no longer needed. Remove it. */
        res = new IR(kOptRecheck, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptRecheck, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;



CreateOpFamilyStmt:

    CREATE OPERATOR FAMILY any_name USING name {
        auto tmp1 = $4;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kCreateOpFamilyStmt, OP3("CREATE OPERATOR FAMILY", "USING", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


AlterOpFamilyStmt:

    ALTER OPERATOR FAMILY any_name USING name ADD_P opclass_item_list {
        auto tmp1 = $4;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterOpFamilyStmt_1, OP3("ALTER OPERATOR FAMILY", "USING", "ADD"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $8;
        res = new IR(kAlterOpFamilyStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER OPERATOR FAMILY any_name USING name DROP opclass_drop_list {
        auto tmp1 = $4;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterOpFamilyStmt_2, OP3("ALTER OPERATOR FAMILY", "USING", "DROP"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $8;
        res = new IR(kAlterOpFamilyStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opclass_drop_list:

    opclass_drop {
        auto tmp1 = $1;
        res = new IR(kOpclassDropList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | opclass_drop_list ',' opclass_drop {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kOpclassDropList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opclass_drop:

    OPERATOR Iconst '(' type_list ')' {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kOpclassDrop, OP3("OPERATOR", "(", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FUNCTION Iconst '(' type_list ')' {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kOpclassDrop, OP3("FUNCTION", "(", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;



DropOpClassStmt:

    DROP OPERATOR CLASS any_name USING name opt_drop_behavior {
        auto tmp1 = $4;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kDropOpClassStmt_1, OP3("DROP OPERATOR CLASS", "USING", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $7;
        res = new IR(kDropOpClassStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DROP OPERATOR CLASS IF_P EXISTS any_name USING name opt_drop_behavior {
        auto tmp1 = $6;
        auto tmp2 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($8);
        res = new IR(kDropOpClassStmt_2, OP3("DROP OPERATOR CLASS IF EXISTS", "USING", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $9;
        res = new IR(kDropOpClassStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


DropOpFamilyStmt:

    DROP OPERATOR FAMILY any_name USING name opt_drop_behavior {
        auto tmp1 = $4;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kDropOpFamilyStmt_1, OP3("DROP OPERATOR FAMILY", "USING", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $7;
        res = new IR(kDropOpFamilyStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DROP OPERATOR FAMILY IF_P EXISTS any_name USING name opt_drop_behavior {
        auto tmp1 = $6;
        auto tmp2 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($8);
        res = new IR(kDropOpFamilyStmt_2, OP3("DROP OPERATOR FAMILY IF EXISTS", "USING", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $9;
        res = new IR(kDropOpFamilyStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
*		QUERY:
*
*		DROP OWNED BY username [, username ...] [ RESTRICT | CASCADE ]
*		REASSIGN OWNED BY username [, username ...] TO username
*
*****************************************************************************/

DropOwnedStmt:

    DROP OWNED BY role_list opt_drop_behavior {
        auto tmp1 = $4;
        auto tmp2 = $5;
        res = new IR(kDropOwnedStmt, OP3("DROP OWNED BY", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


ReassignOwnedStmt:

    REASSIGN OWNED BY role_list TO RoleSpec {
        auto tmp1 = $4;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kReassignOwnedStmt, OP3("REASSIGN OWNED BY", "TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
*		QUERY:
*
*		DROP itemtype [ IF EXISTS ] itemname [, itemname ...]
*           [ RESTRICT | CASCADE ]
*
*****************************************************************************/


DropStmt:

    DROP object_type_any_name IF_P EXISTS any_name_list opt_drop_behavior {
        auto tmp1 = $2;
        auto tmp2 = $5;
        res = new IR(kDropStmt_1, OP3("DROP", "IF EXISTS", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kDropStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;

        switch (tmp1->get_object_type_any_name()) {
        case 0: tmp2->set_any_name_list_type(kDataTableName, kUndefine); break;
        case 1: tmp2->set_any_name_list_type(kDataSequenceName, kUndefine); break;
        case 2: tmp2->set_any_name_list_type(kDataViewName, kUndefine); break;
        case 3: tmp2->set_any_name_list_type(kDataViewName, kUndefine); break;
        case 4: tmp2->set_any_name_list_type(kDataIndexName, kUndefine); break;
        case 5: tmp2->set_any_name_list_type(kDataTableName, kUndefine); break;
        case 7: tmp2->set_any_name_list_type(kDataConversionName, kUndefine); break;
        default: break;
        }
    }

    | DROP object_type_any_name any_name_list opt_drop_behavior {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kDropStmt_2, OP3("DROP", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $4;
        res = new IR(kDropStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;

        switch (tmp1->get_object_type_any_name()) {
        case 0: tmp2->set_any_name_list_type(kDataTableName, kUndefine); break;
        case 1: tmp2->set_any_name_list_type(kDataSequenceName, kUndefine); break;
        case 2: tmp2->set_any_name_list_type(kDataViewName, kUndefine); break;
        case 3: tmp2->set_any_name_list_type(kDataViewName, kUndefine); break;
        case 4: tmp2->set_any_name_list_type(kDataIndexName, kUndefine); break;
        case 5: tmp2->set_any_name_list_type(kDataTableName, kUndefine); break;
        case 7: tmp2->set_any_name_list_type(kDataConversionName, kUndefine); break;
        case 8: tmp2->set_any_name_list_type(kDataStatisticName, kUndefine); break;
        default: break;
        }
    }

    | DROP drop_type_name IF_P EXISTS name_list opt_drop_behavior {
        auto tmp1 = $2;
        auto tmp2 = $5;
        res = new IR(kDropStmt_3, OP3("DROP", "IF EXISTS", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kDropStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DROP drop_type_name name_list opt_drop_behavior {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kDropStmt_4, OP3("DROP", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $4;
        res = new IR(kDropStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DROP object_type_name_on_any_name name ON any_name opt_drop_behavior {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kDropStmt_5, OP3("DROP", "", "ON"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kDropStmt_6, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $6;
        res = new IR(kDropStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DROP object_type_name_on_any_name IF_P EXISTS name ON any_name opt_drop_behavior {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($5), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($5);
        res = new IR(kDropStmt_7, OP3("DROP", "IF EXISTS", "ON"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $7;
        res = new IR(kDropStmt_8, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $8;
        res = new IR(kDropStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DROP TYPE_P type_name_list opt_drop_behavior {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kDropStmt, OP3("DROP TYPE", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DROP TYPE_P IF_P EXISTS type_name_list opt_drop_behavior {
        auto tmp1 = $5;
        auto tmp2 = $6;
        res = new IR(kDropStmt, OP3("DROP TYPE IF EXISTS", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DROP DOMAIN_P type_name_list opt_drop_behavior {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kDropStmt, OP3("DROP DOMAIN", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DROP DOMAIN_P IF_P EXISTS type_name_list opt_drop_behavior {
        auto tmp1 = $5;
        auto tmp2 = $6;
        res = new IR(kDropStmt, OP3("DROP DOMAIN IF EXISTS", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DROP INDEX CONCURRENTLY any_name_list opt_drop_behavior {
        auto tmp1 = $4;
        auto tmp2 = $5;
        res = new IR(kDropStmt, OP3("DROP INDEX CONCURRENTLY", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_any_name_list_type(kDataIndexName, kUndefine);
    }

    | DROP INDEX CONCURRENTLY IF_P EXISTS any_name_list opt_drop_behavior {
        auto tmp1 = $6;
        auto tmp2 = $7;
        res = new IR(kDropStmt, OP3("DROP INDEX CONCURRENTLY IF EXISTS", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_any_name_list_type(kDataIndexName, kUndefine);
    }

;

/* object types taking any_name/any_name_list */

object_type_any_name:

    TABLE {
        res = new IR(kObjectTypeAnyName, OP3("TABLE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SEQUENCE {
        res = new IR(kObjectTypeAnyName, OP3("SEQUENCE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | VIEW {
        res = new IR(kObjectTypeAnyName, OP3("VIEW", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | MATERIALIZED VIEW {
        res = new IR(kObjectTypeAnyName, OP3("MATERIALIZED VIEW", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | INDEX {
        res = new IR(kObjectTypeAnyName, OP3("INDEX", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FOREIGN TABLE {
        res = new IR(kObjectTypeAnyName, OP3("FOREIGN TABLE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | COLLATION {
        res = new IR(kObjectTypeAnyName, OP3("COLLATION", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CONVERSION_P {
        res = new IR(kObjectTypeAnyName, OP3("CONVERSION", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | STATISTICS {
        res = new IR(kObjectTypeAnyName, OP3("STATISTICS", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TEXT_P SEARCH PARSER {
        res = new IR(kObjectTypeAnyName, OP3("TEXT SEARCH PARSER", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TEXT_P SEARCH DICTIONARY {
        res = new IR(kObjectTypeAnyName, OP3("TEXT SEARCH DICTIONARY", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TEXT_P SEARCH TEMPLATE {
        res = new IR(kObjectTypeAnyName, OP3("TEXT SEARCH TEMPLATE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TEXT_P SEARCH CONFIGURATION {
        res = new IR(kObjectTypeAnyName, OP3("TEXT SEARCH CONFIGURATION", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* object types taking name/name_list
*
* DROP handles some of them separately
*/


object_type_name:

    drop_type_name {
        auto tmp1 = $1;
        res = new IR(kObjectTypeName, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DATABASE {
        res = new IR(kObjectTypeName, OP3("DATABASE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ROLE {
        res = new IR(kObjectTypeName, OP3("ROLE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SUBSCRIPTION {
        res = new IR(kObjectTypeName, OP3("SUBSCRIPTION", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TABLESPACE {
        res = new IR(kObjectTypeName, OP3("TABLESPACE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


drop_type_name:

    ACCESS METHOD {
        res = new IR(kDropTypeName, OP3("ACCESS METHOD", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | EVENT TRIGGER {
        res = new IR(kDropTypeName, OP3("EVENT TRIGGER", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | EXTENSION {
        res = new IR(kDropTypeName, OP3("EXTENSION", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FOREIGN DATA_P WRAPPER {
        res = new IR(kDropTypeName, OP3("FOREIGN DATA WRAPPER", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | opt_procedural LANGUAGE {
        auto tmp1 = $1;
        res = new IR(kDropTypeName, OP3("", "LANGUAGE", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | PUBLICATION {
        res = new IR(kDropTypeName, OP3("PUBLICATION", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SCHEMA {
        res = new IR(kDropTypeName, OP3("SCHEMA", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SERVER {
        res = new IR(kDropTypeName, OP3("SERVER", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/* object types attached to a table */

object_type_name_on_any_name:

    POLICY {
        res = new IR(kObjectTypeNameOnAnyName, OP3("POLICY", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | RULE {
        res = new IR(kObjectTypeNameOnAnyName, OP3("RULE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TRIGGER {
        res = new IR(kObjectTypeNameOnAnyName, OP3("TRIGGER", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


any_name_list:

    any_name {
        auto tmp1 = $1;
        res = new IR(kAnyNameList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | any_name_list ',' any_name {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kAnyNameList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


any_name:

    ColId {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kAnyName, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ColId attrs {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = $2;
        res = new IR(kAnyName, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


attrs:

    '.' attr_name {
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        res = new IR(kAttrs, OP3(".", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | attrs '.' attr_name {
        auto tmp1 = $1;
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kAttrs, OP3("", ".", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


type_name_list:

    Typename {
        auto tmp1 = $1;
        res = new IR(kTypeNameList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | type_name_list ',' Typename {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kTypeNameList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
*		QUERY:
*				truncate table relname1, relname2, ...
*
*****************************************************************************/


TruncateStmt:

    TRUNCATE opt_table relation_expr_list opt_restart_seqs opt_drop_behavior {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kTruncateStmt_1, OP3("TRUNCATE", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $4;
        res = new IR(kTruncateStmt_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $5;
        res = new IR(kTruncateStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_restart_seqs:

    CONTINUE_P IDENTITY_P {
        res = new IR(kOptRestartSeqs, OP3("CONTINUE IDENTITY", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | RESTART IDENTITY_P {
        res = new IR(kOptRestartSeqs, OP3("RESTART IDENTITY", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kOptRestartSeqs, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
* COMMENT ON <object> IS <text>
*
*****************************************************************************/


CommentStmt:

    COMMENT ON object_type_any_name any_name IS comment_text {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kCommentStmt_1, OP3("COMMENT ON", "", "IS"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($6);
        res = new IR(kCommentStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;

        switch (tmp1->get_object_type_any_name()) {
            case 0: tmp2->set_any_name_type(kDataTableName, kUse); break;
            case 1: tmp2->set_any_name_type(kDataSequenceName, kUse); break;
            case 2: tmp2->set_any_name_type(kDataViewName, kUse); break;
            case 3: tmp2->set_any_name_type(kDataViewName, kUse); break;
            case 4: tmp2->set_any_name_type(kDataIndexName, kUse); break;
            case 5: tmp2->set_any_name_type(kDataTableName, kUse); break;
            case 7: tmp2->set_any_name_type(kDataConversionName, kUse); break;
            case 8: tmp2->set_any_name_type(kDataStatisticName, kUse); break;
            default: break;
        }

    }

    | COMMENT ON COLUMN any_name IS comment_text {
        auto tmp1 = $4;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kCommentStmt, OP3("COMMENT ON COLUMN", "IS", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_any_name_type(kDataColumnName, kUse);

    }

    | COMMENT ON object_type_name name IS comment_text {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($4), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($4);
        res = new IR(kCommentStmt_2, OP3("COMMENT ON", "", "IS"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($6);
        res = new IR(kCommentStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;

        switch (tmp1->get_object_type()) {
            case 0: tmp2->set_iden_type(kDataDatabaseName, kUse); break;
            case 1: tmp2->set_iden_type(kDataRoleName, kUse); break;
            case 3: tmp2->set_iden_type(kDataTableSpaceName, kUse); break;
            default: break;
        }


    }

    | COMMENT ON TYPE_P Typename IS comment_text {
        auto tmp1 = $4;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kCommentStmt, OP3("COMMENT ON TYPE", "IS", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | COMMENT ON DOMAIN_P Typename IS comment_text {
        auto tmp1 = $4;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kCommentStmt, OP3("COMMENT ON DOMAIN", "IS", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | COMMENT ON AGGREGATE aggregate_with_argtypes IS comment_text {
        auto tmp1 = $4;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kCommentStmt, OP3("COMMENT ON AGGREGATE", "IS", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | COMMENT ON FUNCTION function_with_argtypes IS comment_text {
        auto tmp1 = $4;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kCommentStmt, OP3("COMMENT ON FUNCTION", "IS", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | COMMENT ON OPERATOR operator_with_argtypes IS comment_text {
        auto tmp1 = $4;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kCommentStmt, OP3("COMMENT ON OPERATOR", "IS", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | COMMENT ON CONSTRAINT name ON any_name IS comment_text {
        auto tmp1 = new IR(kIdentifier, string($4), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($4);
        auto tmp2 = $6;
        res = new IR(kCommentStmt_3, OP3("COMMENT ON CONSTRAINT", "ON", "IS"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($8);
        res = new IR(kCommentStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | COMMENT ON CONSTRAINT name ON DOMAIN_P any_name IS comment_text {
        auto tmp1 = new IR(kIdentifier, string($4), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($4);
        auto tmp2 = $7;
        res = new IR(kCommentStmt_4, OP3("COMMENT ON CONSTRAINT", "ON DOMAIN", "IS"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($9), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($9);
        res = new IR(kCommentStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | COMMENT ON object_type_name_on_any_name name ON any_name IS comment_text {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($4), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($4);
        res = new IR(kCommentStmt_5, OP3("COMMENT ON", "", "ON"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kCommentStmt_6, OP3("", "", "IS"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp4 );
        free($8);
        res = new IR(kCommentStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | COMMENT ON PROCEDURE function_with_argtypes IS comment_text {
        auto tmp1 = $4;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kCommentStmt, OP3("COMMENT ON PROCEDURE", "IS", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | COMMENT ON ROUTINE function_with_argtypes IS comment_text {
        auto tmp1 = $4;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kCommentStmt, OP3("COMMENT ON ROUTINE", "IS", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | COMMENT ON TRANSFORM FOR Typename LANGUAGE name IS comment_text {
        auto tmp1 = $5;
        auto tmp2 = new IR(kIdentifier, string($7), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($7);
        res = new IR(kCommentStmt_7, OP3("COMMENT ON TRANSFORM FOR", "LANGUAGE", "IS"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($9), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($9);
        res = new IR(kCommentStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | COMMENT ON OPERATOR CLASS any_name USING name IS comment_text {
        auto tmp1 = $5;
        auto tmp2 = new IR(kIdentifier, string($7), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($7);
        res = new IR(kCommentStmt_8, OP3("COMMENT ON OPERATOR CLASS", "USING", "IS"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($9), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($9);
        res = new IR(kCommentStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | COMMENT ON OPERATOR FAMILY any_name USING name IS comment_text {
        auto tmp1 = $5;
        auto tmp2 = new IR(kIdentifier, string($7), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($7);
        res = new IR(kCommentStmt_9, OP3("COMMENT ON OPERATOR FAMILY", "USING", "IS"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($9), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($9);
        res = new IR(kCommentStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | COMMENT ON LARGE_P OBJECT_P NumericOnly IS comment_text {
        auto tmp1 = $5;
        auto tmp2 = new IR(kIdentifier, string($7), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($7);
        res = new IR(kCommentStmt, OP3("COMMENT ON LARGE OBJECT", "IS", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | COMMENT ON CAST '(' Typename AS Typename ')' IS comment_text {
        auto tmp1 = $5;
        auto tmp2 = $7;
        res = new IR(kCommentStmt_10, OP3("COMMENT ON CAST (", "AS", ") IS"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($10), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($10);
        res = new IR(kCommentStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


comment_text:

    Sconst
    | NULL_P {
        $$ = strdup($1);
    }
;


/*****************************************************************************
*
*  SECURITY LABEL [FOR <provider>] ON <object> IS <label>
*
*  As with COMMENT ON, <object> can refer to various types of database
*  objects (e.g. TABLE, COLUMN, etc.).
*
*****************************************************************************/


SecLabelStmt:

    SECURITY LABEL opt_provider ON object_type_any_name any_name IS security_label {
        auto tmp1 = $3;
        auto tmp2 = $5;
        res = new IR(kSecLabelStmt_1, OP3("SECURITY LABEL", "ON", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kSecLabelStmt_2, OP3("", "", "IS"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $8;
        res = new IR(kSecLabelStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SECURITY LABEL opt_provider ON COLUMN any_name IS security_label {
        auto tmp1 = $3;
        auto tmp2 = $6;
        res = new IR(kSecLabelStmt_3, OP3("SECURITY LABEL", "ON COLUMN", "IS"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $8;
        res = new IR(kSecLabelStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SECURITY LABEL opt_provider ON object_type_name name IS security_label {
        auto tmp1 = $3;
        auto tmp2 = $5;
        res = new IR(kSecLabelStmt_4, OP3("SECURITY LABEL", "ON", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($6);
        res = new IR(kSecLabelStmt_5, OP3("", "", "IS"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $8;
        res = new IR(kSecLabelStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SECURITY LABEL opt_provider ON TYPE_P Typename IS security_label {
        auto tmp1 = $3;
        auto tmp2 = $6;
        res = new IR(kSecLabelStmt_6, OP3("SECURITY LABEL", "ON TYPE", "IS"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $8;
        res = new IR(kSecLabelStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SECURITY LABEL opt_provider ON DOMAIN_P Typename IS security_label {
        auto tmp1 = $3;
        auto tmp2 = $6;
        res = new IR(kSecLabelStmt_7, OP3("SECURITY LABEL", "ON DOMAIN", "IS"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $8;
        res = new IR(kSecLabelStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SECURITY LABEL opt_provider ON AGGREGATE aggregate_with_argtypes IS security_label {
        auto tmp1 = $3;
        auto tmp2 = $6;
        res = new IR(kSecLabelStmt_8, OP3("SECURITY LABEL", "ON AGGREGATE", "IS"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $8;
        res = new IR(kSecLabelStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SECURITY LABEL opt_provider ON FUNCTION function_with_argtypes IS security_label {
        auto tmp1 = $3;
        auto tmp2 = $6;
        res = new IR(kSecLabelStmt_9, OP3("SECURITY LABEL", "ON FUNCTION", "IS"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $8;
        res = new IR(kSecLabelStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SECURITY LABEL opt_provider ON LARGE_P OBJECT_P NumericOnly IS security_label {
        auto tmp1 = $3;
        auto tmp2 = $7;
        res = new IR(kSecLabelStmt_10, OP3("SECURITY LABEL", "ON LARGE OBJECT", "IS"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $9;
        res = new IR(kSecLabelStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SECURITY LABEL opt_provider ON PROCEDURE function_with_argtypes IS security_label {
        auto tmp1 = $3;
        auto tmp2 = $6;
        res = new IR(kSecLabelStmt_11, OP3("SECURITY LABEL", "ON PROCEDURE", "IS"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $8;
        res = new IR(kSecLabelStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SECURITY LABEL opt_provider ON ROUTINE function_with_argtypes IS security_label {
        auto tmp1 = $3;
        auto tmp2 = $6;
        res = new IR(kSecLabelStmt_12, OP3("SECURITY LABEL", "ON ROUTINE", "IS"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $8;
        res = new IR(kSecLabelStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_provider:

    FOR NonReservedWord_or_Sconst {
        /* Yu: This is for the security label string. I do not understand its context and usage.
        ** Do not mutate it for now.
        ** FixLater: $2 into OP3.
        */
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        res = new IR(kOptProvider, OP3("FOR", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kOptProvider, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


security_label:

    Sconst {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kSecurityLabel, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NULL_P {
        res = new IR(kSecurityLabel, OP3("NULL", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
*		QUERY:
*			fetch/move
*
*****************************************************************************/


FetchStmt:

    FETCH fetch_args {
        auto tmp1 = $2;
        res = new IR(kFetchStmt, OP3("FETCH", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | MOVE fetch_args {
        auto tmp1 = $2;
        res = new IR(kFetchStmt, OP3("MOVE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


fetch_args:

    cursor_name {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kFetchArgs, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | from_in cursor_name {
        auto tmp1 = $1;
        auto tmp2 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($2);
        res = new IR(kFetchArgs, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NEXT opt_from_in cursor_name {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kFetchArgs, OP3("NEXT", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | PRIOR opt_from_in cursor_name {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kFetchArgs, OP3("PRIOR", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FIRST_P opt_from_in cursor_name {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kFetchArgs, OP3("FIRST", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | LAST_P opt_from_in cursor_name {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kFetchArgs, OP3("LAST", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ABSOLUTE_P SignedIconst opt_from_in cursor_name {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kFetchArgs_1, OP3("ABSOLUTE", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($4), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($4);
        res = new IR(kFetchArgs, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | RELATIVE_P SignedIconst opt_from_in cursor_name {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kFetchArgs_2, OP3("RELATIVE", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($4), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($4);
        res = new IR(kFetchArgs, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SignedIconst opt_from_in cursor_name {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kFetchArgs_3, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($3);
        res = new IR(kFetchArgs, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALL opt_from_in cursor_name {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kFetchArgs, OP3("ALL", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FORWARD opt_from_in cursor_name {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kFetchArgs, OP3("FORWARD", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FORWARD SignedIconst opt_from_in cursor_name {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kFetchArgs_4, OP3("FORWARD", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($4), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($4);
        res = new IR(kFetchArgs, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FORWARD ALL opt_from_in cursor_name {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($4), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($4);
        res = new IR(kFetchArgs, OP3("FORWARD ALL", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | BACKWARD opt_from_in cursor_name {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kFetchArgs, OP3("BACKWARD", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | BACKWARD SignedIconst opt_from_in cursor_name {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kFetchArgs_5, OP3("BACKWARD", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($4), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($4);
        res = new IR(kFetchArgs, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | BACKWARD ALL opt_from_in cursor_name {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($4), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($4);
        res = new IR(kFetchArgs, OP3("BACKWARD ALL", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


from_in:

    FROM {
        res = new IR(kFromIn, OP3("FROM", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | IN_P {
        res = new IR(kFromIn, OP3("IN", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_from_in:

    from_in {
        auto tmp1 = $1;
        res = new IR(kOptFromIn, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kOptFromIn, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
* GRANT and REVOKE statements
*
*****************************************************************************/


GrantStmt:

    GRANT privileges ON privilege_target TO grantee_list opt_grant_grant_option opt_granted_by {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kGrantStmt_1, OP3("GRANT", "ON", "TO"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kGrantStmt_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $7;
        res = new IR(kGrantStmt_3, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $8;
        res = new IR(kGrantStmt, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


RevokeStmt:

    REVOKE privileges ON privilege_target FROM grantee_list opt_granted_by opt_drop_behavior {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kRevokeStmt_1, OP3("REVOKE", "ON", "FROM"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kRevokeStmt_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $7;
        res = new IR(kRevokeStmt_3, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $8;
        res = new IR(kRevokeStmt, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | REVOKE GRANT OPTION FOR privileges ON privilege_target FROM grantee_list opt_granted_by opt_drop_behavior {
        auto tmp1 = $5;
        auto tmp2 = $7;
        res = new IR(kRevokeStmt_4, OP3("REVOKE GRANT OPTION FOR", "ON", "FROM"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $9;
        res = new IR(kRevokeStmt_5, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $10;
        res = new IR(kRevokeStmt_6, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $11;
        res = new IR(kRevokeStmt, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*
* Privilege names are represented as strings; the validity of the privilege
* names gets checked at execution.  This is a bit annoying but we have little
* choice because of the syntactic conflict with lists of role names in
* GRANT/REVOKE.  What's more, we have to call out in the "privilege"
* production any reserved keywords that need to be usable as privilege names.
*/

/* either ALL [PRIVILEGES] or a list of individual privileges */

privileges:

    privilege_list {
        auto tmp1 = $1;
        res = new IR(kPrivileges, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALL {
        res = new IR(kPrivileges, OP3("ALL", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALL PRIVILEGES {
        res = new IR(kPrivileges, OP3("ALL PRIVILEGES", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALL '(' columnList ')' {
        auto tmp1 = $3;
        res = new IR(kPrivileges, OP3("ALL (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALL PRIVILEGES '(' columnList ')' {
        auto tmp1 = $4;
        res = new IR(kPrivileges, OP3("ALL PRIVILEGES (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


privilege_list:

    privilege {
        auto tmp1 = $1;
        res = new IR(kPrivilegeList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | privilege_list ',' privilege {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kPrivilegeList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


privilege:

    SELECT opt_column_list {
        auto tmp1 = $2;
        res = new IR(kPrivilege, OP3("SELECT", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | REFERENCES opt_column_list {
        auto tmp1 = $2;
        res = new IR(kPrivilege, OP3("REFERENCES", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CREATE opt_column_list {
        auto tmp1 = $2;
        res = new IR(kPrivilege, OP3("CREATE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ColId opt_column_list {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = $2;
        res = new IR(kPrivilege, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/* Don't bother trying to fold the first two rules into one using
* opt_table.  You're going to get conflicts.
*/

privilege_target:

    qualified_name_list {
        auto tmp1 = $1;
        res = new IR(kPrivilegeTarget, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TABLE qualified_name_list {
        auto tmp1 = $2;
        res = new IR(kPrivilegeTarget, OP3("TABLE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SEQUENCE qualified_name_list {
        auto tmp1 = $2;
        res = new IR(kPrivilegeTarget, OP3("SEQUENCE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FOREIGN DATA_P WRAPPER name_list {
        auto tmp1 = $4;
        res = new IR(kPrivilegeTarget, OP3("FOREIGN DATA WRAPPER", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FOREIGN SERVER name_list {
        auto tmp1 = $3;
        res = new IR(kPrivilegeTarget, OP3("FOREIGN SERVER", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FUNCTION function_with_argtypes_list {
        auto tmp1 = $2;
        res = new IR(kPrivilegeTarget, OP3("FUNCTION", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | PROCEDURE function_with_argtypes_list {
        auto tmp1 = $2;
        res = new IR(kPrivilegeTarget, OP3("PROCEDURE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ROUTINE function_with_argtypes_list {
        auto tmp1 = $2;
        res = new IR(kPrivilegeTarget, OP3("ROUTINE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DATABASE name_list {
        auto tmp1 = $2;
        res = new IR(kPrivilegeTarget, OP3("DATABASE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DOMAIN_P any_name_list {
        auto tmp1 = $2;
        res = new IR(kPrivilegeTarget, OP3("DOMAIN", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | LANGUAGE name_list {
        auto tmp1 = $2;
        res = new IR(kPrivilegeTarget, OP3("LANGUAGE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | LARGE_P OBJECT_P NumericOnly_list {
        auto tmp1 = $3;
        res = new IR(kPrivilegeTarget, OP3("LARGE OBJECT", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SCHEMA name_list {
        auto tmp1 = $2;
        res = new IR(kPrivilegeTarget, OP3("SCHEMA", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TABLESPACE name_list {
        auto tmp1 = $2;
        res = new IR(kPrivilegeTarget, OP3("TABLESPACE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TYPE_P any_name_list {
        auto tmp1 = $2;
        res = new IR(kPrivilegeTarget, OP3("TYPE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALL TABLES IN_P SCHEMA name_list {
        auto tmp1 = $5;
        res = new IR(kPrivilegeTarget, OP3("ALL TABLES IN SCHEMA", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALL SEQUENCES IN_P SCHEMA name_list {
        auto tmp1 = $5;
        res = new IR(kPrivilegeTarget, OP3("ALL SEQUENCES IN SCHEMA", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALL FUNCTIONS IN_P SCHEMA name_list {
        auto tmp1 = $5;
        res = new IR(kPrivilegeTarget, OP3("ALL FUNCTIONS IN SCHEMA", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALL PROCEDURES IN_P SCHEMA name_list {
        auto tmp1 = $5;
        res = new IR(kPrivilegeTarget, OP3("ALL PROCEDURES IN SCHEMA", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALL ROUTINES IN_P SCHEMA name_list {
        auto tmp1 = $5;
        res = new IR(kPrivilegeTarget, OP3("ALL ROUTINES IN SCHEMA", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;



grantee_list:

    grantee {
        auto tmp1 = $1;
        res = new IR(kGranteeList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | grantee_list ',' grantee {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kGranteeList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


grantee:

    RoleSpec {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kGrantee, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | GROUP_P RoleSpec {
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        res = new IR(kGrantee, OP3("GROUP", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;



opt_grant_grant_option:

    WITH GRANT OPTION {
        res = new IR(kOptGrantGrantOption, OP3("WITH GRANT OPTION", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptGrantGrantOption, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
* GRANT and REVOKE ROLE statements
*
*****************************************************************************/


GrantRoleStmt:

    GRANT privilege_list TO role_list opt_grant_admin_option opt_granted_by {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kGrantRoleStmt_1, OP3("GRANT", "TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kGrantRoleStmt_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $6;
        res = new IR(kGrantRoleStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


RevokeRoleStmt:

    REVOKE privilege_list FROM role_list opt_granted_by opt_drop_behavior {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kRevokeRoleStmt_1, OP3("REVOKE", "FROM", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kRevokeRoleStmt_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $6;
        res = new IR(kRevokeRoleStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | REVOKE ADMIN OPTION FOR privilege_list FROM role_list opt_granted_by opt_drop_behavior {
        auto tmp1 = $5;
        auto tmp2 = $7;
        res = new IR(kRevokeRoleStmt_3, OP3("REVOKE ADMIN OPTION FOR", "FROM", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $8;
        res = new IR(kRevokeRoleStmt_4, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $9;
        res = new IR(kRevokeRoleStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_grant_admin_option:

    WITH ADMIN OPTION {
        res = new IR(kOptGrantAdminOption, OP3("WITH ADMIN OPTION", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptGrantAdminOption, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_granted_by:

    GRANTED BY RoleSpec {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        res = new IR(kOptGrantedBy, OP3("GRANTED BY", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptGrantedBy, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
* ALTER DEFAULT PRIVILEGES statement
*
*****************************************************************************/


AlterDefaultPrivilegesStmt:

    ALTER DEFAULT PRIVILEGES DefACLOptionList DefACLAction {
        auto tmp1 = $4;
        auto tmp2 = $5;
        res = new IR(kAlterDefaultPrivilegesStmt, OP3("ALTER DEFAULT PRIVILEGES", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


DefACLOptionList:

    DefACLOptionList DefACLOption {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kDefACLOptionList, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kDefACLOptionList, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


DefACLOption:

    IN_P SCHEMA name_list {
        auto tmp1 = $3;
        res = new IR(kDefACLOption, OP3("IN SCHEMA", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FOR ROLE role_list {
        auto tmp1 = $3;
        res = new IR(kDefACLOption, OP3("FOR ROLE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FOR USER role_list {
        auto tmp1 = $3;
        res = new IR(kDefACLOption, OP3("FOR USER", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* This should match GRANT/REVOKE, except that individual target objects
* are not mentioned and we only allow a subset of object types.
*/

DefACLAction:

    GRANT privileges ON defacl_privilege_target TO grantee_list opt_grant_grant_option {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kDefACLAction_1, OP3("GRANT", "ON", "TO"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kDefACLAction_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $7;
        res = new IR(kDefACLAction, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | REVOKE privileges ON defacl_privilege_target FROM grantee_list opt_drop_behavior {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kDefACLAction_3, OP3("REVOKE", "ON", "FROM"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kDefACLAction_4, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $7;
        res = new IR(kDefACLAction, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | REVOKE GRANT OPTION FOR privileges ON defacl_privilege_target FROM grantee_list opt_drop_behavior {
        auto tmp1 = $5;
        auto tmp2 = $7;
        res = new IR(kDefACLAction_5, OP3("REVOKE GRANT OPTION FOR", "ON", "FROM"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $9;
        res = new IR(kDefACLAction_6, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $10;
        res = new IR(kDefACLAction, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


defacl_privilege_target:

    TABLES {
        res = new IR(kDefaclPrivilegeTarget, OP3("TABLES", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FUNCTIONS {
        res = new IR(kDefaclPrivilegeTarget, OP3("FUNCTIONS", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ROUTINES {
        res = new IR(kDefaclPrivilegeTarget, OP3("ROUTINES", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SEQUENCES {
        res = new IR(kDefaclPrivilegeTarget, OP3("SEQUENCES", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TYPES_P {
        res = new IR(kDefaclPrivilegeTarget, OP3("TYPES", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SCHEMAS {
        res = new IR(kDefaclPrivilegeTarget, OP3("SCHEMAS", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
*		QUERY: CREATE INDEX
*
* Note: we cannot put TABLESPACE clause after WHERE clause unless we are
* willing to make TABLESPACE a fully reserved word.
*****************************************************************************/


IndexStmt:

    CREATE opt_unique INDEX opt_concurrently opt_index_name ON relation_expr access_method_clause '(' index_params ')' opt_include opt_reloptions OptTableSpace where_clause {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kIndexStmt_1, OP3("CREATE", "INDEX", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kIndexStmt_2, OP3("", "", "ON"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $7;
        res = new IR(kIndexStmt_3, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $8;
        res = new IR(kIndexStmt_4, OP3("", "", "("), res, tmp5);
        all_gen_ir.push_back(res);
        auto tmp6 = $10;
        res = new IR(kIndexStmt_5, OP3("", "", ")"), res, tmp6);
        all_gen_ir.push_back(res);
        auto tmp7 = $12;
        res = new IR(kIndexStmt_6, OP3("", "", ""), res, tmp7);
        all_gen_ir.push_back(res);
        auto tmp8 = $13;
        res = new IR(kIndexStmt_7, OP3("", "", ""), res, tmp8);
        all_gen_ir.push_back(res);
        auto tmp9 = $14;
        res = new IR(kIndexStmt_8, OP3("", "", ""), res, tmp9);
        all_gen_ir.push_back(res);
        auto tmp10 = $15;
        res = new IR(kIndexStmt, OP3("", "", ""), res, tmp10);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CREATE opt_unique INDEX opt_concurrently IF_P NOT EXISTS name ON relation_expr access_method_clause '(' index_params ')' opt_include opt_reloptions OptTableSpace where_clause {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kIndexStmt_9, OP3("CREATE", "INDEX", "IF NOT EXISTS"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($8);
        res = new IR(kIndexStmt_10, OP3("", "", "ON"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $10;
        res = new IR(kIndexStmt_11, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $11;
        res = new IR(kIndexStmt_12, OP3("", "", "("), res, tmp5);
        all_gen_ir.push_back(res);
        auto tmp6 = $13;
        res = new IR(kIndexStmt_13, OP3("", "", ")"), res, tmp6);
        all_gen_ir.push_back(res);
        auto tmp7 = $15;
        res = new IR(kIndexStmt_14, OP3("", "", ""), res, tmp7);
        all_gen_ir.push_back(res);
        auto tmp8 = $16;
        res = new IR(kIndexStmt_15, OP3("", "", ""), res, tmp8);
        all_gen_ir.push_back(res);
        auto tmp9 = $17;
        res = new IR(kIndexStmt_16, OP3("", "", ""), res, tmp9);
        all_gen_ir.push_back(res);
        auto tmp10 = $18;
        res = new IR(kIndexStmt, OP3("", "", ""), res, tmp10);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp3->set_iden_type(kDataIndexName, kDefine);

    }

;


opt_unique:

    UNIQUE {
        res = new IR(kOptUnique, OP3("UNIQUE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptUnique, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_concurrently:

    CONCURRENTLY {
        res = new IR(kOptConcurrently, OP3("CONCURRENTLY", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptConcurrently, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_index_name:

    name {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kOptIndexName, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_iden_type(kDataIndexName, kDefine);
    }

    | /*EMPTY*/ {
        res = new IR(kOptIndexName, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


access_method_clause:

    USING name {
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        res = new IR(kAccessMethodClause, OP3("USING", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kAccessMethodClause, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


index_params:

    index_elem {
        auto tmp1 = $1;
        res = new IR(kIndexParams, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | index_params ',' index_elem {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kIndexParams, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;



index_elem_options:

    opt_collate opt_class opt_asc_desc opt_nulls_order {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kIndexElemOptions_1, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $3;
        res = new IR(kIndexElemOptions_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $4;
        res = new IR(kIndexElemOptions, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | opt_collate any_name reloptions opt_asc_desc opt_nulls_order {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kIndexElemOptions_3, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $3;
        res = new IR(kIndexElemOptions_4, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $4;
        res = new IR(kIndexElemOptions_5, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $5;
        res = new IR(kIndexElemOptions, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* Index attributes can be either simple column references, or arbitrary
* expressions in parens.  For backwards-compatibility reasons, we allow
* an expression that's just a function call to be written without parens.
*/

index_elem:

    ColId index_elem_options {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = $2;
        res = new IR(kIndexElem, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        /* Yu: This index_elem is actually pointing to table columns. */
        tmp1->set_iden_type(kDataColumnName, kUse);
    }

    | func_expr_windowless index_elem_options {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kIndexElem, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '(' a_expr ')' index_elem_options {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kIndexElem, OP3("(", ")", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_include:

    INCLUDE '(' index_including_params ')' {
        auto tmp1 = $3;
        res = new IR(kOptInclude, OP3("INCLUDE (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kOptInclude, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


index_including_params:

    index_elem {
        auto tmp1 = $1;
        res = new IR(kIndexIncludingParams, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | index_including_params ',' index_elem {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kIndexIncludingParams, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_collate:

    COLLATE any_name {
        auto tmp1 = $2;
        res = new IR(kOptCollate, OP3("COLLATE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_any_name_type(kDataCollate, kNoModi);

    }

    | /*EMPTY*/ {
        res = new IR(kOptCollate, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_class:

    any_name {
        auto tmp1 = $1;
        res = new IR(kOptClass, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptClass, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_asc_desc:

    ASC {
        res = new IR(kOptAscDesc, OP3("ASC", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DESC {
        res = new IR(kOptAscDesc, OP3("DESC", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptAscDesc, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_nulls_order:

    NULLS_LA FIRST_P {
        res = new IR(kOptNullsOrder, OP3("NULLS FIRST", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NULLS_LA LAST_P {
        res = new IR(kOptNullsOrder, OP3("NULLS LAST", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptNullsOrder, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
*		QUERY:
*				create [or replace] function <fname>
*						[(<type-1> { , <type-n>})]
*						returns <type-r>
*						as <filename or code in language as appropriate>
*						language <lang> [with parameters]
*
*****************************************************************************/


CreateFunctionStmt:

    CREATE opt_or_replace FUNCTION func_name func_args_with_defaults RETURNS func_return opt_createfunc_opt_list opt_routine_body {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kCreateFunctionStmt_1, OP3("CREATE", "FUNCTION", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kCreateFunctionStmt_2, OP3("", "", "RETURNS"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $7;
        res = new IR(kCreateFunctionStmt_3, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $8;
        res = new IR(kCreateFunctionStmt_4, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        auto tmp6 = $9;
        res = new IR(kCreateFunctionStmt, OP3("", "", ""), res, tmp6);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CREATE opt_or_replace FUNCTION func_name func_args_with_defaults RETURNS TABLE '(' table_func_column_list ')' opt_createfunc_opt_list opt_routine_body {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kCreateFunctionStmt_5, OP3("CREATE", "FUNCTION", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kCreateFunctionStmt_6, OP3("", "", "RETURNS TABLE ("), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $9;
        res = new IR(kCreateFunctionStmt_7, OP3("", "", ")"), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $11;
        res = new IR(kCreateFunctionStmt_8, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        auto tmp6 = $12;
        res = new IR(kCreateFunctionStmt, OP3("", "", ""), res, tmp6);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CREATE opt_or_replace FUNCTION func_name func_args_with_defaults opt_createfunc_opt_list opt_routine_body {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kCreateFunctionStmt_9, OP3("CREATE", "FUNCTION", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kCreateFunctionStmt_10, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $6;
        res = new IR(kCreateFunctionStmt_11, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $7;
        res = new IR(kCreateFunctionStmt, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CREATE opt_or_replace PROCEDURE func_name func_args_with_defaults opt_createfunc_opt_list opt_routine_body {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kCreateFunctionStmt_12, OP3("CREATE", "PROCEDURE", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kCreateFunctionStmt_13, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $6;
        res = new IR(kCreateFunctionStmt_14, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $7;
        res = new IR(kCreateFunctionStmt, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_or_replace:

    OR REPLACE {
        res = new IR(kOptOrReplace, OP3("OR REPLACE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptOrReplace, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


func_args:

    '(' func_args_list ')' {
        auto tmp1 = $2;
        res = new IR(kFuncArgs, OP3("(", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '(' ')' {
        res = new IR(kFuncArgs, OP3("( )", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


func_args_list:

    func_arg {
        auto tmp1 = $1;
        res = new IR(kFuncArgsList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | func_args_list ',' func_arg {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kFuncArgsList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


function_with_argtypes_list:

    function_with_argtypes {
        auto tmp1 = $1;
        res = new IR(kFunctionWithArgtypesList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | function_with_argtypes_list ',' function_with_argtypes {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kFunctionWithArgtypesList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


function_with_argtypes:

    func_name func_args {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kFunctionWithArgtypes, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | type_func_name_keyword {
        /* This is a specitial use, we are using a read-only char to initialize the string! */
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        res = new IR(kFunctionWithArgtypes, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ColId {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kFunctionWithArgtypes, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ColId indirection {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = $2;
        res = new IR(kFunctionWithArgtypes, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* func_args_with_defaults is separate because we only want to accept
* defaults in CREATE FUNCTION, not in ALTER etc.
*/

func_args_with_defaults:

    '(' func_args_with_defaults_list ')' {
        auto tmp1 = $2;
        res = new IR(kFuncArgsWithDefaults, OP3("(", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '(' ')' {
        res = new IR(kFuncArgsWithDefaults, OP3("( )", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


func_args_with_defaults_list:

    func_arg_with_default {
        auto tmp1 = $1;
        res = new IR(kFuncArgsWithDefaultsList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | func_args_with_defaults_list ',' func_arg_with_default {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kFuncArgsWithDefaultsList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* The style with arg_class first is SQL99 standard, but Oracle puts
* param_name first; accept both since it's likely people will try both
* anyway.  Don't bother trying to save productions by letting arg_class
* have an empty alternative ... you'll get shift/reduce conflicts.
*
* We can catch over-specified arguments here if we want to,
* but for now better to silently swallow typmod, etc.
* - thomas 2000-03-22
*/

func_arg:

    arg_class param_name func_type {
        auto tmp1 = $1;
        auto tmp2 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($2);
        res = new IR(kFuncArg_1, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $3;
        res = new IR(kFuncArg, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | param_name arg_class func_type {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = $2;
        res = new IR(kFuncArg_2, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $3;
        res = new IR(kFuncArg, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | param_name func_type {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = $2;
        res = new IR(kFuncArg, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | arg_class func_type {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kFuncArg, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | func_type {
        auto tmp1 = $1;
        res = new IR(kFuncArg, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/* INOUT is SQL99 standard, IN OUT is for Oracle compatibility */

arg_class:

    IN_P {
        res = new IR(kArgClass, OP3("IN", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | OUT_P {
        res = new IR(kArgClass, OP3("OUT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | INOUT {
        res = new IR(kArgClass, OP3("INOUT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | IN_P OUT_P {
        res = new IR(kArgClass, OP3("IN OUT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | VARIADIC {
        res = new IR(kArgClass, OP3("VARIADIC", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* Ideally param_name should be ColId, but that causes too many conflicts.
*/

param_name:
    type_function_name
;


func_return:

    func_type {
        auto tmp1 = $1;
        res = new IR(kFuncReturn, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* We would like to make the %TYPE productions here be ColId attrs etc,
* but that causes reduce/reduce conflicts.  type_function_name
* is next best choice.
*/

func_type:

    Typename {
        auto tmp1 = $1;
        res = new IR(kFuncType, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | type_function_name attrs '%' TYPE_P {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = $2;
        res = new IR(kFuncType, OP3("", "", "% TYPE"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SETOF type_function_name attrs '%' TYPE_P {
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        auto tmp2 = $3;
        res = new IR(kFuncType, OP3("SETOF", "", "% TYPE"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


func_arg_with_default:

    func_arg {
        auto tmp1 = $1;
        res = new IR(kFuncArgWithDefault, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | func_arg DEFAULT a_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kFuncArgWithDefault, OP3("", "DEFAULT", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | func_arg '=' a_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kFuncArgWithDefault, OP3("", "=", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/* Aggregate args can be most things that function args can be */

aggr_arg:

    func_arg {
        auto tmp1 = $1;
        res = new IR(kAggrArg, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* The SQL standard offers no guidance on how to declare aggregate argument
* lists, since it doesn't have CREATE AGGREGATE etc.  We accept these cases:
*
* (*)									- normal agg with no args
* (aggr_arg,...)						- normal agg with args
* (ORDER BY aggr_arg,...)				- ordered-set agg with no direct args
* (aggr_arg,... ORDER BY aggr_arg,...)	- ordered-set agg with direct args
*
* The zero-argument case is spelled with '*' for consistency with COUNT(*).
*
* An additional restriction is that if the direct-args list ends in a
* VARIADIC item, the ordered-args list must contain exactly one item that
* is also VARIADIC with the same type.  This allows us to collapse the two
* VARIADIC items into one, which is necessary to represent the aggregate in
* pg_proc.  We check this at the grammar stage so that we can return a list
* in which the second VARIADIC item is already discarded, avoiding extra work
* in cases such as DROP AGGREGATE.
*
* The return value of this production is a two-element list, in which the
* first item is a sublist of FunctionParameter nodes (with any duplicate
* VARIADIC item already dropped, as per above) and the second is an integer
* Value node, containing -1 if there was no ORDER BY and otherwise the number
* of argument declarations before the ORDER BY.  (If this number is equal
* to the first sublist's length, then we dropped a duplicate VARIADIC item.)
* This representation is passed as-is to CREATE AGGREGATE; for operations
* on existing aggregates, we can just apply extractArgTypes to the first
* sublist.
*/

aggr_args:

    '(' '*' ')' {
        res = new IR(kAggrArgs, OP3("( * )", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '(' aggr_args_list ')' {
        auto tmp1 = $2;
        res = new IR(kAggrArgs, OP3("(", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '(' ORDER BY aggr_args_list ')' {
        auto tmp1 = $4;
        res = new IR(kAggrArgs, OP3("( ORDER BY", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '(' aggr_args_list ORDER BY aggr_args_list ')' {
        auto tmp1 = $2;
        auto tmp2 = $5;
        res = new IR(kAggrArgs, OP3("(", "ORDER BY", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


aggr_args_list:

    aggr_arg {
        auto tmp1 = $1;
        res = new IR(kAggrArgsList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | aggr_args_list ',' aggr_arg {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kAggrArgsList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


aggregate_with_argtypes:

    func_name aggr_args {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kAggregateWithArgtypes, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


aggregate_with_argtypes_list:

    aggregate_with_argtypes {
        auto tmp1 = $1;
        res = new IR(kAggregateWithArgtypesList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | aggregate_with_argtypes_list ',' aggregate_with_argtypes {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kAggregateWithArgtypesList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_createfunc_opt_list:

    createfunc_opt_list {
        auto tmp1 = $1;
        res = new IR(kOptCreatefuncOptList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptCreatefuncOptList, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


createfunc_opt_list:

    createfunc_opt_item {
        auto tmp1 = $1;
        res = new IR(kCreatefuncOptList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | createfunc_opt_list createfunc_opt_item {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kCreatefuncOptList, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* Options common to both CREATE FUNCTION and ALTER FUNCTION
*/

common_func_opt_item:

    CALLED ON NULL_P INPUT_P {
        res = new IR(kCommonFuncOptItem, OP3("CALLED ON NULL INPUT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | RETURNS NULL_P ON NULL_P INPUT_P {
        res = new IR(kCommonFuncOptItem, OP3("RETURNS NULL ON NULL INPUT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | STRICT_P {
        res = new IR(kCommonFuncOptItem, OP3("STRICT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | IMMUTABLE {
        res = new IR(kCommonFuncOptItem, OP3("IMMUTABLE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | STABLE {
        res = new IR(kCommonFuncOptItem, OP3("STABLE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | VOLATILE {
        res = new IR(kCommonFuncOptItem, OP3("VOLATILE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | EXTERNAL SECURITY DEFINER {
        res = new IR(kCommonFuncOptItem, OP3("EXTERNAL SECURITY DEFINER", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | EXTERNAL SECURITY INVOKER {
        res = new IR(kCommonFuncOptItem, OP3("EXTERNAL SECURITY INVOKER", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SECURITY DEFINER {
        res = new IR(kCommonFuncOptItem, OP3("SECURITY DEFINER", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SECURITY INVOKER {
        res = new IR(kCommonFuncOptItem, OP3("SECURITY INVOKER", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | LEAKPROOF {
        res = new IR(kCommonFuncOptItem, OP3("LEAKPROOF", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NOT LEAKPROOF {
        res = new IR(kCommonFuncOptItem, OP3("NOT LEAKPROOF", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | COST NumericOnly {
        auto tmp1 = $2;
        res = new IR(kCommonFuncOptItem, OP3("COST", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ROWS NumericOnly {
        auto tmp1 = $2;
        res = new IR(kCommonFuncOptItem, OP3("ROWS", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SUPPORT any_name {
        auto tmp1 = $2;
        res = new IR(kCommonFuncOptItem, OP3("SUPPORT", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FunctionSetResetClause {
        auto tmp1 = $1;
        res = new IR(kCommonFuncOptItem, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | PARALLEL ColId {
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        res = new IR(kCommonFuncOptItem, OP3("PARALLEL", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


createfunc_opt_item:

    AS func_as {
        auto tmp1 = $2;
        res = new IR(kCreatefuncOptItem, OP3("AS", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | LANGUAGE NonReservedWord_or_Sconst {
        /* Yu: Assigning program language for the function. It can be c, sql, internal and other user defined language.
        ** Ignore user defined language for now.
        ** FixLater: $2 to OP3
        */
        if ($2 && strcmp($2, "c") == 0 || strcmp($2, "sql") == 0 || strcmp($2, "internal") == 0 || strcmp($2, "plpgsql") == 0) {
            auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
            res = new IR(kCreatefuncOptItem, OP3("LANGUAGE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        } else {
            res = new IR(kCreatefuncOptItem, OP3("LANGUAGE", "sql", ""));
        all_gen_ir.push_back(res);
        }
        free($2);
        $$ = res;
    }

    | TRANSFORM transform_type_list {
        auto tmp1 = $2;
        res = new IR(kCreatefuncOptItem, OP3("TRANSFORM", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | WINDOW {
        res = new IR(kCreatefuncOptItem, OP3("WINDOW", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | common_func_opt_item {
        auto tmp1 = $1;
        res = new IR(kCreatefuncOptItem, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


func_as:

    Sconst {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kFuncAs, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | Sconst ',' Sconst {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kFuncAs, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


ReturnStmt:

    RETURN a_expr {
        auto tmp1 = $2;
        res = new IR(kReturnStmt, OP3("RETURN", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_routine_body:

    ReturnStmt {
        auto tmp1 = $1;
        res = new IR(kOptRoutineBody, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | BEGIN_P ATOMIC routine_body_stmt_list END_P {
        auto tmp1 = $3;
        res = new IR(kOptRoutineBody, OP3("BEGIN ATOMIC", "END", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptRoutineBody, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


routine_body_stmt_list:

    routine_body_stmt_list routine_body_stmt ';' {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kRoutineBodyStmtList, OP3("", "", ";"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kRoutineBodyStmtList, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


routine_body_stmt:

    stmt {
        auto tmp1 = $1;
        res = new IR(kRoutineBodyStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ReturnStmt {
        auto tmp1 = $1;
        res = new IR(kRoutineBodyStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


transform_type_list:

    FOR TYPE_P Typename {
        auto tmp1 = $3;
        res = new IR(kTransformTypeList, OP3("FOR TYPE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | transform_type_list ',' FOR TYPE_P Typename {
        auto tmp1 = $1;
        auto tmp2 = $5;
        res = new IR(kTransformTypeList, OP3("", ", FOR TYPE", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_definition:

    WITH definition {
        auto tmp1 = $2;
        res = new IR(kOptDefinition, OP3("WITH", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptDefinition, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


table_func_column:

    param_name func_type {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = $2;
        res = new IR(kTableFuncColumn, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


table_func_column_list:

    table_func_column {
        auto tmp1 = $1;
        res = new IR(kTableFuncColumnList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | table_func_column_list ',' table_func_column {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kTableFuncColumnList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
* ALTER FUNCTION / ALTER PROCEDURE / ALTER ROUTINE
*
* RENAME and OWNER subcommands are already provided by the generic
* ALTER infrastructure, here we just specify alterations that can
* only be applied to functions.
*
*****************************************************************************/

AlterFunctionStmt:

    ALTER FUNCTION function_with_argtypes alterfunc_opt_list opt_restrict {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kAlterFunctionStmt_1, OP3("ALTER FUNCTION", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kAlterFunctionStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER PROCEDURE function_with_argtypes alterfunc_opt_list opt_restrict {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kAlterFunctionStmt_2, OP3("ALTER PROCEDURE", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kAlterFunctionStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER ROUTINE function_with_argtypes alterfunc_opt_list opt_restrict {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kAlterFunctionStmt_3, OP3("ALTER ROUTINE", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kAlterFunctionStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


alterfunc_opt_list:

    common_func_opt_item {
        auto tmp1 = $1;
        res = new IR(kAlterfuncOptList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | alterfunc_opt_list common_func_opt_item {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kAlterfuncOptList, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/* Ignored, merely for SQL compliance */

opt_restrict:

    RESTRICT {
        res = new IR(kOptRestrict, OP3("RESTRICT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kOptRestrict, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
*		QUERY:
*
*		DROP FUNCTION funcname (arg1, arg2, ...) [ RESTRICT | CASCADE ]
*		DROP PROCEDURE procname (arg1, arg2, ...) [ RESTRICT | CASCADE ]
*		DROP ROUTINE routname (arg1, arg2, ...) [ RESTRICT | CASCADE ]
*		DROP AGGREGATE aggname (arg1, ...) [ RESTRICT | CASCADE ]
*		DROP OPERATOR opname (leftoperand_typ, rightoperand_typ) [ RESTRICT | CASCADE ]
*
*****************************************************************************/


RemoveFuncStmt:

    DROP FUNCTION function_with_argtypes_list opt_drop_behavior {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kRemoveFuncStmt, OP3("DROP FUNCTION", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DROP FUNCTION IF_P EXISTS function_with_argtypes_list opt_drop_behavior {
        auto tmp1 = $5;
        auto tmp2 = $6;
        res = new IR(kRemoveFuncStmt, OP3("DROP FUNCTION IF EXISTS", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DROP PROCEDURE function_with_argtypes_list opt_drop_behavior {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kRemoveFuncStmt, OP3("DROP PROCEDURE", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DROP PROCEDURE IF_P EXISTS function_with_argtypes_list opt_drop_behavior {
        auto tmp1 = $5;
        auto tmp2 = $6;
        res = new IR(kRemoveFuncStmt, OP3("DROP PROCEDURE IF EXISTS", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DROP ROUTINE function_with_argtypes_list opt_drop_behavior {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kRemoveFuncStmt, OP3("DROP ROUTINE", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DROP ROUTINE IF_P EXISTS function_with_argtypes_list opt_drop_behavior {
        auto tmp1 = $5;
        auto tmp2 = $6;
        res = new IR(kRemoveFuncStmt, OP3("DROP ROUTINE IF EXISTS", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


RemoveAggrStmt:

    DROP AGGREGATE aggregate_with_argtypes_list opt_drop_behavior {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kRemoveAggrStmt, OP3("DROP AGGREGATE", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DROP AGGREGATE IF_P EXISTS aggregate_with_argtypes_list opt_drop_behavior {
        auto tmp1 = $5;
        auto tmp2 = $6;
        res = new IR(kRemoveAggrStmt, OP3("DROP AGGREGATE IF EXISTS", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


RemoveOperStmt:

    DROP OPERATOR operator_with_argtypes_list opt_drop_behavior {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kRemoveOperStmt, OP3("DROP OPERATOR", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DROP OPERATOR IF_P EXISTS operator_with_argtypes_list opt_drop_behavior {
        auto tmp1 = $5;
        auto tmp2 = $6;
        res = new IR(kRemoveOperStmt, OP3("DROP OPERATOR IF EXISTS", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


oper_argtypes:

    '(' Typename ')' {
        /* Yu: This syntax is not permitted. (Weird). Change it to the third form. */
        auto tmp1 = $2;
        res = new IR(kOperArgtypes, OP3("( NONE ,", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '(' Typename ',' Typename ')' {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kOperArgtypes, OP3("(", ",", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '(' NONE ',' Typename ')' {
        auto tmp1 = $4;
        res = new IR(kOperArgtypes, OP3("( NONE ,", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '(' Typename ',' NONE ')' {
        auto tmp1 = $2;
        res = new IR(kOperArgtypes, OP3("(", ", NONE )", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


any_operator:

    all_Op {
        auto tmp1 = $1;
        res = new IR(kAnyOperator, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ColId '.' any_operator {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = $3;
        res = new IR(kAnyOperator, OP3("", ".", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


operator_with_argtypes_list:

    operator_with_argtypes {
        auto tmp1 = $1;
        res = new IR(kOperatorWithArgtypesList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | operator_with_argtypes_list ',' operator_with_argtypes {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kOperatorWithArgtypesList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


operator_with_argtypes:

    any_operator oper_argtypes {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kOperatorWithArgtypes, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
*		DO <anonymous code block> [ LANGUAGE language ]
*
* We use a DefElem list for future extensibility, and to allow flexibility
* in the clause order.
*
*****************************************************************************/


DoStmt:

    DO dostmt_opt_list {
        auto tmp1 = $2;
        res = new IR(kDoStmt, OP3("DO", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


dostmt_opt_list:

    dostmt_opt_item {
        auto tmp1 = $1;
        res = new IR(kDostmtOptList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | dostmt_opt_list dostmt_opt_item {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kDostmtOptList, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


dostmt_opt_item:

    Sconst {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kDostmtOptItem, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | LANGUAGE NonReservedWord_or_Sconst {
        /* Yu: Programming language used for the DO stmt. Do not mutate.  */
        /* FixLater: $2 into OP3 */
        if ($2 && strcmp($2, "c") == 0 || strcmp($2, "sql") == 0 || strcmp($2, "internal") == 0 || strcmp($2, "plpgsql") == 0) {
            auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
            res = new IR(kDostmtOptItem, OP3("LANGUAGE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        } else {
            res = new IR(kDostmtOptItem, OP3("LANGUAGE", "sql", ""));
        all_gen_ir.push_back(res);
        }
        free($2);
        $$ = res;
    }

;

/*****************************************************************************
*
*		CREATE CAST / DROP CAST
*
*****************************************************************************/


CreateCastStmt:

    CREATE CAST '(' Typename AS Typename ')' WITH FUNCTION function_with_argtypes cast_context {
        auto tmp1 = $4;
        auto tmp2 = $6;
        res = new IR(kCreateCastStmt_1, OP3("CREATE CAST (", "AS", ") WITH FUNCTION"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $10;
        res = new IR(kCreateCastStmt_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $11;
        res = new IR(kCreateCastStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CREATE CAST '(' Typename AS Typename ')' WITHOUT FUNCTION cast_context {
        auto tmp1 = $4;
        auto tmp2 = $6;
        res = new IR(kCreateCastStmt_3, OP3("CREATE CAST (", "AS", ") WITHOUT FUNCTION"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $10;
        res = new IR(kCreateCastStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CREATE CAST '(' Typename AS Typename ')' WITH INOUT cast_context {
        auto tmp1 = $4;
        auto tmp2 = $6;
        res = new IR(kCreateCastStmt_4, OP3("CREATE CAST (", "AS", ") WITH INOUT"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $10;
        res = new IR(kCreateCastStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


cast_context:

    AS IMPLICIT_P {
        res = new IR(kCastContext, OP3("AS IMPLICIT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | AS ASSIGNMENT {
        res = new IR(kCastContext, OP3("AS ASSIGNMENT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kCastContext, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;



DropCastStmt:

    DROP CAST opt_if_exists '(' Typename AS Typename ')' opt_drop_behavior {
        auto tmp1 = $3;
        auto tmp2 = $5;
        res = new IR(kDropCastStmt_1, OP3("DROP CAST", "(", "AS"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $7;
        res = new IR(kDropCastStmt_2, OP3("", "", ")"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $9;
        res = new IR(kDropCastStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_if_exists:

    IF_P EXISTS {
        res = new IR(kOptIfExists, OP3("IF EXISTS", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptIfExists, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
*		CREATE TRANSFORM / DROP TRANSFORM
*
*****************************************************************************/


CreateTransformStmt:

    CREATE opt_or_replace TRANSFORM FOR Typename LANGUAGE name '(' transform_element_list ')' {
        auto tmp1 = $2;
        auto tmp2 = $5;
        res = new IR(kCreateTransformStmt_1, OP3("CREATE", "TRANSFORM FOR", "LANGUAGE"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($7), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($7);
        res = new IR(kCreateTransformStmt_2, OP3("", "", "("), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $9;
        res = new IR(kCreateTransformStmt, OP3("", "", ")"), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


transform_element_list:

    FROM SQL_P WITH FUNCTION function_with_argtypes ',' TO SQL_P WITH FUNCTION function_with_argtypes {
        auto tmp1 = $5;
        auto tmp2 = $11;
        res = new IR(kTransformElementList, OP3("FROM SQL WITH FUNCTION", ", TO SQL WITH FUNCTION", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TO SQL_P WITH FUNCTION function_with_argtypes ',' FROM SQL_P WITH FUNCTION function_with_argtypes {
        auto tmp1 = $5;
        auto tmp2 = $11;
        res = new IR(kTransformElementList, OP3("TO SQL WITH FUNCTION", ", FROM SQL WITH FUNCTION", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FROM SQL_P WITH FUNCTION function_with_argtypes {
        auto tmp1 = $5;
        res = new IR(kTransformElementList, OP3("FROM SQL WITH FUNCTION", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TO SQL_P WITH FUNCTION function_with_argtypes {
        auto tmp1 = $5;
        res = new IR(kTransformElementList, OP3("TO SQL WITH FUNCTION", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;



DropTransformStmt:

    DROP TRANSFORM opt_if_exists FOR Typename LANGUAGE name opt_drop_behavior {
        auto tmp1 = $3;
        auto tmp2 = $5;
        res = new IR(kDropTransformStmt_1, OP3("DROP TRANSFORM", "FOR", "LANGUAGE"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($7), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($7);
        res = new IR(kDropTransformStmt_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $8;
        res = new IR(kDropTransformStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
*		QUERY:
*
*		REINDEX [ (options) ] type [CONCURRENTLY] <name>
*****************************************************************************/


ReindexStmt:

    REINDEX reindex_target_type opt_concurrently qualified_name {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kReindexStmt_1, OP3("REINDEX", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $4;
        res = new IR(kReindexStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;

        switch (tmp1->get_reindex_target_type()) {
        case 0: tmp3->set_qualified_name_type(kDataIndexName, kUse); break;
        case 1: tmp3->set_qualified_name_type(kDataTableName, kUse); break;
        default: break;
        }
    }

    | REINDEX reindex_target_multitable opt_concurrently name {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kReindexStmt_2, OP3("REINDEX", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($4), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($4);
        res = new IR(kReindexStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;

        switch (tmp1->get_reindex_target_type()) {
            case 2: tmp3->set_iden_type(kDataSchemaName, kUse); break;
            case 3: tmp3->set_iden_type(kDataSystemName, kUse); break;
            case 4: tmp3->set_iden_type(kDataDatabaseName, kUse); break;
            default: break;
        }
    }

    | REINDEX '(' utility_option_list ')' reindex_target_type opt_concurrently qualified_name {
        auto tmp1 = $3;
        auto tmp2 = $5;
        res = new IR(kReindexStmt_3, OP3("REINDEX (", ")", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kReindexStmt_4, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $7;
        res = new IR(kReindexStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
        
        switch (tmp2->get_reindex_target_type()) {
            case 0: tmp4->set_qualified_name_type(kDataIndexName, kUse); break;
            case 1: tmp4->set_qualified_name_type(kDataTableName, kUse); break;
            default: break;
        }
    }

    | REINDEX '(' utility_option_list ')' reindex_target_multitable opt_concurrently name {
        auto tmp1 = $3;
        auto tmp2 = $5;
        res = new IR(kReindexStmt_5, OP3("REINDEX (", ")", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kReindexStmt_6, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = new IR(kIdentifier, string($7), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp4 );
        free($7);
        res = new IR(kReindexStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;

        switch (tmp2->get_reindex_target_type()) {
            case 2: tmp4->set_iden_type(kDataSchemaName, kUse); break;
            case 3: tmp4->set_iden_type(kDataSystemName, kUse); break;
            case 4: tmp4->set_iden_type(kDataDatabaseName, kUse); break;
            default: break;
        }
    }

;

reindex_target_type:

    INDEX {
        res = new IR(kReindexTargetType, OP3("INDEX", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TABLE {
        res = new IR(kReindexTargetType, OP3("TABLE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

reindex_target_multitable:

    SCHEMA {
        res = new IR(kReindexTargetMultitable, OP3("SCHEMA", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SYSTEM_P {
        res = new IR(kReindexTargetMultitable, OP3("SYSTEM", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DATABASE {
        res = new IR(kReindexTargetMultitable, OP3("DATABASE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
* ALTER TABLESPACE
*
*****************************************************************************/


AlterTblSpcStmt:

    ALTER TABLESPACE name SET reloptions {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $5;
        res = new IR(kAlterTblSpcStmt, OP3("ALTER TABLESPACE", "SET", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER TABLESPACE name RESET reloptions {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $5;
        res = new IR(kAlterTblSpcStmt, OP3("ALTER TABLESPACE", "RESET", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
* ALTER THING name RENAME TO newname
*
*****************************************************************************/


RenameStmt:

    ALTER AGGREGATE aggregate_with_argtypes RENAME TO name {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kRenameStmt, OP3("ALTER AGGREGATE", "RENAME TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER COLLATION any_name RENAME TO name {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kRenameStmt, OP3("ALTER COLLATION", "RENAME TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER CONVERSION_P any_name RENAME TO name {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kRenameStmt, OP3("ALTER CONVERSION", "RENAME TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER DATABASE name RENAME TO name {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kRenameStmt, OP3("ALTER DATABASE", "RENAME TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER DOMAIN_P any_name RENAME TO name {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kRenameStmt, OP3("ALTER DOMAIN", "RENAME TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER DOMAIN_P any_name RENAME CONSTRAINT name TO name {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kRenameStmt_1, OP3("ALTER DOMAIN", "RENAME CONSTRAINT", "TO"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($8);
        res = new IR(kRenameStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER FOREIGN DATA_P WRAPPER name RENAME TO name {
        auto tmp1 = new IR(kIdentifier, string($5), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($5);
        auto tmp2 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($8);
        res = new IR(kRenameStmt, OP3("ALTER FOREIGN DATA WRAPPER", "RENAME TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER FUNCTION function_with_argtypes RENAME TO name {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kRenameStmt, OP3("ALTER FUNCTION", "RENAME TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER GROUP_P RoleId RENAME TO RoleId {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kRenameStmt, OP3("ALTER GROUP", "RENAME TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_iden_type(kDataRoleName, kUndefine);
        tmp2->set_iden_type(kDataRoleName, kDefine);
    }

    | ALTER opt_procedural LANGUAGE name RENAME TO name {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($4), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($4);
        res = new IR(kRenameStmt_2, OP3("ALTER", "LANGUAGE", "RENAME TO"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($7), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($7);
        res = new IR(kRenameStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER OPERATOR CLASS any_name USING name RENAME TO name {
        auto tmp1 = $4;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kRenameStmt_3, OP3("ALTER OPERATOR CLASS", "USING", "RENAME TO"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($9), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($9);
        res = new IR(kRenameStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER OPERATOR FAMILY any_name USING name RENAME TO name {
        auto tmp1 = $4;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kRenameStmt_4, OP3("ALTER OPERATOR FAMILY", "USING", "RENAME TO"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($9), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($9);
        res = new IR(kRenameStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER POLICY name ON qualified_name RENAME TO name {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $5;
        res = new IR(kRenameStmt_5, OP3("ALTER POLICY", "ON", "RENAME TO"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($8);
        res = new IR(kRenameStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER POLICY IF_P EXISTS name ON qualified_name RENAME TO name {
        auto tmp1 = new IR(kIdentifier, string($5), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($5);
        auto tmp2 = $7;
        res = new IR(kRenameStmt_6, OP3("ALTER POLICY IF EXISTS", "ON", "RENAME TO"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($10), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($10);
        res = new IR(kRenameStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER PROCEDURE function_with_argtypes RENAME TO name {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kRenameStmt, OP3("ALTER PROCEDURE", "RENAME TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER PUBLICATION name RENAME TO name {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kRenameStmt, OP3("ALTER PUBLICATION", "RENAME TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER ROUTINE function_with_argtypes RENAME TO name {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kRenameStmt, OP3("ALTER ROUTINE", "RENAME TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER SCHEMA name RENAME TO name {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kRenameStmt, OP3("ALTER SCHEMA", "RENAME TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER SERVER name RENAME TO name {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kRenameStmt, OP3("ALTER SERVER", "RENAME TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER SUBSCRIPTION name RENAME TO name {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kRenameStmt, OP3("ALTER SUBSCRIPTION", "RENAME TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER TABLE relation_expr RENAME TO name {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kRenameStmt, OP3("ALTER TABLE", "RENAME TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1 -> set_relation_expr_type(kDataTableName, kUndefine);
        tmp2 -> set_iden_type(kDataTableName, kDefine);

    }

    | ALTER TABLE IF_P EXISTS relation_expr RENAME TO name {
        auto tmp1 = $5;
        auto tmp2 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($8);
        res = new IR(kRenameStmt, OP3("ALTER TABLE IF EXISTS", "RENAME TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1 -> set_relation_expr_type(kDataTableName, kUndefine);
        tmp2 -> set_iden_type(kDataTableName, kDefine);

    }

    | ALTER SEQUENCE qualified_name RENAME TO name {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kRenameStmt, OP3("ALTER SEQUENCE", "RENAME TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1 -> set_qualified_name_type(kDataSequenceName, kUndefine);
        tmp2 -> set_iden_type(kDataSequenceName, kDefine);
    }

    | ALTER SEQUENCE IF_P EXISTS qualified_name RENAME TO name {
        auto tmp1 = $5;
        auto tmp2 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($8);
        res = new IR(kRenameStmt, OP3("ALTER SEQUENCE IF EXISTS", "RENAME TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1 -> set_qualified_name_type(kDataSequenceName, kUndefine);
        tmp2 -> set_iden_type(kDataSequenceName, kDefine);

    }

    | ALTER VIEW qualified_name RENAME TO name {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kRenameStmt, OP3("ALTER VIEW", "RENAME TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_qualified_name_type(kDataViewName, kUndefine);
        tmp2->set_iden_type(kDataViewName, kDefine);
    }

    | ALTER VIEW IF_P EXISTS qualified_name RENAME TO name {
        auto tmp1 = $5;
        auto tmp2 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($8);
        res = new IR(kRenameStmt, OP3("ALTER VIEW IF EXISTS", "RENAME TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_qualified_name_type(kDataViewName, kUndefine);
        tmp2->set_iden_type(kDataViewName, kDefine);
    }

    | ALTER MATERIALIZED VIEW qualified_name RENAME TO name {
        auto tmp1 = $4;
        auto tmp2 = new IR(kIdentifier, string($7), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($7);
        res = new IR(kRenameStmt, OP3("ALTER MATERIALIZED VIEW", "RENAME TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER MATERIALIZED VIEW IF_P EXISTS qualified_name RENAME TO name {
        auto tmp1 = $6;
        auto tmp2 = new IR(kIdentifier, string($9), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($9);
        res = new IR(kRenameStmt, OP3("ALTER MATERIALIZED VIEW IF EXISTS", "RENAME TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER INDEX qualified_name RENAME TO name {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kRenameStmt, OP3("ALTER INDEX", "RENAME TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_qualified_name_type(kDataIndexName, kUndefine);
        tmp2->set_iden_type(kDataIndexName, kDefine);
    }

    | ALTER INDEX IF_P EXISTS qualified_name RENAME TO name {
        auto tmp1 = $5;
        auto tmp2 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($8);
        res = new IR(kRenameStmt, OP3("ALTER INDEX IF EXISTS", "RENAME TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_qualified_name_type(kDataIndexName, kUndefine);
        tmp2->set_iden_type(kDataIndexName, kDefine);
    }

    | ALTER FOREIGN TABLE relation_expr RENAME TO name {
        auto tmp1 = $4;
        auto tmp2 = new IR(kIdentifier, string($7), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($7);
        res = new IR(kRenameStmt, OP3("ALTER FOREIGN TABLE", "RENAME TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1 -> set_relation_expr_type(kDataForeignTableName, kUndefine);
        tmp2 -> set_iden_type(kDataForeignTableName, kDefine);

    }

    | ALTER FOREIGN TABLE IF_P EXISTS relation_expr RENAME TO name {
        auto tmp1 = $6;
        auto tmp2 = new IR(kIdentifier, string($9), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($9);
        res = new IR(kRenameStmt, OP3("ALTER FOREIGN TABLE IF EXISTS", "RENAME TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1 -> set_relation_expr_type(kDataForeignTableName, kUndefine);
        tmp2 -> set_iden_type(kDataForeignTableName, kDefine);

    }

    | ALTER TABLE relation_expr RENAME opt_column name TO name {
        auto tmp1 = $3;
        auto tmp2 = $5;
        res = new IR(kRenameStmt_7, OP3("ALTER TABLE", "RENAME", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($6);
        res = new IR(kRenameStmt_8, OP3("", "", "TO"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp4 );
        free($8);
        res = new IR(kRenameStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp3 -> set_iden_type(kDataColumnName, kUndefine);
        tmp4 -> set_iden_type(kDataColumnName, kDefine);

    }

    | ALTER TABLE IF_P EXISTS relation_expr RENAME opt_column name TO name {
        auto tmp1 = $5;
        auto tmp2 = $7;
        res = new IR(kRenameStmt_9, OP3("ALTER TABLE IF EXISTS", "RENAME", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($8);
        res = new IR(kRenameStmt_10, OP3("", "", "TO"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = new IR(kIdentifier, string($10), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp4 );
        free($10);
        res = new IR(kRenameStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp3 -> set_iden_type(kDataColumnName, kUndefine);
        tmp4 -> set_iden_type(kDataColumnName, kDefine);
    }

    | ALTER VIEW qualified_name RENAME opt_column name TO name {
        auto tmp1 = $3;
        auto tmp2 = $5;
        res = new IR(kRenameStmt_11, OP3("ALTER VIEW", "RENAME", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($6);
        res = new IR(kRenameStmt_12, OP3("", "", "TO"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp4 );
        free($8);
        res = new IR(kRenameStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_qualified_name_type(kDataViewName, kUse);
        tmp3->set_iden_type(kDataColumnName, kUndefine);
        tmp4->set_iden_type(kDataColumnName, kDefine);
    }

    | ALTER VIEW IF_P EXISTS qualified_name RENAME opt_column name TO name {
        auto tmp1 = $5;
        auto tmp2 = $7;
        res = new IR(kRenameStmt_13, OP3("ALTER VIEW IF EXISTS", "RENAME", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($8);
        res = new IR(kRenameStmt_14, OP3("", "", "TO"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = new IR(kIdentifier, string($10), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp4 );
        free($10);
        res = new IR(kRenameStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_qualified_name_type(kDataViewName, kUse);
        tmp3->set_iden_type(kDataColumnName, kUndefine);
        tmp4->set_iden_type(kDataColumnName, kDefine);
    }

    | ALTER MATERIALIZED VIEW qualified_name RENAME opt_column name TO name {
        auto tmp1 = $4;
        auto tmp2 = $6;
        res = new IR(kRenameStmt_15, OP3("ALTER MATERIALIZED VIEW", "RENAME", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($7), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($7);
        res = new IR(kRenameStmt_16, OP3("", "", "TO"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = new IR(kIdentifier, string($9), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp4 );
        free($9);
        res = new IR(kRenameStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_qualified_name_type(kDataViewName, kUse);
        tmp3->set_iden_type(kDataColumnName, kUndefine);
        tmp4->set_iden_type(kDataColumnName, kDefine);

    }

    | ALTER MATERIALIZED VIEW IF_P EXISTS qualified_name RENAME opt_column name TO name {
        auto tmp1 = $6;
        auto tmp2 = $8;
        res = new IR(kRenameStmt_17, OP3("ALTER MATERIALIZED VIEW IF EXISTS", "RENAME", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($9), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($9);
        res = new IR(kRenameStmt_18, OP3("", "", "TO"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = new IR(kIdentifier, string($11), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp4 );
        free($11);
        res = new IR(kRenameStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_qualified_name_type(kDataViewName, kUse);
        tmp3->set_iden_type(kDataColumnName, kUndefine);
        tmp4->set_iden_type(kDataColumnName, kDefine);

    }

    | ALTER TABLE relation_expr RENAME CONSTRAINT name TO name {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kRenameStmt_19, OP3("ALTER TABLE", "RENAME CONSTRAINT", "TO"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($8);
        res = new IR(kRenameStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_relation_expr_type(kDataTableName, kUse);
        tmp2->set_iden_type(kDataConstraintName, kUndefine);
        tmp3->set_iden_type(kDataConstraintName, kDefine);
    }

    | ALTER TABLE IF_P EXISTS relation_expr RENAME CONSTRAINT name TO name {
        auto tmp1 = $5;
        auto tmp2 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($8);
        res = new IR(kRenameStmt_20, OP3("ALTER TABLE IF EXISTS", "RENAME CONSTRAINT", "TO"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($10), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($10);
        res = new IR(kRenameStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_relation_expr_type(kDataTableName, kUse);
        tmp2->set_iden_type(kDataConstraintName, kUndefine);
        tmp3->set_iden_type(kDataConstraintName, kDefine);
    }

    | ALTER FOREIGN TABLE relation_expr RENAME opt_column name TO name {
        auto tmp1 = $4;
        auto tmp2 = $6;
        res = new IR(kRenameStmt_21, OP3("ALTER FOREIGN TABLE", "RENAME", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($7), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($7);
        res = new IR(kRenameStmt_22, OP3("", "", "TO"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = new IR(kIdentifier, string($9), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp4 );
        free($9);
        res = new IR(kRenameStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp3->set_iden_type(kDataColumnName, kUndefine);
        tmp4->set_iden_type(kDataColumnName, kDefine);
    }

    | ALTER FOREIGN TABLE IF_P EXISTS relation_expr RENAME opt_column name TO name {
        auto tmp1 = $6;
        auto tmp2 = $8;
        res = new IR(kRenameStmt_23, OP3("ALTER FOREIGN TABLE IF EXISTS", "RENAME", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($9), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($9);
        res = new IR(kRenameStmt_24, OP3("", "", "TO"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = new IR(kIdentifier, string($11), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp4 );
        free($11);
        res = new IR(kRenameStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp3->set_iden_type(kDataColumnName, kUndefine);
        tmp4->set_iden_type(kDataColumnName, kDefine);

    }

    | ALTER RULE name ON qualified_name RENAME TO name {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $5;
        res = new IR(kRenameStmt_25, OP3("ALTER RULE", "ON", "RENAME TO"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($8);
        res = new IR(kRenameStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER TRIGGER name ON qualified_name RENAME TO name {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $5;
        res = new IR(kRenameStmt_26, OP3("ALTER TRIGGER", "ON", "RENAME TO"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($8);
        res = new IR(kRenameStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER EVENT TRIGGER name RENAME TO name {
        auto tmp1 = new IR(kIdentifier, string($4), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($4);
        auto tmp2 = new IR(kIdentifier, string($7), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($7);
        res = new IR(kRenameStmt, OP3("ALTER EVENT TRIGGER", "RENAME TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER ROLE RoleId RENAME TO RoleId {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kRenameStmt, OP3("ALTER ROLE", "RENAME TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER USER RoleId RENAME TO RoleId {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kRenameStmt, OP3("ALTER USER", "RENAME TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER TABLESPACE name RENAME TO name {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kRenameStmt, OP3("ALTER TABLESPACE", "RENAME TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER STATISTICS any_name RENAME TO name {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kRenameStmt, OP3("ALTER STATISTICS", "RENAME TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER TEXT_P SEARCH PARSER any_name RENAME TO name {
        auto tmp1 = $5;
        auto tmp2 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($8);
        res = new IR(kRenameStmt, OP3("ALTER TEXT SEARCH PARSER", "RENAME TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER TEXT_P SEARCH DICTIONARY any_name RENAME TO name {
        auto tmp1 = $5;
        auto tmp2 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($8);
        res = new IR(kRenameStmt, OP3("ALTER TEXT SEARCH DICTIONARY", "RENAME TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER TEXT_P SEARCH TEMPLATE any_name RENAME TO name {
        auto tmp1 = $5;
        auto tmp2 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($8);
        res = new IR(kRenameStmt, OP3("ALTER TEXT SEARCH TEMPLATE", "RENAME TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER TEXT_P SEARCH CONFIGURATION any_name RENAME TO name {
        auto tmp1 = $5;
        auto tmp2 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($8);
        res = new IR(kRenameStmt, OP3("ALTER TEXT SEARCH CONFIGURATION", "RENAME TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER TYPE_P any_name RENAME TO name {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kRenameStmt, OP3("ALTER TYPE", "RENAME TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER TYPE_P any_name RENAME ATTRIBUTE name TO name opt_drop_behavior {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kRenameStmt_27, OP3("ALTER TYPE", "RENAME ATTRIBUTE", "TO"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($8);
        res = new IR(kRenameStmt_28, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $9;
        res = new IR(kRenameStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_column:

    COLUMN {
        res = new IR(kOptColumn, OP3("COLUMN", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptColumn, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_set_data:

    SET DATA_P {
        res = new IR(kOptSetData, OP3("SET DATA", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptSetData, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
* ALTER THING name DEPENDS ON EXTENSION name
*
*****************************************************************************/


AlterObjectDependsStmt:

    ALTER FUNCTION function_with_argtypes opt_no DEPENDS ON EXTENSION name {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kAlterObjectDependsStmt_1, OP3("ALTER FUNCTION", "", "DEPENDS ON EXTENSION"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($8);
        res = new IR(kAlterObjectDependsStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER PROCEDURE function_with_argtypes opt_no DEPENDS ON EXTENSION name {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kAlterObjectDependsStmt_2, OP3("ALTER PROCEDURE", "", "DEPENDS ON EXTENSION"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($8);
        res = new IR(kAlterObjectDependsStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER ROUTINE function_with_argtypes opt_no DEPENDS ON EXTENSION name {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kAlterObjectDependsStmt_3, OP3("ALTER ROUTINE", "", "DEPENDS ON EXTENSION"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($8);
        res = new IR(kAlterObjectDependsStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER TRIGGER name ON qualified_name opt_no DEPENDS ON EXTENSION name {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $5;
        res = new IR(kAlterObjectDependsStmt_4, OP3("ALTER TRIGGER", "ON", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kAlterObjectDependsStmt_5, OP3("", "", "DEPENDS ON EXTENSION"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = new IR(kIdentifier, string($10), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp4 );
        free($10);
        res = new IR(kAlterObjectDependsStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER MATERIALIZED VIEW qualified_name opt_no DEPENDS ON EXTENSION name {
        auto tmp1 = $4;
        auto tmp2 = $5;
        res = new IR(kAlterObjectDependsStmt_6, OP3("ALTER MATERIALIZED VIEW", "", "DEPENDS ON EXTENSION"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($9), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($9);
        res = new IR(kAlterObjectDependsStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER INDEX qualified_name opt_no DEPENDS ON EXTENSION name {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kAlterObjectDependsStmt_7, OP3("ALTER INDEX", "", "DEPENDS ON EXTENSION"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($8);
        res = new IR(kAlterObjectDependsStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_qualified_name_type(kDataIndexName, kUse);
        tmp3->set_iden_type(kDataExtensionName, kUse);
    }

;


opt_no:

    NO {
        res = new IR(kOptNo, OP3("NO", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kOptNo, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
* ALTER THING name SET SCHEMA name
*
*****************************************************************************/


AlterObjectSchemaStmt:

    ALTER AGGREGATE aggregate_with_argtypes SET SCHEMA name {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterObjectSchemaStmt, OP3("ALTER AGGREGATE", "SET SCHEMA", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER COLLATION any_name SET SCHEMA name {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterObjectSchemaStmt, OP3("ALTER COLLATION", "SET SCHEMA", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER CONVERSION_P any_name SET SCHEMA name {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterObjectSchemaStmt, OP3("ALTER CONVERSION", "SET SCHEMA", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER DOMAIN_P any_name SET SCHEMA name {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterObjectSchemaStmt, OP3("ALTER DOMAIN", "SET SCHEMA", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER EXTENSION name SET SCHEMA name {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterObjectSchemaStmt, OP3("ALTER EXTENSION", "SET SCHEMA", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER FUNCTION function_with_argtypes SET SCHEMA name {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterObjectSchemaStmt, OP3("ALTER FUNCTION", "SET SCHEMA", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER OPERATOR operator_with_argtypes SET SCHEMA name {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterObjectSchemaStmt, OP3("ALTER OPERATOR", "SET SCHEMA", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER OPERATOR CLASS any_name USING name SET SCHEMA name {
        auto tmp1 = $4;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterObjectSchemaStmt_1, OP3("ALTER OPERATOR CLASS", "USING", "SET SCHEMA"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($9), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($9);
        res = new IR(kAlterObjectSchemaStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER OPERATOR FAMILY any_name USING name SET SCHEMA name {
        auto tmp1 = $4;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterObjectSchemaStmt_2, OP3("ALTER OPERATOR FAMILY", "USING", "SET SCHEMA"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($9), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($9);
        res = new IR(kAlterObjectSchemaStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER PROCEDURE function_with_argtypes SET SCHEMA name {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterObjectSchemaStmt, OP3("ALTER PROCEDURE", "SET SCHEMA", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER ROUTINE function_with_argtypes SET SCHEMA name {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterObjectSchemaStmt, OP3("ALTER ROUTINE", "SET SCHEMA", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER TABLE relation_expr SET SCHEMA name {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterObjectSchemaStmt, OP3("ALTER TABLE", "SET SCHEMA", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER TABLE IF_P EXISTS relation_expr SET SCHEMA name {
        auto tmp1 = $5;
        auto tmp2 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($8);
        res = new IR(kAlterObjectSchemaStmt, OP3("ALTER TABLE IF EXISTS", "SET SCHEMA", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER STATISTICS any_name SET SCHEMA name {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterObjectSchemaStmt, OP3("ALTER STATISTICS", "SET SCHEMA", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER TEXT_P SEARCH PARSER any_name SET SCHEMA name {
        auto tmp1 = $5;
        auto tmp2 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($8);
        res = new IR(kAlterObjectSchemaStmt, OP3("ALTER TEXT SEARCH PARSER", "SET SCHEMA", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER TEXT_P SEARCH DICTIONARY any_name SET SCHEMA name {
        auto tmp1 = $5;
        auto tmp2 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($8);
        res = new IR(kAlterObjectSchemaStmt, OP3("ALTER TEXT SEARCH DICTIONARY", "SET SCHEMA", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER TEXT_P SEARCH TEMPLATE any_name SET SCHEMA name {
        auto tmp1 = $5;
        auto tmp2 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($8);
        res = new IR(kAlterObjectSchemaStmt, OP3("ALTER TEXT SEARCH TEMPLATE", "SET SCHEMA", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER TEXT_P SEARCH CONFIGURATION any_name SET SCHEMA name {
        auto tmp1 = $5;
        auto tmp2 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($8);
        res = new IR(kAlterObjectSchemaStmt, OP3("ALTER TEXT SEARCH CONFIGURATION", "SET SCHEMA", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER SEQUENCE qualified_name SET SCHEMA name {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterObjectSchemaStmt, OP3("ALTER SEQUENCE", "SET SCHEMA", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER SEQUENCE IF_P EXISTS qualified_name SET SCHEMA name {
        auto tmp1 = $5;
        auto tmp2 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($8);
        res = new IR(kAlterObjectSchemaStmt, OP3("ALTER SEQUENCE IF EXISTS", "SET SCHEMA", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER VIEW qualified_name SET SCHEMA name {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterObjectSchemaStmt, OP3("ALTER VIEW", "SET SCHEMA", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_qualified_name_type(kDataViewName, kUse);
        tmp2->set_iden_type(kDataSchemaName, kUse);
    }

    | ALTER VIEW IF_P EXISTS qualified_name SET SCHEMA name {
        auto tmp1 = $5;
        auto tmp2 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($8);
        res = new IR(kAlterObjectSchemaStmt, OP3("ALTER VIEW IF EXISTS", "SET SCHEMA", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_qualified_name_type(kDataViewName, kUse);
        tmp2->set_iden_type(kDataSchemaName, kUse);
    }

    | ALTER MATERIALIZED VIEW qualified_name SET SCHEMA name {
        auto tmp1 = $4;
        auto tmp2 = new IR(kIdentifier, string($7), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($7);
        res = new IR(kAlterObjectSchemaStmt, OP3("ALTER MATERIALIZED VIEW", "SET SCHEMA", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER MATERIALIZED VIEW IF_P EXISTS qualified_name SET SCHEMA name {
        auto tmp1 = $6;
        auto tmp2 = new IR(kIdentifier, string($9), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($9);
        res = new IR(kAlterObjectSchemaStmt, OP3("ALTER MATERIALIZED VIEW IF EXISTS", "SET SCHEMA", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER FOREIGN TABLE relation_expr SET SCHEMA name {
        auto tmp1 = $4;
        auto tmp2 = new IR(kIdentifier, string($7), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($7);
        res = new IR(kAlterObjectSchemaStmt, OP3("ALTER FOREIGN TABLE", "SET SCHEMA", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER FOREIGN TABLE IF_P EXISTS relation_expr SET SCHEMA name {
        auto tmp1 = $6;
        auto tmp2 = new IR(kIdentifier, string($9), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($9);
        res = new IR(kAlterObjectSchemaStmt, OP3("ALTER FOREIGN TABLE IF EXISTS", "SET SCHEMA", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER TYPE_P any_name SET SCHEMA name {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterObjectSchemaStmt, OP3("ALTER TYPE", "SET SCHEMA", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
* ALTER OPERATOR name SET define
*
*****************************************************************************/


AlterOperatorStmt:

    ALTER OPERATOR operator_with_argtypes SET '(' operator_def_list ')' {
        auto tmp1 = $3;
        auto tmp2 = $6;
        res = new IR(kAlterOperatorStmt, OP3("ALTER OPERATOR", "SET (", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


operator_def_list:

    operator_def_elem {
        auto tmp1 = $1;
        res = new IR(kOperatorDefList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | operator_def_list ',' operator_def_elem {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kOperatorDefList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


operator_def_elem:

    ColLabel '=' NONE {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kOperatorDefElem, OP3("", "= NONE", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ColLabel '=' operator_def_arg {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = $3;
        res = new IR(kOperatorDefElem, OP3("", "=", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/* must be similar enough to def_arg to avoid reduce/reduce conflicts */

operator_def_arg:

    func_type {
        auto tmp1 = $1;
        res = new IR(kOperatorDefArg, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | reserved_keyword {
        /* This is a specitial use, we are using a read-only char to initialize the string! */
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        res = new IR(kOperatorDefArg, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | qual_all_Op {
        auto tmp1 = $1;
        res = new IR(kOperatorDefArg, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NumericOnly {
        auto tmp1 = $1;
        res = new IR(kOperatorDefArg, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | Sconst {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kOperatorDefArg, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
* ALTER TYPE name SET define
*
* We repurpose ALTER OPERATOR's version of "definition" here
*
*****************************************************************************/


AlterTypeStmt:

    ALTER TYPE_P any_name SET '(' operator_def_list ')' {
        auto tmp1 = $3;
        auto tmp2 = $6;
        res = new IR(kAlterTypeStmt, OP3("ALTER TYPE", "SET (", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
* ALTER THING name OWNER TO newname
*
*****************************************************************************/


AlterOwnerStmt:

    ALTER AGGREGATE aggregate_with_argtypes OWNER TO RoleSpec {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterOwnerStmt, OP3("ALTER AGGREGATE", "OWNER TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER COLLATION any_name OWNER TO RoleSpec {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterOwnerStmt, OP3("ALTER COLLATION", "OWNER TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER CONVERSION_P any_name OWNER TO RoleSpec {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterOwnerStmt, OP3("ALTER CONVERSION", "OWNER TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER DATABASE name OWNER TO RoleSpec {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterOwnerStmt, OP3("ALTER DATABASE", "OWNER TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER DOMAIN_P any_name OWNER TO RoleSpec {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterOwnerStmt, OP3("ALTER DOMAIN", "OWNER TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER FUNCTION function_with_argtypes OWNER TO RoleSpec {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterOwnerStmt, OP3("ALTER FUNCTION", "OWNER TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER opt_procedural LANGUAGE name OWNER TO RoleSpec {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($4), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($4);
        res = new IR(kAlterOwnerStmt_1, OP3("ALTER", "LANGUAGE", "OWNER TO"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($7), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($7);
        res = new IR(kAlterOwnerStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER LARGE_P OBJECT_P NumericOnly OWNER TO RoleSpec {
        auto tmp1 = $4;
        auto tmp2 = new IR(kIdentifier, string($7), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($7);
        res = new IR(kAlterOwnerStmt, OP3("ALTER LARGE OBJECT", "OWNER TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER OPERATOR operator_with_argtypes OWNER TO RoleSpec {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterOwnerStmt, OP3("ALTER OPERATOR", "OWNER TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER OPERATOR CLASS any_name USING name OWNER TO RoleSpec {
        auto tmp1 = $4;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterOwnerStmt_2, OP3("ALTER OPERATOR CLASS", "USING", "OWNER TO"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($9), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($9);
        res = new IR(kAlterOwnerStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER OPERATOR FAMILY any_name USING name OWNER TO RoleSpec {
        auto tmp1 = $4;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterOwnerStmt_3, OP3("ALTER OPERATOR FAMILY", "USING", "OWNER TO"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($9), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($9);
        res = new IR(kAlterOwnerStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER PROCEDURE function_with_argtypes OWNER TO RoleSpec {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterOwnerStmt, OP3("ALTER PROCEDURE", "OWNER TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER ROUTINE function_with_argtypes OWNER TO RoleSpec {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterOwnerStmt, OP3("ALTER ROUTINE", "OWNER TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER SCHEMA name OWNER TO RoleSpec {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterOwnerStmt, OP3("ALTER SCHEMA", "OWNER TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER TYPE_P any_name OWNER TO RoleSpec {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterOwnerStmt, OP3("ALTER TYPE", "OWNER TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER TABLESPACE name OWNER TO RoleSpec {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterOwnerStmt, OP3("ALTER TABLESPACE", "OWNER TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER STATISTICS any_name OWNER TO RoleSpec {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterOwnerStmt, OP3("ALTER STATISTICS", "OWNER TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER TEXT_P SEARCH DICTIONARY any_name OWNER TO RoleSpec {
        auto tmp1 = $5;
        auto tmp2 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($8);
        res = new IR(kAlterOwnerStmt, OP3("ALTER TEXT SEARCH DICTIONARY", "OWNER TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER TEXT_P SEARCH CONFIGURATION any_name OWNER TO RoleSpec {
        auto tmp1 = $5;
        auto tmp2 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($8);
        res = new IR(kAlterOwnerStmt, OP3("ALTER TEXT SEARCH CONFIGURATION", "OWNER TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER FOREIGN DATA_P WRAPPER name OWNER TO RoleSpec {
        auto tmp1 = new IR(kIdentifier, string($5), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($5);
        auto tmp2 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($8);
        res = new IR(kAlterOwnerStmt, OP3("ALTER FOREIGN DATA WRAPPER", "OWNER TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER SERVER name OWNER TO RoleSpec {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterOwnerStmt, OP3("ALTER SERVER", "OWNER TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER EVENT TRIGGER name OWNER TO RoleSpec {
        auto tmp1 = new IR(kIdentifier, string($4), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($4);
        auto tmp2 = new IR(kIdentifier, string($7), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($7);
        res = new IR(kAlterOwnerStmt, OP3("ALTER EVENT TRIGGER", "OWNER TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER PUBLICATION name OWNER TO RoleSpec {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterOwnerStmt, OP3("ALTER PUBLICATION", "OWNER TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER SUBSCRIPTION name OWNER TO RoleSpec {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterOwnerStmt, OP3("ALTER SUBSCRIPTION", "OWNER TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
* CREATE PUBLICATION name [ FOR TABLE ] [ WITH options ]
*
*****************************************************************************/


CreatePublicationStmt:

    CREATE PUBLICATION name opt_publication_for_tables opt_definition {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $4;
        res = new IR(kCreatePublicationStmt_1, OP3("CREATE PUBLICATION", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kCreatePublicationStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_publication_for_tables:

    publication_for_tables {
        auto tmp1 = $1;
        res = new IR(kOptPublicationForTables, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kOptPublicationForTables, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


publication_for_tables:

    FOR TABLE relation_expr_list {
        auto tmp1 = $3;
        res = new IR(kPublicationForTables, OP3("FOR TABLE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FOR ALL TABLES {
        res = new IR(kPublicationForTables, OP3("FOR ALL TABLES", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
* ALTER PUBLICATION name SET ( options )
*
* ALTER PUBLICATION name ADD TABLE table [, table2]
*
* ALTER PUBLICATION name DROP TABLE table [, table2]
*
* ALTER PUBLICATION name SET TABLE table [, table2]
*
*****************************************************************************/


AlterPublicationStmt:

    ALTER PUBLICATION name SET definition {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $5;
        res = new IR(kAlterPublicationStmt, OP3("ALTER PUBLICATION", "SET", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER PUBLICATION name ADD_P TABLE relation_expr_list {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $6;
        res = new IR(kAlterPublicationStmt, OP3("ALTER PUBLICATION", "ADD TABLE", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER PUBLICATION name SET TABLE relation_expr_list {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $6;
        res = new IR(kAlterPublicationStmt, OP3("ALTER PUBLICATION", "SET TABLE", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER PUBLICATION name DROP TABLE relation_expr_list {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $6;
        res = new IR(kAlterPublicationStmt, OP3("ALTER PUBLICATION", "DROP TABLE", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
* CREATE SUBSCRIPTION name ...
*
*****************************************************************************/


CreateSubscriptionStmt:

    CREATE SUBSCRIPTION name CONNECTION Sconst PUBLICATION name_list opt_definition {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = new IR(kIdentifier, string($5), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($5);
        res = new IR(kCreateSubscriptionStmt_1, OP3("CREATE SUBSCRIPTION", "CONNECTION", "PUBLICATION"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $7;
        res = new IR(kCreateSubscriptionStmt_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $8;
        res = new IR(kCreateSubscriptionStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
* ALTER SUBSCRIPTION name ...
*
*****************************************************************************/


AlterSubscriptionStmt:

    ALTER SUBSCRIPTION name SET definition {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $5;
        res = new IR(kAlterSubscriptionStmt, OP3("ALTER SUBSCRIPTION", "SET", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER SUBSCRIPTION name CONNECTION Sconst {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = new IR(kIdentifier, string($5), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($5);
        res = new IR(kAlterSubscriptionStmt, OP3("ALTER SUBSCRIPTION", "CONNECTION", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER SUBSCRIPTION name REFRESH PUBLICATION opt_definition {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $6;
        res = new IR(kAlterSubscriptionStmt, OP3("ALTER SUBSCRIPTION", "REFRESH PUBLICATION", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER SUBSCRIPTION name ADD_P PUBLICATION name_list opt_definition {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $6;
        res = new IR(kAlterSubscriptionStmt_1, OP3("ALTER SUBSCRIPTION", "ADD PUBLICATION", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $7;
        res = new IR(kAlterSubscriptionStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER SUBSCRIPTION name DROP PUBLICATION name_list opt_definition {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $6;
        res = new IR(kAlterSubscriptionStmt_2, OP3("ALTER SUBSCRIPTION", "DROP PUBLICATION", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $7;
        res = new IR(kAlterSubscriptionStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER SUBSCRIPTION name SET PUBLICATION name_list opt_definition {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $6;
        res = new IR(kAlterSubscriptionStmt_3, OP3("ALTER SUBSCRIPTION", "SET PUBLICATION", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $7;
        res = new IR(kAlterSubscriptionStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER SUBSCRIPTION name ENABLE_P {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        res = new IR(kAlterSubscriptionStmt, OP3("ALTER SUBSCRIPTION", "ENABLE", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER SUBSCRIPTION name DISABLE_P {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        res = new IR(kAlterSubscriptionStmt, OP3("ALTER SUBSCRIPTION", "DISABLE", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
* DROP SUBSCRIPTION [ IF EXISTS ] name
*
*****************************************************************************/


DropSubscriptionStmt:

    DROP SUBSCRIPTION name opt_drop_behavior {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $4;
        res = new IR(kDropSubscriptionStmt, OP3("DROP SUBSCRIPTION", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DROP SUBSCRIPTION IF_P EXISTS name opt_drop_behavior {
        auto tmp1 = new IR(kIdentifier, string($5), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($5);
        auto tmp2 = $6;
        res = new IR(kDropSubscriptionStmt, OP3("DROP SUBSCRIPTION IF EXISTS", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
*		QUERY:	Define Rewrite Rule
*
*****************************************************************************/


RuleStmt:

    CREATE opt_or_replace RULE name AS ON event TO qualified_name where_clause DO opt_instead RuleActionList {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($4), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($4);
        res = new IR(kRuleStmt_1, OP3("CREATE", "RULE", "AS ON"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $7;
        res = new IR(kRuleStmt_2, OP3("", "", "TO"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $9;
        res = new IR(kRuleStmt_3, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $10;
        res = new IR(kRuleStmt_4, OP3("", "", "DO"), res, tmp5);
        all_gen_ir.push_back(res);
        auto tmp6 = $12;
        res = new IR(kRuleStmt_5, OP3("", "", ""), res, tmp6);
        all_gen_ir.push_back(res);
        auto tmp7 = $13;
        res = new IR(kRuleStmt, OP3("", "", ""), res, tmp7);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


RuleActionList:

    NOTHING {
        res = new IR(kRuleActionList, OP3("NOTHING", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | RuleActionStmt {
        auto tmp1 = $1;
        res = new IR(kRuleActionList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '(' RuleActionMulti ')' {
        auto tmp1 = $2;
        res = new IR(kRuleActionList, OP3("(", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/* the thrashing around here is to discard "empty" statements... */

RuleActionMulti:

    RuleActionMulti ';' RuleActionStmtOrEmpty {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kRuleActionMulti, OP3("", ";", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | RuleActionStmtOrEmpty {
        auto tmp1 = $1;
        res = new IR(kRuleActionMulti, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


RuleActionStmt:

    SelectStmt {
        auto tmp1 = $1;
        res = new IR(kRuleActionStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | InsertStmt {
        auto tmp1 = $1;
        res = new IR(kRuleActionStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | UpdateStmt {
        auto tmp1 = $1;
        res = new IR(kRuleActionStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DeleteStmt {
        auto tmp1 = $1;
        res = new IR(kRuleActionStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NotifyStmt {
        auto tmp1 = $1;
        res = new IR(kRuleActionStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


RuleActionStmtOrEmpty:

    RuleActionStmt {
        auto tmp1 = $1;
        res = new IR(kRuleActionStmtOrEmpty, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kRuleActionStmtOrEmpty, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


event:

    SELECT {
        res = new IR(kEvent, OP3("SELECT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | UPDATE {
        res = new IR(kEvent, OP3("UPDATE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DELETE_P {
        res = new IR(kEvent, OP3("DELETE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | INSERT {
        res = new IR(kEvent, OP3("INSERT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_instead:

    INSTEAD {
        res = new IR(kOptInstead, OP3("INSTEAD", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALSO {
        res = new IR(kOptInstead, OP3("ALSO", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptInstead, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
*		QUERY:
*				NOTIFY <identifier> can appear both in rule bodies and
*				as a query-level command
*
*****************************************************************************/


NotifyStmt:

    NOTIFY ColId notify_payload {
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kNotifyStmt, OP3("NOTIFY", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


notify_payload:

    ',' Sconst {
        $$ = alloc_and_cat(", '", $2, "'");
        free($2);
    }

    | /*EMPTY*/ {
        char* mem = (char*) calloc(2, 1);
        strcpy(mem, "");
        $$ = mem;
    }

;


ListenStmt:

    LISTEN ColId {
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        res = new IR(kListenStmt, OP3("LISTEN", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


UnlistenStmt:

    UNLISTEN ColId {
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        res = new IR(kUnlistenStmt, OP3("UNLISTEN", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | UNLISTEN '*' {
        res = new IR(kUnlistenStmt, OP3("UNLISTEN *", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
*		Transactions:
*
*		BEGIN / COMMIT / ROLLBACK
*		(also older versions END / ABORT)
*
*****************************************************************************/


TransactionStmt:

    ABORT_P opt_transaction opt_transaction_chain {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kTransactionStmt, OP3("ABORT", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | START TRANSACTION transaction_mode_list_or_empty {
        auto tmp1 = $3;
        res = new IR(kTransactionStmt, OP3("START TRANSACTION", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | COMMIT opt_transaction opt_transaction_chain {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kTransactionStmt, OP3("COMMIT", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ROLLBACK opt_transaction opt_transaction_chain {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kTransactionStmt, OP3("ROLLBACK", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SAVEPOINT ColId {
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        res = new IR(kTransactionStmt, OP3("SAVEPOINT", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | RELEASE SAVEPOINT ColId {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        res = new IR(kTransactionStmt, OP3("RELEASE SAVEPOINT", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | RELEASE ColId {
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        res = new IR(kTransactionStmt, OP3("RELEASE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ROLLBACK opt_transaction TO SAVEPOINT ColId {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($5), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($5);
        res = new IR(kTransactionStmt, OP3("ROLLBACK", "TO SAVEPOINT", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ROLLBACK opt_transaction TO ColId {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($4), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($4);
        res = new IR(kTransactionStmt, OP3("ROLLBACK", "TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | PREPARE TRANSACTION Sconst {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        res = new IR(kTransactionStmt, OP3("PREPARE TRANSACTION", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | COMMIT PREPARED Sconst {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        res = new IR(kTransactionStmt, OP3("COMMIT PREPARED", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ROLLBACK PREPARED Sconst {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        res = new IR(kTransactionStmt, OP3("ROLLBACK PREPARED", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


TransactionStmtLegacy:

    BEGIN_P opt_transaction transaction_mode_list_or_empty {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kTransactionStmtLegacy, OP3("BEGIN", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | END_P opt_transaction opt_transaction_chain {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kTransactionStmtLegacy, OP3("END", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_transaction:

    WORK {
        res = new IR(kOptTransaction, OP3("WORK", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TRANSACTION {
        res = new IR(kOptTransaction, OP3("TRANSACTION", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptTransaction, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


transaction_mode_item:

    ISOLATION LEVEL iso_level {
        auto tmp1 = $3;
        res = new IR(kTransactionModeItem, OP3("ISOLATION LEVEL", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | READ ONLY {
        res = new IR(kTransactionModeItem, OP3("READ ONLY", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | READ WRITE {
        res = new IR(kTransactionModeItem, OP3("READ WRITE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DEFERRABLE {
        res = new IR(kTransactionModeItem, OP3("DEFERRABLE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NOT DEFERRABLE {
        res = new IR(kTransactionModeItem, OP3("NOT DEFERRABLE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/* Syntax with commas is SQL-spec, without commas is Postgres historical */

transaction_mode_list:

    transaction_mode_item {
        auto tmp1 = $1;
        res = new IR(kTransactionModeList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | transaction_mode_list ',' transaction_mode_item {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kTransactionModeList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | transaction_mode_list transaction_mode_item {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kTransactionModeList, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


transaction_mode_list_or_empty:

    transaction_mode_list {
        auto tmp1 = $1;
        res = new IR(kTransactionModeListOrEmpty, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kTransactionModeListOrEmpty, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_transaction_chain:

    AND CHAIN {
        res = new IR(kOptTransactionChain, OP3("AND CHAIN", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | AND NO CHAIN {
        res = new IR(kOptTransactionChain, OP3("AND NO CHAIN", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kOptTransactionChain, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
*	QUERY:
*		CREATE [ OR REPLACE ] [ TEMP ] VIEW <viewname> '('target-list ')'
*			AS <query> [ WITH [ CASCADED | LOCAL ] CHECK OPTION ]
*
*****************************************************************************/


ViewStmt:

    CREATE OptTemp VIEW qualified_name opt_column_list opt_reloptions AS SelectStmt opt_check_option {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kViewStmt_1, OP3("CREATE", "VIEW", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kViewStmt_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $6;
        res = new IR(kViewStmt_3, OP3("", "", "AS"), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $8;
        res = new IR(kViewStmt_4, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        auto tmp6 = $9;
        res = new IR(kViewStmt, OP3("", "", ""), res, tmp6);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp2->set_qualified_name_type(kDataViewName, kDefine);
        tmp3->set_opt_columnlist_type(kDataColumnName, kDefine);

    }

    | CREATE OR REPLACE OptTemp VIEW qualified_name opt_column_list opt_reloptions AS SelectStmt opt_check_option {
        auto tmp1 = $4;
        auto tmp2 = $6;
        res = new IR(kViewStmt_5, OP3("CREATE OR REPLACE", "VIEW", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $7;
        res = new IR(kViewStmt_6, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $8;
        res = new IR(kViewStmt_7, OP3("", "", "AS"), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $10;
        res = new IR(kViewStmt_8, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        auto tmp6 = $11;
        res = new IR(kViewStmt, OP3("", "", ""), res, tmp6);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp2->set_qualified_name_type(kDataViewName, kDefine);
        tmp3->set_opt_columnlist_type(kDataColumnName, kDefine);
    }

    | CREATE OptTemp RECURSIVE VIEW qualified_name '(' columnList ')' opt_reloptions AS SelectStmt opt_check_option {
        /* Yu: Do not allow for opt_check_option */
        auto tmp1 = $2;
        auto tmp2 = $5;
        res = new IR(kViewStmt_9, OP3("CREATE", "RECURSIVE VIEW", "("), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $7;
        res = new IR(kViewStmt_10, OP3("", "", ")"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $9;
        res = new IR(kViewStmt_11, OP3("", "", "AS"), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $11;
        res = new IR(kViewStmt_12, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        auto tmp6 = $12;
        /* tmp6 -> deep_drop(); */
        rov_ir.push_back(tmp6);
        tmp6 = new IR(kOptCheckOption, OP3("", "", ""));
        all_gen_ir.push_back(tmp6);
        res = new IR(kViewStmt, OP3("", "", ""), res, tmp6);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp2->set_qualified_name_type(kDataViewName, kDefine);
        tmp3->set_columnlist_type(kDataColumnName, kDefine);

    }

    | CREATE OR REPLACE OptTemp RECURSIVE VIEW qualified_name '(' columnList ')' opt_reloptions AS SelectStmt opt_check_option {
        /* Yu: Do not allow for opt_check_option. */
        auto tmp1 = $4;
        auto tmp2 = $7;
        res = new IR(kViewStmt_13, OP3("CREATE OR REPLACE", "RECURSIVE VIEW", "("), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $9;
        res = new IR(kViewStmt_14, OP3("", "", ")"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $11;
        res = new IR(kViewStmt_15, OP3("", "", "AS"), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $13;
        res = new IR(kViewStmt_16, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        auto tmp6 = $14;
        /* tmp6 -> deep_drop(); */
        rov_ir.push_back(tmp6);
        tmp6 = new IR(kOptCheckOption, OP3("", "", ""));
        all_gen_ir.push_back(tmp6);
        res = new IR(kViewStmt, OP3("", "", ""), res, tmp6);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp2->set_qualified_name_type(kDataViewName, kDefine);
        tmp3->set_columnlist_type(kDataColumnName, kDefine);

    }

;


opt_check_option:

    WITH CHECK OPTION {
        res = new IR(kOptCheckOption, OP3("WITH CHECK OPTION", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | WITH CASCADED CHECK OPTION {
        res = new IR(kOptCheckOption, OP3("WITH CASCADED CHECK OPTION", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | WITH LOCAL CHECK OPTION {
        res = new IR(kOptCheckOption, OP3("WITH LOCAL CHECK OPTION", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kOptCheckOption, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
*		QUERY:
*				LOAD "filename"
*
*****************************************************************************/


LoadStmt:

    LOAD file_name {
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        res = new IR(kLoadStmt, OP3("LOAD", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
*		CREATE DATABASE
*
*****************************************************************************/


CreatedbStmt:

    CREATE DATABASE name opt_with createdb_opt_list {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $4;
        res = new IR(kCreatedbStmt_1, OP3("CREATE DATABASE", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kCreatedbStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


createdb_opt_list:

    createdb_opt_items {
        auto tmp1 = $1;
        res = new IR(kCreatedbOptList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kCreatedbOptList, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


createdb_opt_items:

    createdb_opt_item {
        auto tmp1 = $1;
        res = new IR(kCreatedbOptItems, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | createdb_opt_items createdb_opt_item {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kCreatedbOptItems, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


createdb_opt_item:

    createdb_opt_name opt_equal SignedIconst {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kCreatedbOptItem_1, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $3;
        res = new IR(kCreatedbOptItem, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | createdb_opt_name opt_equal opt_boolean_or_string {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kCreatedbOptItem_2, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($3);
        res = new IR(kCreatedbOptItem, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | createdb_opt_name opt_equal DEFAULT {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kCreatedbOptItem, OP3("", "", "DEFAULT"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* Ideally we'd use ColId here, but that causes shift/reduce conflicts against
* the ALTER DATABASE SET/RESET syntaxes.  Instead call out specific keywords
* we need, and allow IDENT so that database option names don't have to be
* parser keywords unless they are already keywords for other reasons.
*
* XXX this coding technique is fragile since if someone makes a formerly
* non-keyword option name into a keyword and forgets to add it here, the
* option will silently break.  Best defense is to provide a regression test
* exercising every such option, at least at the syntax level.
*/

createdb_opt_name:

    IDENT {
        /* Yu: Weird. I don't see any documents mentioned we can define anything here.  */
        free($1);
        res = new IR(kCreatedbOptName, OP3("TEMPLATE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CONNECTION LIMIT {
        res = new IR(kCreatedbOptName, OP3("CONNECTION LIMIT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ENCODING {
        res = new IR(kCreatedbOptName, OP3("ENCODING", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | LOCATION {
        res = new IR(kCreatedbOptName, OP3("LOCATION", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | OWNER {
        res = new IR(kCreatedbOptName, OP3("OWNER", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TABLESPACE {
        res = new IR(kCreatedbOptName, OP3("TABLESPACE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TEMPLATE {
        res = new IR(kCreatedbOptName, OP3("TEMPLATE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
*	Though the equals sign doesn't match other WITH options, pg_dump uses
*	equals for backward compatibility, and it doesn't seem worth removing it.
*/

opt_equal:

    '=' {
        res = new IR(kOptEqual, OP3("=", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptEqual, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
*		ALTER DATABASE
*
*****************************************************************************/


AlterDatabaseStmt:

    ALTER DATABASE name WITH createdb_opt_list {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $5;
        res = new IR(kAlterDatabaseStmt, OP3("ALTER DATABASE", "WITH", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER DATABASE name createdb_opt_list {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $4;
        res = new IR(kAlterDatabaseStmt, OP3("ALTER DATABASE", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER DATABASE name SET TABLESPACE name {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterDatabaseStmt, OP3("ALTER DATABASE", "SET TABLESPACE", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


AlterDatabaseSetStmt:

    ALTER DATABASE name SetResetClause {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $4;
        res = new IR(kAlterDatabaseSetStmt, OP3("ALTER DATABASE", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
*		DROP DATABASE [ IF EXISTS ] dbname [ [ WITH ] ( options ) ]
*
* This is implicitly CASCADE, no need for drop behavior
*****************************************************************************/


DropdbStmt:

    DROP DATABASE name {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        res = new IR(kDropdbStmt, OP3("DROP DATABASE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DROP DATABASE IF_P EXISTS name {
        auto tmp1 = new IR(kIdentifier, string($5), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($5);
        res = new IR(kDropdbStmt, OP3("DROP DATABASE IF EXISTS", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DROP DATABASE name opt_with '(' drop_option_list ')' {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        auto tmp2 = $4;
        res = new IR(kDropdbStmt_1, OP3("DROP DATABASE", "", "("), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kDropdbStmt, OP3("", "", ")"), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DROP DATABASE IF_P EXISTS name opt_with '(' drop_option_list ')' {
        auto tmp1 = new IR(kIdentifier, string($5), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($5);
        auto tmp2 = $6;
        res = new IR(kDropdbStmt_2, OP3("DROP DATABASE IF EXISTS", "", "("), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $8;
        res = new IR(kDropdbStmt, OP3("", "", ")"), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


drop_option_list:

    drop_option {
        auto tmp1 = $1;
        res = new IR(kDropOptionList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | drop_option_list ',' drop_option {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kDropOptionList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* Currently only the FORCE option is supported, but the syntax is designed
* to be extensible so that we can add more options in the future if required.
*/

drop_option:

    FORCE {
        res = new IR(kDropOption, OP3("FORCE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
*		ALTER COLLATION
*
*****************************************************************************/


AlterCollationStmt:

    ALTER COLLATION any_name REFRESH VERSION_P {
        auto tmp1 = $3;
        res = new IR(kAlterCollationStmt, OP3("ALTER COLLATION", "REFRESH VERSION", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
*		ALTER SYSTEM
*
* This is used to change configuration parameters persistently.
*****************************************************************************/


AlterSystemStmt:

    ALTER SYSTEM_P SET generic_set {
        auto tmp1 = $4;
        res = new IR(kAlterSystemStmt, OP3("ALTER SYSTEM SET", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER SYSTEM_P RESET generic_reset {
        auto tmp1 = $4;
        res = new IR(kAlterSystemStmt, OP3("ALTER SYSTEM RESET", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
* Manipulate a domain
*
*****************************************************************************/


CreateDomainStmt:

    CREATE DOMAIN_P any_name opt_as Typename ColQualList {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kCreateDomainStmt_1, OP3("CREATE DOMAIN", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kCreateDomainStmt_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $6;
        res = new IR(kCreateDomainStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


AlterDomainStmt:

    ALTER DOMAIN_P any_name alter_column_default {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kAlterDomainStmt, OP3("ALTER DOMAIN", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER DOMAIN_P any_name DROP NOT NULL_P {
        auto tmp1 = $3;
        res = new IR(kAlterDomainStmt, OP3("ALTER DOMAIN", "DROP NOT NULL", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER DOMAIN_P any_name SET NOT NULL_P {
        auto tmp1 = $3;
        res = new IR(kAlterDomainStmt, OP3("ALTER DOMAIN", "SET NOT NULL", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER DOMAIN_P any_name ADD_P TableConstraint {
        auto tmp1 = $3;
        auto tmp2 = $5;
        res = new IR(kAlterDomainStmt, OP3("ALTER DOMAIN", "ADD", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER DOMAIN_P any_name DROP CONSTRAINT name opt_drop_behavior {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterDomainStmt_1, OP3("ALTER DOMAIN", "DROP CONSTRAINT", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $7;
        res = new IR(kAlterDomainStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER DOMAIN_P any_name DROP CONSTRAINT IF_P EXISTS name opt_drop_behavior {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($8);
        res = new IR(kAlterDomainStmt_2, OP3("ALTER DOMAIN", "DROP CONSTRAINT IF EXISTS", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $9;
        res = new IR(kAlterDomainStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER DOMAIN_P any_name VALIDATE CONSTRAINT name {
        auto tmp1 = $3;
        auto tmp2 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($6);
        res = new IR(kAlterDomainStmt, OP3("ALTER DOMAIN", "VALIDATE CONSTRAINT", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_as:

    AS {
        res = new IR(kOptAs, OP3("AS", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kOptAs, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
* Manipulate a text search dictionary or configuration
*
*****************************************************************************/


AlterTSDictionaryStmt:

    ALTER TEXT_P SEARCH DICTIONARY any_name definition {
        auto tmp1 = $5;
        auto tmp2 = $6;
        res = new IR(kAlterTSDictionaryStmt, OP3("ALTER TEXT SEARCH DICTIONARY", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


AlterTSConfigurationStmt:

    ALTER TEXT_P SEARCH CONFIGURATION any_name ADD_P MAPPING FOR name_list any_with any_name_list {
        auto tmp1 = $5;
        auto tmp2 = $9;
        res = new IR(kAlterTSConfigurationStmt_1, OP3("ALTER TEXT SEARCH CONFIGURATION", "ADD MAPPING FOR", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $10;
        res = new IR(kAlterTSConfigurationStmt_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $11;
        res = new IR(kAlterTSConfigurationStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER TEXT_P SEARCH CONFIGURATION any_name ALTER MAPPING FOR name_list any_with any_name_list {
        auto tmp1 = $5;
        auto tmp2 = $9;
        res = new IR(kAlterTSConfigurationStmt_3, OP3("ALTER TEXT SEARCH CONFIGURATION", "ALTER MAPPING FOR", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $10;
        res = new IR(kAlterTSConfigurationStmt_4, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $11;
        res = new IR(kAlterTSConfigurationStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER TEXT_P SEARCH CONFIGURATION any_name ALTER MAPPING REPLACE any_name any_with any_name {
        auto tmp1 = $5;
        auto tmp2 = $9;
        res = new IR(kAlterTSConfigurationStmt_5, OP3("ALTER TEXT SEARCH CONFIGURATION", "ALTER MAPPING REPLACE", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $10;
        res = new IR(kAlterTSConfigurationStmt_6, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $11;
        res = new IR(kAlterTSConfigurationStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER TEXT_P SEARCH CONFIGURATION any_name ALTER MAPPING FOR name_list REPLACE any_name any_with any_name {
        auto tmp1 = $5;
        auto tmp2 = $9;
        res = new IR(kAlterTSConfigurationStmt_7, OP3("ALTER TEXT SEARCH CONFIGURATION", "ALTER MAPPING FOR", "REPLACE"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $11;
        res = new IR(kAlterTSConfigurationStmt_8, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $12;
        res = new IR(kAlterTSConfigurationStmt_9, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $13;
        res = new IR(kAlterTSConfigurationStmt, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER TEXT_P SEARCH CONFIGURATION any_name DROP MAPPING FOR name_list {
        auto tmp1 = $5;
        auto tmp2 = $9;
        res = new IR(kAlterTSConfigurationStmt, OP3("ALTER TEXT SEARCH CONFIGURATION", "DROP MAPPING FOR", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALTER TEXT_P SEARCH CONFIGURATION any_name DROP MAPPING IF_P EXISTS FOR name_list {
        auto tmp1 = $5;
        auto tmp2 = $11;
        res = new IR(kAlterTSConfigurationStmt, OP3("ALTER TEXT SEARCH CONFIGURATION", "DROP MAPPING IF EXISTS FOR", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/* Use this if TIME or ORDINALITY after WITH should be taken as an identifier */

any_with:

    WITH {
        res = new IR(kAnyWith, OP3("WITH", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | WITH_LA {
        res = new IR(kAnyWith, OP3("WITH", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
* Manipulate a conversion
*
*		CREATE [DEFAULT] CONVERSION <conversion_name>
*		FOR <encoding_name> TO <encoding_name> FROM <func_name>
*
*****************************************************************************/


CreateConversionStmt:

    CREATE opt_default CONVERSION_P any_name FOR Sconst TO Sconst FROM any_name {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kCreateConversionStmt_1, OP3("CREATE", "CONVERSION", "FOR"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($6);
        res = new IR(kCreateConversionStmt_2, OP3("", "", "TO"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = new IR(kIdentifier, string($8), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp4 );
        free($8);
        res = new IR(kCreateConversionStmt_3, OP3("", "", "FROM"), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $10;
        res = new IR(kCreateConversionStmt, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
*		QUERY:
*				CLUSTER [VERBOSE] <qualified_name> [ USING <index_name> ]
*				CLUSTER [ (options) ] <qualified_name> [ USING <index_name> ]
*				CLUSTER [VERBOSE]
*				CLUSTER [VERBOSE] <index_name> ON <qualified_name> (for pre-8.3)
*
*****************************************************************************/


ClusterStmt:

    CLUSTER opt_verbose qualified_name cluster_index_specification {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kClusterStmt_1, OP3("CLUSTER", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $4;
        res = new IR(kClusterStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp2->set_qualified_name_type(kDataTableName, kUse);
        tmp3->set_cluster_index_specification_type(kDataAliasName, kUse);

    }

    | CLUSTER '(' utility_option_list ')' qualified_name cluster_index_specification {
        auto tmp1 = $3;
        auto tmp2 = $5;
        res = new IR(kClusterStmt_2, OP3("CLUSTER (", ")", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kClusterStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp2->set_qualified_name_type(kDataTableName, kUse);
        tmp3->set_cluster_index_specification_type(kDataAliasName, kUse);
    }

    | CLUSTER opt_verbose {
        auto tmp1 = $2;
        res = new IR(kClusterStmt, OP3("CLUSTER", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CLUSTER opt_verbose name ON qualified_name {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kClusterStmt_3, OP3("CLUSTER", "", "ON"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kClusterStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp2-> set_iden_type(kDataAliasName, kUse);
        tmp3->set_qualified_name_type(kDataTableName, kUse);
    }

;


cluster_index_specification:

    USING name {
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        res = new IR(kClusterIndexSpecification, OP3("USING", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_iden_type(kDataAliasName, kUse);
    }

    | /*EMPTY*/ {
        res = new IR(kClusterIndexSpecification, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
*		QUERY:
*				VACUUM
*				ANALYZE
*
*****************************************************************************/


VacuumStmt:

    VACUUM opt_full opt_freeze opt_verbose opt_analyze opt_vacuum_relation_list {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kVacuumStmt_1, OP3("VACUUM", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $4;
        res = new IR(kVacuumStmt_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $5;
        res = new IR(kVacuumStmt_3, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $6;
        res = new IR(kVacuumStmt, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | VACUUM '(' utility_option_list ')' opt_vacuum_relation_list {
        auto tmp1 = $3;
        auto tmp2 = $5;
        res = new IR(kVacuumStmt, OP3("VACUUM (", ")", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


AnalyzeStmt:

    analyze_keyword opt_verbose opt_vacuum_relation_list {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = $2;
        res = new IR(kAnalyzeStmt_1, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $3;
        res = new IR(kAnalyzeStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | analyze_keyword '(' utility_option_list ')' opt_vacuum_relation_list {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = $3;
        res = new IR(kAnalyzeStmt_2, OP3("", "(", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kAnalyzeStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


utility_option_list:

    utility_option_elem {
        auto tmp1 = $1;
        res = new IR(kUtilityOptionList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | utility_option_list ',' utility_option_elem {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kUtilityOptionList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


analyze_keyword:

    ANALYZE {
        $$ = strdup("ANALYZE");
    }

    | ANALYSE {
        $$ = strdup("ANALYSE");
    }

;


utility_option_elem:

    utility_option_name utility_option_arg {
        /* Yu: We do not know what is the possible values or types for this utility_option_name.
        ** Do not change it to kIdentifier.
        ** FixLater: $1 into OP3
        */
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        auto tmp2 = $2;
        res = new IR(kUtilityOptionElem, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        free($1);
        $$ = res;
    }

;


utility_option_name:

    NonReservedWord
    | analyze_keyword
;


utility_option_arg:

    opt_boolean_or_string {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kUtilityOptionArg, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NumericOnly {
        auto tmp1 = $1;
        res = new IR(kUtilityOptionArg, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kUtilityOptionArg, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_analyze:

    analyze_keyword {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kOptAnalyze, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptAnalyze, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_verbose:

    VERBOSE {
        res = new IR(kOptVerbose, OP3("VERBOSE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptVerbose, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_full:

    FULL {
        res = new IR(kOptFull, OP3("FULL", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptFull, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_freeze:

    FREEZE {
        res = new IR(kOptFreeze, OP3("FREEZE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptFreeze, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_name_list:

    '(' name_list ')' {
        auto tmp1 = $2;
        res = new IR(kOptNameList, OP3("(", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptNameList, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


vacuum_relation:

    qualified_name opt_name_list {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kVacuumRelation, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_qualified_name_type(kDataTableName, kUse);
        tmp2->set_opt_name_list_type(kDataColumnName, kUse);

    }

;


vacuum_relation_list:

    vacuum_relation {
        auto tmp1 = $1;
        res = new IR(kVacuumRelationList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | vacuum_relation_list ',' vacuum_relation {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kVacuumRelationList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_vacuum_relation_list:

    vacuum_relation_list {
        auto tmp1 = $1;
        res = new IR(kOptVacuumRelationList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptVacuumRelationList, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
*		QUERY:
*				EXPLAIN [ANALYZE] [VERBOSE] query
*				EXPLAIN ( options ) query
*
*****************************************************************************/


ExplainStmt:

    EXPLAIN ExplainableStmt {
        auto tmp1 = $2;
        res = new IR(kExplainStmt, OP3("EXPLAIN", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | EXPLAIN analyze_keyword opt_verbose ExplainableStmt {
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        auto tmp2 = $3;
        res = new IR(kExplainStmt_1, OP3("EXPLAIN", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $4;
        res = new IR(kExplainStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | EXPLAIN VERBOSE ExplainableStmt {
        auto tmp1 = $3;
        res = new IR(kExplainStmt, OP3("EXPLAIN VERBOSE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | EXPLAIN '(' utility_option_list ')' ExplainableStmt {
        auto tmp1 = $3;
        auto tmp2 = $5;
        res = new IR(kExplainStmt, OP3("EXPLAIN (", ")", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


ExplainableStmt:

    SelectStmt {
        auto tmp1 = $1;
        res = new IR(kExplainableStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | InsertStmt {
        auto tmp1 = $1;
        res = new IR(kExplainableStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | UpdateStmt {
        auto tmp1 = $1;
        res = new IR(kExplainableStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DeleteStmt {
        auto tmp1 = $1;
        res = new IR(kExplainableStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DeclareCursorStmt {
        auto tmp1 = $1;
        res = new IR(kExplainableStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CreateAsStmt {
        auto tmp1 = $1;
        res = new IR(kExplainableStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CreateMatViewStmt {
        auto tmp1 = $1;
        res = new IR(kExplainableStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | RefreshMatViewStmt {
        auto tmp1 = $1;
        res = new IR(kExplainableStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ExecuteStmt {
        auto tmp1 = $1;
        res = new IR(kExplainableStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
*		QUERY:
*				PREPARE <plan_name> [(args, ...)] AS <query>
*
*****************************************************************************/


PrepareStmt:

    PREPARE name prep_type_clause AS PreparableStmt {
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        auto tmp2 = $3;
        res = new IR(kPrepareStmt_1, OP3("PREPARE", "", "AS"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kPrepareStmt, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


prep_type_clause:

    '(' type_list ')' {
        auto tmp1 = $2;
        res = new IR(kPrepTypeClause, OP3("(", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kPrepTypeClause, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


PreparableStmt:

    SelectStmt {
        auto tmp1 = $1;
        res = new IR(kPreparableStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | InsertStmt {
        auto tmp1 = $1;
        res = new IR(kPreparableStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | UpdateStmt {
        auto tmp1 = $1;
        res = new IR(kPreparableStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DeleteStmt {
        auto tmp1 = $1;
        res = new IR(kPreparableStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
* EXECUTE <plan_name> [(params, ...)]
* CREATE TABLE <name> AS EXECUTE <plan_name> [(params, ...)]
*
*****************************************************************************/


ExecuteStmt:

    EXECUTE name execute_param_clause {
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        auto tmp2 = $3;
        res = new IR(kExecuteStmt, OP3("EXECUTE", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CREATE OptTemp TABLE create_as_target AS EXECUTE name execute_param_clause opt_with_data {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kExecuteStmt_1, OP3("CREATE", "TABLE", "AS EXECUTE"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($7), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($7);
        res = new IR(kExecuteStmt_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $8;
        res = new IR(kExecuteStmt_3, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $9;
        res = new IR(kExecuteStmt, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CREATE OptTemp TABLE IF_P NOT EXISTS create_as_target AS EXECUTE name execute_param_clause opt_with_data {
        auto tmp1 = $2;
        auto tmp2 = $7;
        res = new IR(kExecuteStmt_4, OP3("CREATE", "TABLE IF NOT EXISTS", "AS EXECUTE"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($10), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($10);
        res = new IR(kExecuteStmt_5, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $11;
        res = new IR(kExecuteStmt_6, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $12;
        res = new IR(kExecuteStmt, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


execute_param_clause:

    '(' expr_list ')' {
        auto tmp1 = $2;
        res = new IR(kExecuteParamClause, OP3("(", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kExecuteParamClause, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
*		QUERY:
*				DEALLOCATE [PREPARE] <plan_name>
*
*****************************************************************************/


DeallocateStmt:

    DEALLOCATE name {
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        res = new IR(kDeallocateStmt, OP3("DEALLOCATE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DEALLOCATE PREPARE name {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        res = new IR(kDeallocateStmt, OP3("DEALLOCATE PREPARE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DEALLOCATE ALL {
        res = new IR(kDeallocateStmt, OP3("DEALLOCATE ALL", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DEALLOCATE PREPARE ALL {
        res = new IR(kDeallocateStmt, OP3("DEALLOCATE PREPARE ALL", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
*		QUERY:
*				INSERT STATEMENTS
*
*****************************************************************************/


InsertStmt:

    opt_with_clause INSERT INTO insert_target insert_rest opt_on_conflict returning_clause {
        auto tmp1 = $1;
        auto tmp2 = $4;
        res = new IR(kInsertStmt_1, OP3("", "INSERT INTO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kInsertStmt_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $6;
        res = new IR(kInsertStmt_3, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $7;
        res = new IR(kInsertStmt, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* Can't easily make AS optional here, because VALUES in insert_rest would
* have a shift/reduce conflict with VALUES as an optional alias.  We could
* easily allow unreserved_keywords as optional aliases, but that'd be an odd
* divergence from other places.  So just require AS for now.
*/

insert_target:

    qualified_name {
        auto tmp1 = $1;
        res = new IR(kInsertTarget, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_qualified_name_type(kDataTableName, kUse);

    }

    | qualified_name AS ColId {
        auto tmp1 = $1;
        auto tmp2 = new IR(kIdentifier, string($3), kDataAliasName, 0, kDefine);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kInsertTarget, OP3("", "AS", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_qualified_name_type(kDataTableName, kUse);
    }

;


insert_rest:

    SelectStmt {
        auto tmp1 = $1;
        res = new IR(kInsertRest, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | OVERRIDING override_kind VALUE_P SelectStmt {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kInsertRest, OP3("OVERRIDING", "VALUE", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '(' insert_column_list ')' SelectStmt {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kInsertRest, OP3("(", ")", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_insert_columnlist_type(kDataColumnName, kUse);
    }

    | '(' insert_column_list ')' OVERRIDING override_kind VALUE_P SelectStmt {
        auto tmp1 = $2;
        auto tmp2 = $5;
        res = new IR(kInsertRest_1, OP3("(", ") OVERRIDING", "VALUE"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $7;
        res = new IR(kInsertRest, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_insert_columnlist_type(kDataColumnName, kUse);
    }

    | DEFAULT VALUES {
        res = new IR(kInsertRest, OP3("DEFAULT VALUES", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


override_kind:

    USER {
        res = new IR(kOverrideKind, OP3("USER", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SYSTEM_P {
        res = new IR(kOverrideKind, OP3("SYSTEM", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


insert_column_list:

    insert_column_item {
        auto tmp1 = $1;
        res = new IR(kInsertColumnList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | insert_column_list ',' insert_column_item {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kInsertColumnList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


insert_column_item:

    ColId opt_indirection {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = $2;
        res = new IR(kInsertColumnItem, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_iden_type(kDataTableNameFollow, kUse);
    }

;


opt_on_conflict:

    ON CONFLICT opt_conf_expr DO UPDATE SET set_clause_list where_clause {
        auto tmp1 = $3;
        auto tmp2 = $7;
        res = new IR(kOptOnConflict_1, OP3("ON CONFLICT", "DO UPDATE SET", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $8;
        res = new IR(kOptOnConflict, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ON CONFLICT opt_conf_expr DO NOTHING {
        auto tmp1 = $3;
        res = new IR(kOptOnConflict, OP3("ON CONFLICT", "DO NOTHING", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptOnConflict, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_conf_expr:

    '(' index_params ')' where_clause {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kOptConfExpr, OP3("(", ")", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ON CONSTRAINT name {
        auto tmp1 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($3);
        res = new IR(kOptConfExpr, OP3("ON CONSTRAINT", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_iden_type(kDataConstraintName, kUse);
    }

    | /*EMPTY*/ {
        res = new IR(kOptConfExpr, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


returning_clause:

    RETURNING target_list {
        auto tmp1 = $2;
        res = new IR(kReturningClause, OP3("RETURNING", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kReturningClause, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
*		QUERY:
*				DELETE STATEMENTS
*
*****************************************************************************/


DeleteStmt:

    opt_with_clause DELETE_P FROM relation_expr_opt_alias using_clause where_or_current_clause returning_clause {
        auto tmp1 = $1;
        auto tmp2 = $4;
        res = new IR(kDeleteStmt_1, OP3("", "DELETE FROM", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kDeleteStmt_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $6;
        res = new IR(kDeleteStmt_3, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $7;
        res = new IR(kDeleteStmt, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


using_clause:

    USING from_list {
        auto tmp1 = $2;
        res = new IR(kUsingClause, OP3("USING", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kUsingClause, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
*		QUERY:
*				LOCK TABLE
*
*****************************************************************************/


LockStmt:

    LOCK_P opt_table relation_expr_list opt_lock opt_nowait {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kLockStmt_1, OP3("LOCK", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $4;
        res = new IR(kLockStmt_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $5;
        res = new IR(kLockStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_lock:

    IN_P lock_type MODE {
        auto tmp1 = $2;
        res = new IR(kOptLock, OP3("IN", "MODE", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptLock, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


lock_type:

    ACCESS SHARE {
        res = new IR(kLockType, OP3("ACCESS SHARE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ROW SHARE {
        res = new IR(kLockType, OP3("ROW SHARE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ROW EXCLUSIVE {
        res = new IR(kLockType, OP3("ROW EXCLUSIVE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SHARE UPDATE EXCLUSIVE {
        res = new IR(kLockType, OP3("SHARE UPDATE EXCLUSIVE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SHARE {
        res = new IR(kLockType, OP3("SHARE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SHARE ROW EXCLUSIVE {
        res = new IR(kLockType, OP3("SHARE ROW EXCLUSIVE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | EXCLUSIVE {
        res = new IR(kLockType, OP3("EXCLUSIVE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ACCESS EXCLUSIVE {
        res = new IR(kLockType, OP3("ACCESS EXCLUSIVE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_nowait:

    NOWAIT {
        res = new IR(kOptNowait, OP3("NOWAIT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptNowait, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_nowait_or_skip:

    NOWAIT {
        res = new IR(kOptNowaitOrSkip, OP3("NOWAIT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SKIP LOCKED {
        res = new IR(kOptNowaitOrSkip, OP3("SKIP LOCKED", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptNowaitOrSkip, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
*		QUERY:
*				UpdateStmt (UPDATE)
*
*****************************************************************************/


UpdateStmt:

    opt_with_clause UPDATE relation_expr_opt_alias SET set_clause_list from_clause where_or_current_clause returning_clause {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kUpdateStmt_1, OP3("", "UPDATE", "SET"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kUpdateStmt_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $6;
        res = new IR(kUpdateStmt_3, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $7;
        res = new IR(kUpdateStmt_4, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        auto tmp6 = $8;
        res = new IR(kUpdateStmt, OP3("", "", ""), res, tmp6);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


set_clause_list:

    set_clause {
        auto tmp1 = $1;
        res = new IR(kSetClauseList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | set_clause_list ',' set_clause {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kSetClauseList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


set_clause:

    set_target '=' a_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kSetClause, OP3("", "=", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '(' set_target_list ')' '=' a_expr {
        auto tmp1 = $2;
        auto tmp2 = $5;
        res = new IR(kSetClause, OP3("(", ") =", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


set_target:

    ColId opt_indirection {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = $2;
        res = new IR(kSetTarget, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


set_target_list:

    set_target {
        auto tmp1 = $1;
        res = new IR(kSetTargetList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | set_target_list ',' set_target {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kSetTargetList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
*		QUERY:
*				CURSOR STATEMENTS
*
*****************************************************************************/

DeclareCursorStmt:

    DECLARE cursor_name cursor_options CURSOR opt_hold FOR SelectStmt {
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        auto tmp2 = $3;
        res = new IR(kDeclareCursorStmt_1, OP3("DECLARE", "", "CURSOR"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kDeclareCursorStmt_2, OP3("", "", "FOR"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $7;
        res = new IR(kDeclareCursorStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


cursor_name:
    name
;


cursor_options:

    /*EMPTY*/ {
        res = new IR(kCursorOptions, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | cursor_options NO SCROLL {
        auto tmp1 = $1;
        res = new IR(kCursorOptions, OP3("", "NO SCROLL", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | cursor_options SCROLL {
        auto tmp1 = $1;
        res = new IR(kCursorOptions, OP3("", "SCROLL", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | cursor_options BINARY {
        auto tmp1 = $1;
        res = new IR(kCursorOptions, OP3("", "BINARY", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | cursor_options ASENSITIVE {
        auto tmp1 = $1;
        res = new IR(kCursorOptions, OP3("", "ASENSITIVE", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | cursor_options INSENSITIVE {
        auto tmp1 = $1;
        res = new IR(kCursorOptions, OP3("", "INSENSITIVE", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_hold:

    /* EMPTY */ {
        res = new IR(kOptHold, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | WITH HOLD {
        res = new IR(kOptHold, OP3("WITH HOLD", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | WITHOUT HOLD {
        res = new IR(kOptHold, OP3("WITHOUT HOLD", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
*		QUERY:
*				SELECT STATEMENTS
*
*****************************************************************************/

/* A complete SELECT statement looks like this.
*
* The rule returns either a single SelectStmt node or a tree of them,
* representing a set-operation tree.
*
* There is an ambiguity when a sub-SELECT is within an a_expr and there
* are excess parentheses: do the parentheses belong to the sub-SELECT or
* to the surrounding a_expr?  We don't really care, but bison wants to know.
* To resolve the ambiguity, we are careful to define the grammar so that
* the decision is staved off as long as possible: as long as we can keep
* absorbing parentheses into the sub-SELECT, we will do so, and only when
* it's no longer possible to do that will we decide that parens belong to
* the expression.	For example, in "SELECT (((SELECT 2)) + 3)" the extra
* parentheses are treated as part of the sub-select.  The necessity of doing
* it that way is shown by "SELECT (((SELECT 2)) UNION SELECT 2)".	Had we
* parsed "((SELECT 2))" as an a_expr, it'd be too late to go back to the
* SELECT viewpoint when we see the UNION.
*
* This approach is implemented by defining a nonterminal select_with_parens,
* which represents a SELECT with at least one outer layer of parentheses,
* and being careful to use select_with_parens, never '(' SelectStmt ')',
* in the expression grammar.  We will then have shift-reduce conflicts
* which we can resolve in favor of always treating '(' <select> ')' as
* a select_with_parens.  To resolve the conflicts, the productions that
* conflict with the select_with_parens productions are manually given
* precedences lower than the precedence of ')', thereby ensuring that we
* shift ')' (and then reduce to select_with_parens) rather than trying to
* reduce the inner <select> nonterminal to something else.  We use UMINUS
* precedence for this, which is a fairly arbitrary choice.
*
* To be able to define select_with_parens itself without ambiguity, we need
* a nonterminal select_no_parens that represents a SELECT structure with no
* outermost parentheses.  This is a little bit tedious, but it works.
*
* In non-expression contexts, we use SelectStmt which can represent a SELECT
* with or without outer parentheses.
*/


SelectStmt:

    select_no_parens %prec UMINUS {
        auto tmp1 = $1;
        res = new IR(kSelectStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | select_with_parens %prec UMINUS {
        auto tmp1 = $1;
        res = new IR(kSelectStmt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


select_with_parens:

    '(' select_no_parens ')' {
        auto tmp1 = $2;
        res = new IR(kSelectWithParens, OP3("(", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '(' select_with_parens ')' {
        auto tmp1 = $2;
        res = new IR(kSelectWithParens, OP3("(", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* This rule parses the equivalent of the standard's <query expression>.
* The duplicative productions are annoying, but hard to get rid of without
* creating shift/reduce conflicts.
*
*	The locking clause (FOR UPDATE etc) may be before or after LIMIT/OFFSET.
*	In <=7.2.X, LIMIT/OFFSET had to be after FOR UPDATE
*	We now support both orderings, but prefer LIMIT/OFFSET before the locking
* clause.
*	2002-08-28 bjm
*/

select_no_parens:

    simple_select {
        auto tmp1 = $1;
        res = new IR(kSelectNoParens, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | select_clause sort_clause {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kSelectNoParens, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | select_clause opt_sort_clause for_locking_clause opt_select_limit {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kSelectNoParens_1, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $3;
        res = new IR(kSelectNoParens_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $4;
        res = new IR(kSelectNoParens, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | select_clause opt_sort_clause select_limit opt_for_locking_clause {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kSelectNoParens_3, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $3;
        res = new IR(kSelectNoParens_4, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $4;
        res = new IR(kSelectNoParens, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | with_clause select_clause {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kSelectNoParens, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | with_clause select_clause sort_clause {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kSelectNoParens_5, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $3;
        res = new IR(kSelectNoParens, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | with_clause select_clause opt_sort_clause for_locking_clause opt_select_limit {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kSelectNoParens_6, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $3;
        res = new IR(kSelectNoParens_7, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $4;
        res = new IR(kSelectNoParens_8, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $5;
        res = new IR(kSelectNoParens, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | with_clause select_clause opt_sort_clause select_limit opt_for_locking_clause {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kSelectNoParens_9, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $3;
        res = new IR(kSelectNoParens_10, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $4;
        res = new IR(kSelectNoParens_11, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $5;
        res = new IR(kSelectNoParens, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


select_clause:

    simple_select {
        auto tmp1 = $1;
        res = new IR(kSelectClause, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | select_with_parens {
        auto tmp1 = $1;
        res = new IR(kSelectClause, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* This rule parses SELECT statements that can appear within set operations,
* including UNION, INTERSECT and EXCEPT.  '(' and ')' can be used to specify
* the ordering of the set operations.	Without '(' and ')' we want the
* operations to be ordered per the precedence specs at the head of this file.
*
* As with select_no_parens, simple_select cannot have outer parentheses,
* but can have parenthesized subclauses.
*
* It might appear that we could fold the first two alternatives into one
* by using opt_distinct_clause.  However, that causes a shift/reduce conflict
* against INSERT ... SELECT ... ON CONFLICT.  We avoid the ambiguity by
* requiring SELECT DISTINCT [ON] to be followed by a non-empty target_list.
*
* Note that sort clauses cannot be included at this level --- SQL requires
*		SELECT foo UNION SELECT bar ORDER BY baz
* to be parsed as
*		(SELECT foo UNION SELECT bar) ORDER BY baz
* not
*		SELECT foo UNION (SELECT bar ORDER BY baz)
* Likewise for WITH, FOR UPDATE and LIMIT.  Therefore, those clauses are
* described as part of the select_no_parens production, not simple_select.
* This does not limit functionality, because you can reintroduce these
* clauses inside parentheses.
*
* NOTE: only the leftmost component SelectStmt should have INTO.
* However, this is not checked by the grammar; parse analysis must check it.
*/

simple_select:

    SELECT opt_all_clause opt_target_list into_clause from_clause where_clause group_clause having_clause window_clause {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kSimpleSelect_1, OP3("SELECT", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $4;
        res = new IR(kSimpleSelect_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $5;
        res = new IR(kSimpleSelect_3, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $6;
        res = new IR(kSimpleSelect_4, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        auto tmp6 = $7;
        res = new IR(kSimpleSelect_5, OP3("", "", ""), res, tmp6);
        all_gen_ir.push_back(res);
        auto tmp7 = $8;
        res = new IR(kSimpleSelect_6, OP3("", "", ""), res, tmp7);
        all_gen_ir.push_back(res);
        auto tmp8 = $9;
        res = new IR(kSimpleSelect, OP3("", "", ""), res, tmp8);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SELECT distinct_clause target_list into_clause from_clause where_clause group_clause having_clause window_clause {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kSimpleSelect_7, OP3("SELECT", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $4;
        res = new IR(kSimpleSelect_8, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $5;
        res = new IR(kSimpleSelect_9, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $6;
        res = new IR(kSimpleSelect_10, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        auto tmp6 = $7;
        res = new IR(kSimpleSelect_11, OP3("", "", ""), res, tmp6);
        all_gen_ir.push_back(res);
        auto tmp7 = $8;
        res = new IR(kSimpleSelect_12, OP3("", "", ""), res, tmp7);
        all_gen_ir.push_back(res);
        auto tmp8 = $9;
        res = new IR(kSimpleSelect, OP3("", "", ""), res, tmp8);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | values_clause {
        auto tmp1 = $1;
        res = new IR(kSimpleSelect, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TABLE relation_expr {
        auto tmp1 = $2;
        res = new IR(kSimpleSelect, OP3("TABLE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | select_clause UNION set_quantifier select_clause {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kSimpleSelect_13, OP3("", "UNION", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $4;
        res = new IR(kSimpleSelect, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | select_clause INTERSECT set_quantifier select_clause {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kSimpleSelect_14, OP3("", "INTERSECT", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $4;
        res = new IR(kSimpleSelect, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | select_clause EXCEPT set_quantifier select_clause {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kSimpleSelect_15, OP3("", "EXCEPT", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $4;
        res = new IR(kSimpleSelect, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* SQL standard WITH clause looks like:
*
* WITH [ RECURSIVE ] <query name> [ (<column>,...) ]
*		AS (query) [ SEARCH or CYCLE clause ]
*
* Recognizing WITH_LA here allows a CTE to be named TIME or ORDINALITY.
*/

with_clause:

    WITH cte_list {
        auto tmp1 = $2;
        res = new IR(kWithClause, OP3("WITH", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | WITH_LA cte_list {
        auto tmp1 = $2;
        res = new IR(kWithClause, OP3("WITH", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | WITH RECURSIVE cte_list {
        auto tmp1 = $3;
        res = new IR(kWithClause, OP3("WITH RECURSIVE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


cte_list:

    common_table_expr {
        auto tmp1 = $1;
        res = new IR(kCteList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | cte_list ',' common_table_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kCteList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


common_table_expr:

    name opt_name_list AS opt_materialized '(' PreparableStmt ')' opt_search_clause opt_cycle_clause {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = $2;
        res = new IR(kCommonTableExpr_1, OP3("", "", "AS"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $4;
        res = new IR(kCommonTableExpr_2, OP3("", "", "("), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $6;
        res = new IR(kCommonTableExpr_3, OP3("", "", ")"), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $8;
        res = new IR(kCommonTableExpr_4, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        auto tmp6 = $9;
        res = new IR(kCommonTableExpr, OP3("", "", ""), res, tmp6);
        all_gen_ir.push_back(res);
        $$ = res;

        /* Yu: This seems to only be used in the WITH Clause.
         * Which means this would always be referred as aliases.
         * */

        tmp1 -> set_iden_type(kDataAliasTableName, kDefine);
        tmp2 -> set_opt_name_list_type(kDataAliasName, kDefine);
    }

;


opt_materialized:

    MATERIALIZED {
        res = new IR(kOptMaterialized, OP3("MATERIALIZED", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NOT MATERIALIZED {
        res = new IR(kOptMaterialized, OP3("NOT MATERIALIZED", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptMaterialized, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_search_clause:

    SEARCH DEPTH FIRST_P BY columnList SET ColId {
        auto tmp1 = $5;
        auto tmp2 = new IR(kIdentifier, string($7), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($7);
        res = new IR(kOptSearchClause, OP3("SEARCH DEPTH FIRST BY", "SET", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SEARCH BREADTH FIRST_P BY columnList SET ColId {
        auto tmp1 = $5;
        auto tmp2 = new IR(kIdentifier, string($7), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($7);
        res = new IR(kOptSearchClause, OP3("SEARCH BREADTH FIRST BY", "SET", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptSearchClause, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_cycle_clause:

    CYCLE columnList SET ColId TO AexprConst DEFAULT AexprConst USING ColId {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($4), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($4);
        res = new IR(kOptCycleClause_1, OP3("CYCLE", "SET", "TO"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kOptCycleClause_2, OP3("", "", "DEFAULT"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $8;
        res = new IR(kOptCycleClause_3, OP3("", "", "USING"), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = new IR(kIdentifier, string($10), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp5 );
        free($10);
        res = new IR(kOptCycleClause, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CYCLE columnList SET ColId USING ColId {
        auto tmp1 = $2;
        auto tmp2 = new IR(kIdentifier, string($4), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($4);
        res = new IR(kOptCycleClause_4, OP3("CYCLE", "SET", "USING"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($6);
        res = new IR(kOptCycleClause, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptCycleClause, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_with_clause:

    with_clause {
        auto tmp1 = $1;
        res = new IR(kOptWithClause, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptWithClause, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


into_clause:

    INTO OptTempTableName {
        auto tmp1 = $2;
        res = new IR(kIntoClause, OP3("INTO", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kIntoClause, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* Redundancy here is needed to avoid shift/reduce conflicts,
* since TEMP is not a reserved word.  See also OptTemp.
*/

OptTempTableName:

    TEMPORARY opt_table qualified_name {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kOptTempTableName, OP3("TEMPORARY", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp2->set_qualified_name_type(kDataTableName, kDefine);

    }

    | TEMP opt_table qualified_name {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kOptTempTableName, OP3("TEMP", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp2->set_qualified_name_type(kDataTableName, kDefine);

    }

    | LOCAL TEMPORARY opt_table qualified_name {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kOptTempTableName, OP3("LOCAL TEMPORARY", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp2->set_qualified_name_type(kDataTableName, kDefine);
    }

    | LOCAL TEMP opt_table qualified_name {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kOptTempTableName, OP3("LOCAL TEMP", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp2->set_qualified_name_type(kDataTableName, kDefine);
    }

    | GLOBAL TEMPORARY opt_table qualified_name {
        /* Yu: GLOBAL TEMPORARY is not supported. */
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kOptTempTableName, OP3("LOCAL TEMPORARY", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp2->set_qualified_name_type(kDataTableName, kDefine);
    }

    | GLOBAL TEMP opt_table qualified_name {
        /* Yu: GLOBAL TEMP is not supported. */
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kOptTempTableName, OP3("LOCAL TEMP", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp2->set_qualified_name_type(kDataTableName, kDefine);
    }

    | UNLOGGED opt_table qualified_name {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kOptTempTableName, OP3("UNLOGGED", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp2->set_qualified_name_type(kDataTableName, kDefine);
    }

    | TABLE qualified_name {
        auto tmp1 = $2;
        res = new IR(kOptTempTableName, OP3("TABLE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_qualified_name_type(kDataTableName, kDefine);
    }

    | qualified_name {
        auto tmp1 = $1;
        res = new IR(kOptTempTableName, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_qualified_name_type(kDataTableName, kDefine);
    }

;


opt_table:

    TABLE {
        res = new IR(kOptTable, OP3("TABLE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptTable, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


set_quantifier:

    ALL {
        res = new IR(kSetQuantifier, OP3("ALL", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DISTINCT {
        res = new IR(kSetQuantifier, OP3("DISTINCT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kSetQuantifier, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/* We use (NIL) as a placeholder to indicate that all target expressions
* should be placed in the DISTINCT list during parsetree analysis.
*/

distinct_clause:

    DISTINCT {
        res = new IR(kDistinctClause, OP3("DISTINCT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DISTINCT ON '(' expr_list ')' {
        auto tmp1 = $4;
        res = new IR(kDistinctClause, OP3("DISTINCT ON (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_all_clause:

    ALL {
        res = new IR(kOptAllClause, OP3("ALL", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptAllClause, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_distinct_clause:

    distinct_clause {
        auto tmp1 = $1;
        res = new IR(kOptDistinctClause, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | opt_all_clause {
        auto tmp1 = $1;
        res = new IR(kOptDistinctClause, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_sort_clause:

    sort_clause {
        auto tmp1 = $1;
        res = new IR(kOptSortClause, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptSortClause, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


sort_clause:

    ORDER BY sortby_list {
        auto tmp1 = $3;
        res = new IR(kSortClause, OP3("ORDER BY", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


sortby_list:

    sortby {
        auto tmp1 = $1;
        res = new IR(kSortbyList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | sortby_list ',' sortby {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kSortbyList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


sortby:

    a_expr USING qual_all_Op opt_nulls_order {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kSortby_1, OP3("", "USING", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $4;
        res = new IR(kSortby, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr opt_asc_desc opt_nulls_order {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kSortby_2, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $3;
        res = new IR(kSortby, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;



select_limit:

    limit_clause offset_clause {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kSelectLimit, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | offset_clause limit_clause {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kSelectLimit, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | limit_clause {
        auto tmp1 = $1;
        res = new IR(kSelectLimit, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | offset_clause {
        auto tmp1 = $1;
        res = new IR(kSelectLimit, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_select_limit:

    select_limit {
        auto tmp1 = $1;
        res = new IR(kOptSelectLimit, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kOptSelectLimit, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


limit_clause:

    LIMIT select_limit_value {
        auto tmp1 = $2;
        res = new IR(kLimitClause, OP3("LIMIT", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | LIMIT select_limit_value ',' select_offset_value {
        /* Yu: Remove select_offset_value. It is not supported by Postgres.   */
        auto tmp1 = $2;
        auto tmp2 = $4;
        /* tmp2->deep_drop(); */
        rov_ir.push_back(tmp2);
        res = new IR(kLimitClause, OP3("LIMIT", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FETCH first_or_next select_fetch_first_value row_or_rows ONLY {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kLimitClause_1, OP3("FETCH", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $4;
        res = new IR(kLimitClause, OP3("", "", "ONLY"), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FETCH first_or_next select_fetch_first_value row_or_rows WITH TIES {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kLimitClause_2, OP3("FETCH", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $4;
        res = new IR(kLimitClause, OP3("", "", "WITH TIES"), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FETCH first_or_next row_or_rows ONLY {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kLimitClause, OP3("FETCH", "", "ONLY"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FETCH first_or_next row_or_rows WITH TIES {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kLimitClause, OP3("FETCH", "", "WITH TIES"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


offset_clause:

    OFFSET select_offset_value {
        auto tmp1 = $2;
        res = new IR(kOffsetClause, OP3("OFFSET", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | OFFSET select_fetch_first_value row_or_rows {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kOffsetClause, OP3("OFFSET", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


select_limit_value:

    a_expr {
        auto tmp1 = $1;
        res = new IR(kSelectLimitValue, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALL {
        res = new IR(kSelectLimitValue, OP3("ALL", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


select_offset_value:

    a_expr {
        auto tmp1 = $1;
        res = new IR(kSelectOffsetValue, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* Allowing full expressions without parentheses causes various parsing
* problems with the trailing ROW/ROWS key words.  SQL spec only calls for
* <simple value specification>, which is either a literal or a parameter (but
* an <SQL parameter reference> could be an identifier, bringing up conflicts
* with ROW/ROWS). We solve this by leveraging the presence of ONLY (see above)
* to determine whether the expression is missing rather than trying to make it
* optional in this rule.
*
* c_expr covers almost all the spec-required cases (and more), but it doesn't
* cover signed numeric literals, which are allowed by the spec. So we include
* those here explicitly. We need FCONST as well as ICONST because values that
* don't fit in the platform's "long", but do fit in bigint, should still be
* accepted here. (This is possible in 64-bit Windows as well as all 32-bit
* builds.)
*/

select_fetch_first_value:

    c_expr {
        auto tmp1 = $1;
        res = new IR(kSelectFetchFirstValue, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '+' I_or_F_const {
        auto tmp1 = $2;
        res = new IR(kSelectFetchFirstValue, OP3("+", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '-' I_or_F_const {
        auto tmp1 = $2;
        res = new IR(kSelectFetchFirstValue, OP3("-", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


I_or_F_const:

    Iconst {
        auto tmp1 = $1;
        res = new IR(kIOrFConst, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FCONST {
        auto tmp1 = new IR(kFloatLiteral, string($1), kDataLiteral, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        res = new IR(kIOrFConst, OP0(), tmp1);
        all_gen_ir.push_back(res);
        free($1);
        $$ = res;
    }

;

/* noise words */

row_or_rows:

    ROW {
        res = new IR(kRowOrRows, OP3("ROW", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ROWS {
        res = new IR(kRowOrRows, OP3("ROWS", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


first_or_next:

    FIRST_P {
        res = new IR(kFirstOrNext, OP3("FIRST", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NEXT {
        res = new IR(kFirstOrNext, OP3("NEXT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*
* This syntax for group_clause tries to follow the spec quite closely.
* However, the spec allows only column references, not expressions,
* which introduces an ambiguity between implicit row constructors
* (a,b) and lists of column references.
*
* We handle this by using the a_expr production for what the spec calls
* <ordinary grouping set>, which in the spec represents either one column
* reference or a parenthesized list of column references. Then, we check the
* top node of the a_expr to see if it's an implicit RowExpr, and if so, just
* grab and use the list, discarding the node. (this is done in parse analysis,
* not here)
*
* (we abuse the row_format field of RowExpr to distinguish implicit and
* explicit row constructors; it's debatable if anyone sanely wants to use them
* in a group clause, but if they have a reason to, we make it possible.)
*
* Each item in the group_clause list is either an expression tree or a
* GroupingSet node of some type.
*/

group_clause:

    GROUP_P BY set_quantifier group_by_list {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kGroupClause, OP3("GROUP BY", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kGroupClause, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


group_by_list:

    group_by_item {
        auto tmp1 = $1;
        res = new IR(kGroupByList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | group_by_list ',' group_by_item {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kGroupByList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


group_by_item:

    a_expr {
        auto tmp1 = $1;
        res = new IR(kGroupByItem, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | empty_grouping_set {
        auto tmp1 = $1;
        res = new IR(kGroupByItem, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | cube_clause {
        auto tmp1 = $1;
        res = new IR(kGroupByItem, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | rollup_clause {
        auto tmp1 = $1;
        res = new IR(kGroupByItem, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | grouping_sets_clause {
        auto tmp1 = $1;
        res = new IR(kGroupByItem, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


empty_grouping_set:

    '(' ')' {
        res = new IR(kEmptyGroupingSet, OP3("( )", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*
* These hacks rely on setting precedence of CUBE and ROLLUP below that of '(',
* so that they shift in these rules rather than reducing the conflicting
* unreserved_keyword rule.
*/


rollup_clause:

    ROLLUP '(' expr_list ')' {
        auto tmp1 = $3;
        res = new IR(kRollupClause, OP3("ROLLUP (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


cube_clause:

    CUBE '(' expr_list ')' {
        auto tmp1 = $3;
        res = new IR(kCubeClause, OP3("CUBE (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


grouping_sets_clause:

    GROUPING SETS '(' group_by_list ')' {
        auto tmp1 = $4;
        res = new IR(kGroupingSetsClause, OP3("GROUPING SETS (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


having_clause:

    HAVING a_expr {
        auto tmp1 = $2;
        res = new IR(kHavingClause, OP3("HAVING", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kHavingClause, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


for_locking_clause:

    for_locking_items {
        auto tmp1 = $1;
        res = new IR(kForLockingClause, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FOR READ ONLY {
        res = new IR(kForLockingClause, OP3("FOR READ ONLY", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_for_locking_clause:

    for_locking_clause {
        auto tmp1 = $1;
        res = new IR(kOptForLockingClause, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kOptForLockingClause, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


for_locking_items:

    for_locking_item {
        auto tmp1 = $1;
        res = new IR(kForLockingItems, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | for_locking_items for_locking_item {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kForLockingItems, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


for_locking_item:

    for_locking_strength locked_rels_list opt_nowait_or_skip {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kForLockingItem_1, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $3;
        res = new IR(kForLockingItem, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


for_locking_strength:

    FOR UPDATE {
        res = new IR(kForLockingStrength, OP3("FOR UPDATE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FOR NO KEY UPDATE {
        res = new IR(kForLockingStrength, OP3("FOR NO KEY UPDATE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FOR SHARE {
        res = new IR(kForLockingStrength, OP3("FOR SHARE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FOR KEY SHARE {
        res = new IR(kForLockingStrength, OP3("FOR KEY SHARE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


locked_rels_list:

    OF qualified_name_list {
        auto tmp1 = $2;
        res = new IR(kLockedRelsList, OP3("OF", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kLockedRelsList, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*
* We should allow ROW '(' expr_list ')' too, but that seems to require
* making VALUES a fully reserved word, which will probably break more apps
* than allowing the noise-word is worth.
*/

values_clause:

    VALUES '(' expr_list ')' {
        auto tmp1 = $3;
        res = new IR(kValuesClause, OP3("VALUES (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | values_clause ',' '(' expr_list ')' {
        auto tmp1 = $1;
        auto tmp2 = $4;
        res = new IR(kValuesClause, OP3("", ", (", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
*	clauses common to all Optimizable Stmts:
*		from_clause		- allow list of both JOIN expressions and table names
*		where_clause	- qualifications for joins or restrictions
*
*****************************************************************************/


from_clause:

    FROM from_list {
        auto tmp1 = $2;
        res = new IR(kFromClause, OP3("FROM", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kFromClause, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


from_list:

    table_ref {
        auto tmp1 = $1;
        res = new IR(kFromList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | from_list ',' table_ref {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kFromList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* table_ref is where an alias clause can be attached.
*/

table_ref:

    relation_expr opt_alias_clause {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kTableRef, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | relation_expr opt_alias_clause tablesample_clause {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kTableRef_1, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $3;
        res = new IR(kTableRef, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | func_table func_alias_clause {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kTableRef, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | LATERAL_P func_table func_alias_clause {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kTableRef, OP3("LATERAL", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | xmltable opt_alias_clause {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kTableRef, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | LATERAL_P xmltable opt_alias_clause {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kTableRef, OP3("LATERAL", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | select_with_parens opt_alias_clause {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kTableRef, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | LATERAL_P select_with_parens opt_alias_clause {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kTableRef, OP3("LATERAL", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | joined_table {
        auto tmp1 = $1;
        res = new IR(kTableRef, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '(' joined_table ')' alias_clause {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kTableRef, OP3("(", ")", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*
* It may seem silly to separate joined_table from table_ref, but there is
* method in SQL's madness: if you don't do it this way you get reduce-
* reduce conflicts, because it's not clear to the parser generator whether
* to expect alias_clause after ')' or not.  For the same reason we must
* treat 'JOIN' and 'join_type JOIN' separately, rather than allowing
* join_type to expand to empty; if we try it, the parser generator can't
* figure out when to reduce an empty join_type right after table_ref.
*
* Note that a CROSS JOIN is the same as an unqualified
* INNER JOIN, and an INNER JOIN/ON has the same shape
* but a qualification expression to limit membership.
* A NATURAL JOIN implicitly matches column names between
* tables and the shape is determined by which columns are
* in common. We'll collect columns during the later transformations.
*/


joined_table:

    '(' joined_table ')' {
        auto tmp1 = $2;
        res = new IR(kJoinedTable, OP3("(", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | table_ref CROSS JOIN table_ref {
        auto tmp1 = $1;
        auto tmp2 = $4;
        res = new IR(kJoinedTable, OP3("", "CROSS JOIN", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | table_ref join_type JOIN table_ref join_qual {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kJoinedTable_1, OP3("", "", "JOIN"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $4;
        res = new IR(kJoinedTable_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $5;
        res = new IR(kJoinedTable, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | table_ref JOIN table_ref join_qual {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kJoinedTable_3, OP3("", "JOIN", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $4;
        res = new IR(kJoinedTable, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | table_ref NATURAL join_type JOIN table_ref {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kJoinedTable_4, OP3("", "NATURAL", "JOIN"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kJoinedTable, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | table_ref NATURAL JOIN table_ref {
        auto tmp1 = $1;
        auto tmp2 = $4;
        res = new IR(kJoinedTable, OP3("", "NATURAL JOIN", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


alias_clause:

    AS ColId '(' name_list ')' {
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        auto tmp2 = $4;
        res = new IR(kAliasClause, OP3("AS", "(", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_iden_type(kDataAliasTableName, kDefine);
        tmp2->set_name_list_type(kDataAliasName, kDefine);
    }

    | AS ColId {
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        res = new IR(kAliasClause, OP3("AS", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
        tmp1->set_iden_type(kDataAliasName, kDefine);

    }

    | ColId '(' name_list ')' {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = $3;
        res = new IR(kAliasClause, OP3("", "(", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_iden_type(kDataAliasTableName, kDefine);
        tmp2->set_name_list_type(kDataAliasName, kDefine);

    }

    | ColId {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kAliasClause, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_iden_type(kDataAliasName, kDefine);

    }

;


opt_alias_clause:

    alias_clause {
        auto tmp1 = $1;
        res = new IR(kOptAliasClause, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptAliasClause, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* The alias clause after JOIN ... USING only accepts the AS ColId spelling,
* per SQL standard.  (The grammar could parse the other variants, but they
* don't seem to be useful, and it might lead to parser problems in the
* future.)
*/

opt_alias_clause_for_join_using:

    AS ColId {
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        res = new IR(kOptAliasClauseForJoinUsing, OP3("AS", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptAliasClauseForJoinUsing, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* func_alias_clause can include both an Alias and a coldeflist, so we make it
* return a 2-element list that gets disassembled by calling production.
*/

func_alias_clause:

    alias_clause {
        auto tmp1 = $1;
        res = new IR(kFuncAliasClause, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | AS '(' TableFuncElementList ')' {
        auto tmp1 = $3;
        res = new IR(kFuncAliasClause, OP3("AS (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | AS ColId '(' TableFuncElementList ')' {
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        auto tmp2 = $4;
        res = new IR(kFuncAliasClause, OP3("AS", "(", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_iden_type(kDataAliasName, kDefine);
    }

    | ColId '(' TableFuncElementList ')' {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = $3;
        res = new IR(kFuncAliasClause, OP3("", "(", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_iden_type(kDataAliasName, kDefine);
    }

    | /*EMPTY*/ {
        res = new IR(kFuncAliasClause, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


join_type:

    FULL opt_outer {
        auto tmp1 = $2;
        res = new IR(kJoinType, OP3("FULL", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | LEFT opt_outer {
        auto tmp1 = $2;
        res = new IR(kJoinType, OP3("LEFT", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | RIGHT opt_outer {
        auto tmp1 = $2;
        res = new IR(kJoinType, OP3("RIGHT", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | INNER_P {
        res = new IR(kJoinType, OP3("INNER", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/* OUTER is just noise... */

opt_outer:

    OUTER_P {
        res = new IR(kOptOuter, OP3("OUTER", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptOuter, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/* JOIN qualification clauses
* Possibilities are:
*	USING ( column list ) [ AS alias ]
*						  allows only unqualified column names,
*						  which must match between tables.
*	ON expr allows more general qualifications.
*
* We return USING as a two-element List (the first item being a sub-List
* of the common column names, and the second either an Alias item or NULL).
* An ON-expr will not be a List, so it can be told apart that way.
*/


join_qual:

    USING '(' name_list ')' opt_alias_clause_for_join_using {
        auto tmp1 = $3;
        auto tmp2 = $5;
        res = new IR(kJoinQual, OP3("USING (", ")", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ON a_expr {
        auto tmp1 = $2;
        res = new IR(kJoinQual, OP3("ON", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;



relation_expr:

    qualified_name {
        auto tmp1 = $1;
        res = new IR(kRelationExpr, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_qualified_name_type(kDataTableName, kUse);
    }

    | qualified_name '*' {
        auto tmp1 = $1;
        res = new IR(kRelationExpr, OP3("", "*", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_qualified_name_type(kDataTableName, kUse);
    }

    | ONLY qualified_name {
        auto tmp1 = $2;
        res = new IR(kRelationExpr, OP3("ONLY", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_qualified_name_type(kDataTableName, kUse);
    }

    | ONLY '(' qualified_name ')' {
        auto tmp1 = $3;
        res = new IR(kRelationExpr, OP3("ONLY (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_qualified_name_type(kDataTableName, kUse);
    }

;



relation_expr_list:

    relation_expr {
        auto tmp1 = $1;
        res = new IR(kRelationExprList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | relation_expr_list ',' relation_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kRelationExprList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*
* Given "UPDATE foo set set ...", we have to decide without looking any
* further ahead whether the first "set" is an alias or the UPDATE's SET
* keyword.  Since "set" is allowed as a column name both interpretations
* are feasible.  We resolve the shift/reduce conflict by giving the first
* relation_expr_opt_alias production a higher precedence than the SET token
* has, causing the parser to prefer to reduce, in effect assuming that the
* SET is not an alias.
*/

relation_expr_opt_alias:

    relation_expr %prec UMINUS {
        auto tmp1 = $1;
        res = new IR(kRelationExprOptAlias, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | relation_expr ColId {
        auto tmp1 = $1;
        auto tmp2 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($2);
        res = new IR(kRelationExprOptAlias, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | relation_expr AS ColId {
        auto tmp1 = $1;
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kRelationExprOptAlias, OP3("", "AS", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* TABLESAMPLE decoration in a FROM item
*/

tablesample_clause:

    TABLESAMPLE func_name '(' expr_list ')' opt_repeatable_clause {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kTablesampleClause_1, OP3("TABLESAMPLE", "(", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kTablesampleClause, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_repeatable_clause:

    REPEATABLE '(' a_expr ')' {
        auto tmp1 = $3;
        res = new IR(kOptRepeatableClause, OP3("REPEATABLE (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptRepeatableClause, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* func_table represents a function invocation in a FROM list. It can be
* a plain function call, like "foo(...)", or a ROWS FROM expression with
* one or more function calls, "ROWS FROM (foo(...), bar(...))",
* optionally with WITH ORDINALITY attached.
* In the ROWS FROM syntax, a column definition list can be given for each
* function, for example:
*     ROWS FROM (foo() AS (foo_res_a text, foo_res_b text),
*                bar() AS (bar_res_a text, bar_res_b text))
* It's also possible to attach a column definition list to the RangeFunction
* as a whole, but that's handled by the table_ref production.
*/

func_table:

    func_expr_windowless opt_ordinality {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kFuncTable, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ROWS FROM '(' rowsfrom_list ')' opt_ordinality {
        auto tmp1 = $4;
        auto tmp2 = $6;
        res = new IR(kFuncTable, OP3("ROWS FROM (", ")", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


rowsfrom_item:

    func_expr_windowless opt_col_def_list {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kRowsfromItem, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


rowsfrom_list:

    rowsfrom_item {
        auto tmp1 = $1;
        res = new IR(kRowsfromList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | rowsfrom_list ',' rowsfrom_item {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kRowsfromList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_col_def_list:

    AS '(' TableFuncElementList ')' {
        auto tmp1 = $3;
        res = new IR(kOptColDefList, OP3("AS (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptColDefList, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_ordinality:

    WITH_LA ORDINALITY {
        res = new IR(kOptOrdinality, OP3("WITH ORDINALITY", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptOrdinality, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;



where_clause:

    WHERE a_expr {
        auto tmp1 = $2;
        res = new IR(kWhereClause, OP3("WHERE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kWhereClause, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/* variant for UPDATE and DELETE */

where_or_current_clause:

    WHERE a_expr {
        auto tmp1 = $2;
        res = new IR(kWhereOrCurrentClause, OP3("WHERE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | WHERE CURRENT_P OF cursor_name {
        auto tmp1 = new IR(kIdentifier, string($4), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($4);
        res = new IR(kWhereOrCurrentClause, OP3("WHERE CURRENT OF", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kWhereOrCurrentClause, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;



OptTableFuncElementList:

    TableFuncElementList {
        auto tmp1 = $1;
        res = new IR(kOptTableFuncElementList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptTableFuncElementList, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


TableFuncElementList:

    TableFuncElement {
        auto tmp1 = $1;
        res = new IR(kTableFuncElementList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TableFuncElementList ',' TableFuncElement {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kTableFuncElementList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


TableFuncElement:

    ColId Typename opt_collate_clause {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = $2;
        res = new IR(kTableFuncElement_1, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $3;
        res = new IR(kTableFuncElement, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* XMLTABLE
*/

xmltable:

    XMLTABLE '(' c_expr xmlexists_argument COLUMNS xmltable_column_list ')' {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kXmltable_1, OP3("XMLTABLE (", "", "COLUMNS"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kXmltable, OP3("", "", ")"), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | XMLTABLE '(' XMLNAMESPACES '(' xml_namespace_list ')' ',' c_expr xmlexists_argument COLUMNS xmltable_column_list ')' {
        auto tmp1 = $5;
        auto tmp2 = $8;
        res = new IR(kXmltable_2, OP3("XMLTABLE ( XMLNAMESPACES (", ") ,", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $9;
        res = new IR(kXmltable_3, OP3("", "", "COLUMNS"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $11;
        res = new IR(kXmltable, OP3("", "", ")"), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


xmltable_column_list:

    xmltable_column_el {
        auto tmp1 = $1;
        res = new IR(kXmltableColumnList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | xmltable_column_list ',' xmltable_column_el {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kXmltableColumnList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


xmltable_column_el:

    ColId Typename {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = $2;
        res = new IR(kXmltableColumnEl, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_iden_type(kDataColumnName, kUse);
    }

    | ColId Typename xmltable_column_option_list {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = $2;
        res = new IR(kXmltableColumnEl_1, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $3;
        res = new IR(kXmltableColumnEl, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_iden_type(kDataColumnName, kUse);
    }

    | ColId FOR ORDINALITY {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kXmltableColumnEl, OP3("", "FOR ORDINALITY", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_iden_type(kDataColumnName, kUse);
    }

;


xmltable_column_option_list:

    xmltable_column_option_el {
        auto tmp1 = $1;
        res = new IR(kXmltableColumnOptionList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | xmltable_column_option_list xmltable_column_option_el {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kXmltableColumnOptionList, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


xmltable_column_option_el:

    IDENT b_expr {
        auto tmp1 = $2;
        free($1);
        res = new IR(kXmltableColumnOptionEl, OP3("DEFAULT", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DEFAULT b_expr {
        auto tmp1 = $2;
        res = new IR(kXmltableColumnOptionEl, OP3("DEFAULT", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NOT NULL_P {
        res = new IR(kXmltableColumnOptionEl, OP3("NOT NULL", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NULL_P {
        res = new IR(kXmltableColumnOptionEl, OP3("NULL", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


xml_namespace_list:

    xml_namespace_el {
        auto tmp1 = $1;
        res = new IR(kXmlNamespaceList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | xml_namespace_list ',' xml_namespace_el {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kXmlNamespaceList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


xml_namespace_el:

    b_expr AS ColLabel {
        auto tmp1 = $1;
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kXmlNamespaceEl, OP3("", "AS", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DEFAULT b_expr {
        auto tmp1 = $2;
        res = new IR(kXmlNamespaceEl, OP3("DEFAULT", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*****************************************************************************
*
*	Type syntax
*		SQL introduces a large amount of type-specific syntax.
*		Define individual clauses to handle these cases, and use
*		 the generic case to handle regular type-extensible Postgres syntax.
*		- thomas 1997-10-10
*
*****************************************************************************/


Typename:

    SimpleTypename opt_array_bounds {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kTypename, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SETOF SimpleTypename opt_array_bounds {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kTypename, OP3("SETOF", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SimpleTypename ARRAY '[' Iconst ']' {
        auto tmp1 = $1;
        auto tmp2 = $4;
        res = new IR(kTypename, OP3("", "ARRAY [", "]"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SETOF SimpleTypename ARRAY '[' Iconst ']' {
        auto tmp1 = $2;
        auto tmp2 = $5;
        res = new IR(kTypename, OP3("SETOF", "ARRAY [", "]"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SimpleTypename ARRAY {
        auto tmp1 = $1;
        res = new IR(kTypename, OP3("", "ARRAY", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SETOF SimpleTypename ARRAY {
        auto tmp1 = $2;
        res = new IR(kTypename, OP3("SETOF", "ARRAY", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_array_bounds:

    opt_array_bounds '[' ']' {
        auto tmp1 = $1;
        res = new IR(kOptArrayBounds, OP3("", "[ ]", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | opt_array_bounds '[' Iconst ']' {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kOptArrayBounds, OP3("", "[", "]"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptArrayBounds, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


SimpleTypename:

    GenericType {
        auto tmp1 = $1;
        res = new IR(kSimpleTypename, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | Numeric {
        auto tmp1 = $1;
        res = new IR(kSimpleTypename, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | Bit {
        auto tmp1 = $1;
        res = new IR(kSimpleTypename, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | Character {
        auto tmp1 = $1;
        res = new IR(kSimpleTypename, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ConstDatetime {
        auto tmp1 = $1;
        res = new IR(kSimpleTypename, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ConstInterval opt_interval {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kSimpleTypename, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ConstInterval '(' Iconst ')' {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kSimpleTypename, OP3("", "(", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/* We have a separate ConstTypename to allow defaulting fixed-length
* types such as CHAR() and BIT() to an unspecified length.
* SQL9x requires that these default to a length of one, but this
* makes no sense for constructs like CHAR 'hi' and BIT '0101',
* where there is an obvious better choice to make.
* Note that ConstInterval is not included here since it must
* be pushed up higher in the rules to accommodate the postfix
* options (e.g. INTERVAL '1' YEAR). Likewise, we have to handle
* the generic-type-name case in AexprConst to avoid premature
* reduce/reduce conflicts against function names.
*/

ConstTypename:

    Numeric {
        auto tmp1 = $1;
        res = new IR(kConstTypename, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ConstBit {
        auto tmp1 = $1;
        res = new IR(kConstTypename, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ConstCharacter {
        auto tmp1 = $1;
        res = new IR(kConstTypename, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ConstDatetime {
        auto tmp1 = $1;
        res = new IR(kConstTypename, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* GenericType covers all type names that don't have special syntax mandated
* by the standard, including qualified names.  We also allow type modifiers.
* To avoid parsing conflicts against function invocations, the modifiers
* have to be shown as expr_list here, but parse analysis will only accept
* constants for them.
*/

GenericType:

    type_function_name opt_type_modifiers {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = $2;
        res = new IR(kGenericType, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_iden_type(kDataGenericType, kNoModi);
    }

    | type_function_name attrs opt_type_modifiers {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = $2;
        res = new IR(kGenericType_1, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $3;
        res = new IR(kGenericType, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_iden_type(kDataGenericType, kNoModi);

    }

;


opt_type_modifiers:

    '(' expr_list ')' {
        auto tmp1 = $2;
        res = new IR(kOptTypeModifiers, OP3("(", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kOptTypeModifiers, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* SQL numeric data types
*/

Numeric:

    INT_P {
        res = new IR(kNumeric, OP3("INT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | INTEGER {
        res = new IR(kNumeric, OP3("INTEGER", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SMALLINT {
        res = new IR(kNumeric, OP3("SMALLINT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | BIGINT {
        res = new IR(kNumeric, OP3("BIGINT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | REAL {
        res = new IR(kNumeric, OP3("REAL", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FLOAT_P opt_float {
        auto tmp1 = $2;
        res = new IR(kNumeric, OP3("FLOAT", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DOUBLE_P PRECISION {
        res = new IR(kNumeric, OP3("DOUBLE PRECISION", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DECIMAL_P opt_type_modifiers {
        auto tmp1 = $2;
        res = new IR(kNumeric, OP3("DECIMAL", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DEC opt_type_modifiers {
        auto tmp1 = $2;
        res = new IR(kNumeric, OP3("DEC", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NUMERIC opt_type_modifiers {
        auto tmp1 = $2;
        res = new IR(kNumeric, OP3("NUMERIC", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | BOOLEAN_P {
        res = new IR(kNumeric, OP3("BOOLEAN", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_float:

    '(' Iconst ')' {
        auto tmp1 = $2;
        res = new IR(kOptFloat, OP3("(", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptFloat, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* SQL bit-field data types
* The following implements BIT() and BIT VARYING().
*/

Bit:

    BitWithLength {
        auto tmp1 = $1;
        res = new IR(kBit, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | BitWithoutLength {
        auto tmp1 = $1;
        res = new IR(kBit, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/* ConstBit is like Bit except "BIT" defaults to unspecified length */
/* See notes for ConstCharacter, which addresses same issue for "CHAR" */

ConstBit:

    BitWithLength {
        auto tmp1 = $1;
        res = new IR(kConstBit, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | BitWithoutLength {
        auto tmp1 = $1;
        res = new IR(kConstBit, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


BitWithLength:

    BIT opt_varying '(' expr_list ')' {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kBitWithLength, OP3("BIT", "(", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


BitWithoutLength:

    BIT opt_varying {
        auto tmp1 = $2;
        res = new IR(kBitWithoutLength, OP3("BIT", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*
* SQL character data types
* The following implements CHAR() and VARCHAR().
*/

Character:

    CharacterWithLength {
        auto tmp1 = $1;
        res = new IR(kCharacter, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CharacterWithoutLength {
        auto tmp1 = $1;
        res = new IR(kCharacter, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


ConstCharacter:

    CharacterWithLength {
        auto tmp1 = $1;
        res = new IR(kConstCharacter, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CharacterWithoutLength {
        auto tmp1 = $1;
        res = new IR(kConstCharacter, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


CharacterWithLength:

    character '(' Iconst ')' {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kCharacterWithLength, OP3("", "(", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


CharacterWithoutLength:

    character {
        auto tmp1 = $1;
        res = new IR(kCharacterWithoutLength, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


character:

    CHARACTER opt_varying {
        auto tmp1 = $2;
        res = new IR(kCharacter, OP3("CHARACTER", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CHAR_P opt_varying {
        auto tmp1 = $2;
        res = new IR(kCharacter, OP3("CHAR", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | VARCHAR {
        res = new IR(kCharacter, OP3("VARCHAR", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NATIONAL CHARACTER opt_varying {
        auto tmp1 = $3;
        res = new IR(kCharacter, OP3("NATIONAL CHARACTER", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NATIONAL CHAR_P opt_varying {
        auto tmp1 = $3;
        res = new IR(kCharacter, OP3("NATIONAL CHAR", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NCHAR opt_varying {
        auto tmp1 = $2;
        res = new IR(kCharacter, OP3("NCHAR", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_varying:

    VARYING {
        res = new IR(kOptVarying, OP3("VARYING", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptVarying, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* SQL date/time types
*/

ConstDatetime:

    TIMESTAMP '(' Iconst ')' opt_timezone {
        auto tmp1 = $3;
        auto tmp2 = $5;
        res = new IR(kConstDatetime, OP3("TIMESTAMP (", ")", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TIMESTAMP opt_timezone {
        auto tmp1 = $2;
        res = new IR(kConstDatetime, OP3("TIMESTAMP", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TIME '(' Iconst ')' opt_timezone {
        auto tmp1 = $3;
        auto tmp2 = $5;
        res = new IR(kConstDatetime, OP3("TIME (", ")", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TIME opt_timezone {
        auto tmp1 = $2;
        res = new IR(kConstDatetime, OP3("TIME", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


ConstInterval:

    INTERVAL {
        res = new IR(kConstInterval, OP3("INTERVAL", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_timezone:

    WITH_LA TIME ZONE {
        res = new IR(kOptTimezone, OP3("WITH TIME ZONE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | WITHOUT TIME ZONE {
        res = new IR(kOptTimezone, OP3("WITHOUT TIME ZONE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptTimezone, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_interval:

    YEAR_P {
        res = new IR(kOptInterval, OP3("YEAR", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | MONTH_P {
        res = new IR(kOptInterval, OP3("MONTH", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DAY_P {
        res = new IR(kOptInterval, OP3("DAY", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | HOUR_P {
        res = new IR(kOptInterval, OP3("HOUR", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | MINUTE_P {
        res = new IR(kOptInterval, OP3("MINUTE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | interval_second {
        auto tmp1 = $1;
        res = new IR(kOptInterval, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | YEAR_P TO MONTH_P {
        res = new IR(kOptInterval, OP3("YEAR TO MONTH", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DAY_P TO HOUR_P {
        res = new IR(kOptInterval, OP3("DAY TO HOUR", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DAY_P TO MINUTE_P {
        res = new IR(kOptInterval, OP3("DAY TO MINUTE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DAY_P TO interval_second {
        auto tmp1 = $3;
        res = new IR(kOptInterval, OP3("DAY TO", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | HOUR_P TO MINUTE_P {
        res = new IR(kOptInterval, OP3("HOUR TO MINUTE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | HOUR_P TO interval_second {
        auto tmp1 = $3;
        res = new IR(kOptInterval, OP3("HOUR TO", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | MINUTE_P TO interval_second {
        auto tmp1 = $3;
        res = new IR(kOptInterval, OP3("MINUTE TO", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptInterval, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


interval_second:

    SECOND_P {
        res = new IR(kIntervalSecond, OP3("SECOND", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SECOND_P '(' Iconst ')' {
        auto tmp1 = $3;
        res = new IR(kIntervalSecond, OP3("SECOND (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
*	expression grammar
*
*****************************************************************************/

/*
* General expressions
* This is the heart of the expression syntax.
*
* We have two expression types: a_expr is the unrestricted kind, and
* b_expr is a subset that must be used in some places to avoid shift/reduce
* conflicts.  For example, we can't do BETWEEN as "BETWEEN a_expr AND a_expr"
* because that use of AND conflicts with AND as a boolean operator.  So,
* b_expr is used in BETWEEN and we remove boolean keywords from b_expr.
*
* Note that '(' a_expr ')' is a b_expr, so an unrestricted expression can
* always be used by surrounding it with parens.
*
* c_expr is all the productions that are common to a_expr and b_expr;
* it's factored out just to eliminate redundant coding.
*
* Be careful of productions involving more than one terminal token.
* By default, bison will assign such productions the precedence of their
* last terminal, but in nearly all cases you want it to be the precedence
* of the first terminal instead; otherwise you will not get the behavior
* you expect!  So we use %prec annotations freely to set precedences.
*/

a_expr:

    c_expr {
        auto tmp1 = $1;
        res = new IR(kAExpr, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr TYPECAST Typename {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kAExpr, OP3("", "::", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr COLLATE any_name {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kAExpr, OP3("", "COLLATE", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp2->set_any_name_type(kDataCollate, kNoModi);

    }

    | a_expr AT TIME ZONE a_expr %prec AT {
        auto tmp1 = $1;
        auto tmp2 = $5;
        res = new IR(kAExpr, OP3("", "AT TIME ZONE", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '+' a_expr %prec UMINUS {
        auto tmp1 = $2;
        res = new IR(kAExpr, OP3("+", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '-' a_expr %prec UMINUS {
        auto tmp1 = $2;
        res = new IR(kAExpr, OP3("-", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr '+' a_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kAExpr, OP3("", "+", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr '-' a_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kAExpr, OP3("", "-", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr '*' a_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kAExpr, OP3("", "*", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr '/' a_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kAExpr, OP3("", "/", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr '%' a_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kAExpr, OP3("", "%", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr '^' a_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kAExpr, OP3("", "^", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr '<' a_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kAExpr, OP3("", "<", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr '>' a_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kAExpr, OP3("", ">", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr '=' a_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kAExpr, OP3("", "=", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr LESS_EQUALS a_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kAExpr, OP3("", "<=", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr GREATER_EQUALS a_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kAExpr, OP3("", ">=", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr NOT_EQUALS a_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kAExpr, OP3("", "!=", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr qual_Op a_expr %prec Op {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kAExpr_1, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $3;
        res = new IR(kAExpr, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | qual_Op a_expr %prec Op {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kAExpr, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr AND a_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kAExpr, OP3("", "AND", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr OR a_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kAExpr, OP3("", "OR", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NOT a_expr {
        auto tmp1 = $2;
        res = new IR(kAExpr, OP3("NOT", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NOT_LA a_expr %prec NOT {
        auto tmp1 = $2;
        res = new IR(kAExpr, OP3("NOT", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr LIKE a_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kAExpr, OP3("", "LIKE", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr LIKE a_expr ESCAPE a_expr %prec LIKE {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kAExpr_2, OP3("", "LIKE", "ESCAPE"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kAExpr, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr NOT_LA LIKE a_expr %prec NOT_LA {
        auto tmp1 = $1;
        auto tmp2 = $4;
        res = new IR(kAExpr, OP3("", "NOT LIKE", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr NOT_LA LIKE a_expr ESCAPE a_expr %prec NOT_LA {
        auto tmp1 = $1;
        auto tmp2 = $4;
        res = new IR(kAExpr_3, OP3("", "NOT LIKE", "ESCAPE"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kAExpr, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr ILIKE a_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kAExpr, OP3("", "ILIKE", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr ILIKE a_expr ESCAPE a_expr %prec ILIKE {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kAExpr_4, OP3("", "ILIKE", "ESCAPE"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kAExpr, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr NOT_LA ILIKE a_expr %prec NOT_LA {
        auto tmp1 = $1;
        auto tmp2 = $4;
        res = new IR(kAExpr, OP3("", "NOT ILIKE", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr NOT_LA ILIKE a_expr ESCAPE a_expr %prec NOT_LA {
        auto tmp1 = $1;
        auto tmp2 = $4;
        res = new IR(kAExpr_5, OP3("", "NOT ILIKE", "ESCAPE"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kAExpr, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr SIMILAR TO a_expr %prec SIMILAR {
        auto tmp1 = $1;
        auto tmp2 = $4;
        res = new IR(kAExpr, OP3("", "SIMILAR TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr SIMILAR TO a_expr ESCAPE a_expr %prec SIMILAR {
        auto tmp1 = $1;
        auto tmp2 = $4;
        res = new IR(kAExpr_6, OP3("", "SIMILAR TO", "ESCAPE"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kAExpr, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr NOT_LA SIMILAR TO a_expr %prec NOT_LA {
        auto tmp1 = $1;
        auto tmp2 = $5;
        res = new IR(kAExpr, OP3("", "NOT SIMILAR TO", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr NOT_LA SIMILAR TO a_expr ESCAPE a_expr %prec NOT_LA {
        auto tmp1 = $1;
        auto tmp2 = $5;
        res = new IR(kAExpr_7, OP3("", "NOT SIMILAR TO", "ESCAPE"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $7;
        res = new IR(kAExpr, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr IS NULL_P %prec IS {
        auto tmp1 = $1;
        res = new IR(kAExpr, OP3("", "IS NULL", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr ISNULL {
        auto tmp1 = $1;
        res = new IR(kAExpr, OP3("", "ISNULL", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr IS NOT NULL_P %prec IS {
        auto tmp1 = $1;
        res = new IR(kAExpr, OP3("", "IS NOT NULL", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr NOTNULL {
        auto tmp1 = $1;
        res = new IR(kAExpr, OP3("", "NOTNULL", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | row OVERLAPS row {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kAExpr, OP3("", "OVERLAPS", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr IS TRUE_P %prec IS {
        auto tmp1 = $1;
        res = new IR(kAExpr, OP3("", "IS TRUE", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr IS NOT TRUE_P %prec IS {
        auto tmp1 = $1;
        res = new IR(kAExpr, OP3("", "IS NOT TRUE", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr IS FALSE_P %prec IS {
        auto tmp1 = $1;
        res = new IR(kAExpr, OP3("", "IS FALSE", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr IS NOT FALSE_P %prec IS {
        auto tmp1 = $1;
        res = new IR(kAExpr, OP3("", "IS NOT FALSE", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr IS UNKNOWN %prec IS {
        auto tmp1 = $1;
        res = new IR(kAExpr, OP3("", "IS UNKNOWN", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr IS NOT UNKNOWN %prec IS {
        auto tmp1 = $1;
        res = new IR(kAExpr, OP3("", "IS NOT UNKNOWN", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr IS DISTINCT FROM a_expr %prec IS {
        auto tmp1 = $1;
        auto tmp2 = $5;
        res = new IR(kAExpr, OP3("", "IS DISTINCT FROM", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr IS NOT DISTINCT FROM a_expr %prec IS {
        auto tmp1 = $1;
        auto tmp2 = $6;
        res = new IR(kAExpr, OP3("", "IS NOT DISTINCT FROM", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr BETWEEN opt_asymmetric b_expr AND a_expr %prec BETWEEN {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kAExpr_8, OP3("", "BETWEEN", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $4;
        res = new IR(kAExpr_9, OP3("", "", "AND"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $6;
        res = new IR(kAExpr, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr NOT_LA BETWEEN opt_asymmetric b_expr AND a_expr %prec NOT_LA {
        auto tmp1 = $1;
        auto tmp2 = $4;
        res = new IR(kAExpr_10, OP3("", "NOT BETWEEN", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kAExpr_11, OP3("", "", "AND"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $7;
        res = new IR(kAExpr, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr BETWEEN SYMMETRIC b_expr AND a_expr %prec BETWEEN {
        auto tmp1 = $1;
        auto tmp2 = $4;
        res = new IR(kAExpr_12, OP3("", "BETWEEN SYMMETRIC", "AND"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kAExpr, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr NOT_LA BETWEEN SYMMETRIC b_expr AND a_expr %prec NOT_LA {
        auto tmp1 = $1;
        auto tmp2 = $5;
        res = new IR(kAExpr_13, OP3("", "NOT BETWEEN SYMMETRIC", "AND"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $7;
        res = new IR(kAExpr, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr IN_P in_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kAExpr, OP3("", "IN", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr NOT_LA IN_P in_expr %prec NOT_LA {
        auto tmp1 = $1;
        auto tmp2 = $4;
        res = new IR(kAExpr, OP3("", "NOT IN", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr subquery_Op sub_type select_with_parens %prec Op {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kAExpr_14, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $3;
        res = new IR(kAExpr_15, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $4;
        res = new IR(kAExpr, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr subquery_Op sub_type '(' a_expr ')' %prec Op {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kAExpr_16, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $3;
        res = new IR(kAExpr_17, OP3("", "", "("), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $5;
        res = new IR(kAExpr, OP3("", "", ")"), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | UNIQUE select_with_parens {
        /* Yu: UNIQUE is not yet implemented. Removed it.  */
        auto tmp1 = $2;
        res = new IR(kAExpr, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr IS DOCUMENT_P %prec IS {
        auto tmp1 = $1;
        res = new IR(kAExpr, OP3("", "IS DOCUMENT", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr IS NOT DOCUMENT_P %prec IS {
        auto tmp1 = $1;
        res = new IR(kAExpr, OP3("", "IS NOT DOCUMENT", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr IS NORMALIZED %prec IS {
        auto tmp1 = $1;
        res = new IR(kAExpr, OP3("", "IS NORMALIZED", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr IS unicode_normal_form NORMALIZED %prec IS {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kAExpr, OP3("", "IS", "NORMALIZED"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr IS NOT NORMALIZED %prec IS {
        auto tmp1 = $1;
        res = new IR(kAExpr, OP3("", "IS NOT NORMALIZED", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr IS NOT unicode_normal_form NORMALIZED %prec IS {
        auto tmp1 = $1;
        auto tmp2 = $4;
        res = new IR(kAExpr, OP3("", "IS NOT", "NORMALIZED"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DEFAULT {
        res = new IR(kAExpr, OP3("DEFAULT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* Restricted expressions
*
* b_expr is a subset of the complete expression syntax defined by a_expr.
*
* Presently, AND, NOT, IS, and IN are the a_expr keywords that would
* cause trouble in the places where b_expr is used.  For simplicity, we
* just eliminate all the boolean-keyword-operator productions from b_expr.
*/

b_expr:

    c_expr {
        auto tmp1 = $1;
        res = new IR(kBExpr, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | b_expr TYPECAST Typename {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kBExpr, OP3("", "::", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '+' b_expr %prec UMINUS {
        auto tmp1 = $2;
        res = new IR(kBExpr, OP3("+", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '-' b_expr %prec UMINUS {
        auto tmp1 = $2;
        res = new IR(kBExpr, OP3("-", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | b_expr '+' b_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kBExpr, OP3("", "+", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | b_expr '-' b_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kBExpr, OP3("", "-", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | b_expr '*' b_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kBExpr, OP3("", "*", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | b_expr '/' b_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kBExpr, OP3("", "/", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | b_expr '%' b_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kBExpr, OP3("", "%", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | b_expr '^' b_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kBExpr, OP3("", "^", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | b_expr '<' b_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kBExpr, OP3("", "<", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | b_expr '>' b_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kBExpr, OP3("", ">", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | b_expr '=' b_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kBExpr, OP3("", "=", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | b_expr LESS_EQUALS b_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kBExpr, OP3("", "<=", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | b_expr GREATER_EQUALS b_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kBExpr, OP3("", ">=", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | b_expr NOT_EQUALS b_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kBExpr, OP3("", "!=", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | b_expr qual_Op b_expr %prec Op {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kBExpr_1, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $3;
        res = new IR(kBExpr, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | qual_Op b_expr %prec Op {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kBExpr, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | b_expr IS DISTINCT FROM b_expr %prec IS {
        auto tmp1 = $1;
        auto tmp2 = $5;
        res = new IR(kBExpr, OP3("", "IS DISTINCT FROM", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | b_expr IS NOT DISTINCT FROM b_expr %prec IS {
        auto tmp1 = $1;
        auto tmp2 = $6;
        res = new IR(kBExpr, OP3("", "IS NOT DISTINCT FROM", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | b_expr IS DOCUMENT_P %prec IS {
        auto tmp1 = $1;
        res = new IR(kBExpr, OP3("", "IS DOCUMENT", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | b_expr IS NOT DOCUMENT_P %prec IS {
        auto tmp1 = $1;
        res = new IR(kBExpr, OP3("", "IS NOT DOCUMENT", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* Productions that can be used in both a_expr and b_expr.
*
* Note: productions that refer recursively to a_expr or b_expr mostly
* cannot appear here.	However, it's OK to refer to a_exprs that occur
* inside parentheses, such as function arguments; that cannot introduce
* ambiguity to the b_expr syntax.
*/

c_expr:

    columnref {
        auto tmp1 = $1;
        res = new IR(kCExpr, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | AexprConst {
        auto tmp1 = $1;
        res = new IR(kCExpr, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | PARAM opt_indirection {
        auto tmp1 = $2;
        res = new IR(kCExpr, OP3("PARAM", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '(' a_expr ')' opt_indirection {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kCExpr, OP3("(", ")", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | case_expr {
        auto tmp1 = $1;
        res = new IR(kCExpr, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | func_expr {
        auto tmp1 = $1;
        res = new IR(kCExpr, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | select_with_parens %prec UMINUS {
        auto tmp1 = $1;
        res = new IR(kCExpr, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | select_with_parens indirection {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kCExpr, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | EXISTS select_with_parens {
        auto tmp1 = $2;
        res = new IR(kCExpr, OP3("EXISTS", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ARRAY select_with_parens {
        auto tmp1 = $2;
        res = new IR(kCExpr, OP3("ARRAY", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ARRAY array_expr {
        auto tmp1 = $2;
        res = new IR(kCExpr, OP3("ARRAY", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | explicit_row {
        auto tmp1 = $1;
        res = new IR(kCExpr, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | implicit_row {
        auto tmp1 = $1;
        res = new IR(kCExpr, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | GROUPING '(' expr_list ')' {
        auto tmp1 = $3;
        res = new IR(kCExpr, OP3("GROUPING (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


func_application:

    func_name '(' ')' {
        auto tmp1 = $1;
        res = new IR(kFuncApplication, OP3("", "( )", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | func_name '(' func_arg_list opt_sort_clause ')' {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kFuncApplication_1, OP3("", "(", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $4;
        res = new IR(kFuncApplication, OP3("", "", ")"), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | func_name '(' VARIADIC func_arg_expr opt_sort_clause ')' {
        auto tmp1 = $1;
        auto tmp2 = $4;
        res = new IR(kFuncApplication_2, OP3("", "( VARIADIC", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kFuncApplication, OP3("", "", ")"), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | func_name '(' func_arg_list ',' VARIADIC func_arg_expr opt_sort_clause ')' {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kFuncApplication_3, OP3("", "(", ", VARIADIC"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kFuncApplication_4, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $7;
        res = new IR(kFuncApplication, OP3("", "", ")"), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | func_name '(' ALL func_arg_list opt_sort_clause ')' {
        auto tmp1 = $1;
        auto tmp2 = $4;
        res = new IR(kFuncApplication_5, OP3("", "( ALL", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kFuncApplication, OP3("", "", ")"), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | func_name '(' DISTINCT func_arg_list opt_sort_clause ')' {
        auto tmp1 = $1;
        auto tmp2 = $4;
        res = new IR(kFuncApplication_6, OP3("", "( DISTINCT", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kFuncApplication, OP3("", "", ")"), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | func_name '(' '*' ')' {
        auto tmp1 = $1;
        res = new IR(kFuncApplication, OP3("", "( * )", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*
* func_expr and its cousin func_expr_windowless are split out from c_expr just
* so that we have classifications for "everything that is a function call or
* looks like one".  This isn't very important, but it saves us having to
* document which variants are legal in places like "FROM function()" or the
* backwards-compatible functional-index syntax for CREATE INDEX.
* (Note that many of the special SQL functions wouldn't actually make any
* sense as functional index entries, but we ignore that consideration here.)
*/

func_expr:

    func_application within_group_clause filter_clause over_clause {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kFuncExpr_1, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $3;
        res = new IR(kFuncExpr_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $4;
        res = new IR(kFuncExpr, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | func_expr_common_subexpr {
        auto tmp1 = $1;
        res = new IR(kFuncExpr, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* As func_expr but does not accept WINDOW functions directly
* (but they can still be contained in arguments for functions etc).
* Use this when window expressions are not allowed, where needed to
* disambiguate the grammar (e.g. in CREATE INDEX).
*/

func_expr_windowless:

    func_application {
        auto tmp1 = $1;
        res = new IR(kFuncExprWindowless, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | func_expr_common_subexpr {
        auto tmp1 = $1;
        res = new IR(kFuncExprWindowless, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* Special expressions that are considered to be functions.
*/

func_expr_common_subexpr:

    COLLATION FOR '(' a_expr ')' {
        auto tmp1 = $4;
        res = new IR(kFuncExprCommonSubexpr, OP3("COLLATION FOR (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CURRENT_DATE {
        res = new IR(kFuncExprCommonSubexpr, OP3("CURRENT_DATE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CURRENT_TIME {
        res = new IR(kFuncExprCommonSubexpr, OP3("CURRENT_TIME", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CURRENT_TIME '(' Iconst ')' {
        auto tmp1 = $3;
        res = new IR(kFuncExprCommonSubexpr, OP3("CURRENT_TIME (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CURRENT_TIMESTAMP {
        res = new IR(kFuncExprCommonSubexpr, OP3("CURRENT_TIMESTAMP", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CURRENT_TIMESTAMP '(' Iconst ')' {
        auto tmp1 = $3;
        res = new IR(kFuncExprCommonSubexpr, OP3("CURRENT_TIMESTAMP (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | LOCALTIME {
        res = new IR(kFuncExprCommonSubexpr, OP3("LOCALTIME", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | LOCALTIME '(' Iconst ')' {
        auto tmp1 = $3;
        res = new IR(kFuncExprCommonSubexpr, OP3("LOCALTIME (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | LOCALTIMESTAMP {
        res = new IR(kFuncExprCommonSubexpr, OP3("LOCALTIMESTAMP", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | LOCALTIMESTAMP '(' Iconst ')' {
        auto tmp1 = $3;
        res = new IR(kFuncExprCommonSubexpr, OP3("LOCALTIMESTAMP (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CURRENT_ROLE {
        res = new IR(kFuncExprCommonSubexpr, OP3("CURRENT_ROLE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CURRENT_USER {
        res = new IR(kFuncExprCommonSubexpr, OP3("CURRENT_USER", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SESSION_USER {
        res = new IR(kFuncExprCommonSubexpr, OP3("SESSION_USER", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | USER {
        res = new IR(kFuncExprCommonSubexpr, OP3("USER", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CURRENT_CATALOG {
        res = new IR(kFuncExprCommonSubexpr, OP3("CURRENT_CATALOG", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CURRENT_SCHEMA {
        res = new IR(kFuncExprCommonSubexpr, OP3("CURRENT_SCHEMA", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CAST '(' a_expr AS Typename ')' {
        auto tmp1 = $3;
        auto tmp2 = $5;
        res = new IR(kFuncExprCommonSubexpr, OP3("CAST (", "AS", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | EXTRACT '(' extract_list ')' {
        auto tmp1 = $3;
        res = new IR(kFuncExprCommonSubexpr, OP3("EXTRACT (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NORMALIZE '(' a_expr ')' {
        auto tmp1 = $3;
        res = new IR(kFuncExprCommonSubexpr, OP3("NORMALIZE (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NORMALIZE '(' a_expr ',' unicode_normal_form ')' {
        auto tmp1 = $3;
        auto tmp2 = $5;
        res = new IR(kFuncExprCommonSubexpr, OP3("NORMALIZE (", ",", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | OVERLAY '(' overlay_list ')' {
        auto tmp1 = $3;
        res = new IR(kFuncExprCommonSubexpr, OP3("OVERLAY (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | OVERLAY '(' func_arg_list_opt ')' {
        auto tmp1 = $3;
        res = new IR(kFuncExprCommonSubexpr, OP3("OVERLAY (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | POSITION '(' position_list ')' {
        auto tmp1 = $3;
        res = new IR(kFuncExprCommonSubexpr, OP3("POSITION (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SUBSTRING '(' substr_list ')' {
        auto tmp1 = $3;
        res = new IR(kFuncExprCommonSubexpr, OP3("SUBSTRING (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SUBSTRING '(' func_arg_list_opt ')' {
        auto tmp1 = $3;
        res = new IR(kFuncExprCommonSubexpr, OP3("SUBSTRING (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TREAT '(' a_expr AS Typename ')' {
        auto tmp1 = $3;
        auto tmp2 = $5;
        res = new IR(kFuncExprCommonSubexpr, OP3("TREAT (", "AS", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TRIM '(' BOTH trim_list ')' {
        auto tmp1 = $4;
        res = new IR(kFuncExprCommonSubexpr, OP3("TRIM ( BOTH", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TRIM '(' LEADING trim_list ')' {
        auto tmp1 = $4;
        res = new IR(kFuncExprCommonSubexpr, OP3("TRIM ( LEADING", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TRIM '(' TRAILING trim_list ')' {
        auto tmp1 = $4;
        res = new IR(kFuncExprCommonSubexpr, OP3("TRIM ( TRAILING", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TRIM '(' trim_list ')' {
        auto tmp1 = $3;
        res = new IR(kFuncExprCommonSubexpr, OP3("TRIM (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NULLIF '(' a_expr ',' a_expr ')' {
        auto tmp1 = $3;
        auto tmp2 = $5;
        res = new IR(kFuncExprCommonSubexpr, OP3("NULLIF (", ",", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | COALESCE '(' expr_list ')' {
        auto tmp1 = $3;
        res = new IR(kFuncExprCommonSubexpr, OP3("COALESCE (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | GREATEST '(' expr_list ')' {
        auto tmp1 = $3;
        res = new IR(kFuncExprCommonSubexpr, OP3("GREATEST (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | LEAST '(' expr_list ')' {
        auto tmp1 = $3;
        res = new IR(kFuncExprCommonSubexpr, OP3("LEAST (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | XMLCONCAT '(' expr_list ')' {
        auto tmp1 = $3;
        res = new IR(kFuncExprCommonSubexpr, OP3("XMLCONCAT (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | XMLELEMENT '(' NAME_P ColLabel ')' {
        auto tmp1 = new IR(kIdentifier, string($4), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($4);
        res = new IR(kFuncExprCommonSubexpr, OP3("XMLELEMENT ( NAME", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | XMLELEMENT '(' NAME_P ColLabel ',' xml_attributes ')' {
        auto tmp1 = new IR(kIdentifier, string($4), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($4);
        auto tmp2 = $6;
        res = new IR(kFuncExprCommonSubexpr, OP3("XMLELEMENT ( NAME", ",", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | XMLELEMENT '(' NAME_P ColLabel ',' expr_list ')' {
        auto tmp1 = new IR(kIdentifier, string($4), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($4);
        auto tmp2 = $6;
        res = new IR(kFuncExprCommonSubexpr, OP3("XMLELEMENT ( NAME", ",", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | XMLELEMENT '(' NAME_P ColLabel ',' xml_attributes ',' expr_list ')' {
        auto tmp1 = new IR(kIdentifier, string($4), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($4);
        auto tmp2 = $6;
        res = new IR(kFuncExprCommonSubexpr_1, OP3("XMLELEMENT ( NAME", ",", ","), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $8;
        res = new IR(kFuncExprCommonSubexpr, OP3("", "", ")"), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | XMLEXISTS '(' c_expr xmlexists_argument ')' {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kFuncExprCommonSubexpr, OP3("XMLEXISTS (", "", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | XMLFOREST '(' xml_attribute_list ')' {
        auto tmp1 = $3;
        res = new IR(kFuncExprCommonSubexpr, OP3("XMLFOREST (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | XMLPARSE '(' document_or_content a_expr xml_whitespace_option ')' {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kFuncExprCommonSubexpr_2, OP3("XMLPARSE (", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kFuncExprCommonSubexpr, OP3("", "", ")"), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | XMLPI '(' NAME_P ColLabel ')' {
        auto tmp1 = new IR(kIdentifier, string($4), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($4);
        res = new IR(kFuncExprCommonSubexpr, OP3("XMLPI ( NAME", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | XMLPI '(' NAME_P ColLabel ',' a_expr ')' {
        auto tmp1 = new IR(kIdentifier, string($4), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($4);
        auto tmp2 = $6;
        res = new IR(kFuncExprCommonSubexpr, OP3("XMLPI ( NAME", ",", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | XMLROOT '(' a_expr ',' xml_root_version opt_xml_root_standalone ')' {
        auto tmp1 = $3;
        auto tmp2 = $5;
        res = new IR(kFuncExprCommonSubexpr_3, OP3("XMLROOT (", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kFuncExprCommonSubexpr, OP3("", "", ")"), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | XMLSERIALIZE '(' document_or_content a_expr AS SimpleTypename ')' {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kFuncExprCommonSubexpr_4, OP3("XMLSERIALIZE (", "", "AS"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $6;
        res = new IR(kFuncExprCommonSubexpr, OP3("", "", ")"), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* SQL/XML support
*/

xml_root_version:

    VERSION_P a_expr {
        auto tmp1 = $2;
        res = new IR(kXmlRootVersion, OP3("VERSION", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | VERSION_P NO VALUE_P {
        res = new IR(kXmlRootVersion, OP3("VERSION NO VALUE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_xml_root_standalone:

    ',' STANDALONE_P YES_P {
        res = new IR(kOptXmlRootStandalone, OP3(", STANDALONE YES", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ',' STANDALONE_P NO {
        res = new IR(kOptXmlRootStandalone, OP3(", STANDALONE NO", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ',' STANDALONE_P NO VALUE_P {
        res = new IR(kOptXmlRootStandalone, OP3(", STANDALONE NO VALUE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptXmlRootStandalone, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


xml_attributes:

    XMLATTRIBUTES '(' xml_attribute_list ')' {
        auto tmp1 = $3;
        res = new IR(kXmlAttributes, OP3("XMLATTRIBUTES (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


xml_attribute_list:

    xml_attribute_el {
        auto tmp1 = $1;
        res = new IR(kXmlAttributeList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | xml_attribute_list ',' xml_attribute_el {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kXmlAttributeList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


xml_attribute_el:

    a_expr AS ColLabel {
        auto tmp1 = $1;
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kXmlAttributeEl, OP3("", "AS", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr {
        auto tmp1 = $1;
        res = new IR(kXmlAttributeEl, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


document_or_content:

    DOCUMENT_P {
        res = new IR(kDocumentOrContent, OP3("DOCUMENT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CONTENT_P {
        res = new IR(kDocumentOrContent, OP3("CONTENT", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


xml_whitespace_option:

    PRESERVE WHITESPACE_P {
        res = new IR(kXmlWhitespaceOption, OP3("PRESERVE WHITESPACE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | STRIP_P WHITESPACE_P {
        res = new IR(kXmlWhitespaceOption, OP3("STRIP WHITESPACE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kXmlWhitespaceOption, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/* We allow several variants for SQL and other compatibility. */

xmlexists_argument:

    PASSING c_expr {
        auto tmp1 = $2;
        res = new IR(kXmlexistsArgument, OP3("PASSING", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | PASSING c_expr xml_passing_mech {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kXmlexistsArgument, OP3("PASSING", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | PASSING xml_passing_mech c_expr {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kXmlexistsArgument, OP3("PASSING", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | PASSING xml_passing_mech c_expr xml_passing_mech {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kXmlexistsArgument_1, OP3("PASSING", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $4;
        res = new IR(kXmlexistsArgument, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


xml_passing_mech:

    BY REF {
        res = new IR(kXmlPassingMech, OP3("BY REF", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | BY VALUE_P {
        res = new IR(kXmlPassingMech, OP3("BY VALUE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*
* Aggregate decoration clauses
*/

within_group_clause:

    WITHIN GROUP_P '(' sort_clause ')' {
        auto tmp1 = $4;
        res = new IR(kWithinGroupClause, OP3("WITHIN GROUP (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kWithinGroupClause, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


filter_clause:

    FILTER '(' WHERE a_expr ')' {
        auto tmp1 = $4;
        res = new IR(kFilterClause, OP3("FILTER ( WHERE", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kFilterClause, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*
* Window Definitions
*/

window_clause:

    WINDOW window_definition_list {
        auto tmp1 = $2;
        res = new IR(kWindowClause, OP3("WINDOW", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kWindowClause, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


window_definition_list:

    window_definition {
        auto tmp1 = $1;
        res = new IR(kWindowDefinitionList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | window_definition_list ',' window_definition {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kWindowDefinitionList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


window_definition:

    ColId AS window_specification {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = $3;
        res = new IR(kWindowDefinition, OP3("", "AS", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


over_clause:

    OVER window_specification {
        auto tmp1 = $2;
        res = new IR(kOverClause, OP3("OVER", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | OVER ColId {
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        res = new IR(kOverClause, OP3("OVER", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOverClause, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


window_specification:

    '(' opt_existing_window_name opt_partition_clause opt_sort_clause opt_frame_clause ')' {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kWindowSpecification_1, OP3("(", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $4;
        res = new IR(kWindowSpecification_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $5;
        res = new IR(kWindowSpecification, OP3("", "", ")"), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* If we see PARTITION, RANGE, ROWS or GROUPS as the first token after the '('
* of a window_specification, we want the assumption to be that there is
* no existing_window_name; but those keywords are unreserved and so could
* be ColIds.  We fix this by making them have the same precedence as IDENT
* and giving the empty production here a slightly higher precedence, so
* that the shift/reduce conflict is resolved in favor of reducing the rule.
* These keywords are thus precluded from being an existing_window_name but
* are not reserved for any other purpose.
*/

opt_existing_window_name:

    ColId {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kOptExistingWindowName, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | %prec Op {
        res = new IR(kOptExistingWindowName, OP0());
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_partition_clause:

    PARTITION BY expr_list {
        auto tmp1 = $3;
        res = new IR(kOptPartitionClause, OP3("PARTITION BY", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;


    }

    | /*EMPTY*/ {
        res = new IR(kOptPartitionClause, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* For frame clauses, we return a WindowDef, but only some fields are used:
* frameOptions, startOffset, and endOffset.
*/

opt_frame_clause:

    RANGE frame_extent opt_window_exclusion_clause {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kOptFrameClause, OP3("RANGE", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ROWS frame_extent opt_window_exclusion_clause {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kOptFrameClause, OP3("ROWS", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | GROUPS frame_extent opt_window_exclusion_clause {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kOptFrameClause, OP3("GROUPS", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptFrameClause, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


frame_extent:

    frame_bound {
        /* Yu: Avoid unsupported bound options.  */
        auto tmp1 = $1;
        if (!strcmp(tmp1->get_prefix(), "UNBOUNDED FOLLOWING") || !strcmp(tmp1->get_prefix(), "FOLLOWING")) {
            /* tmp1->deep_drop(); */
            rov_ir.push_back(tmp1);
            tmp1 = new IR(kFrameBound, OP3("CURRENT ROW", "", ""));
            all_gen_ir.push_back(tmp1);
        }
        res = new IR(kFrameExtent, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | BETWEEN frame_bound AND frame_bound {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kFrameExtent, OP3("BETWEEN", "AND", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* This is used for both frame start and frame end, with output set up on
* the assumption it's frame start; the frame_extent productions must reject
* invalid cases.
*/

frame_bound:

    UNBOUNDED PRECEDING {
        res = new IR(kFrameBound, OP3("UNBOUNDED PRECEDING", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | UNBOUNDED FOLLOWING {
        res = new IR(kFrameBound, OP3("UNBOUNDED FOLLOWING", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | CURRENT_P ROW {
        res = new IR(kFrameBound, OP3("CURRENT ROW", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr PRECEDING {
        auto tmp1 = $1;
        res = new IR(kFrameBound, OP3("", "PRECEDING", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr FOLLOWING {
        auto tmp1 = $1;
        res = new IR(kFrameBound, OP3("", "FOLLOWING", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_window_exclusion_clause:

    EXCLUDE CURRENT_P ROW {
        res = new IR(kOptWindowExclusionClause, OP3("EXCLUDE CURRENT ROW", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | EXCLUDE GROUP_P {
        res = new IR(kOptWindowExclusionClause, OP3("EXCLUDE GROUP", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | EXCLUDE TIES {
        res = new IR(kOptWindowExclusionClause, OP3("EXCLUDE TIES", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | EXCLUDE NO OTHERS {
        res = new IR(kOptWindowExclusionClause, OP3("EXCLUDE NO OTHERS", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptWindowExclusionClause, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*
* Supporting nonterminals for expressions.
*/

/* Explicit row production.
*
* SQL99 allows an optional ROW keyword, so we can now do single-element rows
* without conflicting with the parenthesized a_expr production.  Without the
* ROW keyword, there must be more than one a_expr inside the parens.
*/

row:

    ROW '(' expr_list ')' {
        auto tmp1 = $3;
        res = new IR(kRow, OP3("ROW (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ROW '(' ')' {
        res = new IR(kRow, OP3("ROW ( )", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '(' expr_list ',' a_expr ')' {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kRow, OP3("(", ",", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


explicit_row:

    ROW '(' expr_list ')' {
        auto tmp1 = $3;
        res = new IR(kExplicitRow, OP3("ROW (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ROW '(' ')' {
        res = new IR(kExplicitRow, OP3("ROW ( )", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


implicit_row:

    '(' expr_list ',' a_expr ')' {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kImplicitRow, OP3("(", ",", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


sub_type:

    ANY {
        res = new IR(kSubType, OP3("ANY", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SOME {
        res = new IR(kSubType, OP3("SOME", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ALL {
        res = new IR(kSubType, OP3("ALL", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


all_Op:

    Op {
        res = new IR(kAllOp, string($1));
        all_gen_ir.push_back(res);
        free($1);
        $$ = res;
    }

    | MathOp {
        auto tmp1 = $1;
        res = new IR(kAllOp, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


MathOp:

    '+' {
        res = new IR(kMathOp, OP3("+", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '-' {
        res = new IR(kMathOp, OP3("-", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '*' {
        res = new IR(kMathOp, OP3("*", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '/' {
        res = new IR(kMathOp, OP3("/", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '%' {
        res = new IR(kMathOp, OP3("%", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '^' {
        res = new IR(kMathOp, OP3("^", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '<' {
        res = new IR(kMathOp, OP3("<", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '>' {
        res = new IR(kMathOp, OP3(">", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '=' {
        res = new IR(kMathOp, OP3("=", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | LESS_EQUALS {
        res = new IR(kMathOp, OP3("<=", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | GREATER_EQUALS {
        res = new IR(kMathOp, OP3(">=", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NOT_EQUALS {
        res = new IR(kMathOp, OP3("!=", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


qual_Op:

    Op {
        res = new IR(kQualOp, string($1));
        all_gen_ir.push_back(res);
        free($1);
        $$ = res;
    }

    | OPERATOR '(' any_operator ')' {
        auto tmp1 = $3;
        res = new IR(kQualOp, OP3("OPERATOR (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


qual_all_Op:

    all_Op {
        auto tmp1 = $1;
        res = new IR(kQualAllOp, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | OPERATOR '(' any_operator ')' {
        auto tmp1 = $3;
        res = new IR(kQualAllOp, OP3("OPERATOR (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


subquery_Op:

    all_Op {
        auto tmp1 = $1;
        res = new IR(kSubqueryOp, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | OPERATOR '(' any_operator ')' {
        auto tmp1 = $3;
        res = new IR(kSubqueryOp, OP3("OPERATOR (", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | LIKE {
        res = new IR(kSubqueryOp, OP3("LIKE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NOT_LA LIKE {
        res = new IR(kSubqueryOp, OP3("NOT LIKE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ILIKE {
        res = new IR(kSubqueryOp, OP3("ILIKE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NOT_LA ILIKE {
        res = new IR(kSubqueryOp, OP3("NOT ILIKE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


expr_list:

    a_expr {
        auto tmp1 = $1;
        res = new IR(kExprList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | expr_list ',' a_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kExprList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/* function arguments can have names */

func_arg_list:

    func_arg_expr {
        auto tmp1 = $1;
        res = new IR(kFuncArgList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | func_arg_list ',' func_arg_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kFuncArgList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


func_arg_expr:

    a_expr {
        auto tmp1 = $1;
        res = new IR(kFuncArgExpr, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | param_name COLON_EQUALS a_expr {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = $3;
        res = new IR(kFuncArgExpr, OP3("", ":=", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | param_name EQUALS_GREATER a_expr {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = $3;
        res = new IR(kFuncArgExpr, OP3("", "=>", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


func_arg_list_opt:

    func_arg_list {
        auto tmp1 = $1;
        res = new IR(kFuncArgListOpt, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kFuncArgListOpt, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


type_list:

    Typename {
        auto tmp1 = $1;
        res = new IR(kTypeList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | type_list ',' Typename {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kTypeList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


array_expr:

    '[' expr_list ']' {
        auto tmp1 = $2;
        res = new IR(kArrayExpr, OP3("[", "]", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '[' array_expr_list ']' {
        auto tmp1 = $2;
        res = new IR(kArrayExpr, OP3("[", "]", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '[' ']' {
        res = new IR(kArrayExpr, OP3("[ ]", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


array_expr_list:

    array_expr {
        auto tmp1 = $1;
        res = new IR(kArrayExprList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | array_expr_list ',' array_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kArrayExprList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;



extract_list:

    extract_arg FROM a_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kExtractList, OP3("", "FROM", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/* Allow delimited string Sconst in extract_arg as an SQL extension.
* - thomas 2001-04-12
*/

extract_arg:

    IDENT {
        /* Yu: The IDENT is used for extensions.
        ** However, it is rare for us to encounter these cases, and IDENT can produce a lot of semantic error.
        ** Ignore IDENT and change it to DAY as default.
        */
        free($1);
        res = new IR(kExtractArg, OP3("DAY", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | YEAR_P {
        res = new IR(kExtractArg, OP3("YEAR", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | MONTH_P {
        res = new IR(kExtractArg, OP3("MONTH", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | DAY_P {
        res = new IR(kExtractArg, OP3("DAY", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | HOUR_P {
        res = new IR(kExtractArg, OP3("HOUR", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | MINUTE_P {
        res = new IR(kExtractArg, OP3("MINUTE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | SECOND_P {
        res = new IR(kExtractArg, OP3("SECOND", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | Sconst {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kExtractArg, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


unicode_normal_form:

    NFC {
        res = new IR(kUnicodeNormalForm, OP3("NFC", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NFD {
        res = new IR(kUnicodeNormalForm, OP3("NFD", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NFKC {
        res = new IR(kUnicodeNormalForm, OP3("NFKC", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NFKD {
        res = new IR(kUnicodeNormalForm, OP3("NFKD", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/* OVERLAY() arguments */

overlay_list:

    a_expr PLACING a_expr FROM a_expr FOR a_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kOverlayList_1, OP3("", "PLACING", "FROM"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kOverlayList_2, OP3("", "", "FOR"), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $7;
        res = new IR(kOverlayList, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr PLACING a_expr FROM a_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kOverlayList_3, OP3("", "PLACING", "FROM"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kOverlayList, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/* position_list uses b_expr not a_expr to avoid conflict with general IN */

position_list:

    b_expr IN_P b_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kPositionList, OP3("", "IN", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* SUBSTRING() arguments
*
* Note that SQL:1999 has both
*     text FROM int FOR int
* and
*     text FROM pattern FOR escape
*
* In the parser we map them both to a call to the substring() function and
* rely on type resolution to pick the right one.
*
* In SQL:2003, the second variant was changed to
*     text SIMILAR pattern ESCAPE escape
* We could in theory map that to a different function internally, but
* since we still support the SQL:1999 version, we don't.  However,
* ruleutils.c will reverse-list the call in the newer style.
*/

substr_list:

    a_expr FROM a_expr FOR a_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kSubstrList_1, OP3("", "FROM", "FOR"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kSubstrList, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr FOR a_expr FROM a_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kSubstrList_2, OP3("", "FOR", "FROM"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kSubstrList, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr FROM a_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kSubstrList, OP3("", "FROM", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr FOR a_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kSubstrList, OP3("", "FOR", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr SIMILAR a_expr ESCAPE a_expr {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kSubstrList_3, OP3("", "SIMILAR", "ESCAPE"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $5;
        res = new IR(kSubstrList, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


trim_list:

    a_expr FROM expr_list {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kTrimList, OP3("", "FROM", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FROM expr_list {
        auto tmp1 = $2;
        res = new IR(kTrimList, OP3("FROM", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | expr_list {
        auto tmp1 = $1;
        res = new IR(kTrimList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


in_expr:

    select_with_parens {
        auto tmp1 = $1;
        res = new IR(kInExpr, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '(' expr_list ')' {
        auto tmp1 = $2;
        res = new IR(kInExpr, OP3("(", ")", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* Define SQL-style CASE clause.
* - Full specification
*	CASE WHEN a = b THEN c ... ELSE d END
* - Implicit argument
*	CASE a WHEN b THEN c ... ELSE d END
*/

case_expr:

    CASE case_arg when_clause_list case_default END_P {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kCaseExpr_1, OP3("CASE", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $4;
        res = new IR(kCaseExpr, OP3("", "", "END"), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


when_clause_list:

    when_clause {
        auto tmp1 = $1;
        res = new IR(kWhenClauseList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | when_clause_list when_clause {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kWhenClauseList, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


when_clause:

    WHEN a_expr THEN a_expr {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kWhenClause, OP3("WHEN", "THEN", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


case_default:

    ELSE a_expr {
        auto tmp1 = $2;
        res = new IR(kCaseDefault, OP3("ELSE", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kCaseDefault, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


case_arg:

    a_expr {
        auto tmp1 = $1;
        res = new IR(kCaseArg, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kCaseArg, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


columnref:

    ColId {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kColumnref, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1 -> set_iden_type(kDataColumnName, kUse);
    }

    | ColId indirection {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = $2;
        res = new IR(kColumnref, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1 -> set_iden_type(kDataTableNameFollow, kUse);
    }

;


indirection_el:

    '.' attr_name {
        auto tmp1 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($2);
        res = new IR(kIndirectionEl, OP3(".", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp1->set_iden_type(kDataColumnNameFollow, kUse);
    }

    | '.' '*' {
        res = new IR(kIndirectionEl, OP3(". *", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '[' a_expr ']' {
        auto tmp1 = $2;
        res = new IR(kIndirectionEl, OP3("[", "]", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '[' opt_slice_bound ':' opt_slice_bound ']' {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kIndirectionEl, OP3("[", ":", "]"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_slice_bound:

    a_expr {
        auto tmp1 = $1;
        res = new IR(kOptSliceBound, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptSliceBound, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


indirection:

    indirection_el {
        auto tmp1 = $1;
        res = new IR(kIndirection, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | indirection indirection_el {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kIndirection, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_indirection:

    /*EMPTY*/ {
        res = new IR(kOptIndirection, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | opt_indirection indirection_el {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kOptIndirection, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


opt_asymmetric:

    ASYMMETRIC {
        res = new IR(kOptAsymmetric, OP3("ASYMMETRIC", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptAsymmetric, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
*	target list for SELECT
*
*****************************************************************************/


opt_target_list:

    target_list {
        auto tmp1 = $1;
        res = new IR(kOptTargetList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | /* EMPTY */ {
        res = new IR(kOptTargetList, OP3("", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


target_list:

    target_el {
        auto tmp1 = $1;
        res = new IR(kTargetList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | target_list ',' target_el {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kTargetList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


target_el:

    a_expr AS ColLabel {
        auto tmp1 = $1;
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kTargetEl, OP3("", "AS", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;

        tmp2->set_iden_type(kDataAliasName, kDefine);
    }

    | a_expr BareColLabel {
        auto tmp1 = $1;
        auto tmp2 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($2);
        res = new IR(kTargetEl, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | a_expr {
        auto tmp1 = $1;
        res = new IR(kTargetEl, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '*' {
        res = new IR(kTargetEl, OP3("*", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
*	Names and constants
*
*****************************************************************************/


qualified_name_list:

    qualified_name {
        auto tmp1 = $1;
        res = new IR(kQualifiedNameList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | qualified_name_list ',' qualified_name {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kQualifiedNameList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* The production for a qualified relation name has to exactly match the
* production for a qualified func_name, because in a FROM clause we cannot
* tell which we are parsing until we see what comes after it ('(' for a
* func_name, something else for a relation). Therefore we allow 'indirection'
* which may contain subscripts, and reject that case in the C code.
*/

qualified_name:

    ColId {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kQualifiedName, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ColId indirection {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = $2;
        res = new IR(kQualifiedName, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


name_list:

    name {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kNameList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | name_list ',' name {
        auto tmp1 = $1;
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kNameList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;



name:
    ColId
;


attr_name:
    ColLabel
;


file_name:
    Sconst
;

/*
* The production for a qualified func_name has to exactly match the
* production for a qualified columnref, because we cannot tell which we
* are parsing until we see what comes after it ('(' or Sconst for a func_name,
* anything else for a columnref).  Therefore we allow 'indirection' which
* may contain subscripts, and reject that case in the C code.  (If we
* ever implement SQL99-like methods, such syntax may actually become legal!)
*/

func_name:

    type_function_name {
        if ($1) {
            auto tmp1 = new IR(kIdentifier, string($1), kDataFunctionName, 0, kFlagUnknown);
            all_gen_ir.push_back( tmp1 );
            res = new IR(kFuncName, OP3("", "", ""), tmp1);
            all_gen_ir.push_back(res);
            $$ = res;
            free($1);
        } else {
            /* Yu: Unexpected. Use dummy SUM */
            auto tmp1 = new IR(kIdentifier, string("SUM"), kDataFunctionName, 0, kFlagUnknown);
            all_gen_ir.push_back( tmp1 );
            res = new IR(kFuncName, OP3("", "", ""), tmp1);
            all_gen_ir.push_back(res);
            $$ = res;
        }
    }

    | ColId indirection {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFunctionName, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        auto tmp2 = $2;
        res = new IR(kFuncName, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*
* Constants
*/

AexprConst:

    Iconst {
        auto tmp1 = $1;
        res = new IR(kAexprConst, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FCONST {
        auto tmp1 = new IR(kFloatLiteral, string($1), kDataLiteral, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        res = new IR(kAexprConst, OP0(), tmp1);
        all_gen_ir.push_back(res);
        free($1);
        $$ = res;
    }

    | Sconst {
        auto tmp1 = new IR(kStringLiteral, string($1), kDataLiteral, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kAexprConst, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | BCONST {
        auto tmp1 = new IR(kBoolLiteral, string($1), kDataLiteral, 0, kFlagUnknown);
        free($1);
        all_gen_ir.push_back( tmp1 );
        res = new IR(kAexprConst, OP0(), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | XCONST {
        /* Yu: This is actually deximal numberical string. */
        auto tmp1 = new IR(kIntLiteral, string($1), kDataLiteral, 0, kFlagUnknown);
        free($1);
        all_gen_ir.push_back( tmp1 );
        res = new IR(kAexprConst, OP0(), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | func_name Sconst {
        auto tmp1 = $1;
        auto tmp2 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($2);
        res = new IR(kAexprConst, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | func_name '(' func_arg_list opt_sort_clause ')' Sconst {
        /* Yu: Do not allow opt_sort_clause here. Not supported by Postgres. */
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kAexprConst_1, OP3("", "(", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        // auto tmp3 = $4;
        // res = new IR(kAexprConst_2, OP3("", "", ")"), res, tmp3);
        /* all_gen_ir.push_back(res); */
        /* $4 -> deep_drop(); */
        rov_ir.push_back($4);
        auto tmp4 = new IR(kIdentifier, string($6), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp4 );
        free($6);
        res = new IR(kAexprConst, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ConstTypename Sconst {
        auto tmp1 = $1;
        auto tmp2 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($2);
        res = new IR(kAexprConst, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ConstInterval Sconst opt_interval {
        auto tmp1 = $1;
        auto tmp2 = new IR(kIdentifier, string($2), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($2);
        res = new IR(kAexprConst_3, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $3;
        res = new IR(kAexprConst, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | ConstInterval '(' Iconst ')' Sconst {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kAexprConst_4, OP3("", "(", ")"), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = new IR(kIdentifier, string($5), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp3 );
        free($5);
        res = new IR(kAexprConst, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | TRUE_P {
        res = new IR(kAexprConst, OP3("TRUE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | FALSE_P {
        res = new IR(kAexprConst, OP3("FALSE", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | NULL_P {
        res = new IR(kAexprConst, OP3("NULL", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


Iconst:

    ICONST {
        res = new IR(kIntLiteral, to_string($1), kDataLiteral, 0, kFlagUnknown);
        /* free((void*)($1)); */
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

Sconst:
    SCONST
;


SignedIconst:

    Iconst {
        auto tmp1 = $1;
        res = new IR(kSignedIconst, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '+' Iconst {
        auto tmp1 = $2;
        res = new IR(kSignedIconst, OP3("+", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '-' Iconst {
        auto tmp1 = $2;
        res = new IR(kSignedIconst, OP3("-", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/* Role specifications */

RoleId:
    RoleSpec
;


RoleSpec:

    NonReservedWord {
        /* Don't free $1, this is read-only text. */
        if (strcmp($1, "none") == 0) {
            free($1);
            $$ = strdup("public");
        }
        else {
            $$ = $1;
        }
    }

    | CURRENT_ROLE {
        $$ = strdup($1);
    }

    | CURRENT_USER {
        $$ = strdup($1);
    }

    | SESSION_USER {
        $$ = strdup($1);
    }

;


role_list:

    RoleSpec {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kRoleList, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | role_list ',' RoleSpec {
        auto tmp1 = $1;
        auto tmp2 = new IR(kIdentifier, string($3), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp2 );
        free($3);
        res = new IR(kRoleList, OP3("", ",", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*****************************************************************************
*
* PL/pgSQL extensions
*
* You'd think a PL/pgSQL "expression" should be just an a_expr, but
* historically it can include just about anything that can follow SELECT.
* Therefore the returned struct is a SelectStmt.
*****************************************************************************/


PLpgSQL_Expr:

    opt_distinct_clause opt_target_list from_clause where_clause group_clause having_clause window_clause opt_sort_clause opt_select_limit opt_for_locking_clause {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kPLpgSQLExpr_1, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $3;
        res = new IR(kPLpgSQLExpr_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $4;
        res = new IR(kPLpgSQLExpr_3, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        auto tmp5 = $5;
        res = new IR(kPLpgSQLExpr_4, OP3("", "", ""), res, tmp5);
        all_gen_ir.push_back(res);
        auto tmp6 = $6;
        res = new IR(kPLpgSQLExpr_5, OP3("", "", ""), res, tmp6);
        all_gen_ir.push_back(res);
        auto tmp7 = $7;
        res = new IR(kPLpgSQLExpr_6, OP3("", "", ""), res, tmp7);
        all_gen_ir.push_back(res);
        auto tmp8 = $8;
        res = new IR(kPLpgSQLExpr_7, OP3("", "", ""), res, tmp8);
        all_gen_ir.push_back(res);
        auto tmp9 = $9;
        res = new IR(kPLpgSQLExpr_8, OP3("", "", ""), res, tmp9);
        all_gen_ir.push_back(res);
        auto tmp10 = $10;
        res = new IR(kPLpgSQLExpr, OP3("", "", ""), res, tmp10);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;

/*
* PL/pgSQL Assignment statement: name opt_indirection := PLpgSQL_Expr
*/


PLAssignStmt:

    plassign_target opt_indirection plassign_equals PLpgSQL_Expr {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kPLAssignStmt_1, OP3("", "", ""), tmp1, tmp2);
        all_gen_ir.push_back(res);
        auto tmp3 = $3;
        res = new IR(kPLAssignStmt_2, OP3("", "", ""), res, tmp3);
        all_gen_ir.push_back(res);
        auto tmp4 = $4;
        res = new IR(kPLAssignStmt, OP3("", "", ""), res, tmp4);
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


plassign_target:

    ColId {
        auto tmp1 = new IR(kIdentifier, string($1), kDataFixLater, 0, kFlagUnknown);
        all_gen_ir.push_back( tmp1 );
        free($1);
        res = new IR(kPlassignTarget, OP3("", "", ""), tmp1);
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | PARAM {
        res = new IR(kPlassignTarget, OP3("PARAM", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


plassign_equals:

    COLON_EQUALS {
        res = new IR(kPlassignEquals, OP3(":=", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

    | '=' {
        res = new IR(kPlassignEquals, OP3("=", "", ""));
        all_gen_ir.push_back(res);
        $$ = res;
    }

;


/*
* Name classification hierarchy.
*
* IDENT is the lexeme returned by the lexer for identifiers that match
* no known keyword.  In most cases, we can accept certain keywords as
* names, not only IDENTs.	We prefer to accept as many such keywords
* as possible to minimize the impact of "reserved words" on programmers.
* So, we divide names into several possible classes.  The classification
* is chosen in part to make keywords acceptable as names wherever possible.
*/

/* Column identifier --- names that can be column, table, etc names.
*/

ColId:

    IDENT
    | unreserved_keyword { $$ = strdup($1); }
    | col_name_keyword  {$$ = strdup($1);}
;

/* Type/function identifier --- names that can be type or function names.
*/

type_function_name:

    IDENT
    | unreserved_keyword { $$ = strdup($1); }
    | type_func_name_keyword {$$ = strdup($1);}
;

/* Any not-fully-reserved word --- these names can be, eg, role names.
*/

NonReservedWord:

    IDENT
    | unreserved_keyword { $$ = strdup($1); }
    | col_name_keyword { $$ = strdup($1); }
    | type_func_name_keyword { $$ = strdup($1); }
;

/* Column label --- allowed labels in "AS" clauses.
* This presently includes *all* Postgres keywords.
*/

ColLabel:

    IDENT
    | unreserved_keyword { $$ = strdup($1); }
    | col_name_keyword {$$ = strdup($1);}
    | type_func_name_keyword  {$$ = strdup($1);}
    | reserved_keyword  {$$ = strdup($1);}
;

/* Bare column label --- names that can be column labels without writing "AS".
* This classification is orthogonal to the other keyword categories.
*/

BareColLabel:

    IDENT
    | bare_label_keyword  {$$ = strdup($1);}
;


/*
* Keyword category lists.  Generally, every keyword present in
* the Postgres grammar should appear in exactly one of these lists.
*
* Put a new keyword into the first list that it can go into without causing
* shift or reduce conflicts.  The earlier lists define "less reserved"
* categories of keywords.
*
* Make sure that each keyword's category in kwlist.h matches where
* it is listed here.  (Someday we may be able to generate these lists and
* kwlist.h's table from one source of truth.)
*/

/* "Unreserved" keywords --- available for use as any kind of name.
*/

unreserved_keyword:

    ABORT_P
    | ABSOLUTE_P
    | ACCESS
    | ACTION
    | ADD_P
    | ADMIN
    | AFTER
    | AGGREGATE
    | ALSO
    | ALTER
    | ALWAYS
    | ASENSITIVE
    | ASSERTION
    | ASSIGNMENT
    | AT
    | ATOMIC
    | ATTACH
    | ATTRIBUTE
    | BACKWARD
    | BEFORE
    | BEGIN_P
    | BREADTH
    | BY
    | CACHE
    | CALL
    | CALLED
    | CASCADE
    | CASCADED
    | CATALOG_P
    | CHAIN
    | CHARACTERISTICS
    | CHECKPOINT
    | CLASS
    | CLOSE
    | CLUSTER
    | COLUMNS
    | COMMENT
    | COMMENTS
    | COMMIT
    | COMMITTED
    | COMPRESSION
    | CONFIGURATION
    | CONFLICT
    | CONNECTION
    | CONSTRAINTS
    | CONTENT_P
    | CONTINUE_P
    | CONVERSION_P
    | COPY
    | COST
    | CSV
    | CUBE
    | CURRENT_P
    | CURSOR
    | CYCLE
    | DATA_P
    | DATABASE
    | DAY_P
    | DEALLOCATE
    | DECLARE
    | DEFAULTS
    | DEFERRED
    | DEFINER
    | DELETE_P
    | DELIMITER
    | DELIMITERS
    | DEPENDS
    | DEPTH
    | DETACH
    | DICTIONARY
    | DISABLE_P
    | DISCARD
    | DOCUMENT_P
    | DOMAIN_P
    | DOUBLE_P
    | DROP
    | EACH
    | ENABLE_P
    | ENCODING
    | ENCRYPTED
    | ENUM_P
    | ESCAPE
    | EVENT
    | EXCLUDE
    | EXCLUDING
    | EXCLUSIVE
    | EXECUTE
    | EXPLAIN
    | EXPRESSION
    | EXTENSION
    | EXTERNAL
    | FAMILY
    | FILTER
    | FINALIZE
    | FIRST_P
    | FOLLOWING
    | FORCE
    | FORWARD
    | FUNCTION
    | FUNCTIONS
    | GENERATED
    | GLOBAL
    | GRANTED
    | GROUPS
    | HANDLER
    | HEADER_P
    | HOLD
    | HOUR_P
    | IDENTITY_P
    | IF_P
    | IMMEDIATE
    | IMMUTABLE
    | IMPLICIT_P
    | IMPORT_P
    | INCLUDE
    | INCLUDING
    | INCREMENT
    | INDEX
    | INDEXES
    | INHERIT
    | INHERITS
    | INLINE_P
    | INPUT_P
    | INSENSITIVE
    | INSERT
    | INSTEAD
    | INVOKER
    | ISOLATION
    | KEY
    | LABEL
    | LANGUAGE
    | LARGE_P
    | LAST_P
    | LEAKPROOF
    | LEVEL
    | LISTEN
    | LOAD
    | LOCAL
    | LOCATION
    | LOCK_P
    | LOCKED
    | LOGGED
    | MAPPING
    | MATCH
    | MATERIALIZED
    | MAXVALUE
    | METHOD
    | MINUTE_P
    | MINVALUE
    | MODE
    | MONTH_P
    | MOVE
    | NAME_P
    | NAMES
    | NEW
    | NEXT
    | NFC
    | NFD
    | NFKC
    | NFKD
    | NO
    | NORMALIZED
    | NOTHING
    | NOTIFY
    | NOWAIT
    | NULLS_P
    | OBJECT_P
    | OF
    | OFF
    | OIDS
    | OLD
    | OPERATOR
    | OPTION
    | OPTIONS
    | ORDINALITY
    | OTHERS
    | OVER
    | OVERRIDING
    | OWNED
    | OWNER
    | PARALLEL
    | PARSER
    | PARTIAL
    | PARTITION
    | PASSING
    | PASSWORD
    | PLANS
    | POLICY
    | PRECEDING
    | PREPARE
    | PREPARED
    | PRESERVE
    | PRIOR
    | PRIVILEGES
    | PROCEDURAL
    | PROCEDURE
    | PROCEDURES
    | PROGRAM
    | PUBLICATION
    | QUOTE
    | RANGE
    | READ
    | REASSIGN
    | RECHECK
    | RECURSIVE
    | REF
    | REFERENCING
    | REFRESH
    | REINDEX
    | RELATIVE_P
    | RELEASE
    | RENAME
    | REPEATABLE
    | REPLACE
    | REPLICA
    | RESET
    | RESTART
    | RESTRICT
    | RETURN
    | RETURNS
    | REVOKE
    | ROLE
    | ROLLBACK
    | ROLLUP
    | ROUTINE
    | ROUTINES
    | ROWS
    | RULE
    | SAVEPOINT
    | SCHEMA
    | SCHEMAS
    | SCROLL
    | SEARCH
    | SECOND_P
    | SECURITY
    | SEQUENCE
    | SEQUENCES
    | SERIALIZABLE
    | SERVER
    | SESSION
    | SET
    | SETS
    | SHARE
    | SHOW
    | SIMPLE
    | SKIP
    | SNAPSHOT
    | SQL_P
    | STABLE
    | STANDALONE_P
    | START
    | STATEMENT
    | STATISTICS
    | STDIN
    | STDOUT
    | STORAGE
    | STORED
    | STRICT_P
    | STRIP_P
    | SUBSCRIPTION
    | SUPPORT
    | SYSID
    | SYSTEM_P
    | TABLES
    | TABLESPACE
    | TEMP
    | TEMPLATE
    | TEMPORARY
    | TEXT_P
    | TIES
    | TRANSACTION
    | TRANSFORM
    | TRIGGER
    | TRUNCATE
    | TRUSTED
    | TYPE_P
    | TYPES_P
    | UESCAPE
    | UNBOUNDED
    | UNCOMMITTED
    | UNENCRYPTED
    | UNKNOWN
    | UNLISTEN
    | UNLOGGED
    | UNTIL
    | UPDATE
    | VACUUM
    | VALID
    | VALIDATE
    | VALIDATOR
    | VALUE_P
    | VARYING
    | VERSION_P
    | VIEW
    | VIEWS
    | VOLATILE
    | WHITESPACE_P
    | WITHIN
    | WITHOUT
    | WORK
    | WRAPPER
    | WRITE
    | XML_P
    | YEAR_P
    | YES_P
    | ZONE
;

/* Column identifier --- keywords that can be column, table, etc names.
*
* Many of these keywords will in fact be recognized as type or function
* names too; but they have special productions for the purpose, and so
* can't be treated as "generic" type or function names.
*
* The type names appearing here are not usable as function names
* because they can be followed by '(' in typename productions, which
* looks too much like a function call for an LR(1) parser.
*/

col_name_keyword:

    BETWEEN
    | BIGINT
    | BIT
    | BOOLEAN_P
    | CHAR_P
    | CHARACTER
    | COALESCE
    | DEC
    | DECIMAL_P
    | EXISTS
    | EXTRACT
    | FLOAT_P
    | GREATEST
    | GROUPING
    | INOUT
    | INT_P
    | INTEGER
    | INTERVAL
    | LEAST
    | NATIONAL
    | NCHAR
    | NONE
    | NORMALIZE
    | NULLIF
    | NUMERIC
    | OUT_P
    | OVERLAY
    | POSITION
    | PRECISION
    | REAL
    | ROW
    | SETOF
    | SMALLINT
    | SUBSTRING
    | TIME
    | TIMESTAMP
    | TREAT
    | TRIM
    | VALUES
    | VARCHAR
    | XMLATTRIBUTES
    | XMLCONCAT
    | XMLELEMENT
    | XMLEXISTS
    | XMLFOREST
    | XMLNAMESPACES
    | XMLPARSE
    | XMLPI
    | XMLROOT
    | XMLSERIALIZE
    | XMLTABLE
;

/* Type/function identifier --- keywords that can be type or function names.
*
* Most of these are keywords that are used as operators in expressions;
* in general such keywords can't be column names because they would be
* ambiguous with variables, but they are unambiguous as function identifiers.
*
* Do not include POSITION, SUBSTRING, etc here since they have explicit
* productions in a_expr to support the goofy SQL9x argument syntax.
* - thomas 2000-11-28
*/

type_func_name_keyword:

    AUTHORIZATION
    | BINARY
    | COLLATION
    | CONCURRENTLY
    | CROSS
    | CURRENT_SCHEMA
    | FREEZE
    | FULL
    | ILIKE
    | INNER_P
    | IS
    | ISNULL
    | JOIN
    | LEFT
    | LIKE
    | NATURAL
    | NOTNULL
    | OUTER_P
    | OVERLAPS
    | RIGHT
    | SIMILAR
    | TABLESAMPLE
    | VERBOSE
;

/* Reserved keyword --- these keywords are usable only as a ColLabel.
*
* Keywords appear here if they could not be distinguished from variable,
* type, or function names in some contexts.  Don't put things here unless
* forced to.
*/

reserved_keyword:

    ALL
    | ANALYSE
    | ANALYZE
    | AND
    | ANY
    | ARRAY
    | AS
    | ASC
    | ASYMMETRIC
    | BOTH
    | CASE
    | CAST
    | CHECK
    | COLLATE
    | COLUMN
    | CONSTRAINT
    | CREATE
    | CURRENT_CATALOG
    | CURRENT_DATE
    | CURRENT_ROLE
    | CURRENT_TIME
    | CURRENT_TIMESTAMP
    | CURRENT_USER
    | DEFAULT
    | DEFERRABLE
    | DESC
    | DISTINCT
    | DO
    | ELSE
    | END_P
    | EXCEPT
    | FALSE_P
    | FETCH
    | FOR
    | FOREIGN
    | FROM
    | GRANT
    | GROUP_P
    | HAVING
    | IN_P
    | INITIALLY
    | INTERSECT
    | INTO
    | LATERAL_P
    | LEADING
    | LIMIT
    | LOCALTIME
    | LOCALTIMESTAMP
    | NOT
    | NULL_P
    | OFFSET
    | ON
    | ONLY
    | OR
    | ORDER
    | PLACING
    | PRIMARY
    | REFERENCES
    | RETURNING
    | SELECT
    | SESSION_USER
    | SOME
    | SYMMETRIC
    | TABLE
    | THEN
    | TO
    | TRAILING
    | TRUE_P
    | UNION
    | UNIQUE
    | USER
    | USING
    | VARIADIC
    | WHEN
    | WHERE
    | WINDOW
    | WITH
;

/*
* While all keywords can be used as column labels when preceded by AS,
* not all of them can be used as a "bare" column label without AS.
* Those that can be used as a bare label must be listed here,
* in addition to appearing in one of the category lists above.
*
* Always add a new keyword to this list if possible.  Mark it BARE_LABEL
* in kwlist.h if it is included here, or AS_LABEL if it is not.
*/

bare_label_keyword:

    ABORT_P
    | ABSOLUTE_P
    | ACCESS
    | ACTION
    | ADD_P
    | ADMIN
    | AFTER
    | AGGREGATE
    | ALL
    | ALSO
    | ALTER
    | ALWAYS
    | ANALYSE
    | ANALYZE
    | AND
    | ANY
    | ASC
    | ASENSITIVE
    | ASSERTION
    | ASSIGNMENT
    | ASYMMETRIC
    | AT
    | ATOMIC
    | ATTACH
    | ATTRIBUTE
    | AUTHORIZATION
    | BACKWARD
    | BEFORE
    | BEGIN_P
    | BETWEEN
    | BIGINT
    | BINARY
    | BIT
    | BOOLEAN_P
    | BOTH
    | BREADTH
    | BY
    | CACHE
    | CALL
    | CALLED
    | CASCADE
    | CASCADED
    | CASE
    | CAST
    | CATALOG_P
    | CHAIN
    | CHARACTERISTICS
    | CHECK
    | CHECKPOINT
    | CLASS
    | CLOSE
    | CLUSTER
    | COALESCE
    | COLLATE
    | COLLATION
    | COLUMN
    | COLUMNS
    | COMMENT
    | COMMENTS
    | COMMIT
    | COMMITTED
    | COMPRESSION
    | CONCURRENTLY
    | CONFIGURATION
    | CONFLICT
    | CONNECTION
    | CONSTRAINT
    | CONSTRAINTS
    | CONTENT_P
    | CONTINUE_P
    | CONVERSION_P
    | COPY
    | COST
    | CROSS
    | CSV
    | CUBE
    | CURRENT_P
    | CURRENT_CATALOG
    | CURRENT_DATE
    | CURRENT_ROLE
    | CURRENT_SCHEMA
    | CURRENT_TIME
    | CURRENT_TIMESTAMP
    | CURRENT_USER
    | CURSOR
    | CYCLE
    | DATA_P
    | DATABASE
    | DEALLOCATE
    | DEC
    | DECIMAL_P
    | DECLARE
    | DEFAULT
    | DEFAULTS
    | DEFERRABLE
    | DEFERRED
    | DEFINER
    | DELETE_P
    | DELIMITER
    | DELIMITERS
    | DEPENDS
    | DEPTH
    | DESC
    | DETACH
    | DICTIONARY
    | DISABLE_P
    | DISCARD
    | DISTINCT
    | DO
    | DOCUMENT_P
    | DOMAIN_P
    | DOUBLE_P
    | DROP
    | EACH
    | ELSE
    | ENABLE_P
    | ENCODING
    | ENCRYPTED
    | END_P
    | ENUM_P
    | ESCAPE
    | EVENT
    | EXCLUDE
    | EXCLUDING
    | EXCLUSIVE
    | EXECUTE
    | EXISTS
    | EXPLAIN
    | EXPRESSION
    | EXTENSION
    | EXTERNAL
    | EXTRACT
    | FALSE_P
    | FAMILY
    | FINALIZE
    | FIRST_P
    | FLOAT_P
    | FOLLOWING
    | FORCE
    | FOREIGN
    | FORWARD
    | FREEZE
    | FULL
    | FUNCTION
    | FUNCTIONS
    | GENERATED
    | GLOBAL
    | GRANTED
    | GREATEST
    | GROUPING
    | GROUPS
    | HANDLER
    | HEADER_P
    | HOLD
    | IDENTITY_P
    | IF_P
    | ILIKE
    | IMMEDIATE
    | IMMUTABLE
    | IMPLICIT_P
    | IMPORT_P
    | IN_P
    | INCLUDE
    | INCLUDING
    | INCREMENT
    | INDEX
    | INDEXES
    | INHERIT
    | INHERITS
    | INITIALLY
    | INLINE_P
    | INNER_P
    | INOUT
    | INPUT_P
    | INSENSITIVE
    | INSERT
    | INSTEAD
    | INT_P
    | INTEGER
    | INTERVAL
    | INVOKER
    | IS
    | ISOLATION
    | JOIN
    | KEY
    | LABEL
    | LANGUAGE
    | LARGE_P
    | LAST_P
    | LATERAL_P
    | LEADING
    | LEAKPROOF
    | LEAST
    | LEFT
    | LEVEL
    | LIKE
    | LISTEN
    | LOAD
    | LOCAL
    | LOCALTIME
    | LOCALTIMESTAMP
    | LOCATION
    | LOCK_P
    | LOCKED
    | LOGGED
    | MAPPING
    | MATCH
    | MATERIALIZED
    | MAXVALUE
    | METHOD
    | MINVALUE
    | MODE
    | MOVE
    | NAME_P
    | NAMES
    | NATIONAL
    | NATURAL
    | NCHAR
    | NEW
    | NEXT
    | NFC
    | NFD
    | NFKC
    | NFKD
    | NO
    | NONE
    | NORMALIZE
    | NORMALIZED
    | NOT
    | NOTHING
    | NOTIFY
    | NOWAIT
    | NULL_P
    | NULLIF
    | NULLS_P
    | NUMERIC
    | OBJECT_P
    | OF
    | OFF
    | OIDS
    | OLD
    | ONLY
    | OPERATOR
    | OPTION
    | OPTIONS
    | OR
    | ORDINALITY
    | OTHERS
    | OUT_P
    | OUTER_P
    | OVERLAY
    | OVERRIDING
    | OWNED
    | OWNER
    | PARALLEL
    | PARSER
    | PARTIAL
    | PARTITION
    | PASSING
    | PASSWORD
    | PLACING
    | PLANS
    | POLICY
    | POSITION
    | PRECEDING
    | PREPARE
    | PREPARED
    | PRESERVE
    | PRIMARY
    | PRIOR
    | PRIVILEGES
    | PROCEDURAL
    | PROCEDURE
    | PROCEDURES
    | PROGRAM
    | PUBLICATION
    | QUOTE
    | RANGE
    | READ
    | REAL
    | REASSIGN
    | RECHECK
    | RECURSIVE
    | REF
    | REFERENCES
    | REFERENCING
    | REFRESH
    | REINDEX
    | RELATIVE_P
    | RELEASE
    | RENAME
    | REPEATABLE
    | REPLACE
    | REPLICA
    | RESET
    | RESTART
    | RESTRICT
    | RETURN
    | RETURNS
    | REVOKE
    | RIGHT
    | ROLE
    | ROLLBACK
    | ROLLUP
    | ROUTINE
    | ROUTINES
    | ROW
    | ROWS
    | RULE
    | SAVEPOINT
    | SCHEMA
    | SCHEMAS
    | SCROLL
    | SEARCH
    | SECURITY
    | SELECT
    | SEQUENCE
    | SEQUENCES
    | SERIALIZABLE
    | SERVER
    | SESSION
    | SESSION_USER
    | SET
    | SETOF
    | SETS
    | SHARE
    | SHOW
    | SIMILAR
    | SIMPLE
    | SKIP
    | SMALLINT
    | SNAPSHOT
    | SOME
    | SQL_P
    | STABLE
    | STANDALONE_P
    | START
    | STATEMENT
    | STATISTICS
    | STDIN
    | STDOUT
    | STORAGE
    | STORED
    | STRICT_P
    | STRIP_P
    | SUBSCRIPTION
    | SUBSTRING
    | SUPPORT
    | SYMMETRIC
    | SYSID
    | SYSTEM_P
    | TABLE
    | TABLES
    | TABLESAMPLE
    | TABLESPACE
    | TEMP
    | TEMPLATE
    | TEMPORARY
    | TEXT_P
    | THEN
    | TIES
    | TIME
    | TIMESTAMP
    | TRAILING
    | TRANSACTION
    | TRANSFORM
    | TREAT
    | TRIGGER
    | TRIM
    | TRUE_P
    | TRUNCATE
    | TRUSTED
    | TYPE_P
    | TYPES_P
    | UESCAPE
    | UNBOUNDED
    | UNCOMMITTED
    | UNENCRYPTED
    | UNIQUE
    | UNKNOWN
    | UNLISTEN
    | UNLOGGED
    | UNTIL
    | UPDATE
    | USER
    | USING
    | VACUUM
    | VALID
    | VALIDATE
    | VALIDATOR
    | VALUE_P
    | VALUES
    | VARCHAR
    | VARIADIC
    | VERBOSE
    | VERSION_P
    | VIEW
    | VIEWS
    | VOLATILE
    | WHEN
    | WHITESPACE_P
    | WORK
    | WRAPPER
    | WRITE
    | XML_P
    | XMLATTRIBUTES
    | XMLCONCAT
    | XMLELEMENT
    | XMLEXISTS
    | XMLFOREST
    | XMLNAMESPACES
    | XMLPARSE
    | XMLPI
    | XMLROOT
    | XMLSERIALIZE
    | XMLTABLE
    | YES_P
    | ZONE
;

%%

/*
 * The signature of this function is required by bison.  However, we
 * ignore the passed yylloc and instead use the last token position
 * available from the scanner.
 */
static void
base_yyerror(YYLTYPE *yylloc, IR* res, IR **pIR, vector<IR*> all_gen_ir, vector<IR*> rov_ir, core_yyscan_t yyscanner, const char *msg)
{
    for (IR* gen_ir : all_gen_ir) {
        gen_ir->drop();
    }

	/* parser_yyerror(msg); */
}

/* parser_init()
 * Initialize to parse one query string
 */
void
parser_init(base_yy_extra_type *yyext)
{
	yyext->parsetree = NIL;		/* in case grammar forgets to set it */
}


/*
 * the caller should release the allocated memory after finishing use
 * the first and the second are not freed here also
 */
char * alloc_and_cat(const char *first, const char *second) {
    unsigned size = strlen(first) + 1 + strlen(second);
    char * mem = (char *) calloc (size, 1);
    char * p = mem;
    strcat(p, first);
    p += strlen(first);
    strcat(p, second);
    return mem;
}

char * alloc_and_cat(const char *first, const char* middle, const char *second) {
    unsigned size = strlen(first) + strlen(second) + strlen(middle) + 1;
    char * mem = (char *) calloc (size, 1);
    char * p = mem;
    strcat(p, first);
    p += strlen(first);
    strcat(p, middle);
    p += strlen(middle);
    strcat(p, second);
    return mem;
}
