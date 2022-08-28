#pragma once
#ifndef __DEFINE_H__
#define __DEFINE_H__

#define ALLTYPE(V)                                                             \
  V(kIR)                                                                       \
  V(kIROperator)                                                               \
  V(kNode)                                                                     \
  V(kOpt)                                                                      \
  V(kOptString)                                                                \
  V(kProgram)                                                                  \
  V(kStatement)                                                                \
  V(kPreparableStatement)                                                      \
  V(kSelectStatement)                                                          \
  V(kCreateStatement)                                                          \
  V(kCreateTableStatement)                                                     \
  V(kCreateViewStatement)                                                      \
  V(kCreateIndexStatement)                                                     \
  V(kCreateVirtualTableStatement)                                              \
  V(kCreateTriggerStatement)                                                   \
  V(kInsertStatement)                                                          \
  V(kDeleteStatement)                                                          \
  V(kUpdateStatement)                                                          \
  V(kDropStatement)                                                            \
  V(kDropIndexStatement)                                                       \
  V(kDropTableStatement)                                                       \
  V(kDropViewStatement)                                                        \
  V(kDropTriggerStatement)                                                     \
  V(kAttachStatement)                                                          \
  V(kDetachStatement)                                                          \
  V(kPragmaStatement)                                                          \
  V(kFilePath)                                                                 \
  V(kOptIfNotExists)                                                           \
  V(kOptRecursive)                                                             \
  V(kColumnDefList)                                                            \
  V(kColumnDef)                                                                \
  V(kColumnType)                                                               \
  V(kOptColumnNullable)                                                        \
  V(kOptIfExists)                                                              \
  V(kExistsOrNot)                                                              \
  V(kOptColumnListParen)                                                       \
  V(kUpdateClauseList)                                                         \
  V(kUpdateClause)                                                             \
  V(kSetOperator)                                                              \
  V(kSelectCore)                                                               \
  V(kSelectCoreList)                                                           \
  V(kOptDistinct)                                                              \
  V(kOptStoredVirtual)                                                         \
  V(kSelectList)                                                               \
  V(kFromClause)                                                               \
  V(kOptFromClause)                                                            \
  V(kOptWhere)                                                                 \
  V(kOptGroup)                                                                 \
  V(kOptHaving)                                                                \
  V(kOptOrder)                                                                 \
  V(kOrderList)                                                                \
  V(kOrderTerm)                                                                \
  V(kOptOrderType)                                                             \
  V(kOptLimit)                                                                 \
  V(kExprList)                                                                 \
  V(kExprListParen)                                                            \
  V(kExprListParenList)                                                        \
  V(kNewExpr)                                                                  \
  V(kExistsExpr)                                                               \
  V(kElseExpr)                                                                 \
  V(kOptElseExpr)                                                              \
  V(kOptExpr)                                                                  \
  V(kScalarExpr)                                                               \
  V(kUnaryOp)                                                                  \
  V(kBinaryOp)                                                                 \
  V(kInTarget)                                                                 \
  V(kFunctionExpr)                                                             \
  V(kExtractExpr)                                                              \
  V(kArrayExpr)                                                                \
  V(kCaseCondition)                                                            \
  V(kCaseConditionList)                                                        \
  V(kColumnName)                                                               \
  V(kLiteral)                                                                  \
  V(kStringLiteral)                                                            \
  V(kBlobLiteral)                                                              \
  V(kIntLiteral)                                                               \
  V(kNumericLiteral)                                                           \
  V(kSignedNumber)                                                             \
  V(kForeignKeyClause)                                                         \
  V(kForeignKeyOn)                                                             \
  V(kForeignKeyOnList)                                                         \
  V(kOptForeignKeyOnList)                                                      \
  V(kDeferrableClause)                                                         \
  V(kOptDeferrableClause)                                                      \
  V(kNullLiteral)                                                              \
  V(kParamExpr)                                                                \
  V(kIdentifier)                                                               \
  V(kTableOrSubquery)                                                          \
  V(kTableOrSubqueryList)                                                      \
  V(kTableRefCommaList)                                                        \
  V(kTableRefAtomic)                                                           \
  V(kNonjoinTableRefAtomic)                                                    \
  V(kTableRefName)                                                             \
  V(kTableName)                                                                \
  V(kQualifiedTableName)                                                       \
  V(kTableAlias)                                                               \
  V(kOptTableAlias)                                                            \
  V(kOptTableAliasAs)                                                          \
  V(kColumnAlias)                                                              \
  V(kOptColumnAlias)                                                           \
  V(kResultColumn)                                                             \
  V(kResultColumnList)                                                         \
  V(kOptReturningClause)                                                       \
  V(kAlias)                                                                    \
  V(kOptAlias)                                                                 \
  V(kWithClause)                                                               \
  V(kOptWithClause)                                                            \
  V(kCommonTableExpr)                                                          \
  V(kCommonTableExprList)                                                      \
  V(kJoinClause)                                                               \
  V(kOptJoinType)                                                              \
  V(kJoinConstraint)                                                           \
  V(kOptSemicolon)                                                             \
  V(kInit)                                                                     \
  V(kStatementList)                                                            \
  V(kUnknown)                                                                  \
  V(kEmpty)                                                                    \
  V(kPragmaKey)                                                                \
  V(kPragmaName)                                                               \
  V(kPragmaValue)                                                              \
  V(kSchemaName)                                                               \
  V(kOptColumnConstraintlist)                                                  \
  V(kColumnConstraintlist)                                                     \
  V(kColumnConstraint)                                                         \
  V(kOptConflictClause)                                                        \
  V(kResolveType)                                                              \
  V(kOptAutoinc)                                                               \
  V(kOptUnique)                                                                \
  V(kIndexName)                                                                \
  V(kOptTmp)                                                                   \
  V(kTriggerName)                                                              \
  V(kOptTriggerTime)                                                           \
  V(kTriggerEvent)                                                             \
  V(kOptOfColumnList)                                                          \
  V(kOptForEach)                                                               \
  V(kOptWhen)                                                                  \
  V(kTriggerCmdList)                                                           \
  V(kTriggerCmd)                                                               \
  V(kModuleName)                                                               \
  V(kOptOverClause)                                                            \
  V(kOptFilterClause)                                                          \
  V(kFilterClause)                                                             \
  V(kWindowClause)                                                             \
  V(kOptWindowClause)                                                          \
  V(kWindowDefnList)                                                           \
  V(kWindowDefn)                                                               \
  V(kWindowBody)                                                               \
  V(kWindowName)                                                               \
  V(kOptBaseWindowName)                                                        \
  V(kOptFrame)                                                                 \
  V(kRangeOrRows)                                                              \
  V(kFrameBoundS)                                                              \
  V(kFrameBoundE)                                                              \
  V(kFrameBound)                                                               \
  V(kFrameExclude)                                                             \
  V(kOptFrameExclude)                                                          \
  V(kInsertType)                                                               \
  V(kUpdateType)                                                               \
  V(kInsertValue)                                                              \
  V(kReindexStatement)                                                         \
  V(kAnalyzeStatement)                                                         \
  V(kOnExpr)                                                                   \
  V(kEscapeExpr)                                                               \
  V(kOptEscapeExpr)                                                            \
  V(kWhereExpr)                                                                \
  V(kOptIndex)                                                                 \
  V(kJoinOp)                                                                   \
  V(kAlterStatement)                                                           \
  V(kSavepointStatement)                                                       \
  V(kReleaseStatement)                                                         \
  V(kOptColumn)                                                                \
  V(kVacuumStatement)                                                          \
  V(kOptSchemaName)                                                            \
  V(kRollbackStatement)                                                        \
  V(kOptTransaction)                                                           \
  V(kOptToSavepoint)                                                           \
  V(kBeginStatement)                                                           \
  V(kCommitStatement)                                                          \
  V(kUpsertClause)                                                             \
  V(kUpsertItem)                                                               \
  V(kIndexedColumnList)                                                        \
  V(kIndexedColumn)                                                            \
  V(kOptCollate)                                                               \
  V(kCollate)                                                                  \
  V(kAssignList)                                                               \
  V(kOptOrderOfNull)                                                           \
  V(kNullOfExpr)                                                               \
  V(kAssignClause)                                                             \
  V(kColumnNameList)                                                           \
  V(kFunctionName)                                                             \
  V(kFunctionArgs)                                                             \
  V(kOptWithoutRowID)                                                          \
  V(kOptStrict)                                                                \
  V(kOptUpsertClause)                                                          \
  V(kOptConstraintName)                                                        \
  V(kTableConstraint)                                                          \
  V(kTableConstraintList)                                                      \
  V(kJoinSuffix)                                                               \
  V(kJoinSuffixList)                                                           \
  V(kPartitionBy)                                                              \
  V(kOptPartitionBy)                                                           \
  V(kOptNot)                                                                   \
  V(kRaiseFunction)                                                            \
  V(kConflictTarget)                                                           \
  V(kOptConflictTarget)

