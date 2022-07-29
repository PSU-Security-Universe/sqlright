window_func_call:       // Window functions which do not exist as set functions
          ROW_NUMBER_SYM '(' ')' windowing_clause
          {
            $$=  NEW_PTN Item_row_number(@$, $4);
          }
        | RANK_SYM '(' ')' windowing_clause
          {
            $$= NEW_PTN Item_rank(@$, false, $4);
          }
        | DENSE_RANK_SYM '(' ')' windowing_clause
          {
            $$= NEW_PTN Item_rank(@$, true, $4);
          }
        | CUME_DIST_SYM '(' ')' windowing_clause
          {
            $$=  NEW_PTN Item_cume_dist(@$, $4);
          }
        | PERCENT_RANK_SYM '(' ')' windowing_clause
          {
            $$= NEW_PTN Item_percent_rank(@$, $4);
          }
        | NTILE_SYM '(' stable_integer ')' windowing_clause
          {
            $$=NEW_PTN Item_ntile(@$, $3, $5);
          }
        | LEAD_SYM '(' expr opt_lead_lag_info ')' opt_null_treatment windowing_clause
          {
            PT_item_list *args= NEW_PTN PT_item_list;
            if (args == NULL || args->push_back($3))
              MYSQL_YYABORT; // OOM
            if ($4.offset != NULL && args->push_back($4.offset))
              MYSQL_YYABORT; // OOM
            if ($4.default_value != NULL && args->push_back($4.default_value))
              MYSQL_YYABORT; // OOM
            $$= NEW_PTN Item_lead_lag(@$, true, args, $6, $7);
          }
        | LAG_SYM '(' expr opt_lead_lag_info ')' opt_null_treatment windowing_clause
          {
            PT_item_list *args= NEW_PTN PT_item_list;
            if (args == NULL || args->push_back($3))
              MYSQL_YYABORT; // OOM
            if ($4.offset != NULL && args->push_back($4.offset))
              MYSQL_YYABORT; // OOM
            if ($4.default_value != NULL && args->push_back($4.default_value))
              MYSQL_YYABORT; // OOM
            $$= NEW_PTN Item_lead_lag(@$, false, args, $6, $7);
          }
        | FIRST_VALUE_SYM '(' expr ')' opt_null_treatment windowing_clause
          {
            $$= NEW_PTN Item_first_last_value(@$, true, $3, $5, $6);
          }
        | LAST_VALUE_SYM  '(' expr ')' opt_null_treatment windowing_clause
          {
            $$= NEW_PTN Item_first_last_value(@$, false, $3, $5, $6);
          }
        | NTH_VALUE_SYM '(' expr ',' simple_expr ')' opt_from_first_last opt_null_treatment windowing_clause
          {
            PT_item_list *args= NEW_PTN PT_item_list;
            if (args == NULL ||
                args->push_back($3) ||
                args->push_back($5))
              MYSQL_YYABORT;
            $$= NEW_PTN Item_nth_value(@$, args, $7 == NFL_FROM_LAST, $8, $9);
          }
        ;

---

window_func_call:

    ROW_NUMBER_SYM '(' ')' windowing_clause {
        auto tmp1 = $4;
        res = new IR(kWindowFuncCall, OP3("ROW_NUMBER ( )", "", ""), tmp1);
        $$ = res;
    }

    | RANK_SYM '(' ')' windowing_clause {
        auto tmp1 = $4;
        res = new IR(kWindowFuncCall, OP3("RANK ( )", "", ""), tmp1);
        $$ = res;
    }

    | DENSE_RANK_SYM '(' ')' windowing_clause {
        auto tmp1 = $4;
        res = new IR(kWindowFuncCall, OP3("DENSE_RANK ( )", "", ""), tmp1);
        $$ = res;
    }

    | CUME_DIST_SYM '(' ')' windowing_clause {
        auto tmp1 = $4;
        res = new IR(kWindowFuncCall, OP3("CUME_DIST ( )", "", ""), tmp1);
        $$ = res;
    }

    | PERCENT_RANK_SYM '(' ')' windowing_clause {
        auto tmp1 = $4;
        res = new IR(kWindowFuncCall, OP3("PERCENT_RANK ( )", "", ""), tmp1);
        $$ = res;
    }

    | NTILE_SYM '(' stable_integer ')' windowing_clause {
        auto tmp1 = $3;
        auto tmp2 = $5;
        res = new IR(kWindowFuncCall, OP3("NTILE (", ")", ""), tmp1, tmp2);
        $$ = res;
    }

    | LEAD_SYM '(' expr opt_lead_lag_info ')' opt_null_treatment windowing_clause {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kWindowFuncCall_1, OP3("LEAD (", "", ")"), tmp1, tmp2);
        PUSH(res);
        auto tmp3 = $6;
        res = new IR(kWindowFuncCall_2, OP3("", "", ""), res, tmp3);
        PUSH(res);
        auto tmp4 = $7;
        res = new IR(kWindowFuncCall, OP3("", "", ""), res, tmp4);
        $$ = res;
    }

    | LAG_SYM '(' expr opt_lead_lag_info ')' opt_null_treatment windowing_clause {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kWindowFuncCall_3, OP3("LAG (", "", ")"), tmp1, tmp2);
        PUSH(res);
        auto tmp3 = $6;
        res = new IR(kWindowFuncCall_4, OP3("", "", ""), res, tmp3);
        PUSH(res);
        auto tmp4 = $7;
        res = new IR(kWindowFuncCall, OP3("", "", ""), res, tmp4);
        $$ = res;
    }

    | FIRST_VALUE_SYM '(' expr ')' opt_null_treatment windowing_clause {
        auto tmp1 = $3;
        auto tmp2 = $5;
        res = new IR(kWindowFuncCall_5, OP3("FIRST_VALUE (", ")", ""), tmp1, tmp2);
        PUSH(res);
        auto tmp3 = $6;
        res = new IR(kWindowFuncCall, OP3("", "", ""), res, tmp3);
        $$ = res;
    }

    | LAST_VALUE_SYM '(' expr ')' opt_null_treatment windowing_clause {
        auto tmp1 = $3;
        auto tmp2 = $5;
        res = new IR(kWindowFuncCall_6, OP3("LAST_VALUE (", ")", ""), tmp1, tmp2);
        PUSH(res);
        auto tmp3 = $6;
        res = new IR(kWindowFuncCall, OP3("", "", ""), res, tmp3);
        $$ = res;
    }

    | NTH_VALUE_SYM '(' expr ',' simple_expr ')' opt_from_first_last opt_null_treatment windowing_clause {
        auto tmp1 = $3;
        auto tmp2 = $5;
        res = new IR(kWindowFuncCall_7, OP3("NTH_VALUE (", ",", ")"), tmp1, tmp2);
        PUSH(res);
        auto tmp3 = $7;
        res = new IR(kWindowFuncCall_8, OP3("", "", ""), res, tmp3);
        PUSH(res);
        auto tmp4 = $8;
        res = new IR(kWindowFuncCall_9, OP3("", "", ""), res, tmp4);
        PUSH(res);
        auto tmp5 = $9;
        res = new IR(kWindowFuncCall, OP3("", "", ""), res, tmp5);
        $$ = res;
    }

;
