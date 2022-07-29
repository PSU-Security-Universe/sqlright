SET @save_sql_mode=@@sql_mode;
set sql_mode = pipes_as_concat;
SET @@sql_mode=@save_sql_mode;
call solver("[[2,3,1],  [5,-3,10],  [6,0,12]]", "[7,21,28]");
call solver("[[1,2,1,3],  [1,0,1,1],  [0,1,0,1],  [1,3,1,4]]", "[1,3,-1,4]");
call solver("[[1,2,1,3],  [1,0,1,1],  [0,1,0,1],  [1,3,1,3]]", "[1,3,-1,4]");
drop procedure solver;
