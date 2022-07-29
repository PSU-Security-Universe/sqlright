import click
import sys
from loguru import logger
from translate import translate


def _test(data, expect):
    assert expect.strip() == translate(data).strip()


def TestDropSubscriptionStmt():
    data = """
DropSubscriptionStmt: DROP SUBSCRIPTION name opt_drop_behavior
            {
                DropSubscriptionStmt *n = makeNode(DropSubscriptionStmt);
                n->subname = $3;
                n->missing_ok = false;
                n->behavior = $4;
                $$ = (Node *) n;
            }
            |  DROP SUBSCRIPTION IF_P EXISTS name opt_drop_behavior
            {
                DropSubscriptionStmt *n = makeNode(DropSubscriptionStmt);
                n->subname = $5;
                n->missing_ok = true;
                n->behavior = $6;
                $$ = (Node *) n;
            }
    ;
"""
    expect = """
DropSubscriptionStmt:

    DROP SUBSCRIPTION name opt_drop_behavior {
        auto tmp1 = $3;
        auto tmp2 = $4;
        res = new IR(kDropSubscriptionStmt, OP3("DROP SUBSCRIPTION", "", ""), tmp1, tmp2);
        $$ = res;
    }

    | DROP SUBSCRIPTION IF_P EXISTS name opt_drop_behavior {
        auto tmp1 = $5;
        auto tmp2 = $6;
        res = new IR(kDropSubscriptionStmt, OP3("DROP SUBSCRIPTION IF EXISTS", "", ""), tmp1, tmp2);
        $$ = res;
    }

;
    """

    _test(data, expect)


def TestStmtBlock():
    data = """
stmtblock:	stmtmulti
			{
				pg_yyget_extra(yyscanner)->parsetree = $1;
			}
		;    
"""
    expect = """
stmtblock:

    stmtmulti {
        auto tmp1 = $1;
        res = new IR(kStmtblock, OP3("", "", ""), tmp1);
        $$ = res;
    }

;    
"""
    _test(data, expect)


def TestCreateUserStmt():
    data = """
CreateUserStmt:
			CREATE USER RoleId USER opt_with CREATE OptRoleList USER
				{
					CreateRoleStmt *n = makeNode(CreateRoleStmt);
					n->stmt_type = ROLESTMT_USER;
					n->role = $3;
					n->options = $5;
					$$ = (Node *)n;
				}
		;
    """
    expect = """
CreateUserStmt:

    CREATE USER RoleId USER opt_with CREATE OptRoleList USER {
        auto tmp1 = $3;
        auto tmp2 = $5;
        res = new IR(kCreateUserStmt_1, OP3("CREATE USER", "USER", "CREATE"), tmp1, tmp2);
        auto tmp3 = $7;
        res = new IR(kCreateUserStmt, OP3("", "", "USER"), res, tmp3);
        $$ = res;
    }

;
"""

    _test(data, expect)


def TestStmtMulti():
    data = """
stmtmulti:	stmtmulti ';' stmt
            {
                if ($1 != NIL)
                if ($3 != NULL)
                    $$ = lappend($1, makeRawStmt($3, @2 + 1));
                else
                    $$ = $1;
            }
        | stmt
            {
                if ($1 != NULL)
                    $$ = list_make1(makeRawStmt($1, 0));
                else
                    $$ = NIL;
            }
    ;
"""
    expect = """
stmtmulti:

    stmtmulti ';' stmt {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kStmtmulti, OP3("", ";", ""), tmp1, tmp2);
        $$ = res;
    }

    | stmt {
        auto tmp1 = $1;
        res = new IR(kStmtmulti, OP3("", "", ""), tmp1);
        $$ = res;
    }

;
"""
    _test(data, expect)


def TestOnlyKeywords():
    data = """
stmtmulti:	CREATE USER
        {
        }
;
    """
    expect = """
stmtmulti:

    CREATE USER {
        res = new IR(kStmtmulti, OP3("CREATE USER", "", ""));
        $$ = res;
    }

;
"""
    _test(data, expect)


def TestStmt():
    data = """
stmt:
			AlterEventTrigStmt
			| AlterCollationStmt
			| AlterDatabaseStmt
			| AlterDatabaseSetStmt
			| AlterDefaultPrivilegesStmt
			| AlterDomainStmt
			| AlterEnumStmt
			| AlterExtensionStmt
			| AlterExtensionContentsStmt
			| AlterFdwStmt
			| AlterForeignServerStmt
			| AlterFunctionStmt
			| AlterGroupStmt
			| AlterObjectDependsStmt
			| AlterObjectSchemaStmt
			| AlterOwnerStmt
			| AlterOperatorStmt
			| AlterTypeStmt
			| AlterPolicyStmt
			| AlterSeqStmt
			| AlterSystemStmt
			| AlterTableStmt
			| AlterTblSpcStmt
			| AlterCompositeTypeStmt
			| AlterPublicationStmt
			| AlterRoleSetStmt
			| AlterRoleStmt
			| AlterSubscriptionStmt
			| AlterStatsStmt
			| AlterTSConfigurationStmt
			| AlterTSDictionaryStmt
			| AlterUserMappingStmt
			| AnalyzeStmt
			| CallStmt
			| CheckPointStmt
			| ClosePortalStmt
			| ClusterStmt
			| CommentStmt
			| ConstraintsSetStmt
			| CopyStmt
			| CreateAmStmt
			| CreateAsStmt
			| CreateAssertionStmt
			| CreateCastStmt
			| CreateConversionStmt
			| CreateDomainStmt
			| CreateExtensionStmt
			| CreateFdwStmt
			| CreateForeignServerStmt
			| CreateForeignTableStmt
			| CreateFunctionStmt
			| CreateGroupStmt
			| CreateMatViewStmt
			| CreateOpClassStmt
			| CreateOpFamilyStmt
			| CreatePublicationStmt
			| AlterOpFamilyStmt
			| CreatePolicyStmt
			| CreatePLangStmt
			| CreateSchemaStmt
			| CreateSeqStmt
			| CreateStmt
			| CreateSubscriptionStmt
			| CreateStatsStmt
			| CreateTableSpaceStmt
			| CreateTransformStmt
			| CreateTrigStmt
			| CreateEventTrigStmt
			| CreateRoleStmt
			| CreateUserStmt
			| CreateUserMappingStmt
			| CreatedbStmt
			| DeallocateStmt
			| DeclareCursorStmt
			| DefineStmt
			| DeleteStmt
			| DiscardStmt
			| DoStmt
			| DropCastStmt
			| DropOpClassStmt
			| DropOpFamilyStmt
			| DropOwnedStmt
			| DropStmt
			| DropSubscriptionStmt
			| DropTableSpaceStmt
			| DropTransformStmt
			| DropRoleStmt
			| DropUserMappingStmt
			| DropdbStmt
			| ExecuteStmt
			| ExplainStmt
			| FetchStmt
			| GrantStmt
			| GrantRoleStmt
			| ImportForeignSchemaStmt
			| IndexStmt
			| InsertStmt
			| ListenStmt
			| RefreshMatViewStmt
			| LoadStmt
			| LockStmt
			| NotifyStmt
			| PrepareStmt
			| ReassignOwnedStmt
			| ReindexStmt
			| RemoveAggrStmt
			| RemoveFuncStmt
			| RemoveOperStmt
			| RenameStmt
			| RevokeStmt
			| RevokeRoleStmt
			| RuleStmt
			| SecLabelStmt
			| SelectStmt
			| TransactionStmt
			| TruncateStmt
			| UnlistenStmt
			| UpdateStmt
			| VacuumStmt
			| VariableResetStmt
			| VariableSetStmt
			| VariableShowStmt
			| ViewStmt
			| /*EMPTY*/
				{ $$ = NULL; }
		;    
"""
    expect = """
stmt:

    AlterEventTrigStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | AlterCollationStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | AlterDatabaseStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | AlterDatabaseSetStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | AlterDefaultPrivilegesStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | AlterDomainStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | AlterEnumStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | AlterExtensionStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | AlterExtensionContentsStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | AlterFdwStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | AlterForeignServerStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | AlterFunctionStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | AlterGroupStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | AlterObjectDependsStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | AlterObjectSchemaStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | AlterOwnerStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | AlterOperatorStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | AlterTypeStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | AlterPolicyStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | AlterSeqStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | AlterSystemStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | AlterTableStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | AlterTblSpcStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | AlterCompositeTypeStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | AlterPublicationStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | AlterRoleSetStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | AlterRoleStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | AlterSubscriptionStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | AlterStatsStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | AlterTSConfigurationStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | AlterTSDictionaryStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | AlterUserMappingStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | AnalyzeStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | CallStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | CheckPointStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | ClosePortalStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | ClusterStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | CommentStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | ConstraintsSetStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | CopyStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | CreateAmStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | CreateAsStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | CreateAssertionStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | CreateCastStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | CreateConversionStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | CreateDomainStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | CreateExtensionStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | CreateFdwStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | CreateForeignServerStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | CreateForeignTableStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | CreateFunctionStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | CreateGroupStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | CreateMatViewStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | CreateOpClassStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | CreateOpFamilyStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | CreatePublicationStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | AlterOpFamilyStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | CreatePolicyStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | CreatePLangStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | CreateSchemaStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | CreateSeqStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | CreateStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | CreateSubscriptionStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | CreateStatsStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | CreateTableSpaceStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | CreateTransformStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | CreateTrigStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | CreateEventTrigStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | CreateRoleStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | CreateUserStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | CreateUserMappingStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | CreatedbStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | DeallocateStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | DeclareCursorStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | DefineStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | DeleteStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | DiscardStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | DoStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | DropCastStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | DropOpClassStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | DropOpFamilyStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | DropOwnedStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | DropStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | DropSubscriptionStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | DropTableSpaceStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | DropTransformStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | DropRoleStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | DropUserMappingStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | DropdbStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | ExecuteStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | ExplainStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | FetchStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | GrantStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | GrantRoleStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | ImportForeignSchemaStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | IndexStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | InsertStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | ListenStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | RefreshMatViewStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | LoadStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | LockStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | NotifyStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | PrepareStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | ReassignOwnedStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | ReindexStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | RemoveAggrStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | RemoveFuncStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | RemoveOperStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | RenameStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | RevokeStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | RevokeRoleStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | RuleStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | SecLabelStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | SelectStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | TransactionStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | TruncateStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | UnlistenStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | UpdateStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | VacuumStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | VariableResetStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | VariableSetStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | VariableShowStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | ViewStmt {
        auto tmp1 = $1;
        res = new IR(kStmt, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kStmt, OP3("", "", ""));
        $$ = res;
    }

;    
"""
    _test(data, expect)


def TestSingleLine():

    data = """
name:		ColId									{ $$ = $1; };
"""
    expect = """
name:

    ColId {
        auto tmp1 = $1;
        res = new IR(kName, OP3("", "", ""), tmp1);
        $$ = res;
    }

;
"""
    _test(data, expect)


