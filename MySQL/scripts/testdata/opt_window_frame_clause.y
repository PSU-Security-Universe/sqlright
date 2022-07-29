opt_window_frame_clause:
          /* Nothing*/
          {
            $$= NULL;
          }
        | window_frame_units
          window_frame_extent
          opt_window_frame_exclusion
          {
            $$= NEW_PTN PT_frame($1, $2, $3);
          }
        ;
---


opt_window_frame_clause:

    /* Nothing*/ {
        res = new IR(kOptWindowFrameClause, OP3("", "", ""));
        $$ = res;
    }

    | window_frame_units window_frame_extent opt_window_frame_exclusion {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kOptWindowFrameClause_1, OP3("", "", ""), tmp1, tmp2);
        PUSH(res);
        auto tmp3 = $3;
        res = new IR(kOptWindowFrameClause, OP3("", "", ""), res, tmp3);
        $$ = res;
    }

;
