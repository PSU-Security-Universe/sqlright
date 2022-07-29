%type <lexer.lex_str>
        IDENT IDENT_QUOTED TEXT_STRING DECIMAL_NUM FLOAT_NUM NUM LONG_NUM HEX_NUM
        LEX_HOSTNAME ULONGLONG_NUM select_alias ident opt_ident ident_or_text
        role_ident role_ident_or_text
        IDENT_sys TEXT_STRING_sys TEXT_STRING_literal
        NCHAR_STRING opt_component
        BIN_NUM TEXT_STRING_filesystem ident_or_empty
        TEXT_STRING_sys_nonewline TEXT_STRING_password TEXT_STRING_hash
        TEXT_STRING_validated
        filter_wild_db_table_string
        opt_constraint_name
        ts_datafile lg_undofile /*lg_redofile*/ opt_logfile_group_name opt_ts_datafile_name
        opt_describe_column
        opt_datadir_ssl default_encryption
        lvalue_ident
        schema
        engine_or_all
        opt_binlog_in

%type <lex_cstr>
        key_cache_name
        label_ident
        opt_table_alias
        opt_replace_password
        sp_opt_label
        json_attribute
        opt_channel

%type <lex_str_list> TEXT_STRING_sys_list

%type <table>
        table_ident

%type <simple_string>
        opt_db

%type <string>
        text_string opt_gconcat_separator
        opt_xml_rows_identified_by

%type <num>
        lock_option
        udf_type if_exists
        opt_no_write_to_binlog
        all_or_any opt_distinct
        fulltext_options union_option
        transaction_access_mode_types
        opt_natural_language_mode opt_query_expansion
        opt_ev_status opt_ev_on_completion ev_on_completion opt_ev_comment
        ev_alter_on_schedule_completion opt_ev_rename_to opt_ev_sql_stmt
        trg_action_time trg_event
        view_check_option
        signed_num
        opt_num_buckets


%type <order_direction>
        ordering_direction opt_ordering_direction

/*
  Bit field of MYSQL_START_TRANS_OPT_* flags.
*/
%type <num> opt_start_transaction_option_list
%type <num> start_transaction_option_list
%type <num> start_transaction_option

%type <m_yes_no_unk>
        opt_chain opt_release

%type <m_fk_option>
        delete_option

%type <ulong_num>
        ulong_num real_ulong_num merge_insert_types
        ws_num_codepoints func_datetime_precision
        now
        opt_checksum_type
        opt_ignore_lines
        opt_profile_defs
        profile_defs
        profile_def
        factor

%type <ulonglong_number>
        ulonglong_num real_ulonglong_num size_number
        option_autoextend_size

%type <lock_type>
        replace_lock_option opt_low_priority insert_lock_option load_data_lock

%type <locked_row_action> locked_row_action opt_locked_row_action

%type <item>
        literal insert_ident temporal_literal
        simple_ident expr opt_expr opt_else
        set_function_specification sum_expr
        in_sum_expr grouping_operation
        window_func_call opt_ll_default
        variable variable_aux bool_pri
        predicate bit_expr
        table_wild simple_expr udf_expr
        expr_or_default set_expr_or_default
        geometry_function
        signed_literal now_or_signed_literal
        simple_ident_nospvar simple_ident_q
        field_or_var limit_option
        function_call_keyword
        function_call_nonkeyword
        function_call_generic
        function_call_conflict
        signal_allowed_expr
        simple_target_specification
        condition_number
        filter_db_ident
        filter_table_ident
        filter_string
        select_item
        opt_where_clause
        where_clause
        opt_having_clause
        opt_simple_limit
        null_as_literal
        literal_or_null
        signed_literal_or_null
        stable_integer
        param_or_var

%type <item_string> window_name opt_existing_window_name

%type <item_num> NUM_literal
        int64_literal

%type <item_list>
        when_list
        opt_filter_db_list filter_db_list
        opt_filter_table_list filter_table_list
        opt_filter_string_list filter_string_list
        opt_filter_db_pair_list filter_db_pair_list