def TestConstraintAttributeSpec():
    data = """
ConstraintAttributeSpec:
			/*EMPTY*/
				{ $$ = 0; }
			| ConstraintAttributeSpec ConstraintAttributeElem
				{
					/*
					 * We must complain about conflicting options.
					 * We could, but choose not to, complain about redundant
					 * options (ie, where $2's bit is already set in $1).
					 */
					int		newspec = $1 | $2;

					/* special message for this case */
					if ((newspec & (CAS_NOT_DEFERRABLE | CAS_INITIALLY_DEFERRED)) == (CAS_NOT_DEFERRABLE | CAS_INITIALLY_DEFERRED))
						ereport(ERROR,
								(errcode(ERRCODE_SYNTAX_ERROR),
								 errmsg("constraint declared INITIALLY DEFERRED must be DEFERRABLE"),
								 parser_errposition(@2)));
					/* generic message for other conflicts */
					if ((newspec & (CAS_NOT_DEFERRABLE | CAS_DEFERRABLE)) == (CAS_NOT_DEFERRABLE | CAS_DEFERRABLE) ||
						(newspec & (CAS_INITIALLY_IMMEDIATE | CAS_INITIALLY_DEFERRED)) == (CAS_INITIALLY_IMMEDIATE | CAS_INITIALLY_DEFERRED))
						ereport(ERROR,
								(errcode(ERRCODE_SYNTAX_ERROR),
								 errmsg("conflicting constraint properties"),
								 parser_errposition(@2)));
					$$ = newspec;
				}
		;    
"""
    expect = """
ConstraintAttributeSpec:

    /*EMPTY*/ {
        res = new IR(kConstraintAttributeSpec, OP3("", "", ""));
        $$ = res;
    }

    | ConstraintAttributeSpec ConstraintAttributeElem {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kConstraintAttributeSpec, OP3("", "", ""), tmp1, tmp2);
        $$ = res;
    }

;
"""
    _test(data, expect)


def TestEventTriggerWhenItem():
    data = """
event_trigger_when_item:
		ColId IN_P '(' event_trigger_value_list ')'
			{ $$ = makeDefElem($1, (Node *) $4, @1); }
		;    
		| ColId IN_P '(' event_trigger_value_list ')'
			{ $$ = makeDefElem($1, (Node *) $4, @1); }
		;    
"""

    expect = """
event_trigger_when_item:

    ColId IN_P '(' event_trigger_value_list ')' ; {
        auto tmp1 = $1;
        auto tmp2 = $4;
        res = new IR(kEventTriggerWhenItem_1, OP3("", "IN (", ")"), tmp1, tmp2);
        auto tmp3 = $6;
        res = new IR(kEventTriggerWhenItem, OP3("", "", ""), res, tmp3);
        $$ = res;
    }

    | ColId IN_P '(' event_trigger_value_list ')' {
        auto tmp1 = $1;
        auto tmp2 = $4;
        res = new IR(kEventTriggerWhenItem, OP3("", "IN (", ")"), tmp1, tmp2);
        $$ = res;
    }

;
"""

    _test(data, expect)


def TestWhenClauseList():
    data = """
when_clause_list:
			/* There must be at least one */
			when_clause								{ $$ = list_make1($1); }
			| when_clause_list when_clause			{ $$ = lappend($1, $2); }
		;    
"""
    expect = """
when_clause_list:

    when_clause {
        auto tmp1 = $1;
        res = new IR(kWhenClauseList, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | when_clause_list when_clause {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kWhenClauseList, OP3("", "", ""), tmp1, tmp2);
        $$ = res;
    }

;    
"""
    _test(data, expect)


def TestOptCreatefuncOptList():
    data = """
opt_createfunc_opt_list:
			createfunc_opt_list
			| /*EMPTY*/ { $$ = NIL; }
	;    
"""
    expect = """
opt_createfunc_opt_list:

    createfunc_opt_list {
        auto tmp1 = $1;
        res = new IR(kOptCreatefuncOptList, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptCreatefuncOptList, OP3("", "", ""));
        $$ = res;
    }

;    
"""
    _test(data, expect)


def TestEvent():
    data = """
event:		SELECT									{ $$ = CMD_SELECT; }
			| UPDATE								{ $$ = CMD_UPDATE; }
			| DELETE_P								{ $$ = CMD_DELETE; }
			| INSERT								{ $$ = CMD_INSERT; }
		 ;
"""
    expect = """
event:

    SELECT {
        res = new IR(kEvent, OP3("SELECT", "", ""));
        $$ = res;
    }

    | UPDATE {
        res = new IR(kEvent, OP3("UPDATE", "", ""));
        $$ = res;
    }

    | DELETE_P {
        res = new IR(kEvent, OP3("DELETE", "", ""));
        $$ = res;
    }

    | INSERT {
        res = new IR(kEvent, OP3("INSERT", "", ""));
        $$ = res;
    }

;
"""
    _test(data, expect)


def TestFuncApplication():
    data = """
func_application: func_name '(' ')'
				{
					$$ = (Node *) makeFuncCall($1, NIL,
											   COERCE_EXPLICIT_CALL,
											   @1);
				}
			| func_name '(' func_arg_list opt_sort_clause ')'
				{
					FuncCall *n = makeFuncCall($1, $3,
											   COERCE_EXPLICIT_CALL,
											   @1);
					n->agg_order = $4;
					$$ = (Node *)n;
				}
			| func_name '(' VARIADIC func_arg_expr opt_sort_clause ')'
				{
					FuncCall *n = makeFuncCall($1, list_make1($4),
											   COERCE_EXPLICIT_CALL,
											   @1);
					n->func_variadic = true;
					n->agg_order = $5;
					$$ = (Node *)n;
				}
			| func_name '(' func_arg_list ',' VARIADIC func_arg_expr opt_sort_clause ')'
				{
					FuncCall *n = makeFuncCall($1, lappend($3, $6),
											   COERCE_EXPLICIT_CALL,
											   @1);
					n->func_variadic = true;
					n->agg_order = $7;
					$$ = (Node *)n;
				}
			| func_name '(' ALL func_arg_list opt_sort_clause ')'
				{
					FuncCall *n = makeFuncCall($1, $4,
											   COERCE_EXPLICIT_CALL,
											   @1);
					n->agg_order = $5;
					/* Ideally we'd mark the FuncCall node to indicate
					 * "must be an aggregate", but there's no provision
					 * for that in FuncCall at the moment.
					 */
					$$ = (Node *)n;
				}
			| func_name '(' DISTINCT func_arg_list opt_sort_clause ')'
				{
					FuncCall *n = makeFuncCall($1, $4,
											   COERCE_EXPLICIT_CALL,
											   @1);
					n->agg_order = $5;
					n->agg_distinct = true;
					$$ = (Node *)n;
				}
			| func_name '(' '*' ')'
				{
					/*
					 * We consider AGGREGATE(*) to invoke a parameterless
					 * aggregate.  This does the right thing for COUNT(*),
					 * and there are no other aggregates in SQL that accept
					 * '*' as parameter.
					 *
					 * The FuncCall node is also marked agg_star = true,
					 * so that later processing can detect what the argument
					 * really was.
					 */
					FuncCall *n = makeFuncCall($1, NIL,
											   COERCE_EXPLICIT_CALL,
											   @1);
					n->agg_star = true;
					$$ = (Node *)n;
				}
		;

"""
    expect = """
func_application:

    func_name '(' ')' {
        auto tmp1 = $1;
        res = new IR(kFuncApplication, OP3("", "( )", ""), tmp1);
        $$ = res;
    }

    | func_name '(' func_arg_list opt_sort_clause ')' {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kFuncApplication_1, OP3("", "(", ""), tmp1, tmp2);
        auto tmp3 = $4;
        res = new IR(kFuncApplication, OP3("", "", ")"), res, tmp3);
        $$ = res;
    }

    | func_name '(' VARIADIC func_arg_expr opt_sort_clause ')' {
        auto tmp1 = $1;
        auto tmp2 = $4;
        res = new IR(kFuncApplication_2, OP3("", "( VARIADIC", ""), tmp1, tmp2);
        auto tmp3 = $5;
        res = new IR(kFuncApplication, OP3("", "", ")"), res, tmp3);
        $$ = res;
    }

    | func_name '(' func_arg_list ',' VARIADIC func_arg_expr opt_sort_clause ')' {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kFuncApplication_3, OP3("", "(", ", VARIADIC"), tmp1, tmp2);
        auto tmp3 = $6;
        res = new IR(kFuncApplication_4, OP3("", "", ""), res, tmp3);
        auto tmp4 = $7;
        res = new IR(kFuncApplication, OP3("", "", ")"), res, tmp4);
        $$ = res;
    }

    | func_name '(' ALL func_arg_list opt_sort_clause ')' {
        auto tmp1 = $1;
        auto tmp2 = $4;
        res = new IR(kFuncApplication_5, OP3("", "( ALL", ""), tmp1, tmp2);
        auto tmp3 = $5;
        res = new IR(kFuncApplication, OP3("", "", ")"), res, tmp3);
        $$ = res;
    }

    | func_name '(' DISTINCT func_arg_list opt_sort_clause ')' {
        auto tmp1 = $1;
        auto tmp2 = $4;
        res = new IR(kFuncApplication_6, OP3("", "( DISTINCT", ""), tmp1, tmp2);
        auto tmp3 = $5;
        res = new IR(kFuncApplication, OP3("", "", ")"), res, tmp3);
        $$ = res;
    }

    | func_name '(' '*' ')' {
        auto tmp1 = $1;
        res = new IR(kFuncApplication, OP3("", "( * )", ""), tmp1);
        $$ = res;
    }

;
"""
    _test(data, expect)


