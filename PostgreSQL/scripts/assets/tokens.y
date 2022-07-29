%type <node>	stmt toplevel_stmt schema_stmt routine_body_stmt
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

%type <node>	select_no_parens select_with_parens select_clause
				simple_select values_clause
				PLpgSQL_Expr PLAssignStmt

%type <node>	alter_column_default opclass_item opclass_drop alter_using
%type <ival>	add_drop opt_asc_desc opt_nulls_order

%type <node>	alter_table_cmd alter_type_cmd opt_collate_clause
	   replica_identity partition_cmd index_partition_cmd
%type <list>	alter_table_cmds alter_type_cmds
%type <list>    alter_identity_column_option_list
%type <defelt>  alter_identity_column_option

%type <dbehavior>	opt_drop_behavior

%type <list>	createdb_opt_list createdb_opt_items copy_opt_list
				transaction_mode_list
				create_extension_opt_list alter_extension_opt_list
%type <defelt>	createdb_opt_item copy_opt_item
				transaction_mode_item
				create_extension_opt_item alter_extension_opt_item

%type <ival>	opt_lock lock_type cast_context
%type <str>		utility_option_name
%type <defelt>	utility_option_elem
%type <list>	utility_option_list
%type <node>	utility_option_arg
%type <defelt>	drop_option
%type <boolean>	opt_or_replace opt_no
				opt_grant_grant_option opt_grant_admin_option
				opt_nowait opt_if_exists opt_with_data
				opt_transaction_chain
%type <ival>	opt_nowait_or_skip

%type <list>	OptRoleList AlterOptRoleList
%type <defelt>	CreateOptRoleElem AlterOptRoleElem

%type <str>		opt_type
%type <str>		foreign_server_version opt_foreign_server_version
%type <str>		opt_in_database

%type <str>		OptSchemaName
%type <list>	OptSchemaEltList

%type <chr>		am_type

%type <boolean> TriggerForSpec TriggerForType
%type <ival>	TriggerActionTime
%type <list>	TriggerEvents TriggerOneEvent
%type <value>	TriggerFuncArg
%type <node>	TriggerWhen
%type <str>		TransitionRelName
%type <boolean>	TransitionRowOrTable TransitionOldOrNew
%type <node>	TriggerTransition

%type <list>	event_trigger_when_list event_trigger_value_list
%type <defelt>	event_trigger_when_item
%type <chr>		enable_trigger

%type <str>		copy_file_name
				access_method_clause attr_name
				table_access_method_clause name cursor_name file_name
				opt_index_name cluster_index_specification

%type <list>	func_name handler_name qual_Op qual_all_Op subquery_Op
				opt_class opt_inline_handler opt_validator validator_clause
				opt_collate

%type <range>	qualified_name insert_target OptConstrFromTable

%type <str>		all_Op MathOp

%type <str>		row_security_cmd RowSecurityDefaultForCmd
%type <boolean> RowSecurityDefaultPermissive
%type <node>	RowSecurityOptionalWithCheck RowSecurityOptionalExpr
%type <list>	RowSecurityDefaultToRole RowSecurityOptionalToRole

%type <str>		iso_level opt_encoding
%type <rolespec> grantee
%type <list>	grantee_list
%type <accesspriv> privilege
%type <list>	privileges privilege_list
%type <privtarget> privilege_target
%type <objwithargs> function_with_argtypes aggregate_with_argtypes operator_with_argtypes
%type <list>	function_with_argtypes_list aggregate_with_argtypes_list operator_with_argtypes_list
%type <ival>	defacl_privilege_target
%type <defelt>	DefACLOption
%type <list>	DefACLOptionList
%type <ival>	import_qualification_type
%type <importqual> import_qualification
%type <node>	vacuum_relation
%type <selectlimit> opt_select_limit select_limit limit_clause

%type <list>	parse_toplevel stmtmulti routine_body_stmt_list
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

%type <node>	opt_routine_body
%type <groupclause> group_clause
%type <list>	group_by_list
%type <node>	group_by_item empty_grouping_set rollup_clause cube_clause
%type <node>	grouping_sets_clause
%type <node>	opt_publication_for_tables publication_for_tables

%type <list>	opt_fdw_options fdw_options
%type <defelt>	fdw_option

%type <range>	OptTempTableName
%type <into>	into_clause create_as_target create_mv_target

%type <defelt>	createfunc_opt_item common_func_opt_item dostmt_opt_item
%type <fun_param> func_arg func_arg_with_default table_func_column aggr_arg
%type <fun_param_mode> arg_class
%type <typnam>	func_return func_type

%type <boolean>  opt_trusted opt_restart_seqs
%type <ival>	 OptTemp
%type <ival>	 OptNoLog
%type <oncommit> OnCommitOption

%type <ival>	for_locking_strength
%type <node>	for_locking_item
%type <list>	for_locking_clause opt_for_locking_clause for_locking_items
%type <list>	locked_rels_list
%type <setquantifier> set_quantifier

%type <node>	join_qual
%type <jtype>	join_type

%type <list>	extract_list overlay_list position_list
%type <list>	substr_list trim_list
%type <list>	opt_interval interval_second
%type <str>		unicode_normal_form

%type <boolean> opt_instead
%type <boolean> opt_unique opt_concurrently opt_verbose opt_full
%type <boolean> opt_freeze opt_analyze opt_default opt_recheck
%type <defelt>	opt_binary copy_delimiter

%type <boolean> copy_from opt_program

%type <ival>	event cursor_options opt_hold opt_set_data
%type <objtype>	object_type_any_name object_type_name object_type_name_on_any_name
				drop_type_name