%type <item_list2>
        expr_list udf_expr_list opt_udf_expr_list opt_expr_list select_item_list
        opt_paren_expr_list ident_list_arg ident_list values opt_values row_value fields
        fields_or_vars
        opt_field_or_var_spec
        row_value_explicit

%type <var_type>
        option_type opt_var_type opt_var_ident_type opt_set_var_ident_type

%type <key_type>
        opt_unique constraint_key_type

%type <key_alg>
        index_type

%type <string_list>
        string_list using_list opt_use_partition use_partition ident_string_list
        all_or_alt_part_name_list

%type <key_part>
        key_part key_part_with_expression

%type <date_time_type> date_time_type;
%type <interval> interval

%type <interval_time_st> interval_time_stamp

%type <row_type> row_types

%type <resource_group_type> resource_group_types

%type <resource_group_vcpu_list_type>
        opt_resource_group_vcpu_list
        vcpu_range_spec_list

%type <resource_group_priority_type> opt_resource_group_priority

%type <resource_group_state_type> opt_resource_group_enable_disable

%type <resource_group_flag_type> opt_force

%type <thread_id_list_type> thread_id_list thread_id_list_options

%type <vcpu_range_type> vcpu_num_or_range

%type <tx_isolation> isolation_types

%type <ha_rkey_mode> handler_rkey_mode

%type <ha_read_mode> handler_scan_function
        handler_rkey_function

%type <cast_type> cast_type opt_returning_type

%type <lexer.keyword> ident_keyword label_keyword role_keyword
        lvalue_keyword
        ident_keywords_unambiguous
        ident_keywords_ambiguous_1_roles_and_labels
        ident_keywords_ambiguous_2_labels
        ident_keywords_ambiguous_3_roles
        ident_keywords_ambiguous_4_system_variables

%type <lex_user> user_ident_or_text user create_user alter_user user_func role

%type <lex_mfa>
        identification
        identified_by_password
        identified_by_random_password
        identified_with_plugin
        identified_with_plugin_as_auth
        identified_with_plugin_by_random_password
        identified_with_plugin_by_password
        opt_initial_auth
        opt_user_registration

%type <lex_mfas> opt_create_user_with_mfa

%type <lexer.charset>
        opt_collate
        charset_name
        old_or_new_charset_name
        old_or_new_charset_name_or_default
        collation_name
        opt_load_data_charset
        UNDERSCORE_CHARSET
        ascii unicode
        default_charset default_collation

%type <boolfunc2creator> comp_op

%type <num>  sp_decl_idents sp_opt_inout sp_handler_type sp_hcond_list
%type <spcondvalue> sp_cond sp_hcond sqlstate signal_value opt_signal_value
%type <spblock> sp_decls sp_decl
%type <spname> sp_name
%type <index_hint> index_hint_type
%type <num> index_hint_clause
%type <filetype> data_or_xml

%type <da_condition_item_name> signal_condition_information_item_name

%type <diag_area> which_area;
%type <diag_info> diagnostics_information;
%type <stmt_info_item> statement_information_item;
%type <stmt_info_item_name> statement_information_item_name;
%type <stmt_info_list> statement_information;
%type <cond_info_item> condition_information_item;
%type <cond_info_item_name> condition_information_item_name;
%type <cond_info_list> condition_information;
%type <signal_item_list> signal_information_item_list;
%type <signal_item_list> opt_set_signal_information;

%type <trg_characteristics> trigger_follows_precedes_clause;
%type <trigger_action_order_type> trigger_action_order;

%type <xid> xid;
%type <xa_option_type> opt_join_or_resume;
%type <xa_option_type> opt_suspend;
%type <xa_option_type> opt_one_phase;

%type <is_not_empty> opt_convert_xid opt_ignore opt_linear opt_bin_mod
        opt_if_not_exists opt_temporary
        opt_grant_option opt_with_admin_option
        opt_full opt_extended
        opt_ignore_leaves
        opt_local
        opt_retain_current_password
        opt_discard_old_password
        opt_constraint_enforcement
        constraint_enforcement
        opt_not
        opt_interval

%type <show_cmd_type> opt_show_cmd_type