def TestBareLabelKeyword():
    data = """
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

"""

    expect = """
bare_label_keyword:

    ABORT_P {
        res = new IR(kBareLabelKeyword, OP3("ABORT", "", ""));
        $$ = res;
    }

    | ABSOLUTE_P {
        res = new IR(kBareLabelKeyword, OP3("ABSOLUTE", "", ""));
        $$ = res;
    }

    | ACCESS {
        res = new IR(kBareLabelKeyword, OP3("ACCESS", "", ""));
        $$ = res;
    }

    | ACTION {
        res = new IR(kBareLabelKeyword, OP3("ACTION", "", ""));
        $$ = res;
    }

    | ADD_P {
        res = new IR(kBareLabelKeyword, OP3("ADD", "", ""));
        $$ = res;
    }

    | ADMIN {
        res = new IR(kBareLabelKeyword, OP3("ADMIN", "", ""));
        $$ = res;
    }

    | AFTER {
        res = new IR(kBareLabelKeyword, OP3("AFTER", "", ""));
        $$ = res;
    }

    | AGGREGATE {
        res = new IR(kBareLabelKeyword, OP3("AGGREGATE", "", ""));
        $$ = res;
    }

    | ALL {
        res = new IR(kBareLabelKeyword, OP3("ALL", "", ""));
        $$ = res;
    }

    | ALSO {
        res = new IR(kBareLabelKeyword, OP3("ALSO", "", ""));
        $$ = res;
    }

    | ALTER {
        res = new IR(kBareLabelKeyword, OP3("ALTER", "", ""));
        $$ = res;
    }

    | ALWAYS {
        res = new IR(kBareLabelKeyword, OP3("ALWAYS", "", ""));
        $$ = res;
    }

    | ANALYSE {
        res = new IR(kBareLabelKeyword, OP3("ANALYSE", "", ""));
        $$ = res;
    }

    | ANALYZE {
        res = new IR(kBareLabelKeyword, OP3("ANALYZE", "", ""));
        $$ = res;
    }

    | AND {
        res = new IR(kBareLabelKeyword, OP3("AND", "", ""));
        $$ = res;
    }

    | ANY {
        res = new IR(kBareLabelKeyword, OP3("ANY", "", ""));
        $$ = res;
    }

    | ASC {
        res = new IR(kBareLabelKeyword, OP3("ASC", "", ""));
        $$ = res;
    }

    | ASENSITIVE {
        res = new IR(kBareLabelKeyword, OP3("ASENSITIVE", "", ""));
        $$ = res;
    }

    | ASSERTION {
        res = new IR(kBareLabelKeyword, OP3("ASSERTION", "", ""));
        $$ = res;
    }

    | ASSIGNMENT {
        res = new IR(kBareLabelKeyword, OP3("ASSIGNMENT", "", ""));
        $$ = res;
    }

    | ASYMMETRIC {
        res = new IR(kBareLabelKeyword, OP3("ASYMMETRIC", "", ""));
        $$ = res;
    }

    | AT {
        res = new IR(kBareLabelKeyword, OP3("AT", "", ""));
        $$ = res;
    }

    | ATOMIC {
        res = new IR(kBareLabelKeyword, OP3("ATOMIC", "", ""));
        $$ = res;
    }

    | ATTACH {
        res = new IR(kBareLabelKeyword, OP3("ATTACH", "", ""));
        $$ = res;
    }

    | ATTRIBUTE {
        res = new IR(kBareLabelKeyword, OP3("ATTRIBUTE", "", ""));
        $$ = res;
    }

    | AUTHORIZATION {
        res = new IR(kBareLabelKeyword, OP3("AUTHORIZATION", "", ""));
        $$ = res;
    }

    | BACKWARD {
        res = new IR(kBareLabelKeyword, OP3("BACKWARD", "", ""));
        $$ = res;
    }

    | BEFORE {
        res = new IR(kBareLabelKeyword, OP3("BEFORE", "", ""));
        $$ = res;
    }

    | BEGIN_P {
        res = new IR(kBareLabelKeyword, OP3("BEGIN", "", ""));
        $$ = res;
    }

    | BETWEEN {
        res = new IR(kBareLabelKeyword, OP3("BETWEEN", "", ""));
        $$ = res;
    }

    | BIGINT {
        res = new IR(kBareLabelKeyword, OP3("BIGINT", "", ""));
        $$ = res;
    }

    | BINARY {
        res = new IR(kBareLabelKeyword, OP3("BINARY", "", ""));
        $$ = res;
    }

    | BIT {
        res = new IR(kBareLabelKeyword, OP3("BIT", "", ""));
        $$ = res;
    }

    | BOOLEAN_P {
        res = new IR(kBareLabelKeyword, OP3("BOOLEAN", "", ""));
        $$ = res;
    }

    | BOTH {
        res = new IR(kBareLabelKeyword, OP3("BOTH", "", ""));
        $$ = res;
    }

    | BREADTH {
        res = new IR(kBareLabelKeyword, OP3("BREADTH", "", ""));
        $$ = res;
    }

    | BY {
        res = new IR(kBareLabelKeyword, OP3("BY", "", ""));
        $$ = res;
    }

    | CACHE {
        res = new IR(kBareLabelKeyword, OP3("CACHE", "", ""));
        $$ = res;
    }

    | CALL {
        res = new IR(kBareLabelKeyword, OP3("CALL", "", ""));
        $$ = res;
    }

    | CALLED {
        res = new IR(kBareLabelKeyword, OP3("CALLED", "", ""));
        $$ = res;
    }

    | CASCADE {
        res = new IR(kBareLabelKeyword, OP3("CASCADE", "", ""));
        $$ = res;
    }

    | CASCADED {
        res = new IR(kBareLabelKeyword, OP3("CASCADED", "", ""));
        $$ = res;
    }

    | CASE {
        res = new IR(kBareLabelKeyword, OP3("CASE", "", ""));
        $$ = res;
    }

    | CAST {
        res = new IR(kBareLabelKeyword, OP3("CAST", "", ""));
        $$ = res;
    }

    | CATALOG_P {
        res = new IR(kBareLabelKeyword, OP3("CATALOG", "", ""));
        $$ = res;
    }

    | CHAIN {
        res = new IR(kBareLabelKeyword, OP3("CHAIN", "", ""));
        $$ = res;
    }

    | CHARACTERISTICS {
        res = new IR(kBareLabelKeyword, OP3("CHARACTERISTICS", "", ""));
        $$ = res;
    }

    | CHECK {
        res = new IR(kBareLabelKeyword, OP3("CHECK", "", ""));
        $$ = res;
    }

    | CHECKPOINT {
        res = new IR(kBareLabelKeyword, OP3("CHECKPOINT", "", ""));
        $$ = res;
    }

    | CLASS {
        res = new IR(kBareLabelKeyword, OP3("CLASS", "", ""));
        $$ = res;
    }

    | CLOSE {
        res = new IR(kBareLabelKeyword, OP3("CLOSE", "", ""));
        $$ = res;
    }

    | CLUSTER {
        res = new IR(kBareLabelKeyword, OP3("CLUSTER", "", ""));
        $$ = res;
    }

    | COALESCE {
        res = new IR(kBareLabelKeyword, OP3("COALESCE", "", ""));
        $$ = res;
    }

    | COLLATE {
        res = new IR(kBareLabelKeyword, OP3("COLLATE", "", ""));
        $$ = res;
    }

    | COLLATION {
        res = new IR(kBareLabelKeyword, OP3("COLLATION", "", ""));
        $$ = res;
    }

    | COLUMN {
        res = new IR(kBareLabelKeyword, OP3("COLUMN", "", ""));
        $$ = res;
    }

    | COLUMNS {
        res = new IR(kBareLabelKeyword, OP3("COLUMNS", "", ""));
        $$ = res;
    }

    | COMMENT {
        res = new IR(kBareLabelKeyword, OP3("COMMENT", "", ""));
        $$ = res;
    }

    | COMMENTS {
        res = new IR(kBareLabelKeyword, OP3("COMMENTS", "", ""));
        $$ = res;
    }

    | COMMIT {
        res = new IR(kBareLabelKeyword, OP3("COMMIT", "", ""));
        $$ = res;
    }

    | COMMITTED {
        res = new IR(kBareLabelKeyword, OP3("COMMITTED", "", ""));
        $$ = res;
    }

    | COMPRESSION {
        res = new IR(kBareLabelKeyword, OP3("COMPRESSION", "", ""));
        $$ = res;
    }

    | CONCURRENTLY {
        res = new IR(kBareLabelKeyword, OP3("CONCURRENTLY", "", ""));
        $$ = res;
    }

    | CONFIGURATION {
        res = new IR(kBareLabelKeyword, OP3("CONFIGURATION", "", ""));
        $$ = res;
    }

    | CONFLICT {
        res = new IR(kBareLabelKeyword, OP3("CONFLICT", "", ""));
        $$ = res;
    }

    | CONNECTION {
        res = new IR(kBareLabelKeyword, OP3("CONNECTION", "", ""));
        $$ = res;
    }

    | CONSTRAINT {
        res = new IR(kBareLabelKeyword, OP3("CONSTRAINT", "", ""));
        $$ = res;
    }

    | CONSTRAINTS {
        res = new IR(kBareLabelKeyword, OP3("CONSTRAINTS", "", ""));
        $$ = res;
    }

    | CONTENT_P {
        res = new IR(kBareLabelKeyword, OP3("CONTENT", "", ""));
        $$ = res;
    }

    | CONTINUE_P {
        res = new IR(kBareLabelKeyword, OP3("CONTINUE", "", ""));
        $$ = res;
    }

    | CONVERSION_P {
        res = new IR(kBareLabelKeyword, OP3("CONVERSION", "", ""));
        $$ = res;
    }

    | COPY {
        res = new IR(kBareLabelKeyword, OP3("COPY", "", ""));
        $$ = res;
    }

    | COST {
        res = new IR(kBareLabelKeyword, OP3("COST", "", ""));
        $$ = res;
    }

    | CROSS {
        res = new IR(kBareLabelKeyword, OP3("CROSS", "", ""));
        $$ = res;
    }

    | CSV {
        res = new IR(kBareLabelKeyword, OP3("CSV", "", ""));
        $$ = res;
    }

    | CUBE {
        res = new IR(kBareLabelKeyword, OP3("CUBE", "", ""));
        $$ = res;
    }

    | CURRENT_P {
        res = new IR(kBareLabelKeyword, OP3("CURRENT", "", ""));
        $$ = res;
    }

    | CURRENT_CATALOG {
        res = new IR(kBareLabelKeyword, OP3("CURRENT_CATALOG", "", ""));
        $$ = res;
    }

    | CURRENT_DATE {
        res = new IR(kBareLabelKeyword, OP3("CURRENT_DATE", "", ""));
        $$ = res;
    }

    | CURRENT_ROLE {
        res = new IR(kBareLabelKeyword, OP3("CURRENT_ROLE", "", ""));
        $$ = res;
    }

    | CURRENT_SCHEMA {
        res = new IR(kBareLabelKeyword, OP3("CURRENT_SCHEMA", "", ""));
        $$ = res;
    }

    | CURRENT_TIME {
        res = new IR(kBareLabelKeyword, OP3("CURRENT_TIME", "", ""));
        $$ = res;
    }

    | CURRENT_TIMESTAMP {
        res = new IR(kBareLabelKeyword, OP3("CURRENT_TIMESTAMP", "", ""));
        $$ = res;
    }

    | CURRENT_USER {
        res = new IR(kBareLabelKeyword, OP3("CURRENT_USER", "", ""));
        $$ = res;
    }

    | CURSOR {
        res = new IR(kBareLabelKeyword, OP3("CURSOR", "", ""));
        $$ = res;
    }

    | CYCLE {
        res = new IR(kBareLabelKeyword, OP3("CYCLE", "", ""));
        $$ = res;
    }

    | DATA_P {
        res = new IR(kBareLabelKeyword, OP3("DATA", "", ""));
        $$ = res;
    }

    | DATABASE {
        res = new IR(kBareLabelKeyword, OP3("DATABASE", "", ""));
        $$ = res;
    }

    | DEALLOCATE {
        res = new IR(kBareLabelKeyword, OP3("DEALLOCATE", "", ""));
        $$ = res;
    }

    | DEC {
        res = new IR(kBareLabelKeyword, OP3("DEC", "", ""));
        $$ = res;
    }

    | DECIMAL_P {
        res = new IR(kBareLabelKeyword, OP3("DECIMAL", "", ""));
        $$ = res;
    }

    | DECLARE {
        res = new IR(kBareLabelKeyword, OP3("DECLARE", "", ""));
        $$ = res;
    }

    | DEFAULT {
        res = new IR(kBareLabelKeyword, OP3("DEFAULT", "", ""));
        $$ = res;
    }

    | DEFAULTS {
        res = new IR(kBareLabelKeyword, OP3("DEFAULTS", "", ""));
        $$ = res;
    }

    | DEFERRABLE {
        res = new IR(kBareLabelKeyword, OP3("DEFERRABLE", "", ""));
        $$ = res;
    }

    | DEFERRED {
        res = new IR(kBareLabelKeyword, OP3("DEFERRED", "", ""));
        $$ = res;
    }

    | DEFINER {
        res = new IR(kBareLabelKeyword, OP3("DEFINER", "", ""));
        $$ = res;
    }

    | DELETE_P {
        res = new IR(kBareLabelKeyword, OP3("DELETE", "", ""));
        $$ = res;
    }

    | DELIMITER {
        res = new IR(kBareLabelKeyword, OP3("DELIMITER", "", ""));
        $$ = res;
    }

    | DELIMITERS {
        res = new IR(kBareLabelKeyword, OP3("DELIMITERS", "", ""));
        $$ = res;
    }

    | DEPENDS {
        res = new IR(kBareLabelKeyword, OP3("DEPENDS", "", ""));
        $$ = res;
    }

    | DEPTH {
        res = new IR(kBareLabelKeyword, OP3("DEPTH", "", ""));
        $$ = res;
    }

    | DESC {
        res = new IR(kBareLabelKeyword, OP3("DESC", "", ""));
        $$ = res;
    }

    | DETACH {
        res = new IR(kBareLabelKeyword, OP3("DETACH", "", ""));
        $$ = res;
    }

    | DICTIONARY {
        res = new IR(kBareLabelKeyword, OP3("DICTIONARY", "", ""));
        $$ = res;
    }

    | DISABLE_P {
        res = new IR(kBareLabelKeyword, OP3("DISABLE", "", ""));
        $$ = res;
    }

    | DISCARD {
        res = new IR(kBareLabelKeyword, OP3("DISCARD", "", ""));
        $$ = res;
    }

    | DISTINCT {
        res = new IR(kBareLabelKeyword, OP3("DISTINCT", "", ""));
        $$ = res;
    }

    | DO {
        res = new IR(kBareLabelKeyword, OP3("DO", "", ""));
        $$ = res;
    }

    | DOCUMENT_P {
        res = new IR(kBareLabelKeyword, OP3("DOCUMENT", "", ""));
        $$ = res;
    }

    | DOMAIN_P {
        res = new IR(kBareLabelKeyword, OP3("DOMAIN", "", ""));
        $$ = res;
    }

    | DOUBLE_P {
        res = new IR(kBareLabelKeyword, OP3("DOUBLE", "", ""));
        $$ = res;
    }

    | DROP {
        res = new IR(kBareLabelKeyword, OP3("DROP", "", ""));
        $$ = res;
    }

    | EACH {
        res = new IR(kBareLabelKeyword, OP3("EACH", "", ""));
        $$ = res;
    }

    | ELSE {
        res = new IR(kBareLabelKeyword, OP3("ELSE", "", ""));
        $$ = res;
    }

    | ENABLE_P {
        res = new IR(kBareLabelKeyword, OP3("ENABLE", "", ""));
        $$ = res;
    }

    | ENCODING {
        res = new IR(kBareLabelKeyword, OP3("ENCODING", "", ""));
        $$ = res;
    }

    | ENCRYPTED {
        res = new IR(kBareLabelKeyword, OP3("ENCRYPTED", "", ""));
        $$ = res;
    }

    | END_P {
        res = new IR(kBareLabelKeyword, OP3("END", "", ""));
        $$ = res;
    }

    | ENUM_P {
        res = new IR(kBareLabelKeyword, OP3("ENUM", "", ""));
        $$ = res;
    }

    | ESCAPE {
        res = new IR(kBareLabelKeyword, OP3("ESCAPE", "", ""));
        $$ = res;
    }

    | EVENT {
        res = new IR(kBareLabelKeyword, OP3("EVENT", "", ""));
        $$ = res;
    }

    | EXCLUDE {
        res = new IR(kBareLabelKeyword, OP3("EXCLUDE", "", ""));
        $$ = res;
    }

    | EXCLUDING {
        res = new IR(kBareLabelKeyword, OP3("EXCLUDING", "", ""));
        $$ = res;
    }

    | EXCLUSIVE {
        res = new IR(kBareLabelKeyword, OP3("EXCLUSIVE", "", ""));
        $$ = res;
    }

    | EXECUTE {
        res = new IR(kBareLabelKeyword, OP3("EXECUTE", "", ""));
        $$ = res;
    }

    | EXISTS {
        res = new IR(kBareLabelKeyword, OP3("EXISTS", "", ""));
        $$ = res;
    }

    | EXPLAIN {
        res = new IR(kBareLabelKeyword, OP3("EXPLAIN", "", ""));
        $$ = res;
    }

    | EXPRESSION {
        res = new IR(kBareLabelKeyword, OP3("EXPRESSION", "", ""));
        $$ = res;
    }

    | EXTENSION {
        res = new IR(kBareLabelKeyword, OP3("EXTENSION", "", ""));
        $$ = res;
    }

    | EXTERNAL {
        res = new IR(kBareLabelKeyword, OP3("EXTERNAL", "", ""));
        $$ = res;
    }

    | EXTRACT {
        res = new IR(kBareLabelKeyword, OP3("EXTRACT", "", ""));
        $$ = res;
    }

    | FALSE_P {
        res = new IR(kBareLabelKeyword, OP3("FALSE", "", ""));
        $$ = res;
    }

    | FAMILY {
        res = new IR(kBareLabelKeyword, OP3("FAMILY", "", ""));
        $$ = res;
    }

    | FINALIZE {
        res = new IR(kBareLabelKeyword, OP3("FINALIZE", "", ""));
        $$ = res;
    }

    | FIRST_P {
        res = new IR(kBareLabelKeyword, OP3("FIRST", "", ""));
        $$ = res;
    }

    | FLOAT_P {
        res = new IR(kBareLabelKeyword, OP3("FLOAT", "", ""));
        $$ = res;
    }

    | FOLLOWING {
        res = new IR(kBareLabelKeyword, OP3("FOLLOWING", "", ""));
        $$ = res;
    }

    | FORCE {
        res = new IR(kBareLabelKeyword, OP3("FORCE", "", ""));
        $$ = res;
    }

    | FOREIGN {
        res = new IR(kBareLabelKeyword, OP3("FOREIGN", "", ""));
        $$ = res;
    }

    | FORWARD {
        res = new IR(kBareLabelKeyword, OP3("FORWARD", "", ""));
        $$ = res;
    }

    | FREEZE {
        res = new IR(kBareLabelKeyword, OP3("FREEZE", "", ""));
        $$ = res;
    }

    | FULL {
        res = new IR(kBareLabelKeyword, OP3("FULL", "", ""));
        $$ = res;
    }

    | FUNCTION {
        res = new IR(kBareLabelKeyword, OP3("FUNCTION", "", ""));
        $$ = res;
    }

    | FUNCTIONS {
        res = new IR(kBareLabelKeyword, OP3("FUNCTIONS", "", ""));
        $$ = res;
    }

    | GENERATED {
        res = new IR(kBareLabelKeyword, OP3("GENERATED", "", ""));
        $$ = res;
    }

    | GLOBAL {
        res = new IR(kBareLabelKeyword, OP3("GLOBAL", "", ""));
        $$ = res;
    }

    | GRANTED {
        res = new IR(kBareLabelKeyword, OP3("GRANTED", "", ""));
        $$ = res;
    }

    | GREATEST {
        res = new IR(kBareLabelKeyword, OP3("GREATEST", "", ""));
        $$ = res;
    }

    | GROUPING {
        res = new IR(kBareLabelKeyword, OP3("GROUPING", "", ""));
        $$ = res;
    }

    | GROUPS {
        res = new IR(kBareLabelKeyword, OP3("GROUPS", "", ""));
        $$ = res;
    }

    | HANDLER {
        res = new IR(kBareLabelKeyword, OP3("HANDLER", "", ""));
        $$ = res;
    }

    | HEADER_P {
        res = new IR(kBareLabelKeyword, OP3("HEADER", "", ""));
        $$ = res;
    }

    | HOLD {
        res = new IR(kBareLabelKeyword, OP3("HOLD", "", ""));
        $$ = res;
    }

    | IDENTITY_P {
        res = new IR(kBareLabelKeyword, OP3("IDENTITY", "", ""));
        $$ = res;
    }

    | IF_P {
        res = new IR(kBareLabelKeyword, OP3("IF", "", ""));
        $$ = res;
    }

    | ILIKE {
        res = new IR(kBareLabelKeyword, OP3("ILIKE", "", ""));
        $$ = res;
    }

    | IMMEDIATE {
        res = new IR(kBareLabelKeyword, OP3("IMMEDIATE", "", ""));
        $$ = res;
    }

    | IMMUTABLE {
        res = new IR(kBareLabelKeyword, OP3("IMMUTABLE", "", ""));
        $$ = res;
    }

    | IMPLICIT_P {
        res = new IR(kBareLabelKeyword, OP3("IMPLICIT", "", ""));
        $$ = res;
    }

    | IMPORT_P {
        res = new IR(kBareLabelKeyword, OP3("IMPORT", "", ""));
        $$ = res;
    }

    | IN_P {
        res = new IR(kBareLabelKeyword, OP3("IN", "", ""));
        $$ = res;
    }

    | INCLUDE {
        res = new IR(kBareLabelKeyword, OP3("INCLUDE", "", ""));
        $$ = res;
    }

    | INCLUDING {
        res = new IR(kBareLabelKeyword, OP3("INCLUDING", "", ""));
        $$ = res;
    }

    | INCREMENT {
        res = new IR(kBareLabelKeyword, OP3("INCREMENT", "", ""));
        $$ = res;
    }

    | INDEX {
        res = new IR(kBareLabelKeyword, OP3("INDEX", "", ""));
        $$ = res;
    }

    | INDEXES {
        res = new IR(kBareLabelKeyword, OP3("INDEXES", "", ""));
        $$ = res;
    }

    | INHERIT {
        res = new IR(kBareLabelKeyword, OP3("INHERIT", "", ""));
        $$ = res;
    }

    | INHERITS {
        res = new IR(kBareLabelKeyword, OP3("INHERITS", "", ""));
        $$ = res;
    }

    | INITIALLY {
        res = new IR(kBareLabelKeyword, OP3("INITIALLY", "", ""));
        $$ = res;
    }

    | INLINE_P {
        res = new IR(kBareLabelKeyword, OP3("INLINE", "", ""));
        $$ = res;
    }

    | INNER_P {
        res = new IR(kBareLabelKeyword, OP3("INNER", "", ""));
        $$ = res;
    }

    | INOUT {
        res = new IR(kBareLabelKeyword, OP3("INOUT", "", ""));
        $$ = res;
    }

    | INPUT_P {
        res = new IR(kBareLabelKeyword, OP3("INPUT", "", ""));
        $$ = res;
    }

    | INSENSITIVE {
        res = new IR(kBareLabelKeyword, OP3("INSENSITIVE", "", ""));
        $$ = res;
    }

    | INSERT {
        res = new IR(kBareLabelKeyword, OP3("INSERT", "", ""));
        $$ = res;
    }

    | INSTEAD {
        res = new IR(kBareLabelKeyword, OP3("INSTEAD", "", ""));
        $$ = res;
    }

    | INT_P {
        res = new IR(kBareLabelKeyword, OP3("INT", "", ""));
        $$ = res;
    }

    | INTEGER {
        res = new IR(kBareLabelKeyword, OP3("INTEGER", "", ""));
        $$ = res;
    }

    | INTERVAL {
        res = new IR(kBareLabelKeyword, OP3("INTERVAL", "", ""));
        $$ = res;
    }

    | INVOKER {
        res = new IR(kBareLabelKeyword, OP3("INVOKER", "", ""));
        $$ = res;
    }

    | IS {
        res = new IR(kBareLabelKeyword, OP3("IS", "", ""));
        $$ = res;
    }

    | ISOLATION {
        res = new IR(kBareLabelKeyword, OP3("ISOLATION", "", ""));
        $$ = res;
    }

    | JOIN {
        res = new IR(kBareLabelKeyword, OP3("JOIN", "", ""));
        $$ = res;
    }

    | KEY {
        res = new IR(kBareLabelKeyword, OP3("KEY", "", ""));
        $$ = res;
    }

    | LABEL {
        res = new IR(kBareLabelKeyword, OP3("LABEL", "", ""));
        $$ = res;
    }

    | LANGUAGE {
        res = new IR(kBareLabelKeyword, OP3("LANGUAGE", "", ""));
        $$ = res;
    }

    | LARGE_P {
        res = new IR(kBareLabelKeyword, OP3("LARGE", "", ""));
        $$ = res;
    }

    | LAST_P {
        res = new IR(kBareLabelKeyword, OP3("LAST", "", ""));
        $$ = res;
    }

    | LATERAL_P {
        res = new IR(kBareLabelKeyword, OP3("LATERAL", "", ""));
        $$ = res;
    }

    | LEADING {
        res = new IR(kBareLabelKeyword, OP3("LEADING", "", ""));
        $$ = res;
    }

    | LEAKPROOF {
        res = new IR(kBareLabelKeyword, OP3("LEAKPROOF", "", ""));
        $$ = res;
    }

    | LEAST {
        res = new IR(kBareLabelKeyword, OP3("LEAST", "", ""));
        $$ = res;
    }

    | LEFT {
        res = new IR(kBareLabelKeyword, OP3("LEFT", "", ""));
        $$ = res;
    }

    | LEVEL {
        res = new IR(kBareLabelKeyword, OP3("LEVEL", "", ""));
        $$ = res;
    }

    | LIKE {
        res = new IR(kBareLabelKeyword, OP3("LIKE", "", ""));
        $$ = res;
    }

    | LISTEN {
        res = new IR(kBareLabelKeyword, OP3("LISTEN", "", ""));
        $$ = res;
    }

    | LOAD {
        res = new IR(kBareLabelKeyword, OP3("LOAD", "", ""));
        $$ = res;
    }

    | LOCAL {
        res = new IR(kBareLabelKeyword, OP3("LOCAL", "", ""));
        $$ = res;
    }

    | LOCALTIME {
        res = new IR(kBareLabelKeyword, OP3("LOCALTIME", "", ""));
        $$ = res;
    }

    | LOCALTIMESTAMP {
        res = new IR(kBareLabelKeyword, OP3("LOCALTIMESTAMP", "", ""));
        $$ = res;
    }

    | LOCATION {
        res = new IR(kBareLabelKeyword, OP3("LOCATION", "", ""));
        $$ = res;
    }

    | LOCK_P {
        res = new IR(kBareLabelKeyword, OP3("LOCK", "", ""));
        $$ = res;
    }

    | LOCKED {
        res = new IR(kBareLabelKeyword, OP3("LOCKED", "", ""));
        $$ = res;
    }

    | LOGGED {
        res = new IR(kBareLabelKeyword, OP3("LOGGED", "", ""));
        $$ = res;
    }

    | MAPPING {
        res = new IR(kBareLabelKeyword, OP3("MAPPING", "", ""));
        $$ = res;
    }

    | MATCH {
        res = new IR(kBareLabelKeyword, OP3("MATCH", "", ""));
        $$ = res;
    }

    | MATERIALIZED {
        res = new IR(kBareLabelKeyword, OP3("MATERIALIZED", "", ""));
        $$ = res;
    }

    | MAXVALUE {
        res = new IR(kBareLabelKeyword, OP3("MAXVALUE", "", ""));
        $$ = res;
    }

    | METHOD {
        res = new IR(kBareLabelKeyword, OP3("METHOD", "", ""));
        $$ = res;
    }

    | MINVALUE {
        res = new IR(kBareLabelKeyword, OP3("MINVALUE", "", ""));
        $$ = res;
    }

    | MODE {
        res = new IR(kBareLabelKeyword, OP3("MODE", "", ""));
        $$ = res;
    }

    | MOVE {
        res = new IR(kBareLabelKeyword, OP3("MOVE", "", ""));
        $$ = res;
    }

    | NAME_P {
        res = new IR(kBareLabelKeyword, OP3("NAME", "", ""));
        $$ = res;
    }

    | NAMES {
        res = new IR(kBareLabelKeyword, OP3("NAMES", "", ""));
        $$ = res;
    }

    | NATIONAL {
        res = new IR(kBareLabelKeyword, OP3("NATIONAL", "", ""));
        $$ = res;
    }

    | NATURAL {
        res = new IR(kBareLabelKeyword, OP3("NATURAL", "", ""));
        $$ = res;
    }

    | NCHAR {
        res = new IR(kBareLabelKeyword, OP3("NCHAR", "", ""));
        $$ = res;
    }

    | NEW {
        res = new IR(kBareLabelKeyword, OP3("NEW", "", ""));
        $$ = res;
    }

    | NEXT {
        res = new IR(kBareLabelKeyword, OP3("NEXT", "", ""));
        $$ = res;
    }

    | NFC {
        res = new IR(kBareLabelKeyword, OP3("NFC", "", ""));
        $$ = res;
    }

    | NFD {
        res = new IR(kBareLabelKeyword, OP3("NFD", "", ""));
        $$ = res;
    }

    | NFKC {
        res = new IR(kBareLabelKeyword, OP3("NFKC", "", ""));
        $$ = res;
    }

    | NFKD {
        res = new IR(kBareLabelKeyword, OP3("NFKD", "", ""));
        $$ = res;
    }

    | NO {
        res = new IR(kBareLabelKeyword, OP3("NO", "", ""));
        $$ = res;
    }

    | NONE {
        res = new IR(kBareLabelKeyword, OP3("NONE", "", ""));
        $$ = res;
    }

    | NORMALIZE {
        res = new IR(kBareLabelKeyword, OP3("NORMALIZE", "", ""));
        $$ = res;
    }

    | NORMALIZED {
        res = new IR(kBareLabelKeyword, OP3("NORMALIZED", "", ""));
        $$ = res;
    }

    | NOT {
        res = new IR(kBareLabelKeyword, OP3("NOT", "", ""));
        $$ = res;
    }

    | NOTHING {
        res = new IR(kBareLabelKeyword, OP3("NOTHING", "", ""));
        $$ = res;
    }

    | NOTIFY {
        res = new IR(kBareLabelKeyword, OP3("NOTIFY", "", ""));
        $$ = res;
    }

    | NOWAIT {
        res = new IR(kBareLabelKeyword, OP3("NOWAIT", "", ""));
        $$ = res;
    }

    | NULL_P {
        res = new IR(kBareLabelKeyword, OP3("NULL", "", ""));
        $$ = res;
    }

    | NULLIF {
        res = new IR(kBareLabelKeyword, OP3("NULLIF", "", ""));
        $$ = res;
    }

    | NULLS_P {
        res = new IR(kBareLabelKeyword, OP3("NULLS", "", ""));
        $$ = res;
    }

    | NUMERIC {
        res = new IR(kBareLabelKeyword, OP3("NUMERIC", "", ""));
        $$ = res;
    }

    | OBJECT_P {
        res = new IR(kBareLabelKeyword, OP3("OBJECT", "", ""));
        $$ = res;
    }

    | OF {
        res = new IR(kBareLabelKeyword, OP3("OF", "", ""));
        $$ = res;
    }

    | OFF {
        res = new IR(kBareLabelKeyword, OP3("OFF", "", ""));
        $$ = res;
    }

    | OIDS {
        res = new IR(kBareLabelKeyword, OP3("OIDS", "", ""));
        $$ = res;
    }

    | OLD {
        res = new IR(kBareLabelKeyword, OP3("OLD", "", ""));
        $$ = res;
    }

    | ONLY {
        res = new IR(kBareLabelKeyword, OP3("ONLY", "", ""));
        $$ = res;
    }

    | OPERATOR {
        res = new IR(kBareLabelKeyword, OP3("OPERATOR", "", ""));
        $$ = res;
    }

    | OPTION {
        res = new IR(kBareLabelKeyword, OP3("OPTION", "", ""));
        $$ = res;
    }

    | OPTIONS {
        res = new IR(kBareLabelKeyword, OP3("OPTIONS", "", ""));
        $$ = res;
    }

    | OR {
        res = new IR(kBareLabelKeyword, OP3("OR", "", ""));
        $$ = res;
    }

    | ORDINALITY {
        res = new IR(kBareLabelKeyword, OP3("ORDINALITY", "", ""));
        $$ = res;
    }

    | OTHERS {
        res = new IR(kBareLabelKeyword, OP3("OTHERS", "", ""));
        $$ = res;
    }

    | OUT_P {
        res = new IR(kBareLabelKeyword, OP3("OUT", "", ""));
        $$ = res;
    }

    | OUTER_P {
        res = new IR(kBareLabelKeyword, OP3("OUTER", "", ""));
        $$ = res;
    }

    | OVERLAY {
        res = new IR(kBareLabelKeyword, OP3("OVERLAY", "", ""));
        $$ = res;
    }

    | OVERRIDING {
        res = new IR(kBareLabelKeyword, OP3("OVERRIDING", "", ""));
        $$ = res;
    }

    | OWNED {
        res = new IR(kBareLabelKeyword, OP3("OWNED", "", ""));
        $$ = res;
    }

    | OWNER {
        res = new IR(kBareLabelKeyword, OP3("OWNER", "", ""));
        $$ = res;
    }

    | PARALLEL {
        res = new IR(kBareLabelKeyword, OP3("PARALLEL", "", ""));
        $$ = res;
    }

    | PARSER {
        res = new IR(kBareLabelKeyword, OP3("PARSER", "", ""));
        $$ = res;
    }

    | PARTIAL {
        res = new IR(kBareLabelKeyword, OP3("PARTIAL", "", ""));
        $$ = res;
    }

    | PARTITION {
        res = new IR(kBareLabelKeyword, OP3("PARTITION", "", ""));
        $$ = res;
    }

    | PASSING {
        res = new IR(kBareLabelKeyword, OP3("PASSING", "", ""));
        $$ = res;
    }

    | PASSWORD {
        res = new IR(kBareLabelKeyword, OP3("PASSWORD", "", ""));
        $$ = res;
    }

    | PLACING {
        res = new IR(kBareLabelKeyword, OP3("PLACING", "", ""));
        $$ = res;
    }

    | PLANS {
        res = new IR(kBareLabelKeyword, OP3("PLANS", "", ""));
        $$ = res;
    }

    | POLICY {
        res = new IR(kBareLabelKeyword, OP3("POLICY", "", ""));
        $$ = res;
    }

    | POSITION {
        res = new IR(kBareLabelKeyword, OP3("POSITION", "", ""));
        $$ = res;
    }

    | PRECEDING {
        res = new IR(kBareLabelKeyword, OP3("PRECEDING", "", ""));
        $$ = res;
    }

    | PREPARE {
        res = new IR(kBareLabelKeyword, OP3("PREPARE", "", ""));
        $$ = res;
    }

    | PREPARED {
        res = new IR(kBareLabelKeyword, OP3("PREPARED", "", ""));
        $$ = res;
    }

    | PRESERVE {
        res = new IR(kBareLabelKeyword, OP3("PRESERVE", "", ""));
        $$ = res;
    }

    | PRIMARY {
        res = new IR(kBareLabelKeyword, OP3("PRIMARY", "", ""));
        $$ = res;
    }

    | PRIOR {
        res = new IR(kBareLabelKeyword, OP3("PRIOR", "", ""));
        $$ = res;
    }

    | PRIVILEGES {
        res = new IR(kBareLabelKeyword, OP3("PRIVILEGES", "", ""));
        $$ = res;
    }

    | PROCEDURAL {
        res = new IR(kBareLabelKeyword, OP3("PROCEDURAL", "", ""));
        $$ = res;
    }

    | PROCEDURE {
        res = new IR(kBareLabelKeyword, OP3("PROCEDURE", "", ""));
        $$ = res;
    }

    | PROCEDURES {
        res = new IR(kBareLabelKeyword, OP3("PROCEDURES", "", ""));
        $$ = res;
    }

    | PROGRAM {
        res = new IR(kBareLabelKeyword, OP3("PROGRAM", "", ""));
        $$ = res;
    }

    | PUBLICATION {
        res = new IR(kBareLabelKeyword, OP3("PUBLICATION", "", ""));
        $$ = res;
    }

    | QUOTE {
        res = new IR(kBareLabelKeyword, OP3("QUOTE", "", ""));
        $$ = res;
    }

    | RANGE {
        res = new IR(kBareLabelKeyword, OP3("RANGE", "", ""));
        $$ = res;
    }

    | READ {
        res = new IR(kBareLabelKeyword, OP3("READ", "", ""));
        $$ = res;
    }

    | REAL {
        res = new IR(kBareLabelKeyword, OP3("REAL", "", ""));
        $$ = res;
    }

    | REASSIGN {
        res = new IR(kBareLabelKeyword, OP3("REASSIGN", "", ""));
        $$ = res;
    }

    | RECHECK {
        res = new IR(kBareLabelKeyword, OP3("RECHECK", "", ""));
        $$ = res;
    }

    | RECURSIVE {
        res = new IR(kBareLabelKeyword, OP3("RECURSIVE", "", ""));
        $$ = res;
    }

    | REF {
        res = new IR(kBareLabelKeyword, OP3("REF", "", ""));
        $$ = res;
    }

    | REFERENCES {
        res = new IR(kBareLabelKeyword, OP3("REFERENCES", "", ""));
        $$ = res;
    }

    | REFERENCING {
        res = new IR(kBareLabelKeyword, OP3("REFERENCING", "", ""));
        $$ = res;
    }

    | REFRESH {
        res = new IR(kBareLabelKeyword, OP3("REFRESH", "", ""));
        $$ = res;
    }

    | REINDEX {
        res = new IR(kBareLabelKeyword, OP3("REINDEX", "", ""));
        $$ = res;
    }

    | RELATIVE_P {
        res = new IR(kBareLabelKeyword, OP3("RELATIVE", "", ""));
        $$ = res;
    }

    | RELEASE {
        res = new IR(kBareLabelKeyword, OP3("RELEASE", "", ""));
        $$ = res;
    }

    | RENAME {
        res = new IR(kBareLabelKeyword, OP3("RENAME", "", ""));
        $$ = res;
    }

    | REPEATABLE {
        res = new IR(kBareLabelKeyword, OP3("REPEATABLE", "", ""));
        $$ = res;
    }

    | REPLACE {
        res = new IR(kBareLabelKeyword, OP3("REPLACE", "", ""));
        $$ = res;
    }

    | REPLICA {
        res = new IR(kBareLabelKeyword, OP3("REPLICA", "", ""));
        $$ = res;
    }

    | RESET {
        res = new IR(kBareLabelKeyword, OP3("RESET", "", ""));
        $$ = res;
    }

    | RESTART {
        res = new IR(kBareLabelKeyword, OP3("RESTART", "", ""));
        $$ = res;
    }

    | RESTRICT {
        res = new IR(kBareLabelKeyword, OP3("RESTRICT", "", ""));
        $$ = res;
    }

    | RETURN {
        res = new IR(kBareLabelKeyword, OP3("RETURN", "", ""));
        $$ = res;
    }

    | RETURNS {
        res = new IR(kBareLabelKeyword, OP3("RETURNS", "", ""));
        $$ = res;
    }

    | REVOKE {
        res = new IR(kBareLabelKeyword, OP3("REVOKE", "", ""));
        $$ = res;
    }

    | RIGHT {
        res = new IR(kBareLabelKeyword, OP3("RIGHT", "", ""));
        $$ = res;
    }

    | ROLE {
        res = new IR(kBareLabelKeyword, OP3("ROLE", "", ""));
        $$ = res;
    }

    | ROLLBACK {
        res = new IR(kBareLabelKeyword, OP3("ROLLBACK", "", ""));
        $$ = res;
    }

    | ROLLUP {
        res = new IR(kBareLabelKeyword, OP3("ROLLUP", "", ""));
        $$ = res;
    }

    | ROUTINE {
        res = new IR(kBareLabelKeyword, OP3("ROUTINE", "", ""));
        $$ = res;
    }

    | ROUTINES {
        res = new IR(kBareLabelKeyword, OP3("ROUTINES", "", ""));
        $$ = res;
    }

    | ROW {
        res = new IR(kBareLabelKeyword, OP3("ROW", "", ""));
        $$ = res;
    }

    | ROWS {
        res = new IR(kBareLabelKeyword, OP3("ROWS", "", ""));
        $$ = res;
    }

    | RULE {
        res = new IR(kBareLabelKeyword, OP3("RULE", "", ""));
        $$ = res;
    }

    | SAVEPOINT {
        res = new IR(kBareLabelKeyword, OP3("SAVEPOINT", "", ""));
        $$ = res;
    }

    | SCHEMA {
        res = new IR(kBareLabelKeyword, OP3("SCHEMA", "", ""));
        $$ = res;
    }

    | SCHEMAS {
        res = new IR(kBareLabelKeyword, OP3("SCHEMAS", "", ""));
        $$ = res;
    }

    | SCROLL {
        res = new IR(kBareLabelKeyword, OP3("SCROLL", "", ""));
        $$ = res;
    }

    | SEARCH {
        res = new IR(kBareLabelKeyword, OP3("SEARCH", "", ""));
        $$ = res;
    }

    | SECURITY {
        res = new IR(kBareLabelKeyword, OP3("SECURITY", "", ""));
        $$ = res;
    }

    | SELECT {
        res = new IR(kBareLabelKeyword, OP3("SELECT", "", ""));
        $$ = res;
    }

    | SEQUENCE {
        res = new IR(kBareLabelKeyword, OP3("SEQUENCE", "", ""));
        $$ = res;
    }

    | SEQUENCES {
        res = new IR(kBareLabelKeyword, OP3("SEQUENCES", "", ""));
        $$ = res;
    }

    | SERIALIZABLE {
        res = new IR(kBareLabelKeyword, OP3("SERIALIZABLE", "", ""));
        $$ = res;
    }

    | SERVER {
        res = new IR(kBareLabelKeyword, OP3("SERVER", "", ""));
        $$ = res;
    }

    | SESSION {
        res = new IR(kBareLabelKeyword, OP3("SESSION", "", ""));
        $$ = res;
    }

    | SESSION_USER {
        res = new IR(kBareLabelKeyword, OP3("SESSION_USER", "", ""));
        $$ = res;
    }

    | SET {
        res = new IR(kBareLabelKeyword, OP3("SET", "", ""));
        $$ = res;
    }

    | SETOF {
        res = new IR(kBareLabelKeyword, OP3("SETOF", "", ""));
        $$ = res;
    }

    | SETS {
        res = new IR(kBareLabelKeyword, OP3("SETS", "", ""));
        $$ = res;
    }

    | SHARE {
        res = new IR(kBareLabelKeyword, OP3("SHARE", "", ""));
        $$ = res;
    }

    | SHOW {
        res = new IR(kBareLabelKeyword, OP3("SHOW", "", ""));
        $$ = res;
    }

    | SIMILAR {
        res = new IR(kBareLabelKeyword, OP3("SIMILAR", "", ""));
        $$ = res;
    }

    | SIMPLE {
        res = new IR(kBareLabelKeyword, OP3("SIMPLE", "", ""));
        $$ = res;
    }

    | SKIP {
        res = new IR(kBareLabelKeyword, OP3("SKIP", "", ""));
        $$ = res;
    }

    | SMALLINT {
        res = new IR(kBareLabelKeyword, OP3("SMALLINT", "", ""));
        $$ = res;
    }

    | SNAPSHOT {
        res = new IR(kBareLabelKeyword, OP3("SNAPSHOT", "", ""));
        $$ = res;
    }

    | SOME {
        res = new IR(kBareLabelKeyword, OP3("SOME", "", ""));
        $$ = res;
    }

    | SQL_P {
        res = new IR(kBareLabelKeyword, OP3("SQL", "", ""));
        $$ = res;
    }

    | STABLE {
        res = new IR(kBareLabelKeyword, OP3("STABLE", "", ""));
        $$ = res;
    }

    | STANDALONE_P {
        res = new IR(kBareLabelKeyword, OP3("STANDALONE", "", ""));
        $$ = res;
    }

    | START {
        res = new IR(kBareLabelKeyword, OP3("START", "", ""));
        $$ = res;
    }

    | STATEMENT {
        res = new IR(kBareLabelKeyword, OP3("STATEMENT", "", ""));
        $$ = res;
    }

    | STATISTICS {
        res = new IR(kBareLabelKeyword, OP3("STATISTICS", "", ""));
        $$ = res;
    }

    | STDIN {
        res = new IR(kBareLabelKeyword, OP3("STDIN", "", ""));
        $$ = res;
    }

    | STDOUT {
        res = new IR(kBareLabelKeyword, OP3("STDOUT", "", ""));
        $$ = res;
    }

    | STORAGE {
        res = new IR(kBareLabelKeyword, OP3("STORAGE", "", ""));
        $$ = res;
    }

    | STORED {
        res = new IR(kBareLabelKeyword, OP3("STORED", "", ""));
        $$ = res;
    }

    | STRICT_P {
        res = new IR(kBareLabelKeyword, OP3("STRICT", "", ""));
        $$ = res;
    }

    | STRIP_P {
        res = new IR(kBareLabelKeyword, OP3("STRIP", "", ""));
        $$ = res;
    }

    | SUBSCRIPTION {
        res = new IR(kBareLabelKeyword, OP3("SUBSCRIPTION", "", ""));
        $$ = res;
    }

    | SUBSTRING {
        res = new IR(kBareLabelKeyword, OP3("SUBSTRING", "", ""));
        $$ = res;
    }

    | SUPPORT {
        res = new IR(kBareLabelKeyword, OP3("SUPPORT", "", ""));
        $$ = res;
    }

    | SYMMETRIC {
        res = new IR(kBareLabelKeyword, OP3("SYMMETRIC", "", ""));
        $$ = res;
    }

    | SYSID {
        res = new IR(kBareLabelKeyword, OP3("SYSID", "", ""));
        $$ = res;
    }

    | SYSTEM_P {
        res = new IR(kBareLabelKeyword, OP3("SYSTEM", "", ""));
        $$ = res;
    }

    | TABLE {
        res = new IR(kBareLabelKeyword, OP3("TABLE", "", ""));
        $$ = res;
    }

    | TABLES {
        res = new IR(kBareLabelKeyword, OP3("TABLES", "", ""));
        $$ = res;
    }

    | TABLESAMPLE {
        res = new IR(kBareLabelKeyword, OP3("TABLESAMPLE", "", ""));
        $$ = res;
    }

    | TABLESPACE {
        res = new IR(kBareLabelKeyword, OP3("TABLESPACE", "", ""));
        $$ = res;
    }

    | TEMP {
        res = new IR(kBareLabelKeyword, OP3("TEMP", "", ""));
        $$ = res;
    }

    | TEMPLATE {
        res = new IR(kBareLabelKeyword, OP3("TEMPLATE", "", ""));
        $$ = res;
    }

    | TEMPORARY {
        res = new IR(kBareLabelKeyword, OP3("TEMPORARY", "", ""));
        $$ = res;
    }

    | TEXT_P {
        res = new IR(kBareLabelKeyword, OP3("TEXT", "", ""));
        $$ = res;
    }

    | THEN {
        res = new IR(kBareLabelKeyword, OP3("THEN", "", ""));
        $$ = res;
    }

    | TIES {
        res = new IR(kBareLabelKeyword, OP3("TIES", "", ""));
        $$ = res;
    }

    | TIME {
        res = new IR(kBareLabelKeyword, OP3("TIME", "", ""));
        $$ = res;
    }

    | TIMESTAMP {
        res = new IR(kBareLabelKeyword, OP3("TIMESTAMP", "", ""));
        $$ = res;
    }

    | TRAILING {
        res = new IR(kBareLabelKeyword, OP3("TRAILING", "", ""));
        $$ = res;
    }

    | TRANSACTION {
        res = new IR(kBareLabelKeyword, OP3("TRANSACTION", "", ""));
        $$ = res;
    }

    | TRANSFORM {
        res = new IR(kBareLabelKeyword, OP3("TRANSFORM", "", ""));
        $$ = res;
    }

    | TREAT {
        res = new IR(kBareLabelKeyword, OP3("TREAT", "", ""));
        $$ = res;
    }

    | TRIGGER {
        res = new IR(kBareLabelKeyword, OP3("TRIGGER", "", ""));
        $$ = res;
    }

    | TRIM {
        res = new IR(kBareLabelKeyword, OP3("TRIM", "", ""));
        $$ = res;
    }

    | TRUE_P {
        res = new IR(kBareLabelKeyword, OP3("TRUE", "", ""));
        $$ = res;
    }

    | TRUNCATE {
        res = new IR(kBareLabelKeyword, OP3("TRUNCATE", "", ""));
        $$ = res;
    }

    | TRUSTED {
        res = new IR(kBareLabelKeyword, OP3("TRUSTED", "", ""));
        $$ = res;
    }

    | TYPE_P {
        res = new IR(kBareLabelKeyword, OP3("TYPE", "", ""));
        $$ = res;
    }

    | TYPES_P {
        res = new IR(kBareLabelKeyword, OP3("TYPES", "", ""));
        $$ = res;
    }

    | UESCAPE {
        res = new IR(kBareLabelKeyword, OP3("UESCAPE", "", ""));
        $$ = res;
    }

    | UNBOUNDED {
        res = new IR(kBareLabelKeyword, OP3("UNBOUNDED", "", ""));
        $$ = res;
    }

    | UNCOMMITTED {
        res = new IR(kBareLabelKeyword, OP3("UNCOMMITTED", "", ""));
        $$ = res;
    }

    | UNENCRYPTED {
        res = new IR(kBareLabelKeyword, OP3("UNENCRYPTED", "", ""));
        $$ = res;
    }

    | UNIQUE {
        res = new IR(kBareLabelKeyword, OP3("UNIQUE", "", ""));
        $$ = res;
    }

    | UNKNOWN {
        res = new IR(kBareLabelKeyword, OP3("UNKNOWN", "", ""));
        $$ = res;
    }

    | UNLISTEN {
        res = new IR(kBareLabelKeyword, OP3("UNLISTEN", "", ""));
        $$ = res;
    }

    | UNLOGGED {
        res = new IR(kBareLabelKeyword, OP3("UNLOGGED", "", ""));
        $$ = res;
    }

    | UNTIL {
        res = new IR(kBareLabelKeyword, OP3("UNTIL", "", ""));
        $$ = res;
    }

    | UPDATE {
        res = new IR(kBareLabelKeyword, OP3("UPDATE", "", ""));
        $$ = res;
    }

    | USER {
        res = new IR(kBareLabelKeyword, OP3("USER", "", ""));
        $$ = res;
    }

    | USING {
        res = new IR(kBareLabelKeyword, OP3("USING", "", ""));
        $$ = res;
    }

    | VACUUM {
        res = new IR(kBareLabelKeyword, OP3("VACUUM", "", ""));
        $$ = res;
    }

    | VALID {
        res = new IR(kBareLabelKeyword, OP3("VALID", "", ""));
        $$ = res;
    }

    | VALIDATE {
        res = new IR(kBareLabelKeyword, OP3("VALIDATE", "", ""));
        $$ = res;
    }

    | VALIDATOR {
        res = new IR(kBareLabelKeyword, OP3("VALIDATOR", "", ""));
        $$ = res;
    }

    | VALUE_P {
        res = new IR(kBareLabelKeyword, OP3("VALUE", "", ""));
        $$ = res;
    }

    | VALUES {
        res = new IR(kBareLabelKeyword, OP3("VALUES", "", ""));
        $$ = res;
    }

    | VARCHAR {
        res = new IR(kBareLabelKeyword, OP3("VARCHAR", "", ""));
        $$ = res;
    }

    | VARIADIC {
        res = new IR(kBareLabelKeyword, OP3("VARIADIC", "", ""));
        $$ = res;
    }

    | VERBOSE {
        res = new IR(kBareLabelKeyword, OP3("VERBOSE", "", ""));
        $$ = res;
    }

    | VERSION_P {
        res = new IR(kBareLabelKeyword, OP3("VERSION", "", ""));
        $$ = res;
    }

    | VIEW {
        res = new IR(kBareLabelKeyword, OP3("VIEW", "", ""));
        $$ = res;
    }

    | VIEWS {
        res = new IR(kBareLabelKeyword, OP3("VIEWS", "", ""));
        $$ = res;
    }

    | VOLATILE {
        res = new IR(kBareLabelKeyword, OP3("VOLATILE", "", ""));
        $$ = res;
    }

    | WHEN {
        res = new IR(kBareLabelKeyword, OP3("WHEN", "", ""));
        $$ = res;
    }

    | WHITESPACE_P {
        res = new IR(kBareLabelKeyword, OP3("WHITESPACE", "", ""));
        $$ = res;
    }

    | WORK {
        res = new IR(kBareLabelKeyword, OP3("WORK", "", ""));
        $$ = res;
    }

    | WRAPPER {
        res = new IR(kBareLabelKeyword, OP3("WRAPPER", "", ""));
        $$ = res;
    }

    | WRITE {
        res = new IR(kBareLabelKeyword, OP3("WRITE", "", ""));
        $$ = res;
    }

    | XML_P {
        res = new IR(kBareLabelKeyword, OP3("XML", "", ""));
        $$ = res;
    }

    | XMLATTRIBUTES {
        res = new IR(kBareLabelKeyword, OP3("XMLATTRIBUTES", "", ""));
        $$ = res;
    }

    | XMLCONCAT {
        res = new IR(kBareLabelKeyword, OP3("XMLCONCAT", "", ""));
        $$ = res;
    }

    | XMLELEMENT {
        res = new IR(kBareLabelKeyword, OP3("XMLELEMENT", "", ""));
        $$ = res;
    }

    | XMLEXISTS {
        res = new IR(kBareLabelKeyword, OP3("XMLEXISTS", "", ""));
        $$ = res;
    }

    | XMLFOREST {
        res = new IR(kBareLabelKeyword, OP3("XMLFOREST", "", ""));
        $$ = res;
    }

    | XMLNAMESPACES {
        res = new IR(kBareLabelKeyword, OP3("XMLNAMESPACES", "", ""));
        $$ = res;
    }

    | XMLPARSE {
        res = new IR(kBareLabelKeyword, OP3("XMLPARSE", "", ""));
        $$ = res;
    }

    | XMLPI {
        res = new IR(kBareLabelKeyword, OP3("XMLPI", "", ""));
        $$ = res;
    }

    | XMLROOT {
        res = new IR(kBareLabelKeyword, OP3("XMLROOT", "", ""));
        $$ = res;
    }

    | XMLSERIALIZE {
        res = new IR(kBareLabelKeyword, OP3("XMLSERIALIZE", "", ""));
        $$ = res;
    }

    | XMLTABLE {
        res = new IR(kBareLabelKeyword, OP3("XMLTABLE", "", ""));
        $$ = res;
    }

    | YES_P {
        res = new IR(kBareLabelKeyword, OP3("YES", "", ""));
        $$ = res;
    }

    | ZONE {
        res = new IR(kBareLabelKeyword, OP3("ZONE", "", ""));
        $$ = res;
    }

;
"""
    _test(data, expect)


