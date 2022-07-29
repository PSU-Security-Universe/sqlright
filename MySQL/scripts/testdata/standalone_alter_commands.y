standalone_alter_commands:
          DISCARD_SYM TABLESPACE_SYM
          {
            $$= NEW_PTN PT_alter_table_discard_tablespace;
          }
        | IMPORT TABLESPACE_SYM
          {
            $$= NEW_PTN PT_alter_table_import_tablespace;
          }
/*
  This part was added for release 5.1 by Mikael Ronström.
  From here we insert a number of commands to manage the partitions of a
  partitioned table such as adding partitions, dropping partitions,
  reorganising partitions in various manners. In future releases the list
  will be longer.
*/
        | ADD PARTITION_SYM opt_no_write_to_binlog
          {
            $$= NEW_PTN PT_alter_table_add_partition($3);
          }
        | ADD PARTITION_SYM opt_no_write_to_binlog '(' part_def_list ')'
          {
            $$= NEW_PTN PT_alter_table_add_partition_def_list($3, $5);
          }
        | ADD PARTITION_SYM opt_no_write_to_binlog PARTITIONS_SYM real_ulong_num
          {
            $$= NEW_PTN PT_alter_table_add_partition_num($3, $5);
          }
        | DROP PARTITION_SYM ident_string_list
          {
            $$= NEW_PTN PT_alter_table_drop_partition(*$3);
          }
        | REBUILD_SYM PARTITION_SYM opt_no_write_to_binlog
          all_or_alt_part_name_list
          {
            $$= NEW_PTN PT_alter_table_rebuild_partition($3, $4);
          }
        | OPTIMIZE PARTITION_SYM opt_no_write_to_binlog
          all_or_alt_part_name_list
          {
            $$= NEW_PTN PT_alter_table_optimize_partition($3, $4);
          }
        | ANALYZE_SYM PARTITION_SYM opt_no_write_to_binlog
          all_or_alt_part_name_list
          {
            $$= NEW_PTN PT_alter_table_analyze_partition($3, $4);
          }
        | CHECK_SYM PARTITION_SYM all_or_alt_part_name_list opt_mi_check_types
          {
            $$= NEW_PTN PT_alter_table_check_partition($3,
                                                       $4.flags, $4.sql_flags);
          }
        | REPAIR PARTITION_SYM opt_no_write_to_binlog
          all_or_alt_part_name_list
          opt_mi_repair_types
          {
            $$= NEW_PTN PT_alter_table_repair_partition($3, $4,
                                                        $5.flags, $5.sql_flags);
          }
        | COALESCE PARTITION_SYM opt_no_write_to_binlog real_ulong_num
          {
            $$= NEW_PTN PT_alter_table_coalesce_partition($3, $4);
          }
        | TRUNCATE_SYM PARTITION_SYM all_or_alt_part_name_list
          {
            $$= NEW_PTN PT_alter_table_truncate_partition($3);
          }
        | REORGANIZE_SYM PARTITION_SYM opt_no_write_to_binlog
          {
            $$= NEW_PTN PT_alter_table_reorganize_partition($3);
          }
        | REORGANIZE_SYM PARTITION_SYM opt_no_write_to_binlog
          ident_string_list INTO '(' part_def_list ')'
          {
            $$= NEW_PTN PT_alter_table_reorganize_partition_into($3, *$4, $7);
          }
        | EXCHANGE_SYM PARTITION_SYM ident
          WITH TABLE_SYM table_ident opt_with_validation
          {
            $$= NEW_PTN PT_alter_table_exchange_partition($3, $6, $7);
          }
        | DISCARD_SYM PARTITION_SYM all_or_alt_part_name_list
          TABLESPACE_SYM
          {
            $$= NEW_PTN PT_alter_table_discard_partition_tablespace($3);
          }
        | IMPORT PARTITION_SYM all_or_alt_part_name_list
          TABLESPACE_SYM
          {
            $$= NEW_PTN PT_alter_table_import_partition_tablespace($3);
          }
        | SECONDARY_LOAD_SYM
          {
            $$= NEW_PTN PT_alter_table_secondary_load;
          }
        | SECONDARY_UNLOAD_SYM
          {
            $$= NEW_PTN PT_alter_table_secondary_unload;
          }
        ;
---