/*
  A bit field of SLAVE_IO, SLAVE_SQL flags.
*/
%type <num> opt_replica_thread_option_list
%type <num> replica_thread_option_list
%type <num> replica_thread_option

%type <key_usage_element> key_usage_element

%type <key_usage_list> key_usage_list opt_key_usage_list index_hint_definition
        index_hints_list opt_index_hints_list opt_key_definition
        opt_cache_key_list

%type <order_expr> order_expr alter_order_item
        grouping_expr

%type <order_list> order_list group_list gorder_list opt_gorder_clause
      alter_order_list opt_partition_clause opt_window_order_by_clause

%type <c_str> field_length opt_field_length type_datetime_precision
        opt_place

%type <precision> precision opt_precision float_options standard_float_options

%type <charset_with_opt_binary> opt_charset_with_opt_binary

%type <limit_options> limit_options

%type <limit_clause> limit_clause opt_limit_clause

%type <ulonglong_number> query_spec_option

%type <select_options> select_option select_option_list select_options

%type <node>
          option_value

%type <join_table> joined_table joined_table_parens

%type <table_reference_list> opt_from_clause from_clause from_tables
        table_reference_list table_reference_list_parens explicit_table

%type <olap_type> olap_opt

%type <group> opt_group_clause

%type <windows> opt_window_clause  ///< Definition of named windows
                                   ///< for the query specification
                window_definition_list

%type <window> window_definition window_spec window_spec_details window_name_or_spec
  windowing_clause   ///< Definition of unnamed window near the window function.
  opt_windowing_clause ///< For functions which can be either set or window
                       ///< functions (e.g. SUM), non-empty clause makes the difference.

%type <window_frame> opt_window_frame_clause

%type <frame_units> window_frame_units

%type <frame_extent> window_frame_extent window_frame_between

%type <bound> window_frame_start window_frame_bound

%type <frame_exclusion> opt_window_frame_exclusion

%type <null_treatment> opt_null_treatment

%type <lead_lag_info> opt_lead_lag_info

%type <from_first_last> opt_from_first_last

%type <order> order_clause opt_order_clause

%type <locking_clause> locking_clause

%type <locking_clause_list> locking_clause_list

%type <lock_strength> lock_strength

%type <table_reference> table_reference esc_table_reference
        table_factor single_table single_table_parens table_function

%type <query_expression_body> query_expression_body

%type <internal_variable_name> internal_variable_name

%type <option_value_following_option_type> option_value_following_option_type

%type <option_value_no_option_type> option_value_no_option_type

%type <option_value_list> option_value_list option_value_list_continued

%type <start_option_value_list> start_option_value_list

%type <transaction_access_mode> transaction_access_mode
        opt_transaction_access_mode

%type <isolation_level> isolation_level opt_isolation_level

%type <transaction_characteristics> transaction_characteristics

%type <start_option_value_list_following_option_type>
        start_option_value_list_following_option_type

%type <set> set

%type <line_separators> line_term line_term_list opt_line_term

%type <field_separators> field_term field_term_list opt_field_term

%type <into_destination> into_destination into_clause

%type <select_var_ident> select_var_ident

%type <select_var_list> select_var_list

%type <query_primary>
        as_create_query_expression
        query_expression_or_parens
        query_expression_parens
        query_primary
        query_specification

%type <query_expression> query_expression

%type <subquery> subquery row_subquery table_subquery

%type <derived_table> derived_table

%type <param_marker> param_marker

%type <text_literal> text_literal