#define ALLCLASS(V)                                                            \
  V(IR)                                                                        \
  V(IROperator)                                                                \
  V(Node)                                                                      \
  V(Opt)                                                                       \
  V(OptString)                                                                 \
  V(Program)                                                                   \
  V(Statement)                                                                 \
  V(PreparableStatement)                                                       \
  V(SelectStatement)                                                           \
  V(CreateStatement)                                                           \
  V(CreateTableStatement)                                                      \
  V(CreateViewStatement)                                                       \
  V(CreateIndexStatement)                                                      \
  V(CreateVirtualTableStatement)                                               \
  V(CreateTriggerStatement)                                                    \
  V(InsertStatement)                                                           \
  V(DeleteStatement)                                                           \
  V(UpdateStatement)                                                           \
  V(DropStatement)                                                             \
  V(DropIndexStatement)                                                        \
  V(DropTableStatement)                                                        \
  V(DropViewStatement)                                                         \
  V(DropTriggerStatement)                                                      \
  V(AttachStatement)                                                           \
  V(DetachStatement)                                                           \
  V(PragmaStatement)                                                           \
  V(FilePath)                                                                  \
  V(OptIfNotExists)                                                            \
  V(OptRecursive)                                                              \
  V(ColumnDefList)                                                             \
  V(ColumnDef)                                                                 \
  V(ColumnType)                                                                \
  V(OptColumnNullable)                                                         \
  V(OptIfExists)                                                               \
  V(ExistsOrNot)                                                               \
  V(OptColumnListParen)                                                        \
  V(UpdateClauseList)                                                          \
  V(UpdateClause)                                                              \
  V(SetOperator)                                                               \
  V(SelectCore)                                                                \
  V(SelectCoreList)                                                            \
  V(OptDistinct)                                                               \
  V(OptStoredVirtual)                                                          \
  V(SelectList)                                                                \
  V(FromClause)                                                                \
  V(OptFromClause)                                                             \
  V(OptWhere)                                                                  \
  V(OptGroup)                                                                  \
  V(OptHaving)                                                                 \
  V(OptOrder)                                                                  \
  V(OrderList)                                                                 \
  V(OrderTerm)                                                                 \
  V(OptOrderType)                                                              \
  V(OptLimit)                                                                  \
  V(ExprList)                                                                  \
  V(ExprListParen)                                                             \
  V(ExprListParenList)                                                         \
  V(NewExpr)                                                                   \
  V(ElseExpr)                                                                  \
  V(OptElseExpr)                                                               \
  V(OptExpr)                                                                   \
  V(UnaryOp)                                                                   \
  V(BinaryOp)                                                                  \
  V(InTarget)                                                                  \
  V(CaseCondition)                                                             \
  V(CaseConditionList)                                                         \
  V(ColumnName)                                                                \
  V(FunctionName)                                                              \
  V(FunctionArgs)                                                              \
  V(Literal)                                                                   \
  V(StringLiteral)                                                             \
  V(BlobLiteral)                                                               \
  V(NumericLiteral)                                                            \
  V(SignedNumber)                                                              \
  V(ForeignKeyClause)                                                          \
  V(ForeignKeyOn)                                                              \
  V(ForeignKeyOnList)                                                          \
  V(OptForeignKeyOnList)                                                       \
  V(DeferrableClause)                                                          \
  V(OptDeferrableClause)                                                       \
  V(NullLiteral)                                                               \
  V(ParamExpr)                                                                 \
  V(Identifier)                                                                \
  V(TableRefCommaList)                                                         \
  V(TableRefAtomic)                                                            \
  V(NonjoinTableRefAtomic)                                                     \
  V(TableRefName)                                                              \
  V(TableName)                                                                 \
  V(QualifiedTableName)                                                        \
  V(TableAlias)                                                                \
  V(OptTableAlias)                                                             \
  V(OptTableAliasAs)                                                           \
  V(ColumnAlias)                                                               \
  V(OptColumnAlias)                                                            \
  V(ResultColumn)                                                              \
  V(ResultColumnList)                                                          \
  V(OptReturningClause)                                                        \
  V(WithClause)                                                                \
  V(OptWithClause)                                                             \
  V(CommonTableExpr)                                                           \
  V(CommonTableExprList)                                                       \
  V(JoinClause)                                                                \
  V(OptJoinType)                                                               \
  V(JoinConstraint)                                                            \
  V(OptSemicolon)                                                              \
  V(Init)                                                                      \
  V(StatementList)                                                             \
  V(Unknown)                                                                   \
  V(Empty)                                                                     \
  V(PragmaKey)                                                                 \
  V(PragmaName)                                                                \
  V(PragmaValue)                                                               \
  V(SchemaName)                                                                \
  V(OptColumnConstraintlist)                                                   \
  V(ColumnConstraintlist)                                                      \
  V(ColumnConstraint)                                                          \
  V(OptConflictClause)                                                         \
  V(ResolveType)                                                               \
  V(OptAutoinc)                                                                \
  V(OptUnique)                                                                 \
  V(IndexName)                                                                 \
  V(OptTmp)                                                                    \
  V(TriggerName)                                                               \
  V(OptTriggerTime)                                                            \
  V(TriggerEvent)                                                              \
  V(OptOfColumnList)                                                           \
  V(OptForEach)                                                                \
  V(OptWhen)                                                                   \
  V(TriggerCmdList)                                                            \
  V(TriggerCmd)                                                                \
  V(ModuleName)                                                                \
  V(OptOverClause)                                                             \
  V(OptFilterClause)                                                           \
  V(FilterClause)                                                              \
  V(WindowClause)                                                              \
  V(OptWindowClause)                                                           \
  V(WindowDefnList)                                                            \
  V(WindowDefn)                                                                \
  V(WindowBody)                                                                \
  V(WindowName)                                                                \
  V(OptBaseWindowName)                                                         \
  V(OptFrame)                                                                  \
  V(RangeOrRows)                                                               \
  V(FrameBoundS)                                                               \
  V(FrameBoundE)                                                               \
  V(FrameBound)                                                                \
  V(FrameExclude)                                                              \
  V(OptFrameExclude)                                                           \
  V(InsertType)                                                                \
  V(UpdateType)                                                                \
  V(InsertValue)                                                               \
  V(ReindexStatement)                                                          \
  V(AnalyzeStatement)                                                          \
  V(OnExpr)                                                                    \
  V(EscapeExpr)                                                                \
  V(OptEscapeExpr)                                                             \
  V(WhereExpr)                                                                 \
  V(OptIndex)                                                                  \
  V(AlterStatement)                                                            \
  V(SavepointStatement)                                                        \
  V(ReleaseStatement)                                                          \
  V(OptColumn)                                                                 \
  V(VacuumStatement)                                                           \
  V(OptSchemaName)                                                             \
  V(RollbackStatement)                                                         \
  V(OptTransaction)                                                            \
  V(OptToSavepoint)                                                            \
  V(BeginStatement)                                                            \
  V(CommitStatement)                                                           \
  V(JoinOp)                                                                    \
  V(TableOrSubquery)                                                           \
  V(TableOrSubqueryList)                                                       \
  V(UpsertClause)                                                              \
  V(UpsertItem)                                                                \
  V(IndexedColumnList)                                                         \
  V(IndexedColumn)                                                             \
  V(OptCollate)                                                                \
  V(Collate)                                                                   \
  V(AssignList)                                                                \
  V(OptOrderOfNull)                                                            \
  V(NullOfExpr)                                                                \
  V(AssignClause)                                                              \
  V(ColumnNameList)                                                            \
  V(OptWithoutRowID)                                                           \
  V(OptStrict)                                                                 \
  V(OptUpsertClause)                                                           \
  V(OptConstraintName)                                                         \
  V(TableConstraint)                                                           \
  V(TableConstraintList)                                                       \
  V(JoinSuffix)                                                                \
  V(JoinSuffixList)                                                            \
  V(PartitionBy)                                                               \
  V(OptPartitionBy)                                                            \
  V(OptNot)                                                                    \
  V(RaiseFunction)                                                             \
  V(ConflictTarget)                                                            \
  V(OptConflictTarget)

