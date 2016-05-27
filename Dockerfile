FROM ubuntu:15.10
ENV DEBIAN_FRONTEND noninteractive

ENV LD_LIBRARY_PATH=/usr/local/lib/instantclient
ENV TNS_ADMIN=/usr/local/lib/instantclient
ENV ORACLE_BASE=/usr/local/lib/instantclient
ENV ORACLE_HOME=$ORACLE_BASE
ENV PATH=$PATH:$ORACLE_HOME

RUN apt-get update && \
   apt-get install -y build-essential php5-dev php-pear libaio1 php5 php5-mysql libaio-dev php5-curl php5-gd unzip mysql-client  && \
   cd /usr/local/lib && \
   curl https://dl.dropboxusercontent.com/s/2gimcl6tbs1wmz4/instantclient_12_1.tar.gz?dl=0 | tar -xzf - && \
   ln -s instantclient_12_1 instantclient && \
   cd /usr/local/lib/instantclient && \
   ln -s libclntsh.so.12.1 libclntsh.so && \
   echo "instantclient,/usr/local/lib/instantclient" | pecl install oci8-2.0.11 && \
   touch /etc/php5/cli/conf.d/oci8.ini && \
   echo "extension=oci8.so" > /etc/php5/cli/conf.d/oci8.ini && \
   ln -s /etc/php5/cli/conf.d/oci8.ini /etc/php5/apache2/conf.d/oci8.ini && \
   echo "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH" >> /etc/apache2/envvars && \
   echo "export TNS_ADMIN=$TNS_ADMIN" >> /etc/apache2/envvars && \
   echo "export ORACLE_BASE=$ORACLE_BASE" >> /etc/apache2/envvars && \
   echo "export ORACLE_HOME=$ORACLE_HOME" >> /etc/apache2/envvars && \
   a2enmod rewrite proxy_http reqtimeout cgi mime_magic authz_groupfile && \
   mkdir /sugar.d  && \
   apt-get clean  && \
   rm -fr /var/lib/apt/lists/* 


ENV SUGAR_BASE=sugar
ENV WEB_ROOT=/var/www/html
ENV SUGAR_HOME=$WEB_ROOT/$SUGAR_BASE
ENV SUGAR_LICENSE='<>'

ENV SUGAR_DB_TYPE=mysql

ENV MYSQL_HOST=mysql
ENV MYSQL_PORT=3306

ENV DB_USER=sugar
ENV DB_PASS=sugar

ENV ELASTIC_HOST=elastic
ENV ELASTIC_PORT=9200


ENV ORACLE_SERVICE=orcl
ENV ORACLE_HOST=oracle
ENV ORACLE_PORT=1521
ENV TNS_NAME=ORCL

ENV APACHE_USER=www-data
ENV APACHE_GROUP=www-data

ENV PHP_MEM_LIMIT=1024M
ENV PHP_UPLOAD_LIMIT=20M

ENV SUGAR_AUTO="/sugar.d"

EXPOSE 80

COPY entrypoint.sh /entrypoint.sh

VOLUME ["$SUGAR_HOME"]
VOLUME ["/sugar.d"]
ENTRYPOINT ["/entrypoint.sh"]