def TestOnlyMultipleKeywords():
    data = """
document_or_content: DOCUMENT_P						{ $$ = XMLOPTION_DOCUMENT; }
			| CONTENT_P	DOCUMENT_P					{ $$ = XMLOPTION_CONTENT; }
			| CONTENT_P	DOCUMENT_P	CONTENT_P		{ $$ = XMLOPTION_CONTENT; }
		; 
"""
    expect = """
document_or_content:

    DOCUMENT_P {
        res = new IR(kDocumentOrContent, OP3("DOCUMENT", "", ""));
        $$ = res;
    }

    | CONTENT_P DOCUMENT_P {
        res = new IR(kDocumentOrContent, OP3("CONTENT DOCUMENT", "", ""));
        $$ = res;
    }

    | CONTENT_P DOCUMENT_P CONTENT_P {
        res = new IR(kDocumentOrContent, OP3("CONTENT DOCUMENT CONTENT", "", ""));
        $$ = res;
    }

;
"""
    _test(data, expect)


def TestQualifiedNameList():
    data = """
qualified_name_list:
			qualified_name							{ $$ = list_make1($1); }
			| qualified_name_list ',' qualified_name { $$ = lappend($1, $3); }
		;    
"""
    expect = """
qualified_name_list:

    qualified_name {
        auto tmp1 = $1;
        res = new IR(kQualifiedNameList, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | qualified_name_list ',' qualified_name {
        auto tmp1 = $1;
        auto tmp2 = $3;
        res = new IR(kQualifiedNameList, OP3("", ",", ""), tmp1, tmp2);
        $$ = res;
    }

;
"""
    _test(data, expect)


