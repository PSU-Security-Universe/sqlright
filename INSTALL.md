# Get Docker Images

You can take two ways to prepare the docker images for `SQLRight`: download the pre-built images from `Docker Hub`, or build the image from source `Dockerfile`.

### Download Pre-built Docker Images

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

### Build Dockers Locally

* Docker for testing SQLite3  (may take 1 hour or longer)

To run `SQLite` bug bisecting, download pre-built SQLite3 binaries from [Google Drive Shared Link](https://drive.google.com/drive/folders/1zDvLf93MJbtGXByzDXZ-CbfNPAd3wUGJ?usp=sharing), and place the contents to foder `<sqlright_root>/SQLite/docker/sqlite_bisecting_binary_zip`

```bash
cd <sqlright_root>/SQLite/scripts/
bash setup_sqlite.sh
# will create a docker called "sqlright_sqlite"
```

* Docker for testing PostgreSQL (may take 1 hour or longer)

```bash
cd <sqlright_root>/PostgreSQL/scripts/
bash setup_postgres.sh
# will create a docker file "sqlright_postgres"
```

* Docker for testing MySQL (may take 3 hour or longer. Warnnings expected) 


```bash
cd <sqlright_root>/MySQL/scripts/
bash setup_mysql.sh
# will create a docker file "sqlright_mysql"
```

* Docker for bisecting MySQL bug repors

Due to the large size of the pre-compiled binaries, we exclude the steps to build the `sqlright_mysql_bisecting` docker. To bisect `MySQL` bug reports, pull the `sqlright_mysql_bisecting` docker from the `Docker Hub`
