%token  ABORT_SYM 258                     /* INTERNAL (used in lex) */
%token  ACCESSIBLE_SYM 259
%token<lexer.keyword> ACCOUNT_SYM 260
%token<lexer.keyword> ACTION 261                /* SQL-2003-N */
%token  ADD 262                           /* SQL-2003-R */
%token<lexer.keyword> ADDDATE_SYM 263           /* MYSQL-FUNC */
%token<lexer.keyword> AFTER_SYM 264             /* SQL-2003-N */
%token<lexer.keyword> AGAINST 265
%token<lexer.keyword> AGGREGATE_SYM 266
%token<lexer.keyword> ALGORITHM_SYM 267
%token  ALL 268                           /* SQL-2003-R */
%token  ALTER 269                         /* SQL-2003-R */
%token<lexer.keyword> ALWAYS_SYM 270
%token  OBSOLETE_TOKEN_271 271            /* was: ANALYSE_SYM */
%token  ANALYZE_SYM 272
%token  AND_AND_SYM 273                   /* OPERATOR */
%token  AND_SYM 274                       /* SQL-2003-R */
%token<lexer.keyword> ANY_SYM 275               /* SQL-2003-R */
%token  AS 276                            /* SQL-2003-R */
%token  ASC 277                           /* SQL-2003-N */
%token<lexer.keyword> ASCII_SYM 278             /* MYSQL-FUNC */
%token  ASENSITIVE_SYM 279                /* FUTURE-USE */
%token<lexer.keyword> AT_SYM 280                /* SQL-2003-R */
%token<lexer.keyword> AUTOEXTEND_SIZE_SYM 281
%token<lexer.keyword> AUTO_INC 282
%token<lexer.keyword> AVG_ROW_LENGTH 283
%token<lexer.keyword> AVG_SYM 284               /* SQL-2003-N */
%token<lexer.keyword> BACKUP_SYM 285
%token  BEFORE_SYM 286                    /* SQL-2003-N */
%token<lexer.keyword> BEGIN_SYM 287             /* SQL-2003-R */
%token  BETWEEN_SYM 288                   /* SQL-2003-R */
%token  BIGINT_SYM 289                    /* SQL-2003-R */
%token  BINARY_SYM 290                    /* SQL-2003-R */
%token<lexer.keyword> BINLOG_SYM 291
%token  BIN_NUM 292
%token  BIT_AND_SYM 293                   /* MYSQL-FUNC */
%token  BIT_OR_SYM 294                    /* MYSQL-FUNC */
%token<lexer.keyword> BIT_SYM 295               /* MYSQL-FUNC */
%token  BIT_XOR_SYM 296                   /* MYSQL-FUNC */
%token  BLOB_SYM 297                      /* SQL-2003-R */
%token<lexer.keyword> BLOCK_SYM 298
%token<lexer.keyword> BOOLEAN_SYM 299           /* SQL-2003-R */
%token<lexer.keyword> BOOL_SYM 300
%token  BOTH 301                          /* SQL-2003-R */
%token<lexer.keyword> BTREE_SYM 302
%token  BY 303                            /* SQL-2003-R */
%token<lexer.keyword> BYTE_SYM 304
%token<lexer.keyword> CACHE_SYM 305
%token  CALL_SYM 306                      /* SQL-2003-R */
%token  CASCADE 307                       /* SQL-2003-N */
%token<lexer.keyword> CASCADED 308              /* SQL-2003-R */
%token  CASE_SYM 309                      /* SQL-2003-R */
%token  CAST_SYM 310                      /* SQL-2003-R */
%token<lexer.keyword> CATALOG_NAME_SYM 311      /* SQL-2003-N */
%token<lexer.keyword> CHAIN_SYM 312             /* SQL-2003-N */
%token  CHANGE 313
%token<lexer.keyword> CHANGED 314
%token<lexer.keyword> CHANNEL_SYM 315
%token<lexer.keyword> CHARSET 316
%token  CHAR_SYM 317                      /* SQL-2003-R */
%token<lexer.keyword> CHECKSUM_SYM 318
%token  CHECK_SYM 319                     /* SQL-2003-R */
%token<lexer.keyword> CIPHER_SYM 320
%token<lexer.keyword> CLASS_ORIGIN_SYM 321      /* SQL-2003-N */
%token<lexer.keyword> CLIENT_SYM 322
%token<lexer.keyword> CLOSE_SYM 323             /* SQL-2003-R */
%token<lexer.keyword> COALESCE 324              /* SQL-2003-N */
%token<lexer.keyword> CODE_SYM 325
%token  COLLATE_SYM 326                   /* SQL-2003-R */
%token<lexer.keyword> COLLATION_SYM 327         /* SQL-2003-N */
%token<lexer.keyword> COLUMNS 328
%token  COLUMN_SYM 329                    /* SQL-2003-R */
%token<lexer.keyword> COLUMN_FORMAT_SYM 330
%token<lexer.keyword> COLUMN_NAME_SYM 331       /* SQL-2003-N */
%token<lexer.keyword> COMMENT_SYM 332
%token<lexer.keyword> COMMITTED_SYM 333         /* SQL-2003-N */
%token<lexer.keyword> COMMIT_SYM 334            /* SQL-2003-R */
%token<lexer.keyword> COMPACT_SYM 335
%token<lexer.keyword> COMPLETION_SYM 336
%token<lexer.keyword> COMPRESSED_SYM 337
%token<lexer.keyword> COMPRESSION_SYM 338
%token<lexer.keyword> ENCRYPTION_SYM 339
%token<lexer.keyword> CONCURRENT 340
%token  CONDITION_SYM 341                 /* SQL-2003-R, SQL-2008-R */
%token<lexer.keyword> CONNECTION_SYM 342
%token<lexer.keyword> CONSISTENT_SYM 343
%token  CONSTRAINT 344                    /* SQL-2003-R */
%token<lexer.keyword> CONSTRAINT_CATALOG_SYM 345 /* SQL-2003-N */
%token<lexer.keyword> CONSTRAINT_NAME_SYM 346   /* SQL-2003-N */
%token<lexer.keyword> CONSTRAINT_SCHEMA_SYM 347 /* SQL-2003-N */
%token<lexer.keyword> CONTAINS_SYM 348          /* SQL-2003-N */
%token<lexer.keyword> CONTEXT_SYM 349
%token  CONTINUE_SYM 350                  /* SQL-2003-R */
%token  CONVERT_SYM 351                   /* SQL-2003-N */
%token  COUNT_SYM 352                     /* SQL-2003-N */
%token<lexer.keyword> CPU_SYM 353
%token  CREATE 354                        /* SQL-2003-R */
%token  CROSS 355                         /* SQL-2003-R */
%token  CUBE_SYM 356                      /* SQL-2003-R */
%token  CURDATE 357                       /* MYSQL-FUNC */
%token<lexer.keyword> CURRENT_SYM 358           /* SQL-2003-R */
%token  CURRENT_USER 359                  /* SQL-2003-R */
%token  CURSOR_SYM 360                    /* SQL-2003-R */
%token<lexer.keyword> CURSOR_NAME_SYM 361       /* SQL-2003-N */
%token  CURTIME 362                       /* MYSQL-FUNC */
%token  DATABASE 363
%token  DATABASES 364
%token<lexer.keyword> DATAFILE_SYM 365
%token<lexer.keyword> DATA_SYM 366              /* SQL-2003-N */
%token<lexer.keyword> DATETIME_SYM 367          /* MYSQL */
%token  DATE_ADD_INTERVAL 368             /* MYSQL-FUNC */
%token  DATE_SUB_INTERVAL 369             /* MYSQL-FUNC */
%token<lexer.keyword> DATE_SYM 370              /* SQL-2003-R */
%token  DAY_HOUR_SYM 371
%token  DAY_MICROSECOND_SYM 372
%token  DAY_MINUTE_SYM 373
%token  DAY_SECOND_SYM 374
%token<lexer.keyword> DAY_SYM 375               /* SQL-2003-R */
%token<lexer.keyword> DEALLOCATE_SYM 376        /* SQL-2003-R */
%token  DECIMAL_NUM 377
%token  DECIMAL_SYM 378                   /* SQL-2003-R */
%token  DECLARE_SYM 379                   /* SQL-2003-R */
%token  DEFAULT_SYM 380                   /* SQL-2003-R */
%token<lexer.keyword> DEFAULT_AUTH_SYM 381      /* INTERNAL */
%token<lexer.keyword> DEFINER_SYM 382
%token  DELAYED_SYM 383
%token<lexer.keyword> DELAY_KEY_WRITE_SYM 384
%token  DELETE_SYM 385                    /* SQL-2003-R */
%token  DESC 386                          /* SQL-2003-N */
%token  DESCRIBE 387                      /* SQL-2003-R */
%token  OBSOLETE_TOKEN_388 388            /* was: DES_KEY_FILE */
%token  DETERMINISTIC_SYM 389             /* SQL-2003-R */
%token<lexer.keyword> DIAGNOSTICS_SYM 390       /* SQL-2003-N */
%token<lexer.keyword> DIRECTORY_SYM 391
%token<lexer.keyword> DISABLE_SYM 392
%token<lexer.keyword> DISCARD_SYM 393           /* MYSQL */
%token<lexer.keyword> DISK_SYM 394
%token  DISTINCT 395                      /* SQL-2003-R */
%token  DIV_SYM 396
%token  DOUBLE_SYM 397                    /* SQL-2003-R */
%token<lexer.keyword> DO_SYM 398
%token  DROP 399                          /* SQL-2003-R */
%token  DUAL_SYM 400
%token<lexer.keyword> DUMPFILE 401
%token<lexer.keyword> DUPLICATE_SYM 402
%token<lexer.keyword> DYNAMIC_SYM 403           /* SQL-2003-R */
%token  EACH_SYM 404                      /* SQL-2003-R */
%token  ELSE 405                          /* SQL-2003-R */
%token  ELSEIF_SYM 406
%token<lexer.keyword> ENABLE_SYM 407
%token  ENCLOSED 408
%token<lexer.keyword> END 409                   /* SQL-2003-R */
%token<lexer.keyword> ENDS_SYM 410
%token  END_OF_INPUT 411                  /* INTERNAL */
%token<lexer.keyword> ENGINES_SYM 412
%token<lexer.keyword> ENGINE_SYM 413
%token<lexer.keyword> ENUM_SYM 414              /* MYSQL */
%token  EQ 415                            /* OPERATOR */
%token  EQUAL_SYM 416                     /* OPERATOR */
%token<lexer.keyword> ERROR_SYM 417
%token<lexer.keyword> ERRORS 418
%token  ESCAPED 419
%token<lexer.keyword> ESCAPE_SYM 420            /* SQL-2003-R */
%token<lexer.keyword> EVENTS_SYM 421
%token<lexer.keyword> EVENT_SYM 422
%token<lexer.keyword> EVERY_SYM 423             /* SQL-2003-N */
%token<lexer.keyword> EXCHANGE_SYM 424
%token<lexer.keyword> EXECUTE_SYM 425           /* SQL-2003-R */
%token  EXISTS 426                        /* SQL-2003-R */
%token  EXIT_SYM 427
%token<lexer.keyword> EXPANSION_SYM 428
%token<lexer.keyword> EXPIRE_SYM 429
%token<lexer.keyword> EXPORT_SYM 430
%token<lexer.keyword> EXTENDED_SYM 431
%token<lexer.keyword> EXTENT_SIZE_SYM 432
%token  EXTRACT_SYM 433                   /* SQL-2003-N */
%token  FALSE_SYM 434                     /* SQL-2003-R */
%token<lexer.keyword> FAST_SYM 435
%token<lexer.keyword> FAULTS_SYM 436
%token  FETCH_SYM 437                     /* SQL-2003-R */
%token<lexer.keyword> FILE_SYM 438
%token<lexer.keyword> FILE_BLOCK_SIZE_SYM 439
%token<lexer.keyword> FILTER_SYM 440
%token<lexer.keyword> FIRST_SYM 441             /* SQL-2003-N */
%token<lexer.keyword> FIXED_SYM 442
%token  FLOAT_NUM 443
%token  FLOAT_SYM 444                     /* SQL-2003-R */
%token<lexer.keyword> FLUSH_SYM 445
%token<lexer.keyword> FOLLOWS_SYM 446           /* MYSQL */
%token  FORCE_SYM 447
%token  FOREIGN 448                       /* SQL-2003-R */
%token  FOR_SYM 449                       /* SQL-2003-R */
%token<lexer.keyword> FORMAT_SYM 450
%token<lexer.keyword> FOUND_SYM 451             /* SQL-2003-R */
%token  FROM 452
%token<lexer.keyword> FULL 453                  /* SQL-2003-R */
%token  FULLTEXT_SYM 454
%token  FUNCTION_SYM 455                  /* SQL-2003-R */
%token  GE 456
%token<lexer.keyword> GENERAL 457
%token  GENERATED 458
%token<lexer.keyword> GROUP_REPLICATION 459
%token<lexer.keyword> GEOMETRYCOLLECTION_SYM 460 /* MYSQL */
%token<lexer.keyword> GEOMETRY_SYM 461
%token<lexer.keyword> GET_FORMAT 462            /* MYSQL-FUNC */
%token  GET_SYM 463                       /* SQL-2003-R */
%token<lexer.keyword> GLOBAL_SYM 464            /* SQL-2003-R */
%token  GRANT 465                         /* SQL-2003-R */
%token<lexer.keyword> GRANTS 466
%token  GROUP_SYM 467                     /* SQL-2003-R */
%token  GROUP_CONCAT_SYM 468
%token  GT_SYM 469                        /* OPERATOR */
%token<lexer.keyword> HANDLER_SYM 470
%token<lexer.keyword> HASH_SYM 471
%token  HAVING 472                        /* SQL-2003-R */
%token<lexer.keyword> HELP_SYM 473
%token  HEX_NUM 474
%token  HIGH_PRIORITY 475
%token<lexer.keyword> HOST_SYM 476
%token<lexer.keyword> HOSTS_SYM 477
%token  HOUR_MICROSECOND_SYM 478
%token  HOUR_MINUTE_SYM 479
%token  HOUR_SECOND_SYM 480
%token<lexer.keyword> HOUR_SYM 481              /* SQL-2003-R */
%token  IDENT 482
%token<lexer.keyword> IDENTIFIED_SYM 483
%token  IDENT_QUOTED 484
%token  IF 485
%token  IGNORE_SYM 486
%token<lexer.keyword> IGNORE_SERVER_IDS_SYM 487
%token<lexer.keyword> IMPORT 488
%token<lexer.keyword> INDEXES 489
%token  INDEX_SYM 490
%token  INFILE 491
%token<lexer.keyword> INITIAL_SIZE_SYM 492
%token  INNER_SYM 493                     /* SQL-2003-R */
%token  INOUT_SYM 494                     /* SQL-2003-R */
%token  INSENSITIVE_SYM 495               /* SQL-2003-R */
%token  INSERT_SYM 496                    /* SQL-2003-R */
%token<lexer.keyword> INSERT_METHOD 497
%token<lexer.keyword> INSTANCE_SYM 498
%token<lexer.keyword> INSTALL_SYM 499
%token  INTERVAL_SYM 500                  /* SQL-2003-R */
%token  INTO 501                          /* SQL-2003-R */
%token  INT_SYM 502                       /* SQL-2003-R */
%token<lexer.keyword> INVOKER_SYM 503
%token  IN_SYM 504                        /* SQL-2003-R */
%token  IO_AFTER_GTIDS 505                /* MYSQL, FUTURE-USE */
%token  IO_BEFORE_GTIDS 506               /* MYSQL, FUTURE-USE */
%token<lexer.keyword> IO_SYM 507
%token<lexer.keyword> IPC_SYM 508
%token  IS 509                            /* SQL-2003-R */
%token<lexer.keyword> ISOLATION 510             /* SQL-2003-R */
%token<lexer.keyword> ISSUER_SYM 511
%token  ITERATE_SYM 512
%token  JOIN_SYM 513                      /* SQL-2003-R */
%token  JSON_SEPARATOR_SYM 514            /* MYSQL */
%token<lexer.keyword> JSON_SYM 515              /* MYSQL */
%token  KEYS 516
%token<lexer.keyword> KEY_BLOCK_SIZE 517
%token  KEY_SYM 518                       /* SQL-2003-N */
%token  KILL_SYM 519
%token<lexer.keyword> LANGUAGE_SYM 520          /* SQL-2003-R */
%token<lexer.keyword> LAST_SYM 521              /* SQL-2003-N */
%token  LE 522                            /* OPERATOR */
%token  LEADING 523                       /* SQL-2003-R */
%token<lexer.keyword> LEAVES 524
%token  LEAVE_SYM 525
%token  LEFT 526                          /* SQL-2003-R */
%token<lexer.keyword> LESS_SYM 527
%token<lexer.keyword> LEVEL_SYM 528
%token  LEX_HOSTNAME 529
%token  LIKE 530                          /* SQL-2003-R */
%token  LIMIT 531
%token  LINEAR_SYM 532
%token  LINES 533
%token<lexer.keyword> LINESTRING_SYM 534        /* MYSQL */
%token<lexer.keyword> LIST_SYM 535
%token  LOAD 536
%token<lexer.keyword> LOCAL_SYM 537             /* SQL-2003-R */
%token  OBSOLETE_TOKEN_538 538            /* was: LOCATOR_SYM */
%token<lexer.keyword> LOCKS_SYM 539
%token  LOCK_SYM 540
%token<lexer.keyword> LOGFILE_SYM 541
%token<lexer.keyword> LOGS_SYM 542
%token  LONGBLOB_SYM 543                  /* MYSQL */
%token  LONGTEXT_SYM 544                  /* MYSQL */
%token  LONG_NUM 545
%token  LONG_SYM 546
%token  LOOP_SYM 547
%token  LOW_PRIORITY 548
%token  LT 549                            /* OPERATOR */
%token<lexer.keyword> MASTER_AUTO_POSITION_SYM 550
%token  MASTER_BIND_SYM 551
%token<lexer.keyword> MASTER_CONNECT_RETRY_SYM 552
%token<lexer.keyword> MASTER_DELAY_SYM 553
%token<lexer.keyword> MASTER_HOST_SYM 554
%token<lexer.keyword> MASTER_LOG_FILE_SYM 555
%token<lexer.keyword> MASTER_LOG_POS_SYM 556
%token<lexer.keyword> MASTER_PASSWORD_SYM 557
%token<lexer.keyword> MASTER_PORT_SYM 558
%token<lexer.keyword> MASTER_RETRY_COUNT_SYM 559
/* %token<lexer.keyword> MASTER_SERVER_ID_SYM 560 */ /* UNUSED */
%token<lexer.keyword> MASTER_SSL_CAPATH_SYM 561
%token<lexer.keyword> MASTER_TLS_VERSION_SYM 562
%token<lexer.keyword> MASTER_SSL_CA_SYM 563
%token<lexer.keyword> MASTER_SSL_CERT_SYM 564
%token<lexer.keyword> MASTER_SSL_CIPHER_SYM 565
%token<lexer.keyword> MASTER_SSL_CRL_SYM 566
%token<lexer.keyword> MASTER_SSL_CRLPATH_SYM 567
%token<lexer.keyword> MASTER_SSL_KEY_SYM 568
%token<lexer.keyword> MASTER_SSL_SYM 569
%token  MASTER_SSL_VERIFY_SERVER_CERT_SYM 570
%token<lexer.keyword> MASTER_SYM 571
%token<lexer.keyword> MASTER_USER_SYM 572
%token<lexer.keyword> MASTER_HEARTBEAT_PERIOD_SYM 573
%token  MATCH 574                         /* SQL-2003-R */
%token<lexer.keyword> MAX_CONNECTIONS_PER_HOUR 575
%token<lexer.keyword> MAX_QUERIES_PER_HOUR 576
%token<lexer.keyword> MAX_ROWS 577
%token<lexer.keyword> MAX_SIZE_SYM 578
%token  MAX_SYM 579                       /* SQL-2003-N */
%token<lexer.keyword> MAX_UPDATES_PER_HOUR 580
%token<lexer.keyword> MAX_USER_CONNECTIONS_SYM 581
%token  MAX_VALUE_SYM 582                 /* SQL-2003-N */
%token  MEDIUMBLOB_SYM 583                /* MYSQL */
%token  MEDIUMINT_SYM 584                 /* MYSQL */
%token  MEDIUMTEXT_SYM 585                /* MYSQL */
%token<lexer.keyword> MEDIUM_SYM 586
%token<lexer.keyword> MEMORY_SYM 587
%token<lexer.keyword> MERGE_SYM 588             /* SQL-2003-R */
%token<lexer.keyword> MESSAGE_TEXT_SYM 589      /* SQL-2003-N */
%token<lexer.keyword> MICROSECOND_SYM 590       /* MYSQL-FUNC */
%token<lexer.keyword> MIGRATE_SYM 591
%token  MINUTE_MICROSECOND_SYM 592
%token  MINUTE_SECOND_SYM 593
%token<lexer.keyword> MINUTE_SYM 594            /* SQL-2003-R */
%token<lexer.keyword> MIN_ROWS 595
%token  MIN_SYM 596                       /* SQL-2003-N */
%token<lexer.keyword> MODE_SYM 597
%token  MODIFIES_SYM 598                  /* SQL-2003-R */
%token<lexer.keyword> MODIFY_SYM 599
%token  MOD_SYM 600                       /* SQL-2003-N */
%token<lexer.keyword> MONTH_SYM 601             /* SQL-2003-R */
%token<lexer.keyword> MULTILINESTRING_SYM 602   /* MYSQL */
%token<lexer.keyword> MULTIPOINT_SYM 603        /* MYSQL */
%token<lexer.keyword> MULTIPOLYGON_SYM 604      /* MYSQL */
%token<lexer.keyword> MUTEX_SYM 605
%token<lexer.keyword> MYSQL_ERRNO_SYM 606
%token<lexer.keyword> NAMES_SYM 607             /* SQL-2003-N */
%token<lexer.keyword> NAME_SYM 608              /* SQL-2003-N */
%token<lexer.keyword> NATIONAL_SYM 609          /* SQL-2003-R */
%token  NATURAL 610                       /* SQL-2003-R */
%token  NCHAR_STRING 611
%token<lexer.keyword> NCHAR_SYM 612             /* SQL-2003-R */
%token<lexer.keyword> NDBCLUSTER_SYM 613
%token  NE 614                            /* OPERATOR */
%token  NEG 615
%token<lexer.keyword> NEVER_SYM 616
%token<lexer.keyword> NEW_SYM 617               /* SQL-2003-R */
%token<lexer.keyword> NEXT_SYM 618              /* SQL-2003-N */
%token<lexer.keyword> NODEGROUP_SYM 619
%token<lexer.keyword> NONE_SYM 620              /* SQL-2003-R */
%token  NOT2_SYM 621
%token  NOT_SYM 622                       /* SQL-2003-R */
%token  NOW_SYM 623
%token<lexer.keyword> NO_SYM 624                /* SQL-2003-R */
%token<lexer.keyword> NO_WAIT_SYM 625
%token  NO_WRITE_TO_BINLOG 626
%token  NULL_SYM 627                      /* SQL-2003-R */
%token  NUM 628
%token<lexer.keyword> NUMBER_SYM 629            /* SQL-2003-N */
%token  NUMERIC_SYM 630                   /* SQL-2003-R */
%token<lexer.keyword> NVARCHAR_SYM 631
%token<lexer.keyword> OFFSET_SYM 632
%token  ON_SYM 633                        /* SQL-2003-R */
%token<lexer.keyword> ONE_SYM 634
%token<lexer.keyword> ONLY_SYM 635              /* SQL-2003-R */
%token<lexer.keyword> OPEN_SYM 636              /* SQL-2003-R */
%token  OPTIMIZE 637
%token  OPTIMIZER_COSTS_SYM 638
%token<lexer.keyword> OPTIONS_SYM 639
%token  OPTION 640                        /* SQL-2003-N */
%token  OPTIONALLY 641
%token  OR2_SYM 642
%token  ORDER_SYM 643                     /* SQL-2003-R */
%token  OR_OR_SYM 644                     /* OPERATOR */
%token  OR_SYM 645                        /* SQL-2003-R */
%token  OUTER_SYM 646
%token  OUTFILE 647
%token  OUT_SYM 648                       /* SQL-2003-R */
%token<lexer.keyword> OWNER_SYM 649
%token<lexer.keyword> PACK_KEYS_SYM 650
%token<lexer.keyword> PAGE_SYM 651
%token  PARAM_MARKER 652
%token<lexer.keyword> PARSER_SYM 653
%token  OBSOLETE_TOKEN_654 654            /* was: PARSE_GCOL_EXPR_SYM */
%token<lexer.keyword> PARTIAL 655                       /* SQL-2003-N */
%token  PARTITION_SYM 656                 /* SQL-2003-R */
%token<lexer.keyword> PARTITIONS_SYM 657
%token<lexer.keyword> PARTITIONING_SYM 658
%token<lexer.keyword> PASSWORD 659
%token<lexer.keyword> PHASE_SYM 660
%token<lexer.keyword> PLUGIN_DIR_SYM 661        /* INTERNAL */
%token<lexer.keyword> PLUGIN_SYM 662
%token<lexer.keyword> PLUGINS_SYM 663
%token<lexer.keyword> POINT_SYM 664
%token<lexer.keyword> POLYGON_SYM 665           /* MYSQL */
%token<lexer.keyword> PORT_SYM 666
%token  POSITION_SYM 667                  /* SQL-2003-N */
%token<lexer.keyword> PRECEDES_SYM 668          /* MYSQL */
%token  PRECISION 669                     /* SQL-2003-R */
%token<lexer.keyword> PREPARE_SYM 670           /* SQL-2003-R */
%token<lexer.keyword> PRESERVE_SYM 671
%token<lexer.keyword> PREV_SYM 672
%token  PRIMARY_SYM 673                   /* SQL-2003-R */
%token<lexer.keyword> PRIVILEGES 674            /* SQL-2003-N */
%token  PROCEDURE_SYM 675                 /* SQL-2003-R */
%token<lexer.keyword> PROCESS 676
%token<lexer.keyword> PROCESSLIST_SYM 677
%token<lexer.keyword> PROFILE_SYM 678
%token<lexer.keyword> PROFILES_SYM 679
%token<lexer.keyword> PROXY_SYM 680
%token  PURGE 681
%token<lexer.keyword> QUARTER_SYM 682
%token<lexer.keyword> QUERY_SYM 683
%token<lexer.keyword> QUICK 684
%token  RANGE_SYM 685                     /* SQL-2003-R */
%token  READS_SYM 686                     /* SQL-2003-R */
%token<lexer.keyword> READ_ONLY_SYM 687
%token  READ_SYM 688                      /* SQL-2003-N */
%token  READ_WRITE_SYM 689
%token  REAL_SYM 690                      /* SQL-2003-R */
%token<lexer.keyword> REBUILD_SYM 691
%token<lexer.keyword> RECOVER_SYM 692
%token  OBSOLETE_TOKEN_693 693            /* was: REDOFILE_SYM */
%token<lexer.keyword> REDO_BUFFER_SIZE_SYM 694
%token<lexer.keyword> REDUNDANT_SYM 695
%token  REFERENCES 696                    /* SQL-2003-R */
%token  REGEXP 697
%token<lexer.keyword> RELAY 698
%token<lexer.keyword> RELAYLOG_SYM 699
%token<lexer.keyword> RELAY_LOG_FILE_SYM 700
%token<lexer.keyword> RELAY_LOG_POS_SYM 701
%token<lexer.keyword> RELAY_THREAD 702
%token  RELEASE_SYM 703                   /* SQL-2003-R */
%token<lexer.keyword> RELOAD 704
%token<lexer.keyword> REMOVE_SYM 705
%token  RENAME 706
%token<lexer.keyword> REORGANIZE_SYM 707
%token<lexer.keyword> REPAIR 708
%token<lexer.keyword> REPEATABLE_SYM 709        /* SQL-2003-N */
%token  REPEAT_SYM 710                    /* MYSQL-FUNC */
%token  REPLACE_SYM 711                   /* MYSQL-FUNC */
%token<lexer.keyword> REPLICATION 712
%token<lexer.keyword> REPLICATE_DO_DB 713
%token<lexer.keyword> REPLICATE_IGNORE_DB 714
%token<lexer.keyword> REPLICATE_DO_TABLE 715
%token<lexer.keyword> REPLICATE_IGNORE_TABLE 716
%token<lexer.keyword> REPLICATE_WILD_DO_TABLE 717
%token<lexer.keyword> REPLICATE_WILD_IGNORE_TABLE 718
%token<lexer.keyword> REPLICATE_REWRITE_DB 719
%token  REQUIRE_SYM 720
%token<lexer.keyword> RESET_SYM 721
%token  RESIGNAL_SYM 722                  /* SQL-2003-R */
%token<lexer.keyword> RESOURCES 723
%token<lexer.keyword> RESTORE_SYM 724
%token  RESTRICT 725
%token<lexer.keyword> RESUME_SYM 726
%token<lexer.keyword> RETURNED_SQLSTATE_SYM 727 /* SQL-2003-N */
%token<lexer.keyword> RETURNS_SYM 728           /* SQL-2003-R */
%token  RETURN_SYM 729                    /* SQL-2003-R */
%token<lexer.keyword> REVERSE_SYM 730
%token  REVOKE 731                        /* SQL-2003-R */
%token  RIGHT 732                         /* SQL-2003-R */
%token<lexer.keyword> ROLLBACK_SYM 733          /* SQL-2003-R */
%token<lexer.keyword> ROLLUP_SYM 734            /* SQL-2003-R */
%token<lexer.keyword> ROTATE_SYM 735
%token<lexer.keyword> ROUTINE_SYM 736           /* SQL-2003-N */
%token  ROWS_SYM 737                      /* SQL-2003-R */
%token<lexer.keyword> ROW_FORMAT_SYM 738
%token  ROW_SYM 739                       /* SQL-2003-R */
%token<lexer.keyword> ROW_COUNT_SYM 740         /* SQL-2003-N */
%token<lexer.keyword> RTREE_SYM 741
%token<lexer.keyword> SAVEPOINT_SYM 742         /* SQL-2003-R */
%token<lexer.keyword> SCHEDULE_SYM 743
%token<lexer.keyword> SCHEMA_NAME_SYM 744       /* SQL-2003-N */
%token  SECOND_MICROSECOND_SYM 745
%token<lexer.keyword> SECOND_SYM 746            /* SQL-2003-R */
%token<lexer.keyword> SECURITY_SYM 747          /* SQL-2003-N */
%token  SELECT_SYM 748                    /* SQL-2003-R */
%token  SENSITIVE_SYM 749                 /* FUTURE-USE */
%token  SEPARATOR_SYM 750
%token<lexer.keyword> SERIALIZABLE_SYM 751      /* SQL-2003-N */
%token<lexer.keyword> SERIAL_SYM 752
%token<lexer.keyword> SESSION_SYM 753           /* SQL-2003-N */
%token<lexer.keyword> SERVER_SYM 754
%token  OBSOLETE_TOKEN_755 755            /* was: SERVER_OPTIONS */
%token  SET_SYM 756                       /* SQL-2003-R */
%token  SET_VAR 757
%token<lexer.keyword> SHARE_SYM 758
%token  SHIFT_LEFT 759                    /* OPERATOR */
%token  SHIFT_RIGHT 760                   /* OPERATOR */
%token  SHOW 761
%token<lexer.keyword> SHUTDOWN 762
%token  SIGNAL_SYM 763                    /* SQL-2003-R */
%token<lexer.keyword> SIGNED_SYM 764
%token<lexer.keyword> SIMPLE_SYM 765            /* SQL-2003-N */
%token<lexer.keyword> SLAVE 766
%token<lexer.keyword> SLOW 767
%token  SMALLINT_SYM 768                  /* SQL-2003-R */
%token<lexer.keyword> SNAPSHOT_SYM 769
%token<lexer.keyword> SOCKET_SYM 770
%token<lexer.keyword> SONAME_SYM 771
%token<lexer.keyword> SOUNDS_SYM 772
%token<lexer.keyword> SOURCE_SYM 773
%token  SPATIAL_SYM 774
%token  SPECIFIC_SYM 775                  /* SQL-2003-R */
%token  SQLEXCEPTION_SYM 776              /* SQL-2003-R */
%token  SQLSTATE_SYM 777                  /* SQL-2003-R */
%token  SQLWARNING_SYM 778                /* SQL-2003-R */
%token<lexer.keyword> SQL_AFTER_GTIDS 779       /* MYSQL */
%token<lexer.keyword> SQL_AFTER_MTS_GAPS 780    /* MYSQL */
%token<lexer.keyword> SQL_BEFORE_GTIDS 781      /* MYSQL */
%token  SQL_BIG_RESULT 782
%token<lexer.keyword> SQL_BUFFER_RESULT 783
%token  OBSOLETE_TOKEN_784 784            /* was: SQL_CACHE_SYM */
%token  SQL_CALC_FOUND_ROWS 785
%token<lexer.keyword> SQL_NO_CACHE_SYM 786
%token  SQL_SMALL_RESULT 787
%token  SQL_SYM 788                       /* SQL-2003-R */
%token<lexer.keyword> SQL_THREAD 789
%token  SSL_SYM 790
%token<lexer.keyword> STACKED_SYM 791           /* SQL-2003-N */
%token  STARTING 792
%token<lexer.keyword> STARTS_SYM 793
%token<lexer.keyword> START_SYM 794             /* SQL-2003-R */
%token<lexer.keyword> STATS_AUTO_RECALC_SYM 795
%token<lexer.keyword> STATS_PERSISTENT_SYM 796
%token<lexer.keyword> STATS_SAMPLE_PAGES_SYM 797
%token<lexer.keyword> STATUS_SYM 798
%token  STDDEV_SAMP_SYM 799               /* SQL-2003-N */
%token  STD_SYM 800
%token<lexer.keyword> STOP_SYM 801
%token<lexer.keyword> STORAGE_SYM 802
%token  STORED_SYM 803
%token  STRAIGHT_JOIN 804
%token<lexer.keyword> STRING_SYM 805
%token<lexer.keyword> SUBCLASS_ORIGIN_SYM 806   /* SQL-2003-N */
%token<lexer.keyword> SUBDATE_SYM 807
%token<lexer.keyword> SUBJECT_SYM 808
%token<lexer.keyword> SUBPARTITIONS_SYM 809
%token<lexer.keyword> SUBPARTITION_SYM 810
%token  SUBSTRING 811                     /* SQL-2003-N */
%token  SUM_SYM 812                       /* SQL-2003-N */
%token<lexer.keyword> SUPER_SYM 813
%token<lexer.keyword> SUSPEND_SYM 814
%token<lexer.keyword> SWAPS_SYM 815
%token<lexer.keyword> SWITCHES_SYM 816
%token  SYSDATE 817
%token<lexer.keyword> TABLES 818
%token<lexer.keyword> TABLESPACE_SYM 819
%token  OBSOLETE_TOKEN_820 820            /* was: TABLE_REF_PRIORITY */
%token  TABLE_SYM 821                     /* SQL-2003-R */
%token<lexer.keyword> TABLE_CHECKSUM_SYM 822
%token<lexer.keyword> TABLE_NAME_SYM 823        /* SQL-2003-N */
%token<lexer.keyword> TEMPORARY 824             /* SQL-2003-N */
%token<lexer.keyword> TEMPTABLE_SYM 825
%token  TERMINATED 826
%token  TEXT_STRING 827
%token<lexer.keyword> TEXT_SYM 828
%token<lexer.keyword> THAN_SYM 829
%token  THEN_SYM 830                      /* SQL-2003-R */
%token<lexer.keyword> TIMESTAMP_SYM 831         /* SQL-2003-R */
%token<lexer.keyword> TIMESTAMP_ADD 832
%token<lexer.keyword> TIMESTAMP_DIFF 833
%token<lexer.keyword> TIME_SYM 834              /* SQL-2003-R */
%token  TINYBLOB_SYM 835                  /* MYSQL */
%token  TINYINT_SYM 836                   /* MYSQL */
%token  TINYTEXT_SYN 837                  /* MYSQL */
%token  TO_SYM 838                        /* SQL-2003-R */
%token  TRAILING 839                      /* SQL-2003-R */
%token<lexer.keyword> TRANSACTION_SYM 840
%token<lexer.keyword> TRIGGERS_SYM 841
%token  TRIGGER_SYM 842                   /* SQL-2003-R */
%token  TRIM 843                          /* SQL-2003-N */
%token  TRUE_SYM 844                      /* SQL-2003-R */
%token<lexer.keyword> TRUNCATE_SYM 845
%token<lexer.keyword> TYPES_SYM 846
%token<lexer.keyword> TYPE_SYM 847              /* SQL-2003-N */
%token  OBSOLETE_TOKEN_848 848            /* was:  UDF_RETURNS_SYM */
%token  ULONGLONG_NUM 849
%token<lexer.keyword> UNCOMMITTED_SYM 850       /* SQL-2003-N */
%token<lexer.keyword> UNDEFINED_SYM 851
%token  UNDERSCORE_CHARSET 852
%token<lexer.keyword> UNDOFILE_SYM 853
%token<lexer.keyword> UNDO_BUFFER_SIZE_SYM 854
%token  UNDO_SYM 855                      /* FUTURE-USE */
%token<lexer.keyword> UNICODE_SYM 856
%token<lexer.keyword> UNINSTALL_SYM 857
%token  UNION_SYM 858                     /* SQL-2003-R */
%token  UNIQUE_SYM 859
%token<lexer.keyword> UNKNOWN_SYM 860           /* SQL-2003-R */
%token  UNLOCK_SYM 861
%token  UNSIGNED_SYM 862                  /* MYSQL */
%token<lexer.keyword> UNTIL_SYM 863
%token  UPDATE_SYM 864                    /* SQL-2003-R */
%token<lexer.keyword> UPGRADE_SYM 865
%token  USAGE 866                         /* SQL-2003-N */
%token<lexer.keyword> USER 867                  /* SQL-2003-R */
%token<lexer.keyword> USE_FRM 868
%token  USE_SYM 869
%token  USING 870                         /* SQL-2003-R */
%token  UTC_DATE_SYM 871
%token  UTC_TIMESTAMP_SYM 872
%token  UTC_TIME_SYM 873
%token<lexer.keyword> VALIDATION_SYM 874        /* MYSQL */
%token  VALUES 875                        /* SQL-2003-R */
%token<lexer.keyword> VALUE_SYM 876             /* SQL-2003-R */
%token  VARBINARY_SYM 877                 /* SQL-2008-R */
%token  VARCHAR_SYM 878                   /* SQL-2003-R */
%token<lexer.keyword> VARIABLES 879
%token  VARIANCE_SYM 880
%token  VARYING 881                       /* SQL-2003-R */
%token  VAR_SAMP_SYM 882
%token<lexer.keyword> VIEW_SYM 883              /* SQL-2003-N */
%token  VIRTUAL_SYM 884
%token<lexer.keyword> WAIT_SYM 885
%token<lexer.keyword> WARNINGS 886
%token<lexer.keyword> WEEK_SYM 887
%token<lexer.keyword> WEIGHT_STRING_SYM 888
%token  WHEN_SYM 889                      /* SQL-2003-R */
%token  WHERE 890                         /* SQL-2003-R */
%token  WHILE_SYM 891
%token  WITH 892                          /* SQL-2003-R */
%token  OBSOLETE_TOKEN_893 893            /* was: WITH_CUBE_SYM */
%token  WITH_ROLLUP_SYM 894               /* INTERNAL */
%token<lexer.keyword> WITHOUT_SYM 895           /* SQL-2003-R */
%token<lexer.keyword> WORK_SYM 896              /* SQL-2003-N */
%token<lexer.keyword> WRAPPER_SYM 897
%token  WRITE_SYM 898                     /* SQL-2003-N */
%token<lexer.keyword> X509_SYM 899
%token<lexer.keyword> XA_SYM 900
%token<lexer.keyword> XID_SYM 901               /* MYSQL */
%token<lexer.keyword> XML_SYM 902
%token  XOR 903
%token  YEAR_MONTH_SYM 904
%token<lexer.keyword> YEAR_SYM 905              /* SQL-2003-R */
%token  ZEROFILL_SYM 906                  /* MYSQL */

