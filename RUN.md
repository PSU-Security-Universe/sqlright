# Run Fuzzing

### Test SQLite with NoREC

To start fuzzing

```bash
cd <sqlright_root>/SQLite/scripts
# Run the fuzzing with CPU core 1~5 (core id is 0-based)
bash run_sqlite_fuzzing.sh SQLRight --start-core 0 --num-concurrent 5 --oracle NOREC
```

- [obselete] `SQLRight`: the current running configuration
- `start-core`: binds the fuzzing process to specific CPU cores. 
- `num-concurrent`: the number of concurrent fuzzing processes
- For example, `--start-core 0 --num-concurrent 5` will bind `5` fuzzing processes to CPU core `1~5`. 
- Make sure `start-core` + `num-concurrent` won't exceed the total CPU core count of your machine.

To stop the Docker fuzzing instance

```bash
sudo docker stop sqlright_sqlite_NOREC
```

To bisect bug reports

```bash
bash run_sqlite_bisecting.sh SQLRight --oracle NOREC
```

- The bisecting script will exit upon finished. 
- Unique bug reports can be found in `<sqlright_root>/SQLite3/Results/sqlright_sqlite_NOREC_bugs/bug_samples/unique_bug_output/`

---------------------------------------
### Test SQLite with TLP

To start fuzzing

```bash
cd <sqlright_root>/SQLite/scripts
# Run the fuzzing with CPU core 1~5 (core id is 0-based). 
# Please adjust the CORE ID based on your machine, 
# and do not use conflict core id with other running evaluation process. 
bash run_sqlite_fuzzing.sh SQLRight --start-core 0 --num-concurrent 5 --oracle TLP
```

To stop fuzzing

```bash
sudo docker stop sqlright_sqlite_TLP
```

To bisecting bug reports

```
bash run_sqlite_bisecting.sh SQLRight --oracle TLP
```

- Unique bug reports can be found in `<sqlright_root>/SQLite3/Results/sqlright_sqlite_TLP_bugs/bug_samples/unique_bug_output/`

--------------------------------------------------------------------------
### Test PostgreSQL with NoREC

To start fuzzing

```bash
cd <sqlright_root>/PostgreSQL/scripts
# Run the fuzzing with CPU core 1~5 (core id is 0-based). 
# Please adjust the CORE ID based on your machine, 
# and do not use conflict core id with other running evaluation process. 
bash run_postgres_fuzzing.sh SQLRight --start-core 0 --num-concurrent 5 --oracle NOREC
```

To stop fuzzing

```bash
sudo docker stop sqlright_postgres_NOREC
```

- All the detected bugs are logged in `<sqlright_root>/PostgreSQL/Results/sqlright_postgres_NOREC_bugs/bug_samples/`

--------------------------------------------------------------------------
### Test PostgreSQL with TLP

To start fuzzing

```bash
cd <sqlright_root>/PostgreSQL/scripts
# Run the fuzzing with CPU core 1~5 (core id is 0-based). 
# Please adjust the CORE ID based on your machine, 
# and do not use conflict core id with other running evaluation process. 
bash run_postgres_fuzzing.sh SQLRight --start-core 0 --num-concurrent 5 --oracle TLP
```

To stop fuzzing 

```bash
sudo docker stop sqlright_postgres_TLP
```

- All the detected bugs are logged in `<sqlright_root>/PostgreSQL/Results/sqlright_postgres_NOREC_bugs/bug_samples/`

--------------------------------------------------------------------------
### Test MySQL with NoREC

To start fuzzing

```bash
cd <sqlright_root>/MySQL/scripts
# Run the fuzzing with CPU core 1~5 (core id is 0-based). 
# Please adjust the CORE ID based on your machine, 
# and do not use conflict core id with other running evaluation process. 
bash run_mysql_fuzzing.sh SQLRight --start-core 0 --num-concurrent 5 --oracle NOREC
```

To stop fuzzing

```bash
sudo docker stop sqlright_mysql_NOREC
```

To bisect bug reports

```
bash run_mysql_bisecting.sh SQLRight --oracle NOREC
```

- The bisecting process will exit upon finished. 
- Unique bug reports can be found in `<sqlright_root>/MySQL/Results/sqlright_mysql_NOREC_bugs/bug_samples/unique_bug_output`.

**NOTE:** Due to the long compilation time of `MySQL`, we suggest to use pre-compiled binaries to help the bisecting.
The pre-built `MySQL` binaries should be placed in directory `<sqlright_root>/MySQL/bisecting/bisecting/mysql_binary_zip`
`MySQL` pre-built binaries can be found in the `sqlright_mysql_bisecting` docker (available in `Docker Hub`). 


------------------------------------
### Test MySQL with TLP

To start fuzzing

```bash
cd <sqlright_root>/MySQL/scripts
# Run the fuzzing with CPU core 1~5 (core id is 0-based). 
# Please adjust the CORE ID based on your machine, 
# and do not use conflict core id with other running evaluation process. 
bash run_mysql_fuzzing.sh SQLRight --start-core 0 --num-concurrent 5 --oracle TLP
```

To stop fuzzing 

```bash
sudo docker stop sqlright_mysql_TLP
```

To bisect bug reports
```
bash run_mysql_bisecting.sh SQLRight --oracle TLP
```

- The bisecting process will exit upon finished. 
- Unique bug reports can be found in `<sqlright_root>/MySQL/Results/sqlright_mysql_TLP_bugs/bug_samples/unique_bug_output`.

**NOTE:** Due to the long compilation time of `MySQL`, we suggest to use pre-compiled binaries to help the bisecting.
The pre-built `MySQL` binaries should be placed in directory `<sqlright_root>/MySQL/bisecting/bisecting/mysql_binary_zip`
`MySQL` pre-built binaries can be found in the `sqlright_mysql_bisecting` docker (available in `Docker Hub`). 