%type <node>	fetch_args select_limit_value
				offset_clause select_offset_value
				select_fetch_first_value I_or_F_const
%type <ival>	row_or_rows first_or_next

%type <list>	OptSeqOptList SeqOptList OptParenthesizedSeqOptList
%type <defelt>	SeqOptElem

%type <istmt>	insert_rest
%type <infer>	opt_conf_expr
%type <onconflict> opt_on_conflict

%type <vsetstmt> generic_set set_rest set_rest_more generic_reset reset_rest
				 SetResetClause FunctionSetResetClause

%type <node>	TableElement TypedTableElement ConstraintElem TableFuncElement
%type <node>	columnDef columnOptions
%type <defelt>	def_elem reloption_elem old_aggr_elem operator_def_elem
%type <node>	def_arg columnElem where_clause where_or_current_clause
				a_expr b_expr c_expr AexprConst indirection_el opt_slice_bound
				columnref in_expr having_clause func_table xmltable array_expr
				OptWhereClause operator_def_arg
%type <list>	rowsfrom_item rowsfrom_list opt_col_def_list
%type <boolean> opt_ordinality
%type <list>	ExclusionConstraintList ExclusionConstraintElem
%type <list>	func_arg_list func_arg_list_opt
%type <node>	func_arg_expr
%type <list>	row explicit_row implicit_row type_list array_expr_list
%type <node>	case_expr case_arg when_clause case_default
%type <list>	when_clause_list
%type <node>	opt_search_clause opt_cycle_clause
%type <ival>	sub_type opt_materialized
%type <value>	NumericOnly
%type <list>	NumericOnly_list
%type <alias>	alias_clause opt_alias_clause opt_alias_clause_for_join_using
%type <list>	func_alias_clause
%type <sortby>	sortby
%type <ielem>	index_elem index_elem_options
%type <selem>	stats_param
%type <node>	table_ref
%type <jexpr>	joined_table
%type <range>	relation_expr
%type <range>	relation_expr_opt_alias
%type <node>	tablesample_clause opt_repeatable_clause
%type <target>	target_el set_target insert_column_item

%type <str>		generic_option_name
%type <node>	generic_option_arg
%type <defelt>	generic_option_elem alter_generic_option_elem
%type <list>	generic_option_list alter_generic_option_list

%type <ival>	reindex_target_type reindex_target_multitable

%type <node>	copy_generic_opt_arg copy_generic_opt_arg_list_item
%type <defelt>	copy_generic_opt_elem
%type <list>	copy_generic_opt_list copy_generic_opt_arg_list
%type <list>	copy_options

%type <typnam>	Typename SimpleTypename ConstTypename
				GenericType Numeric opt_float
				Character ConstCharacter
				CharacterWithLength CharacterWithoutLength
				ConstDatetime ConstInterval
				Bit ConstBit BitWithLength BitWithoutLength
%type <str>		character
%type <str>		extract_arg
%type <boolean> opt_varying opt_timezone opt_no_inherit

%type <ival>	Iconst SignedIconst
%type <str>		Sconst comment_text notify_payload
%type <str>		RoleId opt_boolean_or_string
%type <list>	var_list
%type <str>		ColId ColLabel BareColLabel
%type <str>		NonReservedWord NonReservedWord_or_Sconst
%type <str>		var_name type_function_name param_name
%type <str>		createdb_opt_name plassign_target
%type <node>	var_value zone_value
%type <rolespec> auth_ident RoleSpec opt_granted_by

%type <keyword> unreserved_keyword type_func_name_keyword
%type <keyword> col_name_keyword reserved_keyword
%type <keyword> bare_label_keyword

%type <node>	TableConstraint TableLikeClause
%type <ival>	TableLikeOptionList TableLikeOption
%type <str>		column_compression opt_column_compression
%type <list>	ColQualList
%type <node>	ColConstraint ColConstraintElem ConstraintAttr
%type <ival>	key_actions key_delete key_match key_update key_action
%type <ival>	ConstraintAttributeSpec ConstraintAttributeElem
%type <str>		ExistingIndex

%type <list>	constraints_set_list
%type <boolean> constraints_set_mode
%type <str>		OptTableSpace OptConsTableSpace
%type <rolespec> OptTableSpaceOwner
%type <ival>	opt_check_option

%type <str>		opt_provider security_label

%type <target>	xml_attribute_el
%type <list>	xml_attribute_list xml_attributes
%type <node>	xml_root_version opt_xml_root_standalone
%type <node>	xmlexists_argument
%type <ival>	document_or_content
%type <boolean> xml_whitespace_option
%type <list>	xmltable_column_list xmltable_column_option_list
%type <node>	xmltable_column_el
%type <defelt>	xmltable_column_option_el
%type <list>	xml_namespace_list
%type <target>	xml_namespace_el

%type <node>	func_application func_expr_common_subexpr
%type <node>	func_expr func_expr_windowless
%type <node>	common_table_expr
%type <with>	with_clause opt_with_clause
%type <list>	cte_list

%type <list>	within_group_clause
%type <node>	filter_clause
%type <list>	window_clause window_definition_list opt_partition_clause
%type <windef>	window_definition over_clause window_specification
				opt_frame_clause frame_extent frame_bound
%type <ival>	opt_window_exclusion_clause
%type <str>		opt_existing_window_name
%type <boolean> opt_if_not_exists
%type <ival>	generated_when override_kind
%type <partspec>	PartitionSpec OptPartitionSpec
%type <partelem>	part_elem
%type <list>		part_params
%type <partboundspec> PartitionBoundSpec
%type <list>		hash_partbound
%type <defelt>		hash_partbound_elem