def TestMappingKeywords():
    data = """
Numeric:	INT_P
				{
					$$ = SystemTypeName("int4");
					$$->location = @1;
				}
			| INTEGER
				{
					$$ = SystemTypeName("int4");
					$$->location = @1;
				}
			| SMALLINT
				{
					$$ = SystemTypeName("int2");
					$$->location = @1;
				}
			| BIGINT
				{
					$$ = SystemTypeName("int8");
					$$->location = @1;
				}
			| REAL
				{
					$$ = SystemTypeName("float4");
					$$->location = @1;
				}
			| FLOAT_P opt_float
				{
					$$ = $2;
					$$->location = @1;
				}
			| DOUBLE_P PRECISION
				{
					$$ = SystemTypeName("float8");
					$$->location = @1;
				}
			| DECIMAL_P opt_type_modifiers
				{
					$$ = SystemTypeName("numeric");
					$$->typmods = $2;
					$$->location = @1;
				}
			| DEC opt_type_modifiers
				{
					$$ = SystemTypeName("numeric");
					$$->typmods = $2;
					$$->location = @1;
				}
			| NUMERIC opt_type_modifiers
				{
					$$ = SystemTypeName("numeric");
					$$->typmods = $2;
					$$->location = @1;
				}
			| BOOLEAN_P
				{
					$$ = SystemTypeName("bool");
					$$->location = @1;
				}
		;
"""
    expect = """
Numeric:

    INT_P {
        res = new IR(kNumeric, OP3("INT", "", ""));
        $$ = res;
    }

    | INTEGER {
        res = new IR(kNumeric, OP3("INTEGER", "", ""));
        $$ = res;
    }

    | SMALLINT {
        res = new IR(kNumeric, OP3("SMALLINT", "", ""));
        $$ = res;
    }

    | BIGINT {
        res = new IR(kNumeric, OP3("BIGINT", "", ""));
        $$ = res;
    }

    | REAL {
        res = new IR(kNumeric, OP3("REAL", "", ""));
        $$ = res;
    }

    | FLOAT_P opt_float {
        auto tmp1 = $2;
        res = new IR(kNumeric, OP3("FLOAT", "", ""), tmp1);
        $$ = res;
    }

    | DOUBLE_P PRECISION {
        res = new IR(kNumeric, OP3("DOUBLE PRECISION", "", ""));
        $$ = res;
    }

    | DECIMAL_P opt_type_modifiers {
        auto tmp1 = $2;
        res = new IR(kNumeric, OP3("DECIMAL", "", ""), tmp1);
        $$ = res;
    }

    | DEC opt_type_modifiers {
        auto tmp1 = $2;
        res = new IR(kNumeric, OP3("DEC", "", ""), tmp1);
        $$ = res;
    }

    | NUMERIC opt_type_modifiers {
        auto tmp1 = $2;
        res = new IR(kNumeric, OP3("NUMERIC", "", ""), tmp1);
        $$ = res;
    }

    | BOOLEAN_P {
        res = new IR(kNumeric, OP3("BOOLEAN", "", ""));
        $$ = res;
    }

;
"""
    _test(data, expect)


