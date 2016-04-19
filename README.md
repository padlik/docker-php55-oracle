[1]:https://github.com/padlik/docker-php55-oracle/blob/master/Dockerfile
# PHP 5.5 with Oracle
Latest:[(Dockerfile/Latest)][1]

Image provides Apache, PHP 5.5 with Oracle client libraries and `SQLPLUS` utility and ready to be used with SugarCRM installations. 

## Running image

```sh
$ docker run -d --name sugar -e SUGAR_DB_TYPE=oci8 \ 
    -e DB_USER=sugar -e DB_PASS=sugar \
    -p 80:80 --link oracle:oracle --link elastic:elastic \ 
    -v $(pwd)/sugar.d:/sugar.d absolutapps/stack-php55-oracle
```

- `SUGAR_DB_TYPE`  can be set to `mysql` (which is default) or `oci8`
- `DB_USER` should have admin privileges (e.g DBA for Oracle) 
Each sugar ZIP bundle under `/sugar.d` folder will be unzipped and silently installed into /var/www/html/sugar/<Bundle_Name> 

## Possible options

### Licensing
`SUGAR_LICENSE` - String. Valid license key for appropriate SugarCRM version 

### Database options
- `SUGAR_DB_TYPE` - [ **mysql** | oic8 ]
- `MYSQL_HOST` - default: **mysql** 
- `MYSQL_PORT` - default: **3306**
- `DB_USER` default: **sugar**
- `DB_PASS` default: **sugar**
- `ORACLE_SERVICE` default: **orcl**
- `ORACLE_HOST` default: **oracle**
- `ORACLE_PORT` default: **1521**
- `TNS_NAME` default: **ORCL**

> **Note:**
Oracle client is installed to `/usr/local/lib/instantclient`. All Oracle (e.g. `ORACLE_HOME`) related variables are point to this folder. File `tnsnames.ora` is populated by default with values based on `TNS_NAME`, `ORACLE_HOST`, `ORACLE_PORT` and `ORACLE_SERVICE` as per example:
```
ORCL =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = oracle)(PORT = 1521))
      (CONNECT_DATA =
        (SERVER = DEDICATED)
        (SERVICE_NAME = orcl)
      )
    )
```

### Elasticsearch related parameters
Sugar requires [Elasticsearch][2] to be available. 
`ELASTIC_HOST` default: **elastic**
`ELASTIC_PORT` default: **9200**

[2]:https://hub.docker.com/_/elasticsearch/