%type <top_level_node>
        alter_instance_stmt
        alter_resource_group_stmt
        alter_table_stmt
        analyze_table_stmt
        call_stmt
        check_table_stmt
        create_index_stmt
        create_resource_group_stmt
        create_role_stmt
        create_srs_stmt
        create_table_stmt
        delete_stmt
        describe_stmt
        do_stmt
        drop_index_stmt
        drop_resource_group_stmt
        drop_role_stmt
        drop_srs_stmt
        explain_stmt
        explainable_stmt
        handler_stmt
        insert_stmt
        keycache_stmt
        load_stmt
        optimize_table_stmt
        preload_stmt
        repair_table_stmt
        replace_stmt
        restart_server_stmt
        select_stmt
        select_stmt_with_into
        set_resource_group_stmt
        set_role_stmt
        show_binary_logs_stmt
        show_binlog_events_stmt
        show_character_set_stmt
        show_collation_stmt
        show_columns_stmt
        show_count_errors_stmt
        show_count_warnings_stmt
        show_create_database_stmt
        show_create_event_stmt
        show_create_function_stmt
        show_create_procedure_stmt
        show_create_table_stmt
        show_create_trigger_stmt
        show_create_user_stmt
        show_create_view_stmt
        show_databases_stmt
        show_engine_logs_stmt
        show_engine_mutex_stmt
        show_engine_status_stmt
        show_engines_stmt
        show_errors_stmt
        show_events_stmt
        show_function_code_stmt
        show_function_status_stmt
        show_grants_stmt
        show_keys_stmt
        show_master_status_stmt
        show_open_tables_stmt
        show_plugins_stmt
        show_privileges_stmt
        show_procedure_code_stmt
        show_procedure_status_stmt
        show_processlist_stmt
        show_profile_stmt
        show_profiles_stmt
        show_relaylog_events_stmt
        show_replica_status_stmt
        show_replicas_stmt
        show_status_stmt
        show_table_status_stmt
        show_tables_stmt
        show_triggers_stmt
        show_variables_stmt
        show_warnings_stmt
        shutdown_stmt
        simple_statement
        truncate_stmt
        update_stmt

%type <table_ident> table_ident_opt_wild

%type <table_ident_list> table_alias_ref_list table_locking_list

%type <simple_ident_list> simple_ident_list opt_derived_column_list

%type <num> opt_delete_options

%type <opt_delete_option> opt_delete_option

%type <column_value_pair>
        update_elem

%type <column_value_list_pair>
        update_list
        opt_insert_update_list

%type <values_list> values_list insert_values table_value_constructor
        values_row_list

%type <insert_query_expression> insert_query_expression

%type <column_row_value_list_pair> insert_from_constructor

%type <lexer.optimizer_hints> SELECT_SYM INSERT_SYM REPLACE_SYM UPDATE_SYM DELETE_SYM

%type <join_type> outer_join_type natural_join_type inner_join_type

%type <user_list> user_list role_list default_role_clause opt_except_role_list

%type <alter_instance_cmd> alter_instance_action

%type <index_column_list> key_list key_list_with_expression

%type <index_options> opt_index_options index_options  opt_fulltext_index_options
          fulltext_index_options opt_spatial_index_options spatial_index_options

%type <opt_index_lock_and_algorithm> opt_index_lock_and_algorithm

%type <index_option> index_option common_index_option fulltext_index_option
          spatial_index_option
          index_type_clause
          opt_index_type_clause

%type <alter_table_algorithm> alter_algorithm_option_value
        alter_algorithm_option

%type <alter_table_lock> alter_lock_option_value alter_lock_option

%type <table_constraint_def> table_constraint_def

%type <index_name_and_type> opt_index_name_and_type

%type <visibility> visibility

%type <with_clause> with_clause opt_with_clause
%type <with_list> with_list
%type <common_table_expr> common_table_expr

%type <partition_option> part_option

%type <partition_option_list> opt_part_options part_option_list

%type <sub_part_definition> sub_part_definition

%type <sub_part_list> sub_part_list opt_sub_partition

%type <part_value_item> part_value_item

%type <part_value_item_list> part_value_item_list

%type <part_value_item_list_paren> part_value_item_list_paren part_func_max

%type <part_value_list> part_value_list

%type <part_values> part_values_in

%type <opt_part_values> opt_part_values

%type <part_definition> part_definition

%type <part_def_list> part_def_list opt_part_defs

%type <ulong_num> opt_num_subparts opt_num_parts

%type <name_list> name_list opt_name_list

%type <opt_key_algo> opt_key_algo

%type <opt_sub_part> opt_sub_part

%type <part_type_def> part_type_def