def TestCExpr():
    data = """
c_expr:		columnref								{ $$ = $1; }
			| AexprConst							{ $$ = $1; }
			| PARAM opt_indirection
			| '(' a_expr ')' opt_indirection
			| case_expr
				{ $$ = $1; }
			| func_expr
				{ $$ = $1; }
			| select_with_parens			%prec UMINUS
				{
					SubLink *n = makeNode(SubLink);
					n->subLinkType = EXPR_SUBLINK;
					n->subLinkId = 0;
					n->testexpr = NULL;
					n->operName = NIL;
					n->subselect = $1;
					n->location = @1;
					$$ = (Node *)n;
				}
			| select_with_parens indirection
				{
					/*
					 * Because the select_with_parens nonterminal is designed
					 * to "eat" as many levels of parens as possible, the
					 * '(' a_expr ')' opt_indirection production above will
					 * fail to match a sub-SELECT with indirection decoration;
					 * the sub-SELECT won't be regarded as an a_expr as long
					 * as there are parens around it.  To support applying
					 * subscripting or field selection to a sub-SELECT result,
					 * we need this redundant-looking production.
					 */
					SubLink *n = makeNode(SubLink);
					A_Indirection *a = makeNode(A_Indirection);
					n->subLinkType = EXPR_SUBLINK;
					n->subLinkId = 0;
					n->testexpr = NULL;
					n->operName = NIL;
					n->subselect = $1;
					n->location = @1;
					a->arg = (Node *)n;
					a->indirection = check_indirection($2, yyscanner);
					$$ = (Node *)a;
				}
			| EXISTS select_with_parens
				{
					SubLink *n = makeNode(SubLink);
					n->subLinkType = EXISTS_SUBLINK;
					n->subLinkId = 0;
					n->testexpr = NULL;
					n->operName = NIL;
					n->subselect = $2;
					n->location = @1;
					$$ = (Node *)n;
				}
			| ARRAY select_with_parens
				{
					SubLink *n = makeNode(SubLink);
					n->subLinkType = ARRAY_SUBLINK;
					n->subLinkId = 0;
					n->testexpr = NULL;
					n->operName = NIL;
					n->subselect = $2;
					n->location = @1;
					$$ = (Node *)n;
				}
			| ARRAY array_expr
				{
					A_ArrayExpr *n = castNode(A_ArrayExpr, $2);
					/* point outermost A_ArrayExpr to the ARRAY keyword */
					n->location = @1;
					$$ = (Node *)n;
				}
			| explicit_row
				{
					RowExpr *r = makeNode(RowExpr);
					r->args = $1;
					r->row_typeid = InvalidOid;	/* not analyzed yet */
					r->colnames = NIL;	/* to be filled in during analysis */
					r->row_format = COERCE_EXPLICIT_CALL; /* abuse */
					r->location = @1;
					$$ = (Node *)r;
				}
			| implicit_row
				{
					RowExpr *r = makeNode(RowExpr);
					r->args = $1;
					r->row_typeid = InvalidOid;	/* not analyzed yet */
					r->colnames = NIL;	/* to be filled in during analysis */
					r->row_format = COERCE_IMPLICIT_CAST; /* abuse */
					r->location = @1;
					$$ = (Node *)r;
				}
			| GROUPING '(' expr_list ')'
			  {
				  GroupingFunc *g = makeNode(GroupingFunc);
				  g->args = $3;
				  g->location = @1;
				  $$ = (Node *)g;
			  }
		;
"""
    expect = """
c_expr:

    columnref {
        auto tmp1 = $1;
        res = new IR(kCExpr, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | AexprConst {
        auto tmp1 = $1;
        res = new IR(kCExpr, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | PARAM opt_indirection {
        auto tmp1 = $2;
        res = new IR(kCExpr, OP3("PARAM", "", ""), tmp1);
        $$ = res;
    }

    | '(' a_expr ')' opt_indirection {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kCExpr, OP3("(", ")", ""), tmp1, tmp2);
        $$ = res;
    }

    | case_expr {
        auto tmp1 = $1;
        res = new IR(kCExpr, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | func_expr {
        auto tmp1 = $1;
        res = new IR(kCExpr, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | select_with_parens %prec UMINUS {
        auto tmp1 = $1;
        res = new IR(kCExpr, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | select_with_parens indirection {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kCExpr, OP3("", "", ""), tmp1, tmp2);
        $$ = res;
    }

    | EXISTS select_with_parens {
        auto tmp1 = $2;
        res = new IR(kCExpr, OP3("EXISTS", "", ""), tmp1);
        $$ = res;
    }

    | ARRAY select_with_parens {
        auto tmp1 = $2;
        res = new IR(kCExpr, OP3("ARRAY", "", ""), tmp1);
        $$ = res;
    }

    | ARRAY array_expr {
        auto tmp1 = $2;
        res = new IR(kCExpr, OP3("ARRAY", "", ""), tmp1);
        $$ = res;
    }

    | explicit_row {
        auto tmp1 = $1;
        res = new IR(kCExpr, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | implicit_row {
        auto tmp1 = $1;
        res = new IR(kCExpr, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | GROUPING '(' expr_list ')' {
        auto tmp1 = $3;
        res = new IR(kCExpr, OP3("GROUPING (", ")", ""), tmp1);
        $$ = res;
    }

;
"""
    _test(data, expect)