/*
   Tokens from MySQL 8.0
*/
%token  JSON_UNQUOTED_SEPARATOR_SYM 907   /* MYSQL */
%token<lexer.keyword> PERSIST_SYM 908           /* MYSQL */
%token<lexer.keyword> ROLE_SYM 909              /* SQL-1999-R */
%token<lexer.keyword> ADMIN_SYM 910             /* SQL-2003-N */
%token<lexer.keyword> INVISIBLE_SYM 911
%token<lexer.keyword> VISIBLE_SYM 912
%token  EXCEPT_SYM 913                    /* SQL-1999-R */
%token<lexer.keyword> COMPONENT_SYM 914         /* MYSQL */
%token  RECURSIVE_SYM 915                 /* SQL-1999-R */
%token  GRAMMAR_SELECTOR_EXPR 916         /* synthetic token: starts single expr. */
%token  GRAMMAR_SELECTOR_GCOL 917       /* synthetic token: starts generated col. */
%token  GRAMMAR_SELECTOR_PART 918      /* synthetic token: starts partition expr. */
%token  GRAMMAR_SELECTOR_CTE 919             /* synthetic token: starts CTE expr. */
%token  JSON_OBJECTAGG 920                /* SQL-2015-R */
%token  JSON_ARRAYAGG 921                 /* SQL-2015-R */
%token  OF_SYM 922                        /* SQL-1999-R */
%token<lexer.keyword> SKIP_SYM 923              /* MYSQL */
%token<lexer.keyword> LOCKED_SYM 924            /* MYSQL */
%token<lexer.keyword> NOWAIT_SYM 925            /* MYSQL */
%token  GROUPING_SYM 926                  /* SQL-2011-R */
%token<lexer.keyword> PERSIST_ONLY_SYM 927      /* MYSQL */
%token<lexer.keyword> HISTOGRAM_SYM 928         /* MYSQL */
%token<lexer.keyword> BUCKETS_SYM 929           /* MYSQL */
%token<lexer.keyword> OBSOLETE_TOKEN_930 930    /* was: REMOTE_SYM */
%token<lexer.keyword> CLONE_SYM 931             /* MYSQL */
%token  CUME_DIST_SYM 932                 /* SQL-2003-R */
%token  DENSE_RANK_SYM 933                /* SQL-2003-R */
%token<lexer.keyword> EXCLUDE_SYM 934           /* SQL-2003-N */
%token  FIRST_VALUE_SYM 935               /* SQL-2011-R */
%token<lexer.keyword> FOLLOWING_SYM 936         /* SQL-2003-N */
%token  GROUPS_SYM 937                    /* SQL-2011-R */
%token  LAG_SYM 938                       /* SQL-2011-R */
%token  LAST_VALUE_SYM 939                /* SQL-2011-R */
%token  LEAD_SYM 940                      /* SQL-2011-R */
%token  NTH_VALUE_SYM 941                 /* SQL-2011-R */
%token  NTILE_SYM 942                     /* SQL-2011-R */
%token<lexer.keyword> NULLS_SYM 943             /* SQL-2003-N */
%token<lexer.keyword> OTHERS_SYM 944            /* SQL-2003-N */
%token  OVER_SYM 945                      /* SQL-2003-R */
%token  PERCENT_RANK_SYM 946              /* SQL-2003-R */
%token<lexer.keyword> PRECEDING_SYM 947         /* SQL-2003-N */
%token  RANK_SYM 948                      /* SQL-2003-R */
%token<lexer.keyword> RESPECT_SYM 949           /* SQL_2011-N */
%token  ROW_NUMBER_SYM 950                /* SQL-2003-R */
%token<lexer.keyword> TIES_SYM 951              /* SQL-2003-N */
%token<lexer.keyword> UNBOUNDED_SYM 952         /* SQL-2003-N */
%token  WINDOW_SYM 953                    /* SQL-2003-R */
%token  EMPTY_SYM 954                     /* SQL-2016-R */
%token  JSON_TABLE_SYM 955                /* SQL-2016-R */
%token<lexer.keyword> NESTED_SYM 956            /* SQL-2016-N */
%token<lexer.keyword> ORDINALITY_SYM 957        /* SQL-2003-N */
%token<lexer.keyword> PATH_SYM 958              /* SQL-2003-N */
%token<lexer.keyword> HISTORY_SYM 959           /* MYSQL */
%token<lexer.keyword> REUSE_SYM 960             /* MYSQL */
%token<lexer.keyword> SRID_SYM 961              /* MYSQL */
%token<lexer.keyword> THREAD_PRIORITY_SYM 962   /* MYSQL */
%token<lexer.keyword> RESOURCE_SYM 963          /* MYSQL */
%token  SYSTEM_SYM 964                    /* SQL-2003-R */
%token<lexer.keyword> VCPU_SYM 965              /* MYSQL */
%token<lexer.keyword> MASTER_PUBLIC_KEY_PATH_SYM 966    /* MYSQL */
%token<lexer.keyword> GET_MASTER_PUBLIC_KEY_SYM 967     /* MYSQL */
%token<lexer.keyword> RESTART_SYM 968                   /* SQL-2003-N */
%token<lexer.keyword> DEFINITION_SYM 969                /* MYSQL */
%token<lexer.keyword> DESCRIPTION_SYM 970               /* MYSQL */
%token<lexer.keyword> ORGANIZATION_SYM 971              /* MYSQL */
%token<lexer.keyword> REFERENCE_SYM 972                 /* MYSQL */
%token<lexer.keyword> ACTIVE_SYM 973                    /* MYSQL */
%token<lexer.keyword> INACTIVE_SYM 974                  /* MYSQL */
%token          LATERAL_SYM 975                   /* SQL-1999-R */
%token<lexer.keyword> ARRAY_SYM 976                     /* SQL-2003-R */
%token<lexer.keyword> MEMBER_SYM 977                    /* SQL-2003-R */
%token<lexer.keyword> OPTIONAL_SYM 978                  /* MYSQL */
%token<lexer.keyword> SECONDARY_SYM 979                 /* MYSQL */
%token<lexer.keyword> SECONDARY_ENGINE_SYM 980          /* MYSQL */
%token<lexer.keyword> SECONDARY_LOAD_SYM 981            /* MYSQL */
%token<lexer.keyword> SECONDARY_UNLOAD_SYM 982          /* MYSQL */
%token<lexer.keyword> RETAIN_SYM 983                    /* MYSQL */
%token<lexer.keyword> OLD_SYM 984                       /* SQL-2003-R */
%token<lexer.keyword> ENFORCED_SYM 985                  /* SQL-2015-N */
%token<lexer.keyword> OJ_SYM 986                        /* ODBC */
%token<lexer.keyword> NETWORK_NAMESPACE_SYM 987         /* MYSQL */
%token<lexer.keyword> RANDOM_SYM 988                    /* MYSQL */
%token<lexer.keyword> MASTER_COMPRESSION_ALGORITHM_SYM 989 /* MYSQL */
%token<lexer.keyword> MASTER_ZSTD_COMPRESSION_LEVEL_SYM 990  /* MYSQL */
%token<lexer.keyword> PRIVILEGE_CHECKS_USER_SYM 991     /* MYSQL */
%token<lexer.keyword> MASTER_TLS_CIPHERSUITES_SYM 992   /* MYSQL */
%token<lexer.keyword> REQUIRE_ROW_FORMAT_SYM 993        /* MYSQL */
%token<lexer.keyword> PASSWORD_LOCK_TIME_SYM 994        /* MYSQL */
%token<lexer.keyword> FAILED_LOGIN_ATTEMPTS_SYM 995     /* MYSQL */
%token<lexer.keyword> REQUIRE_TABLE_PRIMARY_KEY_CHECK_SYM 996 /* MYSQL */
%token<lexer.keyword> STREAM_SYM 997                    /* MYSQL */
%token<lexer.keyword> OFF_SYM 998                       /* SQL-1999-R */
%token<lexer.keyword> RETURNING_SYM 999                 /* SQL-2016-N */
/*
  Here is an intentional gap in token numbers.

  Token numbers starting 1000 till YYUNDEF are occupied by:
  1. hint terminals (see sql_hints.yy),
  2. digest special internal token numbers (see gen_lex_token.cc, PART 6).

  Note: YYUNDEF in internal to Bison. Please don't change its number, or change
  it in sync with YYUNDEF in sql_hints.yy.
*/
%token YYUNDEF 1150                /* INTERNAL (for use in the lexer) */
%token<lexer.keyword> JSON_VALUE_SYM 1151               /* SQL-2016-R */
%token<lexer.keyword> TLS_SYM 1152                      /* MYSQL */
%token<lexer.keyword> ATTRIBUTE_SYM 1153                /* SQL-2003-N */