#define SWITCHSTART switch (sub_type_) {

#define SWITCHEND                                                              \
  default:                                                                     \
                                                                               \
    assert(0);                                                                 \
    }

#define CASESTART(idx) case CASE##idx: {

#define CASEEND                                                                \
  break;                                                                       \
  }

#define TRANSLATESTART IR *res = NULL;

#define TRANSLATEEND                                                           \
  v_ir_collector.push_back(res);                                               \
                                                                               \
  return res;

#define TRANSLATEENDNOPUSH return res;

#define SAFETRANSLATE(a) (assert(a != NULL), a->translate(v_ir_collector))

#define SAFEDELETE(a)                                                          \
  if (a != NULL)                                                               \
  a->deep_delete()

#define SAFEDELETELIST(a)                                                      \
  for (auto _i : a)                                                            \
  SAFEDELETE(_i)

#define OP1(a) new IROperator(a)

#define OP2(a, b) new IROperator(a, b)

#define OP3(a, b, c) new IROperator(a, b, c)

#define OPSTART(a) new IROperator(a)

#define OPMID(a) new IROperator(NULL, a, NULL)

#define OPEND(a) new IROperator(NULL, NULL, a)

#define OP0() new IROperator()

#define TRANSLATELIST(t, a, b)                                                 \
  res = SAFETRANSLATE(a[0]);                                                   \
  res = new IR(t, OP0(), res);                                                 \
  v_ir_collector.push_back(res);                                               \
  for (int i = 1; i < a.size(); i++) {                                         \
    IR *tmp = SAFETRANSLATE(a[i]);                                             \
    res = new IR(t, OPMID(b), res, tmp);                                       \
    v_ir_collector.push_back(res);                                             \
  }

#define PUSH(a) v_ir_collector.push_back(a)

#define MUTATESTART                                                            \
  IR *res;                                                                     \
  auto randint = get_rand_int(3);                                              \
  switch (randint) {

#define DOLEFT case 0: {

#define DORIGHT                                                                \
  break;                                                                       \
  }                                                                            \
                                                                               \
  case 1: {

#define DOBOTH                                                                 \
  break;                                                                       \
  }                                                                            \
  case 2: {

#define MUTATEEND                                                              \
  }                                                                            \
  }                                                                            \
                                                                               \
  return res;

#endif