def TestMultipleComments():
    data = """
bare_label_keyword: /* EMPTY */
			  ABORT_P
			  /* EMPTY */
			| /* EMPTY */
			  ABSOLUTE_P /* EMPTY */
			| /* EMPTY */ ACCESS
			| ACTION /* EMPTY */
			| /* EMPTY */ XMLTABLE /* EMPTY */
			/* EMPTY */
			| /* EMPTY */
			  YES_P
			| ZONE
			  /* EMPTY */
	    ;
"""
    expect = """
bare_label_keyword:

    ABORT_P {
        res = new IR(kBareLabelKeyword, OP3("ABORT", "", ""));
        $$ = res;
    }

    | ABSOLUTE_P {
        res = new IR(kBareLabelKeyword, OP3("ABSOLUTE", "", ""));
        $$ = res;
    }

    | ACCESS {
        res = new IR(kBareLabelKeyword, OP3("ACCESS", "", ""));
        $$ = res;
    }

    | ACTION {
        res = new IR(kBareLabelKeyword, OP3("ACTION", "", ""));
        $$ = res;
    }

    | XMLTABLE {
        res = new IR(kBareLabelKeyword, OP3("XMLTABLE", "", ""));
        $$ = res;
    }

    | YES_P {
        res = new IR(kBareLabelKeyword, OP3("YES", "", ""));
        $$ = res;
    }

    | ZONE {
        res = new IR(kBareLabelKeyword, OP3("ZONE", "", ""));
        $$ = res;
    }

;
"""
    _test(data, expect)