%type <partition_clause> partition_clause

%type <mi_type> mi_repair_type mi_repair_types opt_mi_repair_types
        mi_check_type mi_check_types opt_mi_check_types

%type <opt_restrict> opt_restrict;

%type <table_list> table_list opt_table_list

%type <ternary_option> ternary_option;

%type <create_table_option> create_table_option

%type <create_table_options> create_table_options

%type <space_separated_alter_table_opts> create_table_options_space_separated

%type <on_duplicate> duplicate opt_duplicate

%type <col_attr> column_attribute

%type <column_format> column_format

%type <storage_media> storage_media

%type <col_attr_list> column_attribute_list opt_column_attribute_list

%type <virtual_or_stored> opt_stored_attribute

%type <field_option> field_option field_opt_list field_options

%type <int_type> int_type

%type <type> spatial_type type

%type <numeric_type> real_type numeric_type

%type <sp_default> sp_opt_default

%type <field_def> field_def

%type <item> check_constraint

%type <table_constraint_def> opt_references

%type <fk_options> opt_on_update_delete

%type <opt_match_clause> opt_match_clause

%type <reference_list> reference_list opt_ref_list

%type <fk_references> references

%type <column_def> column_def

%type <table_element> table_element

%type <table_element_list> table_element_list

%type <create_table_tail> opt_create_table_options_etc
        opt_create_partitioning_etc opt_duplicate_as_qe

%type <wild_or_where> opt_wild_or_where

// used by JSON_TABLE
%type <jtc_list> columns_clause columns_list
%type <jt_column> jt_column
%type <json_on_response> json_on_response on_empty on_error
%type <json_on_error_or_empty> opt_on_empty_or_error
        opt_on_empty_or_error_json_table
%type <jt_column_type> jt_column_type

%type <acl_type> opt_acl_type
%type <histogram> opt_histogram

%type <lex_cstring_list> column_list opt_column_list

%type <role_or_privilege> role_or_privilege

%type <role_or_privilege_list> role_or_privilege_list

%type <with_validation> with_validation opt_with_validation
/*%type <ts_access_mode> ts_access_mode*/

%type <alter_table_action> alter_list_item alter_table_partition_options
%type <ts_options> logfile_group_option_list opt_logfile_group_options
                   alter_logfile_group_option_list opt_alter_logfile_group_options
                   tablespace_option_list opt_tablespace_options
                   alter_tablespace_option_list opt_alter_tablespace_options
                   opt_drop_ts_options drop_ts_option_list
                   undo_tablespace_option_list opt_undo_tablespace_options

%type <alter_table_standalone_action> standalone_alter_commands

%type <algo_and_lock_and_validation> alter_commands_modifier
        alter_commands_modifier_list

%type <alter_list> alter_list opt_alter_command_list opt_alter_table_actions

%type <standalone_alter_table_action> standalone_alter_table_action

%type <assign_to_keycache> assign_to_keycache

%type <keycache_list> keycache_list

%type <adm_partition> adm_partition

%type <preload_keys> preload_keys

%type <preload_list> preload_list
%type <ts_option>
        alter_logfile_group_option
        alter_tablespace_option
        drop_ts_option
        logfile_group_option
        tablespace_option
        undo_tablespace_option
        ts_option_autoextend_size
        ts_option_comment
        ts_option_engine
        ts_option_extent_size
        ts_option_file_block_size
        ts_option_initial_size
        ts_option_max_size
        ts_option_nodegroup
        ts_option_redo_buffer_size
        ts_option_undo_buffer_size
        ts_option_wait
        ts_option_encryption
        ts_option_engine_attribute

%type <explain_format_type> opt_explain_format_type
%type <explain_format_type> opt_explain_analyze_type

%type <load_set_element> load_data_set_elem

%type <load_set_list> load_data_set_list opt_load_data_set_spec

%type <num> opt_array_cast
%type <sql_cmd_srs_attributes> srs_attributes

%type <insert_update_values_reference> opt_values_reference

%type <alter_tablespace_type> undo_tablespace_state

%type <query_id> opt_for_query