%token<lexer.keyword> ENGINE_ATTRIBUTE_SYM 1154         /* MYSQL */
%token<lexer.keyword> SECONDARY_ENGINE_ATTRIBUTE_SYM 1155 /* MYSQL */
%token<lexer.keyword> SOURCE_CONNECTION_AUTO_FAILOVER_SYM 1156 /* MYSQL */
%token<lexer.keyword> ZONE_SYM 1157                     /* SQL-2003-N */
%token<lexer.keyword> GRAMMAR_SELECTOR_DERIVED_EXPR 1158  /* synthetic token:
                                                            starts derived
                                                            table expressions. */
%token<lexer.keyword> REPLICA_SYM 1159
%token<lexer.keyword> REPLICAS_SYM 1160
%token<lexer.keyword> ASSIGN_GTIDS_TO_ANONYMOUS_TRANSACTIONS_SYM 1161      /* MYSQL */
%token<lexer.keyword> GET_SOURCE_PUBLIC_KEY_SYM 1162           /* MYSQL */
%token<lexer.keyword> SOURCE_AUTO_POSITION_SYM 1163            /* MYSQL */
%token<lexer.keyword> SOURCE_BIND_SYM 1164                     /* MYSQL */
%token<lexer.keyword> SOURCE_COMPRESSION_ALGORITHM_SYM 1165    /* MYSQL */
%token<lexer.keyword> SOURCE_CONNECT_RETRY_SYM 1166            /* MYSQL */
%token<lexer.keyword> SOURCE_DELAY_SYM 1167                    /* MYSQL */
%token<lexer.keyword> SOURCE_HEARTBEAT_PERIOD_SYM 1168         /* MYSQL */
%token<lexer.keyword> SOURCE_HOST_SYM 1169                     /* MYSQL */
%token<lexer.keyword> SOURCE_LOG_FILE_SYM 1170                 /* MYSQL */
%token<lexer.keyword> SOURCE_LOG_POS_SYM 1171                  /* MYSQL */
%token<lexer.keyword> SOURCE_PASSWORD_SYM 1172                 /* MYSQL */
%token<lexer.keyword> SOURCE_PORT_SYM 1173                     /* MYSQL */
%token<lexer.keyword> SOURCE_PUBLIC_KEY_PATH_SYM 1174          /* MYSQL */
%token<lexer.keyword> SOURCE_RETRY_COUNT_SYM 1175              /* MYSQL */
%token<lexer.keyword> SOURCE_SSL_SYM 1176                      /* MYSQL */
%token<lexer.keyword> SOURCE_SSL_CA_SYM 1177                   /* MYSQL */
%token<lexer.keyword> SOURCE_SSL_CAPATH_SYM 1178               /* MYSQL */
%token<lexer.keyword> SOURCE_SSL_CERT_SYM 1179                 /* MYSQL */
%token<lexer.keyword> SOURCE_SSL_CIPHER_SYM 1180               /* MYSQL */
%token<lexer.keyword> SOURCE_SSL_CRL_SYM 1181                  /* MYSQL */
%token<lexer.keyword> SOURCE_SSL_CRLPATH_SYM 1182              /* MYSQL */
%token<lexer.keyword> SOURCE_SSL_KEY_SYM 1183                  /* MYSQL */
%token<lexer.keyword> SOURCE_SSL_VERIFY_SERVER_CERT_SYM 1184   /* MYSQL */
%token<lexer.keyword> SOURCE_TLS_CIPHERSUITES_SYM 1185         /* MYSQL */
%token<lexer.keyword> SOURCE_TLS_VERSION_SYM 1186              /* MYSQL */
%token<lexer.keyword> SOURCE_USER_SYM 1187                     /* MYSQL */
%token<lexer.keyword> SOURCE_ZSTD_COMPRESSION_LEVEL_SYM 1188   /* MYSQL */

