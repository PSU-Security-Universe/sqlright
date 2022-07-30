# Development New Oracles


```bash

# SQLRight Code Structure

# SQLite
<sqlright_root>/SQLite/docker/src

# PostgreSQL
<sqlright_root>/PostgreSQL/docker/src

# MySQL
<sqlright_root>/MySQL/docker/src

# under each src folder
- AFL: fuzzing logic, like code coverage
- include: header files
- oracle: oracle related code 
- parser: per-DBMS Bison parser file, translated from the original DBMS parser
- src: helper tools, including: 
    - ast.cpp: definition of intermediate representation (IR) 
    - ir_wrapper.cpp: helper functions for processing IR, heavily used by the general oracle interface
    - mutator.cpp: IR mutation logic
    - utils.cpp: more general helper functions, like string processing
```

To develop a new DBMS oracle for `SQLRight`, all we need to do is to implement a new C++ inherited class, and place it in the `oracle` folder. The base oracle class is implemented in the `<dbms_name>_oracle.h` and `<dbms_name_oracle.cpp>` source files. We can inherit the pre-defined base class APIs to implement our new oracles. 

We can use the `SQLite` `LIKELY` oracle as example, to demonstrate how to implement a new oracle using `SQLRight` oracle interface. 

The `LIKELY` oracle adds additional `LIKELY` or `UNLIKELY` optimization hints, to the `SQLite3` output `SELECT` statements. The `LIKELY/UNLIKELY` optimization from `SQLite3` should not change the results from the `SELECT`. By using this intuition and comparing the `SELECT` results with/without `LIKELY/UNLIKLY` hints, we can find `LIKELY` related optimization bugs in the `SQLite3` DBMS. 

--------------------------------------------------------------------------

### 1. Create oracle class files

Create the `sqlite_likely.h` and `sqlite_likely.cpp` files in the `<sqlright_root>/SQLite/docker/src/oracle` folder. 

Include the `sqlite_oracle.h` header file, and declare the new `SQLITE_LIKELY` class, inherited from the `SQLITE_ORACLE` class. 

--------------------------------------------------------------------------

### 2. Implement the required class functions

A more detailed per class function explanations are included in the `sqlite_oracle.h` source code comments. Here, we only mentioned the APIs we used to implement  the `LIKELY` oracle. 

- **preprocess** APIs: We do not require to implement any custom logic for `LIKELY` oracle query preprocessing. Therefore, the `SQLITE_LIKELY` class doesn't contain any `preprocess` functions. However, for other oracles such as `INDEX` (add/remove `INDEX` from the query), we can use `IR* get_random_append_stmts_ir();` to insert `CREATE INDEX` statements to the query set. 

- **attach_output** APIs: In this step, we add in the oracle related `SELECT` statements to the query sets. `SQLRight` will save all the `SELECT` statements from the input seeds, mutate them to a different form, and pass the mutated `SELECT` statements to `bool get_random_append_stmts_ir();` function. Developer can use this function to determine whether the current form of `SELECT` statement is supported by the oracle or not, and use this function to return the boolean results. If return false, the mutated `select` will be discarded. If return true, the current mutated `select` will passed to the next step for query transformation. For `LIKELY` oracle, this API make sure the `FROM` clause and the `WHERE` clause are existed in the mutated `SELECT` query. 

- **transform** APIs: The `transform` APIs contains two main functions: `vector<IR*> pre_fix_transform_select_stmt` and `vector<IR*> pro_fix_transform_select_stmt`. These APIs receive the original form of the oracle compatible `SELECT` statements (from **attach_output** step), and return multiple functional equivalent forms of `SELECTs`. The `pre_fix_*` API happens before the `IR Instantiazation` process, where all the query operands (table names, column names, numerical values etc) are not filled in yet. And thus, the equivalent forms of `SELECTs` will later be filled in with different operands. The `post_fix_*` API happens after the `IR Instantiazation` process, where the query operands are determined and already filled in to the received `SELECT` statement. This `post_fix_*` API is suitable for functional equivalent queries that requires to maintain the exact same operands. The `LIKELY` oracle use the `post_fix_*` function, which adds in `LIKELY` and `UNLIKELY` functions to the `SELECT WHERE clause`, forming three functionally equivalent queries (including the original received form). 

- **compare** API: Allow the developer to define their own rules to check the `SELECT` statements' results for potential logical bugs. The related function is `compare_results`. If the query results are expected, returns `ORA_COMP_RES::Pass`; if the query results are potentially buggy, returns `ORA_COMP_RES::Fail`; if the query results are plained errors, returns `ORA_COMP_RES::Error`. `SQLRight` will automatically generate bug report for every result that has been marked as `ORA_COMP_RES:Fail`. 

