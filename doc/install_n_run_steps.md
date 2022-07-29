# Installation and Run Instructions

### Operating System configuration and Source Code setup

The `SQLRight` fuzzing tools are built inside the Docker hosted environment. We have evaluated the `SQLRight` code, using `Ubuntu 20.04` as host system, with Docker version `>= 20.10.16`. The following scripts will setup some operating system settings that are required for `SQLRight` to run. 

**Warning**: If you are running your "host" system inside an Virtual Machine, i.e., VMware Workstation, VMware Fusion, VirtualBox, Parallel Desktop etc, the `Disable On-demand CPU scaling` step in the following script could fail. User can continue running `SQLRight` even if this specific setup step fails on their machine. But we generally don't recommend to run the `SQLRight` Docker environment inside any Virtual Machines, it could cause some unexpected errors. Check [Host system in VM](#host-system-in-vm) for more details. 

```bash
# System Configurations. 
# Open the terminal app from the host system.
# Disable On-demand CPU scaling
cd /sys/devices/system/cpu
echo performance | sudo tee cpu*/cpufreq/scaling_governor

# Avoid having crashes being misinterpreted as hangs
sudo sh -c " echo core >/proc/sys/kernel/core_pattern "
```

**WARNING**: Since the operating system will automatically reset some settings upon restarts, we need to reset the system settings using the above scripts **EVERY TIME** the computer restarted. If the system settings are not being setup correctly, the `SQLRight` fuzzing processes inside Docker could failed. 

The whole Artifact Evaluations are built within the `Docker` virtual environment. If the host system does not have the `Docker` application installed, here is the command to install `Docker` in `Ubuntu`. 

```bash
# The script is grabbed from Docker official documentation: https://docs.docker.com/engine/install/ubuntu/

sudo apt-get remove docker docker-engine docker.io containerd runc

sudo apt-get update
sudo apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
    
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# The next script could fail on some machines. However, the following installation process should still succeed. 
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Receiving a GPG error when running apt-get update?
# Your default umask may not be set correctly, causing the public key file for the repo to not be detected. Run the following command and then try to update your repo again: sudo chmod a+r /etc/apt/keyrings/docker.gpg.

# To test the Docker installation. 
sudo docker run hello-world
# Expected outputs 'Hello from Docker!'
``` 

By default, interacting with `Docker` requires the `root` privilege from the host system. For a normal (non-root) user, calling `docker` requires the `sudo` command prefix. 

### Host system in VM

We generally don't recommend to run this Artifact Evaluation inside a Virtual Machine, e.g., VMware Workstation, VMware Fusion, VirtualBox, Parallel Desktop etc. However, if an VM is the only choice, make sure you check the following:

- Make sure when you call any fuzzing command in the instructions, the `--start-core + --num-concurrent` number won't exceed the total number of CPU cores you assigned to the Virtual Machine. 

- If any of the `SQLRight` processes fail inside the system that is hosted by Virtual Machine, please consider to redo the `SQLRight` runs in a native (not virtual) environment. 

### Troubleshooting

- If the Docker image building process failed or stuck at some steps for a couple hours, consider to clean the Docker environment and rebuild the image. The following command will clean up the Docker cache, and we can rebuild another Docker image from scratch. 

```bash
sudo docker system prune --all
```

- If any fuzzing processes failed to launch, immediately return errors, or never output any results while running:
    - Please check whether the `System Configuration` has been setup correctly. Specifically, please repeat the steps of `Disable On-demand CPU scaling` and `Avoid having crashes being misinterpreted as hangs` before retrying the fuzzing scripts. 
    - Please check the `--start-core` and `--num-concurrent` flags you passed into the fuzzing command, and make sure `--start-core + --num-concurrent` won't exceed the total number of CPU cores you have on your machine. (This is a very common mistake that causes `SQLRight` failure. )

<br/><br/>
## 1.  Build the Docker Images

There are two ways to build the `Docker` Images for `SQLRight` fuzzing. The first way is to download the pre-built `Docker` images from `Docker Hub`. The detailed instructions are illustrated in `Section 1.1`. The second way is to build the `Docker` image from source `Dockerfile`. The steps are showed in `Section 1.2`.

### 1.1 Download pre-built `SQLRight` `Docker` images from `Docker Hub`

Here is the commands to download `SQLRight` images:

```bash
# For SQLite3 fuzzing and bisecting
sudo docker pull steveleungsly/sqlright_sqlite:version1.0

# For PostgreSQL fuzzing
sudo docker pull steveleungsly/sqlright_postgres:version1.0

# For MySQL fuzzing
sudo docker pull steveleungsly/sqlright_mysql:version1.0

# For MySQL bisecting
sudo docker pull steveleungsly/sqlright_mysql_bisecting:version1.0
```

### 1.2 Build `SQLRight` from `Dockerfile`

--------------------------------------------------------------------------
#### 1.2.1  Build the Docker Image for SQLite3 fuzzing

(Optional) If you want to run `SQLite` bug bisecting, please download all the contents from [Google Drive Shared Link](https://drive.google.com/drive/folders/1zDvLf93MJbtGXByzDXZ-CbfNPAd3wUGJ?usp=sharing), and place the downloaded contents to the following `SQLRight` repo location. 

```bash
<sqlright_root>/SQLite/docker/sqlite_bisecting_binary_zip
```

Execute the following command before running any SQLite3 related fuzzing. 

The Docker build process can last for about `1` hour. Expect long runtime when executing this command. 
```bash
cd <sqlright_root>/SQLite/scripts/
bash setup_sqlite.sh
```

After the command finished, a Docker Image named `sqlright_sqlite` is created. 

--------------------------------------------------------------------------
#### 1.2.2  Build the Docker Image for PostgreSQL fuzzing

Execute the following command before running any PostgreSQL related fuzzing. 

The Docker build process can last for about `1` hour. Expect long runtime when executing this command. 
```bash
cd <sqlright_root>/PostgreSQL/scripts/
bash setup_postgres.sh
```

After the command finished, a Docker Image named `sqlright_postgres` is created. 

--------------------------------------------------------------------------
#### 1.2.3  Build the Docker Images for MySQL evaluations

Execute the following command before running any MySQL related fuzzing. 

The Docker build process can last for about `3` hour. Expect long runtime when executing the command.

We expect some **Warnings** returned from the MySQL compilation process. These **Warnings** won't impact the build process. 

```bash
cd <sqlright_root>/MySQL/scripts/
bash setup_mysql.sh
```

After the command finished, the Docker image named `sqlright_mysql` is created. 

**Warning** Due to the large binary size from the pre-compiled versions of `MySQL`, we do not include the steps to build the `sqlright_mysql_bisecting` docker image. To run bisecting for the detected bugs from the `MySQL` DBMS, please pull the `sqlright_mysql_bisecting` image from the `Docker Hub`. More detailed instructions are shown in `Section 1.1`. 

<br/><br/>
## 2. Run SQLRight fuzzing

### 2.1 SQLite NoREC oracle

The following bash scripts will wake the fuzzing script inside `sqlright_sqlite` Docker image, and start the `SQLRight` `SQLite3` fuzzing with `NoREC` oracle. 

```bash
cd <sqlright_root>/SQLite/scripts
# Run the fuzzing with CPU core 1~5 (core id is 0-based)
bash run_sqlite_fuzzing.sh SQLRight --start-core 0 --num-concurrent 5 --oracle NOREC
```

Explanation of the command:

- The argument `SQLRight` determines the current running configuration. 

- The `start-core` flag binds the fuzzing process to the specific CPU core. The index starts with `0`. Using `start-core 0` will bind the first fuzzing process to the first CPU core on your machine. Combined with `num-concurrent`, the script will bind each fuzzing process to a unique CPU core, in order to avoid performance penalty introduced by running mutliple processes on one CPU core. For example, flags: `--start-core 0 --num-concurrent 5` will bind `5` fuzzing processes to CPU core `1~5`. Throughout all the evaluation scripts we show in this instruction, we use a default value of `0` for `--start-core`. However, please adjust the CORE-ID based on your testing scenarios, and avoid conflicted CORE-ID already used by other running evaluation processes. 

- The `num-concurrent` flag determines the number of concurrent fuzzing processes. If the testing machine is constrained by CPU cores, memory size or hard drive space, consider using a lower value for this flag. In our paper evaluations, we use the value of `5` across all the configurations. 

- **Attention**: Make sure `start-core + num-concurrent` won't exceed the total CPU core count of your machine. Otherwise, the script will return error and the fuzzing process will failed to launch. 

- The `oracle` flag determines the oracle used for the fuzzing. `SQLRight` currently support: `NOREC` and `TLP`. User can include more oracles in their own implementation. 

To stop the Docker container instance, use the following command.
```bash
# Stop the fuzzing process
sudo docker stop sqlright_sqlite_NOREC
# Run bug bisecting
bash run_sqlite_bisecting.sh SQLRight --oracle NOREC
```

And then, use the following command to do bug bisecting: 

```bash
# Run bug bisecting
bash run_sqlite_bisecting.sh SQLRight --oracle NOREC
```

The bisecting script doesn't require `--start-core` and `--num-concurrent` flags. And it will auto exit upon finished. The unique bug reports will be generated in `<sqlright_root>/SQLite3/Results/sqlright_sqlite_NOREC_bugs/bug_samples/unique_bug_output/`.

--------------------------------------------------------------------------
### 2.2 PostgreSQL NoREC

The following bash scripts will wake the fuzzing script inside `sqlright_postgres` Docker image, and start the `SQLRight` `PostgreSQL` fuzzing with `NoREC` oracle. 

```bash
cd <sqlright_root>/PostgreSQL/scripts
# Run the fuzzing with CPU core 1~5 (core id is 0-based). 
# Please adjust the CORE ID based on your machine, 
# and do not use conflict core id with other running evaluation process. 
bash run_postgres_fuzzing.sh SQLRight --start-core 0 --num-concurrent 5 --oracle NOREC
```

To stop the Docker container instance:

```bash
sudo docker stop sqlright_postgres_NOREC
```

Since we did not find any bugs for `PostgreSQL` in our evaluation, we did not include the bug bisecting tool for `PostgreSQL` fuzzing. All the detected bugs from `Postgres` are logged in `<sqlright_root>/PostgreSQL/Results/sqlright_postgres_NOREC_bugs/bug_samples/`

--------------------------------------------------------------------------
### 2.3 MySQL NoREC

The following bash scripts will wake the fuzzing script inside `sqlright_mysql` Docker image, and start the `SQLRight` `MySQL` fuzzing with `NoREC` oracle. 

```bash
cd <sqlright_root>/MySQL/scripts
# Run the fuzzing with CPU core 1~5 (core id is 0-based). 
# Please adjust the CORE ID based on your machine, 
# and do not use conflict core id with other running evaluation process. 
bash run_mysql_fuzzing.sh SQLRight --start-core 0 --num-concurrent 5 --oracle NOREC
```

To stop the Docker container instance, run the following command.

```bash
# Stop the fuzzing process
sudo docker stop sqlright_mysql_NOREC
```

And then run the following bug bisecting command. 

```
# Run bug bisecting
bash run_mysql_bisecting.sh SQLRight --oracle NOREC
```

**WARNING** Due to the long compilation time for the `MySQL` DBMS, we are using pre-compiled and cached `MySQL` binaries to bisect the detect logical bugs. As time passes, the cached `MySQL` binaries can become out-of-date and the bisecting can thus become inaccurate. We recommend the developer to add in new `MySQL` versions, or re-compile the MySQL cached binaries in the future `MySQL` runs, in order to keep the bisecting results more accurate. The `MySQL` cached binaries zip files can be located in directory `<sqlright_root>/MySQL/bisecting/bisecting/mysql_binary_zip`. 

**WARNING** Bisecting requires `sqlright_mysql_bisecting` docker image pulled from the `Docker Hub`. Please pull the Docker image using the instructions provided in `Section 1.1`. 

The bisecting script doesn't require `--start-core` and `--num-concurrent` flags. And it will auto exit upon finished. The unique bug reports will be generated in `<sqlright_root>/MySQL/Results/sqlright_mysql_NOREC_bugs/bug_samples/unique_bug_output`.

---------------------------------------
### 2.4 SQLite TLP

Run the following command. 

The following bash scripts will wake the fuzzing script inside `sqlright_sqlite` Docker image, and start the `SQLRight` `SQLite3` fuzzing with `TLP` oracle. 

```bash
cd <sqlright_root>/SQLite/scripts
# Run the fuzzing with CPU core 1~5 (core id is 0-based). 
# Please adjust the CORE ID based on your machine, 
# and do not use conflict core id with other running evaluation process. 
bash run_sqlite_fuzzing.sh SQLRight --start-core 0 --num-concurrent 5 --oracle TLP
```

To stop the Docker container instance, run the following command.


```bash
# Stop the fuzzing process
sudo docker stop sqlright_sqlite_TLP
```

Run the bug bisecting command. 

```
# Run bug bisecting
bash run_sqlite_bisecting.sh SQLRight --oracle TLP
```

--------------------------------------------------------------------------
### 2.5 PostgreSQL TLP

Run the following command.

The following bash scripts will wake the fuzzing script inside `sqlright_postgres` Docker image, and start the `SQLRight` `PostgreSQL` fuzzing with `TLP` oracle. 

```bash
cd <sqlright_root>/PostgreSQL/scripts
# Run the fuzzing with CPU core 1~5 (core id is 0-based). 
# Please adjust the CORE ID based on your machine, 
# and do not use conflict core id with other running evaluation process. 
bash run_postgres_fuzzing.sh SQLRight --start-core 0 --num-concurrent 5 --oracle TLP
```

To stop the Docker container instance. 

```bash
sudo docker stop sqlright_postgres_TLP
```

Since we did not find any bugs for PostgreSQL, we skip the bug bisecting process for PostgreSQL fuzzing. 

--------------------------------------------------------------------------
### 2.6 MySQL TLP

Run the following command.

The following bash scripts will wake the fuzzing script inside `sqlright_mysql` Docker image, and start the `SQLRight` `MySQL` fuzzing with `TLP` oracle. 

```bash
cd <sqlright_root>/MySQL/scripts
# Run the fuzzing with CPU core 1~5 (core id is 0-based). 
# Please adjust the CORE ID based on your machine, 
# and do not use conflict core id with other running evaluation process. 
bash run_mysql_fuzzing.sh SQLRight --start-core 0 --num-concurrent 5 --oracle TLP
```

To stop the Docker container instance, run the following command. 

```bash
# Stop the fuzzing process
sudo docker stop sqlright_mysql_TLP
```

And then run the following bug bisecting command. 
```
# Run bug bisecting
bash run_mysql_bisecting.sh SQLRight --oracle TLP
```

**WARNING** Due to the long compilation time for the `MySQL` DBMS, we are using pre-compiled and cached `MySQL` binaries to bisect the detect logical bugs. As time passes, the cached `MySQL` binaries can become out-of-date and the bisecting can thus become inaccurate. We recommend the developer to add in new `MySQL` versions, or re-compile the MySQL cached binaries in the future `MySQL` runs, in order to keep the bisecting results more accurate. The `MySQL` cached binaries zip files can be located in directory `<sqlright_root>/MySQL/bisecting/bisecting/mysql_binary_zip`. 

**WARNING** Bisecting requires `sqlright_mysql_bisecting` docker image pulled from the `Docker Hub`. Please pull the Docker image using the instructions provided in `Section 1.1`. 

The unique bug reports will be generated in `<sqlright_root>/MySQL/Results/sqlright_mysql_TLP_bugs/bug_samples/unique_bug_output`.

<br/><br/>
## 3. SQLRight development

### 3.1 SQLRight code structure

The `SQLRight` source code are located in the following location in the repo:

```bash
# SQLite
<sqlright_root>/SQLite/docker/src

# PostgreSQL
<sqlright_root>/PostgreSQL/docker/src

# MySQL
<sqlright_root>/MySQL/docker/src
```

The `SQLRight` code for all three DBMSs share a similar code structure. 

- `AFL` folder contains the main entry of the `SQLRight` program. The `main` function of `SQLRight` is located in the file `AFL/afl-fuzz.cpp`.
- `include` folder for header files. 
- `oracle` folder contains all the `DBMS oracle` implementation code. All `oracle` related code, including the source and header files are all placed here. 
- `parser` folder contains the per-DBMS Bison parser file. This translated parser comes from the original parser front end from the DBMS, it now translates the SQL strings to `SQLRight Intermediate Representation (IR)` instead of `DBMS internal Representation`. 
- `src` folder contains all the helper tools for `SQLRight`, including: 
    - `ast.cpp`: The `SQLRight IR` definitions. 
    - `ir_wrapper.cpp`: The helper functions for handling the `SQLRight IR`. Heavily used by the `general oracle interface`.
    - `mutator.cpp`: The fuzzing mutation logic for `SQLRight`.
    - `utils.cpp`: Some more general helper functions, such as string handling functions etc. 

### 3.2 SQLRight new oracle development

To develop a new DBMS oracle for `SQLRight`, all we need to do is to implement a new C++ inherited class, and place it in the `oracle` folder. The base oracle class is implemented in the `<dbms_name>_oracle.h` and `<dbms_name_oracle.cpp>` source files. We can inherit the pre-defined base class APIs to implement our new oracles. 

We can use the `SQLite` `LIKELY` oracle as example, to demonstrate how to implement a new oracle using `SQLRight` oracle interface. 

The `LIKELY` oracle adds additional `LIKELY` or `UNLIKELY` optimization hints, to the `SQLite3` output `SELECT` statements. The `LIKELY/UNLIKELY` optimization from `SQLite3` should not change the results from the `SELECT`. By using this intuition and comparing the `SELECT` results with/without `LIKELY/UNLIKLY` hints, we can find `LIKELY` related optimization bugs in the `SQLite3` DBMS. 

--------------------------------------------------------------------------

#### 3.2.1 Create oracle class files

Create the `sqlite_likely.h` and `sqlite_likely.cpp` files in the `<sqlright_root>/SQLite/docker/src/oracle` folder. 

Include the `sqlite_oracle.h` header file, and declare the new `SQLITE_LIKELY` class, inherited from the `SQLITE_ORACLE` class. 

--------------------------------------------------------------------------

#### 3.2.2 Implement the required class functions

A more detailed per class function explanations are included in the `sqlite_oracle.h` source code comments. Here, we only mentioned the APIs we used to implement  the `LIKELY` oracle. 

- **preprocess** APIs: We do not require to implement any custom logic for `LIKELY` oracle query preprocessing. Therefore, the `SQLITE_LIKELY` class doesn't contain any `preprocess` functions. However, for other oracles such as `INDEX` (add/remove `INDEX` from the query), we can use `IR* get_random_append_stmts_ir();` to insert `CREATE INDEX` statements to the query set. 

- **attach_output** APIs: In this step, we add in the oracle related `SELECT` statements to the query sets. `SQLRight` will save all the `SELECT` statements from the input seeds, mutate them to a different form, and pass the mutated `SELECT` statements to `bool get_random_append_stmts_ir();` function. Developer can use this function to determine whether the current form of `SELECT` statement is supported by the oracle or not, and use this function to return the boolean results. If return false, the mutated `select` will be discarded. If return true, the current mutated `select` will passed to the next step for query transformation. For `LIKELY` oracle, this API make sure the `FROM` clause and the `WHERE` clause are existed in the mutated `SELECT` query. 

- **transform** APIs: The `transform` APIs contains two main functions: `vector<IR*> pre_fix_transform_select_stmt` and `vector<IR*> pro_fix_transform_select_stmt`. These APIs receive the original form of the oracle compatible `SELECT` statements (from **attach_output** step), and return multiple functional equivalent forms of `SELECTs`. The `pre_fix_*` API happens before the `IR Instantiazation` process, where all the query operands (table names, column names, numerical values etc) are not filled in yet. And thus, the equivalent forms of `SELECTs` will later be filled in with different operands. The `post_fix_*` API happens after the `IR Instantiazation` process, where the query operands are determined and already filled in to the received `SELECT` statement. This `post_fix_*` API is suitable for functional equivalent queries that requires to maintain the exact same operands. The `LIKELY` oracle use the `post_fix_*` function, which adds in `LIKELY` and `UNLIKELY` functions to the `SELECT WHERE clause`, forming three functionally equivalent queries (including the original received form). 

- **compare** API: Allow the developer to define their own rules to check the `SELECT` statements' results for potential logical bugs. The related function is `compare_results`. If the query results are expected, returns `ORA_COMP_RES::Pass`; if the query results are potentially buggy, returns `ORA_COMP_RES::Fail`; if the query results are plained errors, returns `ORA_COMP_RES::Error`. `SQLRight` will automatically generate bug report for every result that has been marked as `ORA_COMP_RES:Fail`. 

Some additional tools can be used to design a new oracle: The `test-parser` program (src: `AFL/test-parser.cpp`, to build: `make test-parser`) can print the IR structure for any compatible SQL query strings. It can be used to visualize and debug the SQL query statements modified by the oracle interface. 

--------------------------------------------------------------------------

#### 3.2.3 Expose the newly implemented oracle

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

#### 3.2.4 Implement the oracle in the bisecting code

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

#### 3.2.5 Run the newly implemented oracle

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

#### End of New Oracle Development Steps

--------------------------------------------------------------------------