%token<lexer.keyword> ST_COLLECT_SYM 1189                      /* MYSQL */
%token<lexer.keyword> KEYRING_SYM 1190                         /* MYSQL */

%token<lexer.keyword> AUTHENTICATION_SYM         1191      /* MYSQL */
%token<lexer.keyword> FACTOR_SYM                 1192      /* MYSQL */
%token<lexer.keyword> FINISH_SYM                 1193      /* SQL-2016-N */
%token<lexer.keyword> INITIATE_SYM               1194      /* MYSQL */
%token<lexer.keyword> REGISTRATION_SYM           1195      /* MYSQL */
%token<lexer.keyword> UNREGISTER_SYM             1196      /* MYSQL */
%token<lexer.keyword> INITIAL_SYM                1197      /* SQL-2016-R */
%token<lexer.keyword> CHALLENGE_RESPONSE_SYM     1198      /* MYSQL */

%token<lexer.keyword> GTID_ONLY_SYM 1199                       /* MYSQL */

/*
  Precedence rules used to resolve the ambiguity when using keywords as idents
  in the case e.g.:

      SELECT TIMESTAMP'...'

  vs.

      CREATE TABLE t1 ( timestamp INT );

  The use as an ident is allowed, but must never take precedence over the use
  as an actual keyword. Hence we declare the fake token KEYWORD_USED_AS_IDENT
  to have the lowest possible precedence, KEYWORD_USED_AS_KEYWORD need only be
  a bit higher. The TEXT_STRING token is added here to resolve the ambiguity
  in the above example.
*/
%left KEYWORD_USED_AS_IDENT
%nonassoc TEXT_STRING
%left KEYWORD_USED_AS_KEYWORD


/*
  Resolve column attribute ambiguity -- force precedence of "UNIQUE KEY" against
  simple "UNIQUE" and "KEY" attributes:
*/
%right UNIQUE_SYM KEY_SYM

%left CONDITIONLESS_JOIN
%left   JOIN_SYM INNER_SYM CROSS STRAIGHT_JOIN NATURAL LEFT RIGHT ON_SYM USING
%left   SET_VAR
%left   OR_SYM OR2_SYM
%left   XOR
%left   AND_SYM AND_AND_SYM
%left   BETWEEN_SYM CASE_SYM WHEN_SYM THEN_SYM ELSE
%left   EQ EQUAL_SYM GE GT_SYM LE LT NE IS LIKE REGEXP IN_SYM
%left   '|'
%left   '&'
%left   SHIFT_LEFT SHIFT_RIGHT
%left   '-' '+'
%left   '*' '/' '%' DIV_SYM MOD_SYM
%left   '^'
%left   OR_OR_SYM
%left   NEG '~'
%right  NOT_SYM NOT2_SYM
%right  BINARY_SYM COLLATE_SYM
%left  INTERVAL_SYM
%left SUBQUERY_AS_EXPR
%left '(' ')'

%left EMPTY_FROM_CLAUSE
%right INTO