Some additional tools can be used to design a new oracle: The `test-parser` program (src: `AFL/test-parser.cpp`, to build: `make test-parser`) can print the IR structure for any compatible SQL query strings. It can be used to visualize and debug the SQL query statements modified by the oracle interface. 

--------------------------------------------------------------------------

### 3. Expose the newly implemented oracle

Include the newly created `sqlite_<new-oracle>.h` header file to the `AFL/afl-fuzz.cpp` source. 

In the `main` function arguments handling logic, add in the new oracle as available parameter. For `LIKELY` oracle, the following lines are added. 

```diff
@@ -7660,8 +7660,6 @@ int main(int argc, char **argv) {
...
      case 'O': /* Oracle */
      {
        /* Default NOREC */
        string arg = string(optarg);
        if (arg == "NOREC")
         p_oracle = new SQL_NOREC();
       else if (arg == "TLP")
         p_oracle = new SQL_TLP();
+      else if (arg == "LIKELY")
+        p_oracle = new SQL_LIKELY();
       else if (arg == "ROWID")
         p_oracle = new SQL_ROWID();
       else if (arg == "INDEX")
...
```

The implementation of `LIKELY` oracle is finished in `SQLRight` source code. 

--------------------------------------------------------------------------
### 4. Implement the oracle in the bisecting code

This step is optional.

The `bisecting` code are located in the following locations:

```bash
# SQLite bisecting python script
<sqlright_root>/SQLite/docker/bisecting

# MySQL bisecting python script
<sqlright_root>/MySQL/bisecting/bisecting/bisecting_scripts
```

Similar to the `SQLRight` source code, all the oracle related code are located in the `ORACLE` subfolders. Take `SQLite` `LIKELY` oracle again for example, the newly created `ORACLE_LIKELY.py` file is responsible to implement the following two functions:

- `def retrive_all_results()`: This function retrieves all the results from the `SELECT` statements, and extracts only the oracle related results. Since `SQLRight` puts all oracle related results within the `BEGIN VERI *` lines, this function simply extracts all results between those lines. (We can copy and paste this function to new oracle implementation if we didn't change the `SQLRight` results outputting logic. )

- `def comp_query_res()`: Port the logic of result comparison methods from `SQLRight` `compare` API to a python version, and place the translated python code here. 

And at last, import the newly defined oracle python file to the `__main__.py` file (`SQLite`), or `analysis.py` (`MySQL`), and expose the oracle parameter to the CLI. 

```diff
--- a/SQLite/docker/bisecting/__main__.py
+++ b/SQLite/docker/bisecting/__main__.py
@@ -42,6 +42,8 @@ def main():
...
     oracle = 0
     if oracle_str == "NOREC":
         oracle = Oracle_NOREC
     elif oracle_str == "TLP":
         oracle = Oracle_TLP
+    elif oracle_str == "LIKELY":
+        oracle = Oracle_LIKELY
     else:
         oracle = Oracle_NoREC
...
```

--------------------------------------------------------------------------

### 5. Run the newly implemented oracle

Because we have modified the `SQLRight` and bisecting source code, we need to rebuild the docker testing environment to reflect on the changes. We need to repeat the steps on `Section 1: Build the Docker Images`. 

And then, run the fuzzing process with the new oracle:

```bash
# For SQLite3
cd <sqlright_root>/SQLite/scripts
# Run the fuzzing with CPU core 1~5 (core id is 0-based)
# bash run_sqlite_fuzzing.sh SQLRight --start-core 0 --num-concurrent 5 --oracle <new-oracle>
bash run_sqlite_fuzzing.sh SQLRight --start-core 0 --num-concurrent 5 --oracle LIKELY


# For PostgreSQL
cd <sqlright_root>/PostgreSQL/scripts
# Run the fuzzing with CPU core 1~5 (core id is 0-based). 
# Please adjust the CORE ID based on your machine, 
# and do not use conflict core id with other running evaluation process. 
bash run_postgres_fuzzing.sh SQLRight --start-core 0 --num-concurrent 5 --oracle <new-oracle>

# For MySQL
cd <sqlright_root>/MySQL/scripts
# Run the fuzzing with CPU core 1~5 (core id is 0-based). 
# Please adjust the CORE ID based on your machine, 
# and do not use conflict core id with other running evaluation process. 
bash run_mysql_fuzzing.sh SQLRight --start-core 0 --num-concurrent 5 --oracle <new-oracle>
```

For bisecting:
```bash
# For SQLite3
cd <sqlright_root>/SQLite/scripts
# bash run_sqlite_bisecting.sh SQLRight --oracle <new-oracle>
bash run_sqlite_bisecting.sh SQLRight --oracle LIKELY

# For MySQL
cd <sqlright_root>/MySQL/scripts
bash run_mysql_bisecting.sh SQLRight --oracle <new-oracle>
```