standalone_alter_commands:

    DISCARD_SYM TABLESPACE_SYM {
        res = new IR(kStandaloneAlterCommands, OP3("DISCARD TABLESPACE", "", ""));
        $$ = res;
    }

    | IMPORT TABLESPACE_SYM {
        res = new IR(kStandaloneAlterCommands, OP3("IMPORT TABLESPACE", "", ""));
        $$ = res;
    }

    | ADD PARTITION_SYM opt_no_write_to_binlog {
        auto tmp1 = $3;
        res = new IR(kStandaloneAlterCommands, OP3("ADD PARTITION", "", ""), tmp1);
        $$ = res;
    }

    | ADD PARTITION_SYM opt_no_write_to_binlog '(' part_def_list ')' {
        auto tmp1 = $3;
        auto tmp2 = $5;
        res = new IR(kStandaloneAlterCommands, OP3("ADD PARTITION", "(", ")"), tmp1, tmp2);
        $$ = res;
    }

    | ADD PARTITION_SYM opt_no_write_to_binlog PARTITIONS_SYM real_ulong_num {
        auto tmp1 = $3;
        auto tmp2 = $5;
        res = new IR(kStandaloneAlterCommands, OP3("ADD PARTITION", "PARTITIONS", ""), tmp1, tmp2);
        $$ = res;
    }

    | DROP PARTITION_SYM ident_string_list {
        auto tmp1 = $3;
        res = new IR(kStandaloneAlterCommands, OP3("DROP PARTITION", "", ""), tmp1);
        $$ = res;
    }

    | REBUILD_SYM PARTITION_SYM opt_no_write_to_binlog all_or_alt_part_name_list {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kStandaloneAlterCommands, OP3("REBUILD PARTITION", "", ""), tmp1, tmp2);
        $$ = res;
    }

    | OPTIMIZE PARTITION_SYM opt_no_write_to_binlog all_or_alt_part_name_list {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kStandaloneAlterCommands, OP3("OPTIMIZE PARTITION", "", ""), tmp1, tmp2);
        $$ = res;
    }

    | ANALYZE_SYM PARTITION_SYM opt_no_write_to_binlog all_or_alt_part_name_list {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kStandaloneAlterCommands, OP3("ANALYZE PARTITION", "", ""), tmp1, tmp2);
        $$ = res;
    }

    | CHECK_SYM PARTITION_SYM all_or_alt_part_name_list opt_mi_check_types {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kStandaloneAlterCommands, OP3("CHECK PARTITION", "", ""), tmp1, tmp2);
        $$ = res;
    }

    | REPAIR PARTITION_SYM opt_no_write_to_binlog all_or_alt_part_name_list opt_mi_repair_types {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kStandaloneAlterCommands_1, OP3("REPAIR PARTITION", "", ""), tmp1, tmp2);
        PUSH(res);
        auto tmp3 = $5;
        res = new IR(kStandaloneAlterCommands, OP3("", "", ""), res, tmp3);
        $$ = res;
    }

    | COALESCE PARTITION_SYM opt_no_write_to_binlog real_ulong_num {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kStandaloneAlterCommands, OP3("COALESCE PARTITION", "", ""), tmp1, tmp2);
        $$ = res;
    }

    | TRUNCATE_SYM PARTITION_SYM all_or_alt_part_name_list {
        auto tmp1 = $3;
        res = new IR(kStandaloneAlterCommands, OP3("TRUNCATE PARTITION", "", ""), tmp1);
        $$ = res;
    }

    | REORGANIZE_SYM PARTITION_SYM opt_no_write_to_binlog {
        auto tmp1 = $3;
        res = new IR(kStandaloneAlterCommands, OP3("REORGANIZE PARTITION", "", ""), tmp1);
        $$ = res;
    }

    | REORGANIZE_SYM PARTITION_SYM opt_no_write_to_binlog ident_string_list INTO '(' part_def_list ')' {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kStandaloneAlterCommands_2, OP3("REORGANIZE PARTITION", "", "INTO ("), tmp1, tmp2);
        PUSH(res);
        auto tmp3 = $7;
        res = new IR(kStandaloneAlterCommands, OP3("", "", ")"), res, tmp3);
        $$ = res;
    }

    | EXCHANGE_SYM PARTITION_SYM ident WITH TABLE_SYM table_ident opt_with_validation {
        auto tmp1 = $3;
        auto tmp2 = $6;
        res = new IR(kStandaloneAlterCommands_3, OP3("EXCHANGE PARTITION", "WITH TABLE", ""), tmp1, tmp2);
        PUSH(res);
        auto tmp3 = $7;
        res = new IR(kStandaloneAlterCommands, OP3("", "", ""), res, tmp3);
        $$ = res;
    }

    | DISCARD_SYM PARTITION_SYM all_or_alt_part_name_list TABLESPACE_SYM {
        auto tmp1 = $3;
        res = new IR(kStandaloneAlterCommands, OP3("DISCARD PARTITION", "TABLESPACE", ""), tmp1);
        $$ = res;
    }

    | IMPORT PARTITION_SYM all_or_alt_part_name_list TABLESPACE_SYM {
        auto tmp1 = $3;
        res = new IR(kStandaloneAlterCommands, OP3("IMPORT PARTITION", "TABLESPACE", ""), tmp1);
        $$ = res;
    }

    | SECONDARY_LOAD_SYM {
        res = new IR(kStandaloneAlterCommands, OP3("SECONDARY_LOAD", "", ""));
        $$ = res;
    }

    | SECONDARY_UNLOAD_SYM {
        res = new IR(kStandaloneAlterCommands, OP3("SECONDARY_UNLOAD", "", ""));
        $$ = res;
    }

;
