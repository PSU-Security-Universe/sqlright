sql_statement:
          END_OF_INPUT
          {
            THD *thd= YYTHD;
            if (!thd->is_bootstrap_system_thread() &&
                !thd->m_parser_state->has_comment())
            {
              my_error(ER_EMPTY_QUERY, MYF(0));
              MYSQL_YYABORT;
            }
            thd->lex->sql_command= SQLCOM_EMPTY_QUERY;
            YYLIP->found_semicolon= NULL;
          }
        | simple_statement_or_begin
          {
            Lex_input_stream *lip = YYLIP;

            if (YYTHD->get_protocol()->has_client_capability(CLIENT_MULTI_QUERIES) &&
                lip->multi_statements &&
                ! lip->eof())
            {
              /*
                We found a well formed query, and multi queries are allowed:
                - force the parser to stop after the ';'
                - mark the start of the next query for the next invocation
                  of the parser.
              */
              lip->next_state= MY_LEX_END;
              lip->found_semicolon= lip->get_ptr();
            }
            else
            {
              /* Single query, terminated. */
              lip->found_semicolon= NULL;
            }
          }
          ';'
          opt_end_of_input
        | simple_statement_or_begin END_OF_INPUT
          {
            /* Single query, not terminated. */
            YYLIP->found_semicolon= NULL;
          }
        ;

---

sql_statement:

    END_OF_INPUT {
        res = new IR(kSqlStatement, OP3("", "", ""));
        $$ = res;
    }

    | simple_statement_or_begin {} ';' opt_end_of_input {
        auto tmp1 = $1;
        auto tmp2 = $4;
        res = new IR(kSqlStatement, OP3("", ";", ""), tmp1, tmp2);
        $$ = res;
    }

    | simple_statement_or_begin END_OF_INPUT {
        auto tmp1 = $1;
        res = new IR(kSqlStatement, OP3("", "", ""), tmp1);
        $$ = res;
    }

;