def TestOptEqual():
    data = """
opt_equal:	'='
			| /*EMPTY*/
		;
"""
    expect = """
opt_equal:

    '=' {
        res = new IR(kOptEqual, OP3("=", "", ""));
        $$ = res;
    }

    | /*EMPTY*/ {
        res = new IR(kOptEqual, OP3("", "", ""));
        $$ = res;
    }

;
"""
    _test(data, expect)


def TestCopyStmt():
    data = """
CopyStmt:	COPY opt_binary qualified_name opt_column_list
			copy_from opt_program copy_file_name copy_delimiter opt_with
			copy_options where_clause
				{
					CopyStmt *n = makeNode(CopyStmt);
					n->relation = $3;
					n->query = NULL;
					n->attlist = $4;
					n->is_from = $5;
					n->is_program = $6;
					n->filename = $7;
					n->whereClause = $11;

					if (n->is_program && n->filename == NULL)
						ereport(ERROR,
								(errcode(ERRCODE_SYNTAX_ERROR),
								 errmsg("STDIN/STDOUT not allowed with PROGRAM"),
								 parser_errposition(@8)));

					if (!n->is_from && n->whereClause != NULL)
						ereport(ERROR,
								(errcode(ERRCODE_SYNTAX_ERROR),
								 errmsg("WHERE clause not allowed with COPY TO"),
								 parser_errposition(@11)));

					n->options = NIL;
					/* Concatenate user-supplied flags */
					if ($2)
						n->options = lappend(n->options, $2);
					if ($8)
						n->options = lappend(n->options, $8);
					if ($10)
						n->options = list_concat(n->options, $10);
					$$ = (Node *)n;
				}
			| COPY opt_binary CREATE qualified_name USER opt_column_list
			CHECK copy_from PASSWORD opt_program POLICY copy_file_name STORAGE copy_delimiter ROLLBACK opt_with
			DESC copy_options ACTION where_clause SEARCH 
			    {
			        CopyStmt *n = makeNode(CopyStmt);
			    }
			| COPY '(' PreparableStmt ')' TO opt_program copy_file_name opt_with copy_options
				{
					CopyStmt *n = makeNode(CopyStmt);
					n->relation = NULL;
					n->query = $3;
					n->attlist = NIL;
					n->is_from = false;
					n->is_program = $6;
					n->filename = $7;
					n->options = $9;

					if (n->is_program && n->filename == NULL)
						ereport(ERROR,
								(errcode(ERRCODE_SYNTAX_ERROR),
								 errmsg("STDIN/STDOUT not allowed with PROGRAM"),
								 parser_errposition(@5)));

					$$ = (Node *)n;
				}
		;
"""
    expect = """
CopyStmt:

    COPY opt_binary qualified_name opt_column_list copy_from opt_program copy_file_name copy_delimiter opt_with copy_options where_clause {
        auto tmp1 = $2;
        auto tmp2 = $3;
        res = new IR(kCopyStmt_1, OP3("COPY", "", ""), tmp1, tmp2);
        auto tmp3 = $4;
        res = new IR(kCopyStmt_2, OP3("", "", ""), res, tmp3);
        auto tmp4 = $5;
        res = new IR(kCopyStmt_3, OP3("", "", ""), res, tmp4);
        auto tmp5 = $6;
        res = new IR(kCopyStmt_4, OP3("", "", ""), res, tmp5);
        auto tmp6 = $7;
        res = new IR(kCopyStmt_5, OP3("", "", ""), res, tmp6);
        auto tmp7 = $8;
        res = new IR(kCopyStmt_6, OP3("", "", ""), res, tmp7);
        auto tmp8 = $9;
        res = new IR(kCopyStmt_7, OP3("", "", ""), res, tmp8);
        auto tmp9 = $10;
        res = new IR(kCopyStmt_8, OP3("", "", ""), res, tmp9);
        auto tmp10 = $11;
        res = new IR(kCopyStmt, OP3("", "", ""), res, tmp10);
        $$ = res;
    }

    | COPY opt_binary CREATE qualified_name USER opt_column_list CHECK copy_from PASSWORD opt_program POLICY copy_file_name STORAGE copy_delimiter ROLLBACK opt_with DESC copy_options ACTION where_clause SEARCH {
        auto tmp1 = $2;
        auto tmp2 = $4;
        res = new IR(kCopyStmt_9, OP3("COPY", "CREATE", "USER"), tmp1, tmp2);
        auto tmp3 = $6;
        res = new IR(kCopyStmt_10, OP3("", "", "CHECK"), res, tmp3);
        auto tmp4 = $8;
        res = new IR(kCopyStmt_11, OP3("", "", "PASSWORD"), res, tmp4);
        auto tmp5 = $10;
        res = new IR(kCopyStmt_12, OP3("", "", "POLICY"), res, tmp5);
        auto tmp6 = $12;
        res = new IR(kCopyStmt_13, OP3("", "", "STORAGE"), res, tmp6);
        auto tmp7 = $14;
        res = new IR(kCopyStmt_14, OP3("", "", "ROLLBACK"), res, tmp7);
        auto tmp8 = $16;
        res = new IR(kCopyStmt_15, OP3("", "", "DESC"), res, tmp8);
        auto tmp9 = $18;
        res = new IR(kCopyStmt_16, OP3("", "", "ACTION"), res, tmp9);
        auto tmp10 = $20;
        res = new IR(kCopyStmt, OP3("", "", "SEARCH"), res, tmp10);
        $$ = res;
    }

    | COPY '(' PreparableStmt ')' TO opt_program copy_file_name opt_with copy_options {
        auto tmp1 = $3;
        auto tmp2 = $6;
        res = new IR(kCopyStmt_17, OP3("COPY (", ") TO", ""), tmp1, tmp2);
        auto tmp3 = $7;
        res = new IR(kCopyStmt_18, OP3("", "", ""), res, tmp3);
        auto tmp4 = $8;
        res = new IR(kCopyStmt_19, OP3("", "", ""), res, tmp4);
        auto tmp5 = $9;
        res = new IR(kCopyStmt, OP3("", "", ""), res, tmp5);
        $$ = res;
    }

;
"""

    _test(data, expect)


@click.command()
@click.option("-p", "--print-output", is_flag=True, default=False)
def test(print_output):
    if not print_output:
        logger.remove()
        logger.add(sys.stderr, level="ERROR")

    try:
        TestDropSubscriptionStmt()
        TestStmtBlock()
        TestCreateUserStmt()
        TestStmtMulti()
        TestOnlyKeywords()
        TestStmt()
        TestSingleLine()
        TestConstraintAttributeSpec()
        TestEventTriggerWhenItem()
        TestWhenClauseList()
        TestOptCreatefuncOptList()
        TestEvent()
        TestFuncApplication()
        TestBareLabelKeyword()
        TestOnlyMultipleKeywords()
        TestQualifiedNameList()
        TestMappingKeywords()
        TestCExpr()
        TestMultipleComments()
        TestOptEqual()
        TestCopyStmt()
        logger.info("All tests passed!")
    except Exception as e:
        logger.exception(e)


if __name__ == "__main__":
    test()
